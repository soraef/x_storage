import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:x_storage_core/x_storage_core.dart';

/// A widget that automatically detects and displays images from XStorage (Asset/Network/File/Other)
///
/// Note: This is a simple implementation. Consider caching and redraw timing
/// based on your specific use case.
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

  const XStorageImage({
    super.key,
    required this.uri,
    required this.xStorage,
    this.width,
    this.height,
    this.fit,
  });

  @override
  State<XStorageImage> createState() => _XStorageImageState();
}

class _XStorageImageState extends State<XStorageImage> {
  late XStorageType storageType;
  bool isLoading = true;
  File? file;
  Uri? networkUri;
  String? assetPath;

  @override
  void initState() {
    super.initState();

    _load().then((_) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    });
  }

  Future<void> _load() async {
    storageType = widget.xStorage.getStorageType(widget.uri);

    switch (storageType) {
      case XStorageType.asset:
        final driver =
            widget.xStorage.getProvider(widget.uri) as AssetProviderMixin;
        assetPath = driver.assetName(widget.uri);
        break;

      case XStorageType.network:
        final driver =
            widget.xStorage.getProvider(widget.uri) as NetworkProviderMixin;
        networkUri = await driver.getNetworkUrl(widget.uri);
        break;

      case XStorageType.file:
        final xFileResult = await widget.xStorage.loadXFile(widget.uri);
        if (xFileResult.isSuccess) {
          file = File(xFileResult.success.path);
        }
        break;

      case XStorageType.other:
        final xFileResult = await widget.xStorage.loadXFile(widget.uri);
        if (xFileResult.isSuccess) {
          file = File(xFileResult.success.path);
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      // Return an empty space while loading
      return SizedBox(width: widget.width, height: widget.height);
    }

    switch (storageType) {
      case XStorageType.asset:
        return Image.asset(
          assetPath!,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          errorBuilder: (context, error, stack) => SizedBox(
            width: widget.width,
            height: widget.height,
          ),
        );

      case XStorageType.network:
        return Image.network(
          networkUri.toString(),
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          errorBuilder: (context, error, stack) => SizedBox(
            width: widget.width,
            height: widget.height,
          ),
        );

      case XStorageType.file:
        if (file == null) {
          return SizedBox(width: widget.width, height: widget.height);
        }
        return Image.file(
          file!,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          errorBuilder: (context, error, stack) => SizedBox(
            width: widget.width,
            height: widget.height,
          ),
        );

      case XStorageType.other:
        if (file == null) {
          return SizedBox(width: widget.width, height: widget.height);
        }
        return Image.file(
          file!,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          errorBuilder: (context, error, stack) => SizedBox(
            width: widget.width,
            height: widget.height,
          ),
        );
    }
  }
}
