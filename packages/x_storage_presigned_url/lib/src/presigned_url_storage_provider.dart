import 'package:http/http.dart' as http;
import 'package:x_storage_core/x_storage_core.dart';
import 'package:flutter/foundation.dart';
import 'package:type_result/type_result.dart';

import 'presigned_url_storage_exception.dart';

/// Abstract provider for storage services that use Presigned URLs for upload/download
///
/// This provider implements file operations using Presigned URLs, typically used with
/// services like AWS S3 or other S3-compatible storage services.
///
/// To implement this provider, you need to:
/// 1. Override [scheme] to specify your storage scheme
/// 2. Implement [fetchUploadPresignedUrl] to generate Presigned URLs for upload
/// 3. Implement [getNetworkUrl] from NetworkProviderMixin for download URLs
abstract class PresignedUrlStorageProvider extends XStorageProvider
    with NetworkProviderMixin {
  bool get enableDownloadPresignedUrl;

  @override
  String get scheme;

  @override
  Future<Result<void, XStorageException>> saveFile(
    XUri uri,
    Uint8List data,
  ) async {
    try {
      // Extract filename and directories from uri.pathSegments
      final pathSegments = uri.pathSegments;
      final filename = pathSegments.last;
      final dirs = pathSegments.sublist(0, pathSegments.length - 1);

      // Get the Presigned URL for upload
      final contentType = _mimeFromExtension(filename);
      final url = await fetchUploadPresignedUrl(
        dirs: dirs,
        filename: filename,
        sizeBytes: data.lengthInBytes,
        contentType: contentType,
      );

      // Upload using PUT request
      final headers = uploadHeaders(dirs: dirs, filename: filename, contentType: contentType);
      final response = await http.put(Uri.parse(url), body: data, headers: headers);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint('PUT upload failed: status=${response.statusCode}, body=${response.body}');
        return Result.failure(
          HttpException(
            "Failed to upload file to storage: ${response.statusCode}",
          ),
        );
      }
      await onSaveComplete(dirs: dirs, filename: filename);
      return Result.success(null);
    } catch (e) {
      return Result.failure(UnknownException(e));
    }
  }

  /// Returns headers for the PUT upload request.
  /// Override to add custom headers (e.g., Content-Type for presigned URL matching).
  Map<String, String>? uploadHeaders({
    required List<String> dirs,
    required String filename,
    String? contentType,
  }) {
    if (contentType != null) return {'Content-Type': contentType};
    return null;
  }

  /// Called after a successful PUT upload.
  /// Override to perform post-upload actions (e.g., notifying the server).
  Future<void> onSaveComplete({
    required List<String> dirs,
    required String filename,
  }) async {}

  @override
  Future<Result<Uint8List, XStorageException>> loadFile(XUri uri) async {
    try {
      final url = await getNetworkUrl(uri);
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return Result.success(response.bodyBytes);
      }
      return Result.failure(FileNotFoundException(uri));
    } catch (e) {
      debugPrint('Error reading file from storage: $e');
      return Result.failure(UnknownException(e));
    }
  }

  @override
  Future<Result<void, XStorageException>> deleteFile(XUri uri) async {
    return Result.failure(
      UnsupportedOperationException("delete operation not implemented"),
    );
  }

  @override
  Future<bool> exists(XUri uri) async {
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
  Future<Uri> getNetworkUrl(XUri uri) async {
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
  /// [sizeBytes] is the size of the file in bytes (optional)
  /// [contentType] is the MIME type of the file (optional)
  ///
  /// Returns a Presigned URL that can be used to upload the file using a PUT request
  Future<String> fetchUploadPresignedUrl({
    required List<String> dirs,
    required String filename,
    int? sizeBytes,
    String? contentType,
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

  static String? _mimeFromExtension(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      'pdf' => 'application/pdf',
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      _ => null,
    };
  }
}
