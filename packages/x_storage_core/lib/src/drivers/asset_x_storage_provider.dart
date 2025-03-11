import 'package:flutter/services.dart';
import '../x_storage_provider.dart';
import '../x_uri.dart';

/// Flutter アセットから読み書きするためのプロバイダ
/// （アセットへの書き込みや削除はサポートされない）
class AssetXStorageProvider extends XStorageProvider with AssetProviderMixin {
  @override
  String get scheme => "asset";

  @override
  Future<void> saveFile(XUri uri, Uint8List data) async {
    throw UnsupportedError("Cannot write to assets in Flutter");
  }

  @override
  Future<Uint8List?> loadFile(XUri uri) async {
    try {
      final assetPath = uri.path;
      final data = await rootBundle.load(assetPath);
      return data.buffer.asUint8List();
    } catch (e) {
      return null; // 読み込み失敗時にnullを返す
    }
  }

  @override
  Future<void> deleteFile(XUri uri) async {
    throw UnsupportedError("Cannot delete assets in Flutter");
  }

  @override
  Future<String> getFilePath(XUri uri) {
    // TODO: implement getFilePath
    throw UnimplementedError();
  }
}
