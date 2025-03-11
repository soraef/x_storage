import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';

import 'x_storage_driver.dart';
import 'x_storage_type.dart';
import 'x_storage_uri.dart';

/// The main XStorage class
///
/// This class manages multiple [XStorageDriver] instances registered by scheme,
/// providing a unified interface to handle different storage types.
///
/// Example:
/// ```dart
/// final storage = XStorage();
/// storage.registerDriver(MyCustomDriver());
///
/// // Save a file
/// await storage.saveFile(
///   XStorageUri.create('custom', 'path/to/file.txt'),
///   data,
/// );
/// ```
class XStorage {
  final Map<String, XStorageDriver> _drivers = {};

  /// Registers a storage driver
  ///
  /// The driver will be registered with its [XStorageDriver.scheme] and can be
  /// used to handle storage operations for that scheme.
  void registerDriver(XStorageDriver driver) {
    _drivers[driver.scheme] = driver;
  }

  D getDriverFromScheme<D extends XStorageDriver>(String scheme) {
    final driver = _drivers[scheme];
    if (driver == null) {
      throw UnsupportedError('Unknown storage scheme in URI: $scheme');
    }
    if (driver is! D) {
      throw UnsupportedError('Unsupported driver type: ${driver.runtimeType}');
    }
    return driver;
  }

  /// Gets the appropriate driver for the given URI
  ///
  /// Throws [UnsupportedError] if no driver is registered for the URI's scheme.
  XStorageDriver getDriver(XStorageUri uri) {
    final scheme = uri.scheme;
    if (_drivers.containsKey(scheme)) {
      return _drivers[scheme]!;
    }
    throw UnsupportedError('Unknown storage scheme in URI: $scheme');
  }

  /// match driver from uri
  Future<T> withResource<T>({
    required XStorageUri xStorageUri,
    required Future<T> Function(Uri uri) network,
    required Future<T> Function(String filePath) file,
    required Future<T> Function(String assetName) asset,
    required Future<T> Function(XFile xFile) onNoMatch,
  }) async {
    final driver = getDriver(xStorageUri);
    if (driver is NetworkXStorageMixin) {
      final uri = await driver.getNetworkUrl(xStorageUri);
      return await network(uri);
    } else if (driver is FileXStorageMixin) {
      final filePath = await driver.getFilePath(xStorageUri);
      return await file(filePath);
    } else if (driver is AssetXStorageMixin) {
      return await asset(xStorageUri.path);
    }
    final xFile = await loadXFile(xStorageUri);
    if (xFile == null) {
      throw Exception('File not found: ${xStorageUri.toString()}');
    }
    return await onNoMatch(xFile);
  }

  /// Saves file data to the specified URI
  ///
  /// The appropriate driver will be selected based on the URI's scheme.
  Future<void> saveFile(XStorageUri uri, Uint8List data) async {
    final driver = getDriver(uri);
    await driver.saveFile(uri, data);
  }

  /// Loads file data from the specified URI
  ///
  /// Returns null if the file doesn't exist.
  Future<Uint8List?> loadFile(XStorageUri uri) async {
    final driver = getDriver(uri);
    return await driver.loadFile(uri);
  }

  /// Deletes the file at the specified URI
  Future<void> deleteFile(XStorageUri uri) async {
    final driver = getDriver(uri);
    await driver.deleteFile(uri);
  }

  /// Checks if a file exists at the specified URI
  Future<bool> exists(XStorageUri uri) async {
    final driver = getDriver(uri);
    return await driver.exists(uri);
  }

  /// Saves an XFile to the specified URI
  Future<void> saveXFile(XStorageUri uri, XFile file) async {
    final data = await file.readAsBytes();
    await saveFile(uri, data);
  }

  /// Loads an XFile from the specified URI
  ///
  /// Returns null if the file doesn't exist.
  Future<XFile?> loadXFile(XStorageUri uri) async {
    final data = await loadFile(uri);
    final driver = getDriver(uri);

    String? path;
    if (driver is FileXStorageMixin) {
      path = await driver.getFilePath(uri);
    }

    return data == null ? null : XFile.fromData(data, path: path);
  }

  /// Saves a Base64 encoded string to the specified URI
  Future<void> saveString(XStorageUri uri, String data) async {
    final dataBytes = base64Decode(data);
    await saveFile(uri, dataBytes);
  }

  /// Loads a Base64 encoded string from the specified URI
  ///
  /// Returns null if the file doesn't exist.
  Future<String?> loadString(XStorageUri uri) async {
    final data = await loadFile(uri);
    return data == null ? null : base64Encode(data);
  }

  /// Gets the storage type for the specified URI
  XStorageType getStorageType(XStorageUri uri) {
    final driver = getDriver(uri);
    return driver.storageType;
  }
}
