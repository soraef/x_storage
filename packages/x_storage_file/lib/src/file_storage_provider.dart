import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:x_storage_core/x_storage_core.dart';
import 'package:type_result/type_result.dart';

class FileStorageProvider extends XStorageProvider with FileProviderMixin {
  @override
  final String scheme = 'file';

  // Dioインスタンス
  final Dio _dio = Dio();

  @override
  Future<Result<void, XStorageException>> deleteFile(XUri uri) async {
    try {
      final filePath = await getFilePath(uri);
      final file = File(filePath);

      if (await file.exists()) {
        await file.delete();
      }
      return Result.success(null);
    } catch (e) {
      return Result.failure(UnknownException(e));
    }
  }

  @override
  Future<Result<Uint8List, XStorageException>> loadFile(XUri uri) async {
    try {
      final filePath = await getFilePath(uri);
      final file = File(filePath);

      if (await file.exists()) {
        final data = await file.readAsBytes();
        return Result.success(data);
      }
      return Result.failure(FileNotFoundException(uri));
    } catch (e) {
      return Result.failure(UnknownException(e));
    }
  }

  @override
  Future<Result<void, XStorageException>> saveFile(
      XUri uri, Uint8List data) async {
    try {
      final filePath = await getFilePath(uri);
      final file = File(filePath);

      // 親ディレクトリが存在しない場合は作成
      final parentDir = file.parent;
      if (!await parentDir.exists()) {
        await parentDir.create(recursive: true);
      }

      await file.writeAsBytes(data);
      return Result.success(null);
    } catch (e) {
      return Result.failure(UnknownException(e));
    }
  }

  @override
  Future<bool> exists(XUri uri) async {
    final filePath = await getFilePath(uri);
    final file = File(filePath);
    return await file.exists();
  }

  @override
  Future<String> getFilePath(XUri uri) async {
    final dirPath = await _getAppSupportDirPath();
    return '$dirPath${uri.path}';
  }

  /// アプリ専用領域のパスを取得
  Future<String> _getAppSupportDirPath() async {
    final directory = await getApplicationSupportDirectory();
    return directory.path;
  }
}

// /// Mixin for file system-based storage providers
// ///
// /// Provides common functionality for handling file system storage.
// mixin FileProviderMixin on XStorageProvider {
//   @override
//   XStorageType get storageType => XStorageType.file;
// }

extension FileXStorageExtension on XStorage {
  /// URIがすでにダウンロード済みかどうかを確認
  ///
  /// ファイルがローカルに存在する場合はtrueを返す
  Future<bool> isDownloaded(XUri uri) async {
    final fileProviderResult =
        getProviderFromScheme<FileStorageProvider>('file');
    if (fileProviderResult.isFailure) {
      return false;
    }
    final fileProvider = fileProviderResult.success;
    final fileStorageUri = uri.changeScheme(fileProvider.scheme);
    return await fileProvider.exists(fileStorageUri);
  }

  /// ファイルをダウンロードして保存
  ///
  /// ダウンロードしたファイルのURIを返す
  /// 対象のファイルのプロバイダーがNetworkProviderMixinを実装している必要がある
  ///
  Future<Result<XUri, XStorageException>> downloadFile(
    XUri uri, {
    Function(int, int)? onProgress,
  }) async {
    try {
      final providerResult = getProvider(uri);
      if (providerResult.isFailure) {
        return Result.failure(providerResult.failure);
      }
      final provider = providerResult.success;

      final fileProviderResult =
          getProviderFromScheme<FileStorageProvider>('file');
      if (fileProviderResult.isFailure) {
        return Result.failure(fileProviderResult.failure);
      }
      final fileProvider = fileProviderResult.success;

      if (provider is! NetworkProviderMixin) {
        return Result.failure(
          UnsupportedOperationException(
            'Unsupported provider type: ${provider.runtimeType}',
          ),
        );
      }

      final networkUrl = await provider.getNetworkUrl(uri);
      final fileStorageUri = uri.changeScheme(fileProvider.scheme);
      final filePath = await fileProvider.getFilePath(fileStorageUri);

      final file = File(filePath);
      // if (await file.exists()) {
      //   return Result.success(fileStorageUri);
      // }

      // 親ディレクトリが存在しない場合は作成
      final parentDir = file.parent;
      if (!await parentDir.exists()) {
        await parentDir.create(recursive: true);
      }

      await fileProvider._dio.download(
        networkUrl.toString(),
        filePath,
        onReceiveProgress: onProgress,
      );

      return Result.success(fileStorageUri);
    } catch (e) {
      return Result.failure(UnknownException(e));
    }
  }
}
