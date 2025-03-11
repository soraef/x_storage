/// Enum representing the type of storage
///
/// Defines different types of storage that can be used in the XStorage system:
/// - [asset]: Asset storage (e.g., Flutter assets)
/// - [network]: Network-based storage (e.g., HTTP/HTTPS)
/// - [file]: File system storage
/// - [other]: Other storage types
enum XStorageType {
  /// Asset storage type (e.g., Flutter assets)
  asset,

  /// Network-based storage type (e.g., HTTP/HTTPS)
  network,

  /// File system storage type
  file,

  /// Other storage types
  other,
}
