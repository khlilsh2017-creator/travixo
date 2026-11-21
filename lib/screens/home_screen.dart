// الشاشة الرئيسية — Travixo Advanced UI (مستوحاة من travixo.html)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/demo_data.dart';
import '../data/models.dart';
import '../data/places_data.dart';
import '../data/real_hotels_data.dart';
import '../l10n/app_localizations.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'assistant_screen.dart';
import 'best_places_screen.dart';
import 'details_screens.dart';
import 'haptic.dart';
import 'live_map_screen.dart';
import 'notifications_sheet.dart';
import 'trip_planner_screen.dart';

class HomeScreen extends StatelessWidget {
  final ValueChanged<int>? onNavigateTab;
  final VoidCallback? onToggleCurrency;
  final VoidCallback? onToggleTheme;

  const HomeScreen({
    super.key,
    this.onNavigateTab,
    this.onToggleCurrency,
    this.onToggleTheme,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final state = context.watch<AppState>();
    final isWide = MediaQuery.of(context).size.width >= 840;
    final hotels = getAllHotels();
    final offers = getAllOffers();
    final places = kBestPlaces.take(4).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          if (!isWide) SliverToBoxAdapter(child: _mobileHeader(context, l, state)),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1152),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _heroBanner(context, l),
                      const SizedBox(height: 24),
                      _servicesGrid(context, l),
                      const SizedBox(height: 24),
                      _offersSection(context, l, offers),
                      const SizedBox(height: 24),
                      _hotelsSection(context, l, state, hotels.take(3).toList()),
                      const SizedBox(height: 24),
                      _placesSection(context, l, state, places),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobileHeader(
      BuildContext context, AppLocalizations l, AppState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, MediaQuery.of(context).padding.top + 10, 16, 10),
      decoration: BoxDecoration(
        color: (isDark ? TIColors.darkCard : Colors.white).withOpacity(0.95),
        border: Border(
          bottom: BorderSide(
            color: isDark ? TIColors.darkLine : TIColors.orangeSoft,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: TravixoFX.orange,
              borderRadius: BorderRadius.circular(11),
              boxShadow: [TravixoFX.shadow(TIColors.orange)],
            ),
            child: const Icon(Icons.explore, color: Colors.white, size: 21),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'TRAVIXO',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark
                            ? TIColors.orangeDeep.withOpacity(0.22)
                            : TIColors.orangeSoft,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        l.isArabic ? 'نسخة مطورة' : 'Pro',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: TIColors.orangeDeep,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  state.user != null
                      ? '${l.t('welcome')} ${state.user!.firstName}'
                      : (l.isArabic
                          ? 'شريكك الذكي للسفر في اليمن'
                          : 'Your Smart Travel Partner'),
                  style: TextStyle(
                      fontSize: 11, color: Theme.of(context).hintColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          _miniPill(
            context,
            onTap: onToggleCurrency ?? () {},
            child: Text(
              state.currency,
              style:
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 6),
          _miniPill(
            context,
            onTap: onToggleTheme ?? () {},
            child: Icon(
              isDark ? Icons.wb_sunny_rounded : Icons.nightlight_round,
              size: 16,
              color: isDark ? TIColors.gold : null,
            ),
          ),
          const SizedBox(width: 6),
          const NotificationBellButton(asPill: true),
        ],
      ),
    );
  }

  Widget _miniPill(BuildContext context,
      {required VoidCallback onTap, required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? TIColors.darkLine : const Color(0xFFE2E8F0),
          ),
        ),
        child: child,
      ),
    );
  }

  // ==================== Hero Banner ====================
  Widget _heroBanner(BuildContext context, AppLocalizations l) {
    final heroImg = kProvinceImgs['sanaa'] ?? kDemoImg;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: 245,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              heroImg,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Container(decoration: const BoxDecoration(gradient: TravixoFX.orange)),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    const Color(0xFF020617).withOpacity(0.88),
                    const Color(0xFF020617).withOpacity(0.45),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: TIColors.orangeDeep.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_awesome,
                            color: Colors.white, size: 13),
                        const SizedBox(width: 5),
                        Text(
                          l.isArabic
                              ? 'مرحباً بك في TRAVIXO'
                              : 'Welcome to TRAVIXO',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l.isArabic
                        ? 'اكتشف جمال اليمن، وخطط رحلتك بذكاء'
                        : 'Discover Yemen & Plan Your Trip Smartly',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l.isArabic
                        ? 'فنادق موثقة، سيارات حديثة، وباقات سياحية في صنعاء وعدن وحضرموت وإب.'
                        : 'Verified hotels, modern cars, and curated tours across Yemen.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.88),
                      fontSize: 12.5,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          Haptics.light();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const TripPlannerScreen()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TIColors.orangeDeep,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          minimumSize: const Size(0, 38),
                        ),
                        icon: const Icon(Icons.auto_fix_high, size: 16),
                        label: Text(
                          l.isArabic ? 'صمم خطتك الآن' : 'Plan Your Trip',
                          style: const TextStyle(fontSize: 12.5),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          Haptics.light();
                          if (onNavigateTab != null) onNavigateTab!(1);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.18),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          minimumSize: const Size(0, 38),
                        ),
                        icon: const Icon(Icons.search, size: 16),
                        label: Text(
                          l.isArabic ? 'استكشف الوجهات' : 'Explore',
                          style: const TextStyle(fontSize: 12.5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== 8 Services Grid ====================
  Widget _servicesGrid(BuildContext context, AppLocalizations l) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items = [
      (
        l.isArabic ? 'الرحلات' : 'Tours',
        Icons.luggage_rounded,
        TIColors.cardTrips,
        () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) =>
                const DetailsScreen(service: ServiceType.tour, targetId: 'list')))
      ),
      (
        l.isArabic ? 'تأجير السيارات' : 'Car Rental',
        Icons.directions_car_rounded,
        TIColors.cardRent,
        () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const DetailsScreen(
                service: ServiceType.rentCar, targetId: 'list')))
      ),
      (
        l.isArabic ? 'فنادق' : 'Hotels',
        Icons.apartment_rounded,
        TIColors.cardHotels,
        () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const DetailsScreen(
                service: ServiceType.hotel, targetId: 'list')))
      ),
      (
        l.isArabic ? 'مخطط الرحلات' : 'Planner',
        Icons.auto_fix_high_rounded,
        TIColors.cardPlans,
        () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const TripPlannerScreen()))
      ),
      (
        l.isArabic ? 'منتجعات واستراحات' : 'Resorts',
        Icons.beach_access_rounded,
        TIColors.cardResorts,
        () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const DetailsScreen(
                service: ServiceType.hotel, targetId: 'list')))
      ),
      (
        l.isArabic ? 'أفضل الأماكن' : 'Best Places',
        Icons.account_balance_rounded,
        TIColors.cardPlaces,
        () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const BestPlacesScreen()))
      ),
      (
        l.isArabic ? 'الخريطة الحية' : 'Live Map',
        Icons.map_rounded,
        TIColors.cardMap,
        () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const LiveMapScreen()))
      ),
      (
        l.isArabic ? 'المساعد الذكي' : 'AI Assistant',
        Icons.smart_toy_rounded,
        TIColors.cardAssistant,
        () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const AssistantScreen()))
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l.isArabic ? 'الخدمات الرئيسية' : 'Main Services',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            Text(
              l.isArabic ? 'تجربة متكاملة' : 'All-in-one',
              style:
                  TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final cols = constraints.maxWidth >= 820 ? 8 : 4;
            const spacing = 10.0;
            final itemWidth =
                (constraints.maxWidth - (cols - 1) * spacing) / cols;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: items.map((item) {
                return SizedBox(
                  width: itemWidth,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () {
                      Haptics.light();
                      item.$4();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isDark
                              ? TIColors.darkLine
                              : const Color(0xFFF1F5F9),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: item.$3.withOpacity(isDark ? 0.20 : 0.12),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Icon(item.$2, color: item.$3, size: 22),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item.$1,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  // ==================== Exclusive Offers ====================
  Widget _offersSection(
      BuildContext context, AppLocalizations l, List<Offer> offers) {
    final gradients = [
      const [Color(0xFFF97316), Color(0xFFE11D48)],
      const [Color(0xFF0EA5E9), Color(0xFF2563EB)],
      const [Color(0xFF10B981), Color(0xFF0D9488)],
      const [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.isArabic ? 'عروض حصرية' : 'Exclusive Offers',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 128,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: offers.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, idx) {
              final o = offers[idx];
              final g = gradients[idx % gradients.length];
              return InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  Haptics.light();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DetailsScreen(
                          service: o.service, targetId: o.targetId),
                    ),
                  );
                },
                child: Container(
                  width: 240,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: g,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [TravixoFX.shadow(g.first)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.22),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${l.isArabic ? 'خصم' : 'Save'} ${o.discountPercent}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            o.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            l.isArabic ? 'اضغط للاستكشاف ←' : 'Explore now →',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.88),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ==================== Hotels Section ====================
  Widget _hotelsSection(BuildContext context, AppLocalizations l,
      AppState state, List<Hotel> hotels) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l.isArabic ? 'فنادق قريبة ومختارة' : 'Featured Hotels',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const DetailsScreen(
                      service: ServiceType.hotel, targetId: 'list'),
                ),
              ),
              child: Text(l.isArabic ? 'عرض الكل' : 'See all'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final cols = constraints.maxWidth >= 820
                ? 3
                : (constraints.maxWidth >= 560 ? 2 : 1);
            const spacing = 14.0;
            final cardW =
                (constraints.maxWidth - (cols - 1) * spacing) / cols;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: hotels
                  .map((h) => SizedBox(
                      width: cardW, child: _hotelCard(context, l, state, h)))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _hotelCard(
      BuildContext context, AppLocalizations l, AppState state, Hotel h) {
    final isFav = state.isFavorite(h.id);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final price = h.rooms.isNotEmpty ? h.rooms.first.pricePerNightYer : 0;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              DetailsScreen(service: ServiceType.hotel, targetId: h.id),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isDark ? TIColors.darkLine : const Color(0xFFE2E8F0)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 165,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    h.img(),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Container(color: TIColors.navy),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: InkWell(
                      onTap: () => state.toggleFavorite(h.id),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.92),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isFav ? Icons.favorite : Icons.favorite_border,
                          size: 18,
                          color: isFav ? TIColors.danger : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A).withOpacity(0.78),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        l.province(h.provinceId),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          h.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 14.5),
                        ),
                      ),
                      const Icon(Icons.star, size: 15, color: TIColors.gold),
                      const SizedBox(width: 3),
                      Text('${h.rating}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              color: TIColors.gold)),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    h.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12, color: Theme.of(context).hintColor),
                  ),
                  const SizedBox(height: 12),
                  Divider(
                      height: 1,
                      color: isDark
                          ? TIColors.darkLine
                          : const Color(0xFFF1F5F9)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${l.money(price)} / ${l.isArabic ? 'ليلة' : 'night'}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13.5,
                          color: TIColors.orangeDeep,
                        ),
                      ),
                      Text(
                        l.t('bookNow'),
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== Suggested Places ====================
  Widget _placesSection(BuildContext context, AppLocalizations l,
      AppState state, List<BestPlace> places) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l.isArabic ? 'أماكن مقترحة لك' : 'Suggested Places',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BestPlacesScreen()),
              ),
              child: Text(l.isArabic ? 'عرض الكل' : 'See all'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final cols = constraints.maxWidth >= 820
                ? 4
                : (constraints.maxWidth >= 520 ? 2 : 1);
            const spacing = 12.0;
            final cardW =
                (constraints.maxWidth - (cols - 1) * spacing) / cols;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: places.map((p) {
                final isFav = state.isFavorite(p.id);
                return SizedBox(
                  width: cardW,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color: isDark
                              ? TIColors.darkLine
                              : const Color(0xFFE2E8F0)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 145,
                          width: double.infinity,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(
                                kProvinceImgs[p.provinceId] ?? kDemoImg,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    Container(color: TIColors.navy),
                              ),
                              Positioned(
                                top: 8,
                                left: 8,
                                child: InkWell(
                                  onTap: () => state.toggleFavorite(p.id),
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.92),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isFav
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      size: 16,
                                      color: isFav
                                          ? TIColors.danger
                                          : const Color(0xFF475569),
                                    ),
                                  ),
                                ),
                              ),
                              if (p.unesco)
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: TIColors.orangeDeep,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'UNESCO',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      p.name(l.isArabic),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 13.5),
                                    ),
                                  ),
                                  Text(
                                    '★ ${p.rating}',
                                    style: const TextStyle(
                                        color: TIColors.gold,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${l.province(p.provinceId)} • ${p.category}',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(context).hintColor),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () {
                                        if (onNavigateTab != null) {
                                          onNavigateTab!(1);
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 7),
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? const Color(0xFF1E293B)
                                              : TIColors.orangeTint,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          l.isArabic
                                              ? 'فنادق قريبة'
                                              : 'Nearby',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: TIColors.orangeDeep,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const LiveMapScreen()),
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 7),
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? const Color(0xFF1E293B)
                                              : const Color(0xFFF1F5F9),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          l.isArabic ? 'الخريطة' : 'Map',
                                          style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
