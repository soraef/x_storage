import 'dart:convert';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:type_result/type_result.dart';

import 'caching_provider_mixin.dart';
import 'x_storage_exception.dart';
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

  Result<P, XStorageException>
      getProviderFromScheme<P extends XStorageProvider>(String scheme) {
    final provider = _providers[scheme];
    if (provider == null) {
      return Result.failure(ProviderNotFoundException(scheme));
    }
    if (provider is! P) {
      return Result.failure(
        UnsupportedOperationException(
            'Unsupported provider type: ${provider.runtimeType}'),
      );
    }
    return Result.success(provider);
  }

  /// Gets the appropriate provider for the given URI
  ///
  /// Throws [UnsupportedError] if no provider is registered for the URI's scheme.
  Result<XStorageProvider, XStorageException> getProvider(XUri uri) {
    final scheme = uri.scheme;
    if (_providers.containsKey(scheme)) {
      return Result.success(_providers[scheme]!);
    }
    return Result.failure(ProviderNotFoundException(scheme));
  }

  /// match provider from uri
  Future<Result<T, XStorageException>> withResource<T>({
    required XUri xUri,
    required Future<T> Function(Uri uri) network,
    required Future<T> Function(String filePath) file,
    required Future<T> Function(String assetName) asset,
    required Future<T> Function(XFile xFile) onNoMatch,
  }) async {
    try {
      final providerResult = getProvider(xUri);
      if (providerResult.isFailure) {
        return Result.failure(providerResult.failure);
      }

      final provider = providerResult.success;
      // キャッシュ済みの場合はローカルファイルパスを使用
      if (provider is CachingProviderMixin) {
        final cachedPath = await provider.getCachedFilePath(xUri);
        if (cachedPath != null) {
          return Result.success(await file(cachedPath));
        }
      }
      if (provider is NetworkProviderMixin) {
        final uri = await provider.getNetworkUrl(xUri);
        return Result.success(await network(uri));
      } else if (provider is FileProviderMixin) {
        final filePath = await provider.getFilePath(xUri);
        return Result.success(await file(filePath));
      } else if (provider is AssetProviderMixin) {
        return Result.success(await asset(xUri.path));
      }

      final xFileResult = await loadXFile(xUri);
      if (xFileResult.isFailure) {
        return Result.failure(xFileResult.failure);
      }

      final xFile = xFileResult.success;
      return Result.success(await onNoMatch(xFile));
    } catch (e) {
      return Result.failure(UnknownException(e));
    }
  }

  /// Saves file data to the specified URI
  ///
  /// The appropriate provider will be selected based on the URI's scheme.
  Future<Result<void, XStorageException>> saveFile(
    XUri uri,
    Uint8List data,
  ) async {
    try {
      final providerResult = getProvider(uri);
      if (providerResult.isFailure) {
        return Result.failure(providerResult.failure);
      }

      final provider = providerResult.success;
      final result = await provider.saveFile(uri, data);
      return result;
    } catch (e) {
      return Result.failure(UnknownException(e));
    }
  }

  /// Loads file data from the specified URI
  ///
  /// Returns null if the file doesn't exist.
  Future<Result<Uint8List, XStorageException>> loadFile(XUri uri) async {
    try {
      final providerResult = getProvider(uri);
      if (providerResult.isFailure) {
        return Result.failure(providerResult.failure);
      }

      final provider = providerResult.success;
      final result = await provider.loadFile(uri);
      return result;
    } catch (e) {
      return Result.failure(UnknownException(e));
    }
  }

  /// Deletes the file at the specified URI
  Future<Result<void, XStorageException>> deleteFile(XUri uri) async {
    try {
      final providerResult = getProvider(uri);
      if (providerResult.isFailure) {
        return Result.failure(providerResult.failure);
      }

      final provider = providerResult.success;
      final result = await provider.deleteFile(uri);
      return result;
    } catch (e) {
      return Result.failure(UnknownException(e));
    }
  }

  /// Checks if a file exists at the specified URI
  Future<Result<bool, XStorageException>> exists(XUri uri) async {
    try {
      final providerResult = getProvider(uri);
      if (providerResult.isFailure) {
        return Result.failure(providerResult.failure);
      }

      final provider = providerResult.success;
      final result = await provider.exists(uri);
      return Result.success(result);
    } catch (e) {
      return Result.failure(UnknownException(e));
    }
  }

  /// Saves an XFile to the specified URI
  Future<Result<void, XStorageException>> saveXFile(
      XUri uri, XFile file) async {
    try {
      final data = await file.readAsBytes();
      return await saveFile(uri, data);
    } catch (e) {
      return Result.failure(UnknownException(e));
    }
  }

  /// Loads an XFile from the specified URI
  ///
  /// Returns null if the file doesn't exist.
  Future<Result<XFile, XStorageException>> loadXFile(XUri uri) async {
    try {
      final dataResult = await loadFile(uri);
      if (dataResult.isFailure) {
        return Result.failure(dataResult.failure);
      }

      final data = dataResult.success;
      final providerResult = getProvider(uri);
      if (providerResult.isFailure) {
        return Result.failure(providerResult.failure);
      }

      final provider = providerResult.success;
      String? path;
      if (provider is FileProviderMixin) {
        path = await provider.getFilePath(uri);
      }

      return Result.success(XFile.fromData(data, path: path));
    } catch (e) {
      return Result.failure(UnknownException(e));
    }
  }

  /// Saves a Base64 encoded string to the specified URI
  Future<Result<void, XStorageException>> saveString(
      XUri uri, String data) async {
    try {
      final dataBytes = base64Decode(data);
      return await saveFile(uri, dataBytes);
    } catch (e) {
      return Result.failure(UnknownException(e));
    }
  }

  /// Loads a Base64 encoded string from the specified URI
  ///
  /// Returns null if the file doesn't exist.
  Future<Result<String, XStorageException>> loadString(XUri uri) async {
    try {
      final dataResult = await loadFile(uri);
      if (dataResult.isFailure) {
        return Result.failure(dataResult.failure);
      }

      final data = dataResult.success;
      return Result.success(base64Encode(data));
    } catch (e) {
      return Result.failure(UnknownException(e));
    }
  }

  /// Gets the storage type for the specified URI
  XStorageType getStorageType(XUri uri) {
    final providerResult = getProvider(uri);
    if (providerResult.isFailure) {
      throw UnsupportedError('Unknown storage scheme in URI: ${uri.scheme}');
    }
    return providerResult.success.storageType;
  }
}
