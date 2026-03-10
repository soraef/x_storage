# x_storage_core

XStorage is a Flutter package that provides a unified interface for handling different storage services (Firebase Storage, local file system, AWS S3, etc.). This package provides the core functionality of XStorage.

## Why XStorage?

File storage management in app development can be complex and time-consuming. Some common challenges include:

- **Using multiple storage services**: Having to use different APIs when you need both local and cloud storage in your app
- **Switching storage providers**: Need for extensive code changes when changing storage providers during development or production
- **Testing difficulties**: Complexity in creating mocks and building test environments
- **Error handling**: Implementing consistent error handling across different storage services

XStorage solves these challenges by providing a unified interface. It abstracts the type of storage and allows file operations through a consistent URI-based API.

## Key Features

- **Unified storage interface**: Operate different storage services through the same API via `XStorageProvider`
- **URI-based file management**: Handle files with a consistent path format regardless of storage type using `XUri`
- **Multiple provider support**: Register and use multiple storage services simultaneously
- **Basic file operations**: Support for read, write, delete, existence check, and other basic operations
- **Robust error handling**: Safe error handling using the `Result` type
- **Extensibility**: Easy creation of custom storage providers
- **File transfer between providers**: Support for transferring files between different storage services

## Understanding XUri

XUri is a core concept in XStorage that provides a unified way to reference files across different storage providers. It consists of:

```
scheme://path/to/file.ext
```

Where:
- **scheme**: Identifies the storage provider (e.g., 'file', 'firebase', 's3')
- **path**: The path to the file within that storage system

Examples:
```dart
// Local file reference
final localUri = XUri.create('file', 'documents/report.pdf');

// Firebase Storage reference
final firebaseUri = XUri.create('firebase', 'user_uploads/profile.jpg');

// S3 reference (using a presigned URL provider)
final s3Uri = XUri.create('s3', 'bucket/images/banner.png');
```

XUri allows your application to reference files in a storage-agnostic way. This means you can change storage providers without changing file references throughout your code.

## Available Storage Providers

The XStorage ecosystem offers these storage providers:

- **FileStorageProvider**: For local file system (`x_storage_file` package)
- **FirebaseStorageProvider**: For Firebase Storage (`x_storage_firebase` package)
- **PresignedUrlStorageProvider**: For storage services that use presigned URLs like AWS S3 (`x_storage_presigned_url` package)
- **AssetStorageProvider**: For Flutter assets (included in this package)

## Getting Started

### Installation

Add dependencies to your `pubspec.yaml`:

```yaml
dependencies:
  x_storage_core: ^0.0.1
  
  # Add additional provider packages as needed
  x_storage_file: ^0.0.1      # For file system
  x_storage_firebase: ^0.0.1  # For Firebase Storage
  x_storage_presigned_url: ^0.0.1  # For presigned URL storage
```

### Basic Usage

```dart
import 'package:x_storage_core/x_storage_core.dart';
import 'package:x_storage_file/x_storage_file.dart';
import 'package:x_storage_firebase/x_storage_firebase.dart';

void main() async {
  // Create XStorage instance
  final storage = XStorage();

  // Register providers
  storage.registerProvider(FileStorageProvider());
  storage.registerProvider(FirebaseStorageProvider(
    firebaseStorage: FirebaseStorage.instance,
  ));

  // Save a file (example: saving to local storage)
  final saveResult = await storage.saveFile(
    XUri.create('file', 'documents/myfile.txt'),
    Uint8List.fromList(utf8.encode('Hello, World!')),
  );
  
  // Error handling with Result type
  if (saveResult.isSuccess) {
    print('File saved successfully');
  } else {
    print('Error: ${saveResult.failure.message}');
  }

  // Load a file
  final loadResult = await storage.loadFile(
    XUri.create('file', 'documents/myfile.txt'),
  );
  
  if (loadResult.isSuccess) {
    final content = utf8.decode(loadResult.success);
    print('File content: $content');
  } else {
    print('Load error: ${loadResult.failure.message}');
  }

  // Check if file exists
  final exists = await storage.exists(
    XUri.create('file', 'documents/myfile.txt'),
  );
  print('Does file exist? $exists');

  // Delete a file
  final deleteResult = await storage.deleteFile(
    XUri.create('file', 'documents/myfile.txt'),
  );
  
  if (deleteResult.isSuccess) {
    print('File deleted');
  } else {
    print('Delete error: ${deleteResult.failure.message}');
  }
}
```

## Transferring Files Between Storage Providers

XStorage makes it easy to transfer files between different storage services:

```dart
// Example: Download from Firebase Storage to local storage
Future<void> downloadFromFirebaseToLocal() async {
  final storage = XStorage();
  
  // Register both providers
  storage.registerProvider(FileStorageProvider());
  storage.registerProvider(FirebaseStorageProvider(
    firebaseStorage: FirebaseStorage.instance,
  ));
  
  // Download file from Firebase URL
  final downloadResult = await storage.downloadFile(
    XUri.create('firebase', 'images/photo.jpg'),
    onProgress: (received, total) {
      final progress = (received / total * 100).toStringAsFixed(2);
      print('Download progress: $progress%');
    },
  );
  
  if (downloadResult.isSuccess) {
    final localUri = downloadResult.success;
    print('File saved locally: ${localUri.toString()}');
  } else {
    print('Download error: ${downloadResult.failure.message}');
  }
}
```

## Creating Custom Storage Providers

To support a new storage service, extend `XStorageProvider` and implement the required methods:

```dart
class CustomStorageProvider extends XStorageProvider with NetworkProviderMixin {
  @override
  String get scheme => 'custom';

  @override
  String get rootUrl => 'https://custom-storage.example.com';

  @override
  Future<Result<void, XStorageException>> saveFile(XUri uri, Uint8List data) async {
    try {
      // Implementation for uploading to your custom storage service
      // ...
      return Result.success(null);
    } catch (e) {
      return Result.failure(UnknownException(e));
    }
  }

  @override
  Future<Result<Uint8List, XStorageException>> loadFile(XUri uri) async {
    try {
      // Implementation for downloading from your custom storage service
      // ...
      if (/* file found */) {
        return Result.success(data);
      } else {
        return Result.failure(FileNotFoundException(uri));
      }
    } catch (e) {
      return Result.failure(UnknownException(e));
    }
  }

  @override
  Future<Result<void, XStorageException>> deleteFile(XUri uri) async {
    try {
      // Implementation for deleting from your custom storage service
      // ...
      return Result.success(null);
    } catch (e) {
      return Result.failure(UnknownException(e));
    }
  }

  @override
  Future<bool> exists(XUri uri) async {
    try {
      // Implementation for checking file existence
      // ...
      return /* boolean indicating existence */;
    } catch (e) {
      return false;
    }
  }
}
```

## Available Mixins and Their Benefits

XStorage provides mixins to facilitate implementation of different storage service types:

- **NetworkProviderMixin**: For network-based storage
  - Provides conversion from URI to network URL through the `getNetworkUrl` method
  - Ideal for implementing cloud storage services (Firebase, S3, etc.)

- **FileProviderMixin**: For file system-based storage
  - Provides conversion from URI to local file path through the `getFilePath` method
  - Ideal for implementing local storage in your app

- **AssetProviderMixin**: For Flutter assets
  - Provides functionality to access assets in Flutter apps
  - Ideal for loading resources bundled with the application

## Error Handling

XStorage uses the `Result<T, E>` type for concise and safe error handling:

```dart
// Example of file loading
final result = await storage.loadFile(XUri.create('file', 'document.txt'));

// Error handling using switch expression
switch (result) {
  case Success(value: final data):
    final text = utf8.decode(data);
    print('File content: $text');
    break;
  case Failure(value: final error):
    switch (error) {
      case FileNotFoundException():
        print('File not found');
        break;
      case AccessDeniedException():
        print('Access denied');
        break;
      default:
        print('An error occurred: ${error.message}');
        break;
    }
    break;
}
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
