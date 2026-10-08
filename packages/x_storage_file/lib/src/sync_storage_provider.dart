import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:type_result/type_result.dart';
import 'package:x_storage_core/x_storage_core.dart';

import 'file_storage_provider.dart';
import 'sync_metadata_store.dart';

/// Local writes finish after durable local data and sync intent are stored.
/// Network operations run separately through syncPending/syncAll. Applications
/// should call those methods again on startup, resume and connectivity recovery.
class SyncStorageProvider extends XStorageProvider
    with FileProviderMixin, SyncProviderMixin {
  @override
  final String scheme;

  final FileStorageProvider _local;
  XStorageProvider? _remote;
  final SyncMetadataStore _metadataStore;
  Future<void> _localTail = Future.value();
  Future<void> _remoteTail = Future.value();
  final Map<String, int> _revisions = {};
  int _remoteGeneration = 0;
  bool _syncScheduled = false;

  Future<T> _locally<T>(Future<T> Function() action) {
    final result = _localTail.then((_) => action());
    _localTail =
        result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<T> _remotely<T>(Future<T> Function() action) {
    final result = _remoteTail.then((_) => action());
    _remoteTail =
        result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  void _scheduleSync() {
    if (_remote == null || _syncScheduled) return;
    _syncScheduled = true;
    unawaited(Future<void>(() async {
      _syncScheduled = false;
      try {
        await syncPending();
      } catch (error) {
        debugPrint('[SyncStorage] Deferred sync failed: $error');
      }
    }));
  }

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

  /// 同期OFF時にリモートを外す。以後の保存はローカルのみ（localOnly）になる。
  void clearRemote() {
    _remoteGeneration++;
    _remote = null;
  }

  /// リモートプロバイダーを設定・差し替える
  ///
  /// [resetStatus] が true（デフォルト）の場合:
  /// - `synced` → `localOnly`（新リモートにはまだデータがない）
  /// - `pendingDelete` → メタデータ除去（ローカルも消えてるので不要）
  /// - `pendingUpload` → そのまま（アップロードが必要な事実は変わらない）
  Future<void> setRemote(XStorageProvider remote,
      {bool resetStatus = true}) async {
    _remoteGeneration++;
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
  Future<int> syncAll() => _remotely(() => _sync(includeLocalOnly: true));

  // --- URI変換 ---

  XUri _localUri(XUri uri) => uri.changeScheme(_local.scheme);
  XUri _remoteUri(XUri uri, XStorageProvider remote) =>
      uri.changeScheme(remote.scheme);

  // --- XStorageProvider ---

  @override
  Future<Result<void, XStorageException>> saveFile(
      XUri uri, Uint8List data) async {
    try {
      final result = await _locally(() async {
        _revisions.update(uri.toString(), (v) => v + 1, ifAbsent: () => 1);
        // Write intent first. If the process dies after the atomic file write,
        // a fresh provider can still discover the file without an app job.
        await _metadataStore.setStatus(uri,
            _remote == null ? SyncStatus.localOnly : SyncStatus.pendingUpload);
        return _local.saveFile(_localUri(uri), data);
      });
      if (result.isSuccess) _scheduleSync();
      return result;
    } catch (error) {
      return Result.failure(UnknownException(error));
    }
  }

  @override
  Future<Result<Uint8List, XStorageException>> loadFile(XUri uri) async {
    final local = await _locally(() async {
      if (await _metadataStore.getStatus(uri) == SyncStatus.pendingDelete) {
        return Result<Uint8List, XStorageException>.failure(
            FileNotFoundException(uri));
      }
      return _local.loadFile(_localUri(uri));
    });
    if (local.isSuccess) return local;
    final remote = _remote;
    final generation = _remoteGeneration;
    if (remote == null ||
        await _metadataStore.getStatus(uri) == SyncStatus.pendingDelete) {
      return local;
    }
    final downloaded = await remote.loadFile(_remoteUri(uri, remote));
    if (downloaded.isFailure) return downloaded;
    return _locally(() async {
      // A local edit/deletion that happened during download always wins.
      if (await _metadataStore.getStatus(uri) == SyncStatus.pendingDelete ||
          generation != _remoteGeneration) {
        return Result<Uint8List, XStorageException>.failure(
            FileNotFoundException(uri));
      }
      final latest = await _local.loadFile(_localUri(uri));
      if (latest.isSuccess) return latest;
      final saved = await _local.saveFile(_localUri(uri), downloaded.success);
      if (saved.isSuccess) {
        await _metadataStore.setStatus(uri, SyncStatus.synced);
      }
      return downloaded;
    });
  }

  @override
  Future<Result<void, XStorageException>> deleteFile(XUri uri) async {
    try {
      final result = await _locally(() async {
        _revisions.update(uri.toString(), (v) => v + 1, ifAbsent: () => 1);
        await _metadataStore.setStatus(uri, SyncStatus.pendingDelete);
        final result = await _local.deleteFile(_localUri(uri));
        if (result.isSuccess && _remote == null) {
          await _metadataStore.remove(uri);
        }
        return result;
      });
      if (result.isSuccess) _scheduleSync();
      return result;
    } catch (error) {
      return Result.failure(UnknownException(error));
    }
  }

  @override
  Future<bool> exists(XUri uri) async {
    if (await _metadataStore.getStatus(uri) == SyncStatus.pendingDelete) {
      return false;
    }
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
  Future<int> syncPending() => _remotely(() => _sync(includeLocalOnly: false));

  Future<int> _sync({required bool includeLocalOnly}) async {
    final targets = await _locally(() async => [
          ...await _metadataStore.getByStatus(SyncStatus.pendingUpload),
          ...await _metadataStore.getByStatus(SyncStatus.pendingDelete),
          if (includeLocalOnly)
            ...await _metadataStore.getByStatus(SyncStatus.localOnly),
        ]);
    var failures = 0;
    for (final uri in targets.toSet()) {
      if (_remote == null) break;
      if ((await _transfer(uri)).isFailure) failures++;
    }
    return failures;
  }

  Future<Result<void, XStorageException>> _transfer(XUri uri) async {
    try {
      final remote = _remote;
      if (remote == null) {
        return Result.failure(
            UnsupportedOperationException('remote is not set'));
      }
      final generation = _remoteGeneration;
      final snapshot = await _locally(() async {
        final status = await _metadataStore.getStatus(uri);
        final revision = _revisions[uri.toString()] ?? 0;
        if (status == SyncStatus.pendingDelete) {
          final removed = await _local.deleteFile(_localUri(uri));
          if (removed.isFailure) throw removed.failure;
          return (status: status, revision: revision, data: null as Uint8List?);
        }
        final data = await _local.loadFile(_localUri(uri));
        if (data.isFailure) throw data.failure;
        // Explicit upload also needs durable intent before any network call.
        await _metadataStore.setStatus(uri, SyncStatus.pendingUpload);
        return (
          status: SyncStatus.pendingUpload,
          revision: revision,
          data: data.success as Uint8List?
        );
      });
      if (_remoteGeneration != generation) {
        return Result.failure(UnsupportedOperationException('remote changed'));
      }
      final result = snapshot.status == SyncStatus.pendingDelete
          ? await remote.deleteFile(_remoteUri(uri, remote))
          : await remote.saveFile(_remoteUri(uri, remote), snapshot.data!);
      if (result.isSuccess) {
        await _locally(() async {
          if (_remoteGeneration != generation ||
              (_revisions[uri.toString()] ?? 0) != snapshot.revision) {
            return;
          }
          if (snapshot.status == SyncStatus.pendingDelete) {
            await _metadataStore.remove(uri);
          } else {
            await _metadataStore.setStatus(uri, SyncStatus.synced);
          }
        });
      }
      return result;
    } catch (error) {
      return Result.failure(UnknownException(error));
    }
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

    bool remoteExists;
    try {
      remoteExists = await remote.exists(_remoteUri(uri, remote));
    } catch (_) {
      // サーバー状態が不明（オフライン等）なので、ステータスを変更せずそのまま返す
      return await _metadataStore.getStatus(uri) ?? SyncStatus.localOnly;
    }
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
  Future<Result<void, XStorageException>> uploadToRemote(XUri uri) =>
      _remotely(() => _transfer(uri));
}
