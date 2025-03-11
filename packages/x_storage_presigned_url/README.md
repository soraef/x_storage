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

# x_storage_presigned_url

A storage driver package for XStorage that supports Presigned URL-based storage services such as AWS S3 and other S3-compatible storage services.

## Features

- Abstract driver implementation for Presigned URL-based storage
- File upload and download using Presigned URLs
- File existence check
- Support for AWS S3 and other S3-compatible storage services

## Getting Started

### Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  x_storage_presigned_url: ^0.0.1
  x_storage_core: ^0.0.1
```

### Implementing the Driver

To implement your own Presigned URL storage driver, extend the `PresignedUrlXStorageDriver` class:

```dart
import 'package:x_storage_presigned_url/x_storage_presigned_url.dart';
import 'package:x_storage_core/x_storage_core.dart';

class MyPresignedUrlDriver extends PresignedUrlXStorageDriver {
  @override
  String get scheme => 'my_storage';

  @override
  Future<String> fetchUploadPresignedUrl({
    required List<String> dirs,
    required String filename,
  }) async {
    // Implement your logic to generate Presigned URL for upload
    // Example: Generate using AWS SDK
    return 'https://...';
  }
}
```

### Basic Usage

```dart
// Create XStorage instance
final storage = XStorage();

// Register your custom driver
storage.registerDriver(MyPresignedUrlDriver());

// Save a file
await storage.saveFile(
  XStorageUri.create('my_storage', 'path/to/file.txt'),
  Uint8List.fromList([/* data */]),
);

// Load a file
final data = await storage.loadFile(
  XStorageUri.create('my_storage', 'path/to/file.txt'),
);

// Check if file exists
final exists = await storage.exists(
  XStorageUri.create('my_storage', 'path/to/file.txt'),
);
```

## Implementation Example

### AWS S3 Implementation

```dart
import 'package:aws_s3_api/aws_s3_api.dart';

class S3PresignedUrlDriver extends PresignedUrlXStorageDriver {
  final S3Client s3Client;
  final String bucketName;

  S3PresignedUrlDriver({
    required this.s3Client,
    required this.bucketName,
  });

  @override
  String get scheme => 's3';

  @override
  Future<String> fetchUploadPresignedUrl({
    required List<String> dirs,
    required String filename,
  }) async {
    final path = [...dirs, filename].join('/');
    final url = await s3Client.getPresignedUrl(
      'PUT',
      bucketName,
      path,
      expires: Duration(minutes: 15),
    );
    return url.toString();
  }
}
```

## Implementation Details

The `PresignedUrlXStorageDriver` provides the following features:

- Network operations implementation using `NetworkXStorageMixin`
- `saveFile`: File upload using PUT request with Presigned URL
- `loadFile`: File download using network URL
- `exists`: File existence check using HEAD request
- `deleteFile`: Currently not supported (throws `UnsupportedError`)

Methods that must be implemented when extending:

- `scheme`: Specify the storage scheme
- `fetchUploadPresignedUrl`: Generate Presigned URL for upload

## Security Considerations

- Set appropriate expiration times for Presigned URLs
- Securely manage API keys and secrets
- Configure proper bucket access permissions
- Set up CORS configuration as needed
- Use HTTPS for sensitive data transfer

## Limitations

- File deletion operation is not currently supported
- Presigned URL generation must be handled server-side
- Be mindful of URL expiration times

## Supported Storage Services

This driver can be used with storage services that support Presigned URLs, including:

- Amazon S3
- Google Cloud Storage (Signed URLs)
- Other S3-compatible storage services

## Additional Information

For more information about developing packages, see the Dart guide for
[creating packages](https://dart.dev/guides/libraries/create-packages)
and the Flutter guide for
[developing packages and plugins](https://flutter.dev/developing-packages).

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
