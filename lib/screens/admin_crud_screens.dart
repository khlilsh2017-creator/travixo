import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../state/app_state.dart';
import '../supabase.dart';
import '../theme/app_theme.dart';

/// تسجيل أي تعديل إداري في جدول audit_logs
Future<void> logAdminAction(String action,
    {String? oldVal, String? newVal}) async {
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

/// نافذة تأكيد الحذف المشتركة
Future<bool> _confirmDelete(BuildContext context, String itemName) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      title: const Text('تأكيد الحذف'),
      content: Text('هل أنت متأكد من حذف «$itemName»؟ لا يمكن التراجع عن هذا الإجراء.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(d, false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: TIColors.danger),
          onPressed: () => Navigator.pop(d, true),
          child: const Text('حذف'),
        ),
      ],
    ),
  );
  return ok == true;
}

/// شريط ملخص الإحصائيات أعلى كل شاشة إدارة
class _AdminStatStrip extends StatelessWidget {
  final List<(String label, String value, Color color)> stats;
  const _AdminStatStrip({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < stats.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Theme.of(context).dividerColor.withOpacity(0.5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stats[i].$2,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: stats[i].$3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    stats[i].$1,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Theme.of(context).hintColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// مكون معاينة ورفع الصورة داخل نماذج الإضافة والتعديل
class _AdminImagePickerSection extends StatelessWidget {
  final TextEditingController controller;
  final bool uploading;
  final VoidCallback onPick;
  const _AdminImagePickerSection({
    required this.controller,
    required this.uploading,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final url = controller.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (url.isNotEmpty) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.network(
              url,
              height: 140,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 90,
                color: TIColors.orangeTint,
                alignment: Alignment.center,
                child: const Text('تعذّر معاينة الرابط',
                    style: TextStyle(fontSize: 12)),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'رابط الصورة',
                  hintText: 'https://...',
                  prefixIcon: Icon(Icons.link, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: uploading ? null : onPick,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              icon: uploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.upload_rounded, size: 18),
              label: const Text('رفع'),
            ),
          ],
        ),
      ],
    );
  }
}

/// ============ 1. إدارة السيارات (عرض مطور + بحث + فلاتر + تبديل سريع للحالة) ============
class AdminVehiclesScreen extends StatefulWidget {
  const AdminVehiclesScreen({super.key});
  @override
  State<AdminVehiclesScreen> createState() => _AdminVehiclesScreenState();
}

class _AdminVehiclesScreenState extends State<AdminVehiclesScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _drivers = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _companies = [];

  String _query = '';
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res =
          await supabase.from('vehicles').select().order('vehicle_id');
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

  String _driverName(dynamic id) {
    if (id == null) return 'بدون سائق محدد';
    for (final d in _drivers) {
      if (d['driver_id'] == id) return d['full_name']?.toString() ?? '—';
    }
    return '—';
  }

  String _catName(dynamic id) {
    for (final c in _categories) {
      if (c['category_id'] == id) {
        return c['name_ar']?.toString() ?? c['name']?.toString() ?? '—';
      }
    }
    return 'عام';
  }

  Future<void> _quickToggleStatus(Map<String, dynamic> v) async {
    final current = (v['status'] ?? 'available').toString();
    final next = current == 'available' ? 'busy' : 'available';
    try {
      await supabase
          .from('vehicles')
          .update({'status': next})
          .eq('vehicle_id', v['vehicle_id']);
      await AppState.instance?.fetchLiveCatalog();
      await logAdminAction('Toggle vehicle #${v['vehicle_id']} status',
          oldVal: current, newVal: next);
      _load();
    } catch (_) {}
  }

  Future<void> _delete(dynamic id, String name) async {
    if (!await _confirmDelete(context, name)) return;
    try {
      await supabase.from('vehicles').delete().eq('vehicle_id', id);
      await AppState.instance?.fetchLiveCatalog();
      await logAdminAction('Delete vehicle #$id', oldVal: name);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('فشل الحذف: $e')));
      }
    }
  }

  Future<void> _openForm([Map<String, dynamic>? item]) async {
    final name = TextEditingController(text: item?['name']?.toString() ?? '');
    final year =
        TextEditingController(text: item?['year']?.toString() ?? '2024');
    final seats =
        TextEditingController(text: item?['seats']?.toString() ?? '4');
    final fullPrice =
        TextEditingController(text: item?['full_price']?.toString() ?? '35000');
    final seatPrice =
        TextEditingController(text: item?['seat_price']?.toString() ?? '8000');
    final imgCtrl =
        TextEditingController(text: item?['image_url']?.toString() ?? '');
    bool withDriver = item?['with_driver'] == true;
    String status = item?['status']?.toString() ?? 'available';
    dynamic driverId = item?['driver_id'];
    dynamic categoryId = item?['category_id'] ??
        (_categories.isNotEmpty ? _categories.first['category_id'] : null);
    dynamic companyId = item?['company_id'] ??
        (_companies.isNotEmpty ? _companies.first['company_id'] : null);
    bool uploading = false;

    try {
      final saved = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setS) => Padding(
            padding: EdgeInsets.fromLTRB(
                18, 18, 18, MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item == null ? 'إضافة سيارة جديدة' : 'تعديل بيانات السيارة',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 14),
                  _AdminImagePickerSection(
                    controller: imgCtrl,
                    uploading: uploading,
                    onPick: () async {
                      setS(() => uploading = true);
                      final url = await pickAndUploadAdminImage(ctx, 'vehicle');
                      if (url != null) imgCtrl.text = url;
                      setS(() => uploading = false);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(
                        labelText: 'اسم وموديل السيارة *'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: year,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'سنة الصنع'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: seats,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'عدد المقاعد'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: fullPrice,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'سعر اليوم (YER)'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: seatPrice,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'سعر المقعد (YER)'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: ['available', 'busy', 'maintenance'].contains(status)
                        ? status
                        : 'available',
                    decoration: const InputDecoration(labelText: 'الحالة'),
                    items: const [
                      DropdownMenuItem(value: 'available', child: Text('متاحة')),
                      DropdownMenuItem(value: 'busy', child: Text('محجوزة')),
                      DropdownMenuItem(
                          value: 'maintenance', child: Text('في الصيانة')),
                    ],
                    onChanged: (v) => setS(() => status = v ?? 'available'),
                  ),
                  if (_categories.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<dynamic>(
                      value: _categories
                              .any((c) => c['category_id'] == categoryId)
                          ? categoryId
                          : null,
                      decoration: const InputDecoration(labelText: 'فئة السيارة'),
                      items: _categories
                          .map((c) => DropdownMenuItem<dynamic>(
                                value: c['category_id'],
                                child: Text(c['name_ar']?.toString() ??
                                    c['name']?.toString() ??
                                    '#${c['category_id']}'),
                              ))
                          .toList(),
                      onChanged: (v) => setS(() => categoryId = v),
                    ),
                  ],
                  if (_drivers.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<dynamic>(
                      value: _drivers.any((d) => d['driver_id'] == driverId)
                          ? driverId
                          : null,
                      decoration: const InputDecoration(labelText: 'السائق'),
                      items: [
                        const DropdownMenuItem<dynamic>(
                            value: null, child: Text('بدون سائق محدد')),
                        ..._drivers.map((d) => DropdownMenuItem<dynamic>(
                              value: d['driver_id'],
                              child: Text(d['full_name']?.toString() ??
                                  '#${d['driver_id']}'),
                            )),
                      ],
                      onChanged: (v) => setS(() => driverId = v),
                    ),
                  ],
                  if (_companies.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<dynamic>(
                      value: _companies.any((c) => c['company_id'] == companyId)
                          ? companyId
                          : null,
                      decoration:
                          const InputDecoration(labelText: 'شركة النقل'),
                      items: _companies
                          .map((c) => DropdownMenuItem<dynamic>(
                                value: c['company_id'],
                                child: Text(c['name']?.toString() ??
                                    '#${c['company_id']}'),
                              ))
                          .toList(),
                      onChanged: (v) => setS(() => companyId = v),
                    ),
                  ],
                  const SizedBox(height: 6),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('متاحة مع سائق',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    value: withDriver,
                    onChanged: (v) => setS(() => withDriver = v),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
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
                      icon: const Icon(Icons.save_rounded, size: 18),
                      label: const Text('حفظ السيارة'),
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
    final availCount =
        _items.where((v) => v['status'] == 'available').length;
    final drvCount = _items.where((v) => v['with_driver'] == true).length;

    final filtered = _items.where((v) {
      if (_statusFilter != 'all' &&
          (v['status'] ?? '').toString() != _statusFilter) {
        return false;
      }
      if (_query.trim().isNotEmpty) {
        final q = _query.trim().toLowerCase();
        final hay =
            '${v['name'] ?? ''} ${v['year'] ?? ''} ${_driverName(v['driver_id'])}'
                .toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة السيارات والأسطول'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('إضافة سيارة'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                children: [
                  _AdminStatStrip(stats: [
                    ('إجمالي السيارات', '${_items.length}', TIColors.navy),
                    ('متاحة الآن', '$availCount', TIColors.success),
                    ('مع سائق', '$drvCount', TIColors.orangeDeep),
                  ]),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (v) => setState(() => _query = v),
                    decoration: const InputDecoration(
                      hintText: 'ابحث باسم السيارة، الموديل، أو السائق...',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final f in const [
                          ('all', 'الكل'),
                          ('available', 'متاحة'),
                          ('busy', 'محجوزة'),
                          ('maintenance', 'صيانة'),
                        ])
                          Padding(
                            padding: const EdgeInsetsDirectional.only(end: 8),
                            child: ChoiceChip(
                              label: Text(f.$2),
                              selected: _statusFilter == f.$1,
                              onSelected: (_) =>
                                  setState(() => _statusFilter = f.$1),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (filtered.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(36),
                      child: Center(child: Text('لا توجد سيارات مطابقة')),
                    )
                  else
                    LayoutBuilder(
                      builder: (ctx, c) {
                        final cols = c.maxWidth >= 780 ? 2 : 1;
                        const spacing = 12.0;
                        final w = (c.maxWidth - (cols - 1) * spacing) / cols;
                        return Wrap(
                          spacing: spacing,
                          runSpacing: spacing,
                          children: filtered.map((v) {
                            final st = (v['status'] ?? 'available').toString();
                            final isAvail = st == 'available';
                            final stColor = isAvail
                                ? TIColors.success
                                : (st == 'busy'
                                    ? TIColors.warning
                                    : TIColors.danger);
                            final img = v['image_url']?.toString();
                            return SizedBox(
                              width: w,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(ctx).cardColor,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: Theme.of(ctx)
                                        .dividerColor
                                        .withOpacity(0.5),
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      height: 138,
                                      width: double.infinity,
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          if (img != null && img.isNotEmpty)
                                            Image.network(
                                              img,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  Container(
                                                color: TIColors.orangeTint,
                                                child: const Icon(
                                                    Icons.directions_car,
                                                    size: 46,
                                                    color: TIColors.orangeDeep),
                                              ),
                                            )
                                          else
                                            Container(
                                              color: TIColors.orangeTint,
                                              child: const Icon(
                                                  Icons.directions_car,
                                                  size: 46,
                                                  color: TIColors.orangeDeep),
                                            ),
                                          Positioned(
                                            top: 10,
                                            right: 10,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: stColor,
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                isAvail
                                                    ? 'متاحة'
                                                    : (st == 'busy'
                                                        ? 'محجوزة'
                                                        : 'صيانة'),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  v['name']?.toString() ?? '—',
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      fontSize: 15),
                                                ),
                                              ),
                                              Text(
                                                '${v['full_price'] ?? 0} YER / يوم',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                  color: TIColors.orangeDeep,
                                                  fontSize: 13.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 4,
                                            children: [
                                              Text('موديل ${v['year'] ?? '—'}',
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      color: Theme.of(ctx)
                                                          .hintColor)),
                                              Text('• ${v['seats'] ?? 4} مقاعد',
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      color: Theme.of(ctx)
                                                          .hintColor)),
                                              Text(
                                                  '• ${_catName(v['category_id'])}',
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      color: Theme.of(ctx)
                                                          .hintColor)),
                                              if (v['with_driver'] == true)
                                                Text(
                                                    '• السائق: ${_driverName(v['driver_id'])}',
                                                    style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w700)),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: OutlinedButton.icon(
                                                  onPressed: () =>
                                                      _quickToggleStatus(v),
                                                  style:
                                                      OutlinedButton.styleFrom(
                                                    minimumSize:
                                                        const Size(0, 36),
                                                  ),
                                                  icon: Icon(
                                                    isAvail
                                                        ? Icons.pause_circle
                                                        : Icons.check_circle,
                                                    size: 16,
                                                  ),
                                                  label: Text(
                                                    isAvail
                                                        ? 'تعيين كمحجوزة'
                                                        : 'تفعيل الإتاحة',
                                                    style: const TextStyle(
                                                        fontSize: 11.5),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              IconButton(
                                                tooltip: 'تعديل',
                                                onPressed: () => _openForm(v),
                                                icon: const Icon(
                                                    Icons.edit_outlined,
                                                    color: TIColors.cardRent),
                                              ),
                                              IconButton(
                                                tooltip: 'حذف',
                                                onPressed: () => _delete(
                                                    v['vehicle_id'],
                                                    v['name']?.toString() ??
                                                        'السيارة'),
                                                icon: const Icon(
                                                    Icons.delete_outline,
                                                    color: TIColors.danger),
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
              ),
            ),
    );
  }
}

/// ============ 2. إدارة الفنادق (عرض مطور + بحث + فلتر محافظات + توثيق سريع + دخول للغرف) ============
class AdminHotelsScreen extends StatefulWidget {
  const AdminHotelsScreen({super.key});
  @override
  State<AdminHotelsScreen> createState() => _AdminHotelsScreenState();
}

class _AdminHotelsScreenState extends State<AdminHotelsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _provinces = [];
  String _query = '';
  dynamic _provinceFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await supabase.from('hotels').select().order('hotel_id');
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

  String _provName(dynamic id) {
    for (final p in _provinces) {
      if (p['province_id'] == id) {
        return p['name_ar']?.toString() ?? p['name']?.toString() ?? '—';
      }
    }
    return 'اليمن';
  }

  Future<void> _toggleVerified(Map<String, dynamic> h) async {
    final next = h['verified'] != true;
    try {
      await supabase
          .from('hotels')
          .update({'verified': next})
          .eq('hotel_id', h['hotel_id']);
      await AppState.instance?.fetchLiveCatalog();
      await logAdminAction('Toggle hotel #${h['hotel_id']} verified',
          newVal: '$next');
      _load();
    } catch (_) {}
  }

  Future<void> _delete(dynamic id, String name) async {
    if (!await _confirmDelete(context, name)) return;
    try {
      await supabase.from('hotel_rooms').delete().eq('hotel_id', id);
      await supabase.from('hotels').delete().eq('hotel_id', id);
      await AppState.instance?.fetchLiveCatalog();
      await logAdminAction('Delete hotel #$id', oldVal: name);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('فشل الحذف: $e')));
      }
    }
  }

  Future<void> _openForm([Map<String, dynamic>? item]) async {
    final name =
        TextEditingController(text: item?['name_ar']?.toString() ?? '');
    final rating =
        TextEditingController(text: item?['rating']?.toString() ?? '4.5');
    final latCtrl =
        TextEditingController(text: item?['lat']?.toString() ?? '');
    final lngCtrl =
        TextEditingController(text: item?['lng']?.toString() ?? '');
    final imgCtrl =
        TextEditingController(text: item?['image_url']?.toString() ?? '');
    dynamic provinceId = item?['province_id'] ??
        (_provinces.isNotEmpty ? _provinces.first['province_id'] : null);
    bool verified = item?['verified'] != false;
    bool uploading = false;

    try {
      final saved = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setS) => Padding(
            padding: EdgeInsets.fromLTRB(
                18, 18, 18, MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item == null ? 'إضافة فندق جديد' : 'تعديل بيانات الفندق',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 14),
                  _AdminImagePickerSection(
                    controller: imgCtrl,
                    uploading: uploading,
                    onPick: () async {
                      setS(() => uploading = true);
                      final url = await pickAndUploadAdminImage(ctx, 'hotel');
                      if (url != null) imgCtrl.text = url;
                      setS(() => uploading = false);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: name,
                    decoration:
                        const InputDecoration(labelText: 'اسم الفندق *'),
                  ),
                  const SizedBox(height: 10),
                  if (_provinces.isNotEmpty)
                    DropdownButtonFormField<dynamic>(
                      value: _provinces
                              .any((p) => p['province_id'] == provinceId)
                          ? provinceId
                          : null,
                      decoration: const InputDecoration(labelText: 'المحافظة'),
                      items: _provinces
                          .map((p) => DropdownMenuItem<dynamic>(
                                value: p['province_id'],
                                child: Text(p['name_ar']?.toString() ??
                                    p['name']?.toString() ??
                                    '#${p['province_id']}'),
                              ))
                          .toList(),
                      onChanged: (v) => setS(() => provinceId = v),
                    ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: rating,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'التقييم (من 5)'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: latCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration:
                              const InputDecoration(labelText: 'خط العرض (Lat)'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: lngCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration:
                              const InputDecoration(labelText: 'خط الطول (Lng)'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('فندق موثّق ومعتمد',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    value: verified,
                    onChanged: (v) => setS(() => verified = v),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
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
                      icon: const Icon(Icons.save_rounded, size: 18),
                      label: const Text('حفظ الفندق'),
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
    final verifiedCount = _items.where((h) => h['verified'] == true).length;
    final filtered = _items.where((h) {
      if (_provinceFilter != null && h['province_id'] != _provinceFilter) {
        return false;
      }
      if (_query.trim().isNotEmpty) {
        final q = _query.trim().toLowerCase();
        final hay =
            '${h['name_ar'] ?? ''} ${_provName(h['province_id'])}'.toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الفنادق والغرف'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('إضافة فندق'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                children: [
                  _AdminStatStrip(stats: [
                    ('إجمالي الفنادق', '${_items.length}', TIColors.navy),
                    ('فنادق موثقة', '$verifiedCount', TIColors.success),
                    ('المحافظات', '${_provinces.length}', TIColors.orangeDeep),
                  ]),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (v) => setState(() => _query = v),
                    decoration: const InputDecoration(
                      hintText: 'ابحث باسم الفندق أو المحافظة...',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  if (_provinces.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          Padding(
                            padding: const EdgeInsetsDirectional.only(end: 8),
                            child: ChoiceChip(
                              label: const Text('كل المحافظات'),
                              selected: _provinceFilter == null,
                              onSelected: (_) =>
                                  setState(() => _provinceFilter = null),
                            ),
                          ),
                          for (final p in _provinces)
                            Padding(
                              padding: const EdgeInsetsDirectional.only(end: 8),
                              child: ChoiceChip(
                                label: Text(p['name_ar']?.toString() ??
                                    p['name']?.toString() ??
                                    '—'),
                                selected: _provinceFilter == p['province_id'],
                                onSelected: (_) => setState(
                                    () => _provinceFilter = p['province_id']),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  if (filtered.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(36),
                      child: Center(child: Text('لا توجد فنادق مطابقة')),
                    )
                  else
                    LayoutBuilder(
                      builder: (ctx, c) {
                        final cols = c.maxWidth >= 780 ? 2 : 1;
                        const spacing = 12.0;
                        final w = (c.maxWidth - (cols - 1) * spacing) / cols;
                        return Wrap(
                          spacing: spacing,
                          runSpacing: spacing,
                          children: filtered.map((h) {
                            final isVer = h['verified'] == true;
                            final img = h['image_url']?.toString();
                            final hName = h['name_ar']?.toString() ?? 'فندق';
                            return SizedBox(
                              width: w,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(ctx).cardColor,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: Theme.of(ctx)
                                        .dividerColor
                                        .withOpacity(0.5),
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      height: 140,
                                      width: double.infinity,
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          if (img != null && img.isNotEmpty)
                                            Image.network(
                                              img,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  Container(
                                                color: TIColors.orangeTint,
                                                child: const Icon(Icons.hotel,
                                                    size: 46,
                                                    color: TIColors.orangeDeep),
                                              ),
                                            )
                                          else
                                            Container(
                                              color: TIColors.orangeTint,
                                              child: const Icon(Icons.hotel,
                                                  size: 46,
                                                  color: TIColors.orangeDeep),
                                            ),
                                          Positioned(
                                            top: 10,
                                            right: 10,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 9,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: isVer
                                                    ? TIColors.success
                                                    : TIColors.warning,
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                isVer ? 'موثّق ✓' : 'قيد المراجعة',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            bottom: 10,
                                            left: 10,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 3),
                                              decoration: BoxDecoration(
                                                color: TIColors.navy
                                                    .withOpacity(0.8),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                '⭐ ${h['rating'] ?? 4.5}',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            hName,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w900,
                                                fontSize: 15.5),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${_provName(h['province_id'])} • ${h['lat'] != null ? 'إحداثيات GPS مضبوطة' : 'بدون إحداثيات'}',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Theme.of(ctx).hintColor),
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: FilledButton.icon(
                                                  onPressed: () =>
                                                      Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          AdminHotelRoomsScreen(
                                                        hotelId: h['hotel_id'],
                                                        hotelName: hName,
                                                      ),
                                                    ),
                                                  ),
                                                  style: FilledButton.styleFrom(
                                                    minimumSize:
                                                        const Size(0, 36),
                                                  ),
                                                  icon: const Icon(
                                                      Icons.bed_outlined,
                                                      size: 16),
                                                  label: const Text(
                                                    'إدارة الغرف',
                                                    style:
                                                        TextStyle(fontSize: 12),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              IconButton(
                                                tooltip: isVer
                                                    ? 'إلغاء التوثيق'
                                                    : 'توثيق الفندق',
                                                onPressed: () =>
                                                    _toggleVerified(h),
                                                icon: Icon(
                                                  isVer
                                                      ? Icons.verified
                                                      : Icons.verified_outlined,
                                                  color: TIColors.success,
                                                ),
                                              ),
                                              IconButton(
                                                tooltip: 'تعديل',
                                                onPressed: () => _openForm(h),
                                                icon: const Icon(
                                                    Icons.edit_outlined,
                                                    color: TIColors.cardRent),
                                              ),
                                              IconButton(
                                                tooltip: 'حذف',
                                                onPressed: () => _delete(
                                                    h['hotel_id'], hName),
                                                icon: const Icon(
                                                    Icons.delete_outline,
                                                    color: TIColors.danger),
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
              ),
            ),
    );
  }
}

/// ============ 3. إدارة غرف الفندق (تبديل فوري للإتاحة + بحث + بطاقات حديثة) ============
class AdminHotelRoomsScreen extends StatefulWidget {
  final dynamic hotelId;
  final String hotelName;
  const AdminHotelRoomsScreen(
      {super.key, required this.hotelId, required this.hotelName});

  @override
  State<AdminHotelRoomsScreen> createState() => _AdminHotelRoomsScreenState();
}

class _AdminHotelRoomsScreenState extends State<AdminHotelRoomsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _rooms = [];
  String _filter = 'all';

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
          .order('room_id');
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

  Future<void> _toggleAvailable(Map<String, dynamic> r) async {
    final next = r['available'] != true;
    try {
      await supabase
          .from('hotel_rooms')
          .update({'available': next})
          .eq('room_id', r['room_id']);
      await AppState.instance?.fetchLiveCatalog();
      await logAdminAction('Toggle room #${r['room_id']} available',
          newVal: '$next');
      _load();
    } catch (_) {}
  }

  Future<void> _deleteRoom(Map<String, dynamic> r) async {
    if (!await _confirmDelete(context, r['name']?.toString() ?? 'الغرفة')) {
      return;
    }
    try {
      await supabase.from('hotel_rooms').delete().eq('room_id', r['room_id']);
      await AppState.instance?.fetchLiveCatalog();
      await logAdminAction('Delete room #${r['room_id']}',
          oldVal: r['name']?.toString());
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('فشل الحذف: $e')));
      }
    }
  }

  Future<void> _openForm([Map<String, dynamic>? item]) async {
    final name = TextEditingController(text: item?['name']?.toString() ?? '');
    final bed =
        TextEditingController(text: item?['bed_type']?.toString() ?? 'سرير مزدوج');
    final price =
        TextEditingController(text: item?['price_night']?.toString() ?? '25000');
    final cap =
        TextEditingController(text: item?['capacity']?.toString() ?? '2');
    bool available = item?['available'] != false;

    try {
      final saved = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setS) => Padding(
            padding: EdgeInsets.fromLTRB(
                18, 18, 18, MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item == null ? 'إضافة غرفة جديدة' : 'تعديل بيانات الغرفة',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(
                        labelText: 'اسم الغرفة / الجناح *'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: bed,
                    decoration: const InputDecoration(labelText: 'نوع السرير'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: price,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'سعر الليلة (YER)'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: cap,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'السعة (أشخاص)'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('الغرفة متاحة للحجز',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    value: available,
                    onChanged: (v) => setS(() => available = v),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        if (name.text.trim().isEmpty) return;
                        final data = {
                          'hotel_id': widget.hotelId,
                          'name': name.text.trim(),
                          'bed_type': bed.text.trim(),
                          'price_night':
                              double.tryParse(price.text.trim()) ?? 0,
                          'capacity': int.tryParse(cap.text.trim()) ?? 2,
                          'available': available,
                        };
                        try {
                          if (item == null) {
                            await supabase.from('hotel_rooms').insert(data);
                            await AppState.instance?.fetchLiveCatalog();
                            await logAdminAction('Add room',
                                newVal:
                                    '${widget.hotelName}: ${name.text.trim()}');
                          } else {
                            await supabase
                                .from('hotel_rooms')
                                .update(data)
                                .eq('room_id', item['room_id']);
                            await AppState.instance?.fetchLiveCatalog();
                            await logAdminAction(
                                'Update room #${item['room_id']}',
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
                      icon: const Icon(Icons.save_rounded, size: 18),
                      label: const Text('حفظ الغرفة'),
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
      bed.dispose();
      price.dispose();
      cap.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final availCount = _rooms.where((r) => r['available'] == true).length;
    final filtered = _rooms.where((r) {
      if (_filter == 'available') return r['available'] == true;
      if (_filter == 'unavailable') return r['available'] != true;
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('غرف: ${widget.hotelName}'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('إضافة غرفة'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                children: [
                  _AdminStatStrip(stats: [
                    ('إجمالي الغرف', '${_rooms.length}', TIColors.navy),
                    ('متاحة للحجز', '$availCount', TIColors.success),
                    ('غير متاحة', '${_rooms.length - availCount}',
                        TIColors.danger),
                  ]),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      for (final f in const [
                        ('all', 'الكل'),
                        ('available', 'متاحة'),
                        ('unavailable', 'غير متاحة'),
                      ])
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 8),
                          child: ChoiceChip(
                            label: Text(f.$2),
                            selected: _filter == f.$1,
                            onSelected: (_) => setState(() => _filter = f.$1),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (filtered.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(36),
                      child: Center(child: Text('لا توجد غرف مضافة بعد')),
                    )
                  else
                    ...filtered.map((r) {
                      final avail = r['available'] == true;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Theme.of(context)
                                .dividerColor
                                .withOpacity(0.5),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: (avail
                                        ? TIColors.success
                                        : TIColors.danger)
                                    .withOpacity(0.14),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.bed_rounded,
                                color:
                                    avail ? TIColors.success : TIColors.danger,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r['name']?.toString() ?? 'غرفة',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14.5),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${r['bed_type'] ?? '—'} • ${r['capacity'] ?? 2} أشخاص',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context).hintColor),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${r['price_night'] ?? 0} YER / ليلة',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: TIColors.orangeDeep,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: avail,
                              activeColor: TIColors.success,
                              onChanged: (_) => _toggleAvailable(r),
                            ),
                            IconButton(
                              onPressed: () => _openForm(r),
                              icon: const Icon(Icons.edit_outlined,
                                  color: TIColors.cardRent),
                            ),
                            IconButton(
                              onPressed: () => _deleteRoom(r),
                              icon: const Icon(Icons.delete_outline,
                                  color: TIColors.danger),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}

/// ============ 4. إدارة السائقين (عرض مطور + بحث + إحصائيات) ============
class AdminDriversScreen extends StatefulWidget {
  const AdminDriversScreen({super.key});
  @override
  State<AdminDriversScreen> createState() => _AdminDriversScreenState();
}

class _AdminDriversScreenState extends State<AdminDriversScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await supabase.from('drivers').select().order('driver_id');
      if (!mounted) return;
      setState(() {
        _items = List<Map<String, dynamic>>.from(res);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _deleteDriver(Map<String, dynamic> d) async {
    if (!await _confirmDelete(context, d['full_name']?.toString() ?? 'السائق')) {
      return;
    }
    try {
      await supabase.from('drivers').delete().eq('driver_id', d['driver_id']);
      await AppState.instance?.fetchLiveCatalog();
      await logAdminAction('Delete driver #${d['driver_id']}',
          oldVal: d['full_name']?.toString());
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('فشل الحذف: $e')));
      }
    }
  }

  Future<void> _openForm([Map<String, dynamic>? item]) async {
    final name =
        TextEditingController(text: item?['full_name']?.toString() ?? '');
    final license =
        TextEditingController(text: item?['license_no']?.toString() ?? '');
    final rating =
        TextEditingController(text: item?['rating']?.toString() ?? '4.8');

    try {
      final saved = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) => Padding(
          padding: EdgeInsets.fromLTRB(
              18, 18, 18, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item == null ? 'إضافة سائق جديد' : 'تعديل بيانات السائق',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: name,
                decoration:
                    const InputDecoration(labelText: 'الاسم الكامل للسائق *'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: license,
                decoration: const InputDecoration(labelText: 'رقم الرخصة'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: rating,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'التقييم (من 5)'),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
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
                  icon: const Icon(Icons.save_rounded, size: 18),
                  label: const Text('حفظ السائق'),
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
    final avgRating = _items.isEmpty
        ? 0.0
        : _items
                .map((d) => (d['rating'] as num?)?.toDouble() ?? 4.8)
                .reduce((a, b) => a + b) /
            _items.length;

    final filtered = _items.where((d) {
      if (_query.trim().isEmpty) return true;
      final q = _query.trim().toLowerCase();
      return '${d['full_name'] ?? ''} ${d['license_no'] ?? ''}'
          .toLowerCase()
          .contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة السائقين'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('إضافة سائق'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                children: [
                  _AdminStatStrip(stats: [
                    ('إجمالي السائقين', '${_items.length}', TIColors.navy),
                    ('متوسط التقييم', '⭐ ${avgRating.toStringAsFixed(1)}',
                        TIColors.gold),
                  ]),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (v) => setState(() => _query = v),
                    decoration: const InputDecoration(
                      hintText: 'ابحث باسم السائق أو رقم الرخصة...',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (filtered.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(36),
                      child: Center(child: Text('لا يوجد سائقون مطابقون')),
                    )
                  else
                    ...filtered.map((d) => Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Theme.of(context)
                                  .dividerColor
                                  .withOpacity(0.5),
                            ),
                          ),
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: TIColors.orangeSoft,
                              child: Icon(Icons.badge_rounded,
                                  color: TIColors.orangeDeep),
                            ),
                            title: Text(
                              d['full_name']?.toString() ?? 'سائق',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            subtitle: Text(
                                'رخصة: ${d['license_no'] ?? '—'} • ⭐ ${d['rating'] ?? 4.8}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  onPressed: () => _openForm(d),
                                  icon: const Icon(Icons.edit_outlined,
                                      color: TIColors.cardRent),
                                ),
                                IconButton(
                                  onPressed: () => _deleteDriver(d),
                                  icon: const Icon(Icons.delete_outline,
                                      color: TIColors.danger),
                                ),
                              ],
                            ),
                          ),
                        )),
                ],
              ),
            ),
    );
  }
}

/// ============ 5. إدارة العروض والتخفيضات (مع تفعيل/إيقاف وبث إشعار فوري) ============
class AdminOffersScreen extends StatefulWidget {
  const AdminOffersScreen({super.key});
  @override
  State<AdminOffersScreen> createState() => _AdminOffersScreenState();
}

class _AdminOffersScreenState extends State<AdminOffersScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await supabase.from('offers').select().order('offer_id');
      if (!mounted) return;
      setState(() {
        _items = List<Map<String, dynamic>>.from(res);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> o) async {
    final next = o['active'] != true;
    try {
      await supabase
          .from('offers')
          .update({'active': next})
          .eq('offer_id', o['offer_id']);
      await AppState.instance?.fetchLiveCatalog();
      await logAdminAction('Toggle offer #${o['offer_id']} active',
          newVal: '$next');
      _load();
    } catch (_) {}
  }

  Future<void> _broadcastOffer(Map<String, dynamic> o) async {
    await AppState.instance?.sendNotification(
      targetRole: 'all',
      title: 'عرض خاص: ${o['title'] ?? ''}',
      body: '${o['subtitle'] ?? ''} (خصم ${o['discount'] ?? 10}%)',
      type: 'offer',
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال إشعار العرض لجميع العملاء ✅')),
      );
    }
  }

  Future<void> _delete(dynamic id, String title) async {
    if (!await _confirmDelete(context, title)) return;
    try {
      await supabase.from('offers').delete().eq('offer_id', id);
      await AppState.instance?.fetchLiveCatalog();
      await logAdminAction('Delete offer #$id', oldVal: title);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('فشل الحذف: $e')));
      }
    }
  }

  Future<void> _openForm([Map<String, dynamic>? item]) async {
    final title = TextEditingController(text: item?['title']?.toString() ?? '');
    final subtitle =
        TextEditingController(text: item?['subtitle']?.toString() ?? '');
    final discount =
        TextEditingController(text: item?['discount']?.toString() ?? '15');
    final imgCtrl =
        TextEditingController(text: item?['image_url']?.toString() ?? '');
    bool active = item?['active'] != false;
    bool uploading = false;

    try {
      final saved = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setS) => Padding(
            padding: EdgeInsets.fromLTRB(
                18, 18, 18, MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item == null ? 'إضافة عرض جديد' : 'تعديل العرض',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 14),
                  _AdminImagePickerSection(
                    controller: imgCtrl,
                    uploading: uploading,
                    onPick: () async {
                      setS(() => uploading = true);
                      final url = await pickAndUploadAdminImage(ctx, 'offer');
                      if (url != null) imgCtrl.text = url;
                      setS(() => uploading = false);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: title,
                    decoration:
                        const InputDecoration(labelText: 'عنوان العرض *'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: subtitle,
                    decoration: const InputDecoration(labelText: 'وصف مختصر'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: discount,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'نسبة الخصم (%)'),
                  ),
                  const SizedBox(height: 6),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('العرض نشط وظاهر للعملاء',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    value: active,
                    onChanged: (v) => setS(() => active = v),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
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
                            await AppState.instance?.sendNotification(
                              targetRole: 'all',
                              title: 'عرض جديد: ${title.text.trim()}',
                              body:
                                  '${subtitle.text.trim()} (خصم ${data['discount']}%)',
                              type: 'offer',
                            );
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
                      icon: const Icon(Icons.save_rounded, size: 18),
                      label: const Text('حفظ العرض'),
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
    final activeCount = _items.where((o) => o['active'] == true).length;
    final filtered = _items.where((o) {
      if (_filter == 'active') return o['active'] == true;
      if (_filter == 'inactive') return o['active'] != true;
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة العروض والتخفيضات'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('إضافة عرض'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                children: [
                  _AdminStatStrip(stats: [
                    ('إجمالي العروض', '${_items.length}', TIColors.navy),
                    ('عروض نشطة', '$activeCount', TIColors.success),
                    ('متوقفة', '${_items.length - activeCount}',
                        TIColors.lightSub),
                  ]),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      for (final f in const [
                        ('all', 'الكل'),
                        ('active', 'نشط'),
                        ('inactive', 'متوقف'),
                      ])
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 8),
                          child: ChoiceChip(
                            label: Text(f.$2),
                            selected: _filter == f.$1,
                            onSelected: (_) => setState(() => _filter = f.$1),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (filtered.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(36),
                      child: Center(child: Text('لا توجد عروض مطابقة')),
                    )
                  else
                    ...filtered.map((o) {
                      final isAct = o['active'] == true;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Theme.of(context)
                                .dividerColor
                                .withOpacity(0.5),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: TIColors.orangeSoft,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    'خصم ${o['discount'] ?? 10}%',
                                    style: const TextStyle(
                                      color: TIColors.orangeDeep,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Switch(
                                  value: isAct,
                                  activeColor: TIColors.success,
                                  onChanged: (_) => _toggleActive(o),
                                ),
                              ],
                            ),
                            Text(
                              o['title']?.toString() ?? 'عرض',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900, fontSize: 15.5),
                            ),
                            if ((o['subtitle'] ?? '').toString().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  o['subtitle'].toString(),
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      color: Theme.of(context).hintColor),
                                ),
                              ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _broadcastOffer(o),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(0, 36),
                                    ),
                                    icon: const Icon(Icons.campaign_outlined,
                                        size: 16),
                                    label: const Text(
                                      'إشعار العملاء بالعرض',
                                      style: TextStyle(fontSize: 11.5),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                IconButton(
                                  onPressed: () => _openForm(o),
                                  icon: const Icon(Icons.edit_outlined,
                                      color: TIColors.cardRent),
                                ),
                                IconButton(
                                  onPressed: () => _delete(o['offer_id'],
                                      o['title']?.toString() ?? 'العرض'),
                                  icon: const Icon(Icons.delete_outline,
                                      color: TIColors.danger),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}

/// ============ 6. إدارة أسعار الصرف والتسعير ============
class AdminPricingScreen extends StatefulWidget {
  const AdminPricingScreen({super.key});
  @override
  State<AdminPricingScreen> createState() => _AdminPricingScreenState();
}

class _AdminPricingScreenState extends State<AdminPricingScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _rates = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res =
          await supabase.from('exchange_rates').select().order('rate_id');
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
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'السعر الجديد'),
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
      appBar: AppBar(
        title: const Text('إدارة أسعار الصرف'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rates.isEmpty
              ? const Center(child: Text('لا توجد أسعار صرف مسجلة'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _rates.length,
                    itemBuilder: (_, i) {
                      final r = _rates[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Theme.of(context)
                                .dividerColor
                                .withOpacity(0.5),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: TIColors.orangeSoft,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.currency_exchange,
                                  color: TIColors.orangeDeep),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${r['from_cur']} → ${r['to_cur']}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 15),
                                  ),
                                  Text(
                                    'آخر تحديث: ${(r['updated_at'] ?? '—').toString().split('T').first}',
                                    style: TextStyle(
                                        fontSize: 11.5,
                                        color: Theme.of(context).hintColor),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${r['rate']}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: TIColors.orangeDeep,
                              ),
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              onPressed: () => _editRate(r),
                              icon: const Icon(Icons.edit_outlined,
                                  color: TIColors.cardRent),
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

/// ============ 7. سجل التدقيق والرقابة (مع بحث فوري وبطاقات زمنية) ============
class AdminAuditLogsScreen extends StatefulWidget {
  const AdminAuditLogsScreen({super.key});
  @override
  State<AdminAuditLogsScreen> createState() => _AdminAuditLogsScreenState();
}

class _AdminAuditLogsScreenState extends State<AdminAuditLogsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _logs = [];
  String _query = '';

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
          .limit(80);
      if (!mounted) return;
      setState(() {
        _logs = List<Map<String, dynamic>>.from(res);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _logs.where((l) {
      if (_query.trim().isEmpty) return true;
      final q = _query.trim().toLowerCase();
      return '${l['action'] ?? ''} ${l['new_value'] ?? ''} ${l['old_value'] ?? ''}'
          .toLowerCase()
          .contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل التدقيق والرقابة'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextField(
                    onChanged: (v) => setState(() => _query = v),
                    decoration: const InputDecoration(
                      hintText: 'ابحث في سجل التعديلات...',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (filtered.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(36),
                      child: Center(
                          child: Text('لا توجد عمليات مسجلة في السجل بعد')),
                    )
                  else
                    ...filtered.map((l) {
                      final oldV = l['old_value']?.toString();
                      final newV = l['new_value']?.toString();
                      final rawTime = (l['changed_at'] ?? '').toString();
                      final shortTime = rawTime.length >= 16
                          ? rawTime.substring(0, 16).replaceFirst('T', ' ')
                          : rawTime;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Theme.of(context)
                                .dividerColor
                                .withOpacity(0.5),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.history_rounded,
                                color: TIColors.orangeDeep, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l['action']?.toString() ?? 'عملية إدارية',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13.5),
                                  ),
                                  if (oldV != null || newV != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 3),
                                      child: Text(
                                        oldV != null && newV != null
                                            ? '$oldV → $newV'
                                            : (newV ?? oldV ?? ''),
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(context).hintColor),
                                      ),
                                    ),
                                  if (shortTime.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 3),
                                      child: Text(
                                        shortTime,
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Theme.of(context).hintColor),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}
