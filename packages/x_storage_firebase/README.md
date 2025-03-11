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

# x_storage_firebase

A package that provides Firebase Storage driver for XStorage. It enables file operations such as saving, loading, and deleting files using Firebase Storage.

## Features

- XStorage driver implementation for Firebase Storage
- File save, load, delete, and existence check operations
- Compliance with Firebase Storage security rules

## Getting Started

### Installation

```yaml
dependencies:
  x_storage_firebase: ^0.0.1
  x_storage_core: ^0.0.1
  firebase_storage: ^11.2.6
```

### Firebase Initialization

First, set up your Firebase project and perform the necessary initialization:

```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:x_storage_firebase/x_storage_firebase.dart';
import 'package:x_storage_core/x_storage_core.dart';

// Initialize Firebase
await Firebase.initializeApp();

// Create XStorage instance
final storage = XStorage();

// Register Firebase Storage driver
final firebaseStorage = FirebaseStorage.instance;
storage.registerDriver(FirebaseXStorageDriver(firebaseStorage: firebaseStorage));
```

### Basic Usage

```dart
// Save a file
await storage.saveFile(
  XStorageUri.create('firebase', 'path/to/file.txt'),
  Uint8List.fromList([/* data */]),
);

// Load a file
final data = await storage.loadFile(
  XStorageUri.create('firebase', 'path/to/file.txt'),
);

// Delete a file
await storage.deleteFile(
  XStorageUri.create('firebase', 'path/to/file.txt'),
);

// Check if a file exists
final exists = await storage.exists(
  XStorageUri.create('firebase', 'path/to/file.txt'),
);
```

## Security

- Configure appropriate Firebase Storage security rules
- Use Firebase Authentication for operations that require authentication
- Implement proper access control when handling sensitive data

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
