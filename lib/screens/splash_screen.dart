// شاشة البداية السينمائية — Travixo Assembling Logo Splash Screen
// يتجمّع الشعار من 4 أجزاء + حلقة مضيئة + بريق ضوئي + تجميع حروف TRAVIXO
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'developer_dashboard.dart';
import 'main_shell.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _assemble;
  late final Animation<double> _ringSweep;
  late final Animation<double> _shimmer;
  late final Animation<double> _tagline;

  static const _letters = ['T', 'R', 'A', 'V', 'I', 'X', 'O'];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    // 1) تجميع أجزاء الشعار الأربعة نحو المركز
    _assemble = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.52, curve: Curves.easeOutBack),
    );

    // 2) رسم الحلقة المضيئة حول الشعار لحظة الالتحام
    _ringSweep = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.38, 0.72, curve: Curves.easeInOutCubic),
    );

    // 3) بريق ضوئي يمر فوق الشعار بعد التجميع
    _shimmer = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.52, 0.80, curve: Curves.easeInOut),
    );

    // 4) ظهور الشعار اللفظي
    _tagline = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.74, 0.96, curve: Curves.easeOut),
    );

    _ctrl.forward();

    Future.delayed(const Duration(milliseconds: 3000), _navigateToNextScreen);
  }

  void _navigateToNextScreen() {
    if (!mounted) return;
    final state = context.read<AppState>();
    final Widget nextPage = !state.hasSeenOnboarding
        ? const OnboardingScreen()
        : (state.user?.role == 'developer'
            ? const DeveloperDashboard()
            : const MainShell());

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => nextPage,
        transitionDuration: const Duration(milliseconds: 550),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  Widget _logoImage(double size) {
    return Image.asset(
      'logo.png.jpg',
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        width: size,
        height: size,
        color: Colors.white,
        child: const Center(
          child: Icon(Icons.travel_explore, size: 96, color: TIColors.orange),
        ),
      ),
    );
  }

  /// بناء ربع واحد من الشعار مع حركته من زاويته إلى المركز
  Widget _buildQuadrant({
    required double size,
    required Alignment alignment,
    required Offset startOffset,
    required double startAngle,
    required double progress,
  }) {
    final t = progress.clamp(0.0, 1.0);
    final inv = 1.0 - progress; // يسمح بـ overshoot لطيف من easeOutBack
    final dx = startOffset.dx * inv;
    final dy = startOffset.dy * inv;
    final angle = startAngle * inv;
    final half = size / 2;

    return Positioned(
      left: alignment.x < 0 ? 0 : half,
      top: alignment.y < 0 ? 0 : half,
      width: half,
      height: half,
      child: Transform.translate(
        offset: Offset(dx, dy),
        child: Transform.rotate(
          angle: angle,
          child: Opacity(
            opacity: (t * 1.4).clamp(0.0, 1.0),
            child: ClipRect(
              child: OverflowBox(
                alignment: alignment,
                minWidth: size,
                maxWidth: size,
                minHeight: size,
                maxHeight: size,
                child: _logoImage(size),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const double logoSize = 196;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              TIColors.navyDark,
              TIColors.navy,
              TIColors.orangeDark,
            ],
          ),
        ),
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            final p = _assemble.value;
            final merged = p >= 0.96;

            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),

                // الشعار المتجمّع + الحلقة المضيئة + البريق
                SizedBox(
                  width: logoSize + 36,
                  height: logoSize + 36,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // توهج خلفي ناعم عند اكتمال التجميع
                      Container(
                        width: logoSize + 18,
                        height: logoSize + 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: TIColors.orange
                                  .withOpacity(0.38 * _ringSweep.value),
                              blurRadius: 42,
                              spreadRadius: 6,
                            ),
                          ],
                        ),
                      ),

                      // حلقة مضيئة تُرسَم حول الشعار
                      CustomPaint(
                        size: const Size(logoSize + 24, logoSize + 24),
                        painter: _RingArcPainter(
                          progress: _ringSweep.value,
                          color: TIColors.orange,
                          accent: TIColors.gold,
                        ),
                      ),

                      // حاوية الشعار الدائرية
                      Container(
                        width: logoSize,
                        height: logoSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(
                            (p.clamp(0.0, 1.0) * 0.95).clamp(0.0, 1.0),
                          ),
                        ),
                        child: ClipOval(
                          child: Stack(
                            children: [
                              if (merged)
                                _logoImage(logoSize)
                              else ...[
                                _buildQuadrant(
                                  size: logoSize,
                                  alignment: Alignment.topLeft,
                                  startOffset: const Offset(-72, -72),
                                  startAngle: -0.32,
                                  progress: p,
                                ),
                                _buildQuadrant(
                                  size: logoSize,
                                  alignment: Alignment.topRight,
                                  startOffset: const Offset(72, -72),
                                  startAngle: 0.32,
                                  progress: p,
                                ),
                                _buildQuadrant(
                                  size: logoSize,
                                  alignment: Alignment.bottomLeft,
                                  startOffset: const Offset(-72, 72),
                                  startAngle: 0.28,
                                  progress: p,
                                ),
                                _buildQuadrant(
                                  size: logoSize,
                                  alignment: Alignment.bottomRight,
                                  startOffset: const Offset(72, 72),
                                  startAngle: -0.28,
                                  progress: p,
                                ),
                              ],

                              // وميض ضوئي مائل يمر فوق الشعار عند الالتحام
                              if (_shimmer.value > 0 && _shimmer.value < 1)
                                Transform.translate(
                                  offset: Offset(
                                    (_shimmer.value * 2 - 1) * logoSize * 1.4,
                                    0,
                                  ),
                                  child: Transform.rotate(
                                    angle: 0.45,
                                    child: Container(
                                      width: 48,
                                      height: logoSize * 1.5,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.white.withOpacity(0.0),
                                            Colors.white.withOpacity(0.55),
                                            Colors.white.withOpacity(0.0),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // تجميع حروف TRAVIXO حرفاً بحرف من الأطراف
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(_letters.length, (i) {
                      final start = 0.48 + (i * 0.045);
                      final end = (start + 0.22).clamp(0.0, 1.0);
                      final t = Curves.easeOutCubic.transform(
                        ((_ctrl.value - start) / (end - start)).clamp(0.0, 1.0),
                      );
                      final fromX = (i - 3) * 18.0 * (1.0 - t);
                      final fromY = (i.isEven ? -14.0 : 14.0) * (1.0 - t);

                      return Transform.translate(
                        offset: Offset(fromX, fromY),
                        child: Opacity(
                          opacity: t,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2.5),
                            child: Text(
                              _letters[i],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                const SizedBox(height: 10),

                // الشعار اللفظي
                Transform.translate(
                  offset: Offset(0, 14 * (1.0 - _tagline.value)),
                  child: Opacity(
                    opacity: _tagline.value,
                    child: Text(
                      'شريكك الذكي للسفر في اليمن',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.88),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const Spacer(flex: 3),

                // شريط تقدم سفلي ناعم
                Padding(
                  padding: const EdgeInsets.only(bottom: 42),
                  child: SizedBox(
                    width: 110,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: _ctrl.value,
                        minHeight: 4,
                        backgroundColor: Colors.white.withOpacity(0.16),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          TIColors.orange,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
}

class _RingArcPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color accent;
  const _RingArcPainter({
    required this.progress,
    required this.color,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final rect = Rect.fromLTWH(4, 4, size.width - 8, size.height - 8);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [color, accent, color],
      ).createShader(rect);

    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * progress.clamp(0.0, 1.0),
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingArcPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
