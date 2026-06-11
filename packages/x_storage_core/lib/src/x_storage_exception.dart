import 'package:x_storage_core/x_storage_core.dart';

/// ストレージ操作に関するエラー
class XStorageException implements Exception {
  XStorageException();
}

/// プロバイダが見つからない場合のエラー
class ProviderNotFoundException extends XStorageException {
  final String scheme;
  ProviderNotFoundException(this.scheme);
}

/// ファイルが見つからない場合のエラー
class FileNotFoundException extends XStorageException {
  final XUri uri;
  FileNotFoundException(this.uri);
}

/// 操作が未サポートの場合のエラー
class UnsupportedOperationException extends XStorageException {
  final String message;
  UnsupportedOperationException(this.message);
}

/// その他のエラー
class UnknownException extends XStorageException {
  final Object error;
  UnknownException(this.error);

  @override
  String toString() => 'UnknownException($error)';
}
