import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:x_storage_core/x_storage_core.dart';

class FileStorageProvider extends XStorageProvider with FileProviderMixin {
  @override
  final String scheme = 'file';

  // Dioインスタンス
  final Dio _dio = Dio();

  @override
  Future<void> deleteFile(XUri uri) async {
    final filePath = await getFilePath(uri);
    final file = File(filePath);

    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<Uint8List?> loadFile(XUri uri) async {
    final filePath = await getFilePath(uri);
    final file = File(filePath);

    if (await file.exists()) {
      return await file.readAsBytes();
    }
    return null;
  }

  @override
  Future<void> saveFile(XUri uri, Uint8List data) async {
    final filePath = await getFilePath(uri);
    final file = File(filePath);
    await file.writeAsBytes(data);
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
  /// ファイルをダウンロードして保存
  ///
  /// ダウンロードしたファイルのURIを返す
  /// 対象のファイルのプロバイダーがNetworkProviderMixinを実装している必要がある
  ///
  Future<XUri> downloadFile(
    XUri uri, {
    Function(int, int)? onProgress,
  }) async {
    final provider = getProvider(uri);
    final fileProvider = getProviderFromScheme<FileStorageProvider>('file');
    if (provider is! NetworkProviderMixin) {
      throw UnsupportedError(
          'Unsupported provider type: ${provider.runtimeType}');
    }

    final networkUrl = await provider.getNetworkUrl(uri);
    final fileStorageUri = uri.changeScheme(fileProvider.scheme);
    final filePath = await fileProvider.getFilePath(fileStorageUri);

    final file = File(filePath);
    if (await file.exists()) {
      return fileStorageUri;
    }

    await fileProvider._dio.download(
      networkUrl.toString(),
      filePath,
      onReceiveProgress: onProgress,
    );

    return fileStorageUri;
  }
}
