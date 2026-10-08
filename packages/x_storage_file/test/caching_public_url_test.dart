import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:x_storage_core/x_storage_core.dart';
import 'package:x_storage_file/x_storage_file.dart';

class _TempPathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _TempPathProvider(this.path);
  final String path;

  @override
  Future<String?> getApplicationSupportPath() async => path;
}

/// 公開 URL のファイルを CachingStorageProvider で包むと、
/// 初回だけ HTTP で読み、以降は端末のキャッシュから読む。
void main() {
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('xstorage-public-');
    PathProviderPlatform.instance = _TempPathProvider(root.path);
  });
  tearDown(() async {
    await root.delete(recursive: true);
  });

  test('first load fetches over HTTP, later loads come from the disk cache',
      () async {
    var gets = 0;
    final client = MockClient((request) async {
      gets++;
      return http.Response.bytes([7, 8, 9], 200);
    });
    CachingStorageProvider cached() => CachingStorageProvider(
          delegate: PublicUrlStorageProvider(
              scheme: 'cdn', rootUrl: 'https://cdn.example', client: client),
          cache: FileStorageProvider(),
        );
    final uri = XUri.create('cdn', 'backgrounds/cafe.webp');

    final first = cached();
    expect(await first.isCached(uri), isFalse);
    expect((await first.loadFile(uri)).success, Uint8List.fromList([7, 8, 9]));
    expect(await first.isCached(uri), isTrue);
    expect(await first.getCachedFilePath(uri), isNotNull);

    // 次の起動（新しいプロバイダ）でもネットワークに出ない。
    final second = cached();
    expect((await second.loadFile(uri)).success, Uint8List.fromList([7, 8, 9]));
    expect(gets, 1);
  });
}
