import 'dart:convert';

import 'package:city_courierapp/screens/courier/ci_word/wallet/add_bank_account_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/wallet/add_ewallet_account_screen.dart';
import 'package:city_courierapp/screens/wallet/customer_refund_screen.dart';
import 'package:city_courierapp/screens/wallet/customer_wallet_dashboard_screen.dart';
import 'package:city_courierapp/screens/wallet/payout_destinations_screen.dart';
import 'package:city_courierapp/screens/wallet/topup_amount_screen.dart';
import 'package:city_courierapp/screens/wallet/topup_instruction_screen.dart';
import 'package:city_courierapp/screens/wallet/topup_method_screen.dart';
import 'package:city_courierapp/screens/wallet/topup_status_screen.dart';
import 'package:city_courierapp/screens/wallet/wallet_transaction_detail_screen.dart';
import 'package:city_courierapp/screens/wallet/wallet_transactions_screen.dart';
import 'package:city_courierapp/services/wallet/courier_wallet_v1_service.dart';
import 'package:city_courierapp/services/wallet/customer_wallet_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'CustomerWalletDashboardScreen navigates to redesigned Riwayat & Detail Transaksi with filtering',
    (tester) async {
      String? lastTypeFilter;
      final allTxs = [
        {
          'id': 101,
          'type': 'topup',
          'direction': 'credit',
          'amount': 150000,
          'signed_amount': 150000,
          'balance_before': 100000,
          'balance_after': 250000,
          'status': 'completed',
          'reference_id': 'TOPUP-101',
          'description': 'Top-up Saldo QRIS',
          'mode': 'sandbox',
        },
        {
          'id': 102,
          'type': 'payment',
          'direction': 'debit',
          'amount': 35000,
          'signed_amount': -35000,
          'balance_before': 250000,
          'balance_after': 215000,
          'status': 'completed',
          'reference_id': 'PAY-102',
          'description': 'Pembayaran Order CC-01',
          'mode': 'sandbox',
        },
      ];

      final client = MockClient((req) async {
        final path = req.url.path;
        if (path.endsWith('/v1/customer/wallet') && req.method == 'GET') {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'wallet_id': 1,
                'wallet_type': 'customer',
                'currency': 'IDR',
                'status': 'active',
                'is_frozen': false,
                'available_balance': 215000,
                'pending_balance': 0,
                'reserved_balance': 0,
                'total_credited': 250000,
                'total_debited': 35000,
                'mode': 'sandbox',
                'is_sandbox_or_demo': true,
                'active_payment_provider': 'mock',
                'topup_provider_enabled': true,
                'withdrawal_policy': {
                  'enabled': true,
                  'provider_enabled': true,
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

        if (path.endsWith('/v1/customer/wallet/transactions') &&
            req.method == 'GET') {
          final type = req.url.queryParameters['type'];
          lastTypeFilter = type;
          final filtered = type == null
              ? allTxs
              : allTxs.where((e) => e['type'] == type).toList();
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'items': filtered,
                'pagination': {
                  'current_page': 1,
                  'last_page': 1,
                  'per_page': 15,
                  'total': filtered.length,
                },
              },
            }),
            200,
          );
        }

        if (path.endsWith('/v1/customer/wallet/transactions/101') &&
            req.method == 'GET') {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': allTxs.first,
            }),
            200,
          );
        }

        return http.Response('{}', 404);
      });

      final service = CustomerWalletService(
        client: client,
        baseUrl: 'https://example.test/api',
        tokenReader: () async => 'cust-token',
      );

      await tester.pumpWidget(
        MaterialApp(home: CustomerWalletDashboardScreen(service: service)),
      );
      await tester.pumpAndSettle();

      expect(find.text('City Wallet Saya'), findsOneWidget);
      expect(find.text('Rp 215.000'), findsOneWidget);
      expect(find.text('Riwayat'), findsOneWidget);
      expect(find.text('Rekening'), findsOneWidget);
      expect(find.text('Tarik Dana'), findsOneWidget);
      expect(find.text('Refund'), findsOneWidget);

      await tester.tap(find.text('Riwayat'));
      await tester.pumpAndSettle();

      expect(find.byType(WalletTransactionsScreen), findsOneWidget);
      expect(find.text('Riwayat Transaksi'), findsOneWidget);
      expect(find.text('Top-up Saldo QRIS'), findsOneWidget);
      expect(find.text('Pembayaran Order CC-01'), findsOneWidget);

      // Filter by Top-Up
      await tester.tap(find.widgetWithText(ChoiceChip, 'Top-Up'));
      await tester.pumpAndSettle();
      expect(lastTypeFilter, 'topup');
      expect(find.text('Top-up Saldo QRIS'), findsOneWidget);
      expect(find.text('Pembayaran Order CC-01'), findsNothing);

      // Open transaction detail
      await tester.tap(find.text('Top-up Saldo QRIS'));
      await tester.pumpAndSettle();

      expect(find.byType(WalletTransactionDetailScreen), findsOneWidget);
      expect(find.text('Detail Transaksi'), findsOneWidget);
      expect(find.text('TOPUP-101'), findsOneWidget);
    },
  );

  testWidgets(
    'PayoutDestinationsScreen supports adding Bank & E-Wallet and setting default',
    (tester) async {
      final destinations = <Map<String, dynamic>>[
        {
          'id': 1,
          'owner_type': 'customer',
          'destination_type': 'bank',
          'channel_code': 'ID_BCA',
          'channel_name': 'Bank BCA',
          'account_number_masked': '******1111',
          'account_holder_name': 'Sari Customer',
          'is_verified': true,
          'verification_status': 'verified',
          'is_default': true,
          'is_active': true,
        },
      ];
      var nextId = 2;

      final client = MockClient((req) async {
        final path = req.url.path;
        if (path.endsWith('/v1/customer/wallet/destinations') &&
            req.method == 'GET') {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {'items': destinations},
            }),
            200,
          );
        }

        if (path.endsWith('/v1/customer/wallet/destinations') &&
            req.method == 'POST') {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          final code = (body['channel_code'] ?? 'ID_BCA').toString();
          final acc = (body['account_number'] ?? '').toString();
          final masked = acc.length > 4
              ? '${'*' * (acc.length - 4)}${acc.substring(acc.length - 4)}'
              : acc;
          final created = {
            'id': nextId++,
            'owner_type': 'customer',
            'destination_type': body['destination_type'] ?? 'bank',
            'channel_code': code,
            'channel_name': code == 'ID_DANA'
                ? 'DANA'
                : (code == 'ID_OVO' ? 'OVO' : 'Bank BCA ($code)'),
            'account_number_masked': masked,
            'account_holder_name': body['account_holder_name'],
            'is_verified': true,
            'verification_status': 'verified',
            'is_default': body['is_default'] == true,
            'is_active': true,
          };
          if (created['is_default'] == true) {
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

        if (path.contains('/v1/customer/wallet/destinations/') &&
            req.method == 'PATCH') {
          final id = int.parse(path.split('/').last);
          late Map<String, dynamic> target;
          for (final d in destinations) {
            final isTarget = d['id'] == id;
            d['is_default'] = isTarget;
            if (isTarget) target = d;
          }
          return http.Response(
            jsonEncode({'success': true, 'data': target}),
            200,
          );
        }

        return http.Response('{}', 404);
      });

      final service = CustomerWalletService(
        client: client,
        baseUrl: 'https://example.test/api',
        tokenReader: () async => 'cust-token',
      );

      await tester.pumpWidget(
        MaterialApp(home: PayoutDestinationsScreen(service: service)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Rekening & E-Wallet'), findsOneWidget);
      expect(find.text('Bank BCA'), findsOneWidget);
      expect(find.text('DEFAULT'), findsOneWidget);

      // Open sheet via + E-Wallet and add OVO
      await tester.tap(find.text('+ E-Wallet'));
      await tester.pumpAndSettle();

      expect(find.text('Tambah Rekening / E-Wallet'), findsOneWidget);
      final sheetFields = find.byType(TextField);
      await tester.enterText(sheetFields.at(0), '081234567899');
      await tester.enterText(sheetFields.at(1), 'Sari OVO');
      await tester.tap(find.text('Simpan Rekening Tujuan'));
      await tester.pumpAndSettle();

      expect(find.text('DANA'), findsOneWidget);
      expect(find.textContaining('Sari OVO'), findsOneWidget);
      // Bank BCA is no longer default, so 'Jadikan Default' action is now shown
      expect(find.text('Jadikan Default'), findsOneWidget);

      await tester.tap(find.text('Jadikan Default'));
      await tester.pumpAndSettle();
      expect(find.text('DEFAULT'), findsOneWidget);
      expect(find.text('Jadikan Default'), findsOneWidget);
    },
  );

  testWidgets(
    'CustomerRefundScreen submits refund request with redesigned sticky CTA and refreshes list',
    (tester) async {
      final refunds = <Map<String, dynamic>>[];

      final client = MockClient((req) async {
        final path = req.url.path;
        if (path.endsWith('/v1/customer/wallet/refunds') &&
            req.method == 'GET') {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'items': refunds,
                'eligible_shipments': [
                  {
                    'id': 77,
                    'shipment_number': 'SHP-CUST-77',
                    'status': 'paid',
                    'total_cost': 45000,
                  },
                ],
              },
            }),
            200,
          );
        }

        if (path.endsWith('/v1/customer/wallet/refunds') &&
            req.method == 'POST') {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          final created = {
            'id': 501,
            'reference': 'REF-CUST-501',
            'shipment_id': body['shipment_id'],
            'order_id': 900,
            'amount': 45000,
            'status': 'completed',
            'destination': 'wallet',
            'reason': body['reason'],
            'mode': 'sandbox',
            'is_simulated': true,
          };
          refunds.insert(0, created);
          return http.Response(
            jsonEncode({'success': true, 'data': created}),
            201,
          );
        }

        return http.Response('{}', 404);
      });

      final service = CustomerWalletService(
        client: client,
        baseUrl: 'https://example.test/api',
        tokenReader: () async => 'cust-token',
      );

      await tester.pumpWidget(
        MaterialApp(home: CustomerRefundScreen(service: service)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pengajuan Refund'), findsOneWidget);
      expect(find.textContaining('SHP-CUST-77'), findsOneWidget);

      await tester.enterText(
        find.byType(TextField),
        'Kurir batal menjemput paket sesuai jadwal',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Kirim Pengajuan Refund'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.textContaining('REF-CUST-501'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('REF-CUST-501'), findsOneWidget);
    },
  );

  testWidgets(
    'Redesigned Customer Top-Up flow works end-to-end from TopupAmountScreen to TopupStatusScreen',
    (tester) async {
      final topupPayload = {
        'id': 33,
        'reference': 'TOPUP-REDESIGN-33',
        'provider': 'mock',
        'mode': 'sandbox',
        'is_simulated': true,
        'payment_type': 'va',
        'channel_code': 'BCA_VIRTUAL_ACCOUNT',
        'amount': 100000,
        'fee': 0,
        'net_amount': 100000,
        'status': 'pending',
        'va_number': '88001234999',
        'instructions': ['Buka m-BCA dan masukkan nomor VA.'],
      };

      final client = MockClient((req) async {
        final path = req.url.path;
        if (path.endsWith('/v1/customer/wallet/topups/methods') &&
            req.method == 'GET') {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'mode': 'sandbox',
                'is_simulated': true,
                'active_provider': 'mock',
                'provider_enabled': true,
                'methods': [
                  {
                    'channel_code': 'BCA_VIRTUAL_ACCOUNT',
                    'label': 'BCA Virtual Account',
                    'payment_type': 'va',
                    'fee_idr': 0,
                    'provider': 'mock',
                  },
                  {
                    'channel_code': 'QRIS',
                    'label': 'QRIS Instan',
                    'payment_type': 'qris',
                    'fee_idr': 0,
                    'provider': 'mock',
                  },
                ],
              },
            }),
            200,
          );
        }

        if (path.endsWith('/v1/customer/wallet/topups') &&
            req.method == 'POST') {
          return http.Response(
            jsonEncode({'success': true, 'data': topupPayload}),
            201,
          );
        }

        if (path.endsWith('/v1/customer/wallet/topups/33/simulate-paid') &&
            req.method == 'POST') {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                ...topupPayload,
                'status': 'settled',
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
        tokenReader: () async => 'cust-token',
      );

      await tester.pumpWidget(
        MaterialApp(home: TopupAmountScreen(service: service)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Top-Up City Wallet'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Rp 100.000'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pilih Metode (Rp 100.000)'));
      await tester.pumpAndSettle();

      expect(find.byType(TopupMethodScreen), findsOneWidget);
      expect(find.text('Pilih Metode Top-Up'), findsOneWidget);
      expect(find.text('BCA Virtual Account'), findsOneWidget);
      expect(find.text('QRIS Instan'), findsOneWidget);

      await tester.tap(find.text('Buat Instruksi Pembayaran'));
      await tester.pumpAndSettle();

      expect(find.byType(TopupInstructionScreen), findsOneWidget);
      expect(find.text('Instruksi Top-Up'), findsOneWidget);
      expect(find.text('88001234999'), findsOneWidget);

      await tester.tap(find.text('Simulasikan Pembayaran Berhasil (Sandbox)'));
      await tester.pumpAndSettle();

      expect(find.byType(TopupStatusScreen), findsOneWidget);
      expect(find.text('Top-Up Berhasil!'), findsOneWidget);
      expect(find.text('TOPUP-REDESIGN-33'), findsOneWidget);
      expect(find.text('Kembali ke Wallet'), findsOneWidget);
    },
  );

  testWidgets(
    'Real-time destination inquiry auto-fills owner name without typing on Customer and Courier forms',
    (tester) async {
      String? submittedCustomerHolder;
      String? submittedBankHolder;
      String? submittedEwalletHolder;

      final custClient = MockClient((req) async {
        final path = req.url.path;
        if (path.endsWith('/v1/customer/wallet/destinations') &&
            req.method == 'GET') {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {'items': []},
            }),
            200,
          );
        }
        if (path.endsWith('/v1/customer/wallet/destinations/inquiry') &&
            req.method == 'POST') {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'supported': true,
                'found': true,
                'account_holder_name': 'SARI WIBOWO',
                'channel_code': 'ID_DANA',
                'account_number': '081234567890',
                'mode': 'sandbox',
                'is_simulated': true,
                'provider': 'mock',
                'message': 'Nama pemilik ditemukan (Simulasi Sandbox).',
              },
            }),
            200,
          );
        }
        if (path.endsWith('/v1/customer/wallet/destinations') &&
            req.method == 'POST') {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          submittedCustomerHolder = body['account_holder_name']?.toString();
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'id': 9,
                'owner_type': 'customer',
                'destination_type': body['destination_type'],
                'channel_code': body['channel_code'],
                'channel_name': 'DANA',
                'account_number_masked': '******7890',
                'account_holder_name': submittedCustomerHolder,
                'is_verified': true,
                'verification_status': 'verified',
                'is_default': true,
                'is_active': true,
              },
            }),
            201,
          );
        }
        return http.Response('{}', 404);
      });

      final custSvc = CustomerWalletService(
        client: custClient,
        baseUrl: 'https://example.test/api',
        tokenReader: () async => 'cust-token',
      );

      await tester.pumpWidget(
        MaterialApp(home: PayoutDestinationsScreen(service: custSvc)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('+ E-Wallet'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), '081234567890');
      // Wait for 450ms real-time inquiry debounce to resolve
      await tester.pump(const Duration(milliseconds: 550));
      await tester.pumpAndSettle();

      expect(find.textContaining('SARI WIBOWO'), findsWidgets);
      expect(find.text('Terisi otomatis'), findsOneWidget);

      // Submit WITHOUT typing in the Name field manually
      await tester.tap(find.text('Simpan Rekening Tujuan'));
      await tester.pumpAndSettle();
      expect(submittedCustomerHolder, 'SARI WIBOWO');

      // Now verify Courier AddBankAccountScreen & AddEwalletAccountScreen
      final curClient = MockClient((req) async {
        final path = req.url.path;
        if (path.endsWith('/v1/courier/wallet/destinations/inquiry') &&
            req.method == 'POST') {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          final isBank = body['destination_type'] == 'bank';
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'supported': true,
                'found': true,
                'account_holder_name': isBank ? 'BUDI SANTOSO' : 'RINA DANA',
                'channel_code': body['channel_code'],
                'account_number': body['account_number'],
                'mode': 'sandbox',
                'is_simulated': true,
                'provider': 'mock',
                'message': 'Nama pemilik ditemukan (Simulasi Sandbox).',
              },
            }),
            200,
          );
        }
        if (path.endsWith('/v1/courier/wallet/destinations') &&
            req.method == 'POST') {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          if (body['destination_type'] == 'bank') {
            submittedBankHolder = body['account_holder_name']?.toString();
          } else {
            submittedEwalletHolder = body['account_holder_name']?.toString();
          }
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'id': 12,
                'owner_type': 'courier',
                'destination_type': body['destination_type'],
                'channel_code': body['channel_code'],
                'channel_name': body['channel_code'],
                'account_number_masked': '******7890',
                'account_holder_name': body['account_holder_name'],
                'is_verified': true,
                'verification_status': 'verified',
                'is_default': true,
                'is_active': true,
              },
            }),
            201,
          );
        }
        return http.Response('{}', 404);
      });

      final curSvc = CourierWalletV1Service(
        client: curClient,
        baseUrl: 'https://example.test/api',
        tokenReader: () async => 'cur-token',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: ElevatedButton(
                onPressed: () => Navigator.push(
                  ctx,
                  MaterialPageRoute(
                    builder: (_) => AddBankAccountScreen(service: curSvc),
                  ),
                ),
                child: const Text('Push Bank'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Push Bank'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), '1234567890');
      await tester.pump(const Duration(milliseconds: 550));
      await tester.pumpAndSettle();

      expect(find.text('BUDI SANTOSO'), findsOneWidget);
      await tester.tap(find.text('Simpan Rekening Bank'));
      await tester.pumpAndSettle();
      expect(submittedBankHolder, 'BUDI SANTOSO');
      expect(find.text('Push Bank'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: ElevatedButton(
                onPressed: () => Navigator.push(
                  ctx,
                  MaterialPageRoute(
                    builder: (_) => AddEwalletAccountScreen(service: curSvc),
                  ),
                ),
                child: const Text('Push Ewallet'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Push Ewallet'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), '081298765432');
      await tester.pump(const Duration(milliseconds: 550));
      await tester.pumpAndSettle();

      expect(find.text('RINA DANA'), findsOneWidget);
      await tester.tap(find.text('Simpan E-Wallet'));
      await tester.pumpAndSettle();
      expect(submittedEwalletHolder, 'RINA DANA');
      expect(find.text('Push Ewallet'), findsOneWidget);
    },
  );
}
