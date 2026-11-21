import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/demo_data.dart';
import '../data/models.dart';
import '../data/real_hotels_data.dart';
import '../l10n/app_localizations.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'booking_screens.dart';

/// شاشة تفاصيل موحّدة — وإذا كان targetId == 'list' تفتح قائمة العناصر
class DetailsScreen extends StatelessWidget {
  final ServiceType service;
  final String targetId;
  const DetailsScreen({super.key, required this.service, required this.targetId});

  @override
  Widget build(BuildContext context) {
    if (targetId == 'list') {
      if (service == ServiceType.airport) return const _AirportDetails();
      return _CategoryListScreen(service: service);
    }
    switch (service) {
      case ServiceType.hotel:
        return _HotelDetails(hotelId: targetId);
      case ServiceType.localRide:
      case ServiceType.rentCar:
        return _CarDetails(
            carId: targetId, withDriver: service == ServiceType.localRide);
      case ServiceType.tour:
      case ServiceType.package:
        return _TourDetails(tourId: targetId);
      case ServiceType.airport:
        return const _AirportDetails();
    }
  }
}

/// ===== قائمة عناصر الخدمة =====
class _CategoryListScreen extends StatelessWidget {
  final ServiceType service;
  const _CategoryListScreen({required this.service});

  @override
  Widget build(BuildContext context) {
    final l = context.l;

    String title;
    List<Widget> tiles;

    if (service == ServiceType.hotel) {
      title = l.t('hotels');
      tiles = [
        for (final h in getAllHotels())
          _Tile(
            icon: Icons.hotel,
            imageUrl: h.img(),
            title: h.name,
            subtitle: '${l.province(h.provinceId)} • ⭐ ${h.rating}',
            trailing: h.rooms.isNotEmpty
                ? l.money(h.rooms.first.pricePerNightYer)
                : '—',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) =>
                    DetailsScreen(service: ServiceType.hotel, targetId: h.id))),
          ),
      ];
    } else if (service == ServiceType.localRide) {
      title = l.t('localRide');
      tiles = [
        for (final c in getAllCars().where((c) => c.withDriver))
          _Tile(
            icon: Icons.directions_car,
            imageUrl: c.img(),
            title: c.name,
            subtitle: '${l.carCat(c.categoryId)} • ${c.seats} ${l.t('seats')}',
            trailing: l.money(c.pricePerDayYer),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => DetailsScreen(
                    service: ServiceType.localRide, targetId: c.id))),
          ),
      ];
    } else if (service == ServiceType.rentCar) {
      title = l.t('rentCar');
      tiles = [
        for (final c in getAllCars().where((c) => !c.withDriver))
          _Tile(
            icon: Icons.car_rental,
            imageUrl: c.img(),
            title: c.name,
            subtitle: '${l.carCat(c.categoryId)} • ${c.seats} ${l.t('seats')}',
            trailing: l.money(c.pricePerDayYer),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => DetailsScreen(
                    service: ServiceType.rentCar, targetId: c.id))),
          ),
      ];
    } else {
      title = service == ServiceType.package ? l.t('packages') : l.t('tours');
      tiles = [
        for (final t in kTours)
          _Tile(
            icon: Icons.map,
            imageUrl: kProvinceImgs[t.provinceId] ?? kDemoImg,
            title: t.name,
            subtitle:
                '${l.province(t.provinceId)} • ${t.days} ${l.t('days')} • ${t.seatsLeft} ${l.t('available')}',
            trailing: l.money(t.priceYer),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) =>
                    DetailsScreen(service: ServiceType.tour, targetId: t.id))),
          ),
      ];
    }

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: tiles.isEmpty
          ? Center(
              child: Text(l.t('comingSoon'),
                  style: TextStyle(color: Theme.of(context).hintColor)))
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: ListView(
                    padding: const EdgeInsets.all(16), children: tiles),
              ),
            ),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String? imageUrl;
  final String title, subtitle, trailing;
  final VoidCallback onTap;

  const _Tile({
    required this.icon,
    this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: isDark ? TIColors.darkLine : const Color(0xFFE2E8F0)),
        ),
        child: Row(children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: TIColors.orangeSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: imageUrl != null
                  ? Image.network(
                      imageUrl!,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                          child: Icon(icon, color: TIColors.orangeDeep)),
                    )
                  : Center(child: Icon(icon, color: TIColors.orangeDeep)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12, color: Theme.of(context).hintColor)),
                ]),
          ),
          const SizedBox(width: 8),
          Text(trailing,
              style: const TextStyle(
                  fontWeight: FontWeight.w900, color: TIColors.orangeDeep)),
        ]),
      ),
    );
  }
}

// ============================================================
// فندق — تصميم متجاوب مع اختيار الغرفة وحاسبة الليالي والحجز الفوري
// ============================================================
class _HotelDetails extends StatefulWidget {
  final String hotelId;
  const _HotelDetails({required this.hotelId});

  @override
  State<_HotelDetails> createState() => _HotelDetailsState();
}

class _HotelDetailsState extends State<_HotelDetails> {
  int _selectedRoomIdx = 0;
  int _nights = 2;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final state = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hotel = getAllHotels().firstWhere(
      (h) => h.id == widget.hotelId,
      orElse: () => getAllHotels().first,
    );

    final rooms = hotel.rooms;
    final safeIdx =
        rooms.isEmpty ? 0 : _selectedRoomIdx.clamp(0, rooms.length - 1);
    final selectedRoom = rooms.isNotEmpty ? rooms[safeIdx] : null;
    final totalYer =
        selectedRoom != null ? selectedRoom.pricePerNightYer * _nights : 0.0;

    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverAppBar(
          expandedHeight: 240,
          pinned: true,
          actions: [
            IconButton(
              icon: Icon(
                  state.isFavorite(hotel.id)
                      ? Icons.favorite
                      : Icons.favorite_border,
                  color: TIColors.danger),
              onPressed: () => state.toggleFavorite(hotel.id),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  hotel.img(),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Container(color: TIColors.navy),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.55),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(hotel.name,
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.w900)),
                        ),
                        if (!hotel.verified)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: TIColors.warning.withOpacity(.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(l.t('pendingVerify'),
                                style: const TextStyle(
                                    fontSize: 10, color: TIColors.warning)),
                          ),
                      ]),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 12,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.star,
                                size: 17, color: TIColors.gold),
                            const SizedBox(width: 4),
                            Text(
                                '${hotel.rating} • ${hotel.reviewsCount} ${l.t('reviews')}'),
                          ]),
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.location_on_outlined,
                                size: 16, color: Theme.of(context).hintColor),
                            const SizedBox(width: 2),
                            Text(l.province(hotel.provinceId),
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context).hintColor)),
                          ]),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(l.t('description'),
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16)),
                      const SizedBox(height: 6),
                      Text(hotel.description,
                          style: TextStyle(
                              height: 1.5, color: Theme.of(context).hintColor)),
                      const SizedBox(height: 16),
                      Text(l.t('amenities'),
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: hotel.amenities
                            .map((a) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF1E293B)
                                        : TIColors.orangeTint,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: isDark
                                            ? TIColors.darkLine
                                            : TIColors.orangeSoft),
                                  ),
                                  child: Text(a,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600)),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 22),
                      Text(l.t('selectRoom'),
                          style: const TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 17)),
                      const SizedBox(height: 12),
                      if (rooms.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: Theme.of(context).dividerColor),
                          ),
                          child: Text(l.t('comingSoon')),
                        )
                      else
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final cols = constraints.maxWidth >= 600 ? 2 : 1;
                            const spacing = 12.0;
                            final cardW =
                                (constraints.maxWidth - (cols - 1) * spacing) /
                                    cols;
                            return Wrap(
                              spacing: spacing,
                              runSpacing: spacing,
                              children: List.generate(rooms.length, (i) {
                                final r = rooms[i];
                                final selected = i == safeIdx;
                                return SizedBox(
                                  width: cardW,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: r.available
                                        ? () =>
                                            setState(() => _selectedRoomIdx = i)
                                        : null,
                                    child: Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? (isDark
                                                ? TIColors.orangeDeep
                                                    .withOpacity(0.14)
                                                : TIColors.orangeTint)
                                            : Theme.of(context).cardColor,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: selected
                                              ? TIColors.orangeDeep
                                              : (isDark
                                                  ? TIColors.darkLine
                                                  : const Color(0xFFE2E8F0)),
                                          width: selected ? 1.8 : 1.0,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  r.name,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 14.5,
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: r.available
                                                      ? TIColors.orangeDeep
                                                          .withOpacity(0.12)
                                                      : TIColors.danger
                                                          .withOpacity(0.12),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  r.available
                                                      ? (selected
                                                          ? (l.isArabic
                                                              ? 'مختارة'
                                                              : 'Selected')
                                                          : l.money(
                                                              r.pricePerNightYer))
                                                      : l.t('unavailable'),
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w800,
                                                    color: r.available
                                                        ? TIColors.orangeDeep
                                                        : TIColors.danger,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            '${l.roomType(r.typeId)} • ${r.bedType} • ${r.capacity} ${l.isArabic ? 'أشخاص' : 'guests'}',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Theme.of(context)
                                                    .hintColor),
                                          ),
                                          if (r.amenities.isNotEmpty) ...[
                                            const SizedBox(height: 8),
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 4,
                                              children: r.amenities
                                                  .take(3)
                                                  .map((a) => Text(
                                                        '• $a',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color:
                                                              Theme.of(context)
                                                                  .hintColor,
                                                        ),
                                                      ))
                                                  .toList(),
                                            ),
                                          ],
                                          const SizedBox(height: 10),
                                          Text(
                                            '${l.money(r.pricePerNightYer)} / ${l.t('perNight')}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 14,
                                              color: TIColors.orangeDeep,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            );
                          },
                        ),
                      if (selectedRoom != null) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E293B)
                                : TIColors.orangeTint,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isDark
                                  ? TIColors.darkLine
                                  : TIColors.orangeSoft,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    l.isArabic ? 'عدد الليالي' : 'Nights',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14),
                                  ),
                                  Row(
                                    children: [
                                      _StepperBtn(
                                        icon: Icons.remove,
                                        onTap: () => setState(() => _nights =
                                            (_nights - 1).clamp(1, 30)),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14),
                                        child: Text('$_nights',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w900,
                                                fontSize: 16)),
                                      ),
                                      _StepperBtn(
                                        icon: Icons.add,
                                        onTap: () => setState(() => _nights =
                                            (_nights + 1).clamp(1, 30)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        l.isArabic
                                            ? 'الإجمالي (${selectedRoom.name})'
                                            : 'Total (${selectedRoom.name})',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(context).hintColor),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        l.money(totalYer),
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w900,
                                          color: TIColors.orangeDeep,
                                        ),
                                      ),
                                    ],
                                  ),
                                  FilledButton.icon(
                                    onPressed: selectedRoom.available
                                        ? () => showModalBottomSheet(
                                              context: context,
                                              isScrollControlled: true,
                                              shape:
                                                  const RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.vertical(
                                                        top:
                                                            Radius.circular(24)),
                                              ),
                                              builder: (_) => BookingSheet(
                                                service: ServiceType.hotel,
                                                title:
                                                    '${hotel.name} — ${selectedRoom.name}',
                                                provinceId: hotel.provinceId,
                                                cityId: hotel.cityId,
                                                basePriceYer:
                                                    totalYer.toDouble(),
                                                dateLabel:
                                                    '$_nights ${(l.isArabic ? 'ليالٍ' : 'nights')}',
                                                details: {
                                                  'hotelId': hotel.id,
                                                  'roomId': selectedRoom.id,
                                                  'nights': _nights,
                                                },
                                              ),
                                            )
                                        : null,
                                    icon: const Icon(Icons.check_circle_outline,
                                        size: 18),
                                    label: Text(l.t('bookNow')),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),
                    ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _StepperBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _StepperBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Icon(icon, size: 17),
      ),
    );
  }
}

// ============================================================
// سيارة — مع عداد الأيام وخيار السائق وحاسبة السعر الفورية
// ============================================================
class _CarDetails extends StatefulWidget {
  final String carId;
  final bool withDriver;
  const _CarDetails({required this.carId, required this.withDriver});

  @override
  State<_CarDetails> createState() => _CarDetailsState();
}

class _CarDetailsState extends State<_CarDetails> {
  int _days = 3;
  late bool _withDriver = widget.withDriver;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final state = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final car = getAllCars()
        .firstWhere((c) => c.id == widget.carId, orElse: () => getAllCars().first);
    final driverFeePerDay = _withDriver && !widget.withDriver ? 10000 : 0;
    final totalYer = (car.pricePerDayYer + driverFeePerDay) * _days;

    return Scaffold(
      appBar:
          AppBar(title: Text(_withDriver ? l.t('localRide') : l.t('rentCar'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.network(car.img(),
                  height: 210,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                      height: 210,
                      color: TIColors.orangeTint,
                      child: const Icon(Icons.directions_car_filled,
                          size: 80, color: TIColors.orangeDeep))),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: Text(car.name,
                    style: const TextStyle(
                        fontSize: 21, fontWeight: FontWeight.w900)),
              ),
              IconButton(
                icon: Icon(
                    state.isFavorite(car.id)
                        ? Icons.favorite
                        : Icons.favorite_border,
                    color: TIColors.danger),
                onPressed: () => state.toggleFavorite(car.id),
              ),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _pill(context, l.carCat(car.categoryId)),
              _pill(context, '${car.year}'),
              _pill(context, '${car.seats} ${l.t('seats')}'),
              _pill(context, car.transmission),
              _pill(context, car.fuel),
            ]),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : TIColors.orangeTint,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: isDark ? TIColors.darkLine : TIColors.orangeSoft),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(l.isArabic ? 'عدد الأيام' : 'Days',
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      Row(children: [
                        _StepperBtn(
                            icon: Icons.remove,
                            onTap: () => setState(
                                () => _days = (_days - 1).clamp(1, 30))),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Text('$_days',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900, fontSize: 16)),
                        ),
                        _StepperBtn(
                            icon: Icons.add,
                            onTap: () => setState(
                                () => _days = (_days + 1).clamp(1, 30))),
                      ]),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      l.isArabic ? 'مع سائق خاص' : 'With Private Driver',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    subtitle: Text(
                      l.isArabic
                          ? '+${l.money(10000)} / يوم'
                          : '+${l.money(10000)} / day',
                      style: TextStyle(
                          fontSize: 12, color: Theme.of(context).hintColor),
                    ),
                    value: _withDriver,
                    onChanged: (v) => setState(() => _withDriver = v),
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.isArabic ? 'الإجمالي' : 'Total',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).hintColor)),
                          Text(l.money(totalYer),
                              style: const TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w900,
                                  color: TIColors.orangeDeep)),
                        ],
                      ),
                      FilledButton.icon(
                        onPressed: () => showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          shape: const RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.vertical(top: Radius.circular(24)),
                          ),
                          builder: (_) => BookingSheet(
                            service: _withDriver
                                ? ServiceType.localRide
                                : ServiceType.rentCar,
                            title:
                                '${car.name} (${_withDriver ? (l.isArabic ? "مع سائق" : "With driver") : (l.isArabic ? "بدون سائق" : "Self-drive")})',
                            provinceId: 'sanaa',
                            cityId: 'sanaa_city',
                            basePriceYer: totalYer.toDouble(),
                            dateLabel: '$_days ${l.t('days')}',
                            details: {
                              'days': _days,
                              'withDriver': _withDriver,
                            },
                          ),
                        ),
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: Text(l.t('bookNow')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _pill(BuildContext context, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Text(text, style: const TextStyle(fontSize: 12)),
      );
}

// ============================================================
// رحلة سياحية — مع عداد المسافرين وحاسبة السعر الفورية
// ============================================================
class _TourDetails extends StatefulWidget {
  final String tourId;
  const _TourDetails({required this.tourId});

  @override
  State<_TourDetails> createState() => _TourDetailsState();
}

class _TourDetailsState extends State<_TourDetails> {
  int _people = 2;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final state = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tour = kTours.firstWhere((t) => t.id == widget.tourId,
        orElse: () => kTours.first);
    final totalYer = tour.priceYer * _people;

    return Scaffold(
      appBar: AppBar(title: Text(tour.name)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.network(
                kProvinceImgs[tour.provinceId] ?? kDemoImg,
                height: 210,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                    height: 210,
                    color: TIColors.orangeTint,
                    child: const Icon(Icons.landscape,
                        size: 70, color: TIColors.orangeDeep)),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: Text(tour.name,
                    style: const TextStyle(
                        fontSize: 21, fontWeight: FontWeight.w900)),
              ),
              IconButton(
                icon: Icon(
                    state.isFavorite(tour.id)
                        ? Icons.favorite
                        : Icons.favorite_border,
                    color: TIColors.danger),
                onPressed: () => state.toggleFavorite(tour.id),
              ),
            ]),
            Text(
              '${l.province(tour.provinceId)} • ${tour.days} ${l.t('days')} • ${tour.seatsLeft} ${l.t('available')}',
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
            if (tour.includes.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: tour.includes
                    .map((inc) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E293B)
                                : TIColors.orangeTint,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: isDark
                                    ? TIColors.darkLine
                                    : TIColors.orangeSoft),
                          ),
                          child: Text('✓ $inc',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600)),
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 18),
            Text(l.isArabic ? 'برنامج الرحلة' : 'Itinerary',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            for (var i = 0; i < tour.plan.length; i++)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color:
                          isDark ? TIColors.darkLine : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: TIColors.orangeDeep,
                        child: Text('${i + 1}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${tour.plan[i].day} — ${tour.plan[i].title}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 13.5),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              tour.plan[i].details,
                              style: TextStyle(
                                  fontSize: 12.5,
                                  color: Theme.of(context).hintColor),
                            ),
                          ],
                        ),
                      ),
                    ]),
              ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : TIColors.orangeTint,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: isDark ? TIColors.darkLine : TIColors.orangeSoft),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(l.isArabic ? 'عدد المسافرين' : 'Travelers',
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      Row(children: [
                        _StepperBtn(
                            icon: Icons.remove,
                            onTap: () => setState(
                                () => _people = (_people - 1).clamp(1, 15))),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Text('$_people',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900, fontSize: 16)),
                        ),
                        _StepperBtn(
                            icon: Icons.add,
                            onTap: () => setState(
                                () => _people = (_people + 1).clamp(1, 15))),
                      ]),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.isArabic ? 'الإجمالي' : 'Total',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).hintColor)),
                          Text(l.money(totalYer),
                              style: const TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w900,
                                  color: TIColors.orangeDeep)),
                        ],
                      ),
                      FilledButton.icon(
                        onPressed: () => showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          shape: const RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.vertical(top: Radius.circular(24)),
                          ),
                          builder: (_) => BookingSheet(
                            service: ServiceType.tour,
                            title: '${tour.name} ($_people)',
                            provinceId: tour.provinceId,
                            cityId: tour.provinceId,
                            basePriceYer: totalYer.toDouble(),
                            dateLabel: '${tour.days} ${l.t('days')}',
                            details: {'people': _people, 'tourId': tour.id},
                          ),
                        ),
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: Text(l.t('bookNow')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ]),
        ),
      ),
    );
  }
}

class _AirportDetails extends StatelessWidget {
  const _AirportDetails();

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final vipCar = getAllCars().firstWhere((c) => c.id == 'c5',
        orElse: () => getAllCars().first);

    return Scaffold(
      appBar: AppBar(title: Text(l.t('airport'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: Theme.of(context).dividerColor.withOpacity(.4)),
              ),
              child: Column(children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                        value: 'arrival', label: Icon(Icons.flight_land)),
                    ButtonSegment(
                        value: 'depart', label: Icon(Icons.flight_takeoff)),
                  ],
                  selected: const {'arrival'},
                ),
                const SizedBox(height: 16),
                TextField(
                    decoration: InputDecoration(labelText: l.t('flightNo'))),
                const SizedBox(height: 12),
                TextField(decoration: InputDecoration(labelText: l.t('date'))),
                const SizedBox(height: 12),
                TextField(
                    decoration: InputDecoration(labelText: l.t('passengers'))),
                const SizedBox(height: 12),
                TextField(
                    decoration: InputDecoration(labelText: l.t('luggage'))),
                const SizedBox(height: 16),
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(l.money(vipCar.pricePerDayYer),
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: TIColors.orangeDeep)),
                      FilledButton(
                          onPressed: () => showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(24))),
                                builder: (_) => BookingSheet(
                                  service: ServiceType.airport,
                                  title: 'Airport Transfer — ${vipCar.name}',
                                  provinceId: 'sanaa',
                                  cityId: 'sanaa_city',
                                  basePriceYer:
                                      vipCar.pricePerDayYer.toDouble(),
                                  dateLabel: l.t('oneWay'),
                                  details: {'type': 'airport'},
                                ),
                              ),
                          child: Text(l.t('bookNow'))),
                    ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
