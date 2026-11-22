import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../state/app_state.dart';
import '../data/models.dart';
import '../supabase.dart';
import '../theme/app_theme.dart';
import 'main_shell.dart';
import 'developer_dashboard.dart';

/// ===== شاشة اختيار نوع المستخدم =====
class UserTypeScreen extends StatelessWidget {
  const UserTypeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return Scaffold(
      appBar: Navigator.of(context).canPop()
          ? AppBar(backgroundColor: Colors.transparent, elevation: 0)
          : null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Text(l.t('whoUses'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(l.t('whoHint'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).hintColor)),
              const SizedBox(height: 36),
              _UserTypeCard(
                icon: Icons.person,
                title: l.t('customer'),
                desc: l.t('customerDesc'),
                gold: false,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const PhoneLoginScreen())),
              ),
              const SizedBox(height: 16),
              _UserTypeCard(
                icon: Icons.admin_panel_settings,
                title: l.t('developer'),
                desc: l.t('developerDesc'),
                gold: true,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const DeveloperLoginScreen())),
              ),
              const Spacer(),
              Text(l.t('demoNote'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 11, color: Theme.of(context).hintColor)),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserTypeCard extends StatelessWidget {
  final IconData icon;
  final String title, desc;
  final bool gold;
  final VoidCallback onTap;

  const _UserTypeCard({
    required this.icon,
    required this.title,
    required this.desc,
    required this.gold,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: gold ? TIColors.gold : Theme.of(context).dividerColor,
              width: gold ? 1.5 : 1),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(isDark ? .3 : .06),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(children: [
          CircleAvatar(
            radius: 28,
            backgroundColor:
                (gold ? TIColors.gold : TIColors.teal).withOpacity(.15),
            child: Icon(icon,
                color: gold ? TIColors.gold : TIColors.teal, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(desc,
                      style: TextStyle(
                          fontSize: 13, color: Theme.of(context).hintColor)),
                ]),
          ),
          const Icon(Icons.chevron_right),
        ]),
      ),
    );
  }
}

/// ===== دخول وتسجيل العميل: البريد + كلمة مرور (OTP مرة واحدة عند التسجيل أو عند نسيان الرمز) =====
class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});
  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

enum _EmailFlow { signIn, signUp, forgot }

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _newPass = TextEditingController();
  final _otp = TextEditingController();

  bool _emailMode = true;
  _EmailFlow _flow = _EmailFlow.signIn;
  bool _awaitingOtp = false;
  bool _busy = false;

  Future<void> _routeCustomerByEmail(String email) async {
    try {
      final existing = await supabase
          .from('users')
          .select()
          .eq('email', email)
          .maybeSingle();
      if (existing != null && mounted) {
        context.read<AppState>().login(AppUser(
              id: existing['user_id'].toString(),
              firstName: existing['first_name']?.toString() ?? '',
              secondName: existing['second_name']?.toString() ?? '',
              age: (existing['age'] as num?)?.toInt() ?? 20,
              phone: existing['phone']?.toString(),
              email: existing['email']?.toString(),
              role: existing['role']?.toString() ?? 'customer',
              demo: false,
            ));
        Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const MainShell()), (r) => false);
        return;
      }
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => ProfileSetupScreen(email: email)),
    );
  }

  /// تسجيل دخول العميل بالبريد وكلمة المرور (بدون OTP)
  Future<void> _customerSignIn() async {
    final l = context.l;
    final email = _email.text.trim().toLowerCase();
    final pass = _pass.text.trim();
    if (!email.contains('@') || pass.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.isArabic
              ? 'أدخل بريداً صحيحاً وكلمة مرور (6 أحرف فأكثر)'
              : 'Enter valid email and password (6+ chars)'),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await supabase.auth.signInWithPassword(email: email, password: pass);
      if (!mounted) return;
      await _routeCustomerByEmail(email);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.isArabic
              ? 'البريد أو كلمة المرور غير صحيحة (أو لم يتم تأكيد الحساب بعد)'
              : 'Invalid email or password'),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// إنشاء حساب عميل جديد بالبريد وكلمة المرور + إرسال OTP مرة واحدة
  Future<void> _customerSignUp() async {
    final l = context.l;
    final email = _email.text.trim().toLowerCase();
    final pass = _pass.text.trim();
    if (!email.contains('@') || pass.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.isArabic
              ? 'أدخل بريداً صحيحاً وكلمة مرور (6 أحرف فأكثر)'
              : 'Enter valid email and password (6+ chars)'),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await supabase.auth.signUp(email: email, password: pass);
      if (!mounted) return;
      setState(() => _awaitingOtp = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.isArabic
              ? 'تم إرسال رمز التحقق (OTP) إلى بريدك الإلكتروني لتأكيد الحساب'
              : 'Verification OTP sent to your email'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.isArabic
              ? 'تعذّر إنشاء الحساب: $e'
              : 'Sign up failed: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// تأكيد OTP لأول مرة بعد إنشاء الحساب
  Future<void> _verifySignUpOtp() async {
    final l = context.l;
    final email = _email.text.trim().toLowerCase();
    final code = _otp.text.trim();
    if (code.length < 6) return;
    setState(() => _busy = true);
    try {
      await supabase.auth.verifyOTP(
        email: email,
        token: code,
        type: OtpType.signup,
      );
      if (!mounted) return;
      await _routeCustomerByEmail(email);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.isArabic
              ? 'رمز التحقق غير صحيح أو منتهي الصلاحية'
              : 'Invalid or expired OTP code'),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// نسيان كلمة المرور: إرسال OTP لإعادة التعيين
  Future<void> _sendResetOtp() async {
    final l = context.l;
    final email = _email.text.trim().toLowerCase();
    if (!email.contains('@')) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.t('errEmail'))));
      return;
    }
    setState(() => _busy = true);
    try {
      await supabase.auth.resetPasswordForEmail(email);
      if (!mounted) return;
      setState(() => _awaitingOtp = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.isArabic
              ? 'تم إرسال رمز استعادة كلمة المرور (OTP) إلى بريدك'
              : 'Password reset OTP sent to your email'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// تأكيد OTP وتعيين كلمة المرور الجديدة
  Future<void> _confirmPasswordReset() async {
    final l = context.l;
    final email = _email.text.trim().toLowerCase();
    final code = _otp.text.trim();
    final newPw = _newPass.text.trim();
    if (code.length < 6 || newPw.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.isArabic
              ? 'أدخل رمز التحقق وكلمة مرور جديدة (6 أحرف فأكثر)'
              : 'Enter OTP code and new password (6+ chars)'),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await supabase.auth.verifyOTP(
        email: email,
        token: code,
        type: OtpType.recovery,
      );
      await supabase.auth.updateUser(UserAttributes(password: newPw));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.isArabic
              ? 'تم تحديث كلمة المرور بنجاح ✅'
              : 'Password updated successfully'),
        ),
      );
      await _routeCustomerByEmail(email);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.isArabic
              ? 'رمز الاستعادة غير صحيح أو منتهي الصلاحية'
              : 'Invalid or expired reset code'),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// دخول سريع برقم الهاتف (خيار بديل)
  Future<void> _phoneLogin() async {
    final l = context.l;
    final phone = _phone.text.trim();
    if (phone.length < 9) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.t('errPhone'))));
      return;
    }
    try {
      final existing = await supabase
          .from('users')
          .select()
          .eq('phone', phone)
          .maybeSingle();
      if (existing != null && mounted) {
        context.read<AppState>().login(AppUser(
              id: existing['user_id'].toString(),
              firstName: existing['first_name']?.toString() ?? '',
              secondName: existing['second_name']?.toString() ?? '',
              age: (existing['age'] as num?)?.toInt() ?? 20,
              phone: existing['phone']?.toString(),
              email: existing['email']?.toString(),
              role: existing['role']?.toString() ?? 'customer',
              demo: false,
            ));
        Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const MainShell()), (r) => false);
        return;
      }
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ProfileSetupScreen(phone: phone)));
  }

  @override
  void dispose() {
    _phone.dispose();
    _email.dispose();
    _pass.dispose();
    _newPass.dispose();
    _otp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final ar = l.isArabic;
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _logo(),
            const SizedBox(height: 24),
            if (_emailMode) ...[
              // تبديل بين تسجيل الدخول وإنشاء حساب جديد
              if (_flow != _EmailFlow.forgot)
                SegmentedButton<_EmailFlow>(
                  segments: [
                    ButtonSegment(
                      value: _EmailFlow.signIn,
                      label: Text(ar ? 'تسجيل الدخول' : 'Sign In'),
                    ),
                    ButtonSegment(
                      value: _EmailFlow.signUp,
                      label: Text(ar ? 'حساب جديد' : 'Create Account'),
                    ),
                  ],
                  selected: {_flow},
                  onSelectionChanged: (s) => setState(() {
                    _flow = s.first;
                    _awaitingOtp = false;
                    _otp.clear();
                  }),
                ),
              const SizedBox(height: 18),
              TextField(
                controller: _email,
                enabled: !_awaitingOtp,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: l.t('email'),
                  hintText: 'name@example.com',
                  prefixIcon: const Icon(Icons.mail_outline),
                ),
              ),
              const SizedBox(height: 14),
              if (_flow == _EmailFlow.signIn) ...[
                TextField(
                  controller: _pass,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: l.t('password'),
                    prefixIcon: const Icon(Icons.lock_outline),
                  ),
                ),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(
                    onPressed: () => setState(() {
                      _flow = _EmailFlow.forgot;
                      _awaitingOtp = false;
                      _otp.clear();
                    }),
                    child: Text(ar ? 'نسيت كلمة المرور؟' : 'Forgot password?'),
                  ),
                ),
                const SizedBox(height: 6),
                ElevatedButton(
                  onPressed: _busy ? null : _customerSignIn,
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(l.t('login')),
                ),
              ] else if (_flow == _EmailFlow.signUp) ...[
                if (!_awaitingOtp) ...[
                  TextField(
                    controller: _pass,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: ar
                          ? 'كلمة مرور الحساب (6 أحرف فأكثر)'
                          : 'Account Password (6+ chars)',
                      prefixIcon: const Icon(Icons.lock_outline),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _busy ? null : _customerSignUp,
                    icon: const Icon(Icons.mark_email_read_outlined, size: 18),
                    label: Text(ar
                        ? 'إنشاء الحساب وإرسال رمز التحقق (OTP)'
                        : 'Sign Up & Send OTP'),
                  ),
                ] else ...[
                  TextField(
                    controller: _otp,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 8,
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 5),
                    decoration: InputDecoration(
                      labelText: ar ? 'رمز التحقق (OTP)' : 'OTP Code',
                      prefixIcon: const Icon(Icons.verified_user_outlined),
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    onPressed: _busy ? null : _verifySignUpOtp,
                    child: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text(ar ? 'تأكيد الحساب والدخول' : 'Verify & Continue'),
                  ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() => _awaitingOtp = false),
                    child: Text(ar ? 'تعديل البيانات' : 'Edit Details'),
                  ),
                ],
              ] else ...[
                // تدفق نسيان كلمة المرور (OTP + كلمة مرور جديدة)
                if (!_awaitingOtp) ...[
                  ElevatedButton.icon(
                    onPressed: _busy ? null : _sendResetOtp,
                    icon: const Icon(Icons.lock_reset_rounded, size: 18),
                    label: Text(ar
                        ? 'إرسال رمز استعادة كلمة المرور (OTP)'
                        : 'Send Reset OTP'),
                  ),
                ] else ...[
                  TextField(
                    controller: _otp,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 8,
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 5),
                    decoration: InputDecoration(
                      labelText: ar ? 'رمز الاستعادة (OTP)' : 'Reset OTP',
                      prefixIcon: const Icon(Icons.verified_user_outlined),
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _newPass,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: ar ? 'كلمة المرور الجديدة' : 'New Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                    ),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    onPressed: _busy ? null : _confirmPasswordReset,
                    child: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text(ar
                            ? 'تعيين كلمة المرور والدخول'
                            : 'Reset Password & Sign In'),
                  ),
                ],
                TextButton(
                  onPressed: () => setState(() {
                    _flow = _EmailFlow.signIn;
                    _awaitingOtp = false;
                  }),
                  child: Text(ar ? 'العودة لتسجيل الدخول' : 'Back to Sign In'),
                ),
              ],
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () => setState(() => _emailMode = false),
                icon: const Icon(Icons.phone),
                label: Text(l.t('phoneLogin')),
              ),
            ] else ...[
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: l.t('phone'),
                  prefixIcon: const Icon(Icons.phone),
                  hintText: '77x xxx xxx',
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _phoneLogin,
                child: Text(l.t('login')),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => setState(() => _emailMode = true),
                icon: const Icon(Icons.mail_outline),
                label: Text(l.t('emailLogin')),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _logo() => Column(children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [TIColors.orange, TIColors.orangeDeep]),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: TIColors.gold, width: 1.5),
          ),
          child: const Icon(Icons.flight_takeoff,
              color: TIColors.gold, size: 42),
        ),
        const SizedBox(height: 12),
        const Text('Travixo',
            style: TextStyle(
                fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
      ]);
}

/// ===== دخول المطور بالبريد وكلمة المرور مباشرة (بدون OTP) =====
class DeveloperLoginScreen extends StatefulWidget {
  const DeveloperLoginScreen({super.key});
  @override
  State<DeveloperLoginScreen> createState() => _DeveloperLoginScreenState();
}

class _DeveloperLoginScreenState extends State<DeveloperLoginScreen> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _loading = false;

  Future<void> _login() async {
    final l = context.l;
    final email = _user.text.trim().toLowerCase();
    final password = _pass.text.trim();
    if (!email.contains('@') || password.length < 6) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.t('errEmail'))));
      return;
    }

    setState(() => _loading = true);
    try {
      // 1) التحقق أولاً من المطورين المضافين/المعدّلين عبر لوحة الإدارة (users.password_code)
      try {
        final row = await supabase
            .from('users')
            .select()
            .eq('email', email)
            .maybeSingle();
        if (row != null) {
          final role = row['role']?.toString() ?? '';
          final savedPw = row['password_code']?.toString() ?? '';
          if ((role == 'developer' || role == 'super_admin') &&
              savedPw.isNotEmpty &&
              savedPw == password) {
            if (!mounted) return;
            context.read<AppState>().login(AppUser(
                  id: row['user_id'].toString(),
                  firstName: row['first_name']?.toString() ?? 'Admin',
                  secondName: row['second_name']?.toString() ?? '',
                  age: (row['age'] as num?)?.toInt() ?? 25,
                  email: email,
                  phone: row['phone']?.toString(),
                  role: 'developer',
                  demo: false,
                ));
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const DeveloperDashboard()),
              (r) => false,
            );
            return;
          }
        }
      } catch (_) {}

      // 2) الدخول عبر حساب المطور الأساسي في Supabase Auth
      final res = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final authUser = res.user;
      if (authUser == null) throw Exception('Auth failed');

      String firstName =
          authUser.userMetadata?['first_name']?.toString() ?? 'Admin';
      String secondName =
          authUser.userMetadata?['second_name']?.toString() ?? '';
      String role = authUser.userMetadata?['role']?.toString() ?? 'developer';

      try {
        final row = await supabase
            .from('users')
            .select()
            .eq('email', email)
            .maybeSingle();
        if (row != null) {
          firstName = row['first_name']?.toString() ?? firstName;
          secondName = row['second_name']?.toString() ?? secondName;
          role = row['role']?.toString() ?? role;
        }
      } catch (_) {}

      if (role != 'developer' && role != 'super_admin') {
        await supabase.auth.signOut();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.isArabic
                ? 'هذا الحساب لا يملك صلاحية المطور'
                : 'This account does not have developer access'),
          ),
        );
        return;
      }

      if (!mounted) return;
      context.read<AppState>().login(AppUser(
            id: authUser.id,
            firstName: firstName,
            secondName: secondName,
            age: 25,
            email: authUser.email,
            role: 'developer',
            demo: false,
          ));

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const DeveloperDashboard()),
        (r) => false,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.isArabic
              ? 'البريد الإلكتروني أو كلمة المرور غير صحيحة'
              : 'Invalid email or password'),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return Scaffold(
      appBar: AppBar(title: Text(l.t('developer'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Icon(Icons.admin_panel_settings,
                size: 72, color: TIColors.gold),
            const SizedBox(height: 24),
            TextField(
              controller: _user,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: l.t('email'),
                prefixIcon: const Icon(Icons.mail_outline),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _pass,
              obscureText: true,
              decoration: InputDecoration(
                labelText: l.t('password'),
                prefixIcon: const Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loading ? null : _login,
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(l.t('login')),
            ),
          ],
        ),
      ),
    );
  }
}

/// ===== إكمال الملف الشخصي: الاسم الأول والثاني والعمر =====
class ProfileSetupScreen extends StatefulWidget {
  final String? phone, email;
  final bool isDeveloper;
  const ProfileSetupScreen(
      {super.key, this.phone, this.email, this.isDeveloper = false});
  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _form = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _second = TextEditingController();
  final _age = TextEditingController();
  String _currency = 'YER';
  bool _saving = false;

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    final firstName = _first.text.trim();
    final secondName = _second.text.trim();
    final age = int.parse(_age.text.trim());
    final role = widget.isDeveloper ? 'developer' : 'customer';
    String userId = 'U${DateTime.now().millisecondsSinceEpoch}';
    bool isDemo = true;

    try {
      final inserted = await supabase
          .from('users')
          .insert({
            'first_name': firstName,
            'second_name': secondName,
            'age': age,
            if (widget.phone != null && widget.phone!.isNotEmpty)
              'phone': widget.phone,
            if (widget.email != null && widget.email!.isNotEmpty)
              'email': widget.email,
            'role': role,
            'membership': 'basic',
          })
          .select()
          .single();
      userId = inserted['user_id'].toString();
      isDemo = false;

      // إنشاء محفظة للمستخدم في قاعدة البيانات
      await supabase.from('wallets').insert({
        'user_id': inserted['user_id'],
        'balance': 100000,
        'currency': _currency,
      });
    } catch (_) {}

    if (!mounted) return;
    final state = context.read<AppState>();
    state.setCurrency(_currency);
    state.login(AppUser(
      id: userId,
      firstName: firstName,
      secondName: secondName,
      age: age,
      phone: widget.phone,
      email: widget.email,
      role: role,
      demo: isDemo,
    ));

    if (widget.isDeveloper) {
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const DeveloperDashboard()),
          (r) => false);
    } else {
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainShell()), (r) => false);
    }
  }

  @override
  void dispose() {
    _first.dispose();
    _second.dispose();
    _age.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(l.t('completeProfile'),
              style:
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(l.t('profileHint'),
              style: TextStyle(color: Theme.of(context).hintColor)),
          const SizedBox(height: 28),
          Form(
            key: _form,
            child: Column(children: [
              TextFormField(
                controller: _first,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                    labelText: l.t('firstName'),
                    prefixIcon: const Icon(Icons.person_outline)),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? l.t('errRequired') : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _second,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                    labelText: l.t('secondName'),
                    prefixIcon: const Icon(Icons.person_outline)),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? l.t('errRequired') : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _age,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                    labelText: l.t('age'),
                    prefixIcon: const Icon(Icons.cake_outlined)),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  return (n == null || n < 10 || n > 100)
                      ? l.t('errAge')
                      : null;
                },
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: _currency,
                decoration: InputDecoration(
                    labelText: l.t('prefCurrency'),
                    prefixIcon: const Icon(Icons.currency_exchange)),
                items: const [
                  DropdownMenuItem(value: 'YER', child: Text('YER — ريال يمني')),
                  DropdownMenuItem(value: 'USD', child: Text('USD — Dollar')),
                  DropdownMenuItem(value: 'SAR', child: Text('SAR — ريال سعودي')),
                ],
                onChanged: (v) => setState(() => _currency = v ?? 'YER'),
              ),
            ]),
          ),
          const SizedBox(height: 28),
          ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(l.t('saveContinue'))),
        ],
      ),
    );
  }
}
