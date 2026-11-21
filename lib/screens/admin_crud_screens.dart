import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase.dart';
import '../theme/app_theme.dart';

/// أداة مساعدة لرفع صورة من الجهاز إلى Supabase Storage وإرجاع رابطها العام
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

/// ============ إدارة السيارات (إضافة / تعديل / حذف + صور) ============
class AdminVehiclesScreen extends StatefulWidget {
  const AdminVehiclesScreen({super.key});

  @override
  State<AdminVehiclesScreen> createState() => _AdminVehiclesScreenState();
}

class _AdminVehiclesScreenState extends State<AdminVehiclesScreen> {
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
          .from('vehicles')
          .select()
          .order('vehicle_id', ascending: false);
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

  Future<void> _delete(int id) async {
    try {
      await supabase.from('vehicles').delete().eq('vehicle_id', id);
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
                        labelText: 'اسم السيارة', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: year,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'السنة', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: seats,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'المقاعد',
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
                          if (imgCtrl.text.trim().isNotEmpty)
                            'image_url': imgCtrl.text.trim(),
                        };
                        try {
                          if (item == null) {
                            await supabase.from('vehicles').insert(data);
                          } else {
                            await supabase
                                .from('vehicles')
                                .update(data)
                                .eq('vehicle_id', item['vehicle_id']);
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
                            '${v['year'] ?? ''} • ${v['full_price'] ?? 0} YER • ${v['status'] ?? ''}'),
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
                              onPressed: () =>
                                  _delete(v['vehicle_id'] as int),
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

/// ============ إدارة الفنادق (إضافة / تعديل / حذف + صور) ============
class AdminHotelsScreen extends StatefulWidget {
  const AdminHotelsScreen({super.key});

  @override
  State<AdminHotelsScreen> createState() => _AdminHotelsScreenState();
}

class _AdminHotelsScreenState extends State<AdminHotelsScreen> {
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
          .from('hotels')
          .select()
          .order('hotel_id', ascending: false);
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

  Future<void> _delete(int id) async {
    try {
      await supabase.from('hotels').delete().eq('hotel_id', id);
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
    final imgCtrl =
        TextEditingController(text: item?['image_url']?.toString() ?? '');
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
                        final data = {
                          'name_ar': name.text.trim(),
                          'rating': double.tryParse(rating.text.trim()) ?? 4.5,
                          'verified': verified,
                          if (imgCtrl.text.trim().isNotEmpty)
                            'image_url': imgCtrl.text.trim(),
                        };
                        try {
                          if (item == null) {
                            await supabase.from('hotels').insert(data);
                          } else {
                            await supabase
                                .from('hotels')
                                .update(data)
                                .eq('hotel_id', item['hotel_id']);
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
      imgCtrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة الفنادق')),
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
                        subtitle: Text('⭐ ${h['rating'] ?? 4.5}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: TIColors.teal),
                              onPressed: () => _openForm(h),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete,
                                  color: TIColors.danger),
                              onPressed: () => _delete(h['hotel_id'] as int),
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

/// ============ إدارة العروض (إضافة / تعديل / حذف + صور) ============
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

  Future<void> _delete(int id) async {
    try {
      await supabase.from('offers').delete().eq('offer_id', id);
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
                        final data = {
                          'title': title.text.trim(),
                          'subtitle': subtitle.text.trim(),
                          'discount': int.tryParse(discount.text.trim()) ?? 10,
                          'active': active,
                          if (imgCtrl.text.trim().isNotEmpty)
                            'image_url': imgCtrl.text.trim(),
                        };
                        try {
                          if (item == null) {
                            await supabase.from('offers').insert(data);
                          } else {
                            await supabase
                                .from('offers')
                                .update(data)
                                .eq('offer_id', item['offer_id']);
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
                              onPressed: () => _delete(o['offer_id'] as int),
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
