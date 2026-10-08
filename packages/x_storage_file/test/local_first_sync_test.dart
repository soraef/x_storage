import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:type_result/type_result.dart';
import 'package:x_storage_core/x_storage_core.dart';
import 'package:x_storage_file/x_storage_file.dart';

class DiskProvider extends FileStorageProvider {
  DiskProvider(this.root);
  final String root;
  @override
  Future<String> getFilePath(XUri uri) async => '$root${uri.path}';
}

class PausedRemote extends XStorageProvider {
  @override
  String get scheme => 'remote';
  @override
  XStorageType get storageType => XStorageType.other;
  final started = Completer<void>();
  final release = Completer<void>();
  final files = <String, Uint8List>{};
  bool pause = true;
  @override
  Future<Result<void, XStorageException>> saveFile(
      XUri uri, Uint8List data) async {
    if (!started.isCompleted) started.complete();
    if (pause) await release.future;
    files[uri.toString()] = Uint8List.fromList(data);
    return Result.success(null);
  }

  @override
  Future<Result<Uint8List, XStorageException>> loadFile(XUri uri) async =>
      files.containsKey(uri.toString())
          ? Result.success(files[uri.toString()]!)
          : Result.failure(FileNotFoundException(uri));
  @override
  Future<Result<void, XStorageException>> deleteFile(XUri uri) async {
    files.remove(uri.toString());
    return Result.success(null);
  }

  @override
  Future<bool> exists(XUri uri) async => files.containsKey(uri.toString());
}

void main() {
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('xstorage-restart-');
  });
  tearDown(() async {
    await root.delete(recursive: true);
  });

  test(
      'five files commit while upload is paused; new provider discovers and uploads all five',
      () async {
    final local = DiskProvider(root.path);
    final path = '${root.path}/metadata.json';
    final remote = PausedRemote();
    final provider = SyncStorageProvider(
        scheme: 'sync',
        local: local,
        remote: remote,
        metadataStore: JsonSyncMetadataStore(filePath: path));
    final uris = List.generate(5, (i) => XUri.create('sync', 'images/$i.png'));
    for (var i = 0; i < 5; i++) {
      final result = await provider
          .saveFile(uris[i], Uint8List.fromList([i, 42]))
          .timeout(const Duration(seconds: 2));
      expect(result.isSuccess, isTrue);
    }
    await remote.started.future;
    final freshMetadata = JsonSyncMetadataStore(filePath: path);
    expect(await freshMetadata.getByStatus(SyncStatus.pendingUpload),
        hasLength(5));
    for (var i = 0; i < 5; i++) {
      expect((await provider.loadFile(uris[i])).success, [i, 42]);
    }
    // End the old session without allowing it to acknowledge an upload.
    provider.clearRemote();
    remote.release.complete();
    await provider.syncPending();
    final freshRemote = PausedRemote()..pause = false;
    final reopened = SyncStorageProvider(
        scheme: 'sync',
        local: DiskProvider(root.path),
        remote: freshRemote,
        metadataStore: JsonSyncMetadataStore(filePath: path));
    expect(await reopened.syncPending(), 0);
    expect(freshRemote.files, hasLength(5));
    for (final uri in uris) {
      expect(await reopened.getSyncStatus(uri), SyncStatus.synced);
    }
  });

  test('local-only files can later sync without changing their URI', () async {
    final provider = SyncStorageProvider(
        scheme: 'sync',
        local: DiskProvider(root.path),
        metadataStore:
            JsonSyncMetadataStore(filePath: '${root.path}/metadata.json'));
    final uri = XUri.create('sync', 'a.jpg');
    expect((await provider.saveFile(uri, Uint8List.fromList([4, 5]))).isSuccess,
        isTrue);
    expect(await provider.getSyncStatus(uri), SyncStatus.localOnly);
    final remote = PausedRemote()..pause = false;
    await provider.setRemote(remote);
    expect(await provider.syncAll(), 0);
    expect((await provider.loadFile(uri)).success, [4, 5]);
    expect(await provider.getSyncStatus(uri), SyncStatus.synced);
  });

  test(
      'overwriting during a paused upload does not block local save or acknowledge stale bytes',
      () async {
    final remote = PausedRemote();
    final provider = SyncStorageProvider(
        scheme: 'sync',
        local: DiskProvider(root.path),
        remote: remote,
        metadataStore:
            JsonSyncMetadataStore(filePath: '${root.path}/metadata.json'));
    final uri = XUri.create('sync', 'a.jpg');
    await provider.saveFile(uri, Uint8List.fromList([1]));
    await remote.started.future;
    await provider
        .saveFile(uri, Uint8List.fromList([2]))
        .timeout(const Duration(seconds: 2));
    expect((await provider.loadFile(uri)).success, [2]);
    expect(await provider.getSyncStatus(uri), SyncStatus.pendingUpload);
    remote.release.complete();
    await provider.syncPending();
    expect(remote.files[uri.changeScheme('remote').toString()], [2]);
    expect(await provider.getSyncStatus(uri), SyncStatus.synced);
  });

  test(
      'concurrent metadata updates survive reopening; incomplete staging is never read',
      () async {
    final path = '${root.path}/metadata.json';
    final metadata = JsonSyncMetadataStore(filePath: path);
    await Future.wait(List.generate(
        50,
        (i) => metadata.setStatus(
            XUri.create('sync', 'file-$i'), SyncStatus.pendingUpload)));
    await File('$path.writing').writeAsString('{partial');
    final reopened = JsonSyncMetadataStore(filePath: path);
    expect(await reopened.getAll(), hasLength(50));
    await reopened.setStatus(XUri.create('sync', 'new'), SyncStatus.localOnly);
    expect(await JsonSyncMetadataStore(filePath: path).getAll(), hasLength(51));
  });
}
