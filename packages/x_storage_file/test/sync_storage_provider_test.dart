import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:type_result/type_result.dart';
import 'package:x_storage_core/x_storage_core.dart';
import 'package:x_storage_file/x_storage_file.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class FakeFileStorageProvider extends FileStorageProvider {
  @override
  final String scheme;

  final Map<String, Uint8List> store = {};

  FakeFileStorageProvider({this.scheme = 'file'});

  @override
  Future<Result<void, XStorageException>> saveFile(
      XUri uri, Uint8List data) async {
    store[uri.toString()] = data;
    return Result.success(null);
  }

  @override
  Future<Result<Uint8List, XStorageException>> loadFile(XUri uri) async {
    final data = store[uri.toString()];
    if (data == null) return Result.failure(FileNotFoundException(uri));
    return Result.success(data);
  }

  @override
  Future<Result<void, XStorageException>> deleteFile(XUri uri) async {
    store.remove(uri.toString());
    return Result.success(null);
  }

  @override
  Future<bool> exists(XUri uri) async => store.containsKey(uri.toString());

  @override
  Future<String> getFilePath(XUri uri) async => '/fake${uri.path}';
}

class FakeRemoteProvider extends XStorageProvider {
  @override
  final String scheme;

  final Map<String, Uint8List> store = {};
  bool shouldFail = false;

  FakeRemoteProvider({this.scheme = 'remote'});

  @override
  XStorageType get storageType => XStorageType.network;

  @override
  Future<Result<void, XStorageException>> saveFile(
      XUri uri, Uint8List data) async {
    if (shouldFail) return Result.failure(UnknownException('fail'));
    store[uri.toString()] = data;
    return Result.success(null);
  }

  @override
  Future<Result<Uint8List, XStorageException>> loadFile(XUri uri) async {
    if (shouldFail) return Result.failure(UnknownException('fail'));
    final data = store[uri.toString()];
    if (data == null) return Result.failure(FileNotFoundException(uri));
    return Result.success(data);
  }

  @override
  Future<Result<void, XStorageException>> deleteFile(XUri uri) async {
    if (shouldFail) return Result.failure(UnknownException('fail'));
    store.remove(uri.toString());
    return Result.success(null);
  }

  @override
  Future<bool> exists(XUri uri) async {
    if (shouldFail) return false;
    return store.containsKey(uri.toString());
  }
}

class InMemorySyncMetadataStore extends SyncMetadataStore {
  final Map<String, SyncStatus> _store = {};

  @override
  Future<void> setStatus(XUri uri, SyncStatus status) async {
    _store[uri.toString()] = status;
  }

  @override
  Future<SyncStatus?> getStatus(XUri uri) async {
    return _store[uri.toString()];
  }

  @override
  Future<void> remove(XUri uri) async {
    _store.remove(uri.toString());
  }

  @override
  Future<List<XUri>> getByStatus(SyncStatus status) async {
    return _store.entries
        .where((e) => e.value == status)
        .map((e) => XUri(Uri.parse(e.key)))
        .toList();
  }

  @override
  Future<int> countByStatus(SyncStatus status) async {
    return _store.values.where((v) => v == status).length;
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

XUri _uri(String path) => XUri.create('sync', path);

Uint8List _data(String s) => Uint8List.fromList(s.codeUnits);

/// Returns the URI as it would appear in the local provider's store
XUri _localKey(XUri uri) => uri.changeScheme('file');

/// Returns the URI as it would appear in the remote provider's store
XUri _remoteKey(XUri uri, String remoteScheme) =>
    uri.changeScheme(remoteScheme);

void main() {
  late FakeFileStorageProvider local;
  late InMemorySyncMetadataStore metadata;

  setUp(() {
    local = FakeFileStorageProvider();
    metadata = InMemorySyncMetadataStore();
  });

  // =========================================================================
  // Group 1: remote なし
  // =========================================================================
  group('without remote', () {
    late SyncStorageProvider sut;

    setUp(() {
      sut = SyncStorageProvider(
        scheme: 'sync',
        local: local,
        metadataStore: metadata,
      );
    });

    test('hasRemote is false', () {
      expect(sut.hasRemote, isFalse);
    });

    test('saveFile stores locally with localOnly status', () async {
      final uri = _uri('a.txt');
      final result = await sut.saveFile(uri, _data('hello'));

      expect(result.isSuccess, isTrue);
      expect(await local.exists(_localKey(uri)), isTrue);
      expect(await metadata.getStatus(uri), SyncStatus.localOnly);
    });

    test('loadFile returns local data', () async {
      final uri = _uri('a.txt');
      await sut.saveFile(uri, _data('hello'));

      final result = await sut.loadFile(uri);
      expect(result.isSuccess, isTrue);
      expect(result.success, _data('hello'));
    });

    test('loadFile returns failure when not found', () async {
      final result = await sut.loadFile(_uri('missing.txt'));
      expect(result.isFailure, isTrue);
    });

    test('deleteFile removes local file and metadata', () async {
      final uri = _uri('a.txt');
      await sut.saveFile(uri, _data('hello'));

      final result = await sut.deleteFile(uri);
      expect(result.isSuccess, isTrue);
      expect(await local.exists(_localKey(uri)), isFalse);
      expect(await metadata.getStatus(uri), isNull);
    });

    test('exists checks local only', () async {
      final uri = _uri('a.txt');
      expect(await sut.exists(uri), isFalse);

      await sut.saveFile(uri, _data('hello'));
      expect(await sut.exists(uri), isTrue);
    });

    test('syncPending returns 0', () async {
      await sut.saveFile(_uri('a.txt'), _data('hello'));
      expect(await sut.syncPending(), 0);
    });

    test('syncAll returns 0', () async {
      await sut.saveFile(_uri('a.txt'), _data('hello'));
      expect(await sut.syncAll(), 0);
    });

    test('verifyStatus returns localOnly', () async {
      final uri = _uri('a.txt');
      await sut.saveFile(uri, _data('hello'));

      expect(await sut.verifyStatus(uri), SyncStatus.localOnly);
    });

    test('removeFromRemote is no-op', () async {
      final uri = _uri('a.txt');
      await sut.saveFile(uri, _data('hello'));
      final statusBefore = await metadata.getStatus(uri);

      await sut.removeFromRemote(uri);

      expect(await metadata.getStatus(uri), statusBefore);
    });

    test('uploadToRemote returns UnsupportedOperationException', () async {
      final uri = _uri('a.txt');
      await sut.saveFile(uri, _data('hello'));

      final result = await sut.uploadToRemote(uri);
      expect(result.isFailure, isTrue);
      expect(result.failure, isA<UnsupportedOperationException>());
    });

    test('pendingCount is 0', () async {
      await sut.saveFile(_uri('a.txt'), _data('hello'));
      expect(await sut.pendingCount, 0);
    });

    test('getSyncStatus returns stored status', () async {
      final uri = _uri('a.txt');
      expect(await sut.getSyncStatus(uri), isNull);

      await sut.saveFile(uri, _data('hello'));
      expect(await sut.getSyncStatus(uri), SyncStatus.localOnly);
    });
  });

  // =========================================================================
  // Group 2: remote あり
  // =========================================================================
  group('with remote', () {
    late FakeRemoteProvider remote;
    late SyncStorageProvider sut;

    setUp(() {
      remote = FakeRemoteProvider();
      sut = SyncStorageProvider(
        scheme: 'sync',
        local: local,
        remote: remote,
        metadataStore: metadata,
      );
    });

    test('hasRemote is true', () {
      expect(sut.hasRemote, isTrue);
    });

    // --- saveFile ---

    test('saveFile: remote success → synced', () async {
      final uri = _uri('a.txt');
      final result = await sut.saveFile(uri, _data('hello'));

      expect(result.isSuccess, isTrue);
      expect(await local.exists(_localKey(uri)), isTrue);
      expect(await remote.exists(_remoteKey(uri, 'remote')), isTrue);
      expect(await metadata.getStatus(uri), SyncStatus.synced);
    });

    test('saveFile: remote failure → pendingUpload', () async {
      remote.shouldFail = true;
      final uri = _uri('a.txt');
      final result = await sut.saveFile(uri, _data('hello'));

      expect(result.isSuccess, isTrue); // local succeeded
      expect(await local.exists(_localKey(uri)), isTrue);
      expect(await metadata.getStatus(uri), SyncStatus.pendingUpload);
    });

    // --- loadFile ---

    test('loadFile: local hit → returns local data', () async {
      final uri = _uri('a.txt');
      await sut.saveFile(uri, _data('hello'));

      final result = await sut.loadFile(uri);
      expect(result.isSuccess, isTrue);
      expect(result.success, _data('hello'));
    });

    test('loadFile: local miss → falls back to remote and caches', () async {
      final uri = _uri('a.txt');
      // Put data only in remote
      final remoteUri = _remoteKey(uri, 'remote');
      remote.store[remoteUri.toString()] = _data('from-remote');

      final result = await sut.loadFile(uri);
      expect(result.isSuccess, isTrue);
      expect(result.success, _data('from-remote'));

      // Should be cached locally now
      expect(await local.exists(_localKey(uri)), isTrue);
      expect(await metadata.getStatus(uri), SyncStatus.synced);
    });

    test('loadFile: both miss → failure', () async {
      final result = await sut.loadFile(_uri('missing.txt'));
      expect(result.isFailure, isTrue);
    });

    // --- deleteFile ---

    test('deleteFile: remote success → metadata removed', () async {
      final uri = _uri('a.txt');
      await sut.saveFile(uri, _data('hello'));

      final result = await sut.deleteFile(uri);
      expect(result.isSuccess, isTrue);
      expect(await local.exists(_localKey(uri)), isFalse);
      expect(await remote.exists(_remoteKey(uri, 'remote')), isFalse);
      expect(await metadata.getStatus(uri), isNull);
    });

    test('deleteFile: remote failure → pendingDelete', () async {
      final uri = _uri('a.txt');
      await sut.saveFile(uri, _data('hello'));

      remote.shouldFail = true;
      final result = await sut.deleteFile(uri);
      expect(result.isSuccess, isTrue); // local succeeded
      expect(await metadata.getStatus(uri), SyncStatus.pendingDelete);
    });

    // --- exists ---

    test('exists: local true → true', () async {
      final uri = _uri('a.txt');
      await sut.saveFile(uri, _data('hello'));
      expect(await sut.exists(uri), isTrue);
    });

    test('exists: local false, remote true → true', () async {
      final uri = _uri('a.txt');
      final remoteUri = _remoteKey(uri, 'remote');
      remote.store[remoteUri.toString()] = _data('data');
      expect(await sut.exists(uri), isTrue);
    });

    test('exists: both false → false', () async {
      expect(await sut.exists(_uri('missing.txt')), isFalse);
    });

    // --- syncPending ---

    test('syncPending: uploads pendingUpload files', () async {
      final uri = _uri('a.txt');
      remote.shouldFail = true;
      await sut.saveFile(uri, _data('hello'));
      expect(await metadata.getStatus(uri), SyncStatus.pendingUpload);

      remote.shouldFail = false;
      final failCount = await sut.syncPending();
      expect(failCount, 0);
      expect(await metadata.getStatus(uri), SyncStatus.synced);
      expect(await remote.exists(_remoteKey(uri, 'remote')), isTrue);
    });

    test('syncPending: deletes pendingDelete files', () async {
      final uri = _uri('a.txt');
      await sut.saveFile(uri, _data('hello'));

      remote.shouldFail = true;
      await sut.deleteFile(uri);
      expect(await metadata.getStatus(uri), SyncStatus.pendingDelete);

      remote.shouldFail = false;
      final failCount = await sut.syncPending();
      expect(failCount, 0);
      expect(await metadata.getStatus(uri), isNull);
      expect(await remote.exists(_remoteKey(uri, 'remote')), isFalse);
    });

    test('syncPending: returns failure count', () async {
      remote.shouldFail = true;
      await sut.saveFile(_uri('a.txt'), _data('a'));
      await sut.saveFile(_uri('b.txt'), _data('b'));
      // both are pendingUpload, remote still failing
      final failCount = await sut.syncPending();
      expect(failCount, 2);
    });

    // --- syncAll ---

    test('syncAll: uploads localOnly and pendingUpload', () async {
      // Create a localOnly file by saving without remote
      final noRemote = SyncStorageProvider(
        scheme: 'sync',
        local: local,
        metadataStore: metadata,
      );
      await noRemote.saveFile(_uri('local.txt'), _data('local'));
      expect(await metadata.getStatus(_uri('local.txt')), SyncStatus.localOnly);

      // Create a pendingUpload file
      remote.shouldFail = true;
      await sut.saveFile(_uri('pending.txt'), _data('pending'));
      expect(await metadata.getStatus(_uri('pending.txt')),
          SyncStatus.pendingUpload);

      remote.shouldFail = false;
      final failCount = await sut.syncAll();
      expect(failCount, 0);
      expect(
          await metadata.getStatus(_uri('local.txt')), SyncStatus.synced);
      expect(
          await metadata.getStatus(_uri('pending.txt')), SyncStatus.synced);
      expect(
          await remote.exists(_remoteKey(_uri('local.txt'), 'remote')), isTrue);
      expect(
          await remote.exists(_remoteKey(_uri('pending.txt'), 'remote')),
          isTrue);
    });

    test('syncAll: returns failure count', () async {
      remote.shouldFail = true;
      await sut.saveFile(_uri('a.txt'), _data('a'));
      // remote still failing
      final failCount = await sut.syncAll();
      expect(failCount, 1);
    });

    // --- verifyStatus ---

    test('verifyStatus: synced but remote missing → localOnly', () async {
      final uri = _uri('a.txt');
      await sut.saveFile(uri, _data('hello'));
      expect(await metadata.getStatus(uri), SyncStatus.synced);

      // Remove from remote behind the scenes
      remote.store.remove(_remoteKey(uri, 'remote').toString());

      final status = await sut.verifyStatus(uri);
      expect(status, SyncStatus.localOnly);
      expect(await metadata.getStatus(uri), SyncStatus.localOnly);
    });

    test('verifyStatus: localOnly but remote exists → synced', () async {
      final uri = _uri('a.txt');
      await metadata.setStatus(uri, SyncStatus.localOnly);
      final remoteUri = _remoteKey(uri, 'remote');
      remote.store[remoteUri.toString()] = _data('hello');

      final status = await sut.verifyStatus(uri);
      expect(status, SyncStatus.synced);
      expect(await metadata.getStatus(uri), SyncStatus.synced);
    });

    // --- removeFromRemote ---

    test('removeFromRemote: deletes remote and sets localOnly', () async {
      final uri = _uri('a.txt');
      await sut.saveFile(uri, _data('hello'));
      expect(await remote.exists(_remoteKey(uri, 'remote')), isTrue);

      await sut.removeFromRemote(uri);
      expect(await remote.exists(_remoteKey(uri, 'remote')), isFalse);
      expect(await metadata.getStatus(uri), SyncStatus.localOnly);
    });

    // --- uploadToRemote ---

    test('uploadToRemote: success → synced', () async {
      final uri = _uri('a.txt');
      // Save locally only (using local provider directly)
      await local.saveFile(_localKey(uri), _data('hello'));
      await metadata.setStatus(uri, SyncStatus.localOnly);

      final result = await sut.uploadToRemote(uri);
      expect(result.isSuccess, isTrue);
      expect(await remote.exists(_remoteKey(uri, 'remote')), isTrue);
      expect(await metadata.getStatus(uri), SyncStatus.synced);
    });

    test('uploadToRemote: local data missing → failure', () async {
      final uri = _uri('a.txt');
      final result = await sut.uploadToRemote(uri);
      expect(result.isFailure, isTrue);
    });

    test('uploadToRemote: remote failure → failure', () async {
      final uri = _uri('a.txt');
      await local.saveFile(_localKey(uri), _data('hello'));
      remote.shouldFail = true;

      final result = await sut.uploadToRemote(uri);
      expect(result.isFailure, isTrue);
    });
  });

  // =========================================================================
  // Group 3: setRemote
  // =========================================================================
  group('setRemote', () {
    late SyncStorageProvider sut;

    setUp(() {
      sut = SyncStorageProvider(
        scheme: 'sync',
        local: local,
        metadataStore: metadata,
      );
    });

    test('hasRemote becomes true after setRemote', () async {
      expect(sut.hasRemote, isFalse);
      await sut.setRemote(FakeRemoteProvider());
      expect(sut.hasRemote, isTrue);
    });

    test('resetStatus=true: synced → localOnly', () async {
      final uri = _uri('a.txt');
      await metadata.setStatus(uri, SyncStatus.synced);

      await sut.setRemote(FakeRemoteProvider(), resetStatus: true);
      expect(await metadata.getStatus(uri), SyncStatus.localOnly);
    });

    test('resetStatus=true: pendingDelete → removed', () async {
      final uri = _uri('a.txt');
      await metadata.setStatus(uri, SyncStatus.pendingDelete);

      await sut.setRemote(FakeRemoteProvider(), resetStatus: true);
      expect(await metadata.getStatus(uri), isNull);
    });

    test('resetStatus=true: pendingUpload → unchanged', () async {
      final uri = _uri('a.txt');
      await metadata.setStatus(uri, SyncStatus.pendingUpload);

      await sut.setRemote(FakeRemoteProvider(), resetStatus: true);
      expect(await metadata.getStatus(uri), SyncStatus.pendingUpload);
    });

    test('resetStatus=false: no metadata changes', () async {
      final uri = _uri('a.txt');
      await metadata.setStatus(uri, SyncStatus.synced);

      await sut.setRemote(FakeRemoteProvider(), resetStatus: false);
      expect(await metadata.getStatus(uri), SyncStatus.synced);
    });

    test('CRUD uses new remote after setRemote', () async {
      final newRemote = FakeRemoteProvider(scheme: 'new-remote');
      await sut.setRemote(newRemote);

      final uri = _uri('a.txt');
      await sut.saveFile(uri, _data('hello'));

      expect(
          await newRemote.exists(_remoteKey(uri, 'new-remote')), isTrue);
      expect(await metadata.getStatus(uri), SyncStatus.synced);
    });
  });

  // =========================================================================
  // Group 4: getFilePath
  // =========================================================================
  group('getFilePath', () {
    test('delegates to local provider', () async {
      final sut = SyncStorageProvider(
        scheme: 'sync',
        local: local,
        metadataStore: metadata,
      );

      final uri = _uri('a.txt');
      final path = await sut.getFilePath(uri);
      final expectedPath = await local.getFilePath(_localKey(uri));
      expect(path, expectedPath);
    });
  });
}
