import 'dart:convert';

import 'package:city_courierapp/models/payment/payment_method.dart';
import 'package:city_courierapp/models/wallet/wallet_models.dart';
import 'package:city_courierapp/screens/home/shipping/payment_method_screen.dart';
import 'package:city_courierapp/screens/home_screen.dart';
import 'package:city_courierapp/screens/wallet/customer_withdrawal_screen.dart';
import 'package:city_courierapp/screens/wallet/topup_amount_screen.dart';
import 'package:city_courierapp/screens/wallet/topup_instruction_screen.dart';
import 'package:city_courierapp/screens/wallet/wallet_payment_confirmation_screen.dart';
import 'package:city_courierapp/services/payment/payment_service.dart';
import 'package:city_courierapp/services/security/account_security_service.dart';
import 'package:city_courierapp/services/security/biometric_guard_service.dart';
import 'package:city_courierapp/services/token_store.dart';
import 'package:city_courierapp/services/wallet/customer_wallet_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestBiometricDriver implements BiometricDriver {
  bool supported = true;
  bool allowAuth = true;
  int authCalls = 0;

  @override
  Future<BiometricCheckResult> checkAvailability() async {
    return BiometricCheckResult(
      supported: supported,
      hasEnrolledBiometrics: supported,
      availableTypes: supported ? [BiometricType.fingerprint] : [],
      hardwareLabel:
          supported ? 'Sidik Jari (Fingerprint)' : 'Biometrik tidak tersedia',
    );
  }

  @override
  Future<BiometricAuthResult> authenticate({
    required String localizedReason,
    bool biometricOnly = false,
  }) async {
    authCalls++;
    return BiometricAuthResult(
      authenticated: allowAuth,
      message: allowAuth ? null : 'Verifikasi biometrik dibatalkan.',
    );
  }
}

class _FakeWalletService extends CustomerWalletService {
  final CustomerWalletSummary summary;
  int payCalls = 0;
  String? lastSubmittedPin;

  _FakeWalletService(this.summary);

  @override
  Future<CustomerWalletSummary> getWallet() async => summary;

  @override
  Future<Map<String, dynamic>> payOrderWithWallet({
    int? shipmentId,
    int? orderId,
    String? idempotencyKey,
    String? transactionPin,
  }) async {
    payCalls++;
    lastSubmittedPin = transactionPin;
    return {
      'payment_transaction': {
        'reference': 'WALPAY-SEC-1',
        'amount': 30000,
        'mode': 'sandbox',
      },
      'wallet_available_balance': summary.availableBalance - 30000,
    };
  }
}

CustomerWalletSummary _walletSummary({
  int availableBalance = 200000,
  bool biometricEnabled = false,
  bool hasTransactionPin = false,
}) {
  return CustomerWalletSummary(
    walletId: 1,
    walletType: 'customer',
    currency: 'IDR',
    status: 'active',
    isFrozen: false,
    availableBalance: availableBalance,
    pendingBalance: 0,
    reservedBalance: 0,
    totalCredited: availableBalance,
    totalDebited: 0,
    mode: 'sandbox',
    isSandboxOrDemo: true,
    activePaymentProvider: 'xendit',
    withdrawalEnabled: true,
    withdrawalMinIdr: 10000,
    withdrawalMaxIdr: 5000000,
    topupMinIdr: 10000,
    topupMaxIdr: 10000000,
    hasTransactionPin: hasTransactionPin,
    biometricEnabled: biometricEnabled,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _TestBiometricDriver fakeBiometric;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await TokenStore.clear();
    fakeBiometric = _TestBiometricDriver();
    BiometricGuardService.driver = fakeBiometric;
    await BiometricGuardService.clearSessionUnlock(clearPreference: true);
  });

  tearDown(() async {
    await BiometricGuardService.clearSessionUnlock(clearPreference: true);
  });

  test('BiometricGuardService menyimpan cache preferensi dan mereset saat logout',
      () async {
    expect(await BiometricGuardService.isLocallyEnabled(), isFalse);
    await BiometricGuardService.setLocalEnabled(true, userId: 7);
    expect(await BiometricGuardService.isLocallyEnabled(), isTrue);

    await BiometricGuardService.clearSessionUnlock(clearPreference: true);
    expect(await BiometricGuardService.isLocallyEnabled(), isFalse);
    expect(BiometricGuardService.isSessionUnlocked, isFalse);
  });

  testWidgets(
      'HomeScreen mengunci sesi dengan Biometrik saat sudah login & biometrik aktif, lalu terbuka setelah verifikasi',
      (tester) async {
    await TokenStore.save('logged_in_token');
    await BiometricGuardService.setLocalEnabled(true, userId: 10);
    fakeBiometric.allowAuth = false;

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pumpAndSettle();

    expect(fakeBiometric.authCalls, 1);
    expect(find.text('Verifikasi Biometrik Diperlukan'), findsOneWidget);
    expect(find.text('Masuk dengan Biometrik'), findsOneWidget);

    // Lolos verifikasi saat menekan tombol Masuk dengan Biometrik
    fakeBiometric.allowAuth = true;
    await tester.tap(find.text('Masuk dengan Biometrik'));
    await tester.pumpAndSettle();

    expect(fakeBiometric.authCalls, 2);
    expect(find.text('Verifikasi Biometrik Diperlukan'), findsNothing);
    expect(BiometricGuardService.isSessionUnlocked, isTrue);
  });

  testWidgets(
      'PaymentMethodScreen meminta Biometrik lalu PIN Transaksi saat membayar dengan saldo City Wallet',
      (tester) async {
    final walletSvc = _FakeWalletService(
      _walletSummary(
        availableBalance: 200000,
        biometricEnabled: true,
        hasTransactionPin: true,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PaymentMethodScreen(
          totalAmount: 30000,
          shipmentId: '88',
          trackingNumber: 'CC-WALLET-88',
          walletService: walletSvc,
          methodsFetcher: () async => const CheckoutPaymentMethodsResult(
            methods: <PaymentMethod>[],
            xenditEnabled: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Saldo tersedia • Dilindungi Biometrik & PIN'),
      findsOneWidget,
    );

    await tester.tap(find.textContaining('City Wallet'));
    await tester.pumpAndSettle();

    // 1. Jika biometrik dibatalkan, PIN tidak muncul dan pembayaran batal.
    fakeBiometric.allowAuth = false;
    await tester.tap(find.text('Bayar'));
    await tester.pumpAndSettle();

    expect(fakeBiometric.authCalls, 1);
    expect(find.text('Verifikasi biometrik dibatalkan.'), findsOneWidget);
    expect(find.text('Masukkan PIN Transaksi'), findsNothing);
    expect(walletSvc.payCalls, 0);

    // Tunggu snackbar hilang dan pastikan tombol Bayar aktif kembali.
    ScaffoldMessenger.of(tester.element(find.byType(PaymentMethodScreen)))
        .removeCurrentSnackBar();
    await tester.pumpAndSettle();

    // 2. Jika biometrik berhasil, PIN prompt muncul; setelah isi 6 digit PIN baru debit diproses.
    fakeBiometric.allowAuth = true;
    await tester.tap(find.text('Bayar'));
    await tester.pumpAndSettle();

    expect(fakeBiometric.authCalls, 2);
    expect(find.text('Masukkan PIN Transaksi'), findsOneWidget);

    for (final d in ['4', '8', '2', '9', '1', '0']) {
      await tester.tap(find.widgetWithText(InkWell, d));
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pumpAndSettle();

    expect(walletSvc.payCalls, 1);
    expect(walletSvc.lastSubmittedPin, '482910');
    expect(find.byType(WalletPaymentConfirmationScreen), findsOneWidget);
  });

  testWidgets(
      'TopupAmountScreen memverifikasi Biometrik dan PIN Transaksi sebelum membuat transaksi Top-Up',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    String? verifiedPin;
    bool topupCreated = false;

    final walletClient = MockClient((req) async {
      if (req.url.path.endsWith('/v1/customer/wallet') && req.method == 'GET') {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'wallet_id': 1,
              'wallet_type': 'customer',
              'currency': 'IDR',
              'status': 'active',
              'is_frozen': false,
              'available_balance': 50000,
              'pending_balance': 0,
              'reserved_balance': 0,
              'total_credited': 50000,
              'total_debited': 0,
              'mode': 'sandbox',
              'is_sandbox_or_demo': true,
              'active_payment_provider': 'xendit',
              'security': {
                'has_transaction_pin': true,
                'biometric_enabled': true,
              },
              'withdrawal_policy': {'enabled': true},
              'topup_policy': {'min_amount_idr': 10000, 'max_amount_idr': 10000000},
            },
          }),
          200,
        );
      }
      if (req.url.path.endsWith('/v1/customer/wallet/topups/methods')) {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'mode': 'sandbox',
              'is_simulated': true,
              'active_provider': 'xendit',
              'provider_enabled': true,
              'methods': [
                {
                  'channel_code': 'QRIS',
                  'label': 'QRIS Instan',
                  'payment_type': 'qris',
                  'fee_idr': 0,
                },
              ],
            },
          }),
          200,
        );
      }
      if (req.url.path.endsWith('/v1/customer/wallet/topups') &&
          req.method == 'POST') {
        topupCreated = true;
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'id': 91,
              'reference': 'TOPUP-SEC-91',
              'provider': 'xendit',
              'mode': 'sandbox',
              'is_simulated': true,
              'payment_type': 'qris',
              'channel_code': 'QRIS',
              'amount': 50000,
              'fee': 0,
              'net_amount': 50000,
              'status': 'pending',
              'instructions': ['Bayar QRIS'],
            },
          }),
          201,
        );
      }
      return http.Response('{}', 404);
    });

    final securityClient = MockClient((req) async {
      if (req.url.path.endsWith('/security/pin/verify')) {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        verifiedPin = body['pin']?.toString();
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {'valid': true},
          }),
          200,
        );
      }
      return http.Response('{}', 404);
    });

    final walletService = CustomerWalletService(
      client: walletClient,
      baseUrl: 'https://example.test/api',
      tokenReader: () async => 'cust-token',
    );
    final securityService = AccountSecurityService(
      client: securityClient,
      baseUrl: 'https://example.test/api',
      tokenReader: () async => 'cust-token',
      deviceHeadersReader: () async => {'X-Device-Id': 'dev-test'},
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TopupAmountScreen(
          service: walletService,
          securityService: securityService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Buat Instruksi Pembayaran'));
    await tester.tap(find.text('Buat Instruksi Pembayaran'));
    await tester.pumpAndSettle();

    expect(fakeBiometric.authCalls, 1);
    expect(find.text('Masukkan PIN Transaksi'), findsOneWidget);

    for (final d in ['1', '3', '5', '7', '9', '2']) {
      await tester.tap(find.widgetWithText(InkWell, d));
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pumpAndSettle();

    expect(verifiedPin, '135792');
    expect(topupCreated, isTrue);
    expect(find.byType(TopupInstructionScreen), findsOneWidget);
  });

  testWidgets(
      'CustomerWithdrawalScreen memverifikasi Biometrik sebelum meminta PIN Transaksi',
      (tester) async {
    String? sentPin;
    final walletClient = MockClient((req) async {
      if (req.url.path.endsWith('/destinations')) {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'items': [
                {
                  'id': 5,
                  'destination_type': 'bank_account',
                  'channel_code': 'BCA',
                  'account_number': '1234567890',
                  'account_holder_name': 'Siti Customer',
                  'is_default': true,
                },
              ],
            },
          }),
          200,
        );
      }
      if (req.url.path.endsWith('/withdrawals') && req.method == 'GET') {
        return http.Response(
          jsonEncode({'success': true, 'data': {'items': []}}),
          200,
        );
      }
      if (req.url.path.endsWith('/withdrawals') && req.method == 'POST') {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        sentPin = body['transaction_pin']?.toString();
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'id': 77,
              'reference': 'WD-BIO-77',
              'amount': 50000,
              'status': 'processing',
              'mode': 'sandbox',
            },
          }),
          201,
        );
      }
      return http.Response('{}', 404);
    });

    final walletService = CustomerWalletService(
      client: walletClient,
      baseUrl: 'https://example.test/api',
      tokenReader: () async => 'cust-token',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CustomerWithdrawalScreen(
          wallet: _walletSummary(
            biometricEnabled: true,
            hasTransactionPin: true,
          ),
          service: walletService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Masukkan nominal penarikan'),
      '50000',
    );
    await tester.tap(find.text('Ajukan Penarikan'));
    await tester.pumpAndSettle();

    expect(fakeBiometric.authCalls, 1);
    expect(find.text('Masukkan PIN Transaksi'), findsOneWidget);

    for (final d in ['6', '2', '4', '8', '1', '9']) {
      await tester.tap(find.widgetWithText(InkWell, d));
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pumpAndSettle();

    expect(sentPin, '624819');
  });
}
