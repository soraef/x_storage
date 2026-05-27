import 'package:just_audio/just_audio.dart';
import 'package:x_storage_core/x_storage_core.dart';

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
    final providerResult = _xStorage.getProvider(uri);

    if (providerResult.isFailure) {
      throw Exception('Unsupported storage driver for audio playback');
    }

    final provider = providerResult.success;

    // Example: Only support network-based storage
    if (provider is NetworkProviderMixin) {
      await _playNetwork(provider, uri);
    }

    if (provider is FileProviderMixin) {
      await _playFile(provider, uri);
    }

    if (provider is AssetProviderMixin) {
      await _playAsset(provider, uri);
    }
  }

  void dispose() {
    _audioPlayer.dispose();
  }

  /// Stops the currently playing audio
  Future<void> stop() async {
    await _audioPlayer.stop();
  }

  Future<void> setVolume(double volume) async {
    await _audioPlayer.setVolume(volume);
  }

  Future<void> setLoop(bool loop) async {
    await _audioPlayer.setLoopMode(loop ? LoopMode.all : LoopMode.off);
  }

  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  Future<void> resume() async {
    await _audioPlayer.play();
  }

  Future<void> setSpeed(double speed) async {
    await _audioPlayer.setSpeed(speed);
  }

  Future<void> _playNetwork(NetworkProviderMixin provider, XUri uri) async {
    final audioUrl = await provider.getNetworkUrl(uri);
    await _audioPlayer.setUrl(audioUrl.toString());
    await _audioPlayer.play();
  }

  Future<void> _playFile(FileProviderMixin provider, XUri uri) async {
    final file = await provider.getFilePath(uri);
    await _audioPlayer.setFilePath(file);
    await _audioPlayer.play();
  }

  Future<void> _playAsset(AssetProviderMixin provider, XUri uri) async {
    final asset = provider.assetName(uri);
    await _audioPlayer.setAsset(asset);
    await _audioPlayer.play();
  }
}
