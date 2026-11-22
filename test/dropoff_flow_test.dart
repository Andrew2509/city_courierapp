import 'dart:async';

import 'package:city_courierapp/models/drop_point.dart';
import 'package:city_courierapp/models/payment/payment_method.dart';
import 'package:city_courierapp/models/shipping/shipment_model.dart';
import 'package:city_courierapp/models/shipping/tracking_model.dart';
import 'package:city_courierapp/models/wallet/wallet_models.dart';
import 'package:city_courierapp/screens/home/drop_point/drop_point_screen.dart';
import 'package:city_courierapp/screens/home/dropoff/dropoff_screen.dart';
import 'package:city_courierapp/screens/home/dropoff/dropoff_service_selection_screen.dart';
import 'package:city_courierapp/screens/home/shipping/add_sender_screen.dart';
import 'package:city_courierapp/screens/home/shipping/confirmation_screen.dart';
import 'package:city_courierapp/screens/home/shipping/item_info_screen.dart';
import 'package:city_courierapp/screens/home/shipping/payment/direct_payment_confirmation_screen.dart';
import 'package:city_courierapp/screens/home/shipping/payment_method_screen.dart';
import 'package:city_courierapp/screens/wallet/wallet_payment_confirmation_screen.dart';
import 'package:city_courierapp/services/payment/payment_service.dart';
import 'package:city_courierapp/services/provider_availability_service.dart';
import 'package:city_courierapp/services/wallet/customer_wallet_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

class _FakeWalletService extends CustomerWalletService {
  CustomerWalletSummary summary;
  int payCallCount = 0;
  Duration payDelay;

  _FakeWalletService({
    required this.summary,
    this.payDelay = Duration.zero,
  });

  @override
  Future<CustomerWalletSummary> getWallet() async => summary;

  @override
  Future<Map<String, dynamic>> payOrderWithWallet({
    int? shipmentId,
    int? orderId,
    String? idempotencyKey,
    String? transactionPin,
  }) async {
    payCallCount++;
    if (payDelay > Duration.zero) {
      await Future.delayed(payDelay);
    }
    return {
      'payment_transaction': {
        'reference': 'WALLET-REF-991',
        'amount': 24000,
        'mode': 'sandbox',
      },
      'wallet_available_balance': summary.availableBalance - 24000,
    };
  }
}

CustomerWalletSummary _walletSummary({
  required int availableBalance,
  bool isFrozen = false,
}) {
  return CustomerWalletSummary(
    walletId: 1,
    walletType: 'customer',
    currency: 'IDR',
    status: isFrozen ? 'frozen' : 'active',
    isFrozen: isFrozen,
    availableBalance: availableBalance,
    pendingBalance: 0,
    reservedBalance: 0,
    totalCredited: availableBalance,
    totalDebited: 0,
    mode: 'sandbox',
    isSandboxOrDemo: true,
    activePaymentProvider: 'ipaymu',
    withdrawalEnabled: true,
    withdrawalMinIdr: 10000,
    withdrawalMaxIdr: 5000000,
    topupMinIdr: 10000,
    topupMaxIdr: 10000000,
  );
}

List<Map<String, dynamic>> _sampleDropPoints() => [
  {
    'id': 10,
    'name': 'City Courier Hub Grogol',
    'address': 'Jl. Latumenten No. 12, Jakarta Barat',
    'phone': '081211112222',
    'schedule': '24 Jam',
    'rating': 4.9,
    'latitude': -6.1665,
    'longitude': 106.7905,
    'is_active': true,
    'city_id': '151',
    'subdistrict_id': '2095',
    'city_name': 'Jakarta Barat',
    'subdistrict_name': 'Grogol Petamburan',
    'postal_code': '11460',
  },
  {
    'id': 11,
    'name': 'City Courier Agen Kemang',
    'address': 'Jl. Kemang Raya No. 88, Jakarta Selatan',
    'phone': '081233334444',
    'schedule': '08:00 - 20:00',
    'rating': 4.7,
    'latitude': -6.2605,
    'longitude': 106.8141,
    'is_active': true,
    'city_id': '153',
    'subdistrict_id': '2110',
    'city_name': 'Jakarta Selatan',
    'subdistrict_name': 'Mampang Prapatan',
  },
];

Map<String, dynamic> _sampleSenderAddress() => {
  'id': 1,
  'name': 'Budi Pengirim',
  'phone': '081234567890',
  'province_id': '6',
  'province_name': 'DKI Jakarta',
  'city_id': '151',
  'city_name': 'Jakarta Barat',
  'kecamatan_id': '2095',
  'kecamatan_name': 'Grogol Petamburan',
  'subdistrict_id': '2095',
  'kelurahan_name': 'Tomang',
  'address': 'Jl. Tomang Raya No. 10',
  'postal_code': '11440',
};

Map<String, dynamic> _sampleReceiverAddress() => {
  'id': 2,
  'name': 'Sari Penerima',
  'phone': '081398765432',
  'province_id': '11',
  'province_name': 'Jawa Timur',
  'city_id': '444',
  'city_name': 'Surabaya',
  'kecamatan_id': '6154',
  'kecamatan_name': 'Gubeng',
  'subdistrict_id': '6154',
  'kelurahan_name': 'Airlangga',
  'address': 'Jl. Dharmawangsa No. 45',
  'postal_code': '60286',
};

Future<Map<String, dynamic>> _fakeCostFetcher({
  required String origin,
  required String destination,
  required int weight,
  required String courier,
}) async {
  return {
    'success': true,
    'data': [
      {
        'name': 'JNE',
        'code': 'jne',
        'service': 'REG',
        'description': 'Layanan Reguler',
        'cost': 24000,
        'etd': '2-3 hari',
      },
      {
        'name': 'JNE',
        'code': 'jne',
        'service': 'YES',
        'description': 'Yakin Esok Sampai Express',
        'cost': 42000,
        'etd': '1 hari',
      },
    ],
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    ProviderAvailabilityService.clearCache();
    ProviderAvailabilityService.testSettingsFetcher = () async => {
      'payment': {'ipaymu': true},
    };
  });

  tearDown(() {
    ProviderAvailabilityService.clearCache();
    ProviderAvailabilityService.testSettingsFetcher = null;
  });

  group('Dropoff Models, Validations & Lifecycle', () {
    test('DropPoint parses and serializes RajaOngkir origin fields safely', () {
      final point = DropPoint.fromJson(_sampleDropPoints().first);
      expect(point.id, 10);
      expect(point.name, 'City Courier Hub Grogol');
      expect(point.cityId, '151');
      expect(point.subdistrictId, '2095');
      expect(point.postalCode, '11460');

      final map = point.toMap();
      expect(map['city_id'], '151');
      expect(map['subdistrict_id'], '2095');
      expect(map['postal_code'], '11460');
    });

    test('ShipmentModel identifies Dropoff order from API JSON', () {
      final model = ShipmentModel.fromJson({
        'id': 77,
        'order_number': 'ORD-77',
        'tracking_number': 'CC-DROP-77',
        'sender_name': 'Budi',
        'recipient_name': 'Sari',
        'recipient_phone': '081398765432',
        'pickup_address': 'Jl. Tomang No. 1',
        'delivery_address': 'Jl. Dharmawangsa No. 45',
        'weight': 2,
        'total_price': 24000,
        'status': 'waiting_dropoff',
        'status_label': 'Menunggu Diantar ke Drop Point',
        'shipping_method': 'dropoff',
        'drop_point': {
          'id': 10,
          'name': 'City Courier Hub Grogol',
          'address': 'Jl. Latumenten No. 12',
        },
        'created_at': '2026-11-21T10:00:00Z',
        'updated_at': '2026-11-21T10:00:00Z',
      });

      expect(model.isDropoff, isTrue);
      expect(model.dropPointId, 10);
      expect(model.dropPointName, 'City Courier Hub Grogol');
      expect(model.dropPointAddress, 'Jl. Latumenten No. 12');
    });

    test('TrackingStatus maps full Dropoff lifecycle accurately', () {
      expect(
        TrackingStatus.fromString('waiting_dropoff'),
        TrackingStatus.awaitingDropoff,
      );
      expect(
        TrackingStatus.awaitingDropoff.label,
        'Menunggu Diantar ke Drop Point',
      );
      expect(TrackingStatus.awaitingDropoff.progressIndex, 0);
      expect(TrackingStatus.awaitingDropoff.isCustomerCancellableStatus, isTrue);

      final droppedOff = TrackingStatus.fromString('dropped_off');
      expect(droppedOff, TrackingStatus.droppedOff);
      expect(droppedOff.label, 'Paket Diterima Petugas Drop Point');
      expect(droppedOff.progressIndex, 1);
      expect(droppedOff.isCustomerCancellableStatus, isFalse);

      expect(TrackingStatus.fromString('processing').label, 'Paket Diproses');
      expect(
        TrackingStatus.fromString('arrived_at_destination').label,
        'Sampai di Kota Tujuan',
      );
      expect(
        TrackingStatus.fromString('arrived_at_destination').progressIndex,
        2,
      );
    });

    test('Indonesian phone validator accepts valid and rejects invalid formats', () {
      expect(AddSenderScreen.isValidIndonesianPhone('081234567890'), isTrue);
      expect(AddSenderScreen.isValidIndonesianPhone('+6281234567890'), isTrue);
      expect(AddSenderScreen.isValidIndonesianPhone('6281234567890'), isTrue);
      expect(AddSenderScreen.isValidIndonesianPhone('0812-3456-7890'), isTrue);
      expect(AddSenderScreen.isValidIndonesianPhone('12345'), isFalse);
      expect(AddSenderScreen.isValidIndonesianPhone('00123456789'), isFalse);
      expect(AddSenderScreen.isValidIndonesianPhone('0812abc6789'), isFalse);
    });
  });

  group('Drop Point & Service Selection Widgets', () {
    testWidgets('DropPointScreen shows retry on error and filters search in selectionMode', (tester) async {
      bool shouldFail = true;
      Map<String, dynamic>? selectedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  selectedResult = await Navigator.push<Map<String, dynamic>>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DropPointScreen(
                        selectionMode: true,
                        locationProvider: () async =>
                            const LatLng(-6.17, 106.79),
                        dropPointsFetcher: () async {
                          if (shouldFail) {
                            throw Exception('Koneksi server gagal');
                          }
                          return _sampleDropPoints();
                        },
                      ),
                    ),
                  );
                },
                child: const Text('Buka'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Buka'));
      await tester.pumpAndSettle();

      expect(find.text('Muat Ulang'), findsOneWidget);
      shouldFail = false;

      await tester.tap(find.text('Muat Ulang'));
      await tester.pumpAndSettle();

      expect(find.text('City Courier Hub Grogol'), findsOneWidget);
      expect(find.text('City Courier Agen Kemang'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Kemang');
      await tester.pumpAndSettle();

      expect(find.text('City Courier Hub Grogol'), findsNothing);
      expect(find.text('City Courier Agen Kemang'), findsOneWidget);

      await tester.tap(find.text('Pilih Drop Point'));
      await tester.pumpAndSettle();

      expect(selectedResult, isNotNull);
      expect(selectedResult!['name'], 'City Courier Agen Kemang');
    });

    testWidgets('ItemInfoScreen hides vehicle selector in Dropoff mode and supports Gram/Catatan', (tester) async {
      Map<String, dynamic>? popped;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  popped = await Navigator.push<Map<String, dynamic>>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ItemInfoScreen(
                        showVehicleSelector: false,
                      ),
                    ),
                  );
                },
                child: const Text('Buka Paket'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Buka Paket'));
      await tester.pumpAndSettle();

      // Motor/Mobil vehicle selector must be hidden for Dropoff
      expect(find.text('KENDARAAN PENGIRIMAN'), findsNothing);

      await tester.enterText(
        find.byKey(const Key('field_deskripsi_barang')),
        'Kemeja Batik',
      );
      await tester.tap(find.byKey(const Key('weight_unit_gram')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('field_berat')),
        '500',
      );
      await tester.enterText(find.byKey(const Key('field_panjang')), '10');
      await tester.enterText(find.byKey(const Key('field_lebar')), '10');
      await tester.enterText(find.byKey(const Key('field_tinggi')), '10');
      await tester.enterText(
        find.byKey(const Key('field_catatan')),
        'Jangan dilipat',
      );
      await tester.pumpAndSettle();

      final saveBtn = find.text('Simpan Detail Barang');
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(popped, isNotNull);
      expect(popped!['status'], 'tersimpan');
      expect(popped!['deskripsi'], 'Kemeja Batik');
      expect(popped!['catatan'], 'Jangan dilipat');
      expect((popped!['berat'] as num).toDouble(), closeTo(0.5, 0.01));
    });

    testWidgets('DropoffServiceSelectionScreen renders only API-supported services with error retry', (tester) async {
      bool failApi = true;
      Map<String, dynamic>? pickedService;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  pickedService = await Navigator.push<Map<String, dynamic>>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DropoffServiceSelectionScreen(
                        originId: '2095',
                        destinationId: '6154',
                        originName: 'Grogol',
                        destinationName: 'Gubeng',
                        weightGrams: 1000,
                        costFetcher: ({
                          required String origin,
                          required String destination,
                          required int weight,
                          required String courier,
                        }) async {
                          if (failApi) {
                            return {
                              'success': false,
                              'message': 'Gagal memuat tarif',
                            };
                          }
                          return _fakeCostFetcher(
                            origin: origin,
                            destination: destination,
                            weight: weight,
                            courier: courier,
                          );
                        },
                      ),
                    ),
                  );
                },
                child: const Text('Buka Layanan'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Buka Layanan'));
      await tester.pumpAndSettle();

      expect(find.text('Gagal memuat tarif'), findsOneWidget);
      failApi = false;

      await tester.tap(find.text('Muat Ulang Ongkir'));
      await tester.pumpAndSettle();

      // Cargo was not returned by backend mock so Cargo chip must not appear
      expect(find.text('Reguler'), findsAtLeastNWidgets(1));
      expect(find.text('Express'), findsAtLeastNWidgets(1));
      expect(find.text('Cargo'), findsNothing);

      await tester.tap(find.text('Express').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('YES'), findsOneWidget);

      await tester.tap(find.textContaining('YES'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Konfirmasi Layanan'));
      await tester.pumpAndSettle();

      expect(pickedService, isNotNull);
      expect(pickedService!['status'], 'tersimpan');
      expect(pickedService!['courier']['service'], 'YES');
      expect(pickedService!['courier']['price'], 42000);
    });

    testWidgets('DropoffServiceSelectionScreen falls back to alternate candidate IDs and single courier when primary bundled call fails', (tester) async {
      final calls = <String>[];
      Map<String, dynamic>? picked;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  picked = await Navigator.push<Map<String, dynamic>>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DropoffServiceSelectionScreen(
                        originId: '5601',
                        destinationId: '6154',
                        originCandidates: const ['5601', '409'],
                        destinationCandidates: const ['6154', '444'],
                        originName: 'Waru, Sidoarjo',
                        destinationName: 'Gubeng, Surabaya',
                        weightGrams: 1000,
                        costFetcher: ({
                          required String origin,
                          required String destination,
                          required int weight,
                          required String courier,
                        }) async {
                          calls.add('$origin->$destination:$courier');
                          // Primary subdistrict pair & multi-courier fail; single courier 'jne' at city pair succeeds
                          if (origin == '409' &&
                              destination == '444' &&
                              courier == 'jne') {
                            return {
                              'success': true,
                              'data': [
                                {
                                  'name': 'JNE',
                                  'code': 'jne',
                                  'service': 'REG',
                                  'description': 'Reguler Fallback',
                                  'cost': 18000,
                                  'etd': '1-2 hari',
                                },
                              ],
                            };
                          }
                          return {'success': false, 'message': 'Invalid region'};
                        },
                      ),
                    ),
                  );
                },
                child: const Text('Cek Fallback'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Cek Fallback'));
      await tester.pumpAndSettle();

      expect(find.text('JNE • REG'), findsOneWidget);
      expect(find.text('Rp18.000'), findsWidgets);
      expect(calls.contains('409->444:jne'), isTrue);

      await tester.tap(find.text('Konfirmasi Layanan'));
      await tester.pumpAndSettle();
      expect(picked?['courier']?['price'], 18000);
    });
  });

  group('Dropoff Checkout, Payment Safety & Order Receipt', () {
    testWidgets('DropoffScreen validates incomplete steps and navigates through complete flow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DropoffScreen(
            dropPointsFetcher: () async => _sampleDropPoints(),
            dropPointLocationProvider: () async => const LatLng(-6.1665, 106.7905),
            addressesFetcher: () async => [
              _sampleSenderAddress(),
              _sampleReceiverAddress(),
            ],
            costFetcher: _fakeCostFetcher,
            postShipmentFn: (ep, body) async => {
              'success': true,
              'data': {
                'id': 501,
                'tracking_number': 'CC-DROP-501',
                'tracking_url': 'https://www.neonflux.my.id/track/CC-DROP-501',
              },
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tapping next before selecting Drop Point shows validation error
      await tester.tap(find.byKey(const Key('dropoff_next_button')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Silakan pilih lokasi Drop Point'),
        findsOneWidget,
      );
      ScaffoldMessenger.of(
        tester.element(find.byType(DropoffScreen)),
      ).hideCurrentSnackBar();
      await tester.pumpAndSettle();

      // 1. Select Drop Point
      final dropPointCard = find.byKey(
        const Key('dropoff_select_drop_point_card'),
      );
      await tester.ensureVisible(dropPointCard);
      await tester.tap(dropPointCard);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pilih Drop Point').first);
      await tester.pumpAndSettle();
      expect(find.text('City Courier Hub Grogol'), findsOneWidget);

      // 2. Select Sender
      final senderCard = find.byKey(const Key('dropoff_sender_card'));
      await tester.ensureVisible(senderCard);
      await tester.tap(senderCard);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Budi Pengirim'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Budi Pengirim'), findsOneWidget);

      // 3. Select Receiver
      final receiverCard = find.byKey(const Key('dropoff_receiver_card'));
      await tester.ensureVisible(receiverCard);
      await tester.tap(receiverCard);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sari Penerima'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Sari Penerima'), findsOneWidget);

      // 4. Fill Package Info
      final itemCard = find.byKey(const Key('dropoff_item_info_card'));
      await tester.ensureVisible(itemCard);
      await tester.tap(itemCard);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('field_deskripsi_barang')),
        'Buku Pelajaran',
      );
      await tester.enterText(find.byKey(const Key('field_catatan')), 'Hati-hati');
      final saveItemBtn = find.text('Simpan Detail Barang');
      await tester.ensureVisible(saveItemBtn);
      await tester.tap(saveItemBtn);
      await tester.pumpAndSettle();
      expect(find.textContaining('Buku Pelajaran'), findsOneWidget);
      expect(find.text('PENGIRIMAN'), findsOneWidget);

      // 5. Select Service from backend cost API
      final serviceCard = find.byKey(const Key('dropoff_service_card'));
      await tester.ensureVisible(serviceCard);
      await tester.tap(serviceCard);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('REG'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Konfirmasi Layanan'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Rp24.000'), findsWidgets);

      // 6. Proceed to ConfirmationScreen
      await tester.tap(find.byKey(const Key('dropoff_next_button')));
      await tester.pumpAndSettle();
      expect(find.text('LOKASI DROP POINT'), findsOneWidget);
      expect(find.text('City Courier Hub Grogol'), findsOneWidget);
      expect(find.text('Catatan: Hati-hati'), findsOneWidget);
    });

    testWidgets('ConfirmationScreen prevents double-submit and forwards Dropoff metadata', (tester) async {
      int postCalls = 0;
      Map<String, dynamic>? capturedBody;
      final completer = Completer<Map<String, dynamic>?>();

      await tester.pumpWidget(
        MaterialApp(
          home: ConfirmationScreen(
            isDropoff: true,
            dropPointData: _sampleDropPoints().first,
            itemCatatan: 'Fragile',
            senderData: _sampleSenderAddress(),
            receiverData: _sampleReceiverAddress(),
            selectedCourier: const {
              'code': 'jne',
              'name': 'JNE',
              'service': 'REG',
              'price': 24000,
              'etd': '2-3 hari',
            },
            itemDeskripsi: 'Elektronik',
            itemBerat: 2.0,
            itemBeratVolume: 1.0,
            itemPanjang: 20,
            itemLebar: 15,
            itemTinggi: 10,
            itemJumlah: 1,
            asuransiPengiriman: false,
            packingKayu: false,
            selectedVehicle: 'JNE REG',
            postShipmentFn: (ep, body) {
              postCalls++;
              capturedBody = body;
              return completer.future;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final payBtn = find.text('Bayar Sekarang');
      await tester.tap(payBtn);
      await tester.pump();
      await tester.tap(find.text('Memproses Pesanan...'));
      await tester.pump();

      expect(postCalls, 1);
      expect(capturedBody?['shipping_method'], 'dropoff');
      expect(capturedBody?['drop_point_id'], 10);
      expect(capturedBody?['drop_point_name'], 'City Courier Hub Grogol');
      expect(capturedBody?['notes'], 'Fragile');

      completer.complete({
        'success': false,
        'message': 'Uji selesai',
      });
      await tester.pumpAndSettle();
    });

    testWidgets('PaymentMethodScreen blocks insufficient City Wallet balance without calling pay API', (tester) async {
      final fakeWallet = _FakeWalletService(
        summary: _walletSummary(availableBalance: 10000),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PaymentMethodScreen(
            totalAmount: 24000,
            shipmentId: '501',
            trackingNumber: 'CC-DROP-501',
            senderName: 'Budi Pengirim',
            senderCity: 'Grogol',
            receiverName: 'Sari Penerima',
            receiverCity: 'Surabaya',
            vehicle: 'JNE REG',
            isDropoff: true,
            dropPointData: _sampleDropPoints().first,
            walletService: fakeWallet,
            methodsFetcher: () async => const CheckoutPaymentMethodsResult(
              methods: <PaymentMethod>[],
              xenditEnabled: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Dropoff mode hides COD and offers Bayar Tunai di Drop Point
      expect(find.text('Bayar di Tempat (COD)'), findsNothing);
      expect(find.text('Bayar Tunai di Drop Point'), findsOneWidget);
      expect(find.textContaining('Saldo tidak mencukupi'), findsOneWidget);

      await tester.tap(find.textContaining('City Wallet'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bayar'));
      await tester.pumpAndSettle();

      expect(fakeWallet.payCallCount, 0);
      expect(find.byType(WalletPaymentConfirmationScreen), findsNothing);
    });

    testWidgets('PaymentMethodScreen prevents double debit on City Wallet and shows Dropoff receipt', (tester) async {
      String? clipboardText;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              clipboardText =
                  (call.arguments as Map?)?['text']?.toString();
            }
            return null;
          });

      final fakeWallet = _FakeWalletService(
        summary: _walletSummary(availableBalance: 100000),
        payDelay: const Duration(milliseconds: 50),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PaymentMethodScreen(
            totalAmount: 24000,
            shipmentId: '501',
            trackingNumber: 'CC-DROP-501',
            senderName: 'Budi Pengirim',
            senderCity: 'Grogol',
            receiverName: 'Sari Penerima',
            receiverCity: 'Surabaya',
            vehicle: 'JNE REG',
            isDropoff: true,
            dropPointData: _sampleDropPoints().first,
            itemDescription: 'Elektronik',
            packageWeight: 2.0,
            receiverPhone: '081398765432',
            receiverAddress: 'Jl. Dharmawangsa No. 45',
            walletService: fakeWallet,
            methodsFetcher: () async => const CheckoutPaymentMethodsResult(
              methods: <PaymentMethod>[],
              xenditEnabled: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('City Wallet'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bayar'));
      await tester.tap(find.text('Bayar'));
      await tester.pumpAndSettle();

      expect(fakeWallet.payCallCount, 1);
      expect(find.byType(WalletPaymentConfirmationScreen), findsOneWidget);
      expect(find.text('Menunggu Diantar ke Drop Point'), findsOneWidget);
      expect(find.text('Paket Diterima'), findsNothing);
      expect(find.text('City Courier Hub Grogol'), findsOneWidget);
      expect(find.text('CC-DROP-501'), findsOneWidget);
      expect(find.text('Lacak Pesanan'), findsOneWidget);

      await tester.tap(find.text('CC-DROP-501'));
      await tester.pumpAndSettle();
      expect(clipboardText, 'CC-DROP-501');

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    testWidgets('PaymentMethodScreen rejects TUNAI when server confirmation fails and succeeds when confirmed', (tester) async {
      bool confirmSuccess = false;

      await tester.pumpWidget(
        MaterialApp(
          home: PaymentMethodScreen(
            totalAmount: 24000,
            shipmentId: '502',
            trackingNumber: 'CC-DROP-502',
            senderName: 'Budi Pengirim',
            senderCity: 'Grogol',
            receiverName: 'Sari Penerima',
            receiverCity: 'Surabaya',
            vehicle: 'JNE REG',
            isDropoff: true,
            dropPointData: _sampleDropPoints().first,
            itemDescription: 'Dokumen',
            packageWeight: 1.0,
            receiverPhone: '081398765432',
            receiverAddress: 'Jl. Dharmawangsa No. 45',
            walletService: _FakeWalletService(
              summary: _walletSummary(availableBalance: 0),
            ),
            methodsFetcher: () async => const CheckoutPaymentMethodsResult(
              methods: <PaymentMethod>[],
              xenditEnabled: false,
            ),
            confirmPaymentFn: (ep, body) async {
              if (!confirmSuccess) {
                return {
                  'success': false,
                  'message': 'Metode tunai ditolak server',
                };
              }
              return {'success': true, 'confirmed': true};
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bayar Tunai di Drop Point'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bayar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Metode tunai ditolak server'), findsOneWidget);
      expect(find.byType(DirectPaymentConfirmationScreen), findsNothing);

      ScaffoldMessenger.of(
        tester.element(find.byType(PaymentMethodScreen)),
      ).hideCurrentSnackBar();
      await tester.pumpAndSettle();

      confirmSuccess = true;
      await tester.tap(find.text('Bayar'));
      await tester.pumpAndSettle();

      expect(find.byType(DirectPaymentConfirmationScreen), findsOneWidget);
      expect(find.text('Menunggu Diantar ke Drop Point'), findsWidgets);
      expect(find.text('Tunjukkan Resi / QR ini di Drop Point'), findsOneWidget);
      expect(find.text('City Courier Hub Grogol'), findsOneWidget);
      expect(find.text('CC-DROP-502'), findsOneWidget);
      expect(find.text('Live Tracking'), findsOneWidget);
    });
  });
}
