import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:type_result/type_result.dart';

import '../x_file_head.dart';
import '../x_storage_exception.dart';
import '../x_storage_provider.dart';
import '../x_uri.dart';

/// 公開 URL（認証なしの HTTP(S)）から読むためのプロバイダ
/// （書き込みや削除はサポートされない）
///
/// CDN やバケットの公開 URL（Cloudflare R2 の公開バケットなど）に置いた
/// ファイルを、`<scheme>:///path` → `<rootUrl>/path` として読む。
/// アップロードは配信とは別の経路（管理ツールなど）で行う前提。
///
/// 端末に残したいときは `CachingStorageProvider` で包む。
///
/// 例:
/// ```dart
/// storage.registerProvider(PublicUrlStorageProvider(
///   scheme: 'cdn',
///   rootUrl: 'https://pub-xxxx.r2.dev',
/// ));
///
/// // https://pub-xxxx.r2.dev/backgrounds/cafe.webp を読む
/// await storage.loadFile(XUri.create('cdn', 'backgrounds/cafe.webp'));
/// ```
class PublicUrlStorageProvider extends XStorageProvider
    with NetworkProviderMixin {
  PublicUrlStorageProvider({
    required this.scheme,
    required this.rootUrl,
    http.Client? client,
  }) : _client = client;

  @override
  final String scheme;

  @override
  final String rootUrl;

  final http.Client? _client;

  Future<http.Response> _get(Uri url) =>
      _client == null ? http.get(url) : _client.get(url);

  Future<http.Response> _head(Uri url) =>
      _client == null ? http.head(url) : _client.head(url);

  @override
  Future<Result<Uint8List, XStorageException>> loadFile(XUri uri) async {
    try {
      final response = await _get(await getNetworkUrl(uri));
      if (response.statusCode == 200) {
        return Result.success(response.bodyBytes);
      }
      if (response.statusCode == 404) {
        return Result.failure(FileNotFoundException(uri));
      }
      return Result.failure(
        UnknownException('HTTP ${response.statusCode} for $uri'),
      );
    } catch (e) {
      return Result.failure(UnknownException(e));
    }
  }

  @override
  Future<bool> exists(XUri uri) async {
    try {
      final response = await _head(await getNetworkUrl(uri));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<Result<XFileHead, XStorageException>> head(XUri uri) async {
    try {
      final response = await _head(await getNetworkUrl(uri));
      if (response.statusCode == 404) {
        return Result.failure(FileNotFoundException(uri));
      }
      if (response.statusCode != 200) {
        return Result.failure(
          UnknownException('HTTP ${response.statusCode} for $uri'),
        );
      }
      return Result.success(XFileHead(
        size: int.tryParse(response.headers['content-length'] ?? ''),
        contentType: response.headers['content-type'],
      ));
    } catch (e) {
      return Result.failure(UnknownException(e));
    }
  }

  @override
  Future<Result<void, XStorageException>> saveFile(
      XUri uri, Uint8List data) async {
    return Result.failure(
      UnsupportedOperationException('Public URLs are read-only'),
    );
  }

  @override
  Future<Result<void, XStorageException>> deleteFile(XUri uri) async {
    return Result.failure(
      UnsupportedOperationException('Public URLs are read-only'),
    );
  }
}
