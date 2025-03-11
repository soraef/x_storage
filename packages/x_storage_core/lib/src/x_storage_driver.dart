import 'dart:typed_data';
import 'x_storage_type.dart';
import 'x_storage_uri.dart';

/// Abstract base class for storage drivers
///
/// This class defines the interface that all storage drivers must implement.
/// Each driver represents a specific storage type (e.g., asset, file, network)
/// and provides implementations for basic file operations.
abstract class XStorageDriver {
  /// The scheme for this driver (e.g., "asset", "file", "firebase", "s3")
  ///
  /// This scheme is used to identify which driver should handle a specific URI.
  String get scheme;

  /// Saves data to the specified URI
  Future<void> saveFile(XStorageUri uri, Uint8List data);

  /// Loads data from the specified URI
  ///
  /// Returns null if the file doesn't exist.
  Future<Uint8List?> loadFile(XStorageUri uri);

  /// Deletes the file at the specified URI
  Future<void> deleteFile(XStorageUri uri);

  /// Checks if a file exists at the specified URI
  ///
  /// Default implementation checks if [loadFile] returns non-null data.
  Future<bool> exists(XStorageUri uri) async {
    return await loadFile(uri).then((value) => value != null);
  }

  /// Gets the storage type for this driver
  XStorageType get storageType;

  /// Helper method to create a URI for this driver
  ///
  /// Creates a [XStorageUri] using this driver's scheme and the provided path.
  XStorageUri getUri(String path) {
    return XStorageUri.create(scheme, path);
  }
}

/// Mixin for asset-based storage drivers
///
/// Provides common functionality for handling asset storage.
mixin AssetXStorageMixin on XStorageDriver {
  /// Converts a URI to an asset name
  String assetName(XStorageUri uri) {
    return uri.path;
  }

  @override
  XStorageType get storageType => XStorageType.asset;
}

/// Mixin for network-based storage drivers
///
/// Provides common functionality for handling network storage,
/// including URL generation and type identification.
mixin NetworkXStorageMixin on XStorageDriver {
  /// The root URL for the storage service (e.g., "https://example.com")
  String get rootUrl;

  /// Converts a storage URI to a network URL
  ///
  /// Combines the [rootUrl] with the URI path to create a complete network URL.
  /// Handles trailing slashes in the root URL appropriately.
  Future<Uri> getNetworkUrl(XStorageUri uri) async {
    final root = rootUrl.endsWith("/")
        ? rootUrl.substring(0, rootUrl.length - 1)
        : rootUrl;
    return Uri.parse("$root${uri.path}");
  }

  @override
  XStorageType get storageType => XStorageType.network;
}

/// Mixin for file system-based storage drivers
///
/// Provides common functionality for handling file system storage.
mixin FileXStorageMixin on XStorageDriver {
  @override
  XStorageType get storageType => XStorageType.file;

  Future<String> getFilePath(XStorageUri uri);
}
