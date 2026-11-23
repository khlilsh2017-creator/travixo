import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'offline_tile_store.dart';

/// مزوّد بلاطات خرائط يعمل بدون إنترنت (Cache-First):
/// 1) يقرأ البلاطة من الكاش المحلي فوراً إن وُجدت
/// 2) إن لم توجد، يحمّلها من OpenStreetMap ويحفظها محلياً للمستقبل
/// 3) عند انقطاع الإنترنت وعدم وجود البلاطة، يُعيد بلاطة ناعمة بدون أي خطأ
class OfflineTileProvider extends TileProvider {
  OfflineTileProvider();

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final template =
        options.urlTemplate ?? 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    return _OfflineTileImageProvider(
      z: coordinates.z,
      x: coordinates.x,
      y: coordinates.y,
      urlTemplate: template,
    );
  }
}

class _OfflineTileImageProvider
    extends ImageProvider<_OfflineTileImageProvider> {
  final int z;
  final int x;
  final int y;
  final String urlTemplate;

  const _OfflineTileImageProvider({
    required this.z,
    required this.x,
    required this.y,
    required this.urlTemplate,
  });

  // صورة PNG صالحة بحجم 1x1 بلون كريمي خفيف كبديل آمن عند غياب الإنترنت والكاش
  static final Uint8List _fallbackPng = Uint8List.fromList(<int>[
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, 0xDE, 0x00, 0x00, 0x00,
    0x0C, 0x49, 0x44, 0x41, 0x54, 0x08, 0xD7, 0x63, 0xF8, 0xEF, 0xE7, 0x03,
    0x00, 0x04, 0xF8, 0x01, 0xF2, 0xF4, 0x4F, 0x5A, 0xC6, 0x00, 0x00, 0x00,
    0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
  ]);

  @override
  Future<_OfflineTileImageProvider> obtainKey(
          ImageConfiguration configuration) =>
      SynchronousFuture<_OfflineTileImageProvider>(this);

  @override
  ImageStreamCompleter loadImage(
    _OfflineTileImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: 1.0,
      debugLabel: 'OfflineTile(${key.z}/${key.x}/${key.y})',
    );
  }

  Future<ui.Codec> _loadAsync(
    _OfflineTileImageProvider key,
    ImageDecoderCallback decode,
  ) async {
    Uint8List? bytes = await OfflineTileStore.readTile(key.z, key.x, key.y);

    if (bytes == null) {
      final url = key.urlTemplate
          .replaceAll('{z}', '${key.z}')
          .replaceAll('{x}', '${key.x}')
          .replaceAll('{y}', '${key.y}');
      try {
        final resp = await http.get(
          Uri.parse(url),
          headers: const {
            'User-Agent': 'TravixoApp/1.0 (com.travixo.travel_in_app)',
          },
        ).timeout(const Duration(seconds: 8));
        if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
          bytes = resp.bodyBytes;
          await OfflineTileStore.writeTile(key.z, key.x, key.y, bytes);
        }
      } catch (_) {}
    }

    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes ?? _fallbackPng);
    return decode(buffer);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _OfflineTileImageProvider &&
        other.z == z &&
        other.x == x &&
        other.y == y &&
        other.urlTemplate == urlTemplate;
  }

  @override
  int get hashCode => Object.hash(z, x, y, urlTemplate);
}

/// أداة تحميل مسبق لخريطة اليمن والمدن الرئيسية للعمل بدون إنترنت
class YemenOfflineMapDownloader {
  static int _lonToTileX(double lon, int zoom) {
    return ((lon + 180.0) / 360.0 * (1 << zoom)).floor();
  }

  static int _latToTileY(double lat, int zoom) {
    final rad = lat * math.pi / 180.0;
    return ((1.0 -
                math.log(math.tan(rad) + 1.0 / math.cos(rad)) / math.pi) /
            2.0 *
            (1 << zoom))
        .floor();
  }

  /// يجمع إحداثيات بلاطات اليمن (مستويات التقريب 5 إلى 8) + أهم المدن (مستوى 9)
  static List<(int z, int x, int y)> buildYemenTileList() {
    final Set<String> seen = {};
    final List<(int, int, int)> list = [];

    void addBox(double minLat, double maxLat, double minLon, double maxLon,
        int minZ, int maxZ) {
      for (int z = minZ; z <= maxZ; z++) {
        final x1 = _lonToTileX(minLon, z);
        final x2 = _lonToTileX(maxLon, z);
        final y1 = _latToTileY(maxLat, z);
        final y2 = _latToTileY(minLat, z);
        for (int x = math.min(x1, x2); x <= math.max(x1, x2); x++) {
          for (int y = math.min(y1, y2); y <= math.max(y1, y2); y++) {
            final k = '$z/$x/$y';
            if (seen.add(k)) list.add((z, x, y));
          }
        }
      }
    }

    // كامل خريطة اليمن (مستويات 5 - 8)
    addBox(12.2, 18.8, 42.3, 54.1, 5, 8);

    // تقريب إضافي (مستوى 9) لأهم المدن السياحية: صنعاء، عدن، تعز، إب، حضرموت، الحديدة
    const cities = [
      (15.37, 44.19),
      (12.79, 45.02),
      (13.58, 44.02),
      (13.97, 44.18),
      (14.54, 49.12),
      (14.80, 42.95),
    ];
    for (final c in cities) {
      addBox(c.$1 - 0.18, c.$1 + 0.18, c.$2 - 0.18, c.$2 + 0.18, 9, 9);
    }

    return list;
  }

  /// يحمّل البلاطات غير المحفوظة مع تقرير التقدم المباشر
  static Future<int> downloadYemenMap({
    required void Function(int done, int total) onProgress,
  }) async {
    final tiles = buildYemenTileList();
    int done = 0;
    int downloadedNow = 0;
    const batchSize = 6;

    for (int i = 0; i < tiles.length; i += batchSize) {
      final chunk = tiles.sublist(
        i,
        (i + batchSize) > tiles.length ? tiles.length : (i + batchSize),
      );
      await Future.wait(chunk.map((t) async {
        final cached = await OfflineTileStore.readTile(t.$1, t.$2, t.$3);
        if (cached == null) {
          final url =
              'https://tile.openstreetmap.org/${t.$1}/${t.$2}/${t.$3}.png';
          try {
            final resp = await http.get(
              Uri.parse(url),
              headers: const {
                'User-Agent': 'TravixoApp/1.0 (com.travixo.travel_in_app)',
              },
            ).timeout(const Duration(seconds: 8));
            if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
              await OfflineTileStore.writeTile(
                  t.$1, t.$2, t.$3, resp.bodyBytes);
              downloadedNow++;
            }
          } catch (_) {}
        }
        done++;
        onProgress(done, tiles.length);
      }));
    }
    return downloadedNow;
  }
}
