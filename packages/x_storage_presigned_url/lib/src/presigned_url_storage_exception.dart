import 'package:x_storage_core/x_storage_core.dart';

class HttpException extends XStorageException {
  final String message;
  HttpException(this.message);
}
