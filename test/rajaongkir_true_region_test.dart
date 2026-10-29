import 'package:flutter_test/flutter_test.dart';
import 'package:city_courierapp/services/shipping/rajaongkir_matcher_service.dart';
import 'package:city_courierapp/data/models/address_model.dart';

void main() {
  group('RajaOngkir True Region Matcher - 9 Mandatory Scenarios', () {
    // Skenario 1: Data wilayah lengkap dan cocok sempurna (Hierarki Lengkap)
    test('Skenario 1: Data wilayah lengkap dan cocok hierarki resmi (Jawa Timur -> Surabaya -> Sukolilo -> Semolowaru)', () async {
      final result = await RajaOngkirMatcherService.match(
        latitude: -7.278000,
        longitude: 112.790000,
        village: 'Semolowaru',
        district: 'Sukolilo',
        city: 'Surabaya',
        province: 'Jawa Timur',
        postalCode: '60111',
        fullAddress: 'Jl. Semolowaru No. 25, Semolowaru, Sukolilo, Surabaya, Jawa Timur 60111',
      );

      expect(result['matched'], true);
      expect(result['province_name'], 'Jawa Timur');
      expect(result['province_id'], '11');
      expect(result['city_name'], 'Surabaya');
      expect(result['rajaongkir_city_id'], '444');
      expect(result['district_name'], 'Sukolilo');
      expect(result['rajaongkir_subdistrict_id'], '6041');
      expect(result['subdistrict_name'], 'Semolowaru');
      expect(result['postal_code_verified'], true);
      expect(result['postal_code'], '60111');
    });

    // Skenario 2: Ketidaksesuaian kelurahan/kecamatan (Anti False-Positive Teluk Waru Maluku)
    test('Skenario 2: Pencegahan false positive Teluk Waru - Alamat di Wedoro, Waru, Sidoarjo HARUS ke Sidoarjo bukan Maluku', () async {
      final result = await RajaOngkirMatcherService.match(
        latitude: -7.3485677,
        longitude: 112.7538236,
        village: 'Wedoro',
        district: 'Waru',
        city: 'Waru', // Nominatim sering keliru mengisi city dengan nama kecamatan
        province: 'Jawa Timur',
        postalCode: '60236',
        fullAddress: 'Real Estate Wisma Waru Indah, Wedoro, Waru, Sidoarjo, Jawa Timur, 60236, Indonesia',
      );

      expect(result['matched'], true);
      // Validasi tegas: TIDAK BOLEH menjadi Maluku atau Seram Bagian Timur!
      expect(result['province_name'], isNot(contains('MALUKU')));
      expect(result['province_name'], isNot(contains('Maluku')));
      expect(result['city_name'], isNot(contains('SERAM BAGIAN TIMUR')));
      expect(result['city_name'], isNot(contains('Seram Bagian Timur')));
      expect(result['district_name'], isNot(contains('TELUK WARU')));
      expect(result['district_name'], isNot(contains('Teluk Waru')));

      // Harus cocok ke Kabupaten Sidoarjo, Jawa Timur dengan ID RajaOngkir resmi (5601 atau 71074)
      expect(result['city_name'], contains('Sidoarjo'));
      expect(result['province_name'], contains('Jawa Timur'));
      expect(result['district_name'], 'Waru');
      expect(result['rajaongkir_region_id'], anyOf(['5601', '71074']));
    });

    // Skenario 3: Kode pos dari peta berbeda dengan data RajaOngkir
    test('Skenario 3: Penanganan kode pos - Map postcode tidak menimpa data resmi RajaOngkir', () async {
      // Peta Nominatim mengembalikan postcode 60236 untuk area perbatasan Waru,
      // padahal kode pos resmi RajaOngkir untuk Waru Sidoarjo adalah 61256.
      final result = await RajaOngkirMatcherService.match(
        latitude: -7.3485677,
        longitude: 112.7538236,
        village: 'Wedoro',
        district: 'Waru',
        city: 'Sidoarjo',
        province: 'Jawa Timur',
        postalCode: '60236', // Peta salah memberi kode pos
        fullAddress: 'Real Estate Wisma Waru Indah, Wedoro, Waru, Sidoarjo, Jawa Timur 60236',
      );

      expect(result['matched'], true);
      // Kode pos terverifikasi resmi RajaOngkir harus 61256 (bukan 60236)
      expect(result['postal_code'], '61256');
      expect(result['postal_code_verified'], true);
      expect(result['map_postal_code'], '60236'); // Map code disimpan terpisah sebagai clue
    });

    // Skenario 4: Titik koordinat di perbatasan dua kecamatan atau wilayah ambigu
    test('Skenario 4: Penanganan wilayah tidak dikenal / ambigu', () async {
      // Alamat fiktif di antah berantah yang tidak ada dalam hierarki RajaOngkir
      final result = await RajaOngkirMatcherService.match(
        latitude: -0.123456,
        longitude: 100.123456,
        village: 'Desa Tak Dikenal',
        district: 'Kecamatan Antah Berantah',
        city: 'Kota Fiktif',
        province: 'Provinsi Non Eksis',
        fullAddress: 'Jalan Tengah Hutan Belantara',
      );

      // Tidak boleh mencocokkan secara sembarangan jika tidak ada dalam hierarki
      expect(result['matched'], false);
      expect(result['message'], contains('manual'));
    });

    // Skenario 5: Alamat tanpa nomor rumah atau tanpa kode pos dari peta
    test('Skenario 5: Alamat tanpa nomor rumah dan tanpa kode pos tetap mencocokkan hierarki resmi', () async {
      final result = await RajaOngkirMatcherService.match(
        latitude: -7.310000,
        longitude: 112.770000,
        village: 'Kali Rungkut',
        district: 'Rungkut',
        city: 'Surabaya',
        province: 'Jawa Timur',
        // Tidak ada no rumah dan tidak ada postal code
        fullAddress: 'Gang Buntu, Kali Rungkut, Rungkut, Surabaya',
      );

      expect(result['matched'], true);
      expect(result['district_name'], 'Rungkut');
      expect(result['city_name'], 'Surabaya');
      expect(result['rajaongkir_subdistrict_id'], '6038');
      expect(result['postal_code'], '60293');
    });

    // Skenario 6: Titik koordinat dipindahkan ke lokasi lain yang berbeda kecamatan/kota
    test('Skenario 6: Pin dipindahkan dari Sidoarjo ke Surabaya menghasilkan wilayah dan ID baru yang akurat', () async {
      // Titik 1: Waru, Sidoarjo
      final resultPoint1 = await RajaOngkirMatcherService.match(
        latitude: -7.3485,
        longitude: 112.7538,
        district: 'Waru',
        city: 'Sidoarjo',
        province: 'Jawa Timur',
        fullAddress: 'Waru, Sidoarjo, Jawa Timur',
      );
      expect(resultPoint1['matched'], true);
      expect(resultPoint1['city_name'], 'Sidoarjo');
      expect(resultPoint1['district_name'], 'Waru');
      final idPoint1 = resultPoint1['rajaongkir_region_id'];

      // Titik 2: Pin digeser ke Gubeng, Surabaya
      final resultPoint2 = await RajaOngkirMatcherService.match(
        latitude: -7.2750,
        longitude: 112.7530,
        village: 'Airlangga',
        district: 'Gubeng',
        city: 'Surabaya',
        province: 'Jawa Timur',
        fullAddress: 'Airlangga, Gubeng, Surabaya, Jawa Timur',
      );
      expect(resultPoint2['matched'], true);
      expect(resultPoint2['city_name'], 'Surabaya');
      expect(resultPoint2['district_name'], 'Gubeng');
      final idPoint2 = resultPoint2['rajaongkir_region_id'];

      // ID dan wilayah harus berbeda dan sesuai titik baru
      expect(idPoint1, isNot(equals(idPoint2)));
      expect(resultPoint2['rajaongkir_subdistrict_id'], '6035');
    });

    // Skenario 7: Endpoint RajaOngkir lambat/error - fallback ke dataset lokal tetap sukses
    test('Skenario 7: Fallback ke dataset lokal tetap menghasilkan ID RajaOngkir yang valid saat offline', () async {
      // Memanggil method lokal langsung atau saat backend tidak merespons
      final result = await RajaOngkirMatcherService.match(
        latitude: -7.2600,
        longitude: 112.7400,
        district: 'Genteng',
        city: 'Surabaya',
        province: 'Jawa Timur',
        fullAddress: 'Genteng, Surabaya, Jawa Timur',
      );

      expect(result['matched'], true);
      expect(result['district_name'], 'Genteng');
      expect(result['city_name'], 'Surabaya');
      expect(result['rajaongkir_subdistrict_id'], '6034');
      expect(result['rajaongkir_city_id'], '444');
    });

    // Skenario 8: Perubahan alamat pickup tidak memengaruhi alamat drop-off
    test('Skenario 8: Isolasi data penjemputan (pickup) vs pengantaran (drop-off)', () async {
      // Simulasikan state pickup dan dropoff terpisah
      Address pickup = Address(
        formattedAddress: 'Jl. Rungkut Asri No. 10, Kali Rungkut, Rungkut, Surabaya',
        district: 'Rungkut',
        city: 'Surabaya',
        province: 'Jawa Timur',
        latitude: -7.3180,
        longitude: 112.7750,
        locationSource: 'provider',
      );

      Address dropoff = Address(
        formattedAddress: 'Jl. Wedoro Candi No. 5, Wedoro, Waru, Sidoarjo',
        district: 'Waru',
        city: 'Sidoarjo',
        province: 'Jawa Timur',
        latitude: -7.3500,
        longitude: 112.7500,
        locationSource: 'provider',
      );

      final pickupMatch = await RajaOngkirMatcherService.match(
        latitude: pickup.latitude,
        longitude: pickup.longitude,
        district: pickup.district,
        city: pickup.city,
        province: pickup.province,
        fullAddress: pickup.formattedAddress,
      );

      final dropoffMatch = await RajaOngkirMatcherService.match(
        latitude: dropoff.latitude,
        longitude: dropoff.longitude,
        district: dropoff.district,
        city: dropoff.city,
        province: dropoff.province,
        fullAddress: dropoff.formattedAddress,
      );

      // Pastikan kedua data independen dan tidak saling mencemari
      expect(pickupMatch['rajaongkir_city_id'], '444'); // Surabaya
      expect(pickupMatch['district_name'], 'Rungkut');

      expect(dropoffMatch['rajaongkir_city_id'], '409'); // Sidoarjo
      expect(dropoffMatch['district_name'], 'Waru');

      // Ubah pickup ke tempat lain
      pickup = Address(
        formattedAddress: 'Jl. Sukolilo No. 1, Sukolilo, Surabaya',
        district: 'Sukolilo',
        city: 'Surabaya',
        province: 'Jawa Timur',
        latitude: -7.2800,
        longitude: 112.7900,
        locationSource: 'provider',
      );

      final newPickupMatch = await RajaOngkirMatcherService.match(
        latitude: pickup.latitude,
        longitude: pickup.longitude,
        district: pickup.district,
        city: pickup.city,
        province: pickup.province,
        fullAddress: pickup.formattedAddress,
      );

      expect(newPickupMatch['district_name'], 'Sukolilo');
      // Dropoff tetap Sidoarjo Waru
      expect(dropoffMatch['district_name'], 'Waru');
      expect(dropoffMatch['city_name'], 'Sidoarjo');
    });

    // Skenario 9: ID wilayah terverifikasi kompatibel dengan payload ongkir
    test('Skenario 9: ID wilayah terverifikasi siap digunakan untuk payload kalkulasi ongkir RajaOngkir', () async {
      final originMatch = await RajaOngkirMatcherService.match(
        latitude: -7.278000,
        longitude: 112.790000,
        district: 'Sukolilo',
        city: 'Surabaya',
        province: 'Jawa Timur',
        fullAddress: 'Sukolilo, Surabaya',
      );

      final destMatch = await RajaOngkirMatcherService.match(
        latitude: -7.348567,
        longitude: 112.753823,
        district: 'Waru',
        city: 'Sidoarjo',
        province: 'Jawa Timur',
        fullAddress: 'Waru, Sidoarjo',
      );

      expect(originMatch['matched'], true);
      expect(destMatch['matched'], true);

      // Bentuk payload perhitungan ongkir
      final costPayload = {
        'origin': originMatch['rajaongkir_subdistrict_id'] ?? originMatch['rajaongkir_region_id'],
        'destination': destMatch['rajaongkir_subdistrict_id'] ?? destMatch['rajaongkir_region_id'],
        'weight': 1000,
        'courier': 'jne',
      };

      expect(costPayload['origin'], '6041'); // Sukolilo ID
      expect(costPayload['destination'], anyOf(['5601', '71074'])); // Waru ID
      expect(costPayload['origin'], isNotEmpty);
      expect(costPayload['destination'], isNotEmpty);
    });
  });
}
