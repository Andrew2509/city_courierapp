/// Utilitas untuk mengekstrak wilayah (kecamatan/kota) dari alamat lengkap.
///
/// Geocoder seperti Nominatim gagal memproses alamat yang sangat panjang
/// (mis. "Reny Swalayan, No. 132-134, Jalan Bratang Gede, ... Surabaya").
/// Regional query yang lebih umum jauh lebih mungkin menghasilkan koordinat
/// yang benar, dengan tetap menunjuk ke lokasi pesanan yang sesuai.
library;

/// Ambil string wilayah yang lebih umum dari alamat lengkap.
///
/// Memakai elemen-elemen terakhir alamat yang dipisah koma (umumnya berisi
/// kecamatan, kota, provinsi, kode pos) dan membuang bagian detail alamat
/// di depannya. Mengembalikan String kosong bila tidak ada wilayah yang aman.
String extractRegion(String address) {
  final addr = address.trim();
  if (addr.isEmpty) return '';

  // Pecah per koma, buang elemen kosong.
  final parts = addr
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  if (parts.isEmpty) return '';

  // Ambil maksimal 3 elemen terakhir yang paling mungkin berisi wilayah
  // (kecamatan, kota/kabupaten, provinsi). Elemen terakhir sering kali
  // berupa "JAWA TIMUR 60245" atau "SIDOARJO, JAWA TIMUR 61256".
  int take = parts.length >= 3 ? 3 : parts.length;
  final regionParts = parts.sublist(parts.length - take);
  final region = regionParts.join(', ');

  // Hindari hanya berisi kode pos / nilai kosmetik belaka.
  if (region.replaceAll(RegExp(r'[\d\s,]'), '').length < 3) return '';

  return region;
}
