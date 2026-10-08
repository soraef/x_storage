import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:type_result/type_result.dart';
import 'package:x_storage_core/x_storage_core.dart';
import 'package:x_storage_flutter/x_storage_flutter.dart';

/// 1x1 の PNG を dart:ui で作る。
Future<Uint8List> _png() async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
      const Rect.fromLTWH(0, 0, 1, 1), Paint()..color = const Color(0xFFFF0000));
  final image = await recorder.endRecording().toImage(1, 1);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

/// メモリ上の読み取り専用プロバイダ。読んだ回数を数える。
class _MemoryProvider extends XStorageProvider with NetworkProviderMixin {
  _MemoryProvider(this.files);

  final Map<String, Uint8List> files;
  int loads = 0;

  @override
  String get scheme => 'mem';

  @override
  String get rootUrl => 'https://mem.example';

  @override
  Future<Result<Uint8List, XStorageException>> loadFile(XUri uri) async {
    loads++;
    final data = files[uri.path];
    return data == null
        ? Result.failure(FileNotFoundException(uri))
        : Result.success(data);
  }

  @override
  Future<Result<void, XStorageException>> saveFile(
          XUri uri, Uint8List data) async =>
      Result.failure(UnsupportedOperationException('read-only'));

  @override
  Future<Result<void, XStorageException>> deleteFile(XUri uri) async =>
      Result.failure(UnsupportedOperationException('read-only'));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MemoryProvider provider;
  late XStorage storage;

  late Uint8List png;
  setUpAll(() async => png = await _png());

  setUp(() {
    PaintingBinding.instance.imageCache.clear();
    provider = _MemoryProvider({'/bg/cafe.png': png});
    storage = XStorage()..registerProvider(provider);
  });

  Future<Object> resolve(ImageProvider image) async {
    final completer = Completer<Object>();
    image.resolve(ImageConfiguration.empty).addListener(ImageStreamListener(
          (info, _) => completer.complete(info),
          onError: (error, _) => completer.complete(error),
        ));
    return completer.future;
  }

  testWidgets('decodes bytes loaded through XStorage and reuses the cache',
      (tester) async {
    await tester.runAsync(() async {
      final image = XStorageImageProvider(
          XUri.create('mem', 'bg/cafe.png'), storage);
      final info = await resolve(image) as ImageInfo;
      expect(info.image.width, 1);
      // 同じ URI・同じ XStorage なら同じキーで、読み直さない。
      await resolve(XStorageImageProvider(
          XUri.create('mem', 'bg/cafe.png'), storage));
      expect(provider.loads, 1);
    });
  });

  testWidgets('a failed load reports an error and is retried next time',
      (tester) async {
    await tester.runAsync(() async {
      final image =
          XStorageImageProvider(XUri.create('mem', 'bg/missing.png'), storage);
      final error = await resolve(image);
      expect(error, isA<XStorageImageLoadException>());
      expect((error as XStorageImageLoadException).cause,
          isA<FileNotFoundException>());
      await Future<void>.delayed(Duration.zero);
      await resolve(image);
      expect(provider.loads, 2);
    });
  });

  test('keys differ by uri, storage and scale', () {
    final uri = XUri.create('mem', 'bg/cafe.png');
    expect(XStorageImageProvider(uri, storage),
        XStorageImageProvider(uri, storage));
    expect(XStorageImageProvider(uri, storage) == XStorageImageProvider(uri, XStorage()),
        isFalse);
    expect(
        XStorageImageProvider(uri, storage) ==
            XStorageImageProvider(uri, storage, scale: 2),
        isFalse);
  });
}
