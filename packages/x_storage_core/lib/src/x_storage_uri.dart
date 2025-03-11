/// An extension type that wraps [Uri] to provide simplified creation methods
/// for storage URIs.
///
/// This type implements [Uri] and provides convenient methods for creating
/// storage URIs with specific schemes and paths.
///
/// Example:
/// ```dart
/// final uri = XStorageUri.create('s3', 'path/to/file.txt');
/// print(uri.scheme); // 's3'
/// print(uri.path); // '/path/to/file.txt'
/// ```
extension type XStorageUri(Uri uri) implements Uri {
  /// Creates a new [XStorageUri] with the specified scheme and path
  ///
  /// The [scheme] parameter specifies the storage type (e.g., 's3', 'file').
  /// The [path] parameter specifies the path to the resource.
  factory XStorageUri.create(String scheme, String path) {
    return XStorageUri(Uri.parse("$scheme:///$path"));
  }

  /// スキーマを変更する
  XStorageUri changeScheme(String scheme) {
    return XStorageUri(Uri.parse("$scheme:///$path"));
  }
}
