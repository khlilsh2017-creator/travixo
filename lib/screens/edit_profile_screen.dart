import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../l10n/app_localizations.dart';

/// شاشة تعديل البيانات الشخصية — الاسم والبريد والرقم
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _second = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      final user = context.read<AppState>().user;
      _first.text = user?.firstName ?? '';
      _second.text = user?.secondName ?? '';
      _email.text = user?.email ?? '';
      _phone.text = user?.phone ?? '';
      _loaded = true;
    }
  }

  void _save() {
    if (!(_form.currentState?.validate() ?? false)) return;
    final state = context.read<AppState>();
    if (state.user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l.t('errRequired'))),
      );
      return;
    }
    state.updateProfile(
      firstName: _first.text.trim(),
      secondName: _second.text.trim(),
      email: _email.text.trim().isEmpty ? null : _email.text.trim(),
      phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l.t('savedOk'))),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return Scaffold(
      appBar: AppBar(title: Text(l.t('editProfileTitle'))),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _first,
              decoration: InputDecoration(
                labelText: l.t('firstName'),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.person_outline),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? l.t('errRequired') : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _second,
              decoration: InputDecoration(
                labelText: l.t('secondName'),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.person_outline),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? l.t('errRequired') : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: l.t('email'),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.email_outlined),
              ),
              validator: (v) {
                final val = v?.trim() ?? '';
                if (val.isNotEmpty && !val.contains('@')) {
                  return l.t('errEmail');
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: l.t('mobile'),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: Text(l.t('saveEdits')),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _first.dispose();
    _second.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }
}
