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

# x_storage_flutter

A package that provides Flutter widgets and services for XStorage. It includes Flutter-specific features such as image display widgets and audio playback services.

## Features

- `XStorageImage`: A widget that displays images from XStorage URIs
- `XStorageAudioService`: A service that plays audio from XStorage URIs

## Getting Started

### Installation

```yaml
dependencies:
  x_storage_flutter: ^0.0.1
  x_storage_core: ^0.0.1
```

### Image Display

```dart
import 'package:x_storage_flutter/x_storage_flutter.dart';
import 'package:x_storage_core/x_storage_core.dart';

// Create and configure XStorage instance
final storage = XStorage();
// Register drivers...

// Display an image
XStorageImage(
  uri: XStorageUri.create('my_storage', 'path/to/image.jpg'),
  xStorage: storage,
  width: 200,
  height: 200,
  fit: BoxFit.cover,
)
```

### Audio Playback

```dart
import 'package:x_storage_flutter/x_storage_flutter.dart';
import 'package:x_storage_core/x_storage_core.dart';

// Create and configure XStorage instance
final storage = XStorage();
// Register drivers...

// Create audio service
final audioService = XStorageAudioService(storage);

// Play audio
await audioService.play(
  XStorageUri.create('my_storage', 'path/to/audio.mp3'),
);

// Stop playback
await audioService.stop();
```

## Important Notes

- `XStorageImage` automatically detects the storage type and displays images accordingly
- `XStorageAudioService` currently only supports network-based storage
- Consider implementing appropriate caching and redraw timing based on your use case

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
