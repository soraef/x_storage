import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:type_result/type_result.dart';
import 'package:x_storage_core/x_storage_core.dart';

import 'file_storage_provider.dart';
import 'sync_metadata_store.dart';

/// ローカルが正、リモートがバックアップ/同期先となるストレージプロバイダー
///
/// - `saveFile`: ローカル保存 → リモート試行 → 成功: synced / 失敗: pendingUpload
/// - `loadFile`: ローカル → 失敗ならリモート → ローカルに保存、synced に設定
/// - `deleteFile`: ローカル削除 → リモート試行 → 成功: メタデータ除去 / 失敗: pendingDelete
///
/// リモート操作は await するがエラーは飲み込み、常にローカル操作の結果を返す。
/// リモートはオプショナル。未設定時はローカルのみで動作し、後から [setRemote] で追加可能。
///
/// 例:
/// ```dart
/// final syncProvider = SyncStorageProvider(
///   scheme: 'synced',
///   local: fileProvider,
///   remote: firebaseProvider,
///   metadataStore: JsonSyncMetadataStore(filePath: '...'),
/// );
/// storage.registerProvider(syncProvider);
/// ```
class SyncStorageProvider extends XStorageProvider
    with FileProviderMixin, SyncProviderMixin {
  @override
  final String scheme;

  final FileStorageProvider _local;
  XStorageProvider? _remote;
  final SyncMetadataStore _metadataStore;

  SyncStorageProvider({
    required this.scheme,
    required FileStorageProvider local,
    XStorageProvider? remote,
    required SyncMetadataStore metadataStore,
  })  : _local = local,
        _remote = remote,
        _metadataStore = metadataStore;

  // --- remote management ---

  bool get hasRemote => _remote != null;

  /// リモートプロバイダーを設定・差し替える
  ///
  /// [resetStatus] が true（デフォルト）の場合:
  /// - `synced` → `localOnly`（新リモートにはまだデータがない）
  /// - `pendingDelete` → メタデータ除去（ローカルも消えてるので不要）
  /// - `pendingUpload` → そのまま（アップロードが必要な事実は変わらない）
  Future<void> setRemote(XStorageProvider remote,
      {bool resetStatus = true}) async {
    _remote = remote;

    if (!resetStatus) return;

    final synced = await _metadataStore.getByStatus(SyncStatus.synced);
    for (final uri in synced) {
      await _metadataStore.setStatus(uri, SyncStatus.localOnly);
    }

    final pendingDeletes =
        await _metadataStore.getByStatus(SyncStatus.pendingDelete);
    for (final uri in pendingDeletes) {
      await _metadataStore.remove(uri);
    }
  }

  /// `localOnly` + `pendingUpload` のファイルをすべてリモートにアップロード。
  /// 戻り値 = 失敗数。リモート未設定時は 0 を返す。
  Future<int> syncAll() async {
    final remote = _remote;
    if (remote == null) return 0;

    int failCount = 0;

    final targets = [
      ...await _metadataStore.getByStatus(SyncStatus.localOnly),
      ...await _metadataStore.getByStatus(SyncStatus.pendingUpload),
    ];

    for (final uri in targets) {
      final localData = await _local.loadFile(_localUri(uri));
      if (localData.isFailure) {
        failCount++;
        continue;
      }
      final result =
          await remote.saveFile(_remoteUri(uri, remote), localData.success);
      if (result.isSuccess) {
        await _metadataStore.setStatus(uri, SyncStatus.synced);
      } else {
        failCount++;
      }
    }

    return failCount;
  }

  // --- URI変換 ---

  XUri _localUri(XUri uri) => uri.changeScheme(_local.scheme);
  XUri _remoteUri(XUri uri, XStorageProvider remote) =>
      uri.changeScheme(remote.scheme);

  // --- XStorageProvider ---

  @override
  Future<Result<void, XStorageException>> saveFile(
      XUri uri, Uint8List data) async {
    // ローカルに保存
    final localResult = await _local.saveFile(_localUri(uri), data);
    if (localResult.isFailure) return localResult;

    final remote = _remote;
    if (remote == null) {
      await _metadataStore.setStatus(uri, SyncStatus.localOnly);
      return localResult;
    }

    // リモートに試行
    final remoteUri = _remoteUri(uri, remote);
    debugPrint('[SyncStorage] Uploading to remote: $remoteUri');
    final remoteResult = await remote.saveFile(remoteUri, data);
    if (remoteResult.isSuccess) {
      debugPrint('[SyncStorage] Remote upload success: $uri');
      await _metadataStore.setStatus(uri, SyncStatus.synced);
    } else {
      final failure = remoteResult.failure;
      debugPrint(
          '[SyncStorage] Remote upload failed: $failure (${failure.runtimeType})');
      await _metadataStore.setStatus(uri, SyncStatus.pendingUpload);
    }

    // 常に成功を返す（ローカル保存は成功している）
    return localResult;
  }

  @override
  Future<Result<Uint8List, XStorageException>> loadFile(XUri uri) async {
    // 1. ローカルから読み込み
    final localResult = await _local.loadFile(_localUri(uri));
    if (localResult.isSuccess) return localResult;

    // 2. リモート未設定ならローカル結果をそのまま返す
    final remote = _remote;
    if (remote == null) return localResult;

    // 3. ローカルになければリモートから取得
    final remoteResult = await remote.loadFile(_remoteUri(uri, remote));
    if (remoteResult.isFailure) return remoteResult;

    // 4. リモートから取得成功 → ローカルに保存
    final data = remoteResult.success;
    await _local.saveFile(_localUri(uri), data);
    await _metadataStore.setStatus(uri, SyncStatus.synced);

    return remoteResult;
  }

  @override
  Future<Result<void, XStorageException>> deleteFile(XUri uri) async {
    // ローカルを削除
    final localResult = await _local.deleteFile(_localUri(uri));

    final remote = _remote;
    if (remote == null) {
      await _metadataStore.remove(uri);
      return localResult;
    }

    // リモートを試行
    final remoteResult = await remote.deleteFile(_remoteUri(uri, remote));
    if (remoteResult.isSuccess) {
      await _metadataStore.remove(uri);
    } else {
      await _metadataStore.setStatus(uri, SyncStatus.pendingDelete);
    }

    return localResult;
  }

  @override
  Future<bool> exists(XUri uri) async {
    // ローカル確認
    if (await _local.exists(_localUri(uri))) return true;
    // リモート未設定ならfalse
    final remote = _remote;
    if (remote == null) return false;
    // なければリモート確認
    return await remote.exists(_remoteUri(uri, remote));
  }

  // --- FileProviderMixin ---

  @override
  Future<String> getFilePath(XUri uri) => _local.getFilePath(_localUri(uri));

  /// 指定ステータスのファイル URI 一覧を取得
  Future<List<XUri>> getByStatus(SyncStatus status) =>
      _metadataStore.getByStatus(status);

  // --- SyncProviderMixin ---

  @override
  Future<int> get pendingCount async {
    final uploadCount =
        await _metadataStore.countByStatus(SyncStatus.pendingUpload);
    final deleteCount =
        await _metadataStore.countByStatus(SyncStatus.pendingDelete);
    return uploadCount + deleteCount;
  }

  @override
  Future<SyncStatus?> getSyncStatus(XUri uri) => _metadataStore.getStatus(uri);

  @override
  Future<int> syncPending() async {
    final remote = _remote;
    if (remote == null) return 0;

    int failCount = 0;

    // pendingUpload を処理
    final pendingUploads =
        await _metadataStore.getByStatus(SyncStatus.pendingUpload);
    for (final uri in pendingUploads) {
      final localUri = _localUri(uri);
      final localData = await _local.loadFile(localUri);
      if (localData.isFailure) {
        debugPrint(
            '[SyncStorage] syncPending: local load failed for $localUri (${localData.failure})');
        failCount++;
        continue;
      }
      final remoteUri = _remoteUri(uri, remote);
      debugPrint(
          '[SyncStorage] syncPending: uploading $remoteUri (${localData.success.lengthInBytes} bytes)');
      final result = await remote.saveFile(remoteUri, localData.success);
      if (result.isSuccess) {
        debugPrint('[SyncStorage] syncPending: upload success $uri');
        await _metadataStore.setStatus(uri, SyncStatus.synced);
      } else {
        debugPrint(
            '[SyncStorage] syncPending: upload failed $uri (${result.failure})');
        failCount++;
      }
    }

    // pendingDelete を処理
    final pendingDeletes =
        await _metadataStore.getByStatus(SyncStatus.pendingDelete);
    for (final uri in pendingDeletes) {
      final result = await remote.deleteFile(_remoteUri(uri, remote));
      if (result.isSuccess) {
        await _metadataStore.remove(uri);
      } else {
        failCount++;
      }
    }

    return failCount;
  }

  @override
  Future<void> verifyAll() async {
    final remote = _remote;
    if (remote == null) return;

    final allUris = await _metadataStore.getAll();
    for (final uri in allUris) {
      await verifyStatus(uri);
    }
  }

  @override
  Future<SyncStatus> verifyStatus(XUri uri) async {
    final remote = _remote;
    if (remote == null) return SyncStatus.localOnly;

    final remoteExists = await remote.exists(_remoteUri(uri, remote));
    final currentStatus = await _metadataStore.getStatus(uri);

    if (currentStatus == SyncStatus.synced && !remoteExists) {
      await _metadataStore.setStatus(uri, SyncStatus.localOnly);
      return SyncStatus.localOnly;
    }

    if (currentStatus == SyncStatus.localOnly && remoteExists) {
      await _metadataStore.setStatus(uri, SyncStatus.synced);
      return SyncStatus.synced;
    }

    return currentStatus ?? SyncStatus.localOnly;
  }

  @override
  Future<void> removeFromRemote(XUri uri) async {
    final remote = _remote;
    if (remote == null) return;

    await remote.deleteFile(_remoteUri(uri, remote));
    await _metadataStore.setStatus(uri, SyncStatus.localOnly);
  }

  @override
  Future<Result<void, XStorageException>> uploadToRemote(XUri uri) async {
    final remote = _remote;
    if (remote == null) {
      return Result.failure(
        UnsupportedOperationException('remote is not set'),
      );
    }

    final localData = await _local.loadFile(_localUri(uri));
    if (localData.isFailure) return Result.failure(localData.failure);

    final result =
        await remote.saveFile(_remoteUri(uri, remote), localData.success);
    if (result.isSuccess) {
      await _metadataStore.setStatus(uri, SyncStatus.synced);
    }
    return result;
  }
}
