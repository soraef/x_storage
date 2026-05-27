import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:x_storage_core/x_storage_core.dart';

/// Resolved image data cached by [XStorageImage].
class _ResolvedImage {
  final XStorageType storageType;
  final File? file;
  final Uri? networkUri;
  final String? assetPath;

  _ResolvedImage({
    required this.storageType,
    this.file,
    this.networkUri,
    this.assetPath,
  });
}

/// A widget that automatically detects and displays images from XStorage (Asset/Network/File/Other)
///
/// Resolved image paths are cached in a static map so that subsequent
/// creations with the same URI can display the image synchronously.
/// Call [XStorageImage.preload] to warm the cache ahead of time.
class XStorageImage extends StatefulWidget {
  /// The URI of the image in XStorage
  final XUri uri;

  /// The XStorage instance to use for loading the image
  final XStorage xStorage;

  /// The width of the image
  final double? width;

  /// The height of the image
  final double? height;

  /// How to inscribe the image into the space allocated during layout
  final BoxFit? fit;

  /// How to align the image within its bounds.
  final AlignmentGeometry alignment;

  /// Static cache of resolved image data keyed by URI.
  static final Map<Uri, _ResolvedImage> _cache = {};

  const XStorageImage({
    super.key,
    required this.uri,
    required this.xStorage,
    this.width,
    this.height,
    this.fit,
    this.alignment = Alignment.center,
  });

  /// Pre-resolves the given URIs so that subsequent [XStorageImage] widgets
  /// using the same URIs can display immediately without async loading.
  static Future<void> preload(List<XUri> uris, XStorage xStorage) async {
    await Future.wait(uris.map((uri) async {
      if (_cache.containsKey(uri)) return;
      final resolved = await _resolve(uri, xStorage);
      _cache[uri] = resolved;

      // Flutter の画像キャッシュにもデコード済みデータを入れる
      final imageProvider = _imageProviderFrom(resolved);
      if (imageProvider != null) {
        await _precacheImageProvider(imageProvider);
      }
    }));
  }

  static ImageProvider? _imageProviderFrom(_ResolvedImage resolved) {
    switch (resolved.storageType) {
      case XStorageType.asset:
        if (resolved.assetPath != null) {
          return AssetImage(resolved.assetPath!);
        }
        return null;
      case XStorageType.network:
        if (resolved.networkUri != null) {
          return NetworkImage(resolved.networkUri.toString());
        }
        return null;
      case XStorageType.file:
      case XStorageType.other:
        if (resolved.file != null) {
          return FileImage(resolved.file!);
        }
        return null;
    }
  }

  static Future<void> _precacheImageProvider(ImageProvider provider) {
    final completer = Completer<void>();
    final stream = provider.resolve(ImageConfiguration.empty);
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (_, __) {
        completer.complete();
        stream.removeListener(listener);
      },
      onError: (_, __) {
        completer.complete();
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
    return completer.future;
  }

  /// Clears the resolved image cache.
  static void clearCache() {
    _cache.clear();
  }

  /// Resolves a URI to image data using XStorage.
  static Future<_ResolvedImage> _resolve(XUri uri, XStorage xStorage) async {
    // キャッシュ済みの場合はローカルファイルとして表示
    final providerResult = xStorage.getProvider(uri);
    if (providerResult.isSuccess) {
      final provider = providerResult.success;
      if (provider is CachingProviderMixin) {
        final cachedPath = await provider.getCachedFilePath(uri);
        if (cachedPath != null) {
          return _ResolvedImage(
            storageType: XStorageType.file,
            file: File(cachedPath),
          );
        }
      }
    }

    final storageType = xStorage.getStorageType(uri);

    switch (storageType) {
      case XStorageType.asset:
        final providerResult = xStorage.getProvider(uri);
        if (providerResult.isFailure) {
          throw Exception('Unsupported storage driver for asset');
        }
        final provider = providerResult.success as AssetProviderMixin;
        return _ResolvedImage(
          storageType: storageType,
          assetPath: provider.assetName(uri),
        );

      case XStorageType.network:
        final providerResult = xStorage.getProvider(uri);
        if (providerResult.isFailure) {
          throw Exception('Unsupported storage driver for network');
        }
        final provider = providerResult.success as NetworkProviderMixin;
        final networkUri = await provider.getNetworkUrl(uri);
        return _ResolvedImage(
          storageType: storageType,
          networkUri: networkUri,
        );

      case XStorageType.file:
        final xFileResult = await xStorage.loadXFile(uri);
        if (xFileResult.isSuccess) {
          return _ResolvedImage(
            storageType: storageType,
            file: File(xFileResult.success.path),
          );
        }
        return _ResolvedImage(storageType: storageType);

      case XStorageType.other:
        final xFileResult = await xStorage.loadXFile(uri);
        if (xFileResult.isSuccess) {
          return _ResolvedImage(
            storageType: storageType,
            file: File(xFileResult.success.path),
          );
        }
        return _ResolvedImage(storageType: storageType);
    }
  }

  @override
  State<XStorageImage> createState() => _XStorageImageState();
}

class _XStorageImageState extends State<XStorageImage> {
  _ResolvedImage? _resolved;

  @override
  void initState() {
    super.initState();

    // キャッシュヒットなら同期的に表示
    final cached = XStorageImage._cache[widget.uri];
    if (cached != null) {
      _resolved = cached;
      return;
    }

    // キャッシュミス: 非同期で解決してキャッシュに入れる
    XStorageImage._resolve(widget.uri, widget.xStorage).then((resolved) {
      XStorageImage._cache[widget.uri] = resolved;
      if (mounted) {
        setState(() {
          _resolved = resolved;
        });
      }
    });
  }

  @override
  void didUpdateWidget(XStorageImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uri == widget.uri) return;

    // キャッシュヒットなら同期的に差し替え（次フレームで新画像を表示）
    final cached = XStorageImage._cache[widget.uri];
    if (cached != null) {
      setState(() {
        _resolved = cached;
      });
      return;
    }

    // キャッシュミス: 新画像の解決が終わるまで、あえて _resolved を
    // クリアしない（前の画像を表示したまま）。これと build 側の
    // gaplessPlayback により、切り替え時のチラつきを防ぐ。
    XStorageImage._resolve(widget.uri, widget.xStorage).then((resolved) {
      XStorageImage._cache[widget.uri] = resolved;
      if (mounted) {
        setState(() {
          _resolved = resolved;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final resolved = _resolved;
    if (resolved == null) {
      return SizedBox(width: widget.width, height: widget.height);
    }

    switch (resolved.storageType) {
      case XStorageType.asset:
        return Image.asset(
          resolved.assetPath!,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          alignment: widget.alignment,
          gaplessPlayback: true,
          errorBuilder: (context, error, stack) => SizedBox(
            width: widget.width,
            height: widget.height,
          ),
        );

      case XStorageType.network:
        return Image.network(
          resolved.networkUri.toString(),
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          alignment: widget.alignment,
          gaplessPlayback: true,
          errorBuilder: (context, error, stack) => SizedBox(
            width: widget.width,
            height: widget.height,
          ),
        );

      case XStorageType.file:
        if (resolved.file == null) {
          return SizedBox(width: widget.width, height: widget.height);
        }
        return Image.file(
          resolved.file!,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          alignment: widget.alignment,
          gaplessPlayback: true,
          errorBuilder: (context, error, stack) => SizedBox(
            width: widget.width,
            height: widget.height,
          ),
        );

      case XStorageType.other:
        if (resolved.file == null) {
          return SizedBox(width: widget.width, height: widget.height);
        }
        return Image.file(
          resolved.file!,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          alignment: widget.alignment,
          gaplessPlayback: true,
          errorBuilder: (context, error, stack) => SizedBox(
            width: widget.width,
            height: widget.height,
          ),
        );
    }
  }
}
