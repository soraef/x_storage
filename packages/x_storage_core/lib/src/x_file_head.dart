/// Metadata about a stored file, retrieved without downloading its contents.
///
/// Returned by `XStorage.head` / `XStorageProvider.head`. All fields are
/// optional because not every storage backend exposes every value (for
/// example a plain HTTP HEAD response may omit `Last-Modified`).
class XFileHead {
  /// File size in bytes, if known.
  final int? size;

  /// MIME content type (e.g. `image/png`), if known.
  final String? contentType;

  /// Last modified time, if known.
  final DateTime? lastModified;

  const XFileHead({
    this.size,
    this.contentType,
    this.lastModified,
  });

  @override
  String toString() =>
      'XFileHead(size: $size, contentType: $contentType, lastModified: $lastModified)';
}
