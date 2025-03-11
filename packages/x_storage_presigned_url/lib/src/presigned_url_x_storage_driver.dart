import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:x_storage_core/x_storage_core.dart';
import 'package:flutter/foundation.dart';

/// Abstract driver for storage services that use Presigned URLs for upload/download
///
/// This driver implements file operations using Presigned URLs, typically used with
/// services like AWS S3 or other S3-compatible storage services.
///
/// To implement this driver, you need to:
/// 1. Override [scheme] to specify your storage scheme
/// 2. Implement [fetchUploadPresignedUrl] to generate Presigned URLs for upload
/// 3. Implement [getNetworkUrl] from NetworkXStorageMixin for download URLs
abstract class PresignedUrlXStorageDriver extends XStorageDriver
    with NetworkXStorageMixin {
  bool get enableDownloadPresignedUrl;

  @override
  String get scheme;

  @override
  Future<void> saveFile(XStorageUri uri, Uint8List data) async {
    // Extract filename and directories from uri.pathSegments
    final pathSegments = uri.pathSegments;
    final filename = pathSegments.last;
    final dirs = pathSegments.sublist(0, pathSegments.length - 1);

    // Get the Presigned URL for upload
    final url = await fetchUploadPresignedUrl(dirs: dirs, filename: filename);

    // Upload using PUT request
    final response = await http.put(Uri.parse(url), body: data);
    if (response.statusCode != 200) {
      throw Exception("Failed to upload file to storage");
    }
  }

  @override
  Future<Uint8List?> loadFile(XStorageUri uri) async {
    final url = await getNetworkUrl(uri);

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      return null;
    } catch (e) {
      debugPrint('Error reading file from storage: $e');
      return null;
    }
  }

  @override
  Future<void> deleteFile(XStorageUri uri) async {
    throw UnsupportedError("delete operation not implemented");
  }

  @override
  Future<bool> exists(XStorageUri uri) async {
    try {
      final completeUri = await getNetworkUrl(uri);
      final response = await http.head(completeUri);
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error checking file existence: $e');
      return false;
    }
  }

  @override
  Future<Uri> getNetworkUrl(XStorageUri uri) async {
    if (!enableDownloadPresignedUrl) {
      return await super.getNetworkUrl(uri);
    }

    final pathSegments = uri.pathSegments;
    final filename = pathSegments.last;
    final dirs = pathSegments.sublist(0, pathSegments.length - 1);

    return Uri.parse(await fetchDownloadPresignedUrl(
      dirs: dirs,
      filename: filename,
    ));
  }

  /// Generates a Presigned URL for file upload
  ///
  /// [dirs] is the list of directory names in the path
  /// [filename] is the name of the file to upload
  ///
  /// Returns a Presigned URL that can be used to upload the file using a PUT request
  Future<String> fetchUploadPresignedUrl({
    required List<String> dirs,
    required String filename,
  });

  /// Generates a Presigned URL for file download
  ///
  /// [dirs] is the list of directory names in the path
  /// [filename] is the name of the file to download
  ///
  /// Returns a Presigned URL that can be used to download the file using a GET request
  Future<String> fetchDownloadPresignedUrl({
    required List<String> dirs,
    required String filename,
  });
}
