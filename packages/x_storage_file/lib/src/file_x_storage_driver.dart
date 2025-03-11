import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:x_storage_core/x_storage_core.dart';

class FileXStorageDriver extends XStorageDriver with FileXStorageMixin {
  @override
  final String scheme = 'file';

  // Dioインスタンス
  final Dio _dio = Dio();

  @override
  Future<void> deleteFile(XStorageUri uri) async {
    final filePath = await getFilePath(uri);
    final file = File(filePath);

    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<Uint8List?> loadFile(XStorageUri uri) async {
    final filePath = await getFilePath(uri);
    final file = File(filePath);

    if (await file.exists()) {
      return await file.readAsBytes();
    }
    return null;
  }

  @override
  Future<void> saveFile(XStorageUri uri, Uint8List data) async {
    final filePath = await getFilePath(uri);
    final file = File(filePath);
    await file.writeAsBytes(data);
  }

  @override
  Future<bool> exists(XStorageUri uri) async {
    final filePath = await getFilePath(uri);
    final file = File(filePath);
    return await file.exists();
  }

  Future<String> getFilePath(XStorageUri uri) async {
    final dirPath = await _getAppSupportDirPath();
    return '$dirPath${uri.path}';
  }

  /// アプリ専用領域のパスを取得
  Future<String> _getAppSupportDirPath() async {
    final directory = await getApplicationSupportDirectory();
    return directory.path;
  }
}

// /// Mixin for file system-based storage drivers
// ///
// /// Provides common functionality for handling file system storage.
// mixin FileXStorageMixin on XStorageDriver {
//   @override
//   XStorageType get storageType => XStorageType.file;
// }

extension FileXStorageExtension on XStorage {
  /// ファイルをダウンロードして保存
  ///
  /// ダウンロードしたファイルのURIを返す
  /// 対象のファイルのドライバーがNetworkXStorageMixinを実装している必要がある
  ///
  Future<XStorageUri> downloadFile(
    XStorageUri uri, {
    Function(int, int)? onProgress,
  }) async {
    final driver = getDriver(uri);
    final fileDriver = getDriverFromScheme<FileXStorageDriver>('file');
    if (driver is! NetworkXStorageMixin) {
      throw UnsupportedError('Unsupported driver type: ${driver.runtimeType}');
    }

    final networkUrl = await driver.getNetworkUrl(uri);
    final fileStorageUri = uri.changeScheme(fileDriver.scheme);
    final filePath = await fileDriver.getFilePath(fileStorageUri);

    final file = File(filePath);
    if (await file.exists()) {
      return fileStorageUri;
    }

    await fileDriver._dio.download(
      networkUrl.toString(),
      filePath,
      onReceiveProgress: onProgress,
    );

    return fileStorageUri;
  }
}
