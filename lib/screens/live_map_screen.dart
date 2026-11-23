// الخريطة الحية المطوّرة — OpenStreetMap مع كاش محلي للعمل بدون إنترنت + تحميل مسبق لخريطة اليمن + بديل متجهي تفاعلي
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../data/demo_data.dart';
import '../data/models.dart';
import '../data/real_hotels_data.dart';
import '../l10n/app_localizations.dart';
import '../services/offline_tile_provider.dart';
import '../services/offline_tile_store.dart';
import '../theme/app_theme.dart';
import 'details_screens.dart';
import 'haptic.dart';

class LiveMapScreen extends StatefulWidget {
  const LiveMapScreen({super.key});
  @override
  State<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends State<LiveMapScreen> {
  final MapController _mapCtrl = MapController();
  final OfflineTileProvider _tileProvider = OfflineTileProvider();

  bool _vectorOfflineMode = false;
  int _cachedTiles = 0;
  bool _downloading = false;
  int _dlDone = 0;
  int _dlTotal = 0;

  static const Map<String, LatLng> _coords = {
    'sanaa': LatLng(15.3694, 44.1910),
    'aden': LatLng(12.7855, 45.0187),
    'taiz': LatLng(13.5795, 44.0216),
    'hadramout': LatLng(15.5000, 48.5000),
    'hodeidah': LatLng(14.7960, 42.9510),
    'ibb': LatLng(13.9667, 44.1833),
    'dhamar': LatLng(14.5550, 44.4060),
    'marib': LatLng(15.4500, 45.3300),
    'lahij': LatLng(13.0000, 44.9000),
    'hajjah': LatLng(15.7000, 42.9000),
    'amran': LatLng(15.6000, 43.9000),
    'sadah': LatLng(15.7000, 43.7000),
    'shabwa': LatLng(15.3700, 46.3500),
    'abyan': LatLng(13.1200, 45.6000),
    'socotra': LatLng(12.5500, 53.9500),
    'mahrah': LatLng(16.2000, 52.1500),
    'jawf': LatLng(16.1500, 45.1000),
    'bayda': LatLng(13.9500, 45.5500),
    'dhale': LatLng(13.6800, 44.7500),
    'rima': LatLng(14.6000, 43.6000),
  };

  @override
  void initState() {
    super.initState();
    _refreshTileCount();
  }

  Future<void> _refreshTileCount() async {
    final c = await OfflineTileStore.countCachedTiles();
    if (mounted) setState(() => _cachedTiles = c);
  }

  Color _statusColor(Availability s) {
    switch (s) {
      case Availability.available:
        return TIColors.success;
      case Availability.limited:
        return TIColors.warning;
      case Availability.unavailable:
        return TIColors.danger;
      case Availability.comingSoon:
        return TIColors.teal;
    }
  }

  int _hotelCount(String pid) {
    int c = 0;
    for (final h in getAllHotels()) {
      if (h.provinceId == pid) c++;
    }
    return c;
  }

  void _openSheet(Province p) {
    Haptics.light();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _ProvinceSheet(province: p, color: _statusColor(p.status)),
    );
  }

  void _focus(Province p) {
    if (_vectorOfflineMode) return;
    Haptics.light();
    final c = _coords[p.id];
    if (c != null) _mapCtrl.move(c, 9.2);
  }

  Future<void> _startDownloadYemenMap() async {
    if (_downloading) return;
    final ar = context.l.isArabic;
    setState(() {
      _downloading = true;
      _dlDone = 0;
      _dlTotal = 1;
    });
    final added = await YemenOfflineMapDownloader.downloadYemenMap(
      onProgress: (done, total) {
        if (!mounted) return;
        setState(() {
          _dlDone = done;
          _dlTotal = total;
        });
      },
    );
    await _refreshTileCount();
    if (!mounted) return;
    setState(() => _downloading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ar
              ? 'تم تجهيز خريطة اليمن بدون إنترنت ✅ (تم حفظ $added بلاطة جديدة • الإجمالي $_cachedTiles)'
              : 'Yemen offline map ready ($added new tiles • total $_cachedTiles)',
        ),
      ),
    );
  }

  void _openOfflineManager() {
    final ar = context.l.isArabic;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.offline_pin_rounded,
                    color: TIColors.orangeDeep, size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    ar ? 'خرائط بدون إنترنت (Offline Maps)' : 'Offline Maps',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              ar
                  ? 'كل منطقة تتصفحها على الخريطة تُحفظ تلقائياً في جهازك. ويمكنك تحميل خريطة اليمن والمدن الرئيسية دفعة واحدة لتعمل بدون إنترنت بالكامل.'
                  : 'Visited areas are cached automatically. You can also pre-download Yemen and major cities for full offline access.',
              style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: Theme.of(ctx).hintColor),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(ctx).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Theme.of(ctx).dividerColor),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    ar ? 'البلاطات المحفوظة في الجهاز' : 'Cached Map Tiles',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '$_cachedTiles',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: TIColors.orangeDeep,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _downloading
                    ? null
                    : () {
                        Navigator.pop(ctx);
                        _startDownloadYemenMap();
                      },
                icon: const Icon(Icons.download_for_offline_rounded),
                label: Text(ar
                    ? 'تحميل خريطة اليمن والمدن الرئيسية الآن'
                    : 'Download Yemen Offline Map Now'),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(
                          () => _vectorOfflineMode = !_vectorOfflineMode);
                    },
                    icon: Icon(
                        _vectorOfflineMode ? Icons.public : Icons.map_outlined,
                        size: 17),
                    label: Text(
                      _vectorOfflineMode
                          ? (ar ? 'الخريطة الحقيقية' : 'Real Map')
                          : (ar ? 'الخريطة المتجهية' : 'Vector Map'),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _cachedTiles == 0
                        ? null
                        : () async {
                            await OfflineTileStore.clearCache();
                            await _refreshTileCount();
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: TIColors.danger,
                      side: const BorderSide(color: TIColors.danger),
                    ),
                    icon: const Icon(Icons.delete_outline, size: 17),
                    label: Text(
                      ar ? 'مسح الكاش' : 'Clear Cache',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _mapCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final ar = l.isArabic;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(l.t('liveMap'),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: ar ? 'تحميل الخريطة بدون نت' : 'Offline Maps',
            onPressed: _openOfflineManager,
            icon: Icon(
              _cachedTiles > 0
                  ? Icons.offline_pin_rounded
                  : Icons.download_for_offline_outlined,
              color: _cachedTiles > 0 ? TIColors.success : null,
            ),
          ),
          IconButton(
            tooltip: ar ? 'تبديل الخريطة المتجهية' : 'Toggle Vector Map',
            onPressed: () {
              Haptics.light();
              setState(() => _vectorOfflineMode = !_vectorOfflineMode);
            },
            icon: Icon(_vectorOfflineMode ? Icons.public : Icons.layers_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_downloading)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: TIColors.orangeTint,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        ar
                            ? 'جارٍ تحميل خريطة اليمن للعمل بدون نت...'
                            : 'Downloading Yemen offline map...',
                        style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: TIColors.orangeDark),
                      ),
                      Text(
                        '${(_dlDone * 100 / (_dlTotal == 0 ? 1 : _dlTotal)).round()}%',
                        style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                            color: TIColors.orangeDeep),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: _dlTotal == 0 ? null : _dlDone / _dlTotal,
                      minHeight: 6,
                      backgroundColor: TIColors.orangeSoft,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          TIColors.orangeDeep),
                    ),
                  ),
                ],
              ),
            ),
          _legend(l),
          Expanded(
            child: _vectorOfflineMode
                ? _OfflineFallbackMap(onSelectProvince: _openSheet)
                : _realMap(),
          ),
          _chips(l),
        ],
      ),
    );
  }

  Widget _realMap() {
    return FlutterMap(
      mapController: _mapCtrl,
      options: const MapOptions(
        initialCenter: LatLng(15.2, 47.5),
        initialZoom: 6.2,
        minZoom: 5.0,
        maxZoom: 18.0,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.travixo.travel_in_app',
          tileProvider: _tileProvider,
        ),
        CircleLayer(circles: [
          for (final p in kProvinces)
            if (_coords[p.id] != null)
              CircleMarker(
                point: _coords[p.id]!,
                radius: 16.0 + _hotelCount(p.id) * 2.5,
                color: _statusColor(p.status).withOpacity(0.92),
                borderColor: Colors.white,
                borderStrokeWidth: 3.5,
              ),
        ]),
        MarkerLayer(markers: [
          for (final p in kProvinces)
            if (_coords[p.id] != null)
              Marker(
                point: _coords[p.id]!,
                width: 110,
                height: 80,
                child: GestureDetector(
                  onTap: () => _openSheet(p),
                  onLongPress: () => _focus(p),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _statusColor(p.status),
                          borderRadius: BorderRadius.circular(TIRadius.small),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Text('${_hotelCount(p.id)}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w900)),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(TIRadius.small),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 6,
                                offset: const Offset(0, 2))
                          ],
                        ),
                        child: Text(context.l.province(p.id),
                            style: const TextStyle(
                                color: TIColors.navy,
                                fontSize: 12,
                                fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ),
              ),
        ]),
        Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Text(
              _cachedTiles > 0
                  ? '© OpenStreetMap • كاش محلي: $_cachedTiles'
                  : '© OpenStreetMap contributors',
              style: TextStyle(
                fontSize: 9.5,
                color: Colors.black87,
                backgroundColor: Colors.white.withOpacity(.85),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _legend(AppLocalizations l) {
    final items = [
      (TIColors.success, l.t('available')),
      (TIColors.warning, l.t('limited')),
      (TIColors.teal, l.t('comingSoon')),
      (TIColors.danger, l.t('unavailable')),
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(TIRadius.medium),
        border: Border.all(
            color: Theme.of(context).dividerColor.withOpacity(0.5)),
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        children: items
            .map((e) => Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                      width: 12,
                      height: 12,
                      decoration:
                          BoxDecoration(color: e.$1, shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  Text(e.$2,
                      style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w700)),
                ]))
            .toList(),
      ),
    );
  }

  Widget _chips(AppLocalizations l) {
    final ps = kProvinces;
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: Theme.of(context).colorScheme.surface,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: ps.length,
        itemBuilder: (ctx, i) {
          final p = ps[i];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(l.province(p.id)),
              selected: false,
              onSelected: (_) {
                if (!_vectorOfflineMode) _focus(p);
                _openSheet(p);
              },
              labelStyle:
                  const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              selectedColor: TIColors.orange,
              backgroundColor: TIColors.orangeSoft,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(TIRadius.small)),
            ),
          );
        },
      ),
    );
  }
}

class _ProvinceSheet extends StatelessWidget {
  final Province province;
  final Color color;
  const _ProvinceSheet({required this.province, required this.color});

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final hotels = getAllHotels()
        .where((h) => h.provinceId == province.id)
        .take(4)
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(TIRadius.sheet)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                    color: TIColors.lightLine,
                    borderRadius: BorderRadius.circular(3)),
              ),
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(TIRadius.medium),
              child: SizedBox(
                height: 160,
                width: double.infinity,
                child: Image.network(province.img(),
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => Container(
                        color: TIColors.orangeSoft,
                        child: const Icon(Icons.place,
                            size: 60, color: TIColors.orange))),
              ),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: Text(l.province(province.id),
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w900)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(TIRadius.small)),
                child: Text(_statusLabel(l),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800)),
              ),
            ]),
            const SizedBox(height: 16),
            Text(l.t('hotelsNearby'),
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            if (hotels.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: TIColors.orangeSoft,
                    borderRadius: BorderRadius.circular(TIRadius.medium)),
                child: Row(children: [
                  const Icon(Icons.info_outline, color: TIColors.orangeDeep),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(l.t('soon'),
                          style: const TextStyle(
                              fontSize: 14, color: TIColors.navy))),
                ]),
              )
            else
              ...hotels.map((h) => _tile(context, l, h)),
          ],
        ),
      ),
    );
  }

  String _statusLabel(AppLocalizations l) {
    switch (province.status) {
      case Availability.available:
        return l.t('available');
      case Availability.limited:
        return l.t('limited');
      case Availability.comingSoon:
        return l.t('comingSoon');
      case Availability.unavailable:
        return l.t('unavailable');
    }
  }

  Widget _tile(BuildContext context, AppLocalizations l, Hotel h) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(TIRadius.medium),
        onTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  DetailsScreen(service: ServiceType.hotel, targetId: h.id),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(TIRadius.medium),
            border: Border.all(
                color: Theme.of(context).dividerColor.withOpacity(0.5)),
          ),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(TIRadius.small),
              child: SizedBox(
                width: 60,
                height: 60,
                child: Image.network(h.img(),
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => Container(
                        color: TIColors.orangeSoft,
                        child:
                            const Icon(Icons.hotel, color: TIColors.orange))),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(h.name,
                        style: const TextStyle(
                            fontSize: 14.5, fontWeight: FontWeight.w800),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.star,
                          color: TIColors.warning, size: 14),
                      const SizedBox(width: 4),
                      Text('${h.rating} • ${h.reviewsCount}',
                          style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).hintColor)),
                    ]),
                  ]),
            ),
            const SizedBox(width: 8),
            Text(
              h.rooms.isNotEmpty
                  ? l.money(h.rooms.first.pricePerNightYer)
                  : '—',
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: TIColors.orangeDeep),
            ),
          ]),
        ),
      ),
    );
  }
}

/// خريطة متجهية تفاعلية تعمل 100% بدون إنترنت حتى قبل تحميل أي بلاطات
class _OfflineFallbackMap extends StatelessWidget {
  final ValueChanged<Province> onSelectProvince;
  const _OfflineFallbackMap({required this.onSelectProvince});

  static const Map<String, double> _rxMap = {
    'hajjah': 0.18,
    'sadah': 0.22,
    'amran': 0.28,
    'sanaa': 0.32,
    'hodeidah': 0.12,
    'ibb': 0.35,
    'taiz': 0.33,
    'dhamar': 0.38,
    'lahij': 0.30,
    'aden': 0.35,
    'marib': 0.52,
    'jawf': 0.48,
    'shabwa': 0.62,
    'hadramout': 0.78,
    'mahrah': 0.90,
    'abyan': 0.42,
    'bayda': 0.50,
    'dhale': 0.45,
    'rima': 0.25,
    'socotra': 0.91,
  };

  static const Map<String, double> _ryMap = {
    'hajjah': 0.28,
    'sadah': 0.16,
    'amran': 0.24,
    'sanaa': 0.34,
    'hodeidah': 0.42,
    'ibb': 0.55,
    'taiz': 0.64,
    'dhamar': 0.48,
    'lahij': 0.72,
    'aden': 0.82,
    'marib': 0.38,
    'jawf': 0.26,
    'shabwa': 0.52,
    'hadramout': 0.40,
    'mahrah': 0.28,
    'abyan': 0.70,
    'bayda': 0.54,
    'dhale': 0.64,
    'rima': 0.44,
    'socotra': 0.84,
  };

  Color _pc(Availability s) {
    switch (s) {
      case Availability.available:
        return TIColors.success;
      case Availability.limited:
        return TIColors.warning;
      case Availability.unavailable:
        return TIColors.danger;
      case Availability.comingSoon:
        return TIColors.teal;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(TIRadius.medium),
        border: Border.all(
            color: Theme.of(context).dividerColor.withOpacity(0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InteractiveViewer(
        minScale: 0.9,
        maxScale: 3.0,
        child: LayoutBuilder(
          builder: (ctx, c) => Stack(
            children: [
              CustomPaint(
                painter: _MapPainter(),
                size: Size(c.maxWidth, c.maxHeight),
              ),
              for (final prov in kProvinces)
                Positioned(
                  left: ((_rxMap[prov.id] ?? 0.5) * c.maxWidth - 28)
                      .clamp(4.0, c.maxWidth - 64),
                  top: ((_ryMap[prov.id] ?? 0.5) * c.maxHeight - 16)
                      .clamp(4.0, c.maxHeight - 36),
                  child: GestureDetector(
                    onTap: () => onSelectProvince(prov),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: _pc(prov.status),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.16),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        l.province(prov.id),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = TIColors.lightLine.withOpacity(0.6)
      ..strokeWidth = 1;
    for (int i = 1; i < 8; i++) {
      final y = size.height * i / 8;
      final x = size.width * i / 8;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    final route = Paint()
      ..color = TIColors.orange.withOpacity(0.45)
      ..strokeWidth = 2.8
      ..style = PaintingStyle.stroke;
    final p = ui.Path()
      ..moveTo(size.width * 0.12, size.height * 0.42)
      ..lineTo(size.width * 0.32, size.height * 0.34)
      ..lineTo(size.width * 0.35, size.height * 0.82)
      ..moveTo(size.width * 0.32, size.height * 0.34)
      ..lineTo(size.width * 0.52, size.height * 0.38)
      ..lineTo(size.width * 0.78, size.height * 0.40)
      ..lineTo(size.width * 0.90, size.height * 0.28);
    canvas.drawPath(p, route);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
