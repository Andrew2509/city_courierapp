import 'package:flutter/material.dart';

class MapArrowMarker extends StatelessWidget {
  final double size;
  const MapArrowMarker({super.key, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _ArrowPainter(),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
      
    final borderPaint = Paint()
      ..color = Colors.grey.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path = Path();
    // Gambar panah navigasi (khas panah GPS) menghadap ke ATAS (North)
    path.moveTo(size.width / 2, 0); // Puncak Atas
    path.lineTo(size.width, size.height); // Kanan bawah
    path.lineTo(size.width / 2, size.height * 0.7); // Tengah bawah (lekukan dalam)
    path.lineTo(0, size.height); // Kiri bawah
    path.close();

    // Gambar bayangan/border
    canvas.drawPath(path, borderPaint);
    // Isi dengan warna putih
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
