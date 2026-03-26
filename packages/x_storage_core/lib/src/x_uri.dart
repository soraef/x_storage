/// An extension type that wraps [Uri] to provide simplified creation methods
/// for storage URIs.
///
/// This type implements [Uri] and provides convenient methods for creating
/// storage URIs with specific schemes and paths.
///
/// Example:
/// ```dart
/// final uri = XUri.create('s3', 'path/to/file.txt');
/// print(uri.scheme); // 's3'
/// print(uri.path); // '/path/to/file.txt'
/// ```
extension type XUri(Uri uri) implements Uri {
  /// Creates a new [XUri] with the specified scheme and path
  ///
  /// The [scheme] parameter specifies the storage type (e.g., 's3', 'file').
  /// The [path] parameter specifies the path to the resource.
  factory XUri.create(String scheme, String path) {
    return XUri(Uri.parse("$scheme:///$path"));
  }

  /// スキーマを変更する
  XUri changeScheme(String scheme) {
    return XUri(uri.replace(scheme: scheme));
  }
}
