import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:x_storage_core/x_storage_core.dart';

/// 同期メタデータの永続化インターフェース
abstract class SyncMetadataStore {
  Future<void> setStatus(XUri uri, SyncStatus status);
  Future<SyncStatus?> getStatus(XUri uri);
  Future<void> remove(XUri uri);
  Future<List<XUri>> getByStatus(SyncStatus status);
  Future<int> countByStatus(SyncStatus status);
  Future<List<XUri>> getAll();
}

/// JSONファイルで永続化する [SyncMetadataStore] 実装
///
/// メモリキャッシュを持ち、変更時にファイルへ書き出す。
class JsonSyncMetadataStore extends SyncMetadataStore {
  final String filePath;
  Map<String, String>? _cache;
  Future<void> _tail = Future.value();

  Future<T> _serialized<T>(Future<T> Function() action) {
    final operation = _tail.then((_) => action());
    _tail = operation.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return operation;
  }

  JsonSyncMetadataStore({required this.filePath});

  Future<Map<String, String>> _load() async {
    if (_cache != null) return _cache!;
    final file = File(filePath);
    if (await file.exists()) {
      final content = await file.readAsString();
      final decoded = jsonDecode(content) as Map<String, dynamic>;
      _cache = decoded.map((k, v) => MapEntry(k, v as String));
    } else {
      _cache = {};
    }
    return _cache!;
  }

  Future<void> _save() async {
    final file = File(filePath);
    final parent = file.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }
    final temporary = File('$filePath.writing');
    await temporary.writeAsString(jsonEncode(_cache), flush: true);
    await temporary.rename(filePath);
  }

  String _key(XUri uri) => uri.toString();

  String _statusToString(SyncStatus status) => status.name;

  SyncStatus _statusFromString(String value) {
    return SyncStatus.values.firstWhere((e) => e.name == value);
  }

  @override
  Future<void> setStatus(XUri uri, SyncStatus status) => _serialized(() async {
        final data = await _load();
        data[_key(uri)] = _statusToString(status);
        try {
          await _save();
        } catch (_) {
          _cache = null;
          rethrow;
        }
      });

  @override
  Future<SyncStatus?> getStatus(XUri uri) => _serialized(() async {
        final data = await _load();
        final value = data[_key(uri)];
        if (value == null) return null;
        return _statusFromString(value);
      });

  @override
  Future<void> remove(XUri uri) => _serialized(() async {
        final data = await _load();
        data.remove(_key(uri));
        try {
          await _save();
        } catch (_) {
          _cache = null;
          rethrow;
        }
      });

  @override
  Future<List<XUri>> getByStatus(SyncStatus status) => _serialized(() async {
        final data = await _load();
        final statusStr = _statusToString(status);
        return data.entries
            .where((e) => e.value == statusStr)
            .map((e) => XUri(Uri.parse(e.key)))
            .toList();
      });

  @override
  Future<int> countByStatus(SyncStatus status) => _serialized(() async {
        final data = await _load();
        final statusStr = _statusToString(status);
        return data.values.where((v) => v == statusStr).length;
      });

  @override
  Future<List<XUri>> getAll() => _serialized(() async {
        final data = await _load();
        return data.keys.map((k) => XUri(Uri.parse(k))).toList();
      });
}
