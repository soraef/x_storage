import 'x_storage_provider.dart';
import 'x_uri.dart';

/// キャッシュ機能を持つプロバイダーのインターフェース
///
/// [NetworkProviderMixin] と組み合わせて使用し、ネットワークファイルの
/// ローカルキャッシュを自動的に管理する。
mixin CachingProviderMixin on XStorageProvider {
  /// 指定URIのファイルがキャッシュ済みか確認
  Future<bool> isCached(XUri uri);

  /// キャッシュされたファイルのローカルパスを取得
  ///
  /// キャッシュが存在しない場合はnullを返す。
  Future<String?> getCachedFilePath(XUri uri);

  /// 個別のキャッシュを削除
  Future<void> removeCache(XUri uri);

  /// 特定パス配下のキャッシュを一括削除
  ///
  /// [pathPrefix] に前方一致するパスのキャッシュをすべて削除する。
  /// 例: `removeCacheByPrefix('/images/')` で `/images/` 配下を全削除。
  Future<void> removeCacheByPrefix(String pathPrefix);

  /// このプロバイダーの全キャッシュを削除
  Future<void> clearCache();
}
