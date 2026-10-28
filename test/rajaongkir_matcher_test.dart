import 'package:flutter_test/flutter_test.dart';
import 'package:city_courierapp/services/shipping/rajaongkir_matcher_service.dart';

void main() {
  group('RajaOngkirMatcherService Tests', () {
    test('Membersihkan nama wilayah dari prefix administratif', () {
      expect(RajaOngkirMatcherService.cleanName('Kelurahan Semolowaru'), 'semolowaru');
      expect(RajaOngkirMatcherService.cleanName('Kecamatan Sukolilo'), 'sukolilo');
      expect(RajaOngkirMatcherService.cleanName('Kota Surabaya'), 'surabaya');
      expect(RajaOngkirMatcherService.cleanName('Provinsi Jawa Timur'), 'jawa timur');
    });

    test('Pencocokan Semolowaru, Sukolilo, Surabaya berhasil', () async {
      final result = await RajaOngkirMatcherService.match(
        latitude: -7.278000,
        longitude: 112.790000,
        village: 'Semolowaru',
        district: 'Sukolilo',
        city: 'Surabaya',
        province: 'Jawa Timur',
        fullAddress: 'Jl. Semolowaru No. 25, Semolowaru, Sukolilo, Surabaya',
      );

      expect(result['matched'], true);
      expect(result['city_name'], contains('Surabaya'));
      expect(result['district_name'], contains('Sukolilo'));
      expect(result['rajaongkir_city_id'], isNotNull);
      expect(result['rajaongkir_subdistrict_id'], isNotNull);
    });

    test('Pencocokan Sidoarjo (Waru / Wedoro) berhasil', () async {
      final result = await RajaOngkirMatcherService.match(
        latitude: -7.350000,
        longitude: 112.730000,
        village: 'Wedoro',
        district: 'Waru',
        city: 'Sidoarjo',
        province: 'Jawa Timur',
        fullAddress: 'Wedoro, Waru, Sidoarjo',
      );

      expect(result['matched'], true);
      expect(result['city_name'], contains('Sidoarjo'));
      expect(result['district_name'], contains('Waru'));
    });

    test('Pencocokan via full address text fallback', () async {
      final result = await RajaOngkirMatcherService.match(
        latitude: -7.278000,
        longitude: 112.790000,
        fullAddress: 'Jl. Raya Manyar, Menur Pumpungan, Sukolilo, Kota Surabaya',
      );

      expect(result['matched'], true);
      expect(result['city_name'], contains('Surabaya'));
    });
  });
}
