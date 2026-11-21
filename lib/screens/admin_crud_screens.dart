import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../state/app_state.dart';
import '../supabase.dart';
import '../theme/app_theme.dart';

/// تسجيل أي تعديل إداري في جدول audit_logs
Future<void> logAdminAction(String action, {String? oldVal, String? newVal}) async {
  try {
    await supabase.from('audit_logs').insert({
      'action': action,
      if (oldVal != null) 'old_value': oldVal,
      if (newVal != null) 'new_value': newVal,
    });
  } catch (_) {}
}

/// رفع صورة من الجهاز إلى Supabase Storage وإرجاع رابطها العام
Future<String?> pickAndUploadAdminImage(
    BuildContext context, String prefix) async {
  try {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 1024,
    );
    if (picked == null) return null;
    final bytes = await picked.readAsBytes();
    final path = '${prefix}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await supabase.storage.from('avatars').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
    return supabase.storage.from('avatars').getPublicUrl(path);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل رفع الصورة: $e')),
      );
    }
    return null;
  }
}

/// ============ 1. إدارة السيارات (كل الحقول + السائق + الفئة + الشركة + الصور) ============
class AdminVehiclesScreen extends StatefulWidget {
  const AdminVehiclesScreen({super.key});

  @override
  State<AdminVehiclesScreen> createState() => _AdminVehiclesScreenState();
}

class _AdminVehiclesScreenState extends State<AdminVehiclesScreen> {
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _drivers = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _companies = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await supabase
          .from('vehicles')
          .select()
          .order('vehicle_id', ascending: false);
      final drv = await supabase.from('drivers').select().order('driver_id');
      final cat =
          await supabase.from('car_categories').select().order('category_id');
      final cmp = await supabase
          .from('transport_companies')
          .select()
          .order('company_id');
      if (!mounted) return;
      setState(() {
        _items = List<Map<String, dynamic>>.from(res);
        _drivers = List<Map<String, dynamic>>.from(drv);
        _categories = List<Map<String, dynamic>>.from(cat);
        _companies = List<Map<String, dynamic>>.from(cmp);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطأ التحميل: $e')));
    }
  }

  Future<void> _delete(int id, String name) async {
    try {
      await supabase.from('vehicles').delete().eq('vehicle_id', id);
      await AppState.instance?.fetchLiveCatalog();
      await logAdminAction('Delete vehicle #$id', oldVal: name);
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('فشل الحذف: $e')));
    }
  }

  Future<void> _openForm([Map<String, dynamic>? item]) async {
    final name = TextEditingController(text: item?['name']?.toString() ?? '');
    final year =
        TextEditingController(text: (item?['year'] ?? 2024).toString());
    final seats =
        TextEditingController(text: (item?['seats'] ?? 4).toString());
    final fullPrice = TextEditingController(
        text: (item?['full_price'] ?? 25000).toString());
    final seatPrice =
        TextEditingController(text: (item?['seat_price'] ?? 6000).toString());
    final imgCtrl =
        TextEditingController(text: item?['image_url']?.toString() ?? '');
    bool withDriver = item?['with_driver'] ?? true;
    String status = item?['status']?.toString() ?? 'available';
    int? driverId = item?['driver_id'] as int?;
    int? categoryId = item?['category_id'] as int?;
    int? companyId = item?['company_id'] as int?;
    bool uploading = false;

    try {
      final saved = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setS) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              left: 16,
              right: 16,
              top: 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(item == null ? 'إضافة سيارة جديدة' : 'تعديل سيارة',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(
                        labelText: 'اسم السيارة والموديل',
                        border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: year,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'سنة الصنع',
                            border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: seats,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'عدد المقاعد',
                            border: OutlineInputBorder()),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: fullPrice,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'السعر الكامل (YER)',
                            border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: seatPrice,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'سعر المقعد (YER)',
                            border: OutlineInputBorder()),
                      ),
                    ),
                  ]),
                  if (_categories.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int?>(
                      value: categoryId,
                      decoration: const InputDecoration(
                          labelText: 'فئة السيارة',
                          border: OutlineInputBorder()),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('بدون فئة')),
                        ..._categories.map((c) => DropdownMenuItem(
                              value: c['category_id'] as int,
                              child: Text(c['name_ar']?.toString() ??
                                  c['name_en']?.toString() ??
                                  ''),
                            )),
                      ],
                      onChanged: (v) => setS(() => categoryId = v),
                    ),
                  ],
                  if (_companies.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int?>(
                      value: companyId,
                      decoration: const InputDecoration(
                          labelText: 'شركة النقل',
                          border: OutlineInputBorder()),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('بدون شركة')),
                        ..._companies.map((c) => DropdownMenuItem(
                              value: c['company_id'] as int,
                              child: Text(c['name_ar']?.toString() ??
                                  c['name_en']?.toString() ??
                                  ''),
                            )),
                      ],
                      onChanged: (v) => setS(() => companyId = v),
                    ),
                  ],
                  if (_drivers.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int?>(
                      value: driverId,
                      decoration: const InputDecoration(
                          labelText: 'السائق المعيّن',
                          border: OutlineInputBorder()),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('بدون سائق محدد')),
                        ..._drivers.map((d) => DropdownMenuItem(
                              value: d['driver_id'] as int,
                              child: Text(d['full_name']?.toString() ?? ''),
                            )),
                      ],
                      onChanged: (v) => setS(() => driverId = v),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: imgCtrl,
                        decoration: const InputDecoration(
                            labelText: 'رابط الصورة',
                            border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: uploading
                          ? null
                          : () async {
                              setS(() => uploading = true);
                              final url =
                                  await pickAndUploadAdminImage(ctx, 'car');
                              if (url != null) imgCtrl.text = url;
                              setS(() => uploading = false);
                            },
                      icon: uploading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.photo_library),
                      label: const Text('رفع'),
                    ),
                  ]),
                  SwitchListTile(
                    title: const Text('مع سائق'),
                    value: withDriver,
                    onChanged: (v) => setS(() => withDriver = v),
                  ),
                  DropdownButtonFormField<String>(
                    value: status,
                    decoration: const InputDecoration(
                        labelText: 'الحالة', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'available', child: Text('متاحة')),
                      DropdownMenuItem(value: 'limited', child: Text('محدودة')),
                      DropdownMenuItem(
                          value: 'unavailable', child: Text('غير متاحة')),
                    ],
                    onChanged: (v) => setS(() => status = v ?? 'available'),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        if (name.text.trim().isEmpty) return;
                        final data = {
                          'name': name.text.trim(),
                          'year': int.tryParse(year.text.trim()) ?? 2024,
                          'seats': int.tryParse(seats.text.trim()) ?? 4,
                          'full_price':
                              double.tryParse(fullPrice.text.trim()) ?? 0,
                          'seat_price':
                              double.tryParse(seatPrice.text.trim()) ?? 0,
                          'with_driver': withDriver,
                          'status': status,
                          'driver_id': driverId,
                          'category_id': categoryId,
                          'company_id': companyId,
                          'image_url': imgCtrl.text.trim().isEmpty
                              ? null
                              : imgCtrl.text.trim(),
                        };
                        try {
                          if (item == null) {
                            await supabase.from('vehicles').insert(data);
                            await AppState.instance?.fetchLiveCatalog();
      await logAdminAction('Add vehicle',
                                newVal: name.text.trim());
                          } else {
                            await supabase
                                .from('vehicles')
                                .update(data)
                                .eq('vehicle_id', item['vehicle_id']);
                            await AppState.instance?.fetchLiveCatalog();
      await logAdminAction(
                                'Update vehicle #${item['vehicle_id']}',
                                newVal: name.text.trim());
                          }
                          if (ctx.mounted) Navigator.pop(ctx, true);
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(content: Text('فشل الحفظ: $e')));
                          }
                        }
                      },
                      child: const Text('حفظ'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      if (saved == true) _load();
    } finally {
      name.dispose();
      year.dispose();
      seats.dispose();
      fullPrice.dispose();
      seatPrice.dispose();
      imgCtrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة السيارات')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('إضافة سيارة'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text('لا توجد سيارات في قاعدة البيانات بعد'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (_, i) {
                      final v = _items[i];
                      final img = v['image_url']?.toString();
                      return ListTile(
                        leading: img != null && img.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(img,
                                    width: 48, height: 48, fit: BoxFit.cover),
                              )
                            : const Icon(Icons.directions_car,
                                color: TIColors.teal),
                        title: Text(v['name']?.toString() ?? ''),
                        subtitle: Text(
                            '${v['year'] ?? ''} • ${v['seats'] ?? 4} مقاعد • ${v['full_price'] ?? 0} YER • ${v['status'] ?? ''}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: TIColors.teal),
                              onPressed: () => _openForm(v),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete,
                                  color: TIColors.danger),
                              onPressed: () => _delete(
                                  v['vehicle_id'] as int,
                                  v['name']?.toString() ?? ''),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

/// ============ 2. إدارة الفنادق والغرف (المحافظة + الإحداثيات + الغرف + الصور) ============
class AdminHotelsScreen extends StatefulWidget {
  const AdminHotelsScreen({super.key});

  @override
  State<AdminHotelsScreen> createState() => _AdminHotelsScreenState();
}

class _AdminHotelsScreenState extends State<AdminHotelsScreen> {
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _provinces = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await supabase
          .from('hotels')
          .select()
          .order('hotel_id', ascending: false);
      final provs =
          await supabase.from('provinces').select().order('province_id');
      if (!mounted) return;
      setState(() {
        _items = List<Map<String, dynamic>>.from(res);
        _provinces = List<Map<String, dynamic>>.from(provs);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطأ التحميل: $e')));
    }
  }

  Future<void> _delete(int id, String name) async {
    try {
      await supabase.from('hotel_rooms').delete().eq('hotel_id', id);
      await supabase.from('hotels').delete().eq('hotel_id', id);
      await AppState.instance?.fetchLiveCatalog();
      await logAdminAction('Delete hotel #$id', oldVal: name);
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('فشل الحذف: $e')));
    }
  }

  Future<void> _openForm([Map<String, dynamic>? item]) async {
    final name =
        TextEditingController(text: item?['name_ar']?.toString() ?? '');
    final rating =
        TextEditingController(text: (item?['rating'] ?? 4.5).toString());
    final latCtrl =
        TextEditingController(text: item?['lat']?.toString() ?? '');
    final lngCtrl =
        TextEditingController(text: item?['lng']?.toString() ?? '');
    final imgCtrl =
        TextEditingController(text: item?['image_url']?.toString() ?? '');
    int? provinceId = item?['province_id'] as int?;
    bool verified = item?['verified'] ?? true;
    bool uploading = false;

    try {
      final saved = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setS) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              left: 16,
              right: 16,
              top: 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(item == null ? 'إضافة فندق جديد' : 'تعديل فندق',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(
                        labelText: 'اسم الفندق', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  if (_provinces.isNotEmpty) ...[
                    DropdownButtonFormField<int?>(
                      value: provinceId,
                      decoration: const InputDecoration(
                          labelText: 'المحافظة', border: OutlineInputBorder()),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('اختر المحافظة')),
                        ..._provinces.map((p) => DropdownMenuItem(
                              value: p['province_id'] as int,
                              child: Text(p['name_ar']?.toString() ?? ''),
                            )),
                      ],
                      onChanged: (v) => setS(() => provinceId = v),
                    ),
                    const SizedBox(height: 10),
                  ],
                  TextField(
                    controller: rating,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'التقييم (من 5)',
                        border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: latCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                            labelText: 'خط العرض (Lat)',
                            border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: lngCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                            labelText: 'خط الطول (Lng)',
                            border: OutlineInputBorder()),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: imgCtrl,
                        decoration: const InputDecoration(
                            labelText: 'رابط الصورة',
                            border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: uploading
                          ? null
                          : () async {
                              setS(() => uploading = true);
                              final url =
                                  await pickAndUploadAdminImage(ctx, 'hotel');
                              if (url != null) imgCtrl.text = url;
                              setS(() => uploading = false);
                            },
                      icon: uploading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.photo_library),
                      label: const Text('رفع'),
                    ),
                  ]),
                  SwitchListTile(
                    title: const Text('فندق موثّق'),
                    value: verified,
                    onChanged: (v) => setS(() => verified = v),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        if (name.text.trim().isEmpty) return;
                        final data = {
                          'name_ar': name.text.trim(),
                          'province_id': provinceId,
                          'rating': double.tryParse(rating.text.trim()) ?? 4.5,
                          'lat': double.tryParse(latCtrl.text.trim()),
                          'lng': double.tryParse(lngCtrl.text.trim()),
                          'verified': verified,
                          'image_url': imgCtrl.text.trim().isEmpty
                              ? null
                              : imgCtrl.text.trim(),
                        };
                        try {
                          if (item == null) {
                            await supabase.from('hotels').insert(data);
                            await AppState.instance?.fetchLiveCatalog();
      await logAdminAction('Add hotel',
                                newVal: name.text.trim());
                          } else {
                            await supabase
                                .from('hotels')
                                .update(data)
                                .eq('hotel_id', item['hotel_id']);
                            await AppState.instance?.fetchLiveCatalog();
      await logAdminAction(
                                'Update hotel #${item['hotel_id']}',
                                newVal: name.text.trim());
                          }
                          if (ctx.mounted) Navigator.pop(ctx, true);
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(content: Text('فشل الحفظ: $e')));
                          }
                        }
                      },
                      child: const Text('حفظ'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      if (saved == true) _load();
    } finally {
      name.dispose();
      rating.dispose();
      latCtrl.dispose();
      lngCtrl.dispose();
      imgCtrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة الفنادق والغرف')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('إضافة فندق'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text('لا توجد فنادق في قاعدة البيانات بعد'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (_, i) {
                      final h = _items[i];
                      final img = h['image_url']?.toString();
                      return ListTile(
                        leading: img != null && img.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(img,
                                    width: 48, height: 48, fit: BoxFit.cover),
                              )
                            : const Icon(Icons.hotel, color: TIColors.gold),
                        title: Text(h['name_ar']?.toString() ?? ''),
                        subtitle: Text(
                            '⭐ ${h['rating'] ?? 4.5} • اضغط لإدارة الغرف'),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AdminHotelRoomsScreen(
                              hotelId: h['hotel_id'] as int,
                              hotelName: h['name_ar']?.toString() ?? '',
                            ),
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.bed, color: TIColors.gold),
                              tooltip: 'الغرف',
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AdminHotelRoomsScreen(
                                    hotelId: h['hotel_id'] as int,
                                    hotelName: h['name_ar']?.toString() ?? '',
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, color: TIColors.teal),
                              onPressed: () => _openForm(h),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete,
                                  color: TIColors.danger),
                              onPressed: () => _delete(
                                  h['hotel_id'] as int,
                                  h['name_ar']?.toString() ?? ''),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

/// ============ إدارة غرف الفندق ============
class AdminHotelRoomsScreen extends StatefulWidget {
  final int hotelId;
  final String hotelName;
  const AdminHotelRoomsScreen(
      {super.key, required this.hotelId, required this.hotelName});

  @override
  State<AdminHotelRoomsScreen> createState() => _AdminHotelRoomsScreenState();
}

class _AdminHotelRoomsScreenState extends State<AdminHotelRoomsScreen> {
  List<Map<String, dynamic>> _rooms = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await supabase
          .from('hotel_rooms')
          .select()
          .eq('hotel_id', widget.hotelId)
          .order('room_id', ascending: false);
      if (!mounted) return;
      setState(() {
        _rooms = List<Map<String, dynamic>>.from(res);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطأ التحميل: $e')));
    }
  }

  Future<void> _openForm([Map<String, dynamic>? item]) async {
    final name = TextEditingController(text: item?['name']?.toString() ?? '');
    final bed =
        TextEditingController(text: item?['bed_type']?.toString() ?? 'King');
    final price = TextEditingController(
        text: (item?['price_night'] ?? 35000).toString());
    final cap =
        TextEditingController(text: (item?['capacity'] ?? 2).toString());
    bool available = item?['available'] ?? true;

    try {
      final saved = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setS) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              left: 16,
              right: 16,
              top: 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(item == null ? 'إضافة غرفة' : 'تعديل غرفة',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                TextField(
                  controller: name,
                  decoration: const InputDecoration(
                      labelText: 'اسم/نوع الغرفة',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: bed,
                  decoration: const InputDecoration(
                      labelText: 'نوع السرير', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: price,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'السعر لليلة (YER)',
                          border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: cap,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'السعة (أشخاص)',
                          border: OutlineInputBorder()),
                    ),
                  ),
                ]),
                SwitchListTile(
                  title: const Text('متاحة للحجز'),
                  value: available,
                  onChanged: (v) => setS(() => available = v),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      final data = {
                        'hotel_id': widget.hotelId,
                        'name': name.text.trim(),
                        'bed_type': bed.text.trim(),
                        'price_night': double.tryParse(price.text.trim()) ?? 0,
                        'capacity': int.tryParse(cap.text.trim()) ?? 2,
                        'available': available,
                      };
                      try {
                        if (item == null) {
                          await supabase.from('hotel_rooms').insert(data);
                          await AppState.instance?.fetchLiveCatalog();
      await logAdminAction('Add room',
                              newVal: '${widget.hotelName}: ${name.text.trim()}');
                        } else {
                          await supabase
                              .from('hotel_rooms')
                              .update(data)
                              .eq('room_id', item['room_id']);
                          await AppState.instance?.fetchLiveCatalog();
      await logAdminAction('Update room #${item['room_id']}',
                              newVal: name.text.trim());
                        }
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text('فشل الحفظ: $e')));
                        }
                      }
                    },
                    child: const Text('حفظ'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      if (saved == true) _load();
    } finally {
      name.dispose();
      bed.dispose();
      price.dispose();
      cap.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('غرف: ${widget.hotelName}')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('إضافة غرفة'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rooms.isEmpty
              ? const Center(child: Text('لا توجد غرف مضافة لهذا الفندق'))
              : ListView.builder(
                  itemCount: _rooms.length,
                  itemBuilder: (_, i) {
                    final r = _rooms[i];
                    return ListTile(
                      leading: const Icon(Icons.bed, color: TIColors.teal),
                      title: Text(r['name']?.toString() ?? ''),
                      subtitle: Text(
                          '${r['bed_type'] ?? ''} • ${r['capacity'] ?? 2} أشخاص • ${r['price_night'] ?? 0} YER'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: TIColors.teal),
                            onPressed: () => _openForm(r),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete,
                                color: TIColors.danger),
                            onPressed: () async {
                              await supabase
                                  .from('hotel_rooms')
                                  .delete()
                                  .eq('room_id', r['room_id']);
                              _load();
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

/// ============ 3. إدارة السائقين ============
class AdminDriversScreen extends StatefulWidget {
  const AdminDriversScreen({super.key});

  @override
  State<AdminDriversScreen> createState() => _AdminDriversScreenState();
}

class _AdminDriversScreenState extends State<AdminDriversScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await supabase
          .from('drivers')
          .select()
          .order('driver_id', ascending: false);
      if (!mounted) return;
      setState(() {
        _items = List<Map<String, dynamic>>.from(res);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطأ التحميل: $e')));
    }
  }

  Future<void> _openForm([Map<String, dynamic>? item]) async {
    final name =
        TextEditingController(text: item?['full_name']?.toString() ?? '');
    final license =
        TextEditingController(text: item?['license_no']?.toString() ?? '');
    final rating =
        TextEditingController(text: (item?['rating'] ?? 4.8).toString());

    try {
      final saved = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(item == null ? 'إضافة سائق جديد' : 'تعديل سائق',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              TextField(
                controller: name,
                decoration: const InputDecoration(
                    labelText: 'الاسم الكامل للسائق',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: license,
                decoration: const InputDecoration(
                    labelText: 'رقم الرخصة', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: rating,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'التقييم (من 5)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    if (name.text.trim().isEmpty) return;
                    final data = {
                      'full_name': name.text.trim(),
                      'license_no': license.text.trim(),
                      'rating': double.tryParse(rating.text.trim()) ?? 4.8,
                    };
                    try {
                      if (item == null) {
                        await supabase.from('drivers').insert(data);
                        await AppState.instance?.fetchLiveCatalog();
      await logAdminAction('Add driver',
                            newVal: name.text.trim());
                      } else {
                        await supabase
                            .from('drivers')
                            .update(data)
                            .eq('driver_id', item['driver_id']);
                        await AppState.instance?.fetchLiveCatalog();
      await logAdminAction(
                            'Update driver #${item['driver_id']}',
                            newVal: name.text.trim());
                      }
                      if (ctx.mounted) Navigator.pop(ctx, true);
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('فشل الحفظ: $e')));
                      }
                    }
                  },
                  child: const Text('حفظ'),
                ),
              ),
            ],
          ),
        ),
      );
      if (saved == true) _load();
    } finally {
      name.dispose();
      license.dispose();
      rating.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة السائقين')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('إضافة سائق'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text('لا يوجد سائقون مسجلون بعد'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (_, i) {
                      final d = _items[i];
                      return ListTile(
                        leading:
                            const Icon(Icons.badge, color: TIColors.teal),
                        title: Text(d['full_name']?.toString() ?? ''),
                        subtitle: Text(
                            'رخصة: ${d['license_no'] ?? '—'} • ⭐ ${d['rating'] ?? 4.8}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: TIColors.teal),
                              onPressed: () => _openForm(d),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete,
                                  color: TIColors.danger),
                              onPressed: () async {
                                await supabase
                                    .from('drivers')
                                    .delete()
                                    .eq('driver_id', d['driver_id']);
                                await AppState.instance?.fetchLiveCatalog();
      await logAdminAction(
                                    'Delete driver #${d['driver_id']}',
                                    oldVal: d['full_name']?.toString());
                                _load();
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

/// ============ 4. إدارة العروض ============
class AdminOffersScreen extends StatefulWidget {
  const AdminOffersScreen({super.key});

  @override
  State<AdminOffersScreen> createState() => _AdminOffersScreenState();
}

class _AdminOffersScreenState extends State<AdminOffersScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await supabase
          .from('offers')
          .select()
          .order('offer_id', ascending: false);
      if (!mounted) return;
      setState(() {
        _items = List<Map<String, dynamic>>.from(res);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطأ التحميل: $e')));
    }
  }

  Future<void> _delete(int id, String title) async {
    try {
      await supabase.from('offers').delete().eq('offer_id', id);
      await AppState.instance?.fetchLiveCatalog();
      await logAdminAction('Delete offer #$id', oldVal: title);
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('فشل الحذف: $e')));
    }
  }

  Future<void> _openForm([Map<String, dynamic>? item]) async {
    final title = TextEditingController(text: item?['title']?.toString() ?? '');
    final subtitle =
        TextEditingController(text: item?['subtitle']?.toString() ?? '');
    final discount =
        TextEditingController(text: (item?['discount'] ?? 15).toString());
    final imgCtrl =
        TextEditingController(text: item?['image_url']?.toString() ?? '');
    bool active = item?['active'] ?? true;
    bool uploading = false;

    try {
      final saved = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setS) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              left: 16,
              right: 16,
              top: 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(item == null ? 'إضافة عرض جديد' : 'تعديل عرض',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(
                        labelText: 'عنوان العرض', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: subtitle,
                    decoration: const InputDecoration(
                        labelText: 'الوصف', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: discount,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'نسبة الخصم (%)',
                        border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: imgCtrl,
                        decoration: const InputDecoration(
                            labelText: 'رابط الصورة',
                            border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: uploading
                          ? null
                          : () async {
                              setS(() => uploading = true);
                              final url =
                                  await pickAndUploadAdminImage(ctx, 'offer');
                              if (url != null) imgCtrl.text = url;
                              setS(() => uploading = false);
                            },
                      icon: uploading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.photo_library),
                      label: const Text('رفع'),
                    ),
                  ]),
                  SwitchListTile(
                    title: const Text('العرض نشط'),
                    value: active,
                    onChanged: (v) => setS(() => active = v),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        if (title.text.trim().isEmpty) return;
                        final data = {
                          'title': title.text.trim(),
                          'subtitle': subtitle.text.trim(),
                          'discount': int.tryParse(discount.text.trim()) ?? 10,
                          'active': active,
                          'image_url': imgCtrl.text.trim().isEmpty
                              ? null
                              : imgCtrl.text.trim(),
                        };
                        try {
                          if (item == null) {
                            await supabase.from('offers').insert(data);
                            await AppState.instance?.fetchLiveCatalog();
      await logAdminAction('Add offer',
                                newVal: title.text.trim());
                          } else {
                            await supabase
                                .from('offers')
                                .update(data)
                                .eq('offer_id', item['offer_id']);
                            await AppState.instance?.fetchLiveCatalog();
      await logAdminAction(
                                'Update offer #${item['offer_id']}',
                                newVal: title.text.trim());
                          }
                          if (ctx.mounted) Navigator.pop(ctx, true);
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(content: Text('فشل الحفظ: $e')));
                          }
                        }
                      },
                      child: const Text('حفظ'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      if (saved == true) _load();
    } finally {
      title.dispose();
      subtitle.dispose();
      discount.dispose();
      imgCtrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة العروض')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('إضافة عرض'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text('لا توجد عروض في قاعدة البيانات بعد'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (_, i) {
                      final o = _items[i];
                      final img = o['image_url']?.toString();
                      return ListTile(
                        leading: img != null && img.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(img,
                                    width: 48, height: 48, fit: BoxFit.cover),
                              )
                            : const Icon(Icons.local_offer,
                                color: TIColors.orange),
                        title: Text(o['title']?.toString() ?? ''),
                        subtitle: Text(
                            '${o['discount'] ?? 0}% • ${o['subtitle'] ?? ''}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: TIColors.teal),
                              onPressed: () => _openForm(o),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete,
                                  color: TIColors.danger),
                              onPressed: () => _delete(
                                  o['offer_id'] as int,
                                  o['title']?.toString() ?? ''),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

/// ============ 5. إدارة الأسعار وأسعار الصرف ============
class AdminPricingScreen extends StatefulWidget {
  const AdminPricingScreen({super.key});

  @override
  State<AdminPricingScreen> createState() => _AdminPricingScreenState();
}

class _AdminPricingScreenState extends State<AdminPricingScreen> {
  List<Map<String, dynamic>> _rates = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await supabase
          .from('exchange_rates')
          .select()
          .order('rate_id');
      if (!mounted) return;
      setState(() {
        _rates = List<Map<String, dynamic>>.from(res);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطأ التحميل: $e')));
    }
  }

  Future<void> _editRate(Map<String, dynamic> r) async {
    final ctrl = TextEditingController(text: r['rate']?.toString() ?? '1');
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          title: Text('تعديل سعر ${r['from_cur']} → ${r['to_cur']}'),
          content: TextField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
                labelText: 'السعر الجديد', border: OutlineInputBorder()),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(d, false),
                child: const Text('إلغاء')),
            FilledButton(
                onPressed: () => Navigator.pop(d, true),
                child: const Text('حفظ')),
          ],
        ),
      );
      if (ok != true) return;
      final val = double.tryParse(ctrl.text.trim());
      if (val == null || val <= 0) return;
      await supabase
          .from('exchange_rates')
          .update({'rate': val, 'updated_at': DateTime.now().toIso8601String()})
          .eq('rate_id', r['rate_id']);
      await AppState.instance?.fetchLiveCatalog();
      await logAdminAction(
        'Update rate ${r['from_cur']}->${r['to_cur']}',
        oldVal: r['rate']?.toString(),
        newVal: '$val',
      );
      _load();
    } finally {
      ctrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة الأسعار والصرف')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rates.isEmpty
              ? const Center(child: Text('لا توجد أسعار صرف مسجلة'))
              : ListView.builder(
                  itemCount: _rates.length,
                  itemBuilder: (_, i) {
                    final r = _rates[i];
                    return ListTile(
                      leading: const Icon(Icons.currency_exchange,
                          color: TIColors.gold),
                      title: Text('${r['from_cur']} → ${r['to_cur']}'),
                      subtitle: Text('السعر الحالي: ${r['rate']}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit, color: TIColors.teal),
                        onPressed: () => _editRate(r),
                      ),
                    );
                  },
                ),
    );
  }
}

/// ============ 6. سجل التدقيق (Audit Logs) ============
class AdminAuditLogsScreen extends StatefulWidget {
  const AdminAuditLogsScreen({super.key});

  @override
  State<AdminAuditLogsScreen> createState() => _AdminAuditLogsScreenState();
}

class _AdminAuditLogsScreenState extends State<AdminAuditLogsScreen> {
  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await supabase
          .from('audit_logs')
          .select()
          .order('changed_at', ascending: false)
          .limit(50);
      if (!mounted) return;
      setState(() {
        _logs = List<Map<String, dynamic>>.from(res);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('سجل التدقيق')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
              ? const Center(child: Text('لا توجد عمليات مسجلة في السجل بعد'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    itemCount: _logs.length,
                    itemBuilder: (_, i) {
                      final l = _logs[i];
                      return ListTile(
                        leading:
                            const Icon(Icons.history, color: TIColors.teal),
                        title: Text(l['action']?.toString() ?? ''),
                        subtitle: Text(
                            '${l['new_value'] ?? l['old_value'] ?? ''} • ${l['changed_at'] ?? ''}'),
                      );
                    },
                  ),
                ),
    );
  }
}
