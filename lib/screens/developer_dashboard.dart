import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/demo_data.dart';
import '../data/models.dart';
import '../l10n/app_localizations.dart';
import '../state/app_state.dart';
import '../supabase.dart';
import '../theme/app_theme.dart';
import 'admin_crud_screens.dart';
import 'auth_screens.dart';
import 'notifications_sheet.dart';
import 'support_chat_screen.dart';

/// Travixo — لوحة تحكم المطورين والإدارة المتطورة (Responsive Admin Portal)
/// تدعم الشريط الجانبي على الويب/سطح المكتب وشريط التنقل السفلي على الجوال
/// مع 5 أقسام متكاملة: النظرة العامة، الحجوزات، الكتالوج، العملاء والمحافظ، والدعم الفني
class DeveloperDashboard extends StatefulWidget {
  const DeveloperDashboard({super.key});

  @override
  State<DeveloperDashboard> createState() => _DeveloperDashboardState();
}

class _DeveloperDashboardState extends State<DeveloperDashboard> {
  int _tabIndex = 0;
  bool _loading = true;

  // إحصائيات
  int _usersCount = 0;
  int _bookingsCount = 0;
  double _totalRevenueYer = 0;
  int _carsCount = 0;
  int _roomsCount = 0;
  int _openTicketsCount = 0;

  // بيانات حية من Supabase
  List<Map<String, dynamic>> _tickets = [];
  List<Map<String, dynamic>> _bookings = [];
  List<Map<String, dynamic>> _users = [];
  Map<String, Map<String, dynamic>> _paymentsByBooking = {};
  Map<String, double> _walletBalanceByUser = {};

  // فلاتر وبحث
  String _bookingFilter = 'all';
  String _bookingQuery = '';
  String _userFilter = 'all';
  String _userQuery = '';
  String _ticketFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    try {
      final usersRes = await supabase
          .from('users')
          .select()
          .order('created_at', ascending: false);
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

      final Map<String, double> walletMap = {};
      try {
        final walRes = await supabase.from('wallets').select('user_id, balance');
        for (final row in List<Map<String, dynamic>>.from(walRes)) {
          final uid = row['user_id']?.toString();
          if (uid != null && uid.isNotEmpty) {
            walletMap[uid] = (row['balance'] as num?)?.toDouble() ?? 0;
          }
        }
      } catch (_) {}

      final bookingsList = List<Map<String, dynamic>>.from(bookingsRes);
      final ticketsList = List<Map<String, dynamic>>.from(ticketsRes);
      double revenue = 0;
      for (final b in bookingsList) {
        if ((b['status'] ?? '') != 'cancelled') {
          revenue += (b['total_yer'] as num?)?.toDouble() ?? 0;
        }
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
        _paymentsByBooking = payMap;
        _walletBalanceByUser = walletMap;
        _loading = false;
      });
    } catch (_) {
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

  // ==================== دوال مساعدة للتسميات والألوان ====================
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
        return ar ? 'بنك الكريمي' : 'Kuraimi Bank';
      case 'digitalWallet':
        return ar ? 'محفظة رقمية' : 'Digital Wallet';
      case 'cash':
        return ar ? 'نقداً عند الاستلام' : 'Cash';
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

  int _bookingCountForUser(String uid) {
    return _bookings.where((b) => b['user_id']?.toString() == uid).length;
  }

  // ==================== عمليات التحديث والإشعارات ====================
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
    await _loadStats();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ar
              ? 'تم تحديث حالة الحجز وإشعار العميل ✅'
              : 'Booking updated & customer notified',
        ),
      ),
    );
  }

  Future<void> _openSendNotificationDialog(bool ar,
      {int? preselectedUserId}) async {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    String notifType = preselectedUserId == null ? 'offer' : 'general';
    int? selectedUserId = preselectedUserId;

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
                    ar
                        ? 'إرسال إشعار يدوي للعملاء'
                        : 'Send Notification to Customers',
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
                        child: Text(ar
                            ? 'جميع العملاء (إشعار عام)'
                            : 'All Customers (Broadcast)'),
                      ),
                      ..._users
                          .where((u) => (u['role'] ?? 'customer') != 'developer')
                          .map((u) {
                        final uid = u['user_id'] is int
                            ? u['user_id'] as int
                            : int.tryParse(u['user_id']?.toString() ?? '');
                        final name =
                            '${u['first_name'] ?? ''} ${u['second_name'] ?? ''}'
                                .trim();
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
                        child:
                            Text(ar ? 'تحديث حجز (Booking)' : 'Booking Update'),
                      ),
                      DropdownMenuItem(
                        value: 'wallet',
                        child: Text(ar ? 'تحديث محفظة (Wallet)' : 'Wallet Alert'),
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
                      hintText: ar
                          ? 'مثال: خصم 25% على فنادق صنعاء!'
                          : 'e.g. 25% off Sanaa hotels!',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: bodyCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: ar ? 'نص الإشعار' : 'Message Body',
                      hintText: ar
                          ? 'اكتب تفاصيل العرض أو التنبيه هنا...'
                          : 'Write details here...',
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
                          targetRole:
                              selectedUserId == null ? 'all' : 'customer',
                          title: t,
                          body: b,
                          type: notifType,
                        );
                        await logAdminAction(
                          'Send manual notification',
                          newVal:
                              '$t (${selectedUserId == null ? "all" : "user #$selectedUserId"})',
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

  Future<void> _openAdjustWalletDialog(
      Map<String, dynamic> userRow, bool ar) async {
    final uid = userRow['user_id'] is int
        ? userRow['user_id'] as int
        : int.tryParse(userRow['user_id']?.toString() ?? '');
    if (uid == null) return;

    final amtCtrl = TextEditingController();
    final reasonCtrl = TextEditingController(
      text: ar ? 'شحن رصيد من الإدارة' : 'Admin wallet top-up',
    );
    bool isCredit = true;

    try {
      await showDialog(
        context: context,
        builder: (d) => StatefulBuilder(
          builder: (d, setDlg) => AlertDialog(
            title: Text(ar ? 'تعديل رصيد المحفظة' : 'Adjust Wallet Balance'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(
                      value: true,
                      label: Text(ar ? 'إيداع (+)' : 'Credit (+)'),
                    ),
                    ButtonSegment(
                      value: false,
                      label: Text(ar ? 'خصم (-)' : 'Debit (-)'),
                    ),
                  ],
                  selected: {isCredit},
                  onSelectionChanged: (s) => setDlg(() => isCredit = s.first),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amtCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: ar ? 'المبلغ بالريال (YER)' : 'Amount (YER)',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: reasonCtrl,
                  decoration: InputDecoration(
                    labelText: ar ? 'السبب / البيان' : 'Reason',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(d),
                child: Text(ar ? 'إلغاء' : 'Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  final amt = double.tryParse(amtCtrl.text.trim()) ?? 0;
                  if (amt <= 0) return;
                  final delta = isCredit ? amt : -amt;
                  try {
                    var wal = await supabase
                        .from('wallets')
                        .select()
                        .eq('user_id', uid)
                        .maybeSingle();
                    if (wal == null) {
                      wal = await supabase
                          .from('wallets')
                          .insert({
                            'user_id': uid,
                            'balance': delta > 0 ? delta : 0,
                            'currency': 'YER',
                          })
                          .select()
                          .single();
                    } else {
                      final cur = (wal['balance'] as num?)?.toDouble() ?? 0;
                      final next = (cur + delta).clamp(0, double.infinity);
                      await supabase
                          .from('wallets')
                          .update({'balance': next})
                          .eq('wallet_id', wal['wallet_id']);
                    }
                    await supabase.from('wallet_transactions').insert({
                      'wallet_id': wal['wallet_id'],
                      'amount': delta,
                      'reason': reasonCtrl.text.trim(),
                      'status': 'completed',
                    });
                    await AppState.instance?.sendNotification(
                      userId: uid,
                      targetRole: 'customer',
                      title: isCredit
                          ? (ar ? 'تم شحن محفظتك 💰' : 'Wallet Credited')
                          : (ar ? 'تم خصم مبلغ من محفظتك' : 'Wallet Debited'),
                      body:
                          '${isCredit ? "+" : "-"}${amt.toStringAsFixed(0)} YER — ${reasonCtrl.text.trim()}',
                      type: 'wallet',
                    );
                    await logAdminAction(
                      'Wallet adjust user #$uid',
                      newVal: '${delta.toStringAsFixed(0)} YER',
                    );
                    if (d.mounted) Navigator.pop(d);
                    await _loadStats();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(ar
                              ? 'تم تحديث رصيد المحفظة وإشعار العميل ✅'
                              : 'Wallet updated & customer notified'),
                        ),
                      );
                    }
                  } catch (e) {
                    if (d.mounted) {
                      ScaffoldMessenger.of(d).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  }
                },
                child: Text(ar ? 'حفظ' : 'Save'),
              ),
            ],
          ),
        ),
      );
    } finally {
      amtCtrl.dispose();
      reasonCtrl.dispose();
    }
  }

  Future<void> _openAddDeveloperDialog(bool ar) async {
    final firstCtrl = TextEditingController();
    final secondCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    try {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) => Padding(
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
                  ar ? 'إضافة مطور / مشرف جديد' : 'Add New Developer / Admin',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  ar
                      ? 'يدخل المطور مباشرة بالبريد الإلكتروني وكلمة المرور بدون الحاجة لرمز تحقق OTP.'
                      : 'Developer signs in directly with Email & Password (no OTP required).',
                  style: TextStyle(
                      fontSize: 12.5, color: Theme.of(ctx).hintColor),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: firstCtrl,
                        decoration: InputDecoration(
                          labelText: ar ? 'الاسم الأول *' : 'First Name *',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: secondCtrl,
                        decoration: InputDecoration(
                          labelText: ar ? 'الاسم الثاني' : 'Last Name',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: ar ? 'البريد الإلكتروني *' : 'Email Address *',
                    hintText: 'dev@example.com',
                    prefixIcon: const Icon(Icons.mail_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: ar
                        ? 'كلمة مرور المطور (6 أحرف فأكثر) *'
                        : 'Developer Password (6+ chars) *',
                    prefixIcon: const Icon(Icons.lock_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: ar ? 'رقم الهاتف (اختياري)' : 'Phone (Optional)',
                    prefixIcon: const Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      final fn = firstCtrl.text.trim();
                      final sn = secondCtrl.text.trim();
                      final em = emailCtrl.text.trim().toLowerCase();
                      final pw = passCtrl.text.trim();
                      final ph = phoneCtrl.text.trim();
                      if (fn.isEmpty || !em.contains('@') || pw.length < 6) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text(ar
                                ? 'أدخل الاسم، وبريداً صحيحاً، وكلمة مرور من 6 أحرف فأكثر'
                                : 'Enter name, valid email, and 6+ char password'),
                          ),
                        );
                        return;
                      }
                      try {
                        final existing = await supabase
                            .from('users')
                            .select()
                            .eq('email', em)
                            .maybeSingle();
                        if (existing != null) {
                          await supabase.from('users').update({
                            'first_name': fn,
                            if (sn.isNotEmpty) 'second_name': sn,
                            if (ph.isNotEmpty) 'phone': ph,
                            'password_code': pw,
                            'role': 'developer',
                          }).eq('user_id', existing['user_id']);
                        } else {
                          await supabase.from('users').insert({
                            'first_name': fn,
                            'second_name': sn,
                            'email': em,
                            if (ph.isNotEmpty) 'phone': ph,
                            'password_code': pw,
                            'age': 25,
                            'role': 'developer',
                          });
                        }
                        await logAdminAction(
                          'Add developer',
                          newVal: '$fn ($em)',
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        await _loadStats();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(ar
                                  ? 'تمت إضافة المطور بنجاح ✅ يمكنه الدخول بالبريد وكلمة المرور مباشرة'
                                  : 'Developer added! Ready to sign in with Email & Password.'),
                            ),
                          );
                        }
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                    label: Text(ar ? 'حفظ وإضافة المطور' : 'Save Developer'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } finally {
      firstCtrl.dispose();
      secondCtrl.dispose();
      emailCtrl.dispose();
      passCtrl.dispose();
      phoneCtrl.dispose();
    }
  }

  Future<void> _openChangeDevPasswordDialog(
      Map<String, dynamic> u, bool ar) async {
    final uid = u['user_id'];
    if (uid == null) return;
    final passCtrl = TextEditingController();
    try {
      await showDialog(
        context: context,
        builder: (d) => AlertDialog(
          title: Text(ar ? 'تغيير كلمة مرور المطور' : 'Change Developer Password'),
          content: TextField(
            controller: passCtrl,
            obscureText: true,
            decoration: InputDecoration(
              labelText: ar ? 'كلمة المرور الجديدة (6+ أحرف)' : 'New Password (6+ chars)',
              prefixIcon: const Icon(Icons.lock_reset_rounded),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(d),
              child: Text(ar ? 'إلغاء' : 'Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final pw = passCtrl.text.trim();
                if (pw.length < 6) return;
                try {
                  await supabase
                      .from('users')
                      .update({'password_code': pw})
                      .eq('user_id', uid);
                  await logAdminAction(
                    'Change developer password #$uid',
                    newVal: 'Updated',
                  );
                  if (d.mounted) Navigator.pop(d);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(ar
                            ? 'تم تغيير كلمة مرور المطور بنجاح ✅'
                            : 'Developer password updated'),
                      ),
                    );
                  }
                } catch (e) {
                  if (d.mounted) {
                    ScaffoldMessenger.of(d)
                        .showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              child: Text(ar ? 'حفظ' : 'Save'),
            ),
          ],
        ),
      );
    } finally {
      passCtrl.dispose();
    }
  }

  Future<void> _toggleUserRole(Map<String, dynamic> u, bool ar) async {
    final uid = u['user_id'];
    if (uid == null) return;
    final currentRole = (u['role'] ?? 'customer').toString();
    final isDev = currentRole == 'developer';
    final nextRole = isDev ? 'customer' : 'developer';
    try {
      await supabase
          .from('users')
          .update({'role': nextRole})
          .eq('user_id', uid);
      await logAdminAction(
        'Change role user #$uid',
        oldVal: currentRole,
        newVal: nextRole,
      );
      await _loadStats();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nextRole == 'developer'
                ? (ar
                    ? 'تمت ترقية المستخدم إلى مطور ✅'
                    : 'User promoted to Developer')
                : (ar
                    ? 'تم تحويل الحساب إلى عميل'
                    : 'Account changed to Customer'),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _toggleTicketStatus(Map<String, dynamic> t, bool ar) async {
    final current = (t['status'] ?? 'open').toString();
    final next = current == 'open' ? 'closed' : 'open';
    try {
      await supabase
          .from('support_tickets')
          .update({'status': next})
          .eq('ticket_id', t['ticket_id']);
      await logAdminAction(
        'Ticket #${t['ticket_id']} status',
        oldVal: current,
        newVal: next,
      );
      await _loadStats();
    } catch (_) {}
  }

  // ==================== واجهة البناء الرئيسية (Responsive) ====================
  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final ar = l.isArabic;
    final state = context.watch<AppState>();
    final isWide = MediaQuery.of(context).size.width >= 900;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String bi(String a, String e) => ar ? a : e;

    final navItems = [
      (Icons.dashboard_rounded, bi('نظرة عامة', 'Overview'), 0),
      (Icons.receipt_long_rounded, bi('الحجوزات', 'Bookings'), _bookingsCount),
      (Icons.grid_view_rounded, bi('الكتالوج', 'Catalog'), 0),
      (Icons.people_alt_rounded, bi('العملاء', 'Customers'), _usersCount),
      (Icons.support_agent_rounded, bi('الدعم', 'Support'), _openTicketsCount),
    ];

    final currentPage = switch (_tabIndex) {
      0 => _buildOverviewTab(l, ar, state),
      1 => _buildBookingsTab(l, ar),
      2 => _buildCatalogTab(ar),
      3 => _buildCustomersTab(l, ar),
      _ => _buildSupportTab(ar),
    };

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            // شريط جانبي داكن فاخر للويب وسطح المكتب
            Container(
              width: 248,
              color: TIColors.navy,
              child: SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              gradient: TravixoFX.orange,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.admin_panel_settings,
                                color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'TRAVIXO',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  bi('بوابة الإدارة المطوّرة', 'Admin Portal'),
                                  style: const TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Color(0xFF1E293B), height: 1),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: navItems.length,
                        itemBuilder: (_, idx) {
                          final item = navItems[idx];
                          final active = _tabIndex == idx;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: active
                                  ? TIColors.orangeDeep
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              dense: true,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              leading: Icon(
                                item.$1,
                                color: active
                                    ? Colors.white
                                    : const Color(0xFF94A3B8),
                                size: 20,
                              ),
                              title: Text(
                                item.$2,
                                style: TextStyle(
                                  color: active
                                      ? Colors.white
                                      : const Color(0xFFE2E8F0),
                                  fontWeight: active
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  fontSize: 13.5,
                                ),
                              ),
                              trailing: item.$3 > 0
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: active
                                            ? Colors.white.withOpacity(0.22)
                                            : const Color(0xFF1E293B),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        '${item.$3}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    )
                                  : null,
                              onTap: () => setState(() => _tabIndex = idx),
                            ),
                          );
                        },
                      ),
                    ),
                    const Divider(color: Color(0xFF1E293B), height: 1),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          IconButton(
                            tooltip: bi('تحديث', 'Refresh'),
                            onPressed: _loadStats,
                            icon: const Icon(Icons.refresh,
                                color: Colors.white70, size: 20),
                          ),
                          IconButton(
                            tooltip: bi('المظهر', 'Theme'),
                            onPressed: () => state.toggleTheme(),
                            icon: Icon(
                              state.isDark ? Icons.light_mode : Icons.dark_mode,
                              color: Colors.white70,
                              size: 20,
                            ),
                          ),
                          IconButton(
                            tooltip: bi('اللغة', 'Language'),
                            onPressed: () => state.toggleLanguage(),
                            icon: Text(
                              ar ? 'EN' : 'ع',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900),
                            ),
                          ),
                          IconButton(
                            tooltip: bi('خروج', 'Logout'),
                            onPressed: _logout,
                            icon: const Icon(Icons.logout,
                                color: TIColors.danger, size: 20),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // المحتوى الرئيسي للويب
            Expanded(
              child: Column(
                children: [
                  Container(
                    height: 64,
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    decoration: BoxDecoration(
                      color: isDark ? TIColors.darkCard : Colors.white,
                      border: Border(
                        bottom: BorderSide(
                          color: isDark
                              ? TIColors.darkLine
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          navItems[_tabIndex].$2,
                          style: const TextStyle(
                              fontSize: 19, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: TIColors.success.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.circle,
                                  size: 8, color: TIColors.success),
                              const SizedBox(width: 6),
                              Text(
                                _loading
                                    ? bi('جارٍ المزامنة...', 'Syncing...')
                                    : bi('متصل حي بـ Supabase', 'Live Supabase'),
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: TIColors.success,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: () => _openSendNotificationDialog(ar),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 38),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                          ),
                          icon: const Icon(Icons.campaign_rounded, size: 17),
                          label: Text(
                            bi('إرسال إشعار', 'Broadcast'),
                            style: const TextStyle(fontSize: 12.5),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const NotificationBellButton(asPill: true),
                      ],
                    ),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _loadStats,
                      child: currentPage,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // واجهة الجوال المتجاوبة
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _tabIndex == 0 ? 'Travixo — Admin' : navItems[_tabIndex].$2,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
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
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: TIColors.danger),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: currentPage,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: [
          for (final item in navItems)
            NavigationDestination(
              icon: Icon(item.$1),
              label: item.$2,
            ),
        ],
      ),
    );
  }

  // ==================== التبويب 1: النظرة العامة والتحليلات ====================
  Widget _buildOverviewTab(AppLocalizations l, bool ar, AppState state) {
    String bi(String a, String e) => ar ? a : e;
    final confirmedCount =
        _bookings.where((b) => b['status'] == 'confirmed').length;
    final completedCount =
        _bookings.where((b) => b['status'] == 'completed').length;
    final cancelledCount =
        _bookings.where((b) => b['status'] == 'cancelled').length;
    final totalB = _bookings.isEmpty ? 1 : _bookings.length;

    final payCounts = <String, int>{
      'wallet': _bookings.where((b) => b['payment'] == 'wallet').length,
      'kuraimi': _bookings.where((b) => b['payment'] == 'kuraimi').length,
      'digitalWallet':
          _bookings.where((b) => b['payment'] == 'digitalWallet').length,
      'cash': _bookings.where((b) => b['payment'] == 'cash').length,
    };

    final kpis = [
      (
        bi('إجمالي الإيرادات', 'Net Revenue'),
        l.money(_totalRevenueYer),
        bi('باستثناء الملغاة', 'Excl. cancelled'),
        Icons.trending_up_rounded,
        TIColors.success,
      ),
      (
        bi('إجمالي الحجوزات', 'Total Bookings'),
        '$_bookingsCount',
        bi('$confirmedCount مؤكد • $completedCount مكتمل',
            '$confirmedCount conf • $completedCount done'),
        Icons.receipt_long_rounded,
        TIColors.orangeDeep,
      ),
      (
        bi('المستخدمون المسجلون', 'Registered Users'),
        '$_usersCount',
        bi('في قاعدة Supabase', 'In Supabase DB'),
        Icons.people_alt_rounded,
        TIColors.cardRent,
      ),
      (
        bi('سيارات متاحة', 'Available Cars'),
        '$_carsCount',
        bi('جاهزة للتأجير', 'Ready to rent'),
        Icons.directions_car_rounded,
        TIColors.cardResorts,
      ),
      (
        bi('غرف فندقية متاحة', 'Available Rooms'),
        '$_roomsCount',
        bi('متاحة للحجز', 'Open rooms'),
        Icons.hotel_rounded,
        TIColors.cardPlans,
      ),
      (
        bi('تذاكر دعم مفتوحة', 'Open Tickets'),
        '$_openTicketsCount',
        bi('بانتظار الرد', 'Needs reply'),
        Icons.support_agent_rounded,
        TIColors.danger,
      ),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // بانر ترحيبي للإدارة مع أزرار سريعة
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [TIColors.navy, Color(0xFF1E293B), TIColors.orangeDark],
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${bi('مرحباً بك،', 'Welcome,')} ${state.user?.firstName ?? bi('المشرف', 'Admin')} 👋',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          bi(
                            'تحكم كامل ومباشر في الحجوزات، الفنادق، السيارات، العملاء، والإشعارات الحية.',
                            'Live control over bookings, hotels, fleet, customers, and instant notifications.',
                          ),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.84),
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _openSendNotificationDialog(ar),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TIColors.orange,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 38),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    icon: const Icon(Icons.campaign_rounded, size: 17),
                    label: Text(
                      bi('إرسال إشعار للعملاء', 'Send Broadcast'),
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => setState(() => _tabIndex = 1),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.16),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size(0, 38),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    icon: const Icon(Icons.receipt_long_rounded, size: 17),
                    label: Text(
                      bi('مراجعة الحجوزات ($_bookingsCount)',
                          'Review Bookings ($_bookingsCount)'),
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // بطاقات المؤشرات الرئيسية KPIs
        LayoutBuilder(
          builder: (context, c) {
            final cols = c.maxWidth >= 820 ? 3 : 2;
            const spacing = 12.0;
            final cardW = (c.maxWidth - (cols - 1) * spacing) / cols;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: kpis.map((k) {
                return SizedBox(
                  width: cardW,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Theme.of(context).dividerColor.withOpacity(0.5),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: k.$5.withOpacity(0.14),
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: Icon(k.$4, color: k.$5, size: 20),
                            ),
                            Text(
                              k.$2,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          k.$1,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          k.$3,
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).hintColor,
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
        const SizedBox(height: 18),

        // تحليلات بصرية: حالات الحجز + طرق الدفع
        LayoutBuilder(
          builder: (context, c) {
            final sideBySide = c.maxWidth >= 760;
            final statusCard = _analyticsCard(
              context,
              title: bi('توزيع حالات الحجوزات', 'Booking Status Breakdown'),
              children: [
                _barRow(
                  context,
                  bi('مؤكد', 'Confirmed'),
                  confirmedCount,
                  totalB,
                  TIColors.success,
                ),
                _barRow(
                  context,
                  bi('مكتمل', 'Completed'),
                  completedCount,
                  totalB,
                  TIColors.cardRent,
                ),
                _barRow(
                  context,
                  bi('ملغي', 'Cancelled'),
                  cancelledCount,
                  totalB,
                  TIColors.danger,
                ),
              ],
            );

            final paymentCard = _analyticsCard(
              context,
              title: bi('توزيع طرق الدفع', 'Payment Methods'),
              children: [
                for (final entry in payCounts.entries)
                  _barRow(
                    context,
                    _paymentLabel(entry.key, ar),
                    entry.value,
                    totalB,
                    TIColors.orangeDeep,
                  ),
              ],
            );

            if (sideBySide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: statusCard),
                  const SizedBox(width: 12),
                  Expanded(child: paymentCard),
                ],
              );
            }
            return Column(
              children: [
                statusCard,
                const SizedBox(height: 12),
                paymentCard,
              ],
            );
          },
        ),
        const SizedBox(height: 18),

        // أحدث الحجوزات مباشرة في النظرة العامة
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              bi('أحدث الحجوزات الواردة', 'Latest Incoming Bookings'),
              style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900),
            ),
            TextButton(
              onPressed: () => setState(() => _tabIndex = 1),
              child: Text(bi('عرض الكل', 'View all')),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_bookings.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              bi('لا توجد حجوزات مسجلة بعد', 'No bookings yet'),
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
          )
        else
          ..._bookings.take(4).map((b) => _bookingDetailCard(context, b, ar)),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _analyticsCard(BuildContext context,
      {required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _barRow(
      BuildContext context, String label, int count, int total, Color color) {
    final pct = (count / total).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w700)),
              Text(
                '$count (${(pct * 100).round()}%)',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).hintColor),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: color.withOpacity(0.14),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== التبويب 2: إدارة الحجوزات الكاملة ====================
  Widget _buildBookingsTab(AppLocalizations l, bool ar) {
    final confirmedN =
        _bookings.where((b) => b['status'] == 'confirmed').length;
    final completedN =
        _bookings.where((b) => b['status'] == 'completed').length;
    final cancelledN =
        _bookings.where((b) => b['status'] == 'cancelled').length;

    final filtered = _bookings.where((b) {
      final st = (b['status'] ?? '').toString();
      if (_bookingFilter != 'all' && st != _bookingFilter) return false;
      if (_bookingQuery.trim().isNotEmpty) {
        final q = _bookingQuery.trim().toLowerCase();
        final u = _findUserForBooking(b);
        final hay = [
          b['booking_id'],
          b['title'],
          b['service'],
          b['payment'],
          u?['first_name'],
          u?['second_name'],
          u?['phone'],
          u?['email'],
        ].whereType<Object>().join(' ').toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          onChanged: (v) => setState(() => _bookingQuery = v),
          decoration: InputDecoration(
            hintText: ar
                ? 'ابحث برقم الحجز، اسم العميل، الهاتف، أو البريد...'
                : 'Search booking ID, customer, phone, email...',
            prefixIcon: const Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final f in [
                ('all', '${ar ? 'الكل' : 'All'} (${_bookings.length})'),
                ('confirmed', '${ar ? 'مؤكد' : 'Confirmed'} ($confirmedN)'),
                ('completed', '${ar ? 'مكتمل' : 'Completed'} ($completedN)'),
                ('cancelled', '${ar ? 'ملغي' : 'Cancelled'} ($cancelledN)'),
              ])
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: ChoiceChip(
                    label: Text(f.$2),
                    selected: _bookingFilter == f.$1,
                    onSelected: (_) => setState(() => _bookingFilter = f.$1),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.all(36),
            child: Center(
              child: Text(
                ar ? 'لا توجد حجوزات مطابقة للبحث' : 'No matching bookings',
                style: TextStyle(color: Theme.of(context).hintColor),
              ),
            ),
          )
        else
          ...filtered.map((b) => _bookingDetailCard(context, b, ar)),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _bookingDetailCard(
      BuildContext context, Map<String, dynamic> b, bool ar) {
    final u = _findUserForBooking(b);
    final bid = b['booking_id']?.toString() ?? '—';
    final payRow = _paymentsByBooking[bid];
    final st = b['status']?.toString() ?? 'confirmed';
    final stColor = _statusColor(st);
    final fullName = u != null
        ? '${u['first_name'] ?? ''} ${u['second_name'] ?? ''}'.trim()
        : '';
    final createdRaw = (b['created_at'] ?? '').toString();
    final createdShort = createdRaw.length >= 16
        ? createdRaw.substring(0, 16).replaceFirst('T', ' ')
        : createdRaw;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: TIColors.orangeSoft,
                  borderRadius: BorderRadius.circular(8),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: stColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(8),
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
                  fontSize: 15,
                  color: TIColors.orangeDeep,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            b['title']?.toString() ?? bid,
            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            '${_serviceLabel(b['service']?.toString(), ar)} • ${b['date_text'] ?? '—'}',
            style: TextStyle(fontSize: 12.5, color: Theme.of(context).hintColor),
          ),
          const SizedBox(height: 10),
          // بيانات العميل الكاملة
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_outline,
                        size: 16, color: TIColors.orangeDeep),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${ar ? 'العميل' : 'Customer'}: ${fullName.isEmpty ? '#${b['user_id'] ?? '—'}' : fullName}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                    ),
                    if (u?['age'] != null)
                      Text(
                        '${u!['age']} ${ar ? 'سنة' : 'yrs'}',
                        style: TextStyle(
                            fontSize: 11.5,
                            color: Theme.of(context).hintColor),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 14,
                  runSpacing: 4,
                  children: [
                    if (u?['phone'] != null &&
                        u!['phone'].toString().isNotEmpty)
                      Text('${ar ? 'الهاتف' : 'Phone'}: ${u['phone']}',
                          style: const TextStyle(fontSize: 12)),
                    if (u?['email'] != null &&
                        u!['email'].toString().isNotEmpty)
                      Text('${ar ? 'البريد' : 'Email'}: ${u['email']}',
                          style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.payment_rounded,
                      size: 15, color: TIColors.cardRent),
                  const SizedBox(width: 4),
                  Text(
                    '${ar ? 'الدفع' : 'Payment'}: ${_paymentLabel(b['payment']?.toString(), ar)}',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              if (payRow?['status'] != null)
                Text(
                  '(${payRow!['status']})',
                  style: TextStyle(
                      fontSize: 11.5, color: Theme.of(context).hintColor),
                ),
              if (createdShort.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.access_time,
                        size: 14, color: Theme.of(context).hintColor),
                    const SizedBox(width: 4),
                    Text(
                      createdShort,
                      style: TextStyle(
                          fontSize: 11.5, color: Theme.of(context).hintColor),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: st == 'confirmed'
                      ? null
                      : () => _updateBookingStatus(b, 'confirmed', ar),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    foregroundColor: TIColors.success,
                    side: const BorderSide(color: TIColors.success),
                  ),
                  child: Text(ar ? 'تأكيد' : 'Confirm',
                      style: const TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton(
                  onPressed: st == 'completed'
                      ? null
                      : () => _updateBookingStatus(b, 'completed', ar),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    foregroundColor: TIColors.cardRent,
                    side: const BorderSide(color: TIColors.cardRent),
                  ),
                  child: Text(ar ? 'إكمال' : 'Complete',
                      style: const TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton(
                  onPressed: st == 'cancelled'
                      ? null
                      : () => _updateBookingStatus(b, 'cancelled', ar),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    foregroundColor: TIColors.danger,
                    side: const BorderSide(color: TIColors.danger),
                  ),
                  child: Text(ar ? 'إلغاء' : 'Cancel',
                      style: const TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== التبويب 3: إدارة الكتالوج والخدمات ====================
  Widget _buildCatalogTab(bool ar) {
    String bi(String a, String e) => ar ? a : e;
    final tools = [
      (
        Icons.hotel_rounded,
        bi('إدارة الفنادق والغرف', 'Hotels & Rooms'),
        bi('إضافة وتعديل الفنادق والغرف والصور والأسعار',
            'Manage hotels, rooms, images & prices'),
        TIColors.cardHotels,
        () async {
          await Navigator.push(context,
              MaterialPageRoute(builder: (_) => const AdminHotelsScreen()));
          _loadStats();
        },
      ),
      (
        Icons.directions_car_rounded,
        bi('إدارة السيارات والأسطول', 'Fleet & Vehicles'),
        bi('التحكم بالسيارات، الفئات، التوفر، والصور',
            'Manage cars, categories & availability'),
        TIColors.cardRent,
        () async {
          await Navigator.push(context,
              MaterialPageRoute(builder: (_) => const AdminVehiclesScreen()));
          _loadStats();
        },
      ),
      (
        Icons.badge_rounded,
        bi('إدارة السائقين', 'Drivers'),
        bi('إضافة وتحديث بيانات وتقييمات السائقين',
            'Add & update driver profiles and ratings'),
        TIColors.cardPlaces,
        () async {
          await Navigator.push(context,
              MaterialPageRoute(builder: (_) => const AdminDriversScreen()));
          _loadStats();
        },
      ),
      (
        Icons.local_offer_rounded,
        bi('العروض والتخفيضات', 'Offers & Promos'),
        bi('إنشاء عروض حية مع إشعار فوري لجميع العملاء',
            'Create live promos with auto-notifications'),
        TIColors.orangeDeep,
        () async {
          await Navigator.push(context,
              MaterialPageRoute(builder: (_) => const AdminOffersScreen()));
          _loadStats();
        },
      ),
      (
        Icons.currency_exchange_rounded,
        bi('أسعار الصرف والتسعير', 'Exchange Rates'),
        bi('تحديث أسعار التحويل بين YER و USD و SAR',
            'Update currency exchange rates'),
        TIColors.cardResorts,
        () async {
          await Navigator.push(context,
              MaterialPageRoute(builder: (_) => const AdminPricingScreen()));
          _loadStats();
        },
      ),
      (
        Icons.history_rounded,
        bi('سجل التدقيق والرقابة', 'Audit Logs'),
        bi('متابعة جميع عمليات الإضافة والتعديل والحذف',
            'Track all admin changes and timestamps'),
        TIColors.cardPlans,
        () async {
          await Navigator.push(context,
              MaterialPageRoute(builder: (_) => const AdminAuditLogsScreen()));
        },
      ),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // بطاقة مركز الإشعارات اليدوية
        InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _openSendNotificationDialog(ar),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: TravixoFX.orange,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(Icons.campaign_rounded,
                      color: Colors.white, size: 25),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bi('مركز الإشعارات اليدوية للعملاء',
                            'Manual Customer Broadcast Center'),
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 15),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        bi('أرسل عرضاً جديداً أو تنبيهاً فورياً لجميع العملاء أو لعميل محدد',
                            'Send offers or alerts instantly to all or specific customers'),
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.88),
                            fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios,
                    color: Colors.white, size: 16),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, c) {
            final cols = c.maxWidth >= 780 ? 3 : (c.maxWidth >= 500 ? 2 : 1);
            const spacing = 12.0;
            final cardW = (c.maxWidth - (cols - 1) * spacing) / cols;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: tools.map((t) {
                return SizedBox(
                  width: cardW,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: t.$5,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color:
                              Theme.of(context).dividerColor.withOpacity(0.5),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: t.$4.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(t.$1, color: t.$4, size: 23),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            t.$2,
                            style: const TextStyle(
                                fontWeight: FontWeight.w900, fontSize: 14.5),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            t.$3,
                            style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).hintColor),
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
        const SizedBox(height: 24),
      ],
    );
  }

  // ==================== التبويب 4: العملاء والمحافظ ====================
  Widget _buildCustomersTab(AppLocalizations l, bool ar) {
    final filtered = _users.where((u) {
      final role = (u['role'] ?? 'customer').toString();
      if (_userFilter == 'customer' && role == 'developer') return false;
      if (_userFilter == 'developer' && role != 'developer') return false;
      if (_userQuery.trim().isNotEmpty) {
        final q = _userQuery.trim().toLowerCase();
        final hay = [
          u['user_id'],
          u['first_name'],
          u['second_name'],
          u['phone'],
          u['email'],
        ].whereType<Object>().join(' ').toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _openAddDeveloperDialog(ar),
                icon: const Icon(Icons.admin_panel_settings_rounded, size: 18),
                label: Text(ar ? 'إضافة مطور / مشرف جديد' : 'Add New Developer'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          onChanged: (v) => setState(() => _userQuery = v),
          decoration: InputDecoration(
            hintText: ar
                ? 'ابحث بالاسم، البريد، الهاتف، أو رقم المستخدم...'
                : 'Search name, email, phone, or ID...',
            prefixIcon: const Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final f in [
              ('all', ar ? 'الكل' : 'All'),
              ('customer', ar ? 'العملاء' : 'Customers'),
              ('developer', ar ? 'المطورون' : 'Admins'),
            ])
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: ChoiceChip(
                  label: Text(f.$2),
                  selected: _userFilter == f.$1,
                  onSelected: (_) => setState(() => _userFilter = f.$1),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.all(36),
            child: Center(
              child: Text(
                ar ? 'لا يوجد مستخدمون مطابقون' : 'No matching users',
                style: TextStyle(color: Theme.of(context).hintColor),
              ),
            ),
          )
        else
          ...filtered.map((u) {
            final uidStr = u['user_id']?.toString() ?? '';
            final uidInt = int.tryParse(uidStr);
            final name =
                '${u['first_name'] ?? ''} ${u['second_name'] ?? ''}'.trim();
            final isDev = (u['role'] ?? 'customer') == 'developer';
            final balance = _walletBalanceByUser[uidStr] ?? 0;
            final bCount = _bookingCountForUser(uidStr);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Theme.of(context).dividerColor.withOpacity(0.5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: isDev
                            ? TIColors.gold.withOpacity(0.2)
                            : TIColors.orangeSoft,
                        child: Icon(
                          isDev ? Icons.admin_panel_settings : Icons.person,
                          color: isDev ? TIColors.gold : TIColors.orangeDeep,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name.isEmpty ? '#$uidStr' : name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900, fontSize: 14.5),
                            ),
                            Text(
                              '${u['email'] ?? u['phone'] ?? '—'} • #$uidStr',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).hintColor),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (isDev ? TIColors.gold : TIColors.cardRent)
                              .withOpacity(0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isDev
                              ? (ar ? 'مطور' : 'Admin')
                              : (ar ? 'عميل' : 'Customer'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: isDev ? TIColors.gold : TIColors.cardRent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 14,
                    runSpacing: 4,
                    children: [
                      Text(
                        '${ar ? 'الرصيد' : 'Wallet'}: ${l.money(balance)}',
                        style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: TIColors.orangeDeep),
                      ),
                      Text(
                        '${ar ? 'الحجوزات' : 'Bookings'}: $bCount',
                        style: const TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                      if (u['age'] != null)
                        Text(
                          '${ar ? 'العمر' : 'Age'}: ${u['age']}',
                          style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).hintColor),
                        ),
                    ],
                  ),
                  if (uidInt != null) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (!isDev)
                          OutlinedButton.icon(
                            onPressed: () => _openAdjustWalletDialog(u, ar),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 34),
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                            ),
                            icon: const Icon(
                                Icons.account_balance_wallet_outlined,
                                size: 15),
                            label: Text(
                              ar ? 'شحن الرصيد' : 'Wallet',
                              style: const TextStyle(fontSize: 11.5),
                            ),
                          ),
                        if (!isDev)
                          OutlinedButton.icon(
                            onPressed: () => _openSendNotificationDialog(
                              ar,
                              preselectedUserId: uidInt,
                            ),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 34),
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                            ),
                            icon: const Icon(Icons.notifications_active_outlined,
                                size: 15),
                            label: Text(
                              ar ? 'إشعار خاص' : 'Notify',
                              style: const TextStyle(fontSize: 11.5),
                            ),
                          ),
                        if (isDev)
                          OutlinedButton.icon(
                            onPressed: () => _openChangeDevPasswordDialog(u, ar),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 34),
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              foregroundColor: TIColors.cardRent,
                              side: const BorderSide(color: TIColors.cardRent),
                            ),
                            icon: const Icon(Icons.lock_reset_rounded, size: 15),
                            label: Text(
                              ar ? 'تغيير كلمة المرور' : 'Change Password',
                              style: const TextStyle(fontSize: 11.5),
                            ),
                          ),
                        OutlinedButton.icon(
                          onPressed: () => _toggleUserRole(u, ar),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 34),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            foregroundColor:
                                isDev ? TIColors.danger : TIColors.gold,
                            side: BorderSide(
                              color: isDev ? TIColors.danger : TIColors.gold,
                            ),
                          ),
                          icon: Icon(
                            isDev
                                ? Icons.person_remove_outlined
                                : Icons.admin_panel_settings_outlined,
                            size: 15,
                          ),
                          label: Text(
                            isDev
                                ? (ar ? 'إلغاء صلاحية المطور' : 'Remove Admin')
                                : (ar ? 'ترقية لمطور' : 'Make Developer'),
                            style: const TextStyle(fontSize: 11.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          }),
        const SizedBox(height: 24),
      ],
    );
  }

  // ==================== التبويب 5: الدعم الفني ====================
  Widget _buildSupportTab(bool ar) {
    final filtered = _tickets.where((t) {
      final st = (t['status'] ?? 'open').toString();
      if (_ticketFilter == 'open' && st != 'open') return false;
      if (_ticketFilter == 'closed' && st == 'open') return false;
      return true;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            for (final f in [
              ('all', '${ar ? 'الكل' : 'All'} (${_tickets.length})'),
              ('open', '${ar ? 'مفتوحة' : 'Open'} ($_openTicketsCount)'),
              ('closed', ar ? 'مغلقة' : 'Closed'),
            ])
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: ChoiceChip(
                  label: Text(f.$2),
                  selected: _ticketFilter == f.$1,
                  onSelected: (_) => setState(() => _ticketFilter = f.$1),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.all(36),
            child: Center(
              child: Text(
                ar ? 'لا توجد تذاكر دعم مطابقة' : 'No support tickets',
                style: TextStyle(color: Theme.of(context).hintColor),
              ),
            ),
          )
        else
          ...filtered.map((t) {
            final isOpen = (t['status'] ?? 'open') == 'open';
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).dividerColor.withOpacity(0.5),
                ),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      (isOpen ? TIColors.success : TIColors.lightSub)
                          .withOpacity(0.15),
                  child: Icon(
                    Icons.support_agent_rounded,
                    color: isOpen ? TIColors.success : TIColors.lightSub,
                  ),
                ),
                title: Text(
                  t['subject']?.toString() ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  '${t['user_name'] ?? '—'} • ${isOpen ? (ar ? 'مفتوحة' : 'Open') : (ar ? 'مغلقة' : 'Closed')}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () => _toggleTicketStatus(t, ar),
                      child: Text(
                        isOpen
                            ? (ar ? 'إغلاق' : 'Close')
                            : (ar ? 'إعادة فتح' : 'Reopen'),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => SupportChatScreen(ticket: t)),
                ),
              ),
            );
          }),
        const SizedBox(height: 24),
      ],
    );
  }
}
