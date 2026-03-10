import 'dart:io';
import 'dart:typed_data';

import 'package:type_result/type_result.dart';
import 'package:x_storage_core/x_storage_core.dart';

import 'file_storage_provider.dart';

/// ネットワークプロバイダーのファイルをローカルに自動キャッシュするプロバイダー
///
/// [NetworkProviderMixin] を持つプロバイダーをラップし、
/// [FileStorageProvider] をキャッシュストレージとして使用する。
///
/// - `loadFile`: キャッシュがあればローカルから返し、なければネットワークから取得してキャッシュ
/// - `saveFile`: ネットワークに保存し、成功したらキャッシュにも保存
/// - `deleteFile`: ネットワークとキャッシュの両方から削除
///
/// 例:
/// ```dart
/// final cachedFirebase = CachingStorageProvider(
///   delegate: firebaseProvider,
///   cache: fileProvider,
/// );
/// storage.registerProvider(cachedFirebase);
///
/// // 自動でキャッシュされる
/// await storage.loadFile(XUri.create('firebase', 'images/photo.jpg'));
///
/// // キャッシュ管理
/// await cachedFirebase.removeCache(uri);
/// await cachedFirebase.clearCache();
/// ```
class CachingStorageProvider extends XStorageProvider
    with NetworkProviderMixin, CachingProviderMixin {
  final XStorageProvider _delegate;
  final FileStorageProvider _cache;

  CachingStorageProvider({
    required XStorageProvider delegate,
    required FileStorageProvider cache,
  })  : assert(delegate is NetworkProviderMixin,
            'delegate must implement NetworkProviderMixin'),
        _delegate = delegate,
        _cache = cache;

  NetworkProviderMixin get _networkDelegate =>
      _delegate as NetworkProviderMixin;

  @override
  String get scheme => _delegate.scheme;

  @override
  String get rootUrl => _networkDelegate.rootUrl;

  @override
  Future<Uri> getNetworkUrl(XUri uri) => _networkDelegate.getNetworkUrl(uri);

  XUri _cacheUri(XUri uri) => uri.changeScheme(_cache.scheme);

  // --- XStorageProvider ---

  @override
  Future<Result<Uint8List, XStorageException>> loadFile(XUri uri) async {
    // 1. キャッシュ確認
    final cacheUri = _cacheUri(uri);
    final cached = await _cache.loadFile(cacheUri);
    if (cached.isSuccess) return cached;

    // 2. ネットワークから取得
    final result = await _delegate.loadFile(uri);
    if (result.isSuccess) {
      // 3. キャッシュに保存
      await _cache.saveFile(cacheUri, result.success);
    }
    return result;
  }

  @override
  Future<Result<void, XStorageException>> saveFile(
      XUri uri, Uint8List data) async {
    // ネットワークに保存
    final result = await _delegate.saveFile(uri, data);
    if (result.isSuccess) {
      // キャッシュにも保存
      await _cache.saveFile(_cacheUri(uri), data);
    }
    return result;
  }

  @override
  Future<Result<void, XStorageException>> deleteFile(XUri uri) async {
    // キャッシュを削除
    await removeCache(uri);
    // ネットワークから削除
    return await _delegate.deleteFile(uri);
  }

  @override
  Future<bool> exists(XUri uri) async {
    // キャッシュにあればtrue
    if (await _cache.exists(_cacheUri(uri))) return true;
    // なければネットワークで確認
    return await _delegate.exists(uri);
  }

  // --- CachingProviderMixin ---

  @override
  Future<bool> isCached(XUri uri) async {
    return await _cache.exists(_cacheUri(uri));
  }

  @override
  Future<String?> getCachedFilePath(XUri uri) async {
    final cacheUri = _cacheUri(uri);
    if (await _cache.exists(cacheUri)) {
      return await _cache.getFilePath(cacheUri);
    }
    return null;
  }

  @override
  Future<void> removeCache(XUri uri) async {
    await _cache.deleteFile(_cacheUri(uri));
  }

  @override
  Future<void> removeCacheByPrefix(String pathPrefix) async {
    final dirPath = await _cache.getFilePath(
      XUri.create(_cache.scheme, pathPrefix),
    );
    final dir = Directory(dirPath);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  @override
  Future<void> clearCache() async {
    // schemeごとのルートディレクトリを削除
    // XUriのパスは"/"から始まるので、scheme:///で全体を指す
    await removeCacheByPrefix('/');
  }
}
