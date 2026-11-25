import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:city_courierapp/screens/home/shipping/select_district_screen.dart';
import 'package:city_courierapp/screens/home/shipping/select_regency_screen.dart';
import 'package:city_courierapp/screens/home/shipping/select_region_screen.dart';
import 'package:city_courierapp/screens/home/shipping/select_subdistrict_screen.dart';
import 'package:city_courierapp/services/shipping/rajaongkir_service.dart';
import 'package:city_courierapp/services/token_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await TokenStore.clear();
    RajaOngkirService.httpGetOverride = null;
  });

  tearDown(() {
    RajaOngkirService.httpGetOverride = null;
  });

  test('RajaOngkirService menangani 401 dan HTML error dengan aman tanpa login',
      () async {
    RajaOngkirService.httpGetOverride = (uri, headers) async {
      expect(headers.containsKey('Authorization'), isFalse);
      return http.Response(jsonEncode({'message': 'Unauthenticated.'}), 401);
    };

    final unauthRes = await RajaOngkirService.getProvinces();
    expect(unauthRes['success'], isFalse);
    expect(unauthRes['status_code'], 401);
    expect(unauthRes['message'], isNotEmpty);

    RajaOngkirService.httpGetOverride = (uri, headers) async {
      return http.Response('<!DOCTYPE html><html>Redirect</html>', 302);
    };
    final htmlRes = await RajaOngkirService.getCities(11);
    expect(htmlRes['success'], isFalse);
    expect(htmlRes['message'], contains('Gagal mengambil data kota/kabupaten'));

    RajaOngkirService.httpGetOverride = (uri, headers) async {
      throw TimeoutException('Future not completed');
    };
    final timeoutRes = await RajaOngkirService.getProvinces();
    expect(timeoutRes['success'], isFalse);
    expect(timeoutRes['message'], contains('Waktu koneksi ke server habis'));
    expect(timeoutRes['message'], isNot(contains('TimeoutException')));
  });

  testWidgets(
      'SelectRegionScreen menampilkan daftar provinsi saat logout dan mendukung retry saat error',
      (tester) async {
    int calls = 0;
    RajaOngkirService.httpGetOverride = (uri, headers) async {
      calls++;
      expect(headers.containsKey('Authorization'), isFalse);
      if (calls == 1) {
        return http.Response(jsonEncode({'message': 'Unauthenticated.'}), 401);
      }
      return http.Response(
        jsonEncode({
          'success': true,
          'data': [
            {'province_id': '11', 'province': 'Jawa Timur'},
            {'province_id': '6', 'province': 'DKI Jakarta'},
          ],
        }),
        200,
      );
    };

    await tester.pumpWidget(
      const MaterialApp(home: SelectRegionScreen()),
    );
    await tester.pumpAndSettle();

    // Saat 401, tampilkan pesan error + tombol Coba Lagi (bukan "Provinsi tidak ditemukan")
    expect(find.text('Provinsi tidak ditemukan'), findsNothing);
    expect(find.text('Coba Lagi'), findsOneWidget);

    // Tekan Coba Lagi -> respons 200 tanpa token -> provinsi tampil
    await tester.tap(find.text('Coba Lagi'));
    await tester.pumpAndSettle();

    expect(find.text('2 Provinsi'), findsOneWidget);
    expect(find.text('38 Kota / Kabupaten'), findsOneWidget);
    expect(find.text('6 Kota Administratif'), findsOneWidget);
  });

  testWidgets(
      'SelectRegencyScreen, SelectDistrictScreen, dan SelectSubDistrictScreen tampil normal saat logout',
      (tester) async {
    RajaOngkirService.httpGetOverride = (uri, headers) async {
      expect(headers.containsKey('Authorization'), isFalse);
      if (uri.path.endsWith('/cities')) {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': [
              {'city_id': '444', 'city_name': 'Surabaya', 'type': 'Kota'},
            ],
          }),
          200,
        );
      }
      if (uri.path.endsWith('/districts')) {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': [
              {'subdistrict_id': '3550', 'subdistrict_name': 'Sukolilo'},
            ],
          }),
          200,
        );
      }
      return http.Response(
        jsonEncode({
          'success': true,
          'data': [
            {
              'id': '7001',
              'name': 'Menur Pumpungan',
              'zip_code': '60118',
            },
          ],
        }),
        200,
      );
    };

    await tester.pumpWidget(
      const MaterialApp(
        home: SelectRegencyScreen(provinsiId: 11, provinsiName: 'Jawa Timur'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Kota Surabaya'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: SelectDistrictScreen(
          provinsiId: 11,
          provinsiName: 'Jawa Timur',
          kabupatenId: 444,
          kabupatenName: 'Kota Surabaya',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sukolilo'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: SelectSubDistrictScreen(
          provinsiId: 11,
          provinsiName: 'Jawa Timur',
          kabupatenId: 444,
          kabupatenName: 'Kota Surabaya',
          kecamatanId: 3550,
          kecamatanName: 'Sukolilo',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Menur Pumpungan'), findsOneWidget);
  });
}
