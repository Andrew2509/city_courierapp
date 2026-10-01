import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors
  static const Color primaryOrange = Color(0xFFFA880F);
  static const Color primaryGreen = Color(0xFF4CAF50);
  static const Color primaryBlue = Color(0xFF2196F3);
  static const Color primaryTeal = Color(0xFF1A9E8C);

  // Text Colors
  static const Color textPrimary = Colors.black;
  static const Color textSecondary = Color(0x66000000); // 40% opacity
  static const Color textWhite = Colors.white;

  // Background Colors
  static const Color backgroundColor = Colors.white;
  static const Color cardBackground = Color(0xFFF8F8F8);

  // Status Colors
  static const Color successColor = Color(0xFF4CAF50);
  static const Color warningColor = Color(0xFFFF9800);
  static const Color errorColor = Color(0xFFF44336);
  static const Color infoColor = Color(0xFF2196F3);

  // Dashboard Specific
  static const Color dashboardCardBackground = Color(0xFFFFFFFF);
  static const Color dashboardCardBorder = Color(0xFFE8E8E8);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFA880F), Color(0xFFFF6B35)],
  );

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
  );
}
