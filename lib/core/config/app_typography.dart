import 'package:flutter/material.dart';

class AppTypography {
  // Use default system font (Roboto on Android, San Francisco on iOS)
  static TextStyle get baseStyle => const TextStyle();

  // Font Sizes
  static const double fontSizeXS = 12.0;
  static const double fontSizeS = 14.0;
  static const double fontSizeM = 16.0;
  static const double fontSizeL = 18.0;
  static const double fontSizeXL = 20.0;
  static const double fontSizeXXL = 24.0;

  // Text Styles
  static TextStyle get headline1 => baseStyle.copyWith(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: Colors.black,
  );

  static TextStyle get headline2 => baseStyle.copyWith(
    fontSize: fontSizeXXL,
    fontWeight: FontWeight.w600,
    color: Colors.black,
  );

  static TextStyle get headlineMedium => baseStyle.copyWith(
    fontSize: fontSizeXL,
    fontWeight: FontWeight.w600,
    color: Colors.black,
  );

  static TextStyle get headlineSmall => baseStyle.copyWith(
    fontSize: fontSizeL,
    fontWeight: FontWeight.w600,
    color: Colors.black,
  );

  static TextStyle get titleLarge => baseStyle.copyWith(
    fontSize: fontSizeXL,
    fontWeight: FontWeight.w600,
    color: Colors.black,
  );

  static TextStyle get titleMedium => baseStyle.copyWith(
    fontSize: fontSizeM,
    fontWeight: FontWeight.w600,
    color: Colors.black,
  );

  static TextStyle get titleSmall => baseStyle.copyWith(
    fontSize: fontSizeS,
    fontWeight: FontWeight.w600,
    color: Colors.black,
  );

  static TextStyle get bodyLarge => baseStyle.copyWith(
    fontSize: fontSizeL,
    fontWeight: FontWeight.normal,
    color: Colors.black,
  );

  static TextStyle get bodyMedium => baseStyle.copyWith(
    fontSize: fontSizeM,
    fontWeight: FontWeight.normal,
    color: Colors.black,
  );

  static TextStyle get bodySmall => baseStyle.copyWith(
    fontSize: fontSizeS,
    fontWeight: FontWeight.normal,
    color: Colors.black,
  );

  static TextStyle get caption => baseStyle.copyWith(
    fontSize: fontSizeXS,
    fontWeight: FontWeight.normal,
    color: Colors.grey,
  );
}
