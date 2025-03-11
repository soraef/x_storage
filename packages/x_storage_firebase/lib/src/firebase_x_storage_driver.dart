import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:x_storage_core/x_storage_core.dart';
import 'package:flutter/foundation.dart';

/// XStorage driver for Firebase Storage
///
/// This driver implements the XStorage interface for Firebase Storage,
/// providing file operations that interact with Firebase Storage.
class FirebaseXStorageDriver extends XStorageDriver with NetworkXStorageMixin {
  @override
  final String scheme = 'firebase';

  /// The Firebase Storage instance to use for operations
  final FirebaseStorage firebaseStorage;

  /// Creates a new [FirebaseXStorageDriver] instance
  ///
  /// [firebaseStorage] is the Firebase Storage instance to use
  FirebaseXStorageDriver({
    required this.firebaseStorage,
  });

  @override
  String get rootUrl => firebaseStorage.bucket;

  @override
  Future<Uri> getNetworkUrl(XStorageUri uri) async {
    final ref = firebaseStorage.ref().child(uri.path);
    final url = await ref.getDownloadURL();
    return Uri.parse(url);
  }

  @override
  Future<void> saveFile(XStorageUri uri, Uint8List data) async {
    final ref = firebaseStorage.ref().child(uri.path);
    await ref.putData(data);
  }

  @override
  Future<Uint8List?> loadFile(XStorageUri uri) async {
    final ref = firebaseStorage.ref().child(uri.path);
    try {
      final data = await ref.getData();
      return data;
    } catch (e) {
      // Handle cases where the file doesn't exist or other errors occur
      debugPrint('Error reading file from Firebase Storage: $e');
      return null;
    }
  }

  @override
  Future<void> deleteFile(XStorageUri uri) async {
    final ref = firebaseStorage.ref().child(uri.path);
    await ref.delete();
  }

  @override
  Future<bool> exists(XStorageUri uri) async {
    try {
      await firebaseStorage.ref().child(uri.path).getDownloadURL();
      return true;
    } catch (e) {
      return false;
    }
  }
}
