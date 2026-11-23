import 'dart:io';
import 'dart:typed_data';

final Map<String, Uint8List> _memCache = {};

Future<Directory> _tileDir() async {
  final dir = Directory('${Directory.systemTemp.path}/travixo_map_tiles');
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  return dir;
}

Future<File> _tileFile(int z, int x, int y) async {
  final base = await _tileDir();
  return File('${base.path}/${z}_${x}_$y.png');
}

Future<Uint8List?> readTile(int z, int x, int y) async {
  final key = '$z/$x/$y';
  if (_memCache.containsKey(key)) return _memCache[key];
  try {
    final file = await _tileFile(z, x, y);
    if (await file.exists()) {
      final bytes = await file.readAsBytes();
      if (bytes.isNotEmpty) {
        _memCache[key] = bytes;
        return bytes;
      }
    }
  } catch (_) {}
  return null;
}

Future<void> writeTile(int z, int x, int y, Uint8List bytes) async {
  if (bytes.isEmpty) return;
  final key = '$z/$x/$y';
  _memCache[key] = bytes;
  try {
    final file = await _tileFile(z, x, y);
    await file.writeAsBytes(bytes, flush: false);
  } catch (_) {}
}

Future<int> countCachedTiles() async {
  try {
    final dir = await _tileDir();
    if (!await dir.exists()) return _memCache.length;
    int count = 0;
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.png')) {
        count++;
      }
    }
    return count;
  } catch (_) {
    return _memCache.length;
  }
}

Future<void> clearCache() async {
  _memCache.clear();
  try {
    final dir = await _tileDir();
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  } catch (_) {}
}
