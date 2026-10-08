import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:x_storage_core/x_storage_core.dart';

void main() {
  final requested = <String>[];
  final client = MockClient((request) async {
    requested.add('${request.method} ${request.url}');
    if (request.url.path == '/backgrounds/cafe.webp') {
      return http.Response.bytes([1, 2, 3], 200,
          headers: {'content-type': 'image/webp', 'content-length': '3'});
    }
    if (request.url.path == '/broken.webp') {
      return http.Response('oops', 500);
    }
    return http.Response('', 404);
  });

  PublicUrlStorageProvider provider({String root = 'https://cdn.example/'}) =>
      PublicUrlStorageProvider(scheme: 'cdn', rootUrl: root, client: client);

  setUp(requested.clear);

  test('loads bytes from rootUrl + path through XStorage', () async {
    final storage = XStorage()..registerProvider(provider());
    final result =
        await storage.loadFile(XUri.create('cdn', 'backgrounds/cafe.webp'));
    expect(result.success, Uint8List.fromList([1, 2, 3]));
    expect(requested, ['GET https://cdn.example/backgrounds/cafe.webp']);
    expect(storage.getStorageType(XUri.create('cdn', 'x.webp')),
        XStorageType.network);
  });

  test('404 is FileNotFound, other errors are Unknown', () async {
    final p = provider();
    expect((await p.loadFile(XUri.create('cdn', 'missing.webp'))).failure,
        isA<FileNotFoundException>());
    expect((await p.loadFile(XUri.create('cdn', 'broken.webp'))).failure,
        isA<UnknownException>());
  });

  test('exists uses HEAD', () async {
    final p = provider(root: 'https://cdn.example');
    expect(await p.exists(XUri.create('cdn', 'backgrounds/cafe.webp')), isTrue);
    expect(await p.exists(XUri.create('cdn', 'missing.webp')), isFalse);
    expect(requested.first, 'HEAD https://cdn.example/backgrounds/cafe.webp');
  });

  test('head reads size and type without downloading', () async {
    final p = provider();
    final head = await p.head(XUri.create('cdn', 'backgrounds/cafe.webp'));
    expect(head.success.size, 3);
    expect(head.success.contentType, 'image/webp');
    expect((await p.head(XUri.create('cdn', 'missing.webp'))).failure,
        isA<FileNotFoundException>());
    expect(requested.every((r) => r.startsWith('HEAD ')), isTrue);
  });

  test('save and delete are unsupported', () async {
    final p = provider();
    final uri = XUri.create('cdn', 'a.webp');
    expect((await p.saveFile(uri, Uint8List(0))).failure,
        isA<UnsupportedOperationException>());
    expect((await p.deleteFile(uri)).failure,
        isA<UnsupportedOperationException>());
    expect(requested, isEmpty);
  });
}
