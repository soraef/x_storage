<!--
This README describes the package. If you publish this package to pub.dev,
this README's contents appear on the landing page for your package.

For information about how to write a good package README, see the guide for
[writing package pages](https://dart.dev/tools/pub/writing-package-pages).

For general information about developing packages, see the Dart guide for
[creating packages](https://dart.dev/guides/libraries/create-packages)
and the Flutter guide for
[developing packages and plugins](https://flutter.dev/developing-packages).
-->

# x_storage_core

XStorage is a Flutter package that provides a unified interface for handling different storage services (Firebase Storage, local file system, etc.). This package provides the core functionality of XStorage.

## Features

- Unified storage interface (`XStorageDriver`)
- Base implementations for various storage drivers
- Basic file operations (read, write, delete, existence check)
- URI-based file management

## Getting Started

### Installation

```yaml
dependencies:
  x_storage_core: ^0.0.1
```

### Basic Usage

```dart
import 'package:x_storage_core/x_storage_core.dart';

// Create XStorage instance
final storage = XStorage();

// Register a driver (example: custom driver)
class MyStorageDriver extends XStorageDriver with NetworkXStorageMixin {
  @override
  String get scheme => 'my_storage';

  @override
  String get rootUrl => 'https://example.com';

  // Implement other methods...
}

// Register the driver
storage.registerDriver(MyStorageDriver());

// Save a file
await storage.saveFile(
  XStorageUri.create('my_storage', 'path/to/file.txt'),
  Uint8List.fromList([/* data */]),
);

// Load a file
final data = await storage.loadFile(
  XStorageUri.create('my_storage', 'path/to/file.txt'),
);

// Delete a file
await storage.deleteFile(
  XStorageUri.create('my_storage', 'path/to/file.txt'),
);
```

## Creating Custom Drivers

To create a driver for a new storage service, extend `XStorageDriver` and implement the required methods:

```dart
class CustomStorageDriver extends XStorageDriver with NetworkXStorageMixin {
  @override
  String get scheme => 'custom';

  @override
  String get rootUrl => 'https://custom-storage.example.com';

  @override
  Future<void> saveFile(XStorageUri uri, Uint8List data) async {
    // Implementation...
  }

  @override
  Future<Uint8List?> loadFile(XStorageUri uri) async {
    // Implementation...
  }

  @override
  Future<void> deleteFile(XStorageUri uri) async {
    // Implementation...
  }
}
```

## Available Mixins

- `NetworkXStorageMixin`: For network-based storage
- `FileXStorageMixin`: For file system-based storage
- `AssetXStorageMixin`: For Flutter assets

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
