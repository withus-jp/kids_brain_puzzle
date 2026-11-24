import 'package:flutter/material.dart';

/// 아이 친화적인 파스텔 톤 색상 모음.
abstract final class AppColors {
  static const background = Color(0xFFFFF8EE);
  static const primary = Color(0xFF7C6CF2);
  static const textDark = Color(0xFF3D3553);
  static const textSoft = Color(0xFF7A7290);

  static const pastelPink = Color(0xFFFFD6E0);
  static const pastelMint = Color(0xFFC8F2DC);
  static const pastelSky = Color(0xFFCDE7FF);
  static const pastelLemon = Color(0xFFFFF1B8);
  static const pastelLavender = Color(0xFFE4DBFF);
  static const pastelGray = Color(0xFFE9E6EF);
}

/// 둥근 모서리 기준값.
abstract final class AppRadius {
  static const card = 28.0;
  static const button = 20.0;
}

abstract final class AppTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      surface: AppColors.background,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: AppColors.textDark,
        ),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w800,
          color: AppColors.textDark,
        ),
        titleLarge: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: AppColors.textDark,
        ),
        titleMedium: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
        ),
        bodyLarge: TextStyle(fontSize: 18, color: AppColors.textDark),
        bodyMedium: TextStyle(fontSize: 16, color: AppColors.textSoft),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 56),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
        ),
      ),
    );
  }
}
