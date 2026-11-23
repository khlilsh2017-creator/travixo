import 'dart:typed_data';
import 'offline_tile_store_stub.dart'
    if (dart.library.io) 'offline_tile_store_io.dart'
    if (dart.library.html) 'offline_tile_store_web.dart' as impl;

/// واجهة موحّدة لتخزين بلاطات الخريطة محلياً (تعمل على Android و Web)
class OfflineTileStore {
  static Future<Uint8List?> readTile(int z, int x, int y) =>
      impl.readTile(z, x, y);

  static Future<void> writeTile(int z, int x, int y, Uint8List bytes) =>
      impl.writeTile(z, x, y, bytes);

  static Future<int> countCachedTiles() => impl.countCachedTiles();

  static Future<void> clearCache() => impl.clearCache();
}
