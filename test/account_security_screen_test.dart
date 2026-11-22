import 'dart:convert';

import 'package:city_courierapp/models/wallet/wallet_models.dart';
import 'package:city_courierapp/screens/profile/keamanan_akun/account_security_screen.dart';
import 'package:city_courierapp/screens/wallet/customer_withdrawal_screen.dart';
import 'package:city_courierapp/services/security/account_security_service.dart';
import 'package:city_courierapp/services/security/biometric_guard_service.dart';
import 'package:city_courierapp/services/wallet/customer_wallet_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:local_auth/local_auth.dart';

class _FakeBiometricDriver implements BiometricDriver {
  bool supported = true;
  bool allowAuth = true;
  int authCalls = 0;

  @override
  Future<BiometricCheckResult> checkAvailability() async {
    return BiometricCheckResult(
      supported: supported,
      hasEnrolledBiometrics: supported,
      availableTypes: supported ? [BiometricType.fingerprint] : [],
      hardwareLabel: supported
          ? 'Sidik Jari (Fingerprint)'
          : 'Biometrik tidak tersedia',
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
      message: allowAuth ? null : 'Dibatalkan pengguna',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeBiometricDriver fakeBiometric;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    fakeBiometric = _FakeBiometricDriver();
    BiometricGuardService.driver = fakeBiometric;
    await BiometricGuardService.clearSessionUnlock(clearPreference: true);
  });

  Map<String, dynamic> buildOverviewPayload({
    bool hasPin = false,
    bool biometric = false,
    bool alerts = true,
    bool phoneVerified = true,
    String phone = '081298443210',
    List<Map<String, dynamic>>? devices,
  }) {
    final activeLayers = [
      phoneVerified,
      hasPin,
      biometric,
      alerts,
    ].where((e) => e).length;
    final devList = devices ??
        [
          {
            'id': 1,
            'token_name': 'google-auth',
            'device_name': 'Samsung Galaxy A54 5G',
            'device_type': 'mobile',
            'platform': 'Android 14',
            'app_version': '1.0.0+1',
            'ip_address': '182.253.14.10',
            'location_label': 'Sesi Aktif Ini',
            'is_current': true,
            'is_trusted': true,
            'last_used_label': 'Aktif sekarang',
          },
          {
            'id': 2,
            'token_name': 'phone-auth',
            'device_name': 'Xiaomi Pad 6',
            'device_type': 'tablet',
            'platform': 'Android 13',
            'app_version': '1.0.0+1',
            'ip_address': '182.253.14.88',
            'location_label': 'Indonesia',
            'is_current': false,
            'is_trusted': true,
            'last_used_label': '2 hari lalu',
          },
        ];

    return {
      'score': {
        'active_layers': activeLayers,
        'total_layers': 4,
        'label': activeLayers >= 3 ? 'Kuat' : (activeLayers == 2 ? 'Sedang' : 'Perlu Ditingkatkan'),
        'level': activeLayers >= 3 ? 'strong' : (activeLayers == 2 ? 'medium' : 'weak'),
        'subtitle': 'Akun Anda terlindungi dengan standar enkripsi City Courier Express.',
        'layers': [
          {'key': 'phone_verified', 'label': 'Verifikasi Nomor Telepon', 'active': phoneVerified},
          {'key': 'transaction_pin', 'label': 'PIN Transaksi 6 Digit', 'active': hasPin},
          {'key': 'biometric_login', 'label': 'Masuk dengan Biometrik', 'active': biometric},
          {'key': 'security_alerts', 'label': 'Notifikasi Keamanan Aktif', 'active': alerts},
        ],
      },
      'user': {
        'id': 9,
        'name': 'Pelanggan Uji',
        'email': 'pelanggan@gmail.com',
        'phone': phone,
        'phone_formatted': '+62 812-9844-3210',
        'phone_verified': phoneVerified,
        'has_google_auth': true,
        'registration_method': 'Google',
        'login_methods': ['Google', if (phoneVerified) 'Nomor Telepon & OTP'],
        'login_method_summary': 'Google • Nomor Telepon & OTP',
      },
      'pin': {
        'has_pin': hasPin,
        'updated_human': hasPin ? 'Terakhir diubah baru saja' : 'Belum diatur • Aktifkan untuk transaksi & keamanan',
      },
      'preferences': {
        'biometric_enabled': biometric,
        'security_alerts_enabled': alerts,
      },
      'devices': devList,
      'trusted_device_count': devList.length,
      'latest_login': {
        'summary': 'Samsung Galaxy A54 5G • Hari ini, 08.18 WIB',
        'device_name': 'Samsung Galaxy A54 5G',
        'time_label': 'Hari ini, 08.18 WIB',
      },
      'activity_logs': [
        {
          'id': 10,
          'event_type': 'login_google',
          'title': 'Login Berhasil via Google',
          'description': 'Sesi login baru dibuka menggunakan akun Google.',
          'device_name': 'Samsung Galaxy A54 5G',
          'ip_address': '182.253.14.10',
          'status': 'success',
          'time_label': '17 Nov 2026, 08.18 WIB',
        },
      ],
      'alert_count': hasPin ? 0 : 1,
    };
  }

  testWidgets('Complete Account Security flows work end-to-end', (tester) async {
    bool hasPin = false;
    bool bioEnabled = false;
    bool alertsEnabled = true;
    List<Map<String, dynamic>> devices = List<Map<String, dynamic>>.from(
      buildOverviewPayload()['devices'] as List,
    );
    String? savedPin;
    bool revokedOthersCalled = false;
    int? revokedDeviceId;

    final client = MockClient((req) async {
      http.Response jsonOk(Map<String, dynamic> body, [int status = 200]) =>
          http.Response.bytes(
            utf8.encode(jsonEncode(body)),
            status,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );

      if (req.url.path.endsWith('/security/overview')) {
        return jsonOk({
          'success': true,
          'data': buildOverviewPayload(
            hasPin: hasPin,
            biometric: bioEnabled,
            alerts: alertsEnabled,
            devices: devices,
          ),
        });
      }
      if (req.url.path.endsWith('/security/pin') && req.method == 'POST') {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        savedPin = body['pin']?.toString();
        hasPin = true;
        return jsonOk({
          'success': true,
          'message': 'PIN Transaksi berhasil dibuat!',
          'data': buildOverviewPayload(
            hasPin: hasPin,
            biometric: bioEnabled,
            alerts: alertsEnabled,
            devices: devices,
          ),
        });
      }
      if (req.url.path.endsWith('/security/preferences') && req.method == 'PATCH') {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        if (body.containsKey('biometric_enabled')) {
          bioEnabled = body['biometric_enabled'] == true;
        }
        if (body.containsKey('security_alerts_enabled')) {
          alertsEnabled = body['security_alerts_enabled'] == true;
        }
        return jsonOk({
          'success': true,
          'message': 'Preferensi keamanan berhasil diperbarui.',
          'data': buildOverviewPayload(
            hasPin: hasPin,
            biometric: bioEnabled,
            alerts: alertsEnabled,
            devices: devices,
          ),
        });
      }
      if (req.url.path.endsWith('/security/devices/2') && req.method == 'DELETE') {
        revokedDeviceId = 2;
        devices = devices.where((d) => d['id'] != 2).toList();
        return jsonOk({
          'success': true,
          'message': 'Perangkat berhasil dihapus dari sesi tepercaya.',
          'data': buildOverviewPayload(
            hasPin: hasPin,
            biometric: bioEnabled,
            alerts: alertsEnabled,
            devices: devices,
          ),
        });
      }
      if (req.url.path.endsWith('/security/devices/revoke-others') &&
          req.method == 'POST') {
        revokedOthersCalled = true;
        devices = devices.where((d) => d['is_current'] == true).toList();
        return jsonOk({
          'success': true,
          'message': 'Semua sesi di perangkat lain telah berhasil diakhiri.',
          'revoked_count': 1,
          'data': buildOverviewPayload(
            hasPin: hasPin,
            biometric: bioEnabled,
            alerts: alertsEnabled,
            devices: devices,
          ),
        });
      }
      return http.Response('{}', 404);
    });

    final service = AccountSecurityService(
      client: client,
      baseUrl: 'https://example.test/api',
      tokenReader: () async => 'test-token',
      deviceHeadersReader: () async => {
        'X-Device-Name': 'Samsung Galaxy A54 5G',
        'X-Device-Id': 'dev-1',
        'X-Device-Platform': 'Android 14',
        'X-App-Version': '1.0.0+1',
      },
    );

    String? requestedPhone;
    String? verifiedOtp;

    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: AccountSecurityScreen(
          securityService: service,
          onRequestPhoneOtp: (phone) async {
            requestedPhone = phone;
            return {'success': true, 'retry_after': 60};
          },
          onVerifyPhoneOtp: (phone, otp) async {
            verifiedOtp = otp;
            return {'success': true};
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Keamanan Akun'), findsOneWidget);
    expect(find.text('Skor Keamanan: Sedang'), findsOneWidget);
    expect(find.text('2 dari 4 lapis keamanan aktif'), findsOneWidget);
    expect(find.text('2 Aktif'), findsOneWidget);

    // 1. Toggle biometric ON -> invokes BiometricDriver & PATCH /preferences
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(fakeBiometric.authCalls, 1);
    expect(bioEnabled, isTrue);
    expect(find.text('3 dari 4 lapis keamanan aktif'), findsOneWidget);

    // 2. Navigate to PIN screen via 'Atur' button & create PIN 482910
    await tester.tap(find.text('Atur'));
    await tester.pumpAndSettle();
    expect(find.text('Buat PIN Transaksi'), findsWidgets);

    for (final d in ['4', '8', '2', '9', '1', '0']) {
      await tester.tap(find.byKey(ValueKey('pin-key-$d')));
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.tap(find.text('Lanjut Konfirmasi PIN'));
    await tester.pumpAndSettle();
    expect(find.text('Konfirmasi PIN Baru'), findsOneWidget);

    for (final d in ['4', '8', '2', '9', '1', '0']) {
      await tester.tap(find.byKey(ValueKey('pin-key-$d')));
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.tap(find.text('Simpan PIN Baru'));
    await tester.pumpAndSettle();

    expect(savedPin, '482910');
    expect(find.text('4 dari 4 lapis keamanan aktif'), findsOneWidget);

    // 3. Navigate to Phone Verification screen & test Ubah Nomor modal + OTP
    await tester.tap(find.text('Verifikasi Akun').first);
    await tester.pumpAndSettle();
    expect(find.text('Identitas Terverifikasi'), findsOneWidget);

    // Tap 'Ubah' on the Verifikasi Akun screen
    final ubahButton = find.widgetWithText(OutlinedButton, 'Ubah');
    await tester.tap(ubahButton.first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '81211122233');
    await tester.tap(find.text('Kirim OTP & Simpan'));
    await tester.pumpAndSettle();

    expect(requestedPhone, '081211122233');
    expect(find.text('Verifikasi Kode OTP'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '654321');
    await tester.tap(find.text('Verifikasi'));
    await tester.pumpAndSettle();
    expect(verifiedOtp, '654321');

    // Back from phone screen to main
    await tester.tap(find.byIcon(Icons.arrow_back_rounded).at(2));
    await tester.pumpAndSettle();

    // 4. Open Perangkat Tepercaya & remove Xiaomi Pad 6
    await tester.tap(find.text('Perangkat Tepercaya').first);
    await tester.pumpAndSettle();
    expect(find.text('Xiaomi Pad 6'), findsOneWidget);
    expect(find.text('Sesi Ini'), findsOneWidget);

    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus Sesi'));
    await tester.pumpAndSettle();
    expect(revokedDeviceId, 2);

    // Back to main & test Keluar dari Semua Perangkat
    await tester.tap(find.byIcon(Icons.arrow_back_rounded).at(3));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Keluar dari Semua Perangkat'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Keluar dari Semua Perangkat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keluar dari Semua Perangkat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keluar Semua'));
    await tester.pumpAndSettle();
    expect(revokedOthersCalled, isTrue);

    // Let any active toast timer expire cleanly before test disposes widget tree.
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('CustomerWithdrawalScreen prompts 6-digit PIN when hasTransactionPin is true', (tester) async {
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
        return http.Response(jsonEncode({'success': true, 'data': {'items': []}}), 200);
      }
      if (req.url.path.endsWith('/withdrawals') && req.method == 'POST') {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        sentPin = body['transaction_pin']?.toString();
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'id': 77,
              'reference': 'WD-CUST-77',
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
      tokenReader: () async => 'test-token',
    );

    const summaryWithPin = CustomerWalletSummary(
      walletId: 1,
      walletType: 'customer',
      currency: 'IDR',
      status: 'active',
      isFrozen: false,
      availableBalance: 200000,
      pendingBalance: 0,
      reservedBalance: 0,
      totalCredited: 200000,
      totalDebited: 0,
      mode: 'sandbox',
      isSandboxOrDemo: true,
      activePaymentProvider: 'mock',
      withdrawalEnabled: true,
      withdrawalMinIdr: 10000,
      withdrawalMaxIdr: 5000000,
      topupMinIdr: 10000,
      topupMaxIdr: 10000000,
      hasTransactionPin: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CustomerWithdrawalScreen(
          wallet: summaryWithPin,
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

    // TransactionPinPromptSheet should pop up
    expect(find.text('Masukkan PIN Transaksi'), findsOneWidget);

    for (final d in ['5', '9', '2', '8', '3', '7']) {
      await tester.tap(find.widgetWithText(InkWell, d));
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pumpAndSettle();

    expect(sentPin, '592837');
  });
}
