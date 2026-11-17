import 'dart:convert';

import 'package:city_courierapp/models/payment/payment_method.dart';
import 'package:city_courierapp/models/wallet/wallet_models.dart';
import 'package:city_courierapp/screens/home/shipping/payment_method_screen.dart';
import 'package:city_courierapp/screens/wallet/customer_wallet_dashboard_screen.dart';
import 'package:city_courierapp/screens/wallet/topup_method_screen.dart';
import 'package:city_courierapp/services/maps/location_repository.dart';
import 'package:city_courierapp/services/payment/payment_service.dart';
import 'package:city_courierapp/services/provider_availability_service.dart';
import 'package:city_courierapp/services/shipping/routing_service.dart';
import 'package:city_courierapp/services/wallet/customer_wallet_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    ProviderAvailabilityService.clearCache();
    ProviderAvailabilityService.testSettingsFetcher = null;
  });

  tearDown(() {
    ProviderAvailabilityService.clearCache();
    ProviderAvailabilityService.testSettingsFetcher = null;
  });

  List<PaymentMethod> sampleIpaymuChannels() => [
        PaymentMethod(
          code: 'bca',
          name: 'BCA Virtual Account',
          group: 'virtual_account',
          iconUrl: '',
          fee: 4000,
          isAvailable: true,
        ),
        PaymentMethod(
          code: 'QRIS',
          name: 'QRIS',
          group: 'ewallet',
          iconUrl: '',
          fee: 0,
          isAvailable: true,
        ),
      ];

  CustomerWalletService buildMockWalletService({
    required bool topupEnabled,
    bool hasMethodsWhenEnabled = true,
  }) {
    final client = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/v1/customer/wallet')) {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'wallet_id': 1,
              'wallet_type': 'customer',
              'currency': 'IDR',
              'status': 'active',
              'is_frozen': false,
              'available_balance': 150000,
              'pending_balance': 0,
              'reserved_balance': 0,
              'total_credited': 150000,
              'total_debited': 0,
              'mode': 'sandbox',
              'is_sandbox_or_demo': true,
              'active_payment_provider': 'xendit',
              'topup_provider_enabled': topupEnabled,
              'security': {
                'has_transaction_pin': false,
                'biometric_enabled': false,
              },
              'withdrawal_policy': {
                'enabled': topupEnabled,
                'provider_enabled': topupEnabled,
                'min_amount_idr': 10000,
                'max_amount_idr': 5000000,
              },
              'topup_policy': {
                'min_amount_idr': 10000,
                'max_amount_idr': 10000000,
              },
            },
          }),
          200,
        );
      }

      if (path.endsWith('/v1/customer/wallet/transactions')) {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'items': [],
              'pagination': {'current_page': 1, 'last_page': 1},
            },
          }),
          200,
        );
      }

      if (path.endsWith('/v1/customer/wallet/topups/methods')) {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'mode': 'sandbox',
              'active_provider': 'xendit',
              'provider_enabled': topupEnabled,
              'disabled_reason': topupEnabled
                  ? null
                  : 'Gateway top-up Xendit sedang dinonaktifkan oleh Admin.',
              'is_simulated': false,
              'min_amount_idr': 10000,
              'max_amount_idr': 10000000,
              'methods': topupEnabled && hasMethodsWhenEnabled
                  ? [
                      {
                        'payment_type': 'va',
                        'channel_code': 'BCA',
                        'label': 'BCA Virtual Account',
                        'fee_idr': 0,
                      }
                    ]
                  : [],
            },
          }),
          200,
        );
      }

      return http.Response(jsonEncode({'success': true, 'data': {}}), 200);
    });

    return CustomerWalletService(
      client: client,
      baseUrl: 'https://example.test/api',
      tokenReader: () async => 'test-token',
    );
  }

  testWidgets('Checkout shows VA & QRIS when iPaymu is ON', (tester) async {
    final walletService = buildMockWalletService(topupEnabled: true);

    await tester.pumpWidget(
      MaterialApp(
        home: PaymentMethodScreen(
          totalAmount: 50000,
          shipmentId: '101',
          walletService: walletService,
          methodsFetcher: () async => CheckoutPaymentMethodsResult(
            methods: sampleIpaymuChannels(),
            ipaymuEnabled: true,
          ),
          settingsFetcher: () async => {
            'providers': {'ipaymu': true},
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('VIRTUAL ACCOUNT'), findsOneWidget);
    expect(find.text('E-WALLET'), findsOneWidget);
    expect(find.textContaining('City Wallet'), findsOneWidget);
    expect(find.textContaining('COD'), findsOneWidget);
    expect(find.textContaining('Tunai'), findsOneWidget);
  });

  testWidgets(
    'Checkout hides VA & QRIS when Admin turns iPaymu OFF while keeping Wallet, COD, and Tunai',
    (tester) async {
      final walletService = buildMockWalletService(topupEnabled: true);

      await tester.pumpWidget(
        MaterialApp(
          home: PaymentMethodScreen(
            totalAmount: 50000,
            shipmentId: '101',
            walletService: walletService,
            methodsFetcher: () async => const CheckoutPaymentMethodsResult(
              methods: [],
              ipaymuEnabled: false,
              message: 'Pembayaran iPaymu (VA & QRIS) sedang dinonaktifkan oleh Admin.',
            ),
            settingsFetcher: () async => {
              'providers': {'ipaymu': false},
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // VA and E-Wallet/QRIS accordions must be completely absent
      expect(find.text('VIRTUAL ACCOUNT'), findsNothing);
      expect(find.text('E-WALLET'), findsNothing);
      expect(find.text('BCA Virtual Account'), findsNothing);
      expect(find.text('QRIS'), findsNothing);

      // Local checkout methods remain available
      expect(find.textContaining('City Wallet'), findsOneWidget);
      expect(find.textContaining('COD'), findsOneWidget);
      expect(find.textContaining('Tunai'), findsOneWidget);

      // Even if methodsFetcher returned channels stale-cached, /settings ipaymu=false filters them out
      await tester.pumpWidget(
        MaterialApp(
          home: PaymentMethodScreen(
            totalAmount: 50000,
            shipmentId: '102',
            walletService: walletService,
            methodsFetcher: () async => CheckoutPaymentMethodsResult(
              methods: sampleIpaymuChannels(),
              ipaymuEnabled: true,
            ),
            settingsFetcher: () async => {
              'providers': {'ipaymu': false},
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('VIRTUAL ACCOUNT'), findsNothing);
      expect(find.text('E-WALLET'), findsNothing);
      expect(find.textContaining('COD'), findsOneWidget);
    },
  );

  testWidgets('TopupMethodScreen disables submission & explains when gateway is OFF', (tester) async {
    final walletService = buildMockWalletService(topupEnabled: false);

    await tester.pumpWidget(
      MaterialApp(
        home: TopupMethodScreen(
          amount: 50000,
          service: walletService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Metode Top-Up Tidak Tersedia'), findsOneWidget);
    expect(find.textContaining('dinonaktifkan oleh Admin'), findsOneWidget);

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('CustomerWalletDashboardScreen disables Top-Up button when gateway is OFF', (tester) async {
    final walletService = buildMockWalletService(topupEnabled: false);

    await tester.pumpWidget(
      MaterialApp(
        home: CustomerWalletDashboardScreen(service: walletService),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Top-Up Dinonaktifkan Admin'), findsOneWidget);
    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Top-Up Dinonaktifkan Admin'),
    );
    expect(button.onPressed, isNull);
  });

  test('Map & Routing providers halt immediately when Admin disables map provider', () async {
    ProviderAvailabilityService.testSettingsFetcher = () async => {
          'providers': {'map': false, 'ipaymu': false, 'xendit': false},
        };
    ProviderAvailabilityService.clearCache();

    final repo = LocationRepository();
    expect(await repo.searchAddress('Jakarta'), isEmpty);
    expect(await repo.reverseGeocode(-6.2, 106.8), isNull);

    final routing = CityCourierRoutingService();
    await expectLater(
      () => routing.getRoute(
        origin: const LatLng(-6.2, 106.8),
        destination: const LatLng(-6.3, 106.9),
      ),
      throwsA(isA<RoutingException>()),
    );

    final disabledSnapshot = ProviderStatusSnapshot.fromSettingsData({
      'providers': {'map': false, 'ipaymu': false, 'xendit': false},
    });
    expect(disabledSnapshot.isEnabled('map'), isFalse);
    expect(disabledSnapshot.isEnabled('ipaymu'), isFalse);
    expect(disabledSnapshot.isEnabled('xendit'), isFalse);
    expect(disabledSnapshot.topupProviderEnabled, isFalse);
    expect(
      TopupMethodsBundle.fromJson({'provider_enabled': false, 'methods': []}).providerEnabled,
      isFalse,
    );
  });
}
