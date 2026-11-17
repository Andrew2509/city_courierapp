import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:city_courierapp/data/models/address_model.dart';
import 'package:city_courierapp/screens/location/drop_point_picker_screen.dart';
import 'package:city_courierapp/screens/maps/location_picker_screen.dart';
import 'package:city_courierapp/screens/profile/edit_profile_screen.dart';
import 'package:city_courierapp/services/maps/geocoding_service.dart';
import 'package:city_courierapp/services/maps/location_repository.dart';

class _FakeGeocodingService implements GeocodingService {
  Address? reverseResult;
  final List<Address> searchResults;

  _FakeGeocodingService({
    this.reverseResult,
    this.searchResults = const [],
  });

  @override
  Future<List<Address>> searchAddress(
    String query, {
    double? latitude,
    double? longitude,
    int limit = 5,
  }) async {
    return searchResults;
  }

  @override
  Future<Address?> reverseGeocode(double lat, double lng) async {
    return reverseResult?.copyWith(latitude: lat, longitude: lng);
  }

  @override
  Future<Address?> getPlaceDetails(String placeId) async => null;
}

void main() {
  LocationRepository buildFakeRepo({
    Address? reverseResult,
    List<Address> searchResults = const [],
  }) {
    final fake = _FakeGeocodingService(
      reverseResult: reverseResult,
      searchResults: searchResults,
    );
    return LocationRepository(
      backend: fake,
      nominatim: fake,
      photon: fake,
    );
  }

  testWidgets(
    'Alur lengkap Edit Profil -> Alamat Lengkap -> Pilih dari Peta -> Konfirmasi -> Simpan Profil',
    (tester) async {
      tester.view.physicalSize = const Size(720, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final reverseGeocodedAddress = Address(
        formattedAddress:
            'Jl. Raya Darmo No. 12, Dr. Soetomo, Kec. Tegalsari, Surabaya, Jawa Timur, 60264',
        houseNumber: '12',
        streetName: 'Jl. Raya Darmo',
        village: 'Dr. Soetomo',
        district: 'Tegalsari',
        city: 'Surabaya',
        province: 'Jawa Timur',
        postalCode: '60264',
        latitude: -7.2819,
        longitude: 112.7385,
        locationSource: 'provider',
      );

      final repo = buildFakeRepo(reverseResult: reverseGeocodedAddress);

      String? savedName;
      String? savedAddress;
      bool? popResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  popResult = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditProfileScreen(
                        userData: const {
                          'id': 1,
                          'name': 'Budi Santoso',
                          'email': 'budi@gmail.com',
                          'phone': '081234567890',
                          'phone_verified': true,
                          'address': 'Jl. Lama No. 1, Surabaya',
                        },
                        locationRepository: repo,
                        onSaveProfile: ({
                          required String name,
                          String? email,
                          String? address,
                          String? photoPath,
                        }) async {
                          savedName = name;
                          savedAddress = address;
                          return {'success': true};
                        },
                      ),
                    ),
                  );
                },
                child: const Text('Buka Edit Profil'),
              ),
            ),
          ),
        ),
      );

      // 1. Pengguna membuka Edit Profil.
      await tester.tap(find.text('Buka Edit Profil'));
      await tester.pumpAndSettle();

      expect(find.byType(EditProfileScreen), findsOneWidget);
      expect(find.text('Pilih dari Peta'), findsOneWidget);
      expect(find.text('Jl. Lama No. 1, Surabaya'), findsOneWidget);

      // 2. Pengguna menekan field Alamat Lengkap.
      await tester.tap(find.text('Jl. Lama No. 1, Surabaya'));
      await tester.pumpAndSettle();

      // 3. Tampilan yang muncul sama dengan Pilih dari Peta pada Tambah Alamat
      //    (LocationPickerScreen, bukan DropPointPickerScreen / Pilih Titik Antar).
      expect(find.byType(LocationPickerScreen), findsOneWidget);
      expect(find.byType(DropPointPickerScreen), findsNothing);
      expect(find.text('Pilih Titik Antar'), findsNothing);
      expect(find.text('Set lokasi pengiriman'), findsOneWidget);

      // 4 & 5. Lokasi diambil melalui reverse geocoding dan alamat berhasil ditampilkan.
      expect(
        find.textContaining('Jl. Raya Darmo'),
        findsWidgets,
      );
      expect(
        find.textContaining('Dr. Soetomo, Kec. Tegalsari, Surabaya, 60264'),
        findsOneWidget,
      );

      // 6. Pengguna mengonfirmasi lokasi.
      await tester.tap(find.text('Lanjut'));
      await tester.pumpAndSettle();

      // 7. Pengguna kembali ke Edit Profil & Alamat otomatis terisi.
      expect(find.byType(EditProfileScreen), findsOneWidget);
      expect(
        find.text(
          'Jl. Raya Darmo No. 12, Dr. Soetomo, Kec. Tegalsari, Surabaya, Jawa Timur, 60264',
        ),
        findsOneWidget,
      );

      // 8. Pengguna menyimpan perubahan profil.
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();

      // 9. Alamat baru berhasil tersimpan.
      expect(savedName, 'Budi Santoso');
      expect(
        savedAddress,
        'Jl. Raya Darmo No. 12, Dr. Soetomo, Kec. Tegalsari, Surabaya, Jawa Timur, 60264',
      );
      expect(popResult, isTrue);
    },
  );

  testWidgets(
    'Membatalkan pemilihan lokasi mempertahankan alamat lama di Edit Profil',
    (tester) async {
      tester.view.physicalSize = const Size(720, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final repo = buildFakeRepo(
        reverseResult: Address(
          formattedAddress:
              'Jl. Pemuda No. 39, Embong Kaliasin, Kec. Genteng, Surabaya, Jawa Timur, 60271',
          streetName: 'Jl. Pemuda',
          houseNumber: '39',
          village: 'Embong Kaliasin',
          district: 'Genteng',
          city: 'Surabaya',
          province: 'Jawa Timur',
          postalCode: '60271',
          latitude: -7.2650,
          longitude: 112.7480,
          locationSource: 'provider',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: EditProfileScreen(
            userData: const {
              'id': 1,
              'name': 'Budi Santoso',
              'email': 'budi@gmail.com',
              'phone': '081234567890',
              'phone_verified': true,
              'address': 'Jl. Alamat Awal No. 99, Surabaya',
            },
            locationRepository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tekan tombol Pilih dari Peta / Alamat Lengkap
      await tester.tap(find.text('Pilih dari Peta'));
      await tester.pumpAndSettle();

      expect(find.byType(LocationPickerScreen), findsOneWidget);

      // 10. Pengguna membatalkan pemilihan lokasi (tekan tombol kembali).
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      // Alamat lama tetap dipertahankan.
      expect(find.byType(EditProfileScreen), findsOneWidget);
      expect(find.text('Jl. Alamat Awal No. 99, Surabaya'), findsOneWidget);
    },
  );

  testWidgets(
    'Menyusun komponen alamat lengkap yang tersedia tanpa mengarang data kosong',
    (tester) async {
      tester.view.physicalSize = const Size(720, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // Alamat dengan jalan, kelurahan, kecamatan, kota, provinsi tanpa nomor rumah & tanpa kode pos
      final partialAddress = Address(
        formattedAddress: 'Jl. Ketintang Baru',
        streetName: 'Jl. Ketintang Baru',
        village: 'Ketintang',
        district: 'Gayungan',
        city: 'Surabaya',
        province: 'Jawa Timur',
        postalCode: null,
        houseNumber: null,
        latitude: -7.3150,
        longitude: 112.7280,
        locationSource: 'provider',
      );

      final repo = buildFakeRepo(reverseResult: partialAddress);

      await tester.pumpWidget(
        MaterialApp(
          home: EditProfileScreen(
            userData: const {
              'id': 1,
              'name': 'Siti Aminah',
              'email': 'siti@gmail.com',
              'phone': '081234567890',
              'phone_verified': true,
              'address': '',
            },
            locationRepository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tekan ikon peta pada field Alamat Lengkap
      await tester.tap(find.byIcon(Icons.map_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(LocationPickerScreen), findsOneWidget);

      await tester.tap(find.text('Lanjut'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Jl. Ketintang Baru, Ketintang, Kec. Gayungan, Surabaya, Jawa Timur',
        ),
        findsOneWidget,
      );
    },
  );
}
