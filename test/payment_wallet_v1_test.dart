import 'dart:convert';

import 'package:city_courierapp/models/wallet/wallet_models.dart';
import 'package:city_courierapp/screens/courier/ci_word/wallet/auto_payout_status_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/wallet/courier_earnings_overview_screen.dart';
import 'package:city_courierapp/screens/wallet/customer_refund_screen.dart';
import 'package:city_courierapp/screens/wallet/customer_wallet_dashboard_screen.dart';
import 'package:city_courierapp/screens/wallet/customer_withdrawal_screen.dart';
import 'package:city_courierapp/screens/wallet/topup_instruction_screen.dart';
import 'package:city_courierapp/services/wallet/courier_wallet_v1_service.dart';
import 'package:city_courierapp/services/wallet/customer_wallet_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('CustomerWalletService & CourierWalletV1Service API contracts', () {
    test('CustomerWalletService parses wallet summary and topup with Idempotency-Key', () async {
      String? capturedIdem;
      final client = MockClient((req) async {
        if (req.url.path.endsWith('/v1/customer/wallet')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'message': 'OK',
              'data': {
                'wallet_id': 10,
                'wallet_type': 'customer',
                'currency': 'IDR',
                'status': 'active',
                'is_frozen': false,
                'available_balance': 150000,
                'pending_balance': 0,
                'reserved_balance': 0,
                'total_credited': 200000,
                'total_debited': 50000,
                'mode': 'sandbox',
                'is_sandbox_or_demo': true,
                'active_payment_provider': 'mock',
                'withdrawal_policy': {'enabled': true, 'min_amount_idr': 10000, 'max_amount_idr': 5000000},
                'topup_policy': {'min_amount_idr': 10000, 'max_amount_idr': 10000000},
              },
            }),
            200,
          );
        }
        if (req.url.path.endsWith('/v1/customer/wallet/topups')) {
          capturedIdem = req.headers['Idempotency-Key'];
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'id': 5,
                'reference': 'TOPUP-TEST-5',
                'provider': 'mock',
                'mode': 'sandbox',
                'is_simulated': true,
                'payment_type': 'va',
                'channel_code': 'BCA_VIRTUAL_ACCOUNT',
                'amount': 100000,
                'fee': 0,
                'net_amount': 100000,
                'status': 'pending',
                'va_number': '8808123456',
                'instructions': ['Transfer VA'],
              },
            }),
            201,
          );
        }
        if (req.url.path.endsWith('/v1/customer/wallet/withdrawals')) {
          return http.Response(
            jsonEncode({
              'success': false,
              'error_code': 'CUSTOMER_WITHDRAWAL_DISABLED_IN_PRODUCTION',
              'message': 'Blocked in production',
            }),
            403,
          );
        }
        return http.Response('{}', 404);
      });

      final service = CustomerWalletService(
        client: client,
        baseUrl: 'https://example.test/api',
        tokenReader: () async => 'test-token',
      );

      final wallet = await service.getWallet();
      expect(wallet.availableBalance, 150000);
      expect(wallet.mode, 'sandbox');
      expect(wallet.withdrawalEnabled, true);

      final topup = await service.createTopup(
        amount: 100000,
        paymentType: 'va',
        channelCode: 'BCA_VIRTUAL_ACCOUNT',
        idempotencyKey: 'idem-topup-ui',
      );
      expect(capturedIdem, 'idem-topup-ui');
      expect(topup.vaNumber, '8808123456');

      expect(
        () => service.requestWithdrawal(amount: 20000, destinationId: 1),
        throwsA(isA<WalletApiException>().having(
          (e) => e.errorCode,
          'errorCode',
          'CUSTOMER_WITHDRAWAL_DISABLED_IN_PRODUCTION',
        )),
      );
    });

    test('CourierWalletV1Service parses earnings and auto-payout status', () async {
      final client = MockClient((req) async {
        if (req.url.path.endsWith('/v1/courier/wallet/earnings')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'summary': {
                  'pending_earnings': 45000,
                  'available_earnings': 90000,
                  'reserved_earnings': 0,
                  'paid_earnings': 180000,
                  'total_gross_earnings': 350000,
                  'total_commission_deducted': 35000,
                  'commission_rate_percent': 10.0,
                  'settlement_waiting_minutes': 1440,
                },
                'items': [
                  {
                    'id': 1,
                    'reference': 'ERN-1',
                    'order_id': 77,
                    'gross_amount': 50000,
                    'commission_rate': 10.0,
                    'commission_amount': 5000,
                    'net_amount': 45000,
                    'status': 'pending',
                    'mode': 'sandbox',
                  }
                ],
              },
            }),
            200,
          );
        }
        return http.Response('{}', 404);
      });

      final courierSvc = CourierWalletV1Service(
        client: client,
        baseUrl: 'https://example.test/api',
        tokenReader: () async => 'courier-token',
      );

      final res = await courierSvc.getEarnings();
      expect(res.summary.pendingEarnings, 45000);
      expect(res.summary.availableEarnings, 90000);
      expect(res.items.length, 1);
      expect(res.items.first.orderId, 77);
    });

    test('CustomerWalletService pays order with wallet and surfaces INSUFFICIENT_BALANCE', () async {
      var callCount = 0;
      final client = MockClient((req) async {
        callCount++;
        if (callCount == 1) {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'payment_transaction': {'reference': 'WALPAY-1', 'amount': 25000, 'status': 'paid', 'mode': 'sandbox'},
                'wallet_available_balance': 75000,
              },
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'success': false,
            'error_code': 'INSUFFICIENT_BALANCE',
            'message': 'Saldo tidak cukup',
          }),
          422,
        );
      });

      final service = CustomerWalletService(
        client: client,
        baseUrl: 'https://example.test/api',
        tokenReader: () async => 't',
      );

      final ok = await service.payOrderWithWallet(shipmentId: 12);
      expect((ok['payment_transaction'] as Map)['reference'], 'WALPAY-1');
      expect(ok['wallet_available_balance'], 75000);

      expect(
        () => service.payOrderWithWallet(shipmentId: 99),
        throwsA(isA<WalletApiException>().having((e) => e.errorCode, 'errorCode', 'INSUFFICIENT_BALANCE')),
      );
    });
  });

  group('Payment & Wallet UI Screens', () {
    testWidgets('CustomerWalletDashboardScreen displays balance, mode badge, freeze notice, and tx', (tester) async {
      final client = MockClient((req) async {
        if (req.url.path.endsWith('/v1/customer/wallet')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'wallet_id': 1,
                'wallet_type': 'customer',
                'currency': 'IDR',
                'status': 'frozen',
                'is_frozen': true,
                'freeze_reason': 'Review keamanan',
                'available_balance': 250000,
                'pending_balance': 0,
                'reserved_balance': 0,
                'total_credited': 250000,
                'total_debited': 0,
                'mode': 'sandbox',
                'is_sandbox_or_demo': true,
                'active_payment_provider': 'mock',
                'withdrawal_policy': {'enabled': true, 'min_amount_idr': 10000, 'max_amount_idr': 5000000},
                'topup_policy': {'min_amount_idr': 10000, 'max_amount_idr': 10000000},
              },
            }),
            200,
          );
        }
        if (req.url.path.contains('/v1/customer/wallet/transactions')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'items': [
                  {
                    'id': 99,
                    'type': 'topup',
                    'direction': 'credit',
                    'amount': 250000,
                    'signed_amount': 250000,
                    'status': 'completed',
                    'reference_id': 'TOPUP-99',
                    'description': 'Top-up QRIS berhasil',
                    'mode': 'sandbox',
                  }
                ],
                'pagination': {'current_page': 1, 'last_page': 1, 'per_page': 6, 'total': 1},
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
        tokenReader: () async => 't',
      );

      await tester.pumpWidget(MaterialApp(home: CustomerWalletDashboardScreen(service: service)));
      await tester.pumpAndSettle();

      expect(find.text('Rp 250.000'), findsOneWidget);
      expect(find.textContaining('Wallet Dibekukan: Review keamanan'), findsOneWidget);
      expect(find.text('Top-up QRIS berhasil'), findsOneWidget);
      expect(find.text('SANDBOX (SIMULASI)'), findsNothing);
      expect(find.textContaining('SANDBOX'), findsNothing);
    });

    testWidgets('CustomerWithdrawalScreen shows production regulatory lock warning when disabled', (tester) async {
      final lockedWallet = CustomerWalletSummary(
        walletId: 2,
        walletType: 'customer',
        currency: 'IDR',
        status: 'active',
        isFrozen: false,
        availableBalance: 100000,
        pendingBalance: 0,
        reservedBalance: 0,
        totalCredited: 100000,
        totalDebited: 0,
        mode: 'production',
        isSandboxOrDemo: false,
        activePaymentProvider: 'xendit',
        withdrawalEnabled: false,
        withdrawalBlockedReason: 'Disabled until regulatory approval',
        withdrawalMinIdr: 10000,
        withdrawalMaxIdr: 5000000,
        topupMinIdr: 10000,
        topupMaxIdr: 10000000,
      );

      final client = MockClient((req) async {
        return http.Response(jsonEncode({'success': true, 'data': {'items': []}}), 200);
      });
      final service = CustomerWalletService(
        client: client,
        baseUrl: 'https://example.test/api',
        tokenReader: () async => 't',
      );

      await tester.pumpWidget(
        MaterialApp(home: CustomerWithdrawalScreen(wallet: lockedWallet, service: service)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Fitur Penarikan Terkunci di Production'), findsOneWidget);
      expect(find.text('Disabled until regulatory approval'), findsOneWidget);
      expect(find.text('Tidak Tersedia di Production'), findsOneWidget);
    });

    testWidgets('TopupInstructionScreen renders VA number and hides simulation button in production', (tester) async {
      final prodTopup = TopupTransactionV1(
        id: 1,
        reference: 'TOPUP-PROD-1',
        provider: 'xendit',
        mode: 'production',
        isSimulated: false,
        paymentType: 'va',
        channelCode: 'BCA_VIRTUAL_ACCOUNT',
        amount: 50000,
        fee: 0,
        netAmount: 50000,
        status: 'pending',
        vaNumber: '88800112233',
        instructions: ['Bayar melalui BCA Mobile'],
      );

      await tester.pumpWidget(MaterialApp(home: TopupInstructionScreen(initialTopup: prodTopup)));
      await tester.pumpAndSettle();

      expect(find.text('88800112233'), findsOneWidget);
      expect(find.text('LIVE PRODUCTION'), findsOneWidget);
      expect(find.text('Simulasikan Pembayaran Berhasil'), findsNothing);
    });

    testWidgets('CourierEarningsOverviewScreen and AutoPayoutStatusScreen render real data', (tester) async {
      final client = MockClient((req) async {
        if (req.url.path.endsWith('/earnings')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'summary': {
                  'pending_earnings': 36000,
                  'available_earnings': 72000,
                  'reserved_earnings': 0,
                  'paid_earnings': 144000,
                  'total_gross_earnings': 280000,
                  'total_commission_deducted': 28000,
                  'commission_rate_percent': 10.0,
                  'settlement_waiting_minutes': 60,
                },
                'items': [],
              },
            }),
            200,
          );
        }
        if (req.url.path.endsWith('/payouts')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'auto_payout_status': {
                  'auto_payout_enabled': true,
                  'eligible_now': true,
                  'available_balance': 72000,
                  'reserved_balance': 0,
                  'min_payout_idr': 20000,
                  'schedule_cron': '0 * * * *',
                  'default_destination': {
                    'id': 3,
                    'owner_type': 'courier',
                    'destination_type': 'bank',
                    'channel_code': 'ID_BCA',
                    'channel_name': 'Bank BCA',
                    'account_number_masked': '8880****1234',
                    'account_holder_name': 'Kurir Budi',
                    'is_verified': true,
                    'verification_status': 'verified',
                    'is_default': true,
                    'is_active': true,
                  },
                  'missing_requirements': [],
                },
                'items': [],
              },
            }),
            200,
          );
        }
        return http.Response('{}', 404);
      });

      final courierSvc = CourierWalletV1Service(
        client: client,
        baseUrl: 'https://example.test/api',
        tokenReader: () async => 't',
      );

      await tester.pumpWidget(MaterialApp(home: CourierEarningsOverviewScreen(service: courierSvc)));
      await tester.pumpAndSettle();

      expect(find.text('Rp 280.000'), findsOneWidget);
      expect(find.text('Rp 36.000'), findsOneWidget);
      expect(find.text('Rp 72.000'), findsOneWidget);

      await tester.pumpWidget(MaterialApp(home: AutoPayoutStatusScreen(service: courierSvc)));
      await tester.pumpAndSettle();

      expect(find.text('Siap Dicairkan Otomatis'), findsOneWidget);
      expect(find.textContaining('Bank BCA (8880****1234)'), findsOneWidget);
    });

    testWidgets('CustomerRefundScreen loads eligible shipments and refund statuses', (tester) async {
      final client = MockClient((req) async {
        if (req.url.path.endsWith('/v1/customer/wallet/refunds') && req.method == 'GET') {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'items': [
                  {
                    'id': 4,
                    'reference': 'REF-004',
                    'shipment_id': 11,
                    'refund_method': 'wallet_credit',
                    'mode': 'sandbox',
                    'amount': 35000,
                    'reason': 'Dibatalkan pelanggan',
                    'status': 'requested',
                  }
                ],
                'eligible_shipments': [
                  {
                    'id': 12,
                    'shipment_number': 'SHP-ELIG-12',
                    'status': 'confirmed',
                    'total_cost': 40000,
                  }
                ],
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
        tokenReader: () async => 't',
      );

      await tester.pumpWidget(MaterialApp(home: CustomerRefundScreen(service: service)));
      await tester.pumpAndSettle();

      expect(find.textContaining('SHP-ELIG-12'), findsOneWidget);
      expect(find.textContaining('REF-004'), findsOneWidget);
    });
  });
}
