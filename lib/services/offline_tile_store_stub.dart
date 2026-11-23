import 'dart:typed_data';

final Map<String, Uint8List> _mem = {};

Future<Uint8List?> readTile(int z, int x, int y) async => _mem['$z/$x/$y'];

Future<void> writeTile(int z, int x, int y, Uint8List bytes) async {
  _mem['$z/$x/$y'] = bytes;
}

Future<int> countCachedTiles() async => _mem.length;

Future<void> clearCache() async => _mem.clear();
