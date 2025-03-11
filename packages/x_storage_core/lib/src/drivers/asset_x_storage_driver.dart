import 'package:flutter/services.dart';
import '../x_storage_driver.dart';
import '../x_storage_uri.dart';

/// Flutter アセットから読み書きするためのドライバ
/// （アセットへの書き込みや削除はサポートされない）
class AssetXStorageDriver extends XStorageDriver with AssetXStorageMixin {
  @override
  String get scheme => "asset";

  @override
  Future<void> saveFile(XStorageUri uri, Uint8List data) async {
    throw UnsupportedError("Cannot write to assets in Flutter");
  }

  @override
  Future<Uint8List?> loadFile(XStorageUri uri) async {
    try {
      final assetPath = uri.path;
      final data = await rootBundle.load(assetPath);
      return data.buffer.asUint8List();
    } catch (e) {
      return null; // 読み込み失敗時にnullを返す
    }
  }

  @override
  Future<void> deleteFile(XStorageUri uri) async {
    throw UnsupportedError("Cannot delete assets in Flutter");
  }
  
  @override
  Future<String> getFilePath(XStorageUri uri) {
    // TODO: implement getFilePath
    throw UnimplementedError();
  }
}
