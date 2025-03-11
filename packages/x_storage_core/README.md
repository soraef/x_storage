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

- Unified storage interface (`XStorageProvider`)
- Base implementations for various storage providers
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

// Register a provider (example: custom provider)
class MyStorageProvider extends XStorageProvider with NetworkProviderMixin {
  @override
  String get scheme => 'my_storage';

  @override
  String get rootUrl => 'https://example.com';

  // Implement other methods...
}

// Register the provider
storage.registerProvider(MyStorageProvider());

// Save a file
await storage.saveFile(
  XUri.create('my_storage', 'path/to/file.txt'),
  Uint8List.fromList([/* data */]),
);

// Load a file
final data = await storage.loadFile(
  XUri.create('my_storage', 'path/to/file.txt'),
);

// Delete a file
await storage.deleteFile(
  XUri.create('my_storage', 'path/to/file.txt'),
);
```

## Creating Custom Providers

To create a provider for a new storage service, extend `XStorageProvider` and implement the required methods:

```dart
class CustomStorageProvider extends XStorageProvider with NetworkProviderMixin {
  @override
  String get scheme => 'custom';

  @override
  String get rootUrl => 'https://custom-storage.example.com';

  @override
  Future<void> saveFile(XUri uri, Uint8List data) async {
    // Implementation...
  }

  @override
  Future<Uint8List?> loadFile(XUri uri) async {
    // Implementation...
  }

  @override
  Future<void> deleteFile(XUri uri) async {
    // Implementation...
  }
}
```

## Available Mixins

- `NetworkProviderMixin`: For network-based storage
- `FileProviderMixin`: For file system-based storage
- `AssetProviderMixin`: For Flutter assets

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
