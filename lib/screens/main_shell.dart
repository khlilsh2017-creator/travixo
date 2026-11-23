import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'explore_screen.dart';
import 'trip_planner_screen.dart';
import 'live_map_screen.dart';
import 'booking_screens.dart';
import 'wallet_profile.dart';
import 'onboarding_screen.dart';
import 'notifications_sheet.dart';

/// الهيكل الرئيسي للتطبيق — متجاوب مع الجوال والويب/سطح المكتب
/// Mobile: Bottom Navigation (5 تبويبات)
/// Desktop/Web (>= 840px): Top Navigation Header مع أزرار العملة، المظهر، الجولة التعريفية، والحساب
class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  void _goToTab(int idx) {
    if (mounted) setState(() => _index = idx);
  }

  String _nextCurrency(String current) {
    switch (current) {
      case 'YER':
        return 'USD';
      case 'USD':
        return 'SAR';
      default:
        return 'YER';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final state = context.watch<AppState>();
    final isWide = MediaQuery.of(context).size.width >= 840;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 0: الرئيسية، 1: استكشف، 2: حجوزاتي، 3: المحفظة، 4: حسابي، 5: مخطط الرحلات، 6: الخريطة الحية
    final pages = [
      HomeScreen(
        onNavigateTab: _goToTab,
        onToggleCurrency: () => state.setCurrency(_nextCurrency(state.currency)),
        onToggleTheme: () => state.toggleTheme(),
      ),
      const ExploreScreen(),
      const BookingsTab(),
      const WalletTab(),
      const ProfileTab(),
      const TripPlannerScreen(),
      const LiveMapScreen(),
    ];

    return Scaffold(
      appBar: isWide
          ? PreferredSize(
              preferredSize: const Size.fromHeight(68),
              child: Container(
                decoration: BoxDecoration(
                  color: (isDark ? TIColors.darkCard : Colors.white)
                      .withOpacity(0.95),
                  border: Border(
                    bottom: BorderSide(
                      color: isDark
                          ? TIColors.darkLine
                          : TIColors.orangeSoft,
                    ),
                  ),
                ),
                child: SafeArea(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1152),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            // الشعار
                            InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => _goToTab(0),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      gradient: TravixoFX.orange,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        TravixoFX.shadow(TIColors.orange)
                                      ],
                                    ),
                                    child: const Icon(Icons.explore,
                                        color: Colors.white, size: 22),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Text(
                                            'TRAVIXO',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 17,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? TIColors.orangeDeep
                                                      .withOpacity(0.22)
                                                  : TIColors.orangeSoft,
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              l.isArabic
                                                  ? 'نسخة مطورة'
                                                  : 'Pro',
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
                                        l.isArabic
                                            ? 'شريكك الذكي للسفر في اليمن'
                                            : 'Your Smart Travel Partner',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Theme.of(context).hintColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            // قائمة التنقل العلوية
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1E293B)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  _TopNavBtn(
                                    label: l.t('home'),
                                    active: _index == 0,
                                    onTap: () => _goToTab(0),
                                  ),
                                  _TopNavBtn(
                                    label: l.t('explore'),
                                    active: _index == 1,
                                    onTap: () => _goToTab(1),
                                  ),
                                  _TopNavBtn(
                                    label: (l.isArabic ? 'مخطط الرحلات' : 'Planner'),
                                    active: _index == 5,
                                    onTap: () => _goToTab(5),
                                  ),
                                  _TopNavBtn(
                                    label: l.t('liveMap'),
                                    active: _index == 6,
                                    onTap: () => _goToTab(6),
                                  ),
                                  _TopNavBtn(
                                    label: l.t('bookings'),
                                    active: _index == 2,
                                    onTap: () => _goToTab(2),
                                  ),
                                  _TopNavBtn(
                                    label: l.t('wallet'),
                                    active: _index == 3,
                                    onTap: () => _goToTab(3),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            // أزرار الإجراءات السريعة
                            _HeaderPillButton(
                              onTap: () => state
                                  .setCurrency(_nextCurrency(state.currency)),
                              child: Text(
                                state.currency,
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w800),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _HeaderPillButton(
                              onTap: () => state.toggleTheme(),
                              child: Icon(
                                isDark ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                                size: 17,
                                color: isDark ? TIColors.gold : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const NotificationBellButton(asPill: true),
                            const SizedBox(width: 8),
                            InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => const OnboardingScreen()),
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 7),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? TIColors.orangeDeep.withOpacity(0.2)
                                      : TIColors.orangeTint,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.auto_awesome,
                                        size: 14, color: TIColors.orangeDeep),
                                    const SizedBox(width: 5),
                                    Text(
                                      l.isArabic ? 'جولة تعريفية' : 'Tour',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: TIColors.orangeDeep,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              borderRadius: BorderRadius.circular(999),
                              onTap: () => _goToTab(4),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: _index == 4
                                      ? TIColors.orangeDeep
                                      : (isDark
                                          ? const Color(0xFF1E293B)
                                          : TIColors.orangeSoft),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isDark
                                        ? TIColors.darkLine
                                        : TIColors.lightLine,
                                  ),
                                ),
                                child: Icon(
                                  Icons.person_outline,
                                  size: 18,
                                  color: _index == 4
                                      ? Colors.white
                                      : TIColors.orangeDeep,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            )
          : null,
      body: Column(
        children: [
          if (state.isOffline || state.pendingSyncBookings.isNotEmpty)
            Material(
              color: state.isOffline ? TIColors.navy : TIColors.orangeDark,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  child: Row(
                    children: [
                      Icon(
                        state.isOffline
                            ? Icons.wifi_off_rounded
                            : Icons.cloud_upload_outlined,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          state.isOffline
                              ? (l.isArabic
                                  ? 'وضع بدون إنترنت — يتم عرض البيانات المحفوظة محلياً'
                                  : 'Offline Mode — Showing locally cached data')
                              : (l.isArabic
                                  ? 'يوجد ${state.pendingSyncBookings.length} حجز بانتظار المزامنة السحابية'
                                  : '${state.pendingSyncBookings.length} booking(s) pending cloud sync'),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          await state.fetchLiveCatalog();
                          await state.syncFromSupabase();
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: TIColors.gold,
                          minimumSize: const Size(0, 28),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: Text(
                          l.isArabic ? 'مزامنة' : 'Sync',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(child: IndexedStack(index: _index, children: pages)),
        ],
      ),
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              selectedIndex: _index > 4 ? 0 : _index,
              onDestinationSelected: (i) => _goToTab(i),
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.home_outlined),
                  selectedIcon: const Icon(Icons.home),
                  label: l.t('home'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.explore_outlined),
                  selectedIcon: const Icon(Icons.explore),
                  label: l.t('explore'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.confirmation_number_outlined),
                  selectedIcon: const Icon(Icons.confirmation_number),
                  label: l.t('bookings'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.account_balance_wallet_outlined),
                  selectedIcon: const Icon(Icons.account_balance_wallet),
                  label: l.t('wallet'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.person_outline),
                  selectedIcon: const Icon(Icons.person),
                  label: l.t('profile'),
                ),
              ],
            ),
    );
  }
}

class _TopNavBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TopNavBtn(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active
              ? (isDark ? TIColors.darkCard : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: active
                ? TIColors.orangeDeep
                : Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
      ),
    );
  }
}

class _HeaderPillButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  const _HeaderPillButton({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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
}
