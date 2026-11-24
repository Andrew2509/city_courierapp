import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:city_courierapp/core/config/app_colors.dart';

/// Utilitas matematika kamera navigasi untuk rotasi 360°, interpolasi sudut
/// terpendek, posisi kendaraan bawah-tengah (look-ahead), dan perspektif 2D/3D.
class NavigationCameraMath {
  NavigationCameraMath._();

  static const double defaultTiltAngleRad = 0.56; // ~32 derajat perspektif
  static const double defaultPerspectiveDepth = 0.00105;

  /// Menormalkan sudut ke rentang `[0, 360)`.
  static double normalizeAngleDeg(double deg) {
    final mod = deg % 360.0;
    return mod < 0 ? mod + 360.0 : mod;
  }

  /// Menghitung selisih sudut terpendek dari [fromDeg] ke [toDeg] dalam `[-180, 180]`.
  static double shortestAngleDeltaDeg(double fromDeg, double toDeg) {
    return (toDeg - fromDeg + 540.0) % 360.0 - 180.0;
  }

  /// Interpolasi linear antar dua sudut derajat melalui lintasan terpendek.
  static double lerpAngleDeg(double fromDeg, double toDeg, double t) {
    return fromDeg + shortestAngleDeltaDeg(fromDeg, toDeg) * t;
  }

  /// Menghitung nilai `turns` kontinu (untuk `AnimatedRotation`) agar ikon
  /// tidak pernah berputar balik 359° saat melewati titik utara 0°/360°.
  static double unwrapTurns(double? previousTurns, double targetDeg) {
    final normalizedDeg = normalizeAngleDeg(targetDeg);
    if (previousTurns == null) return normalizedDeg / 360.0;
    final currentDeg = normalizeAngleDeg(previousTurns * 360.0);
    final delta = shortestAngleDeltaDeg(currentDeg, normalizedDeg);
    return previousTurns + (delta / 360.0);
  }

  /// Menghitung offset layar agar marker kurir berada di area bawah-tengah
  /// sehingga jalur di depan kendaraan tampak lebih luas.
  static Offset computeFollowCenterOffset(
    Size viewportSize, {
    required bool isNavigationActive,
    double tiltFraction = 0.0,
  }) {
    if (!isNavigationActive) return Offset.zero;
    final h = viewportSize.height > 0 ? viewportSize.height : 800.0;
    final baseRatio = 0.16 + (0.02 * tiltFraction.clamp(0.0, 1.0));
    return Offset(0.0, h * baseRatio);
  }

  /// Menghitung skala overscan agar saat peta dimiringkan dalam perspektif 3D
  /// tidak pernah muncul celah kosong di sudut atas kiri/kanan.
  static Size computeOverscanFactor(double tiltFraction) {
    final f = tiltFraction.clamp(0.0, 1.0);
    return Size(1.0 + 0.54 * f, 1.0 + 0.42 * f);
  }

  /// Membentuk matriks transformasi perspektif 2D (`0.0`) hingga 3D (`1.0`)
  /// dengan titik poros di area bawah-tengah tempat kendaraan berada.
  static Matrix4 buildPerspectiveMatrix(
    double tiltFraction, {
    double maxAngleRad = defaultTiltAngleRad,
    double perspectiveDepth = defaultPerspectiveDepth,
  }) {
    final f = tiltFraction.clamp(0.0, 1.0);
    if (f <= 0.0001) return Matrix4.identity();
    return Matrix4.identity()
      ..setEntry(3, 2, perspectiveDepth)
      ..rotateX(-maxAngleRad * f);
  }
}

/// Tombol kompas bergaya Google Maps yang jarumnya berputar mengikuti arah peta.
///
/// - Ketika peta tidak menghadap utara (`|rotation| > 2°`), mengetuk kompas akan
///   mengembalikan orientasi peta ke utara (`0°`).
/// - Ketika peta sudah menghadap utara (`|rotation| <= 2°`), mengetuk kompas akan
///   mengaktifkan kembali mode auto-rotate mengikuti arah kendaraan.
class NavigationCompassButton extends StatelessWidget {
  final double mapRotationDeg;
  final bool isAutoRotateActive;
  final VoidCallback onTap;

  const NavigationCompassButton({
    super.key,
    required this.mapRotationDeg,
    required this.isAutoRotateActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isOffNorth = mapRotationDeg.abs() > 2.0;
    final tooltipText = isOffNorth
        ? 'Arahkan peta ke Utara'
        : (isAutoRotateActive
              ? 'Mode ikuti arah aktif (ketuk untuk Utara)'
              : 'Aktifkan rotasi ikuti arah kendaraan');

    return Tooltip(
      message: tooltipText,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 0,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isAutoRotateActive
                    ? AppColors.primaryOrange
                    : const Color(0xFFE2E8F0),
                width: isAutoRotateActive ? 1.5 : 1.0,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x16000000),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Transform.rotate(
                  angle: mapRotationDeg * math.pi / 180.0,
                  child: CustomPaint(
                    size: const Size(24, 24),
                    painter: _CompassNeedlePainter(
                      isActiveHeadingUp: isAutoRotateActive,
                    ),
                  ),
                ),
                Positioned(
                  top: 3,
                  child: Text(
                    'U',
                    style: TextStyle(
                      fontSize: 7.5,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                      color: isOffNorth
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFFDC2626),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompassNeedlePainter extends CustomPainter {
  final bool isActiveHeadingUp;

  const _CompassNeedlePainter({required this.isActiveHeadingUp});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Jarum Utara (Merah)
    final northPath = Path()
      ..moveTo(cx, 2)
      ..lineTo(cx - 4.2, cy)
      ..lineTo(cx + 4.2, cy)
      ..close();
    canvas.drawPath(
      northPath,
      Paint()
        ..color = const Color(0xFFDC2626)
        ..style = PaintingStyle.fill,
    );

    // Jarum Selatan (Abu gelap / Slate)
    final southPath = Path()
      ..moveTo(cx, size.height - 2)
      ..lineTo(cx - 4.2, cy)
      ..lineTo(cx + 4.2, cy)
      ..close();
    canvas.drawPath(
      southPath,
      Paint()
        ..color = isActiveHeadingUp
            ? const Color(0xFF334155)
            : const Color(0xFF94A3B8)
        ..style = PaintingStyle.fill,
    );

    // Poros tengah kompas
    canvas.drawCircle(
      Offset(cx, cy),
      2.1,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _CompassNeedlePainter oldDelegate) =>
      oldDelegate.isActiveHeadingUp != isActiveHeadingUp;
}

/// Tombol pengalih sudut pandang kamera navigasi 2D <-> 3D.
class NavigationTiltToggleButton extends StatelessWidget {
  final bool is3dEnabled;
  final VoidCallback onTap;

  const NavigationTiltToggleButton({
    super.key,
    required this.is3dEnabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: is3dEnabled
          ? 'Ganti ke tampilan 2D datar'
          : 'Ganti ke tampilan 3D miring',
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 0,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: is3dEnabled
                    ? const Color(0xFF0A6051)
                    : const Color(0xFFE2E8F0),
                width: is3dEnabled ? 1.5 : 1.0,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x16000000),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Text(
                is3dEnabled ? '3D' : '2D',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  color: is3dEnabled
                      ? const Color(0xFF0A6051)
                      : const Color(0xFF0F172A),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
