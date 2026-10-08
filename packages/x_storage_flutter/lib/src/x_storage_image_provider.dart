import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:x_storage_core/x_storage_core.dart';

/// XStorage の画像を [ImageProvider] として読む。
///
/// どのプロバイダでも [XStorage.loadFile] を通して読むので、
/// `CachingStorageProvider` で包んだネットワークの画像は、初めて表示したときに
/// 端末のキャッシュへ保存され、次の起動からはキャッシュから出る。
///
/// [DecorationImage] の背景や、[Image] の `frameBuilder` / `errorBuilder`
/// （読み込み中の表示・フェード・失敗時の代わり）と組み合わせて使う。
/// 先に読んでおくには `precacheImage(provider, context)` を使う。
///
/// 例:
/// ```dart
/// DecoratedBox(
///   decoration: BoxDecoration(
///     image: DecorationImage(
///       image: XStorageImageProvider(uri, xStorage),
///       fit: BoxFit.cover,
///     ),
///   ),
/// );
/// ```
@immutable
class XStorageImageProvider extends ImageProvider<XStorageImageProvider> {
  const XStorageImageProvider(this.uri, this.xStorage, {this.scale = 1.0});

  final XUri uri;
  final XStorage xStorage;
  final double scale;

  @override
  Future<XStorageImageProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<XStorageImageProvider>(this);

  @override
  ImageStreamCompleter loadImage(
    XStorageImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _load(decode),
      scale: key.scale,
      debugLabel: '$uri',
      informationCollector: () => [
        DiagnosticsProperty<XStorageImageProvider>('Image provider', this),
      ],
    );
  }

  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    final result = await xStorage.loadFile(uri);
    if (result.isFailure) {
      // 失敗は画像キャッシュに残さない（次に表示するときに読み直す）。
      scheduleMicrotask(() {
        PaintingBinding.instance.imageCache.evict(this);
      });
      throw XStorageImageLoadException(uri, result.failure);
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(result.success);
    return decode(buffer);
  }

  @override
  bool operator ==(Object other) =>
      other is XStorageImageProvider &&
      other.uri == uri &&
      identical(other.xStorage, xStorage) &&
      other.scale == scale;

  @override
  int get hashCode => Object.hash(uri, identityHashCode(xStorage), scale);

  @override
  String toString() =>
      '${objectRuntimeType(this, 'XStorageImageProvider')}("$uri", scale: $scale)';
}

/// [XStorageImageProvider] が画像を読めなかった。
class XStorageImageLoadException implements Exception {
  const XStorageImageLoadException(this.uri, this.cause);

  final XUri uri;
  final XStorageException cause;

  @override
  String toString() => 'XStorageImageLoadException($uri, $cause)';
}
