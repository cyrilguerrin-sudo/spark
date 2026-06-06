import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Backgrounds
  static const Color bgPrimary = Color(0xFF0A0A0A);
  static const Color bgCard = Color(0xFF111111);
  static const Color bgCardBorder = Color(0xFF1E1E1E);
  // rgba(56, 56, 56, 0.2)
  static const Color bgCardSurface = Color(0x33383838);

  // Accents
  static const Color green = Color(0xFF268429);
  static const Color greenLight = Color(0xFF4CAF50);
  static const Color red = Color(0xFF843B26);
  static const Color orange = Color(0xFFE05A3A);

  // Text
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFBBBBBB);
  static const Color textMuted = Color(0xFF555555);

  // Flame glow — #FF6600 à 15% d'opacité
  static const Color flameGlow = Color(0x26FF6600);

  // Bottom nav — rgba(255, 255, 255, 0.05)
  static const Color bottomNavBg = Color(0x0DFFFFFF);
}

class AppRadius {
  AppRadius._();

  static const double card = 20.0;
  static const double button = 24.0;
  static const double bottomNav = 20.0;
  static const double screen = 44.0;
}

class AppTextStyles {
  AppTextStyles._();

  // "Salut Cyril !" — titre principal
  static const TextStyle titleLarge = TextStyle(
    fontFamily: 'Inter',
    fontWeight: FontWeight.w800,
    fontSize: 32,
    fontStyle: FontStyle.italic,
    letterSpacing: -1.6,
    color: AppColors.textPrimary,
  );

  // Chiffre clé (ex: "2h12")
  static const TextStyle metricLarge = TextStyle(
    fontFamily: 'Inter',
    fontWeight: FontWeight.w800,
    fontSize: 50,
    letterSpacing: -2.5,
    color: AppColors.textPrimary,
  );

  // Label section (ex: "Sessions récentes")
  static const TextStyle sectionLabel = TextStyle(
    fontFamily: 'Inter',
    fontWeight: FontWeight.w700,
    fontSize: 18,
    letterSpacing: -0.9,
    color: AppColors.textSecondary,
  );

  // Corps texte
  static const TextStyle body = TextStyle(
    fontFamily: 'Inter',
    fontWeight: FontWeight.w500,
    fontSize: 14,
    letterSpacing: -0.7,
    color: AppColors.textSecondary,
  );

  // Nom réseau social
  static const TextStyle networkName = TextStyle(
    fontFamily: 'Inter',
    fontWeight: FontWeight.w600,
    fontSize: 18,
    color: AppColors.textPrimary,
  );

  // Label bouton
  static const TextStyle buttonLabel = TextStyle(
    fontFamily: 'Inter',
    fontWeight: FontWeight.w700,
    fontSize: 16,
    letterSpacing: -0.5,
    color: AppColors.textPrimary,
  );

  // Petit texte (note, légende)
  static const TextStyle caption = TextStyle(
    fontFamily: 'Inter',
    fontWeight: FontWeight.w500,
    fontSize: 12,
    letterSpacing: -0.3,
    color: AppColors.textSecondary,
  );
}

class AppTheme {
  AppTheme._();

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.bgPrimary,
        fontFamily: 'Inter',
        colorScheme: ColorScheme.dark(
          primary: AppColors.orange,
          secondary: AppColors.green,
          error: AppColors.red,
          surface: AppColors.bgCard,
        ),
        textTheme: const TextTheme(
          displayLarge: AppTextStyles.titleLarge,
          bodyMedium: AppTextStyles.body,
          labelLarge: AppTextStyles.buttonLabel,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.textPrimary,
            foregroundColor: AppColors.bgPrimary,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.button),
            ),
            textStyle: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 16,
              letterSpacing: -0.5,
              color: AppColors.bgPrimary,
            ),
          ),
        ),
        cardTheme: CardTheme(
          color: AppColors.bgCardSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.bgCardSurface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
            borderSide: BorderSide.none,
          ),
          hintStyle: AppTextStyles.body,
        ),
      );
}
