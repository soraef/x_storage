import 'package:type_result/type_result.dart';

import 'x_storage_exception.dart';
import 'x_storage_provider.dart';
import 'x_uri.dart';

/// 同期ステータス
enum SyncStatus {
  /// ローカル・リモート両方にある
  synced,

  /// アップロード待ち（自動リトライ対象）
  pendingUpload,

  /// ローカルのみ（意図的削除 or 外部削除で検知済み）
  localOnly,

  /// リモート削除待ち
  pendingDelete,
}

/// ローカルが正、リモートがバックアップ/同期先となるプロバイダーのインターフェース
mixin SyncProviderMixin on XStorageProvider {
  /// 未同期（pendingUpload + pendingDelete）のファイル数
  Future<int> get pendingCount;

  /// 指定URIの同期ステータスを取得（未管理ならnull）
  Future<SyncStatus?> getSyncStatus(XUri uri);

  /// pendingUpload/pendingDelete を再試行。戻り値 = まだ失敗している数
  Future<int> syncPending();

  /// リモートの実態を確認してメタデータを更新
  /// 例: synced だがリモートに存在しない → localOnly に変更
  Future<SyncStatus> verifyStatus(XUri uri);

  /// リモートから意図的に削除（ローカルは残す）
  Future<void> removeFromRemote(XUri uri);

  /// localOnly のファイルをリモートに再アップロード
  Future<Result<void, XStorageException>> uploadToRemote(XUri uri);
}
