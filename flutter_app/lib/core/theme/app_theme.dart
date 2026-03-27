import "package:flutter/material.dart";

class AppTheme {
  static const Color brandBlue = Color(0xFF1F6FEB);
  static const Color brandMint = Color(0xFF22C55E);
  static const Color warningAmber = Color(0xFFF59E0B);

  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(seedColor: brandBlue, brightness: Brightness.light),
      scaffoldBackgroundColor: const Color(0xFFF6F8FB),
      cardTheme: CardThemeData(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(seedColor: brandBlue, brightness: Brightness.dark),
      scaffoldBackgroundColor: const Color(0xFF0E1217),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }
}
