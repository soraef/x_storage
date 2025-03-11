import 'dart:typed_data';
import 'package:type_result/type_result.dart';
import 'x_storage_exception.dart';
import 'x_storage_type.dart';
import 'x_uri.dart';
import 'x_storage.dart';

/// Abstract base class for storage providers
///
/// This class defines the interface that all storage providers must implement.
/// Each provider represents a specific storage type (e.g., asset, file, network)
/// and provides implementations for basic file operations.
abstract class XStorageProvider {
  /// The scheme for this provider (e.g., "asset", "file", "firebase", "s3")
  ///
  /// This scheme is used to identify which provider should handle a specific URI.
  String get scheme;

  /// Saves data to the specified URI
  Future<Result<void, XStorageException>> saveFile(XUri uri, Uint8List data);

  /// Loads data from the specified URI
  ///
  /// Returns Failure(FileNotFoundError) if the file doesn't exist.
  Future<Result<Uint8List, XStorageException>> loadFile(XUri uri);

  /// Deletes the file at the specified URI
  Future<Result<void, XStorageException>> deleteFile(XUri uri);

  /// Checks if a file exists at the specified URI
  ///
  /// Default implementation checks if [loadFile] returns Success.
  Future<bool> exists(XUri uri) async {
    final result = await loadFile(uri);
    return result.isSuccess;
  }

  /// Gets the storage type for this provider
  XStorageType get storageType;

  /// Helper method to create a URI for this provider
  ///
  /// Creates a [XUri] using this provider's scheme and the provided path.
  XUri getUri(String path) {
    return XUri.create(scheme, path);
  }
}

/// Mixin for asset-based storage providers
///
/// Provides common functionality for handling asset storage.
mixin AssetProviderMixin on XStorageProvider {
  /// Converts a URI to an asset name
  String assetName(XUri uri) {
    return uri.path;
  }

  @override
  XStorageType get storageType => XStorageType.asset;
}

/// Mixin for network-based storage providers
///
/// Provides common functionality for handling network storage,
/// including URL generation and type identification.
mixin NetworkProviderMixin on XStorageProvider {
  /// The root URL for the storage service (e.g., "https://example.com")
  String get rootUrl;

  /// Converts a storage URI to a network URL
  ///
  /// Combines the [rootUrl] with the URI path to create a complete network URL.
  /// Handles trailing slashes in the root URL appropriately.
  Future<Uri> getNetworkUrl(XUri uri) async {
    final root = rootUrl.endsWith("/")
        ? rootUrl.substring(0, rootUrl.length - 1)
        : rootUrl;
    return Uri.parse("$root${uri.path}");
  }

  @override
  XStorageType get storageType => XStorageType.network;
}

/// Mixin for file system-based storage providers
///
/// Provides common functionality for handling file system storage.
mixin FileProviderMixin on XStorageProvider {
  @override
  XStorageType get storageType => XStorageType.file;

  Future<String> getFilePath(XUri uri);
}
