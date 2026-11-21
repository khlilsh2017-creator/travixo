import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/demo_data.dart';
import '../data/models.dart';
import '../l10n/app_localizations.dart';
import '../state/app_state.dart';
import '../supabase.dart';
import '../theme/app_theme.dart';
import 'auth_screens.dart';
import 'admin_crud_screens.dart';
import 'support_chat_screen.dart';

/// Travixo — Admin/Developer Portal connected to Supabase
class DeveloperDashboard extends StatefulWidget {
  const DeveloperDashboard({super.key});

  @override
  State<DeveloperDashboard> createState() => _DeveloperDashboardState();
}

class _DeveloperDashboardState extends State<DeveloperDashboard> {
  bool _loading = true;
  int _usersCount = 0;
  int _bookingsCount = 0;
  double _totalRevenueYer = 0;
  int _carsCount = 0;
  int _roomsCount = 0;
  int _openTicketsCount = 0;
  List<Map<String, dynamic>> _tickets = [];
  List<Map<String, dynamic>> _bookings = [];
  List<Map<String, dynamic>> _users = [];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    try {
      final usersRes = await supabase.from('users').select().order('created_at', ascending: false);
      final bookingsRes = await supabase
          .from('bookings')
          .select()
          .order('created_at', ascending: false);
      final carsRes = await supabase
          .from('vehicles')
          .select('vehicle_id')
          .eq('status', 'available');
      final roomsRes = await supabase
          .from('hotel_rooms')
          .select('room_id')
          .eq('available', true);
      final ticketsRes = await supabase
          .from('support_tickets')
          .select()
          .order('created_at', ascending: false);

      final bookingsList = List<Map<String, dynamic>>.from(bookingsRes);
      final ticketsList = List<Map<String, dynamic>>.from(ticketsRes);
      double revenue = 0;
      for (final b in bookingsList) {
        revenue += (b['total_yer'] as num?)?.toDouble() ?? 0;
      }

      if (!mounted) return;
      setState(() {
        _users = List<Map<String, dynamic>>.from(usersRes);
        _usersCount = _users.length;
        _bookings = bookingsList;
        _bookingsCount = bookingsList.length;
        _totalRevenueYer = revenue;
        _carsCount = (carsRes as List).isNotEmpty
            ? carsRes.length
            : kCars.where((c) => c.status == Availability.available).length;
        _roomsCount = (roomsRes as List).isNotEmpty
            ? roomsRes.length
            : kHotels.expand((h) => h.rooms).where((r) => r.available).length;
        _tickets = ticketsList;
        _openTicketsCount =
            ticketsList.where((t) => t['status'] == 'open').length;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _carsCount =
            kCars.where((c) => c.status == Availability.available).length;
        _roomsCount =
            kHotels.expand((h) => h.rooms).where((r) => r.available).length;
        _loading = false;
      });
    }
  }

  Future<void> _logout() async {
    try {
      await supabase.auth.signOut();
    } catch (_) {}
    if (!mounted) return;
    context.read<AppState>().logout();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const UserTypeScreen()),
      (r) => false,
    );
  }

  void _openBookingsSheet(bool ar) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        builder: (_, ctrl) => ListView(
          controller: ctrl,
          padding: const EdgeInsets.all(16),
          children: [
            Text(ar ? 'الحجوزات من Supabase' : 'Supabase Bookings',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            if (_bookings.isEmpty)
              Center(
                  child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(ar ? 'لا توجد حجوزات بعد' : 'No bookings yet')))
            else
              ..._bookings.map((b) => ListTile(
                    leading: const Icon(Icons.receipt_long, color: TIColors.teal),
                    title: Text(b['title']?.toString() ?? b['booking_id'].toString()),
                    subtitle: Text('${b['status']} • ${b['date_text'] ?? ''}'),
                    trailing: PopupMenuButton<String>(
                      onSelected: (newStatus) async {
                        await supabase
                            .from('bookings')
                            .update({'status': newStatus})
                            .eq('booking_id', b['booking_id']);
                        await logAdminAction(
                          'Booking ${b['booking_id']} status',
                          oldVal: b['status']?.toString(),
                          newVal: newStatus,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        _loadStats();
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'confirmed', child: Text('تأكيد (confirmed)')),
                        PopupMenuItem(value: 'completed', child: Text('مكتمل (completed)')),
                        PopupMenuItem(value: 'cancelled', child: Text('إلغاء (cancelled)')),
                      ],
                      child: Chip(
                        label: Text('${b['total_yer'] ?? 0} YER'),
                      ),
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  void _openUsersSheet(bool ar) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        builder: (_, ctrl) => ListView(
          controller: ctrl,
          padding: const EdgeInsets.all(16),
          children: [
            Text(ar ? 'المستخدمون المسجلون' : 'Registered Users',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            if (_users.isEmpty)
              Center(
                  child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(ar ? 'لا يوجد مستخدمون بعد' : 'No users yet')))
            else
              ..._users.map((u) => ListTile(
                    leading: const Icon(Icons.person, color: TIColors.teal),
                    title: Text('${u['first_name'] ?? ''} ${u['second_name'] ?? ''}'),
                    subtitle: Text('${u['phone'] ?? u['email'] ?? '—'} • ${u['role'] ?? 'customer'}'),
                    trailing: Text('#${u['user_id']}'),
                  )),
          ],
        ),
      ),
    );
  }

  void _openTicketsSheet(bool ar) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        builder: (_, ctrl) => ListView(
          controller: ctrl,
          padding: const EdgeInsets.all(16),
          children: [
            Text(ar ? 'تذاكر الدعم الفني' : 'Support Tickets',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            if (_tickets.isEmpty)
              Center(
                  child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(ar ? 'لا توجد تذاكر دعم' : 'No support tickets')))
            else
              ..._tickets.map((t) => ListTile(
                    leading: const Icon(Icons.support_agent, color: TIColors.gold),
                    title: Text(t['subject']?.toString() ?? ''),
                    subtitle: Text(
                        '${t['user_name'] ?? ''} • ${t['status'] ?? 'open'}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => SupportChatScreen(ticket: t)),
                      );
                    },
                  )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final ar = l.isArabic;
    final state = context.watch<AppState>();
    String bi(String a, String e) => ar ? a : e;

    final kpis = [
      _Kpi(bi('المستخدمون', 'Users'), '$_usersCount', Icons.people,
          TIColors.teal),
      _Kpi(bi('إجمالي الحجوزات', 'Total Bookings'), '$_bookingsCount',
          Icons.receipt_long, TIColors.gold),
      _Kpi(bi('إجمالي الإيرادات', 'Total Revenue'), l.money(_totalRevenueYer),
          Icons.trending_up, TIColors.success),
      _Kpi(bi('سيارات متاحة', 'Cars Available'), '$_carsCount',
          Icons.directions_car, TIColors.teal),
      _Kpi(bi('غرف متاحة', 'Rooms Available'), '$_roomsCount', Icons.hotel,
          TIColors.gold),
      _Kpi(bi('تذاكر دعم مفتوحة', 'Open Tickets'), '$_openTicketsCount',
          Icons.support_agent, TIColors.teal),
    ];

    final sections = [
      (Icons.people, bi('المستخدمون المسجلون', 'Registered Users'),
          () => _openUsersSheet(ar)),
      (Icons.receipt_long, bi('إدارة الحجوزات', 'Bookings'),
          () => _openBookingsSheet(ar)),
      (Icons.support_agent, bi('تذاكر الدعم الفني', 'Support Tickets'),
          () => _openTicketsSheet(ar)),
      (Icons.hotel, bi('إدارة الفنادق والغرف', 'Hotels & Rooms'), () async {
        await Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AdminHotelsScreen()));
        _loadStats();
      }),
      (Icons.directions_car, bi('إدارة السيارات', 'Fleet Management'), () async {
        await Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AdminVehiclesScreen()));
        _loadStats();
      }),
      (Icons.badge_outlined, bi('إدارة السائقين', 'Drivers'), () async {
        await Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AdminDriversScreen()));
        _loadStats();
      }),
      (Icons.price_change, bi('إدارة الأسعار', 'Pricing'), () async {
        await Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AdminPricingScreen()));
        _loadStats();
      }),
      (Icons.local_offer_outlined, bi('العروض والمحتوى', 'Offers & Content'), () async {
        await Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AdminOffersScreen()));
        _loadStats();
      }),
      (Icons.history, bi('سجل التدقيق', 'Audit Logs'), () async {
        await Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AdminAuditLogsScreen()));
      }),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Travixo — Admin'),
        actions: [
          IconButton(
            onPressed: _loadStats,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: () => state.toggleTheme(),
            icon: Icon(state.isDark ? Icons.light_mode : Icons.dark_mode),
          ),
          IconButton(
            onPressed: () => state.toggleLanguage(),
            icon: Text(ar ? 'EN' : 'ع',
                style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: TIColors.danger),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '${bi('مرحباً', 'Welcome')} ${state.user?.firstName ?? ''} 👋',
              style:
                  const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              _loading
                  ? bi('جارٍ تحديث البيانات من Supabase...',
                      'Refreshing live data from Supabase...')
                  : bi('متصل بقاعدة بيانات Supabase الحية',
                      'Connected to live Supabase database'),
              style: TextStyle(
                  fontSize: 12, color: Theme.of(context).hintColor),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.6,
              children: kpis.map((k) {
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color:
                            Theme.of(context).dividerColor.withOpacity(.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(children: [
                        Icon(k.icon, size: 17, color: k.color),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(k.label,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context).hintColor),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      Text(k.value,
                          style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              color: k.color)),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 22),
            Text(bi('الإدارة السريعة', 'Quick Management'),
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            ...sections.map((s) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: Theme.of(context).dividerColor.withOpacity(.4)),
                ),
                child: ListTile(
                  onTap: s.$3 ??
                      () => ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(bi(
                                    'متصل بجدول Supabase — يمكنك إدارته من SQL/Table Editor حالياً',
                                    'Connected to Supabase — manage via Table Editor'))),
                          ),
                  leading: Icon(s.$1, color: TIColors.teal),
                  title: Text(s.$2,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _Kpi {
  final String label, value;
  final IconData icon;
  final Color color;
  const _Kpi(this.label, this.value, this.icon, this.color);
}
