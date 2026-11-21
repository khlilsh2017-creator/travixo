// نظام الألوان والثيمين — Travixo Advanced UI Theme (مستوحى من travixo.html)
import 'package:flutter/material.dart';

class TIColors {
  // ألوان الهوية الأساسية — Brand Orange Palette
  static const Color orange = Color(0xFFF97316); // brand-500
  static const Color orangeDeep = Color(0xFFEA580C); // brand-600
  static const Color orangeDark = Color(0xFFC2410C); // brand-700
  static const Color orangeSoft = Color(0xFFFFEDD5); // brand-100
  static const Color orangeTint = Color(0xFFFFF7ED); // brand-50

  // الأسماء الموروثة وقيمها المتوافقة مع الهوية
  static const Color navy = Color(0xFF0F172A); // slate-900
  static const Color navyDark = Color(0xFF020617); // slate-950
  static const Color gold = Color(0xFFF59E0B); // amber-500
  static const Color teal = Color(0xFFEA580C); // brand-600
  static const Color softGray = Color(0xFFFFFBF7); // cream
  static const Color danger = Color(0xFFE11D48); // rose-600
  static const Color success = Color(0xFF10B981); // emerald-500
  static const Color warning = Color(0xFFF59E0B); // amber-500

  // أسطح الوضع النهاري
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightText = Color(0xFF1E293B); // slate-800
  static const Color lightSub = Color(0xFF64748B); // slate-500
  static const Color lightLine = Color(0xFFFED7AA); // brand-200 subtle border

  // أسطح الوضع الليلي
  static const Color darkCard = Color(0xFF0F172A); // slate-900
  static const Color darkText = Color(0xFFF1F5F9); // slate-100
  static const Color darkSub = Color(0xFF94A3B8); // slate-400
  static const Color darkLine = Color(0xFF1E293B); // slate-800

  // ألوان البطاقات الثماني
  static const Color cardTrips = Color(0xFFF97316);
  static const Color cardRent = Color(0xFF2563EB);
  static const Color cardHotels = Color(0xFF059669);
  static const Color cardPlans = Color(0xFF9333EA);
  static const Color cardResorts = Color(0xFF0D9488);
  static const Color cardPlaces = Color(0xFFD97706);
  static const Color cardMap = Color(0xFFE11D48);
  static const Color cardAssistant = Color(0xFF4F46E5);
  static const Color onCard = Color(0xFFFFFFFF);
}

class TIRadius {
  static const double small = 12;
  static const double medium = 18;
  static const double large = 24;
  static const double card = medium;
  static const double sheet = large;
  static const double l = large;
}

class TravixoFX {
  static const LinearGradient orange = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [TIColors.orange, TIColors.orangeDeep],
  );

  static const LinearGradient splash = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [TIColors.orange, TIColors.orangeDark],
  );

  static LinearGradient soft(Color c) => LinearGradient(
        colors: [c.withOpacity(0.82), c],
      );

  static BoxShadow shadow(Color c) => BoxShadow(
        color: c.withOpacity(0.14),
        blurRadius: 16,
        offset: const Offset(0, 6),
      );
}

class AppTheme {
  static ThemeData get light => build(false);
  static ThemeData get dark => build(true);

  static ThemeData build(bool isDark) {
    final bg = isDark ? TIColors.navyDark : TIColors.softGray;
    final card = isDark ? TIColors.darkCard : TIColors.lightCard;
    final text = isDark ? TIColors.darkText : TIColors.lightText;
    final sub = isDark ? TIColors.darkSub : TIColors.lightSub;
    final line = isDark ? TIColors.darkLine : const Color(0xFFE2E8F0);

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: TIColors.orange,
        brightness: isDark ? Brightness.dark : Brightness.light,
        primary: TIColors.orangeDeep,
        onPrimary: Colors.white,
        secondary: TIColors.orange,
        surface: bg,
        error: TIColors.danger,
      ),
      scaffoldBackgroundColor: bg,
      dividerColor: line,
      hintColor: sub,
      cardColor: card,
      appBarTheme: AppBarTheme(
        backgroundColor: card.withOpacity(0.92),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: text,
          fontSize: 19,
          fontWeight: FontWeight.w800,
        ),
        iconTheme: IconThemeData(color: text),
      ),
      cardTheme: CardTheme(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TIRadius.card),
          side: BorderSide(color: line),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: TIColors.orangeDeep,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: TIColors.orangeDeep,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: TIColors.orangeDeep,
          side: const BorderSide(color: TIColors.orangeDeep, width: 1.4),
          minimumSize: const Size(64, 42),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: TIColors.orangeDeep,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: TIColors.orange, width: 1.6),
        ),
        hintStyle: TextStyle(color: sub, fontSize: 14),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: card,
        selectedItemColor: TIColors.orangeDeep,
        unselectedItemColor: sub,
        type: BottomNavigationBarType.fixed,
      ),
      textTheme: TextTheme(
        headlineLarge: TextStyle(
          color: text,
          fontSize: 28,
          fontWeight: FontWeight.w900,
        ),
        headlineMedium: TextStyle(
          color: text,
          fontSize: 24,
          fontWeight: FontWeight.w800,
        ),
        titleLarge: TextStyle(
          color: text,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
        titleMedium: TextStyle(
          color: text,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: TextStyle(color: text, fontSize: 15),
        bodyMedium: TextStyle(color: text, fontSize: 14),
        bodySmall: TextStyle(color: sub, fontSize: 12),
      ),
    );
  }
}
