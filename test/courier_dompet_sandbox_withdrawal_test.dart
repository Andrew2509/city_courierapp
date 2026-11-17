import 'dart:convert';

import 'package:city_courierapp/screens/courier/ci_word/wallet/courier_payout_destinations_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/wallet/dompet_screen.dart';
import 'package:city_courierapp/services/wallet/courier_wallet_v1_service.dart';
import 'package:city_courierapp/services/wallet/wallet_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CourierWalletV1Service buildMockV1Service({
    List<Map<String, dynamic>>? initialPayouts,
    bool providerEnabled = true,
  }) {
    var availableBalance = 150000;
    var reservedBalance = 0;
    final payouts = List<Map<String, dynamic>>.from(initialPayouts ?? []);
    final destinations = <Map<String, dynamic>>[
      {
        'id': 7,
        'owner_type': 'courier',
        'destination_type': 'bank',
        'channel_code': 'ID_BCA',
        'channel_name': 'Bank BCA',
        'account_number_masked': '******3456',
        'account_holder_name': 'Kurir Sandbox',
        'is_verified': true,
        'verification_status': 'verified',
        'is_default': true,
        'is_active': true,
      },
    ];
    var nextDestId = 8;

    final client = MockClient((request) async {
      final path = request.url.path;

      if (path.endsWith('/v1/courier/wallet') && request.method == 'GET') {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'wallet_id': 10,
              'courier_id': 5,
              'status': 'active',
              'is_frozen': false,
              'available_balance': availableBalance,
              'pending_balance': 0,
              'reserved_balance': reservedBalance,
              'mode': 'sandbox',
              'is_sandbox_or_demo': true,
              'active_payout_provider': 'mock',
              'security': {'has_transaction_pin': false},
              'payout_policy': {
                'auto_payout_enabled': true,
                'provider_enabled': providerEnabled,
                'min_payout_idr': 20000,
                'max_payout_idr': 5000000,
                'fee_idr': 0,
                'schedule_cron': '0 * * * *',
                'eligible_for_next_auto_payout': false,
              },
              'earnings_summary': {},
            },
          }),
          200,
        );
      }

      if (path.endsWith('/v1/courier/wallet/destinations') &&
          request.method == 'GET') {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {'items': destinations},
          }),
          200,
        );
      }

      if (path.endsWith('/v1/courier/wallet/destinations') &&
          request.method == 'POST') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final type = (body['destination_type'] ?? 'bank').toString();
        final code = (body['channel_code'] ?? 'ID_BCA').toString();
        final acc = (body['account_number'] ?? '').toString();
        final holder = (body['account_holder_name'] ?? '').toString();
        final masked = acc.length > 4
            ? '${'*' * (acc.length - 4)}${acc.substring(acc.length - 4)}'
            : acc;
        final created = {
          'id': nextDestId++,
          'owner_type': 'courier',
          'destination_type': type,
          'channel_code': code,
          'channel_name': code == 'ID_OVO'
              ? 'OVO'
              : (code == 'ID_BRI' ? 'Bank BRI' : code),
          'account_number_masked': masked,
          'account_holder_name': holder,
          'is_verified': true,
          'verification_status': 'verified',
          'is_default': body['is_default'] == true,
          'is_active': true,
        };
        if (body['is_default'] == true) {
          for (final d in destinations) {
            d['is_default'] = false;
          }
        }
        destinations.add(created);
        return http.Response(
          jsonEncode({'success': true, 'data': created}),
          201,
        );
      }

      if (path.endsWith('/v1/courier/wallet/payouts') &&
          request.method == 'GET') {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'auto_payout_status': {
                'auto_payout_enabled': true,
                'eligible_now': false,
                'available_balance': availableBalance,
                'reserved_balance': reservedBalance,
                'min_payout_idr': 20000,
                'schedule_cron': '0 * * * *',
                'missing_requirements': [],
              },
              'items': payouts,
            },
          }),
          200,
        );
      }

      if (path.endsWith('/v1/courier/wallet/withdrawals') &&
          request.method == 'POST') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final amount = (body['amount'] as num).toInt();
        availableBalance -= amount;
        reservedBalance += amount;
        final created = {
          'id': 99,
          'reference': 'WD-CUR-SANDBOX-99',
          'owner_type': 'courier',
          'payout_type': 'courier_manual_withdrawal',
          'provider': 'mock',
          'mode': 'sandbox',
          'is_simulated': true,
          'channel_code': 'ID_BCA',
          'account_number_masked': '******3456',
          'account_holder_name': 'Kurir Sandbox',
          'amount': amount,
          'fee': 0,
          'net_amount': amount,
          'status': 'pending',
          'status_history': [],
        };
        payouts.insert(0, created);
        return http.Response(
          jsonEncode({
            'success': true,
            'data': created,
          }),
          201,
        );
      }

      return http.Response(jsonEncode({'success': true, 'data': {}}), 200);
    });

    return CourierWalletV1Service(
      client: client,
      baseUrl: 'https://example.test/api',
      tokenReader: () async => 'courier-token',
    );
  }

  testWidgets(
    'DompetScreen hides Earnings hub, chip buttons, Total pendapatan, and DANA card, and connects Tarik Saldo directly to v1 Sandbox withdrawal',
    (tester) async {
      final v1Service = buildMockV1Service();

      await tester.pumpWidget(
        MaterialApp(
          home: DompetScreen(
            v1Service: v1Service,
            walletFetcher: () async => {
              'success': true,
              'data': {
                'available_balance': 150000,
                'pending_balance': 0,
                'total_earnings': 500000,
              },
            },
            historyFetcher: () async => {
              'success': true,
              'items': <WalletHistoryItem>[],
            },
            notificationsFetcher: () async => {
              'success': true,
              'items': <WalletNotificationItem>[],
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Removed Image 1 elements (hub card + 6 chip buttons) and earning text
      expect(find.text('Earnings & Auto-Payout'), findsNothing);
      expect(find.textContaining('Pending Settlement'), findsNothing);
      expect(find.text('Ringkasan Earnings'), findsNothing);
      expect(find.text('Pending'), findsNothing);
      expect(find.text('Available'), findsNothing);
      expect(find.text('Rekening & E-Wallet'), findsNothing);
      expect(find.text('Auto-Payout'), findsNothing);
      expect(find.text('Riwayat Payout'), findsNothing);
      expect(find.text('Total pendapatan'), findsNothing);

      // Removed Image 2 element (DANA card)
      expect(find.text('DANA'), findsNothing);
      expect(find.textContaining('Metode pencairan saldo penghasilan'), findsNothing);

      // Sandbox badge & Tarik Saldo remain visible
      expect(find.text('SANDBOX (SIMULASI)'), findsOneWidget);
      expect(find.text('Tarik Saldo'), findsOneWidget);

      // Tap Tarik Saldo -> opens CourierWithdrawalV1Screen directly
      await tester.tap(find.text('Tarik Saldo'));
      await tester.pumpAndSettle();

      expect(find.text('Ajukan Penarikan'), findsOneWidget);
      expect(find.text('SANDBOX (SIMULASI)'), findsOneWidget);
      expect(find.textContaining('Bank BCA'), findsWidgets);

      // Enter nominal 50000 and submit
      await tester.enterText(find.byType(TextField), '50000');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ajukan Penarikan'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.textContaining('WD-CUR-SANDBOX-99'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('WD-CUR-SANDBOX-99'), findsOneWidget);
    },
  );

  testWidgets(
    'Kelola Rekening, Tambah Rekening Bank, dan Tambah Akun E-Wallet berfungsi sesuai desain baru',
    (tester) async {
      final v1Service = buildMockV1Service();

      await tester.pumpWidget(
        MaterialApp(
          home: CourierPayoutDestinationsScreen(service: v1Service),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Rekening & E-Wallet'), findsOneWidget);
      expect(find.text('Bank BCA'), findsOneWidget);
      expect(find.text('+ Rekening Bank'), findsOneWidget);
      expect(find.text('+ E-Wallet'), findsOneWidget);

      // Tambah Rekening Bank
      await tester.tap(find.text('+ Rekening Bank'));
      await tester.pumpAndSettle();

      expect(find.text('Tambah Rekening Bank'), findsOneWidget);
      final bankFields = find.byType(TextField);
      await tester.enterText(bankFields.at(0), '9988776655');
      await tester.enterText(bankFields.at(1), 'Budi Kurir');
      await tester.tap(find.text('Simpan Rekening Bank'));
      await tester.pumpAndSettle();

      expect(find.text('Rekening & E-Wallet'), findsOneWidget);
      expect(find.textContaining('Budi Kurir'), findsOneWidget);

      // Tambah Akun E-Wallet
      await tester.tap(find.text('+ E-Wallet'));
      await tester.pumpAndSettle();

      expect(find.text('Tambah Akun E-Wallet'), findsOneWidget);
      await tester.tap(find.text('OVO'));
      await tester.pumpAndSettle();
      final ewalletFields = find.byType(TextField);
      await tester.enterText(ewalletFields.at(0), '081234567890');
      await tester.enterText(ewalletFields.at(1), 'Budi OVO');
      await tester.tap(find.text('Simpan E-Wallet'));
      await tester.pumpAndSettle();

      expect(find.text('OVO'), findsOneWidget);
      expect(find.textContaining('Budi OVO'), findsOneWidget);
    },
  );
}
