import 'package:flutter/services.dart';
import 'package:type_result/type_result.dart';
import 'package:x_storage_core/src/x_storage_exception.dart';
import '../x_storage_provider.dart';
import '../x_uri.dart';

/// Flutter アセットから読み書きするためのプロバイダ
/// （アセットへの書き込みや削除はサポートされない）
class AssetStorageProvider extends XStorageProvider with AssetProviderMixin {
  @override
  String get scheme => "asset";

  @override
  Future<Result<void, XStorageException>> saveFile(
      XUri uri, Uint8List data) async {
    return Result.failure(
      UnsupportedOperationException(
        "Cannot write to assets in Flutter",
      ),
    );
  }

  @override
  Future<Result<Uint8List, XStorageException>> loadFile(XUri uri) async {
    try {
      final assetPath = uri.path;
      final data = await rootBundle.load(assetPath);
      return Result.success(data.buffer.asUint8List());
    } catch (e) {
      return Result.failure(FileNotFoundException(uri));
    }
  }

  @override
  Future<Result<void, XStorageException>> deleteFile(XUri uri) async {
    return Result.failure(
      UnsupportedOperationException(
        "Cannot delete assets in Flutter",
      ),
    );
  }
}
