import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';

import 'x_storage_provider.dart';
import 'x_storage_type.dart';
import 'x_uri.dart';

/// The main XStorage class
///
/// This class manages multiple [XStorageProvider] instances registered by scheme,
/// providing a unified interface to handle different storage types.
///
/// Example:
/// ```dart
/// final storage = XStorage();
/// storage.registerProvider(MyCustomDriver());
///
/// // Save a file
/// await storage.saveFile(
///   XUri.create('custom', 'path/to/file.txt'),
///   data,
/// );
/// ```
class XStorage {
  final Map<String, XStorageProvider> _providers = {};

  /// Registers a storage provider
  ///
  /// The provider will be registered with its [XStorageProvider.scheme] and can be
  /// used to handle storage operations for that scheme.
  void registerProvider(XStorageProvider provider) {
    _providers[provider.scheme] = provider;
  }

  D getProviderFromScheme<D extends XStorageProvider>(String scheme) {
    final provider = _providers[scheme];
    if (provider == null) {
      throw UnsupportedError('Unknown storage scheme in URI: $scheme');
    }
    if (provider is! D) {
      throw UnsupportedError(
          'Unsupported provider type: ${provider.runtimeType}');
    }
    return provider;
  }

  /// Gets the appropriate provider for the given URI
  ///
  /// Throws [UnsupportedError] if no provider is registered for the URI's scheme.
  XStorageProvider getProvider(XUri uri) {
    final scheme = uri.scheme;
    if (_providers.containsKey(scheme)) {
      return _providers[scheme]!;
    }
    throw UnsupportedError('Unknown storage scheme in URI: $scheme');
  }

  /// match provider from uri
  Future<T> withResource<T>({
    required XUri xUri,
    required Future<T> Function(Uri uri) network,
    required Future<T> Function(String filePath) file,
    required Future<T> Function(String assetName) asset,
    required Future<T> Function(XFile xFile) onNoMatch,
  }) async {
    final provider = getProvider(xUri);
    if (provider is NetworkProviderMixin) {
      final uri = await provider.getNetworkUrl(xUri);
      return await network(uri);
    } else if (provider is FileProviderMixin) {
      final filePath = await provider.getFilePath(xUri);
      return await file(filePath);
    } else if (provider is AssetProviderMixin) {
      return await asset(xUri.path);
    }
    final xFile = await loadXFile(xUri);
    if (xFile == null) {
      throw Exception('File not found: ${xUri.toString()}');
    }
    return await onNoMatch(xFile);
  }

  /// Saves file data to the specified URI
  ///
  /// The appropriate provider will be selected based on the URI's scheme.
  Future<void> saveFile(XUri uri, Uint8List data) async {
    final provider = getProvider(uri);
    await provider.saveFile(uri, data);
  }

  /// Loads file data from the specified URI
  ///
  /// Returns null if the file doesn't exist.
  Future<Uint8List?> loadFile(XUri uri) async {
    final provider = getProvider(uri);
    return await provider.loadFile(uri);
  }

  /// Deletes the file at the specified URI
  Future<void> deleteFile(XUri uri) async {
    final provider = getProvider(uri);
    await provider.deleteFile(uri);
  }

  /// Checks if a file exists at the specified URI
  Future<bool> exists(XUri uri) async {
    final provider = getProvider(uri);
    return await provider.exists(uri);
  }

  /// Saves an XFile to the specified URI
  Future<void> saveXFile(XUri uri, XFile file) async {
    final data = await file.readAsBytes();
    await saveFile(uri, data);
  }

  /// Loads an XFile from the specified URI
  ///
  /// Returns null if the file doesn't exist.
  Future<XFile?> loadXFile(XUri uri) async {
    final data = await loadFile(uri);
    final provider = getProvider(uri);

    String? path;
    if (provider is FileProviderMixin) {
      path = await provider.getFilePath(uri);
    }

    return data == null ? null : XFile.fromData(data, path: path);
  }

  /// Saves a Base64 encoded string to the specified URI
  Future<void> saveString(XUri uri, String data) async {
    final dataBytes = base64Decode(data);
    await saveFile(uri, dataBytes);
  }

  /// Loads a Base64 encoded string from the specified URI
  ///
  /// Returns null if the file doesn't exist.
  Future<String?> loadString(XUri uri) async {
    final data = await loadFile(uri);
    return data == null ? null : base64Encode(data);
  }

  /// Gets the storage type for the specified URI
  XStorageType getStorageType(XUri uri) {
    final provider = getProvider(uri);
    return provider.storageType;
  }
}
