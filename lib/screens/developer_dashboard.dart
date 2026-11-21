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
import 'notifications_sheet.dart';

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
  Map<String, Map<String, dynamic>> _paymentsByBooking = {};

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
      final Map<String, Map<String, dynamic>> payMap = {};
      try {
        final payRes = await supabase.from('payments').select();
        for (final row in List<Map<String, dynamic>>.from(payRes)) {
          final bid = row['booking_id']?.toString();
          if (bid != null && bid.isNotEmpty) {
            payMap[bid] = row;
          }
        }
      } catch (_) {}

      final bookingsList = List<Map<String, dynamic>>.from(bookingsRes);
      final ticketsList = List<Map<String, dynamic>>.from(ticketsRes);
      double revenue = 0;
      for (final b in bookingsList) {
        revenue += (b['total_yer'] as num?)?.toDouble() ?? 0;
      }

      if (!mounted) return;
      setState(() {
        _users = List<Map<String, dynamic>>.from(usersRes);
        _paymentsByBooking = payMap;
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

  String _serviceLabel(String? code, bool ar) {
    switch (code) {
      case 'hotel':
        return ar ? 'فندق / إقامة' : 'Hotel';
      case 'rentCar':
        return ar ? 'تأجير سيارة' : 'Car Rental';
      case 'localRide':
        return ar ? 'سيارة مع سائق' : 'Ride with Driver';
      case 'tour':
        return ar ? 'رحلة سياحية' : 'Tour';
      case 'package':
        return ar ? 'باقة سفر' : 'Package';
      case 'airport':
        return ar ? 'توصيل مطار' : 'Airport Transfer';
      default:
        return code ?? (ar ? 'خدمة' : 'Service');
    }
  }

  String _paymentLabel(String? method, bool ar) {
    switch (method) {
      case 'wallet':
        return ar ? 'المحفظة الإلكترونية' : 'App Wallet';
      case 'kuraimi':
        return ar ? 'بنك الكريمي (حوالة)' : 'Kuraimi Bank';
      case 'digitalWallet':
        return ar ? 'محفظة رقمية (جوالي/فلوسك)' : 'Digital Wallet';
      case 'cash':
        return ar ? 'الدفع نقداً عند الاستلام' : 'Cash';
      default:
        return method ?? (ar ? 'غير محدد' : 'N/A');
    }
  }

  String _statusLabel(String? st, bool ar) {
    switch (st) {
      case 'confirmed':
        return ar ? 'مؤكد' : 'Confirmed';
      case 'completed':
        return ar ? 'مكتمل' : 'Completed';
      case 'cancelled':
        return ar ? 'ملغي' : 'Cancelled';
      default:
        return st ?? (ar ? 'قيد المراجعة' : 'Pending');
    }
  }

  Color _statusColor(String? st) {
    switch (st) {
      case 'confirmed':
        return TIColors.success;
      case 'completed':
        return TIColors.cardRent;
      case 'cancelled':
        return TIColors.danger;
      default:
        return TIColors.warning;
    }
  }

  Map<String, dynamic>? _findUserForBooking(Map<String, dynamic> b) {
    final uid = b['user_id']?.toString();
    if (uid == null || uid.isEmpty) return null;
    for (final u in _users) {
      if (u['user_id']?.toString() == uid) return u;
    }
    return null;
  }

  Future<void> _updateBookingStatus(
      Map<String, dynamic> b, String newStatus, bool ar) async {
    await supabase
        .from('bookings')
        .update({'status': newStatus})
        .eq('booking_id', b['booking_id']);
    final targetUid = b['user_id'] is int
        ? b['user_id'] as int
        : int.tryParse(b['user_id']?.toString() ?? '');
    final statusTitle = switch (newStatus) {
      'confirmed' => ar ? 'تم تأكيد حجزك ✅' : 'Booking Confirmed',
      'completed' => ar ? 'تم إكمال حجزك 🎉' : 'Booking Completed',
      'cancelled' => ar ? 'تم إلغاء حجزك ❌' : 'Booking Cancelled',
      _ => ar ? 'تحديث حالة الحجز' : 'Booking Updated',
    };
    await AppState.instance?.sendNotification(
      userId: targetUid,
      targetRole: 'customer',
      title: statusTitle,
      body: '${b['title'] ?? b['booking_id']} — ${_statusLabel(newStatus, ar)}',
      type: 'booking_status',
    );
    await logAdminAction(
      'Booking ${b['booking_id']} status',
      oldVal: b['status']?.toString(),
      newVal: newStatus,
    );
  }

  void _openBookingsSheet(bool ar) {
    String statusFilter = 'all';
    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final filtered = _bookings.where((b) {
            final st = (b['status'] ?? '').toString();
            if (statusFilter != 'all' && st != statusFilter) return false;
            if (searchQuery.trim().isNotEmpty) {
              final q = searchQuery.trim().toLowerCase();
              final u = _findUserForBooking(b);
              final haystack = [
                b['booking_id'],
                b['title'],
                b['service'],
                b['payment'],
                u?['first_name'],
                u?['second_name'],
                u?['phone'],
                u?['email'],
              ].whereType<Object>().join(' ').toLowerCase();
              if (!haystack.contains(q)) return false;
            }
            return true;
          }).toList();

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.85,
            maxChildSize: 0.95,
            builder: (_, ctrl) => Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            ar
                                ? 'إدارة الحجوزات (${filtered.length})'
                                : 'Bookings Management (${filtered.length})',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w900),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () async {
                              await _loadStats();
                              setSheet(() {});
                            },
                            icon: const Icon(Icons.refresh),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        onChanged: (v) => setSheet(() => searchQuery = v),
                        decoration: InputDecoration(
                          hintText: ar
                              ? 'ابحث برقم الحجز، اسم العميل، الهاتف، أو البريد...'
                              : 'Search booking ID, customer name, phone, email...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final item in [
                              ('all', ar ? 'الكل' : 'All'),
                              ('confirmed', ar ? 'مؤكد' : 'Confirmed'),
                              ('completed', ar ? 'مكتمل' : 'Completed'),
                              ('cancelled', ar ? 'ملغي' : 'Cancelled'),
                            ])
                              Padding(
                                padding: const EdgeInsetsDirectional.only(end: 8),
                                child: ChoiceChip(
                                  label: Text(item.$2),
                                  selected: statusFilter == item.$1,
                                  onSelected: (_) =>
                                      setSheet(() => statusFilter = item.$1),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Text(
                            ar
                                ? 'لا توجد حجوزات مطابقة'
                                : 'No matching bookings',
                            style:
                                TextStyle(color: Theme.of(ctx).hintColor),
                          ),
                        )
                      : ListView.builder(
                          controller: ctrl,
                          padding: const EdgeInsets.all(14),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) {
                            final b = filtered[i];
                            final u = _findUserForBooking(b);
                            final bid = b['booking_id']?.toString() ?? '—';
                            final payRow = _paymentsByBooking[bid];
                            final st = b['status']?.toString() ?? 'confirmed';
                            final stColor = _statusColor(st);
                            final fullName = u != null
                                ? '${u['first_name'] ?? ''} ${u['second_name'] ?? ''}'
                                    .trim()
                                : '';
                            final createdRaw =
                                (b['created_at'] ?? '').toString();
                            final createdShort = createdRaw.length >= 16
                                ? createdRaw
                                    .substring(0, 16)
                                    .replaceFirst('T', ' ')
                                : createdRaw;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Theme.of(ctx).cardColor,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: Theme.of(ctx)
                                      .dividerColor
                                      .withOpacity(0.5),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // الرأس: رقم الحجز + الحالة
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: TIColors.orangeSoft,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          bid,
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w900,
                                            color: TIColors.orangeDeep,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: stColor.withOpacity(0.14),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          _statusLabel(st, ar),
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w800,
                                            color: stColor,
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        '${b['total_yer'] ?? 0} YER',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 14.5,
                                          color: TIColors.orangeDeep,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  // الخدمة والعنوان
                                  Text(
                                    b['title']?.toString() ?? bid,
                                    style: const TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_serviceLabel(b['service']?.toString(), ar)} • ${b['date_text'] ?? '—'}',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: Theme.of(ctx).hintColor,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  // بطاقة بيانات العميل
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Theme.of(ctx)
                                          .scaffoldBackgroundColor,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.person_outline,
                                                size: 16,
                                                color: TIColors.orangeDeep),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                '${ar ? 'العميل' : 'Customer'}: ${fullName.isEmpty ? '#${b['user_id'] ?? '—'}' : fullName}',
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 13),
                                              ),
                                            ),
                                            if (u?['age'] != null)
                                              Text(
                                                '${u!['age']} ${ar ? 'سنة' : 'yrs'}',
                                                style: TextStyle(
                                                    fontSize: 11.5,
                                                    color: Theme.of(ctx)
                                                        .hintColor),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        if (u?['phone'] != null &&
                                            u!['phone'].toString().isNotEmpty)
                                          Text(
                                            '${ar ? 'الهاتف' : 'Phone'}: ${u['phone']}',
                                            style:
                                                const TextStyle(fontSize: 12),
                                          ),
                                        if (u?['email'] != null &&
                                            u!['email'].toString().isNotEmpty)
                                          Text(
                                            '${ar ? 'البريد' : 'Email'}: ${u['email']}',
                                            style:
                                                const TextStyle(fontSize: 12),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  // تفاصيل الدفع والوقت
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 4,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.payment_rounded,
                                              size: 15,
                                              color: TIColors.cardRent),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${ar ? 'الدفع' : 'Payment'}: ${_paymentLabel(b['payment']?.toString(), ar)}',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700),
                                          ),
                                        ],
                                      ),
                                      if (payRow?['status'] != null)
                                        Text(
                                          '(${payRow!['status']})',
                                          style: TextStyle(
                                              fontSize: 11.5,
                                              color:
                                                  Theme.of(ctx).hintColor),
                                        ),
                                      if (createdShort.isNotEmpty)
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.access_time,
                                                size: 14,
                                                color:
                                                    Theme.of(ctx).hintColor),
                                            const SizedBox(width: 4),
                                            Text(
                                              createdShort,
                                              style: TextStyle(
                                                  fontSize: 11.5,
                                                  color:
                                                      Theme.of(ctx).hintColor),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  // أزرار التحكم بالحالة مباشرة
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: st == 'confirmed'
                                              ? null
                                              : () async {
                                                  await _updateBookingStatus(
                                                      b, 'confirmed', ar);
                                                  await _loadStats();
                                                  setSheet(() {});
                                                },
                                          style: OutlinedButton.styleFrom(
                                            minimumSize: const Size(0, 36),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6),
                                            foregroundColor: TIColors.success,
                                            side: const BorderSide(
                                                color: TIColors.success),
                                          ),
                                          child: Text(
                                            ar ? 'تأكيد' : 'Confirm',
                                            style:
                                                const TextStyle(fontSize: 12),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: st == 'completed'
                                              ? null
                                              : () async {
                                                  await _updateBookingStatus(
                                                      b, 'completed', ar);
                                                  await _loadStats();
                                                  setSheet(() {});
                                                },
                                          style: OutlinedButton.styleFrom(
                                            minimumSize: const Size(0, 36),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6),
                                            foregroundColor: TIColors.cardRent,
                                            side: const BorderSide(
                                                color: TIColors.cardRent),
                                          ),
                                          child: Text(
                                            ar ? 'إكمال' : 'Complete',
                                            style:
                                                const TextStyle(fontSize: 12),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: st == 'cancelled'
                                              ? null
                                              : () async {
                                                  await _updateBookingStatus(
                                                      b, 'cancelled', ar);
                                                  await _loadStats();
                                                  setSheet(() {});
                                                },
                                          style: OutlinedButton.styleFrom(
                                            minimumSize: const Size(0, 36),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6),
                                            foregroundColor: TIColors.danger,
                                            side: const BorderSide(
                                                color: TIColors.danger),
                                          ),
                                          child: Text(
                                            ar ? 'إلغاء' : 'Cancel',
                                            style:
                                                const TextStyle(fontSize: 12),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
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

  Future<void> _openSendNotificationDialog(bool ar) async {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    String notifType = 'offer';
    int? selectedUserId; // null = broadcast to all customers

    try {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setSheet) => Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ar ? 'إرسال إشعار يدوي للعملاء' : 'Send Notification to Customers',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int?>(
                    value: selectedUserId,
                    decoration: InputDecoration(
                      labelText: ar ? 'المستلم' : 'Recipient',
                    ),
                    items: [
                      DropdownMenuItem<int?>(
                        value: null,
                        child: Text(ar ? 'جميع العملاء (إشعار عام)' : 'All Customers (Broadcast)'),
                      ),
                      ..._users
                          .where((u) => (u['role'] ?? 'customer') != 'developer')
                          .map((u) {
                        final uid = u['user_id'] is int
                            ? u['user_id'] as int
                            : int.tryParse(u['user_id']?.toString() ?? '');
                        final name = '${u['first_name'] ?? ''} ${u['second_name'] ?? ''}'.trim();
                        return DropdownMenuItem<int?>(
                          value: uid,
                          child: Text(
                            name.isEmpty ? '#$uid' : '$name (#$uid)',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }),
                    ],
                    onChanged: (v) => setSheet(() => selectedUserId = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: notifType,
                    decoration: InputDecoration(
                      labelText: ar ? 'نوع الإشعار' : 'Notification Type',
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'offer',
                        child: Text(ar ? 'عرض وتخفيض (Offer)' : 'Offer / Promo'),
                      ),
                      DropdownMenuItem(
                        value: 'booking_status',
                        child: Text(ar ? 'تحديث حجز (Booking)' : 'Booking Update'),
                      ),
                      DropdownMenuItem(
                        value: 'general',
                        child: Text(ar ? 'تنبيه عام (General)' : 'General Alert'),
                      ),
                    ],
                    onChanged: (v) => setSheet(() => notifType = v ?? 'offer'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      labelText: ar ? 'عنوان الإشعار' : 'Title',
                      hintText: ar ? 'مثال: خصم 25% على فنادق صنعاء!' : 'e.g. 25% off Sanaa hotels!',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: bodyCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: ar ? 'نص الإشعار' : 'Message Body',
                      hintText: ar ? 'اكتب تفاصيل العرض أو التنبيه هنا...' : 'Write details here...',
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        final t = titleCtrl.text.trim();
                        final b = bodyCtrl.text.trim();
                        if (t.isEmpty || b.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(ar
                                  ? 'يرجى كتابة العنوان ونص الإشعار'
                                  : 'Please enter title and message'),
                            ),
                          );
                          return;
                        }
                        await AppState.instance?.sendNotification(
                          userId: selectedUserId,
                          targetRole: selectedUserId == null ? 'all' : 'customer',
                          title: t,
                          body: b,
                          type: notifType,
                        );
                        await logAdminAction(
                          'Send manual notification',
                          newVal: '$t (${selectedUserId == null ? "all" : "user #$selectedUserId"})',
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(ar
                                  ? 'تم إرسال الإشعار بنجاح ✅'
                                  : 'Notification sent successfully'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: Text(ar ? 'إرسال الإشعار الآن' : 'Send Now'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } finally {
      titleCtrl.dispose();
      bodyCtrl.dispose();
    }
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
      (Icons.campaign_rounded, bi('إرسال إشعار يدوي للعملاء', 'Send Notification to Customers'),
          () => _openSendNotificationDialog(ar)),
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
          const NotificationBellButton(),
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
                  onTap: s.$3,
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
