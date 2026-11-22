import 'dart:convert';

import 'package:city_courierapp/models/wallet/wallet_models.dart';
import 'package:city_courierapp/screens/wallet/payout_destinations_screen.dart';
import 'package:city_courierapp/screens/wallet/widgets/wallet_ui_components.dart';
import 'package:city_courierapp/services/provider_availability_service.dart';
import 'package:city_courierapp/services/wallet/customer_wallet_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('ProviderStatusSnapshot enforces Xendit-only and disables DOKU', () {
    final snapshot = ProviderStatusSnapshot.fromSettingsData({
      'providers': {
        'whatsapp': true,
        'map': true,
        'rajaongkir': true,
        'xendit': true,
      },
      'active_payment_provider': 'xendit',
      'topup_provider_enabled': true,
    });

    expect(snapshot.isEnabled('xendit'), isTrue);
    expect(snapshot.isEnabled('doku'), isFalse);
    expect(snapshot.topupProviderEnabled, isTrue);
    expect(ProviderStatusSnapshot.defaultProviders.containsKey('doku'), isFalse);
    expect(ProviderStatusSnapshot.defaultProviders.containsKey('ipaymu'), isFalse);
  });

  test('PayoutDestinationV1 defaults unverified honestly and preserves auto_verified', () {
    final unverified = PayoutDestinationV1.fromJson({
      'id': 1,
      'owner_type': 'customer',
      'destination_type': 'bank',
      'channel_code': 'ID_BCA',
      'channel_name': 'Bank BCA',
      'account_number_masked': '******1234',
      'account_holder_name': 'BUDI SANTOSO',
      'is_verified': false,
    });
    expect(unverified.normalizedVerificationStatus, 'unverified');
    expect(unverified.isAutoVerified, isFalse);

    final verified = PayoutDestinationV1.fromJson({
      'id': 2,
      'owner_type': 'courier',
      'destination_type': 'ewallet',
      'channel_code': 'ID_DANA',
      'channel_name': 'DANA',
      'account_number_masked': '******7890',
      'account_holder_name': 'SITI AMINAH',
      'is_verified': true,
      'verification_status': 'auto_verified',
    });
    expect(verified.normalizedVerificationStatus, 'auto_verified');
    expect(verified.isAutoVerified, isTrue);
  });

  testWidgets('DestinationInquiryStatusBanner renders all 4 honest states', (tester) async {
    Future<void> pumpStatus(Map<String, dynamic> inquiryPayload) async {
      final ctrl = DestinationNameInquiryController(
        inquireFn: ({
          required destinationType,
          required channelCode,
          required accountNumber,
        }) async =>
            DestinationInquiryResult.fromJson(inquiryPayload),
      );
      ctrl.result = DestinationInquiryResult.fromJson(inquiryPayload);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DestinationInquiryStatusBanner(controller: ctrl),
          ),
        ),
      );
    }

    // 1. Terverifikasi otomatis
    await pumpStatus({
      'supported': true,
      'found': true,
      'verification_status': 'auto_verified',
      'account_holder_name': 'BUDI SANTOSO',
    });
    expect(find.text('Terverifikasi otomatis'), findsOneWidget);
    expect(find.text('BUDI SANTOSO'), findsOneWidget);

    // 2. Belum terverifikasi (Xendit Payouts standar tanpa Name Validator)
    await pumpStatus({
      'supported': false,
      'found': false,
      'verification_status': 'unverified',
      'can_input_manually': true,
      'message': 'Isi nama pemilik secara manual.',
    });
    expect(find.text('Belum terverifikasi'), findsOneWidget);
    expect(find.text('Isi nama pemilik secara manual.'), findsOneWidget);

    // 3. Tidak tersedia (kanal tidak didukung / dinonaktifkan)
    await pumpStatus({
      'supported': false,
      'found': false,
      'verification_status': 'unavailable',
      'can_input_manually': false,
      'message': 'Kanal tujuan dinonaktifkan.',
    });
    expect(find.text('Tidak tersedia'), findsOneWidget);
    expect(find.text('Kanal tujuan dinonaktifkan.'), findsOneWidget);

    // 4. Gagal diverifikasi
    await pumpStatus({
      'supported': true,
      'found': false,
      'verification_status': 'verification_failed',
      'can_input_manually': true,
      'message': 'Nomor tidak ditemukan oleh validator.',
    });
    expect(find.text('Gagal diverifikasi'), findsOneWidget);
    expect(find.text('Nomor tidak ditemukan oleh validator.'), findsOneWidget);
  });

  testWidgets('PayoutDestinationsScreen keeps supported GoPay/DANA/OVO/ShopeePay/LinkAja and hides excluded channels', (tester) async {
    final client = MockClient((req) async {
      if (req.url.path.endsWith('/v1/customer/wallet/destinations')) {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'items': [],
              'supported_channels': {
                'bank': {'ID_BCA': 'Bank BCA'},
                'ewallet': {
                  'ID_GOPAY': 'GoPay',
                  'ID_DANA': 'DANA',
                  'ID_OVO': 'OVO',
                  'ID_SHOPEEPAY': 'ShopeePay',
                  'ID_LINKAJA': 'LinkAja',
                },
              },
            },
          }),
          200,
        );
      }
      return http.Response('{}', 404);
    });

    final service = CustomerWalletService(
      client: client,
      baseUrl: 'https://example.test/api',
      tokenReader: () async => 'token',
    );

    await tester.pumpWidget(
      MaterialApp(home: PayoutDestinationsScreen(service: service)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('+ E-Wallet'));
    await tester.pumpAndSettle();

    // Buka dropdown e-wallet agar semua kanal Xendit terverifikasi tampil
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();

    expect(find.text('GoPay'), findsAtLeastNWidgets(1));
    expect(find.text('DANA'), findsAtLeastNWidgets(1));
    expect(find.text('OVO'), findsAtLeastNWidgets(1));
    expect(find.text('ShopeePay'), findsAtLeastNWidgets(1));
    expect(find.text('LinkAja'), findsAtLeastNWidgets(1));

    // Tutup dropdown sebelum pindah tab Rekening Bank
    await tester.tap(find.text('GoPay').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rekening Bank'));
    await tester.pumpAndSettle();

    // Bank BCA appears as supported; excluded Bank Mandiri is filtered out
    expect(find.text('Bank BCA'), findsAtLeastNWidgets(1));
    expect(find.text('Bank Mandiri'), findsNothing);
  });
}
