import 'package:flutter_test/flutter_test.dart';
import 'package:city_courierapp/services/shipping/rajaongkir_parser.dart';
import 'package:city_courierapp/screens/home/shipping/select_courier_screen.dart';
import 'package:flutter/material.dart';

void main() {
  group('RajaOngkirParser - Unit Tests', () {
    // TEST 1: Kurir Reguler
    test('Test 1: Kurir Reguler (JNE REG, cost: 16000, etd: 2-3)', () {
      final input = [
        {
          'name': 'JNE',
          'code': 'jne',
          'service': 'REG',
          'description': 'Layanan Reguler',
          'cost': 16000,
          'etd': '2-3',
        }
      ];

      final result = RajaOngkirParser.parseCouriers(input);
      expect(result.length, 1);
      expect(result[0]['name'], 'JNE');
      expect(result[0]['service'], 'REG');
      expect(result[0]['price'], 16000);
      expect(result[0]['duration'], 'Estimasi 2–3 hari');
      expect(result[0]['is_sameday'], false);
    });

    // TEST 2: Same-Day
    test('Test 2: Layanan Instant / Same-Day', () {
      final input = [
        {
          'name': 'Instant Delivery',
          'code': 'instant',
          'service': 'Instant',
          'description': 'Layanan Same Day',
          'cost': 20000,
          'etd': 'Sameday',
        }
      ];

      final result = RajaOngkirParser.parseCouriers(input);
      expect(result.length, 1);
      expect(result[0]['name'], 'Instant Delivery');
      expect(result[0]['service'], 'Instant');
      expect(result[0]['price'], 20000);
      expect(result[0]['duration'], 'Tiba hari ini');
      expect(result[0]['is_sameday'], true);
    });

    // TEST 3: Data Kurir Kosong / 'UNKNOWN'
    test('Test 3: Nama kurir kosong atau bertuliskan UNKNOWN di-resolve dengan benar', () {
      final inputWithUnknown = [
        {
          'name': 'UNKNOWN',
          'code': 'sicepat',
          'service': 'HALU',
          'description': 'Harga Mulai Lima Ribu',
          'cost': 12000,
          'etd': '2-3',
        },
        {
          'name': null,
          'code': 'jnt',
          'service': 'EZ',
          'description': 'Reguler',
          'cost': 14000,
          'etd': '1-2',
        },
        {
          'name': 'UNKNOWN ECO',
          'code': 'jnt',
          'service': 'ECO',
          'cost': 10000,
          'etd': '2-3',
        },
      ];

      final result = RajaOngkirParser.parseCouriers(inputWithUnknown);
      for (var courier in result) {
        expect(courier['name'].toString().toUpperCase().contains('UNKNOWN'), false,
            reason: 'Nama kurir tidak boleh mengandung kata UNKNOWN');
      }

      expect(result.any((c) => c['name'] == 'SiCepat'), true);
      expect(result.any((c) => c['name'] == 'J&T Express'), true);
    });

    // TEST 4: ETD Kosong & Formatter Khusus
    test('Test 4: Format ETD membersihkan "day hari", menangani null/kosong/undefined', () {
      expect(RajaOngkirParser.formatEtd(null), 'Estimasi tidak tersedia');
      expect(RajaOngkirParser.formatEtd(''), 'Estimasi tidak tersedia');
      expect(RajaOngkirParser.formatEtd('undefined'), 'Estimasi tidak tersedia');
      expect(RajaOngkirParser.formatEtd('UNKNOWN'), 'Estimasi tidak tersedia');
      expect(RajaOngkirParser.formatEtd('null'), 'Estimasi tidak tersedia');

      // Menghilangkan duplikasi 'day hari'
      expect(RajaOngkirParser.formatEtd('3 day hari'), 'Estimasi 3 hari');
      expect(RajaOngkirParser.formatEtd('4 day'), 'Estimasi 4 hari');
      expect(RajaOngkirParser.formatEtd('2-3 day hari'), 'Estimasi 2–3 hari');
      expect(RajaOngkirParser.formatEtd('2-3 HARI'), 'Estimasi 2–3 hari');
      expect(RajaOngkirParser.formatEtd('1'), 'Estimasi 1 hari');
      expect(RajaOngkirParser.formatEtd('1-2'), 'Estimasi 1–2 hari');
      expect(RajaOngkirParser.formatEtd('Sameday'), 'Tiba hari ini');
      expect(RajaOngkirParser.formatEtd('Instant'), 'Tiba hari ini');
    });

    // TEST: Prioritisasi Same-Day (Poin 5)
    test('Poin 5: Layanan Same-Day otomatis diprioritaskan di posisi teratas', () {
      final input = [
        {
          'name': 'JNE',
          'code': 'jne',
          'service': 'REG',
          'cost': 16000,
          'etd': '2-3',
        },
        {
          'name': 'Instant',
          'code': 'instant',
          'service': 'Instant',
          'cost': 25000,
          'etd': '0',
        },
        {
          'name': 'SiCepat',
          'code': 'sicepat',
          'service': 'HALU',
          'cost': 12000,
          'etd': '2-3',
        },
      ];

      final result = RajaOngkirParser.parseCouriers(input);
      // Instant harus berada di index 0 meskipun harganya 25.000 (karena same-day priority)
      expect(result[0]['is_sameday'], true);
      expect(result[0]['name'], 'Instant');
      expect(result[0]['duration'], 'Tiba hari ini');
    });

    // TEST: Support format Nested RajaOngkir standard
    test('Support response format nested standar RajaOngkir', () {
      final nestedResponse = {
        'rajaongkir': {
          'results': [
            {
              'code': 'jne',
              'name': 'Jalur Nugraha Ekakurir (JNE)',
              'costs': [
                {
                  'service': 'REG',
                  'description': 'Layanan Reguler',
                  'cost': [
                    {'value': 16000, 'etd': '2-3', 'note': ''}
                  ]
                }
              ]
            }
          ]
        }
      };

      final result = RajaOngkirParser.parseCouriers(nestedResponse);
      expect(result.length, 1);
      expect(result[0]['name'], 'Jalur Nugraha Ekakurir (JNE)');
      expect(result[0]['service'], 'REG');
      expect(result[0]['price'], 16000);
      expect(result[0]['duration'], 'Estimasi 2–3 hari');
    });
  });

  group('SelectCourierScreen - Widget Tests (Instant Courier GoSend Concept)', () {
    testWidgets('SelectCourierScreen menampilkan PILIH KENDARAAN, Motor, Mobil, dan bebas UNKNOWN',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SelectCourierScreen(
            originName: 'Surabaya Pusat',
            destinationName: 'Sidoarjo Waru',
            weight: 2000,
            referenceNow: DateTime(2026, 10, 28, 10, 0), // 10:00 AM operasional buka
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Cek header dan ringkasan pengiriman
      expect(find.text('PILIH KENDARAAN'), findsNWidgets(2));
      expect(find.text('RINGKASAN PENGIRIMAN'), findsOneWidget);
      expect(find.text('2 kg'), findsOneWidget);
      expect(find.text('Surabaya Pusat'), findsOneWidget);
      expect(find.text('Sidoarjo Waru'), findsOneWidget);

      // Pastikan kata 'UNKNOWN', 'undefined', 'null', 'day hari' tidak pernah ada di seluruh screen
      expect(find.textContaining('UNKNOWN'), findsNothing);
      expect(find.textContaining('day hari'), findsNothing);
      expect(find.textContaining('undefined'), findsNothing);

      // Verifikasi komponen kendaraan on-demand City Courier (Motor & Mobil)
      expect(find.text('Motor'), findsOneWidget);
      expect(find.text('Mobil'), findsOneWidget);
      expect(find.text('Cocok untuk barang kecil'), findsOneWidget);
      expect(find.text('Cocok untuk barang besar'), findsOneWidget);

      // Tidak menampilkan ekspedisi reguler (JNE, SiCepat, HALU, ECO)
      expect(find.text('JNE'), findsNothing);
      expect(find.text('SiCepat'), findsNothing);
      expect(find.text('HALU'), findsNothing);
      expect(find.text('ECO'), findsNothing);
      expect(find.textContaining('2–3 hari'), findsNothing);

      // Verifikasi bottom bar
      expect(find.text('Biaya Pengiriman Terpilih:'), findsOneWidget);
      expect(find.text('Pilih Kendaraan'), findsOneWidget);
    });
  });
}
