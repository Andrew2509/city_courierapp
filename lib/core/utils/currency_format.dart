/// Pemformatan nominal Rupiah untuk modul Dompet & penarikan.
///
/// Dipakai bersama oleh halaman Dompet, Tarik Dana, Riwayat, dan Detail
/// transaksi agar format angka konsisten di seluruh alur.
library;

/// `250000` → `Rp 250.000`
String formatRupiah(num value, {bool withPrefix = true}) {
  final negative = value < 0;
  final digits = value.abs().toStringAsFixed(0);
  final grouped = digits.replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]}.',
  );

  final text = withPrefix ? 'Rp $grouped' : grouped;
  return negative ? '-$text' : text;
}

/// Nomor tanpa prefix untuk dipakai di dalam input (`250.000`).
String formatRupiahDigits(num value) => formatRupiah(value, withPrefix: false);
