/// Describes how to perform the PUT (or other method) upload against a
/// presigned URL returned by a storage backend.
///
/// Some backends (e.g. S3-compatible services signing specific headers such
/// as `Content-Type`, `Content-Length`, `If-None-Match`) require the client
/// to send back exactly the headers that were part of the signature. When
/// [headers] is non-null, [PresignedUrlStorageProvider.saveFile] sends them
/// verbatim (with the sole exception of `Content-Length`, which cannot be
/// set through the headers map on `http.StreamedRequest`).
///
/// When [headers] is null, the provider falls back to its legacy behavior
/// via the overridable `uploadHeaders()` method.
class PresignedUploadTarget {
  /// The presigned URL to send the upload request to.
  final String url;

  /// The HTTP method to use for the upload request. Defaults to `PUT`.
  final String method;

  /// Headers that must be sent verbatim with the upload request, as
  /// returned by the backend alongside the presigned URL. `null` means the
  /// backend did not supply headers, so legacy header behavior applies.
  final Map<String, String>? headers;

  const PresignedUploadTarget({
    required this.url,
    this.method = 'PUT',
    this.headers,
  });
}
