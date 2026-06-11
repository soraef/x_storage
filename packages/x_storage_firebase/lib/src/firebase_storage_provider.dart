import 'package:firebase_storage/firebase_storage.dart';
import 'package:x_storage_core/x_storage_core.dart';
import 'package:flutter/foundation.dart';
import 'package:type_result/type_result.dart';

/// XStorage provider for Firebase Storage
///
/// This provider implements the XStorage interface for Firebase Storage,
/// providing file operations that interact with Firebase Storage.
class FirebaseStorageProvider extends XStorageProvider
    with NetworkProviderMixin {
  @override
  final String scheme = 'firebase';

  /// The Firebase Storage instance to use for operations
  final FirebaseStorage firebaseStorage;

  /// Creates a new [FirebaseStorageProvider] instance
  ///
  /// [firebaseStorage] is the Firebase Storage instance to use
  FirebaseStorageProvider({
    required this.firebaseStorage,
  });

  @override
  String get rootUrl => firebaseStorage.bucket;

  @override
  Future<Uri> getNetworkUrl(XUri uri) async {
    final ref = firebaseStorage.ref().child(uri.path);
    final url = await ref.getDownloadURL();
    return Uri.parse(url);
  }

  @override
  Future<Result<void, XStorageException>> saveFile(
      XUri uri, Uint8List data) async {
    try {
      final ref = firebaseStorage.ref().child(uri.path);
      await ref.putData(data);
      return Result.success(null);
    } catch (e) {
      return Result.failure(UnknownException(e));
    }
  }

  @override
  Future<Result<Uint8List, XStorageException>> loadFile(XUri uri) async {
    try {
      final ref = firebaseStorage.ref().child(uri.path);
      final data = await ref.getData();
      if (data == null) {
        return Result.failure(FileNotFoundException(uri));
      }
      return Result.success(data);
    } catch (e) {
      debugPrint('Error reading file from Firebase Storage: $e');
      return Result.failure(UnknownException(e));
    }
  }

  @override
  Future<Result<void, XStorageException>> deleteFile(XUri uri) async {
    try {
      final ref = firebaseStorage.ref().child(uri.path);
      await ref.delete();
      return Result.success(null);
    } catch (e) {
      return Result.failure(UnknownException(e));
    }
  }

  @override
  Future<bool> exists(XUri uri) async {
    try {
      await firebaseStorage.ref().child(uri.path).getDownloadURL();
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<Result<XFileHead, XStorageException>> head(XUri uri) async {
    try {
      final metadata =
          await firebaseStorage.ref().child(uri.path).getMetadata();
      return Result.success(
        XFileHead(
          size: metadata.size,
          contentType: metadata.contentType,
          lastModified: metadata.updated,
        ),
      );
    } catch (e) {
      debugPrint('Error fetching metadata from Firebase Storage: $e');
      return Result.failure(UnknownException(e));
    }
  }
}
