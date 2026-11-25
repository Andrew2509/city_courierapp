import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Kumpulan jenis ikon vektor kustom bergaya stiker ilustrasi Beranda City Courier
/// (warna oranye hangat, teal aksen, outline navy gelap, serta tepi putih stiker),
/// digambar secara programatik lewat CustomPainter tanpa file unduhan eksternal.
enum CourierIconKind {
  avatarUser,
  cameraEdit,
  wallet,
  topup,
  withdraw,
  refund,
  receiptHistory,
  unpaidBill,
  confirmedOrder,
  pickupBox,
  inTransit,
  deliveredCheck,
  cancelledOrder,
  locationPin,
  securityShield,
  courierPartner,
  dailyReward,
  privacyPolicy,
  helpCenter,
  hourglass,
  editProfile,
  language,
  notification,
  rateApp,
  clearCache,
  website,
  storageDisk,
  inviteFriends,
  phoneContact,
  emailContact,
  motorcycle,
  settingsGear,
  infoBadge,
  trackPackage,
  calculateRate,
  supportAgent,
  eyeVisible,
  eyeHidden,
  chevronRight,
  refresh,
  errorCircle,
  logout,
  personalAccount,
  courierAccount,
}

/// Ikon vektor kustom City Courier yang selaras dengan ikon stiker di Beranda
/// (oranye `#F38922`, teal `#14B0A6`, krem `#F9D597`, outline `#1B3139`, dan halo putih),
/// sekaligus mendukung mode monokrom untuk kontrol UI kecil (mata saldo, chevron, keluar).
class CityCourierCustomIcon extends StatelessWidget {
  final CourierIconKind kind;
  final double size;
  final Color? color;
  final Color? accentColor;
  final String? semanticLabel;

  const CityCourierCustomIcon(
    this.kind, {
    super.key,
    this.size = 28,
    this.color,
    this.accentColor,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color ink = color ??
        (isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1B3139));
    final Color accent =
        color ?? accentColor ?? const Color(0xFFF38922);
    final bool isMonochrome = color != null;

    final Widget canvas = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CityCourierStickerPainter(
          kind: kind,
          inkColor: ink,
          accentColor: accent,
          isMonochrome: isMonochrome,
          isDark: isDark,
        ),
      ),
    );

    if (semanticLabel == null) return canvas;
    return Semantics(
      label: semanticLabel,
      child: canvas,
    );
  }
}

class _StickerPart {
  final Path path;
  final Color fill;
  final void Function(Canvas c)? onPaintDetails;

  const _StickerPart(
    this.path,
    this.fill, {
    this.onPaintDetails,
  });
}

class _CityCourierStickerPainter extends CustomPainter {
  final CourierIconKind kind;
  final Color inkColor;
  final Color accentColor;
  final bool isMonochrome;
  final bool isDark;

  const _CityCourierStickerPainter({
    required this.kind,
    required this.inkColor,
    required this.accentColor,
    required this.isMonochrome,
    required this.isDark,
  });

  // Palet khas ikon Beranda City Courier (Pickup, Dropoff, Reguler, Dokumen, Bantuan)
  static const Color _orange = Color(0xFFF38922);
  static const Color _teal = Color(0xFF14B0A6);
  static const Color _navy = Color(0xFF1B3139);
  static const Color _cream = Color(0xFFFAD49B);
  static const Color _skin = Color(0xFFF9C18E);
  static const Color _white = Colors.white;
  static const Color _coralRed = Color(0xFFEF4444);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24.0, size.height / 24.0);

    if (isMonochrome || _isUtilityLineKind(kind)) {
      _paintUtilityLineIcon(canvas);
      canvas.restore();
      return;
    }

    final parts = _buildStickerParts();
    _paintStickerPipeline(canvas, parts);
    canvas.restore();
  }

  bool _isUtilityLineKind(CourierIconKind k) {
    return k == CourierIconKind.eyeVisible ||
        k == CourierIconKind.eyeHidden ||
        k == CourierIconKind.chevronRight ||
        k == CourierIconKind.refresh ||
        k == CourierIconKind.errorCircle ||
        k == CourierIconKind.logout ||
        k == CourierIconKind.personalAccount ||
        k == CourierIconKind.courierAccount;
  }

  void _paintStickerPipeline(Canvas c, List<_StickerPart> parts) {
    // 1. Bayangan lembut khas stiker Beranda
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: isDark ? 0.28 : 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final shadowFill = Paint()
      ..color = Colors.black.withValues(alpha: isDark ? 0.28 : 0.14)
      ..style = PaintingStyle.fill;

    c.save();
    c.translate(0, 0.75);
    for (final part in parts) {
      c.drawPath(part.path, shadowPaint);
      c.drawPath(part.path, shadowFill);
    }
    c.restore();

    // 2. Halo putih stiker di sekeliling siluet gabungan
    final haloPaint = Paint()
      ..color = _white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final haloFill = Paint()
      ..color = _white
      ..style = PaintingStyle.fill;

    for (final part in parts) {
      c.drawPath(part.path, haloPaint);
      c.drawPath(part.path, haloFill);
    }

    // 3. Isi warna solid oranye/teal/krem + garis tepi navy gelap + detail dalam
    for (final part in parts) {
      c.drawPath(
        part.path,
        Paint()
          ..color = part.fill
          ..style = PaintingStyle.fill,
      );
      c.drawPath(
        part.path,
        Paint()
          ..color = _navy
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.35
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      part.onPaintDetails?.call(c);
    }
  }

  Paint _detailStroke({Color color = _navy, double width = 1.3}) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  Paint _detailFill(Color color) => Paint()
    ..color = color
    ..style = PaintingStyle.fill;

  List<_StickerPart> _buildStickerParts() {
    switch (kind) {
      case CourierIconKind.avatarUser:
        return [
          _StickerPart(
            Path()
              ..moveTo(5.0, 20.0)
              ..cubicTo(5.6, 15.2, 8.6, 14.0, 12.0, 14.0)
              ..cubicTo(15.4, 14.0, 18.4, 15.2, 19.0, 20.0)
              ..close(),
            _orange,
            onPaintDetails: (c) {
              c.drawPath(
                Path()
                  ..moveTo(9.4, 14.3)
                  ..lineTo(12.0, 16.9)
                  ..lineTo(14.6, 14.3),
                _detailStroke(color: _white, width: 1.2),
              );
            },
          ),
          _StickerPart(
            Path()
              ..addOval(
                Rect.fromCircle(center: const Offset(12.0, 8.8), radius: 3.9),
              ),
            _skin,
            onPaintDetails: (c) {
              // Rambut navy gaya maskot Bantuan.png
              c.drawPath(
                Path()
                  ..moveTo(8.3, 8.6)
                  ..cubicTo(8.3, 5.2, 15.7, 5.2, 15.7, 8.4)
                  ..cubicTo(14.0, 7.2, 10.6, 7.2, 8.3, 8.6)
                  ..close(),
                _detailFill(_navy),
              );
              c.drawCircle(const Offset(10.6, 9.2), 0.5, _detailFill(_navy));
              c.drawCircle(const Offset(13.4, 9.2), 0.5, _detailFill(_navy));
              c.drawArc(
                const Rect.fromLTRB(10.6, 9.6, 13.4, 11.4),
                0.25,
                2.6,
                false,
                _detailStroke(width: 1.0),
              );
            },
          ),
        ];

      case CourierIconKind.cameraEdit:
        return [
          _StickerPart(
            Path()
              ..moveTo(4.6, 8.2)
              ..lineTo(7.8, 8.2)
              ..lineTo(9.2, 5.8)
              ..lineTo(14.8, 5.8)
              ..lineTo(16.2, 8.2)
              ..lineTo(19.4, 8.2)
              ..quadraticBezierTo(20.6, 8.2, 20.6, 9.4)
              ..lineTo(20.6, 17.6)
              ..quadraticBezierTo(20.6, 18.8, 19.4, 18.8)
              ..lineTo(4.6, 18.8)
              ..quadraticBezierTo(3.4, 18.8, 3.4, 17.6)
              ..lineTo(3.4, 9.4)
              ..quadraticBezierTo(3.4, 8.2, 4.6, 8.2)
              ..close(),
            _orange,
            onPaintDetails: (c) {
              c.drawCircle(const Offset(17.4, 10.6), 0.9, _detailFill(_teal));
            },
          ),
          _StickerPart(
            Path()
              ..addOval(
                Rect.fromCircle(center: const Offset(12.0, 13.5), radius: 3.3),
              ),
            _teal,
            onPaintDetails: (c) {
              c.drawCircle(const Offset(12.0, 13.5), 1.4, _detailFill(_white));
            },
          ),
        ];

      case CourierIconKind.wallet:
        return [
          _StickerPart(
            Path()
              ..addRRect(
                RRect.fromRectAndRadius(
                  const Rect.fromLTRB(6.0, 4.4, 17.6, 9.0),
                  const Radius.circular(1.8),
                ),
              ),
            _teal,
          ),
          _StickerPart(
            Path()
              ..addRRect(
                RRect.fromRectAndRadius(
                  const Rect.fromLTRB(3.8, 7.2, 19.8, 19.0),
                  const Radius.circular(2.8),
                ),
              ),
            _orange,
          ),
          _StickerPart(
            Path()
              ..addRRect(
                RRect.fromRectAndRadius(
                  const Rect.fromLTRB(14.4, 11.1, 20.4, 15.3),
                  const Radius.circular(1.8),
                ),
              ),
            _cream,
            onPaintDetails: (c) {
              c.drawCircle(const Offset(16.6, 13.2), 0.95, _detailFill(_navy));
            },
          ),
        ];

      case CourierIconKind.topup:
        return [
          _StickerPart(
            Path()
              ..addRRect(
                RRect.fromRectAndRadius(
                  const Rect.fromLTRB(4.0, 5.2, 19.0, 18.8),
                  const Radius.circular(3.5),
                ),
              ),
            _orange,
            onPaintDetails: (c) {
              c.drawLine(
                const Offset(6.8, 9.2),
                const Offset(12.4, 9.2),
                _detailStroke(color: _cream, width: 1.5),
              );
            },
          ),
          _StickerPart(
            Path()
              ..addOval(
                Rect.fromCircle(center: const Offset(15.8, 15.2), radius: 4.5),
              ),
            _teal,
            onPaintDetails: (c) {
              final p = _detailStroke(color: _white, width: 1.7);
              c.drawLine(const Offset(15.8, 13.0), const Offset(15.8, 17.4), p);
              c.drawLine(const Offset(13.6, 15.2), const Offset(18.0, 15.2), p);
            },
          ),
        ];

      case CourierIconKind.withdraw:
        return [
          _StickerPart(
            Path()
              ..addRRect(
                RRect.fromRectAndRadius(
                  const Rect.fromLTRB(4.2, 11.4, 19.8, 19.4),
                  const Radius.circular(2.8),
                ),
              ),
            _orange,
            onPaintDetails: (c) {
              c.drawLine(
                const Offset(7.2, 16.0),
                const Offset(16.8, 16.0),
                _detailStroke(color: _cream, width: 1.4),
              );
            },
          ),
          _StickerPart(
            Path()
              ..moveTo(12.0, 4.2)
              ..lineTo(16.6, 9.0)
              ..lineTo(13.8, 9.0)
              ..lineTo(13.8, 13.2)
              ..lineTo(10.2, 13.2)
              ..lineTo(10.2, 9.0)
              ..lineTo(7.4, 9.0)
              ..close(),
            _teal,
          ),
        ];

      case CourierIconKind.refund:
        return [
          _StickerPart(
            Path()
              ..addRRect(
                RRect.fromRectAndRadius(
                  const Rect.fromLTRB(6.6, 7.6, 17.4, 18.2),
                  const Radius.circular(2.4),
                ),
              ),
            _orange,
            onPaintDetails: (c) {
              c.drawPath(
                Path()
                  ..moveTo(10.6, 7.6)
                  ..lineTo(10.6, 11.4)
                  ..lineTo(12.0, 10.4)
                  ..lineTo(13.4, 11.4)
                  ..lineTo(13.4, 7.6)
                  ..close(),
                _detailFill(_cream),
              );
            },
          ),
          _StickerPart(
            Path()
              ..addOval(
                Rect.fromCircle(center: const Offset(16.6, 8.0), radius: 4.1),
              ),
            _teal,
            onPaintDetails: (c) {
              c.drawArc(
                Rect.fromCircle(center: const Offset(16.6, 8.0), radius: 2.1),
                0.5,
                4.2,
                false,
                _detailStroke(color: _white, width: 1.3),
              );
              c.drawPath(
                Path()
                  ..moveTo(14.5, 6.4)
                  ..lineTo(14.8, 8.1)
                  ..lineTo(16.4, 7.6),
                _detailStroke(color: _white, width: 1.2),
              );
            },
          ),
        ];

      case CourierIconKind.receiptHistory:
        return [
          _StickerPart(
            Path()
              ..moveTo(6.0, 4.0)
              ..lineTo(18.0, 4.0)
              ..lineTo(18.0, 19.8)
              ..lineTo(16.0, 18.2)
              ..lineTo(14.0, 19.8)
              ..lineTo(12.0, 18.2)
              ..lineTo(10.0, 19.8)
              ..lineTo(8.0, 18.2)
              ..lineTo(6.0, 19.8)
              ..close(),
            _white,
            onPaintDetails: (c) {
              c.drawRect(
                const Rect.fromLTRB(6.6, 4.6, 17.4, 8.2),
                _detailFill(_orange),
              );
              c.drawLine(
                const Offset(8.4, 11.2),
                const Offset(15.6, 11.2),
                _detailStroke(width: 1.3),
              );
              c.drawLine(
                const Offset(8.4, 14.2),
                const Offset(14.2, 14.2),
                _detailStroke(color: _teal, width: 1.3),
              );
            },
          ),
        ];

      case CourierIconKind.unpaidBill:
        return [
          _StickerPart(
            Path()
              ..addRRect(
                RRect.fromRectAndRadius(
                  const Rect.fromLTRB(4.0, 6.2, 18.8, 17.6),
                  const Radius.circular(2.8),
                ),
              ),
            _orange,
            onPaintDetails: (c) {
              c.drawRect(
                const Rect.fromLTRB(4.6, 8.6, 18.2, 11.2),
                _detailFill(_navy),
              );
              c.drawLine(
                const Offset(6.8, 14.2),
                const Offset(11.6, 14.2),
                _detailStroke(color: _cream, width: 1.5),
              );
            },
          ),
          _StickerPart(
            Path()
              ..addOval(
                Rect.fromCircle(center: const Offset(16.8, 16.0), radius: 4.0),
              ),
            _teal,
            onPaintDetails: (c) {
              c.drawLine(
                const Offset(16.8, 13.8),
                const Offset(16.8, 16.0),
                _detailStroke(color: _white, width: 1.4),
              );
              c.drawLine(
                const Offset(16.8, 16.0),
                const Offset(18.2, 16.8),
                _detailStroke(color: _white, width: 1.4),
              );
            },
          ),
        ];

      case CourierIconKind.confirmedOrder:
        return [
          _StickerPart(
            Path()
              ..moveTo(6.2, 4.4)
              ..lineTo(14.6, 4.4)
              ..lineTo(17.8, 7.6)
              ..lineTo(17.8, 19.6)
              ..lineTo(6.2, 19.6)
              ..close(),
            _orange,
            onPaintDetails: (c) {
              // Lipatan sudut atas gaya Dokumen.png
              c.drawPath(
                Path()
                  ..moveTo(14.6, 4.4)
                  ..lineTo(14.6, 7.6)
                  ..lineTo(17.8, 7.6)
                  ..close(),
                _detailFill(_teal),
              );
              c.drawPath(
                Path()
                  ..moveTo(14.6, 4.4)
                  ..lineTo(14.6, 7.6)
                  ..lineTo(17.8, 7.6),
                _detailStroke(width: 1.2),
              );
              c.drawLine(
                const Offset(8.8, 10.0),
                const Offset(14.8, 10.0),
                _detailStroke(width: 1.3),
              );
              c.drawPath(
                Path()
                  ..moveTo(9.2, 14.4)
                  ..lineTo(11.3, 16.5)
                  ..lineTo(15.2, 12.4),
                _detailStroke(width: 1.6),
              );
            },
          ),
        ];

      case CourierIconKind.pickupBox:
        return [
          _StickerPart(
            Path()
              ..addRRect(
                RRect.fromRectAndRadius(
                  const Rect.fromLTRB(4.6, 6.8, 19.4, 18.8),
                  const Radius.circular(2.6),
                ),
              ),
            _orange,
            onPaintDetails: (c) {
              // Segel pita atas ala Reguler.png & Cargo.png
              c.drawPath(
                Path()
                  ..moveTo(10.3, 6.8)
                  ..lineTo(10.3, 11.4)
                  ..lineTo(12.0, 10.1)
                  ..lineTo(13.7, 11.4)
                  ..lineTo(13.7, 6.8)
                  ..close(),
                _detailFill(_teal),
              );
              c.drawPath(
                Path()
                  ..moveTo(10.3, 6.8)
                  ..lineTo(10.3, 11.4)
                  ..lineTo(12.0, 10.1)
                  ..lineTo(13.7, 11.4)
                  ..lineTo(13.7, 6.8),
                _detailStroke(width: 1.2),
              );
              c.drawRect(
                const Rect.fromLTRB(13.8, 14.2, 17.4, 16.8),
                _detailStroke(width: 1.1),
              );
            },
          ),
        ];

      case CourierIconKind.inTransit:
        return [
          _StickerPart(
            Path()
              ..moveTo(14.2, 9.0)
              ..lineTo(18.4, 9.0)
              ..lineTo(20.6, 12.6)
              ..lineTo(20.6, 15.8)
              ..lineTo(14.2, 15.8)
              ..close(),
            _teal,
            onPaintDetails: (c) {
              c.drawPath(
                Path()
                  ..moveTo(15.6, 10.3)
                  ..lineTo(18.0, 10.3)
                  ..lineTo(19.4, 12.5)
                  ..lineTo(15.6, 12.5)
                  ..close(),
                _detailFill(_white),
              );
            },
          ),
          _StickerPart(
            Path()
              ..addRRect(
                RRect.fromRectAndRadius(
                  const Rect.fromLTRB(3.8, 6.8, 14.6, 15.8),
                  const Radius.circular(2.0),
                ),
              ),
            _orange,
            onPaintDetails: (c) {
              c.drawRect(
                const Rect.fromLTRB(4.4, 7.4, 14.0, 9.2),
                _detailFill(_teal),
              );
            },
          ),
          _StickerPart(
            Path()
              ..addOval(
                Rect.fromCircle(center: const Offset(7.6, 16.8), radius: 2.2),
              ),
            _white,
            onPaintDetails: (c) {
              c.drawCircle(const Offset(7.6, 16.8), 0.9, _detailFill(_navy));
            },
          ),
          _StickerPart(
            Path()
              ..addOval(
                Rect.fromCircle(center: const Offset(17.4, 16.8), radius: 2.2),
              ),
            _white,
            onPaintDetails: (c) {
              c.drawCircle(const Offset(17.4, 16.8), 0.9, _detailFill(_navy));
            },
          ),
        ];

      case CourierIconKind.deliveredCheck:
        return [
          _StickerPart(
            Path()
              ..addRRect(
                RRect.fromRectAndRadius(
                  const Rect.fromLTRB(4.2, 6.8, 18.2, 18.6),
                  const Radius.circular(2.4),
                ),
              ),
            _orange,
            onPaintDetails: (c) {
              c.drawRect(
                const Rect.fromLTRB(9.8, 7.2, 12.6, 10.4),
                _detailFill(_cream),
              );
            },
          ),
          _StickerPart(
            Path()
              ..addOval(
                Rect.fromCircle(center: const Offset(16.6, 15.6), radius: 4.2),
              ),
            _teal,
            onPaintDetails: (c) {
              c.drawPath(
                Path()
                  ..moveTo(14.7, 15.6)
                  ..lineTo(16.1, 17.0)
                  ..lineTo(18.7, 14.2),
                _detailStroke(color: _white, width: 1.55),
              );
            },
          ),
        ];

      case CourierIconKind.cancelledOrder:
        return [
          _StickerPart(
            Path()
              ..addRRect(
                RRect.fromRectAndRadius(
                  const Rect.fromLTRB(4.2, 6.8, 18.2, 18.6),
                  const Radius.circular(2.4),
                ),
              ),
            _orange,
          ),
          _StickerPart(
            Path()
              ..addOval(
                Rect.fromCircle(center: const Offset(16.6, 15.6), radius: 4.1),
              ),
            _coralRed,
            onPaintDetails: (c) {
              final p = _detailStroke(color: _white, width: 1.5);
              c.drawLine(const Offset(15.0, 14.0), const Offset(18.2, 17.2), p);
              c.drawLine(const Offset(18.2, 14.0), const Offset(15.0, 17.2), p);
            },
          ),
        ];

      case CourierIconKind.locationPin:
        return [
          _StickerPart(
            Path()
              ..addOval(
                const Rect.fromLTRB(6.8, 17.2, 17.2, 20.4),
              ),
            _orange,
          ),
          _StickerPart(
            Path()
              ..moveTo(12.0, 19.0)
              ..cubicTo(6.6, 14.0, 5.8, 11.0, 5.8, 9.0)
              ..cubicTo(5.8, 5.6, 8.6, 3.2, 12.0, 3.2)
              ..cubicTo(15.4, 3.2, 18.2, 5.6, 18.2, 9.0)
              ..cubicTo(18.2, 11.0, 17.4, 14.0, 12.0, 19.0)
              ..close(),
            _orange,
          ),
          _StickerPart(
            Path()
              ..addOval(
                Rect.fromCircle(center: const Offset(12.0, 9.1), radius: 3.1),
              ),
            _teal,
            onPaintDetails: (c) {
              c.drawCircle(const Offset(12.0, 9.1), 1.3, _detailFill(_white));
            },
          ),
        ];

      case CourierIconKind.securityShield:
        return [
          _StickerPart(
            Path()
              ..moveTo(12.0, 3.4)
              ..lineTo(18.6, 6.0)
              ..lineTo(18.6, 11.4)
              ..cubicTo(18.6, 15.6, 15.6, 18.8, 12.0, 20.6)
              ..cubicTo(8.4, 18.8, 5.4, 15.6, 5.4, 11.4)
              ..lineTo(5.4, 6.0)
              ..close(),
            _teal,
          ),
          _StickerPart(
            Path()
              ..moveTo(12.0, 6.0)
              ..lineTo(16.2, 7.8)
              ..lineTo(16.2, 11.5)
              ..cubicTo(16.2, 14.4, 14.3, 16.5, 12.0, 17.8)
              ..cubicTo(9.7, 16.5, 7.8, 14.4, 7.8, 11.5)
              ..lineTo(7.8, 7.8)
              ..close(),
            _orange,
            onPaintDetails: (c) {
              c.drawPath(
                Path()
                  ..moveTo(9.8, 11.8)
                  ..lineTo(11.4, 13.4)
                  ..lineTo(14.6, 10.0),
                _detailStroke(color: _white, width: 1.55),
              );
            },
          ),
        ];

      case CourierIconKind.courierPartner:
        return [
          _StickerPart(
            Path()
              ..moveTo(4.6, 19.8)
              ..cubicTo(5.2, 15.2, 8.2, 14.2, 11.4, 14.2)
              ..cubicTo(14.6, 14.2, 17.6, 15.2, 18.2, 19.8)
              ..close(),
            _orange,
          ),
          _StickerPart(
            Path()
              ..addOval(
                Rect.fromCircle(center: const Offset(11.4, 9.4), radius: 3.4),
              ),
            _skin,
          ),
          _StickerPart(
            Path()
              ..moveTo(7.6, 8.4)
              ..cubicTo(7.8, 5.0, 14.8, 5.0, 15.0, 8.4)
              ..lineTo(16.8, 8.4)
              ..lineTo(16.8, 9.5)
              ..lineTo(7.6, 9.5)
              ..close(),
            _teal,
          ),
          _StickerPart(
            Path()
              ..addRRect(
                RRect.fromRectAndRadius(
                  const Rect.fromLTRB(13.6, 13.8, 20.0, 19.8),
                  const Radius.circular(1.6),
                ),
              ),
            _cream,
            onPaintDetails: (c) {
              c.drawRect(
                const Rect.fromLTRB(16.0, 14.2, 17.6, 16.2),
                _detailFill(_teal),
              );
            },
          ),
        ];

      case CourierIconKind.dailyReward:
        return [
          _StickerPart(
            Path()
              ..addRRect(
                RRect.fromRectAndRadius(
                  const Rect.fromLTRB(4.8, 10.6, 19.2, 19.8),
                  const Radius.circular(2.0),
                ),
              ),
            _orange,
          ),
          _StickerPart(
            Path()
              ..addRRect(
                RRect.fromRectAndRadius(
                  const Rect.fromLTRB(3.8, 7.6, 20.2, 10.8),
                  const Radius.circular(1.6),
                ),
              ),
            _teal,
            onPaintDetails: (c) {
              c.drawRect(
                const Rect.fromLTRB(10.6, 8.0, 13.4, 19.4),
                _detailFill(_cream),
              );
              c.drawLine(
                const Offset(10.6, 8.0),
                const Offset(10.6, 19.4),
                _detailStroke(width: 1.15),
              );
              c.drawLine(
                const Offset(13.4, 8.0),
                const Offset(13.4, 19.4),
                _detailStroke(width: 1.15),
              );
            },
          ),
          _StickerPart(
            Path()
              ..moveTo(12.0, 7.6)
              ..cubicTo(9.4, 3.8, 6.4, 5.2, 8.0, 7.6)
              ..lineTo(16.0, 7.6)
              ..cubicTo(17.6, 5.2, 14.6, 3.8, 12.0, 7.6)
              ..close(),
            _cream,
          ),
        ];

      case CourierIconKind.privacyPolicy:
        return [
          _StickerPart(
            Path()
              ..addRRect(
                RRect.fromRectAndRadius(
                  const Rect.fromLTRB(4.8, 4.0, 16.2, 18.8),
                  const Radius.circular(2.2),
                ),
              ),
            _orange,
            onPaintDetails: (c) {
              c.drawLine(
                const Offset(7.4, 8.2),
                const Offset(13.6, 8.2),
                _detailStroke(width: 1.3),
              );
              c.drawLine(
                const Offset(7.4, 11.4),
                const Offset(12.2, 11.4),
                _detailStroke(width: 1.3),
              );
            },
          ),
          _StickerPart(
            Path()
              ..addRRect(
                RRect.fromRectAndRadius(
                  const Rect.fromLTRB(12.6, 13.4, 19.8, 19.8),
                  const Radius.circular(1.8),
                ),
              ),
            _teal,
            onPaintDetails: (c) {
              c.drawArc(
                const Rect.fromLTRB(14.2, 10.2, 18.2, 14.4),
                math.pi,
                math.pi,
                false,
                _detailStroke(width: 1.35),
              );
              c.drawCircle(const Offset(16.2, 16.5), 0.9, _detailFill(_white));
            },
          ),
        ];

      case CourierIconKind.helpCenter:
        return [
          _StickerPart(
            Path()
              ..moveTo(6.2, 4.4)
              ..lineTo(17.8, 4.4)
              ..quadraticBezierTo(20.0, 4.4, 20.0, 6.6)
              ..lineTo(20.0, 14.6)
              ..quadraticBezierTo(20.0, 16.8, 17.8, 16.8)
              ..lineTo(9.4, 16.8)
              ..lineTo(5.2, 19.8)
              ..lineTo(5.8, 16.6)
              ..quadraticBezierTo(4.0, 16.2, 4.0, 14.6)
              ..lineTo(4.0, 6.6)
              ..quadraticBezierTo(4.0, 4.4, 6.2, 4.4)
              ..close(),
            _white,
            onPaintDetails: (c) {
              c.drawPath(
                Path()
                  ..moveTo(9.6, 8.8)
                  ..cubicTo(9.6, 6.8, 14.4, 6.8, 14.4, 9.2)
                  ..cubicTo(14.4, 10.8, 12.0, 11.0, 12.0, 12.3),
                _detailStroke(color: _orange, width: 1.7),
              );
              c.drawCircle(const Offset(12.0, 14.4), 0.95, _detailFill(_teal));
            },
          ),
        ];

      case CourierIconKind.hourglass:
        return [
          _StickerPart(
            Path()
              ..moveTo(7.4, 5.2)
              ..lineTo(16.6, 5.2)
              ..lineTo(13.2, 12.0)
              ..lineTo(16.6, 18.8)
              ..lineTo(7.4, 18.8)
              ..lineTo(10.8, 12.0)
              ..close(),
            _cream,
            onPaintDetails: (c) {
              c.drawPath(
                Path()
                  ..moveTo(8.4, 18.4)
                  ..lineTo(15.6, 18.4)
                  ..lineTo(12.0, 14.0)
                  ..close(),
                _detailFill(_orange),
              );
            },
          ),
          _StickerPart(
            Path()
              ..addRRect(
                RRect.fromRectAndRadius(
                  const Rect.fromLTRB(6.0, 3.6, 18.0, 5.6),
                  const Radius.circular(1.0),
                ),
              ),
            _teal,
          ),
          _StickerPart(
            Path()
              ..addRRect(
                RRect.fromRectAndRadius(
                  const Rect.fromLTRB(6.0, 18.4, 18.0, 20.4),
                  const Radius.circular(1.0),
                ),
              ),
            _teal,
          ),
        ];

      case CourierIconKind.editProfile:
        return [
          _StickerPart(
            Path()
              ..moveTo(4.4, 19.4)
              ..cubicTo(5.0, 15.4, 7.8, 14.2, 10.6, 14.2)
              ..cubicTo(13.4, 14.2, 15.8, 15.4, 16.4, 19.4)
              ..close(),
            _orange,
          ),
          _StickerPart(
            Path()
              ..addOval(
                Rect.fromCircle(center: const Offset(10.4, 8.6), radius: 3.4),
              ),
            _skin,
            onPaintDetails: (c) {
              c.drawPath(
                Path()
                  ..moveTo(7.2, 8.4)
                  ..cubicTo(7.4, 5.2, 13.4, 5.2, 13.6, 8.4)
                  ..cubicTo(12.0, 7.2, 8.8, 7.2, 7.2, 8.4)
                  ..close(),
                _detailFill(_navy),
              );
            },
          ),
          _StickerPart(
            Path()
              ..moveTo(13.2, 19.8)
              ..lineTo(13.9, 16.5)
              ..lineTo(18.6, 11.8)
              ..lineTo(20.6, 13.8)
              ..lineTo(15.9, 18.5)
              ..close(),
            _teal,
          ),
        ];

      case CourierIconKind.language:
        return [
          _StickerPart(
            Path()
              ..addRRect(
                RRect.fromRectAndRadius(
                  const Rect.fromLTRB(4.0, 4.4, 14.0, 14.2),
                  const Radius.circular(2.4),
                ),
              ),
            _orange,
            onPaintDetails: (c) {
              final p = _detailStroke(color: _white, width: 1.3);
              c.drawLine(const Offset(6.8, 11.4), const Offset(9.0, 6.8), p);
              c.drawLine(const Offset(11.2, 11.4), const Offset(9.0, 6.8), p);
              c.drawLine(const Offset(7.5, 9.8), const Offset(10.5, 9.8), p);
            },
          ),
          _StickerPart(
            Path()
              ..addRRect(
                RRect.fromRectAndRadius(
                  const Rect.fromLTRB(9.8, 9.8, 20.0, 19.6),
                  const Radius.circular(2.4),
                ),
              ),
            _teal,
            onPaintDetails: (c) {
              final p = _detailStroke(color: _white, width: 1.25);
              c.drawLine(const Offset(12.4, 12.8), const Offset(17.4, 12.8), p);
              c.drawLine(const Offset(14.9, 11.5), const Offset(14.9, 12.8), p);
              c.drawPath(
                Path()
                  ..moveTo(16.6, 12.8)
                  ..cubicTo(15.8, 15.6, 14.0, 17.0, 12.6, 17.6),
                p,
              );
            },
          ),
        ];

      case CourierIconKind.notification:
        return [
          _StickerPart(
            Path()
              ..moveTo(12.0, 4.4)
              ..cubicTo(8.2, 4.4, 6.8, 7.6, 6.8, 11.4)
              ..lineTo(5.6, 15.4)
              ..lineTo(4.4, 16.8)
              ..lineTo(19.6, 16.8)
              ..lineTo(18.4, 15.4)
              ..lineTo(17.2, 11.4)
              ..cubicTo(17.2, 7.6, 15.8, 4.4, 12.0, 4.4)
              ..close(),
            _orange,
            onPaintDetails: (c) {
              c.drawArc(
                const Rect.fromLTRB(9.6, 16.8, 14.4, 19.8),
                0.1,
                math.pi - 0.2,
                false,
                _detailStroke(color: _navy, width: 1.45),
              );
            },
          ),
          _StickerPart(
            Path()
              ..addOval(
                Rect.fromCircle(center: const Offset(17.2, 6.8), radius: 2.5),
              ),
            _teal,
          ),
        ];

      case CourierIconKind.rateApp:
        final star = Path();
        for (int i = 0; i < 10; i++) {
          final r = i.isEven ? 8.2 : 3.9;
          final a = -math.pi / 2 + i * math.pi / 5;
          final x = 12.0 + r * math.cos(a);
          final y = 12.4 + r * math.sin(a);
          if (i == 0) {
            star.moveTo(x, y);
          } else {
            star.lineTo(x, y);
          }
        }
        star.close();
        return [
          _StickerPart(
            star,
            _orange,
            onPaintDetails: (c) {
              c.drawCircle(const Offset(12.0, 12.2), 1.9, _detailFill(_cream));
            },
          ),
        ];

      case CourierIconKind.clearCache:
        return [
          _StickerPart(
            Path()
              ..moveTo(11.0, 9.6)
              ..lineTo(15.4, 12.6)
              ..lineTo(11.6, 19.4)
              ..lineTo(4.4, 16.0)
              ..close(),
            _orange,
            onPaintDetails: (c) {
              c.drawLine(
                const Offset(8.2, 14.4),
                const Offset(7.2, 17.2),
                _detailStroke(width: 1.15),
              );
              c.drawLine(
                const Offset(10.6, 15.4),
                const Offset(9.6, 18.2),
                _detailStroke(width: 1.15),
              );
            },
          ),
          _StickerPart(
            Path()
              ..moveTo(12.8, 10.6)
              ..lineTo(18.0, 4.4)
              ..lineTo(19.4, 5.6)
              ..lineTo(14.2, 11.8)
              ..close(),
            _teal,
          ),
          _StickerPart(
            Path()
              ..addOval(
                Rect.fromCircle(center: const Offset(17.8, 16.4), radius: 1.8),
              ),
            _teal,
          ),
        ];

      case CourierIconKind.website:
        return [
          _StickerPart(
            Path()
              ..addOval(
                Rect.fromCircle(center: const Offset(12.0, 12.0), radius: 7.8),
              ),
            _teal,
            onPaintDetails: (c) {
              c.drawOval(
                Rect.fromCenter(
                  center: const Offset(12.0, 12.0),
                  width: 7.2,
                  height: 15.4,
                ),
                _detailStroke(color: _white, width: 1.25),
              );
              c.drawLine(
                const Offset(4.4, 12.0),
                const Offset(19.6, 12.0),
                _detailStroke(color: _white, width: 1.25),
              );
            },
          ),
          _StickerPart(
            Path()
              ..moveTo(13.4, 12.6)
              ..lineTo(19.8, 15.6)
              ..lineTo(17.0, 16.8)
              ..lineTo(15.8, 19.6)
              ..close(),
            _orange,
          ),
        ];

      case CourierIconKind.storageDisk:
        return [
          _StickerPart(
            Path()
              ..addRRect(
                RRect.fromRectAndRadius(
                  const Rect.fromLTRB(4.4, 4.4, 19.6, 8.8),
                  const Radius.circular(1.8),
                ),
              ),
            _orange,
            onPaintDetails: (c) =>
                c.drawCircle(const Offset(16.8, 6.6), 0.9, _detailFill(_white)),
          ),
          _StickerPart(
            Path()
              ..addRRect(
                RRect.fromRectAndRadius(
                  const Rect.fromLTRB(4.4, 9.8, 19.6, 14.2),
                  const Radius.circular(1.8),
                ),
              ),
            _teal,
            onPaintDetails: (c) => c.drawCircle(
                const Offset(16.8, 12.0), 0.9, _detailFill(_white)),
          ),
          _StickerPart(
            Path()
              ..addRRect(
                RRect.fromRectAndRadius(
                  const Rect.fromLTRB(4.4, 15.2, 19.6, 19.6),
                  const Radius.circular(1.8),
                ),
              ),
            _cream,
            onPaintDetails: (c) => c.drawCircle(
                const Offset(16.8, 17.4), 0.9, _detailFill(_navy)),
          ),
        ];

      case CourierIconKind.inviteFriends:
        return [
          _StickerPart(
            Path()
              ..moveTo(4.2, 19.2)
              ..cubicTo(4.8, 15.2, 7.2, 14.2, 10.0, 14.2)
              ..cubicTo(12.8, 14.2, 15.2, 15.2, 15.8, 19.2)
              ..close(),
            _orange,
          ),
          _StickerPart(
            Path()
              ..addOval(
                Rect.fromCircle(center: const Offset(10.0, 8.8), radius: 3.4),
              ),
            _skin,
          ),
          _StickerPart(
            Path()
              ..addOval(
                Rect.fromCircle(center: const Offset(17.4, 11.4), radius: 3.3),
              ),
            _teal,
            onPaintDetails: (c) {
              final p = _detailStroke(color: _white, width: 1.45);
              c.drawLine(const Offset(17.4, 9.8), const Offset(17.4, 13.0), p);
              c.drawLine(const Offset(15.8, 11.4), const Offset(19.0, 11.4), p);
            },
          ),
        ];

      case CourierIconKind.phoneContact:
        return [
          _StickerPart(
            Path()
              ..addRRect(
                RRect.fromRectAndRadius(
                  const Rect.fromLTRB(6.6, 3.6, 17.4, 20.4),
                  const Radius.circular(2.5),
                ),
              ),
            _teal,
            onPaintDetails: (c) {
              c.drawRRect(
                RRect.fromRectAndRadius(
                  const Rect.fromLTRB(8.0, 6.2, 16.0, 16.6),
                  const Radius.circular(1.2),
                ),
                _detailFill(_orange),
              );
              c.drawCircle(
                const Offset(12.0, 18.4),
                0.85,
                _detailFill(_white),
              );
            },
          ),
        ];

      case CourierIconKind.emailContact:
        return [
          _StickerPart(
            Path()
              ..addRRect(
                RRect.fromRectAndRadius(
                  const Rect.fromLTRB(3.8, 5.8, 20.2, 18.2),
                  const Radius.circular(2.4),
                ),
              ),
            _orange,
            onPaintDetails: (c) {
              c.drawPath(
                Path()
                  ..moveTo(4.4, 6.4)
                  ..lineTo(12.0, 12.6)
                  ..lineTo(19.6, 6.4)
                  ..close(),
                _detailFill(_cream),
              );
              c.drawPath(
                Path()
                  ..moveTo(4.4, 6.6)
                  ..lineTo(12.0, 12.6)
                  ..lineTo(19.6, 6.6),
                _detailStroke(width: 1.3),
              );
            },
          ),
        ];

      case CourierIconKind.motorcycle:
        return [
          _StickerPart(
            Path()
              ..addRRect(
                RRect.fromRectAndRadius(
                  const Rect.fromLTRB(4.2, 8.2, 9.8, 13.0),
                  const Radius.circular(1.4),
                ),
              ),
            _orange,
          ),
          _StickerPart(
            Path()
              ..moveTo(8.8, 12.4)
              ..lineTo(14.4, 12.4)
              ..lineTo(16.6, 16.0)
              ..lineTo(6.6, 16.0)
              ..close(),
            _teal,
            onPaintDetails: (c) {
              c.drawPath(
                Path()
                  ..moveTo(14.8, 6.6)
                  ..lineTo(16.8, 6.6)
                  ..lineTo(18.0, 15.8),
                _detailStroke(width: 1.45),
              );
            },
          ),
          _StickerPart(
            Path()
              ..addOval(
                Rect.fromCircle(center: const Offset(6.8, 16.8), radius: 2.5),
              ),
            _white,
            onPaintDetails: (c) =>
                c.drawCircle(const Offset(6.8, 16.8), 1.0, _detailFill(_navy)),
          ),
          _StickerPart(
            Path()
              ..addOval(
                Rect.fromCircle(center: const Offset(17.8, 16.8), radius: 2.5),
              ),
            _white,
            onPaintDetails: (c) =>
                c.drawCircle(const Offset(17.8, 16.8), 1.0, _detailFill(_navy)),
          ),
        ];

      case CourierIconKind.settingsGear:
        final gear = Path();
        const teeth = 8;
        const outerR = 8.2;
        const innerR = 6.0;
        for (int i = 0; i < teeth * 4; i++) {
          final a = (i * math.pi * 2) / (teeth * 4);
          final mod = i % 4;
          final r = (mod == 0 || mod == 1) ? outerR : innerR;
          final pt = Offset(12 + r * math.cos(a), 12 + r * math.sin(a));
          if (i == 0) {
            gear.moveTo(pt.dx, pt.dy);
          } else {
            gear.lineTo(pt.dx, pt.dy);
          }
        }
        gear.close();
        return [
          _StickerPart(
            gear,
            _teal,
            onPaintDetails: (c) {
              c.drawCircle(
                const Offset(12.0, 12.0),
                2.9,
                _detailFill(_orange),
              );
              c.drawCircle(
                const Offset(12.0, 12.0),
                2.9,
                _detailStroke(width: 1.25),
              );
            },
          ),
        ];

      case CourierIconKind.infoBadge:
        return [
          _StickerPart(
            Path()
              ..addOval(
                Rect.fromCircle(center: const Offset(12.0, 12.0), radius: 7.8),
              ),
            _orange,
            onPaintDetails: (c) {
              c.drawCircle(
                const Offset(12.0, 8.4),
                1.05,
                _detailFill(_white),
              );
              c.drawLine(
                const Offset(12.0, 11.4),
                const Offset(12.0, 16.0),
                _detailStroke(color: _white, width: 1.75),
              );
            },
          ),
        ];

      case CourierIconKind.trackPackage:
        return [
          _StickerPart(
            Path()
              ..addRRect(
                RRect.fromRectAndRadius(
                  const Rect.fromLTRB(4.0, 5.4, 17.6, 17.4),
                  const Radius.circular(2.4),
                ),
              ),
            _orange,
            onPaintDetails: (c) {
              c.drawPath(
                Path()
                  ..moveTo(9.4, 5.4)
                  ..lineTo(9.4, 9.8)
                  ..lineTo(10.8, 8.6)
                  ..lineTo(12.2, 9.8)
                  ..lineTo(12.2, 5.4)
                  ..close(),
                _detailFill(_cream),
              );
              c.drawPath(
                Path()
                  ..moveTo(9.4, 5.4)
                  ..lineTo(9.4, 9.8)
                  ..lineTo(10.8, 8.6)
                  ..lineTo(12.2, 9.8)
                  ..lineTo(12.2, 5.4),
                _detailStroke(width: 1.15),
              );
            },
          ),
          _StickerPart(
            Path()
              ..moveTo(16.6, 16.0)
              ..lineTo(20.0, 19.4)
              ..lineTo(18.8, 20.6)
              ..lineTo(15.4, 17.2)
              ..close(),
            _teal,
          ),
          _StickerPart(
            Path()
              ..addOval(
                Rect.fromCircle(center: const Offset(14.6, 14.0), radius: 4.1),
              ),
            _teal,
            onPaintDetails: (c) {
              c.drawCircle(const Offset(14.6, 14.0), 2.3, _detailFill(_white));
              c.drawCircle(
                const Offset(14.6, 14.0),
                2.3,
                _detailStroke(width: 1.1),
              );
            },
          ),
        ];

      case CourierIconKind.calculateRate:
        return [
          _StickerPart(
            Path()
              ..addRRect(
                RRect.fromRectAndRadius(
                  const Rect.fromLTRB(5.2, 4.0, 17.2, 19.6),
                  const Radius.circular(2.6),
                ),
              ),
            _orange,
            onPaintDetails: (c) {
              c.drawRRect(
                RRect.fromRectAndRadius(
                  const Rect.fromLTRB(7.2, 5.8, 15.2, 9.4),
                  const Radius.circular(1.0),
                ),
                _detailFill(_teal),
              );
              c.drawRRect(
                RRect.fromRectAndRadius(
                  const Rect.fromLTRB(7.2, 5.8, 15.2, 9.4),
                  const Radius.circular(1.0),
                ),
                _detailStroke(width: 1.1),
              );
              for (final ry in [11.6, 14.4, 17.0]) {
                for (final rx in [8.0, 11.2, 14.2]) {
                  c.drawCircle(Offset(rx, ry), 0.9, _detailFill(_white));
                }
              }
            },
          ),
          _StickerPart(
            Path()
              ..addOval(
                Rect.fromCircle(center: const Offset(17.2, 16.4), radius: 3.7),
              ),
            _teal,
            onPaintDetails: (c) {
              c.drawPath(
                Path()
                  ..moveTo(16.1, 17.3)
                  ..lineTo(18.1, 15.3)
                  ..moveTo(16.6, 15.3)
                  ..lineTo(18.1, 15.3)
                  ..lineTo(18.1, 16.8),
                _detailStroke(color: _white, width: 1.3),
              );
            },
          ),
        ];

      case CourierIconKind.supportAgent:
        return [
          _StickerPart(
            Path()
              ..moveTo(4.0, 19.8)
              ..cubicTo(4.6, 15.2, 7.6, 14.2, 10.6, 14.2)
              ..cubicTo(13.6, 14.2, 16.6, 15.2, 17.2, 19.8)
              ..close(),
            _orange,
            onPaintDetails: (c) {
              c.drawPath(
                Path()
                  ..moveTo(8.4, 14.4)
                  ..lineTo(10.6, 16.6)
                  ..lineTo(12.8, 14.4),
                _detailStroke(width: 1.15),
              );
            },
          ),
          _StickerPart(
            Path()
              ..addOval(
                Rect.fromCircle(center: const Offset(10.6, 9.4), radius: 3.6),
              ),
            _skin,
            onPaintDetails: (c) {
              c.drawPath(
                Path()
                  ..moveTo(7.1, 9.2)
                  ..cubicTo(7.2, 5.6, 14.0, 5.6, 14.1, 9.0)
                  ..cubicTo(12.4, 7.8, 9.0, 7.8, 7.1, 9.2)
                  ..close(),
                _detailFill(_navy),
              );
              c.drawCircle(const Offset(9.4, 9.8), 0.48, _detailFill(_navy));
              c.drawCircle(const Offset(11.8, 9.8), 0.48, _detailFill(_navy));
              c.drawArc(
                const Rect.fromLTRB(9.2, 10.2, 12.0, 11.8),
                0.25,
                2.6,
                false,
                _detailStroke(width: 1.0),
              );
              // Band & mic headset teal gaya Bantuan.png
              c.drawArc(
                Rect.fromCircle(center: const Offset(10.6, 9.4), radius: 4.3),
                math.pi + 0.15,
                math.pi - 0.3,
                false,
                _detailStroke(color: _teal, width: 1.45),
              );
            },
          ),
          _StickerPart(
            Path()
              ..addRRect(
                RRect.fromRectAndRadius(
                  const Rect.fromLTRB(5.8, 8.4, 7.6, 11.4),
                  const Radius.circular(0.9),
                ),
              ),
            _teal,
          ),
          _StickerPart(
            Path()
              ..addRRect(
                RRect.fromRectAndRadius(
                  const Rect.fromLTRB(13.6, 8.4, 15.4, 11.4),
                  const Radius.circular(0.9),
                ),
              ),
            _teal,
          ),
          _StickerPart(
            Path()
              ..addRRect(
                RRect.fromRectAndRadius(
                  const Rect.fromLTRB(14.8, 4.0, 20.6, 9.6),
                  const Radius.circular(1.6),
                ),
              ),
            _white,
            onPaintDetails: (c) {
              c.drawPath(
                Path()
                  ..moveTo(16.7, 6.0)
                  ..cubicTo(16.7, 5.0, 18.7, 5.0, 18.7, 6.2)
                  ..cubicTo(18.7, 6.9, 17.7, 7.0, 17.7, 7.6),
                _detailStroke(width: 1.15),
              );
              c.drawCircle(const Offset(17.7, 8.6), 0.55, _detailFill(_navy));
            },
          ),
        ];

      case CourierIconKind.eyeVisible:
      case CourierIconKind.eyeHidden:
      case CourierIconKind.chevronRight:
      case CourierIconKind.refresh:
      case CourierIconKind.errorCircle:
      case CourierIconKind.logout:
      case CourierIconKind.personalAccount:
      case CourierIconKind.courierAccount:
        return const [];
    }
  }

  void _paintUtilityLineIcon(Canvas c) {
    final stroke = Paint()
      ..color = inkColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final solid = Paint()
      ..color = inkColor
      ..style = PaintingStyle.fill;

    switch (kind) {
      case CourierIconKind.eyeVisible:
      case CourierIconKind.eyeHidden:
        final eye = Path()
          ..moveTo(3.0, 12.0)
          ..cubicTo(6.2, 6.4, 17.8, 6.4, 21.0, 12.0)
          ..cubicTo(17.8, 17.6, 6.2, 17.6, 3.0, 12.0)
          ..close();
        c.drawPath(eye, stroke);
        c.drawCircle(const Offset(12, 12), 2.5, stroke);
        c.drawCircle(const Offset(12, 12), 1.0, solid);
        if (kind == CourierIconKind.eyeHidden) {
          c.drawLine(const Offset(4.4, 4.4), const Offset(19.6, 19.6), stroke);
        }
        break;

      case CourierIconKind.chevronRight:
        c.drawPath(
          Path()
            ..moveTo(9.2, 6.4)
            ..lineTo(14.8, 12.0)
            ..lineTo(9.2, 17.6),
          stroke,
        );
        break;

      case CourierIconKind.refresh:
        c.drawArc(
          Rect.fromCircle(center: const Offset(12, 12), radius: 7.2),
          -0.4,
          4.9,
          false,
          stroke,
        );
        c.drawPath(
          Path()
            ..moveTo(15.2, 4.8)
            ..lineTo(18.6, 6.4)
            ..lineTo(17.2, 9.8),
          stroke,
        );
        break;

      case CourierIconKind.errorCircle:
        c.drawCircle(const Offset(12, 12), 8.2, stroke);
        c.drawLine(const Offset(12, 7.8), const Offset(12, 13.0), stroke);
        c.drawCircle(const Offset(12, 16.0), 1.0, solid);
        break;

      case CourierIconKind.logout:
        c.drawPath(
          Path()
            ..moveTo(10.8, 4.8)
            ..lineTo(6.4, 4.8)
            ..quadraticBezierTo(4.6, 4.8, 4.6, 6.6)
            ..lineTo(4.6, 17.4)
            ..quadraticBezierTo(4.6, 19.2, 6.4, 19.2)
            ..lineTo(10.8, 19.2),
          stroke,
        );
        c.drawLine(const Offset(9.8, 12.0), const Offset(19.2, 12.0), stroke);
        c.drawPath(
          Path()
            ..moveTo(15.8, 8.6)
            ..lineTo(19.4, 12.0)
            ..lineTo(15.8, 15.4),
          stroke,
        );
        break;

      case CourierIconKind.personalAccount:
        c.drawCircle(const Offset(12, 8.2), 3.3, stroke);
        c.drawPath(
          Path()
            ..moveTo(5.4, 19.2)
            ..cubicTo(6.0, 15.2, 8.8, 14.2, 12.0, 14.2)
            ..cubicTo(15.2, 14.2, 18.0, 15.2, 18.6, 19.2),
          stroke,
        );
        break;

      case CourierIconKind.courierAccount:
        final bag = RRect.fromRectAndRadius(
          const Rect.fromLTRB(4.2, 8.0, 19.8, 18.8),
          const Radius.circular(2.4),
        );
        c.drawRRect(bag, stroke);
        c.drawPath(
          Path()
            ..moveTo(8.8, 8.0)
            ..lineTo(8.8, 5.8)
            ..quadraticBezierTo(8.8, 4.8, 9.8, 4.8)
            ..lineTo(14.2, 4.8)
            ..quadraticBezierTo(15.2, 4.8, 15.2, 5.8)
            ..lineTo(15.2, 8.0),
          stroke,
        );
        c.drawLine(const Offset(4.2, 12.4), const Offset(19.8, 12.4), stroke);
        break;

      default:
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _CityCourierStickerPainter oldDelegate) {
    return oldDelegate.kind != kind ||
        oldDelegate.inkColor != inkColor ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.isMonochrome != isMonochrome ||
        oldDelegate.isDark != isDark;
  }
}
