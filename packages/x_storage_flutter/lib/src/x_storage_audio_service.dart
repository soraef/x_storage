import 'package:just_audio/just_audio.dart';
import 'package:x_storage_core/x_storage_core.dart';
import 'package:flutter/foundation.dart';

/// A simple service example that plays audio only through network storage
/// (using NetworkProviderMixin)
///
/// This service demonstrates basic audio playback functionality for
/// network-based storage drivers.
class XStorageAudioService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final XStorage _xStorage;

  /// Creates a new [XStorageAudioService] instance
  ///
  /// [_xStorage] is the XStorage instance to use for loading audio files
  XStorageAudioService(this._xStorage);

  /// Plays audio from the specified URI
  ///
  /// Throws an exception if the storage driver doesn't support network access
  /// (i.e., doesn't implement NetworkProviderMixin)
  Future<void> play(XUri uri) async {
    await stop();
    final driver = _xStorage.getProvider(uri);

    // Example: Only support network-based storage
    if (driver is! NetworkProviderMixin) {
      throw Exception('Unsupported storage driver for audio playback');
    }

    final audioUrl = await driver.getNetworkUrl(uri);

    try {
      await _audioPlayer.setUrl(audioUrl.toString());
      await _audioPlayer.play();
    } catch (e) {
      debugPrint('Error playing audio: $e');
    }
  }

  /// Stops the currently playing audio
  Future<void> stop() async {
    await _audioPlayer.stop();
  }
}
