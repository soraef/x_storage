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
    await file.writeAsString(jsonEncode(_cache));
  }

  String _key(XUri uri) => uri.toString();

  String _statusToString(SyncStatus status) => status.name;

  SyncStatus _statusFromString(String value) {
    return SyncStatus.values.firstWhere((e) => e.name == value);
  }

  @override
  Future<void> setStatus(XUri uri, SyncStatus status) async {
    final data = await _load();
    data[_key(uri)] = _statusToString(status);
    await _save();
  }

  @override
  Future<SyncStatus?> getStatus(XUri uri) async {
    final data = await _load();
    final value = data[_key(uri)];
    if (value == null) return null;
    return _statusFromString(value);
  }

  @override
  Future<void> remove(XUri uri) async {
    final data = await _load();
    data.remove(_key(uri));
    await _save();
  }

  @override
  Future<List<XUri>> getByStatus(SyncStatus status) async {
    final data = await _load();
    final statusStr = _statusToString(status);
    return data.entries
        .where((e) => e.value == statusStr)
        .map((e) => XUri(Uri.parse(e.key)))
        .toList();
  }

  @override
  Future<int> countByStatus(SyncStatus status) async {
    final data = await _load();
    final statusStr = _statusToString(status);
    return data.values.where((v) => v == statusStr).length;
  }

  @override
  Future<List<XUri>> getAll() async {
    final data = await _load();
    return data.keys.map((k) => XUri(Uri.parse(k))).toList();
  }
}
