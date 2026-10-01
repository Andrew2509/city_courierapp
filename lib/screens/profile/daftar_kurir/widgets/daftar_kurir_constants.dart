import 'package:flutter/material.dart';

class DaftarKurirColors {
  static const Color primary = Color(0xFFEC5B13);
  static const Color primaryLight = Color(0xFFFFF0E5);
  static const Color primaryHover = Color(0xFFE65100);
  
  static const Color bgLight = Color(0xFFF8FAFC);
  static const Color cardBg = Color(0xFFFFFFFF);
  
  static const Color textDark = Color(0xFF111827);
  static const Color textSub = Color(0xFF4B5563);
  static const Color textMuted = Color(0xFF9CA3AF);
  
  static const Color border = Color(0xFFE5E7EB);
  
  static const Color success = Color(0xFF16A34A);
  static const Color successLight = Color(0xFFDCFCE7);
  
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  
  static const Color error = Color(0xFFDC2626);
  static const Color errorLight = Color(0xFFFEE2E2);
}

class DaftarKurirTextStyles {
  static const TextStyle title = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: DaftarKurirColors.textDark,
  );
  
  static const TextStyle subtitle = TextStyle(
    fontSize: 14,
    color: DaftarKurirColors.textSub,
    height: 1.5,
  );
  
  static const TextStyle body = TextStyle(
    fontSize: 14,
    color: DaftarKurirColors.textDark,
  );
  
  static const TextStyle label = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: DaftarKurirColors.textDark,
  );
  
  static const TextStyle buttonText = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );
}
