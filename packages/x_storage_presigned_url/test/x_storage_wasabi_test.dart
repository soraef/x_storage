import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:x_storage_core/x_storage_core.dart';
import 'package:x_storage_presigned_url/x_storage_presigned_url.dart';

/// Minimal fake implementer of [PresignedUrlStorageProvider], standing in
/// for backends like Wasabi/R2 that hand back a presigned URL (optionally
/// with signed headers) for uploads.
class _FakeProvider extends PresignedUrlStorageProvider {
  _FakeProvider({
    required this.target,
    this.client,
    this.legacyUploadHeaders,
    this.onSaveCompleteError,
  });

  final PresignedUploadTarget target;
  final http.Client? client;
  final Map<String, String>? Function({
    required List<String> dirs,
    required String filename,
    String? contentType,
  })? legacyUploadHeaders;
  final Object? onSaveCompleteError;

  final List<String> completedFilenames = [];

  @override
  String get scheme => 'fake';

  @override
  String get rootUrl => 'https://example.com';

  @override
  bool get enableDownloadPresignedUrl => false;

  @override
  http.Client? get uploadHttpClient => client;

  @override
  Future<PresignedUploadTarget> fetchUploadPresignedUrl({
    required List<String> dirs,
    required String filename,
    int? sizeBytes,
    String? contentType,
  }) async {
    return target;
  }

  @override
  Map<String, String>? uploadHeaders({
    required List<String> dirs,
    required String filename,
    String? contentType,
  }) {
    if (legacyUploadHeaders != null) {
      return legacyUploadHeaders!(
          dirs: dirs, filename: filename, contentType: contentType);
    }
    return super.uploadHeaders(
        dirs: dirs, filename: filename, contentType: contentType);
  }

  @override
  Future<void> onSaveComplete({
    required List<String> dirs,
    required String filename,
  }) async {
    completedFilenames.add(filename);
    if (onSaveCompleteError != null) {
      throw onSaveCompleteError!;
    }
  }

  @override
  Future<String> fetchDownloadPresignedUrl({
    required List<String> dirs,
    required String filename,
  }) async {
    return 'https://example.com/download';
  }
}

class _ThrowingUploadUrlProvider extends PresignedUrlStorageProvider {
  @override
  String get scheme => 'fake';

  @override
  String get rootUrl => 'https://example.com';

  @override
  bool get enableDownloadPresignedUrl => false;

  @override
  Future<PresignedUploadTarget> fetchUploadPresignedUrl({
    required List<String> dirs,
    required String filename,
    int? sizeBytes,
    String? contentType,
  }) async {
    throw Exception('boom');
  }

  @override
  Future<String> fetchDownloadPresignedUrl({
    required List<String> dirs,
    required String filename,
  }) async {
    return 'https://example.com/download';
  }
}

XUri _uri(String path) => XUri.create('fake', path);

Uint8List _data(String s) => Uint8List.fromList(utf8.encode(s));

void main() {
  group('PresignedUrlStorageProvider.saveFile with server-supplied headers',
      () {
    test(
        'sends headers verbatim (Content-Type, If-None-Match) and sets contentLength from body',
        () async {
      http.BaseRequest? capturedRequest;
      Uint8List? capturedBody;

      final client = MockClient.streaming((request, bodyStream) async {
        capturedRequest = request;
        capturedBody = Uint8List.fromList(await bodyStream.toBytes());
        return http.StreamedResponse(const Stream.empty(), 200);
      });

      final provider = _FakeProvider(
        target: const PresignedUploadTarget(
          url: 'https://r2.example.com/bucket/object-key',
          method: 'PUT',
          headers: {
            'Content-Type': 'image/jpeg',
            'Content-Length': '9999', // must be stripped, not sent verbatim
            'If-None-Match': '*',
          },
        ),
        client: client,
      );

      final data = _data('hello world');
      final result = await provider.saveFile(_uri('photo.jpg'), data);

      expect(result.isSuccess, isTrue);
      expect(provider.completedFilenames, ['photo.jpg']);

      final request = capturedRequest!;
      expect(request.method, 'PUT');
      expect(request.headers['Content-Type'], 'image/jpeg');
      expect(request.headers['If-None-Match'], '*');
      // Content-Length must not be forwarded through the headers map.
      expect(
        request.headers.keys.any((k) => k.toLowerCase() == 'content-length'),
        isFalse,
      );
      expect(request.contentLength, data.lengthInBytes);
      expect(capturedBody, data);
    });

    test('412 with If-None-Match applied is treated as already-uploaded',
        () async {
      final client = MockClient.streaming((request, bodyStream) async {
        await bodyStream.toBytes();
        return http.StreamedResponse(const Stream.empty(), 412);
      });

      final provider = _FakeProvider(
        target: const PresignedUploadTarget(
          url: 'https://r2.example.com/bucket/object-key',
          headers: {
            'Content-Type': 'image/jpeg',
            'If-None-Match': '*',
          },
        ),
        client: client,
      );

      final result = await provider.saveFile(_uri('photo.jpg'), _data('hi'));

      expect(result.isSuccess, isTrue);
      expect(provider.completedFilenames, ['photo.jpg']);
    });

    test('412 without If-None-Match applied remains a failure', () async {
      final client = MockClient.streaming((request, bodyStream) async {
        await bodyStream.toBytes();
        return http.StreamedResponse(const Stream.empty(), 412);
      });

      final provider = _FakeProvider(
        target: const PresignedUploadTarget(
          url: 'https://r2.example.com/bucket/object-key',
          headers: {'Content-Type': 'image/jpeg'},
        ),
        client: client,
      );

      final result = await provider.saveFile(_uri('photo.jpg'), _data('hi'));

      expect(result.isFailure, isTrue);
      expect(provider.completedFilenames, isEmpty);
    });

    test('non-2xx PUT status is a failure and does not call onSaveComplete',
        () async {
      final client = MockClient.streaming((request, bodyStream) async {
        await bodyStream.toBytes();
        return http.StreamedResponse(const Stream.empty(), 500);
      });

      final provider = _FakeProvider(
        target: const PresignedUploadTarget(
          url: 'https://r2.example.com/bucket/object-key',
          headers: {'Content-Type': 'image/jpeg'},
        ),
        client: client,
      );

      final result = await provider.saveFile(_uri('photo.jpg'), _data('hi'));

      expect(result.isFailure, isTrue);
      expect(result.failure, isA<XStorageException>());
      expect(provider.completedFilenames, isEmpty);
    });

    test('onSaveComplete failure surfaces as Result.failure', () async {
      final client = MockClient.streaming((request, bodyStream) async {
        await bodyStream.toBytes();
        return http.StreamedResponse(const Stream.empty(), 200);
      });

      final provider = _FakeProvider(
        target: const PresignedUploadTarget(
          url: 'https://r2.example.com/bucket/object-key',
          headers: {'Content-Type': 'image/jpeg'},
        ),
        client: client,
        onSaveCompleteError: Exception('complete failed'),
      );

      final result = await provider.saveFile(_uri('photo.jpg'), _data('hi'));

      expect(result.isFailure, isTrue);
      expect(provider.completedFilenames, ['photo.jpg']);
    });
  });

  group(
      'PresignedUrlStorageProvider.saveFile without server-supplied headers',
      () {
    test('falls back to legacy uploadHeaders() behavior', () async {
      http.BaseRequest? capturedRequest;

      final client = MockClient.streaming((request, bodyStream) async {
        capturedRequest = request;
        await bodyStream.toBytes();
        return http.StreamedResponse(const Stream.empty(), 200);
      });

      final provider = _FakeProvider(
        target: const PresignedUploadTarget(
          url: 'https://legacy.example.com/bucket/object-key',
          headers: null,
        ),
        client: client,
        legacyUploadHeaders: ({
          required dirs,
          required filename,
          contentType,
        }) =>
            {'Content-Type': contentType ?? 'application/octet-stream'},
      );

      final result = await provider.saveFile(_uri('photo.jpg'), _data('hi'));

      expect(result.isSuccess, isTrue);
      expect(capturedRequest!.headers['Content-Type'], 'image/jpeg');
      expect(provider.completedFilenames, ['photo.jpg']);
    });

    test(
        'legacy uploadHeaders() returning null removes content-type header',
        () async {
      http.BaseRequest? capturedRequest;

      final client = MockClient.streaming((request, bodyStream) async {
        capturedRequest = request;
        await bodyStream.toBytes();
        return http.StreamedResponse(const Stream.empty(), 200);
      });

      final provider = _FakeProvider(
        target: const PresignedUploadTarget(
          url: 'https://legacy.example.com/bucket/object-key',
          headers: null,
        ),
        client: client,
        legacyUploadHeaders: ({
          required dirs,
          required filename,
          contentType,
        }) =>
            null,
      );

      final result = await provider.saveFile(_uri('photo.jpg'), _data('hi'));

      expect(result.isSuccess, isTrue);
      expect(
        capturedRequest!.headers.keys
            .any((k) => k.toLowerCase() == 'content-type'),
        isFalse,
      );
    });
  });

  group('fetchUploadPresignedUrl failure', () {
    test('exception from fetchUploadPresignedUrl surfaces as failure',
        () async {
      final provider = _ThrowingUploadUrlProvider();

      final result = await provider.saveFile(_uri('photo.jpg'), _data('hi'));

      expect(result.isFailure, isTrue);
    });
  });
}
