import 'package:flutter/material.dart';

/// Logo bank / e-wallet yang digambar lokal (tanpa unduhan gambar).
///
/// Sebelumnya layar pembayaran memuat logo dari URL Midtrans/`iconUrl` backend.
/// Kalau koneksi lambat atau diblokir, kartu pembayaran tampil kosong. Widget
/// ini selalu tersedia offline: kotak bersudut dengan warna khas brand dan
/// kode singkatnya.
///
/// Catatan: ini bukan reproduksi logo resmi (yang merupakan merek dagang).
/// Bila nanti file logo resmi sudah dilisensikan, cukup ganti isi widget ini
/// dengan `Image.asset` — seluruh layar otomatis ikut.
class PaymentBrandLogo extends StatelessWidget {
  /// Nama metode dari backend, mis. "BNI", "BNI Virtual Account", "QRIS".
  final String method;

  final double size;
  final double borderRadius;

  const PaymentBrandLogo({
    super.key,
    required this.method,
    this.size = 44,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final brand = PaymentBrand.fromMethod(method);

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: brand.background,
        borderRadius: BorderRadius.circular(borderRadius),
        border: brand.needsBorder ? Border.all(color: const Color(0xFFE2E8F0)) : null,
      ),
      child: Padding(
        padding: EdgeInsets.all(size * 0.16),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            brand.label,
            maxLines: 1,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: size * 0.32,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
              color: brand.foreground,
            ),
          ),
        ),
      ),
    );
  }
}

/// Pemetaan nama metode → warna & label brand.
class PaymentBrand {
  final String label;
  final Color background;
  final Color foreground;
  final bool needsBorder;

  const PaymentBrand({
    required this.label,
    required this.background,
    required this.foreground,
    this.needsBorder = false,
  });

  static const _blue = Color(0xFF0F4C9C);
  static const _white = Colors.white;
  static const _ink = Color(0xFF0F172A);

  /// Cocokkan berdasarkan kata kunci agar nama panjang dari backend
  /// ("BNI Virtual Account", "DANA E-Wallet") tetap dikenali.
  static PaymentBrand fromMethod(String method) {
    final m = method.trim().toUpperCase();

    if (m.contains('QRIS')) {
      return const PaymentBrand(
        label: 'QRIS',
        background: Colors.white,
        foreground: Color(0xFFE11D48),
        needsBorder: true,
      );
    }
    if (m.contains('BNI')) {
      return const PaymentBrand(label: 'BNI', background: Color(0xFFF15A23), foreground: _white);
    }
    if (m.contains('BRI')) {
      return const PaymentBrand(label: 'BRI', background: Color(0xFF00529C), foreground: _white);
    }
    if (m.contains('BCA')) {
      return const PaymentBrand(label: 'BCA', background: Color(0xFF0060AF), foreground: _white);
    }
    if (m.contains('MANDIRI')) {
      return const PaymentBrand(label: 'mandiri', background: Color(0xFF1A3668), foreground: _white);
    }
    if (m.contains('PERMATA')) {
      return const PaymentBrand(label: 'Permata', background: Color(0xFF009A44), foreground: _white);
    }
    if (m.contains('CIMB')) {
      return const PaymentBrand(label: 'CIMB', background: Color(0xFFB01B2E), foreground: _white);
    }
    if (m.contains('BSI')) {
      return const PaymentBrand(label: 'BSI', background: Color(0xFF00A39D), foreground: _white);
    }
    if (m.contains('BTN')) {
      return const PaymentBrand(label: 'BTN', background: Color(0xFF005E9E), foreground: _white);
    }
    if (m.contains('DANAMON')) {
      return const PaymentBrand(label: 'danamon', background: Color(0xFFFFB700), foreground: _ink);
    }
    if (m.contains('DANA')) {
      return const PaymentBrand(label: 'DANA', background: Color(0xFF118EEA), foreground: _white);
    }
    if (m.contains('OVO')) {
      return const PaymentBrand(label: 'OVO', background: Color(0xFF4C3494), foreground: _white);
    }
    if (m.contains('GOPAY')) {
      return const PaymentBrand(label: 'gopay', background: Color(0xFF00AED6), foreground: _white);
    }
    if (m.contains('SHOPEE')) {
      return const PaymentBrand(label: 'Shopee', background: Color(0xFFEE4D2D), foreground: _white);
    }
    if (m.contains('LINKAJA')) {
      return const PaymentBrand(label: 'LinkAja', background: Color(0xFFE82529), foreground: _white);
    }
    if (m.contains('ALFAMART') || m.contains('INDOMARET')) {
      return const PaymentBrand(label: 'Retail', background: Color(0xFFDC2626), foreground: _white);
    }

    // Tidak dikenal: pakai dua huruf pertama agar tetap terlihat rapi.
    final fallback = m.isEmpty
        ? '?'
        : (m.length >= 3 ? m.substring(0, 3) : m);

    return PaymentBrand(label: fallback, background: _blue, foreground: _white);
  }
}
