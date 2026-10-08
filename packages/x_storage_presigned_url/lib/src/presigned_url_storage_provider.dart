import 'package:http/http.dart' as http;
import 'package:x_storage_core/x_storage_core.dart';
import 'package:flutter/foundation.dart';
import 'package:type_result/type_result.dart';

import 'presigned_upload_target.dart';
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

  /// Reused HTTP client so repeated requests (head / exists / load / save)
  /// keep the TCP/TLS connection alive instead of performing a fresh
  /// handshake on every call. This significantly reduces latency when many
  /// metadata requests are issued in a row (e.g. computing download sizes).
  final http.Client _client = http.Client();

  @override
  Future<Result<void, XStorageException>> saveFile(
    XUri uri,
    Uint8List data,
  ) async {
    // Extract filename and directories from uri.pathSegments
    final pathSegments = uri.pathSegments;
    final filename = pathSegments.last;
    final dirs = pathSegments.sublist(0, pathSegments.length - 1);
    final contentType = _mimeFromExtension(filename);

    // --- stage: url-fetch ---
    final PresignedUploadTarget target;
    try {
      target = await fetchUploadPresignedUrl(
        dirs: dirs,
        filename: filename,
        sizeBytes: data.lengthInBytes,
        contentType: contentType,
      );
    } catch (e) {
      debugPrint(
          '[PresignedUrl] stage=url-fetch failed uri=$uri filename=$filename error=$e');
      return Result.failure(UnknownException(e));
    }

    // --- stage: put ---
    Map<String, String>? appliedHeaders;
    try {
      final request =
          http.StreamedRequest(target.method, Uri.parse(target.url));

      final serverHeaders = target.headers;
      if (serverHeaders != null) {
        // Server (presigned URL signer) supplied headers: send them
        // verbatim, they are part of the request signature. The one
        // exception is Content-Length, which cannot be set through the
        // headers map on http.StreamedRequest — it must be set via
        // request.contentLength instead.
        appliedHeaders = Map<String, String>.from(serverHeaders)
          ..removeWhere((key, _) => key.toLowerCase() == 'content-length');
        request.headers.addAll(appliedHeaders);
      } else {
        // Legacy behavior: providers that don't return headers alongside
        // the presigned URL fall back to the overridable uploadHeaders().
        appliedHeaders = uploadHeaders(
            dirs: dirs, filename: filename, contentType: contentType);
        if (appliedHeaders != null) {
          request.headers.addAll(appliedHeaders);
        } else {
          // headers が null の場合、http パッケージが自動で content-type を付けないようにする
          request.headers.remove('content-type');
        }
      }
      request.contentLength = data.lengthInBytes;

      debugPrint('[PresignedUrl] ${target.method} ${target.url}');
      debugPrint(
          '[PresignedUrl] headers=$appliedHeaders, contentType=$contentType, size=${data.lengthInBytes}');

      request.sink.add(data);
      request.sink.close();
      final streamedResponse =
          await (uploadHttpClient ?? _client).send(request);
      final responseBody = await streamedResponse.stream.bytesToString();
      final status = streamedResponse.statusCode;

      final hasIfNoneMatch = appliedHeaders?.keys
              .any((key) => key.toLowerCase() == 'if-none-match') ??
          false;

      if (status == 412 && hasIfNoneMatch) {
        // R2 presigned PUTs are signed with `If-None-Match: *`, so a retry
        // after a successful PUT but a failed `complete` call will get a
        // 412 here because the object already exists. The object key is
        // unique per upload operation and R2 PUTs are atomic, so a 412
        // with If-None-Match applied means the earlier PUT already
        // succeeded — treat it as such and proceed to onSaveComplete
        // (the server verifies size at complete time).
        debugPrint(
            '[PresignedUrl] stage=put status=412 uri=$uri filename=$filename note=object already uploaded (If-None-Match precondition failed); treating as success and proceeding to complete');
      } else if (status < 200 || status >= 300) {
        debugPrint(
            '[PresignedUrl] stage=put failed status=$status uri=$uri filename=$filename body=$responseBody');
        return Result.failure(
          HttpException("Failed to upload file to storage: $status"),
        );
      }
    } catch (e) {
      debugPrint(
          '[PresignedUrl] stage=put failed uri=$uri filename=$filename error=$e');
      return Result.failure(UnknownException(e));
    }

    // --- stage: complete ---
    try {
      await onSaveComplete(dirs: dirs, filename: filename);
    } catch (e) {
      debugPrint(
          '[PresignedUrl] stage=complete failed uri=$uri filename=$filename error=$e');
      return Result.failure(UnknownException(e));
    }

    return Result.success(null);
  }

  /// Optional [http.Client] used to send the upload request to the
  /// presigned URL. When null (the default), the provider's shared client is
  /// used, so uploads reuse the same keep-alive connection as other requests.
  ///
  /// Override to inject a client — e.g. for testing with
  /// `package:http/testing.dart`'s `MockClient`, or to share a client
  /// instance with the rest of the provider.
  @protected
  http.Client? get uploadHttpClient => null;

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
      final response = await _client.get(url);

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
      final response = await _client.head(completeUri);
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error checking file existence: $e');
      return false;
    }
  }

  @override
  Future<Result<XFileHead, XStorageException>> head(XUri uri) async {
    try {
      final completeUri = await getNetworkUrl(uri);
      final response = await _client.head(completeUri);
      if (response.statusCode != 200) {
        return Result.failure(FileNotFoundException(uri));
      }
      // http lowercases all header keys.
      final headers = response.headers;
      final size = int.tryParse(headers['content-length'] ?? '');
      return Result.success(
        XFileHead(
          size: size,
          contentType: headers['content-type'],
        ),
      );
    } catch (e) {
      debugPrint('Error fetching file head: $e');
      return Result.failure(UnknownException(e));
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
  /// Returns a [PresignedUploadTarget] describing the URL, HTTP method, and
  /// (optionally) the exact headers that must be sent to upload the file.
  Future<PresignedUploadTarget> fetchUploadPresignedUrl({
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
      'm4a' => 'audio/mp4',
      'mp3' => 'audio/mpeg',
      'aac' => 'audio/aac',
      'wav' => 'audio/wav',
      'ogg' => 'audio/ogg',
      'flac' => 'audio/flac',
      _ => 'application/octet-stream',
    };
  }
}
