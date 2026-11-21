import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models.dart';
import '../data/demo_data.dart';
import '../data/real_hotels_data.dart';
import '../l10n/app_localizations.dart';
import '../supabase.dart';

class AppState extends ChangeNotifier {
  final SharedPreferences prefs;
  late AppLocalizations l10n;
  static AppState? instance;
  AppState(this.prefs) {
    instance = this;
  }

  // ===== إعدادات عامة =====
  Locale _locale = const Locale('ar');
  ThemeMode _themeMode = ThemeMode.system;
  String _currency = 'YER';

  // ===== المستخدم =====
  AppUser? user;

  // ===== التهيئة الأولى =====
  bool get hasSeenOnboarding => prefs.getBool('hasSeenOnboarding') ?? false;
  void markOnboardingSeen() {
    prefs.setBool('hasSeenOnboarding', true);
    notifyListeners();
  }

  // ===== البيانات =====
  List<Booking> bookings = [];
  List<WalletTx> txs = [];
  double walletBalanceYer = 100000; // رصيد تجريبي ترحيبي (Demo)
  Set<String> favoriteIds = {};
  List<String> notifications = [];
  List<Hotel> liveHotels = [];
  List<Car> liveCars = [];
  List<Offer> liveOffers = [];

  Locale get locale => _locale;
  ThemeMode get themeMode => _themeMode;
  String get currency => _currency;
  bool get isRTL => _locale.languageCode == 'ar';
  bool get isDark => _themeMode == ThemeMode.dark;
  Membership get membership => user?.membership ?? Membership.basic;

  int? get _dbUserId => user == null ? null : int.tryParse(user!.id);

  // ============ التحميل والحفظ ============
  void load() {
    final l = prefs.getString('locale');
    if (l == 'en') _locale = const Locale('en');
    final t = prefs.getString('theme');
    if (t == 'light') _themeMode = ThemeMode.light;
    if (t == 'dark') _themeMode = ThemeMode.dark;
    _currency = prefs.getString('currency') ?? 'YER';
    final u = prefs.getString('user');
    if (u != null) {
      try { user = AppUser.fromJson(jsonDecode(u)); } catch (_) {}
    }
    final b = prefs.getString('bookings');
    if (b != null) {
      try { bookings = (jsonDecode(b) as List).map((e) => Booking.fromJson(e)).toList(); } catch (_) {}
    }
    final tx = prefs.getString('txs');
    if (tx != null) {
      try { txs = (jsonDecode(tx) as List).map((e) => WalletTx.fromJson(e)).toList(); } catch (_) {}
    }
    walletBalanceYer = prefs.getDouble('wallet') ?? 100000;
    favoriteIds = (prefs.getStringList('favorites') ?? []).toSet();
    notifications = prefs.getStringList('notifications') ?? [];
    notifyListeners();
    syncFromSupabase();
    fetchLiveCatalog();
  }

  Future<void> syncFromSupabase() async {
    final uid = _dbUserId;
    if (uid == null) return;
    try {
      final walletRow = await supabase
          .from('wallets')
          .select()
          .eq('user_id', uid)
          .maybeSingle();
      if (walletRow != null) {
        walletBalanceYer =
            (walletRow['balance'] as num?)?.toDouble() ?? walletBalanceYer;
        await prefs.setDouble('wallet', walletBalanceYer);

        final wid = walletRow['wallet_id'];
        final txRows = await supabase
            .from('wallet_transactions')
            .select()
            .eq('wallet_id', wid)
            .order('created_at', ascending: false);
        txs = (txRows as List).map((r) {
          final statusStr = r['status']?.toString() ?? 'completed';
          return WalletTx(
            id: 'TX-${r['tx_id']}',
            reason: r['reason']?.toString() ?? '',
            amountYer: (r['amount'] as num?)?.toDouble() ?? 0,
            status: TxStatus.values.firstWhere(
              (s) => s.name == statusStr,
              orElse: () => TxStatus.completed,
            ),
            createdAt: r['created_at']?.toString().substring(0, 16) ?? _now(),
          );
        }).toList();
        _saveTxs();
      }

      final bRows = await supabase
          .from('bookings')
          .select()
          .eq('user_id', uid)
          .order('created_at', ascending: false);
      if ((bRows as List).isNotEmpty) {
        bookings = bRows.map((r) {
          final svc = r['service']?.toString() ?? 'hotel';
          final pay = r['payment']?.toString() ?? 'cash';
          final st = r['status']?.toString() ?? 'confirmed';
          return Booking(
            id: r['booking_id'].toString(),
            service: ServiceType.values.firstWhere(
              (s) => s.name == svc,
              orElse: () => ServiceType.hotel,
            ),
            title: r['title']?.toString() ?? '',
            provinceId: 'sanaa',
            cityId: 'sanaa',
            dateText: r['date_text']?.toString() ?? '',
            totalYer: (r['total_yer'] as num?)?.toDouble() ?? 0,
            payment: PaymentMethod.values.firstWhere(
              (p) => p.name == pay,
              orElse: () => PaymentMethod.cash,
            ),
            status: BookingStatus.values.firstWhere(
              (s) => s.name == st,
              orElse: () => BookingStatus.confirmed,
            ),
            createdAt: r['created_at']?.toString().substring(0, 16) ?? _now(),
          );
        }).toList();
        await prefs.setString(
            'bookings', jsonEncode(bookings.map((e) => e.toJson()).toList()));
      }
      notifyListeners();
    } catch (_) {}
  }


  Future<void> fetchLiveCatalog() async {
    try {
      final provRows = await supabase.from('provinces').select();
      final Map<int, String> provById = {};
      for (final p in (provRows as List)) {
        final pid = p['province_id'] as int?;
        final en = p['name_en']?.toString().toLowerCase() ?? 'sanaa';
        if (pid != null) provById[pid] = en;
      }

      final hotelRows =
          await supabase.from('hotels').select().order('hotel_id');
      final roomRows =
          await supabase.from('hotel_rooms').select().order('room_id');
      final drvRows = await supabase.from('drivers').select();
      final Map<int, Map<String, dynamic>> drvById = {};
      for (final d in (drvRows as List)) {
        final did = d['driver_id'] as int?;
        if (did != null) drvById[did] = Map<String, dynamic>.from(d);
      }

      if ((hotelRows as List).isNotEmpty) {
        liveHotels = hotelRows.map((h) {
          final hid = h['hotel_id'] as int;
          final rooms = (roomRows as List)
              .where((r) => r['hotel_id'] == hid)
              .map((r) => HotelRoom(
                    id: 'r_${r['room_id']}',
                    name: r['name']?.toString() ?? 'Room',
                    typeId: 'standard',
                    bedType: r['bed_type']?.toString() ?? 'King',
                    pricePerNightYer:
                        (r['price_night'] as num?)?.toDouble() ?? 30000,
                    capacity: (r['capacity'] as num?)?.toInt() ?? 2,
                    amenities: const ['Wi-Fi', 'AC'],
                    available: r['available'] != false,
                  ))
              .toList();
          final pid = provById[h['province_id']] ?? 'sanaa';
          return Hotel(
            id: '$hid',
            name: h['name_ar']?.toString() ?? '',
            provinceId: pid,
            cityId: pid,
            rating: (h['rating'] as num?)?.toDouble() ?? 4.5,
            reviewsCount: 25,
            description: h['name_ar']?.toString() ?? '',
            amenities: const ['Wi-Fi', 'Parking'],
            rooms: rooms,
            verified: h['verified'] == true,
            lat: (h['lat'] as num?)?.toDouble() ?? 15.36,
            lng: (h['lng'] as num?)?.toDouble() ?? 44.19,
            imageUrl: h['image_url']?.toString(),
          );
        }).toList();
      }

      final carRows =
          await supabase.from('vehicles').select().order('vehicle_id');
      if ((carRows as List).isNotEmpty) {
        liveCars = carRows.map((v) {
          final st = v['status']?.toString() ?? 'available';
          final drv = drvById[v['driver_id']];
          return Car(
            id: '${v['vehicle_id']}',
            name: v['name']?.toString() ?? '',
            categoryId: 'sedan',
            year: (v['year'] as num?)?.toInt() ?? 2024,
            seats: (v['seats'] as num?)?.toInt() ?? 4,
            pricePerDayYer: (v['full_price'] as num?)?.toDouble() ?? 25000,
            withDriver: v['with_driver'] != false,
            status: Availability.values.firstWhere(
              (a) => a.name == st,
              orElse: () => Availability.available,
            ),
            driverName: drv?['full_name']?.toString(),
            driverRating: (drv?['rating'] as num?)?.toDouble() ?? 4.8,
            imageUrl: v['image_url']?.toString(),
          );
        }).toList();
      }

      final offerRows = await supabase
          .from('offers')
          .select()
          .eq('active', true)
          .order('offer_id');
      if ((offerRows as List).isNotEmpty) {
        liveOffers = offerRows
            .map((o) => Offer(
                  id: '${o['offer_id']}',
                  title: o['title']?.toString() ?? '',
                  subtitle: o['subtitle']?.toString() ?? '',
                  service: ServiceType.hotel,
                  targetId: liveHotels.isNotEmpty ? liveHotels.first.id : 'h1',
                  discountPercent: (o['discount'] as num?)?.toInt() ?? 10,
                  imageUrl: o['image_url']?.toString(),
                ))
            .toList();
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<String> seedLocalCatalogToSupabase() async {
    int addedHotels = 0, addedCars = 0, addedOffers = 0;
    final provRows = await supabase.from('provinces').select();
    final Map<String, int> provIdByKey = {};
    for (final p in (provRows as List)) {
      final en = p['name_en']?.toString().toLowerCase();
      if (en != null && p['province_id'] is int) {
        provIdByKey[en] = p['province_id'] as int;
      }
    }

    final existingHotels = await supabase.from('hotels').select('name_ar');
    final existingHotelNames =
        (existingHotels as List).map((e) => e['name_ar'].toString()).toSet();

    for (final h in [...kRealHotels, ...kHotels]) {
      if (existingHotelNames.contains(h.name)) continue;
      final inserted = await supabase
          .from('hotels')
          .insert({
            'name_ar': h.name,
            'province_id': provIdByKey[h.provinceId],
            'rating': h.rating,
            'verified': h.verified,
            'lat': h.lat,
            'lng': h.lng,
            'image_url': h.img(),
          })
          .select()
          .single();
      final hid = inserted['hotel_id'];
      for (final r in h.rooms) {
        await supabase.from('hotel_rooms').insert({
          'hotel_id': hid,
          'name': r.name,
          'bed_type': r.bedType,
          'price_night': r.pricePerNightYer,
          'capacity': r.capacity,
          'available': r.available,
        });
      }
      addedHotels++;
    }

    final existingCars = await supabase.from('vehicles').select('name');
    final existingCarNames =
        (existingCars as List).map((e) => e['name'].toString()).toSet();

    for (final c in kCars) {
      if (existingCarNames.contains(c.name)) continue;
      await supabase.from('vehicles').insert({
        'name': c.name,
        'year': c.year,
        'seats': c.seats,
        'full_price': c.pricePerDayYer,
        'seat_price': (c.pricePerDayYer / c.seats).roundToDouble(),
        'with_driver': c.withDriver,
        'status': c.status.name,
        'image_url': c.img(),
      });
      addedCars++;
    }

    final existingOffers = await supabase.from('offers').select('title');
    final existingOfferTitles =
        (existingOffers as List).map((e) => e['title'].toString()).toSet();

    for (final o in kOffers) {
      if (existingOfferTitles.contains(o.title)) continue;
      await supabase.from('offers').insert({
        'title': o.title,
        'subtitle': o.subtitle,
        'discount': o.discountPercent,
        'active': true,
      });
      addedOffers++;
    }

    await fetchLiveCatalog();
    return 'تمت المزامنة: $addedHotels فنادق، $addedCars سيارات، $addedOffers عروض';
  }

  // ============ اللغة والثيم والعملة ============
  void setLocale(Locale loc) {
    _locale = loc;
    prefs.setString('locale', loc.languageCode);
    notifyListeners();
  }

  void toggleLanguage() => setLocale(
      _locale.languageCode == 'ar' ? const Locale('en') : const Locale('ar'));

  void setThemeMode(ThemeMode m) {
    _themeMode = m;
    prefs.setString('theme', m.name);
    notifyListeners();
  }

  void toggleTheme() => setThemeMode(
      _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);

  void setCurrency(String c) {
    _currency = c;
    prefs.setString('currency', c);
    notifyListeners();
  }

  // ============ المصادقة ============
  void login(AppUser u) {
    user = u;
    prefs.setString('user', jsonEncode(u.toJson()));
    notifyListeners();
    syncFromSupabase();
    fetchLiveCatalog();
  }

  // تعديل الملف الشخصي — يدعم الاسم والإيميل والرقم والصورة
  void updateProfile({
    String? firstName,
    String? secondName,
    int? age,
    String? phone,
    String? email,
    String? photoUrl,
  }) {
    if (user == null) return;
    user = AppUser(
      id: user!.id,
      firstName: firstName ?? user!.firstName,
      secondName: secondName ?? user!.secondName,
      age: age ?? user!.age,
      phone: phone ?? user!.phone,
      email: email ?? user!.email,
      photoUrl: photoUrl ?? user!.photoUrl,
      role: user!.role,
      membership: user!.membership,
      demo: user!.demo,
    );
    prefs.setString('user', jsonEncode(user!.toJson()));
    notifyListeners();

    final uid = _dbUserId;
    if (uid != null) {
      supabase.from('users').update({
        'first_name': user!.firstName,
        'second_name': user!.secondName,
        if (user!.phone != null) 'phone': user!.phone,
        if (user!.email != null) 'email': user!.email,
      }).eq('user_id', uid).then((_) {}).catchError((_) {});
    }
  }

  void logout() {
    user = null;
    prefs.remove('user');
    notifyListeners();
  }

  // ============ المفضلة ============
  bool isFavorite(String id) => favoriteIds.contains(id);

  void toggleFavorite(String id) {
    if (favoriteIds.contains(id)) {
      favoriteIds.remove(id);
    } else {
      favoriteIds.add(id);
    }
    prefs.setStringList('favorites', favoriteIds.toList());
    notifyListeners();
  }

  // ============ المحفظة ============
  void addMoney(double yer) {
    if (yer <= 0) return;
    walletBalanceYer += yer;
    prefs.setDouble('wallet', walletBalanceYer);
    txs.insert(0, WalletTx(
      id: _txId(), reason: 'Wallet top-up', amountYer: yer,
      status: TxStatus.completed, createdAt: _now(),
    ));
    _saveTxs();
    notifyListeners();
    _syncWalletToDb(yer, 'Wallet top-up', 'completed');
  }

  void _chargeWallet(double yer, String reason) {
    walletBalanceYer -= yer;
    prefs.setDouble('wallet', walletBalanceYer);
    txs.insert(0, WalletTx(
      id: _txId(), reason: reason, amountYer: -yer,
      status: TxStatus.completed, createdAt: _now(),
    ));
    _saveTxs();
    _syncWalletToDb(-yer, reason, 'completed');
  }

  Future<void> _syncWalletToDb(
      double delta, String reason, String status) async {
    final uid = _dbUserId;
    if (uid == null) return;
    try {
      var walletRow = await supabase
          .from('wallets')
          .select()
          .eq('user_id', uid)
          .maybeSingle();
      walletRow ??= await supabase
          .from('wallets')
          .insert({
            'user_id': uid,
            'balance': walletBalanceYer,
            'currency': _currency,
          })
          .select()
          .single();
      final wid = walletRow['wallet_id'];
      await supabase
          .from('wallets')
          .update({'balance': walletBalanceYer}).eq('wallet_id', wid);
      await supabase.from('wallet_transactions').insert({
        'wallet_id': wid,
        'amount': delta,
        'reason': reason,
        'status': status,
      });
    } catch (_) {}
  }

  void _saveTxs() {
    prefs.setString('txs', jsonEncode(txs.map((e) => e.toJson()).toList()));
  }

  // ============ الحجوزات ============
  /// يحاول الدفع من المحفظة؛ يرجع null إذا الرصيد غير كافٍ أو القيمة غير صالحة
  Booking? createBooking({
    required ServiceType service,
    required String title,
    required String provinceId,
    required String cityId,
    required String dateText,
    required double totalYer,
    required PaymentMethod payment,
    Map<String, dynamic> details = const {},
  }) {
    if (totalYer < 0) return null;
    if (payment == PaymentMethod.wallet) {
      if (walletBalanceYer < totalYer) return null;
      _chargeWallet(totalYer, 'Booking: $title');
    } else {
      txs.insert(0, WalletTx(
        id: _txId(), reason: 'Booking: $title', amountYer: totalYer,
        status: TxStatus.pending, createdAt: _now(),
      ));
      _saveTxs();
    }
    final b = Booking(
      id: 'TI-${10000 + Random().nextInt(90000)}',
      service: service, title: title,
      provinceId: provinceId, cityId: cityId,
      dateText: dateText, totalYer: totalYer, payment: payment,
      status: BookingStatus.confirmed, createdAt: _now(),
      details: details,
    );
    bookings.insert(0, b);
    prefs.setString('bookings', jsonEncode(bookings.map((e) => e.toJson()).toList()));
    notifications.insert(0, '✅ $title (${b.id})');
    prefs.setStringList('notifications', notifications);
    notifyListeners();
    _insertBookingToDb(b);
    return b;
  }

  Future<void> _insertBookingToDb(Booking b) async {
    final uid = _dbUserId;
    if (uid == null) return;
    try {
      await supabase.from('bookings').insert({
        'booking_id': b.id,
        'user_id': uid,
        'service': b.service.name,
        'title': b.title,
        'date_text': b.dateText,
        'total_yer': b.totalYer,
        'payment': b.payment.name,
        'status': b.status.name,
      });
      await supabase.from('payments').insert({
        'booking_id': b.id,
        'method': b.payment.name,
        'amount': b.totalYer,
        'status': b.payment == PaymentMethod.wallet ? 'completed' : 'pending',
        if (b.details['ref'] != null) 'ref_number': b.details['ref'].toString(),
      });
    } catch (_) {}
  }

  void cancelBooking(String id) {
    final i = bookings.indexWhere((b) => b.id == id);
    if (i == -1) return;
    final b = bookings[i];
    if (b.status == BookingStatus.cancelled) return;
    // استرداد إذا كان الدفع بالمحفظة (سياسة مبسطة للعرض)
    if (b.payment == PaymentMethod.wallet) {
      walletBalanceYer += b.totalYer;
      prefs.setDouble('wallet', walletBalanceYer);
      txs.insert(0, WalletTx(
        id: _txId(), reason: 'Refund: ${b.title}', amountYer: b.totalYer,
        status: TxStatus.refunded, createdAt: _now(),
      ));
      _saveTxs();
      _syncWalletToDb(b.totalYer, 'Refund: ${b.title}', 'refunded');
    }
    bookings[i] = Booking(
      id: b.id, service: b.service, title: b.title,
      provinceId: b.provinceId, cityId: b.cityId, dateText: b.dateText,
      totalYer: b.totalYer, payment: b.payment,
      status: BookingStatus.cancelled, createdAt: b.createdAt,
      details: b.details,
    );
    prefs.setString('bookings', jsonEncode(bookings.map((e) => e.toJson()).toList()));
    notifyListeners();

    if (_dbUserId != null) {
      supabase
          .from('bookings')
          .update({'status': 'cancelled'})
          .eq('booking_id', b.id)
          .then((_) {})
          .catchError((_) {});
    }
  }

  // ============ أدوات مساعدة ============
  String _txId() => 'TX-${Random().nextInt(900000) + 100000}';
  String _now() {
    final d = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }
}
