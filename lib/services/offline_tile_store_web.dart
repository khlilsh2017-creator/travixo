import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';

final Map<String, Uint8List> _memCache = {};
const String _kPrefix = 'tm_tile_';
const int _kMaxPersistedTiles = 180;

Future<Uint8List?> readTile(int z, int x, int y) async {
  final key = '$z/$x/$y';
  if (_memCache.containsKey(key)) return _memCache[key];
  try {
    final prefs = await SharedPreferences.getInstance();
    final b64 = prefs.getString('$_kPrefix$key');
    if (b64 != null && b64.isNotEmpty) {
      final bytes = base64Decode(b64);
      _memCache[key] = bytes;
      return bytes;
    }
  } catch (_) {}
  return null;
}

Future<void> writeTile(int z, int x, int y, Uint8List bytes) async {
  if (bytes.isEmpty) return;
  final key = '$z/$x/$y';
  _memCache[key] = bytes;
  try {
    final prefs = await SharedPreferences.getInstance();
    final savedKeys =
        prefs.getKeys().where((k) => k.startsWith(_kPrefix)).toList();
    if (savedKeys.length < _kMaxPersistedTiles) {
      await prefs.setString('$_kPrefix$key', base64Encode(bytes));
    }
  } catch (_) {}
}

Future<int> countCachedTiles() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final persisted =
        prefs.getKeys().where((k) => k.startsWith(_kPrefix)).length;
    return persisted > _memCache.length ? persisted : _memCache.length;
  } catch (_) {
    return _memCache.length;
  }
}

Future<void> clearCache() async {
  _memCache.clear();
  try {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_kPrefix)).toList();
    for (final k in keys) {
      await prefs.remove(k);
    }
  } catch (_) {}
}
