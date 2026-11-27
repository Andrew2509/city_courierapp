import 'dart:convert';

import 'package:city_courierapp/screens/courier/ci_word/wallet/courier_withdrawal_v1_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/wallet/dompet_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/wallet/riwayat_transaksi_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/wallet/transaction_detail_screen.dart';
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

      // Layout sesuai referensi baru Dompet Saya: header oranye + floating white saldo card + card Riwayat Transaksi (tanpa 2 tombol tengah)
      expect(find.text('Dompet Saya'), findsOneWidget);
      expect(find.text('Saldo Tersedia'), findsOneWidget);
      expect(find.text('Dana tertahan'), findsOneWidget);
      expect(find.text('Total saldo'), findsOneWidget);
      expect(find.text('Riwayat'), findsNothing);
      expect(find.text('Tujuan Pencairan'), findsNothing);
      expect(find.text('Notifikasi'), findsNothing);
      expect(find.byTooltip('Notifikasi'), findsOneWidget);
      expect(find.text('Riwayat Transaksi'), findsOneWidget);
      expect(find.text('Lihat Semua'), findsOneWidget);
      expect(find.text('Belum ada transaksi dompet'), findsOneWidget);

      // Sandbox badge hidden; Tarik Saldo remains visible
      expect(find.text('SANDBOX (SIMULASI)'), findsNothing);
      expect(find.textContaining('SANDBOX'), findsNothing);
      expect(find.text('Tarik Saldo'), findsOneWidget);

      // Tap Tarik Saldo -> opens CourierWithdrawalV1Screen directly
      await tester.tap(find.text('Tarik Saldo'));
      await tester.pumpAndSettle();

      expect(find.text('Ajukan Penarikan'), findsOneWidget);
      expect(find.text('Kelola Rekening'), findsNothing);
      expect(find.text('Pilih Tujuan Penarikan'), findsOneWidget);
      expect(find.text('Rekening Bank'), findsWidgets);
      expect(find.text('E-Wallet'), findsOneWidget);
      expect(find.text('Masukkan Informasi Tujuan'), findsOneWidget);
      expect(find.text('Konfirmasi Penarikan'), findsOneWidget);
      expect(find.text('SANDBOX (SIMULASI)'), findsNothing);
      expect(find.textContaining('Bank BCA'), findsWidgets);

      // Pastikan mode input tujuan baru selaras dengan tampilan customer
      await tester.tap(find.text('+ Tujuan Baru'));
      await tester.pumpAndSettle();
      expect(find.text('Pilih Bank'), findsOneWidget);

      await tester.tap(find.text('E-Wallet'));
      await tester.pumpAndSettle();
      expect(find.text('Pilih E-Wallet'), findsOneWidget);

      // Kembali ke Rekening Bank tersimpan dan ajukan penarikan 50000
      await tester.tap(find.text('Rekening Bank').first);
      await tester.pumpAndSettle();
      expect(find.text('Masukkan Informasi Tujuan'), findsOneWidget);

      // Scroll ke input nominal lalu isi 50000 dan ajukan penarikan
      await tester.ensureVisible(find.byType(TextField));
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
    'CourierWithdrawalV1Screen mendukung pengisian tujuan Bank & E-Wallet baru langsung inline tanpa halaman Tujuan Pencairan terpisah',
    (tester) async {
      final v1Service = buildMockV1Service();

      await tester.pumpWidget(
        MaterialApp(
          home: CourierWithdrawalV1Screen(service: v1Service),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Kelola Rekening'), findsNothing);
      expect(find.text('Tujuan Pencairan'), findsNothing);
      expect(find.text('+ Tujuan Baru'), findsOneWidget);

      // Tambah & pakai tujuan E-Wallet baru langsung inline saat Tarik Saldo
      await tester.tap(find.text('E-Wallet'));
      await tester.pumpAndSettle();
      expect(find.text('Pilih E-Wallet'), findsOneWidget);

      final inputs = find.byType(TextField);
      // Input 0: Nomor Telepon E-Wallet, Input 1: Nominal Penarikan
      await tester.enterText(inputs.at(0), '081234567890');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), 'Budi OVO');
      await tester.enterText(find.byType(TextField).last, '40000');
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
    'RiwayatTransaksiScreen menampilkan penarikan v1 saat menekan filter Penarikan meski history legacy kosong dan mencegah duplikasi',
    (tester) async {
      final createdIso = DateTime.now().toUtc().toIso8601String();
      final v1Service = buildMockV1Service(
        initialPayouts: [
          {
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
            'amount': 50000,
            'fee': 0,
            'net_amount': 50000,
            'status': 'completed',
            'status_history': [],
            'created_at': createdIso,
            'completed_at': createdIso,
          },
        ],
      );

      final earningItem = WalletHistoryItem(
        id: 'tx-10',
        kind: 'earning',
        title: 'Pengantaran #10',
        amount: 75000,
        status: 'success',
        statusLabel: 'Berhasil',
        orderId: 10,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: RiwayatTransaksiScreen(
            v1Service: v1Service,
            historyFetcher: ({int page = 1, String? filter, String? status}) async {
              if (filter == 'withdrawal') {
                // Simulasi backend legacy yang belum mengembalikan payout v1
                return {'success': true, 'items': <WalletHistoryItem>[], 'hasMore': false};
              }
              return {
                'success': true,
                'items': [earningItem],
                'hasMore': false,
              };
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tab Semua menampilkan earning + penarikan v1
      expect(find.text('Pengantaran #10'), findsOneWidget);
      expect(find.text('Penarikan ke Bank BCA'), findsOneWidget);

      // Tekan filter Penarikan -> penarikan v1 tetap tampil (tidak kosong)
      await tester.tap(find.widgetWithText(ChoiceChip, 'Penarikan'));
      await tester.pumpAndSettle();
      expect(find.text('Penarikan ke Bank BCA'), findsOneWidget);
      expect(find.text('Pengantaran #10'), findsNothing);
      expect(find.text('Belum ada transaksi'), findsNothing);
      expect(find.text('1 transaksi dimuat'), findsOneWidget);

      // Tekan filter Pendapatan -> hanya pendapatan tampil
      await tester.tap(find.widgetWithText(ChoiceChip, 'Pendapatan'));
      await tester.pumpAndSettle();
      expect(find.text('Pengantaran #10'), findsOneWidget);
      expect(find.text('Penarikan ke Bank BCA'), findsNothing);

      // Uji deduplikasi jika backend sudah mengembalikan payout v1 di /history
      final duplicateCheck = WalletService.mergeHistoryWithPayouts(
        historyItems: [
          WalletHistoryItem(
            id: 'po-99',
            kind: 'withdrawal',
            title: 'Penarikan ke Bank BCA',
            amount: -50000,
            status: 'success',
            statusLabel: 'Berhasil',
            reference: 'WD-CUR-SANDBOX-99',
            payoutId: 99,
            createdAt: DateTime.now(),
          ),
        ],
        payouts: (await v1Service.getPayouts()).items,
        filter: 'withdrawal',
      );
      expect(duplicateCheck.length, 1);
    },
  );

  testWidgets(
    'DompetScreen menampilkan kartu saldo putih, toggle sembunyikan saldo, dan baris ringkas Riwayat Transaksi',
    (tester) async {
      final v1Service = buildMockV1Service();

      await tester.pumpWidget(
        MaterialApp(
          home: DompetScreen(
            v1Service: v1Service,
            walletFetcher: () async => {
              'success': true,
              'data': {
                'available_balance': 8440,
                'pending_balance': 20000,
              },
            },
            historyFetcher: () async => {
              'success': true,
              'items': [
                WalletHistoryItem(
                  id: 'tx-51',
                  kind: 'earning',
                  title: 'Pendapatan order #51 siap dicairkan',
                  amount: 14220,
                  status: 'success',
                  statusLabel: 'Berhasil',
                  orderId: 51,
                  createdAt: DateTime(2026, 11, 27, 10, 7),
                ),
              ],
            },
            notificationsFetcher: () async => {
              'success': true,
              'items': <WalletNotificationItem>[],
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dompet Saya'), findsOneWidget);
      expect(find.text('Saldo Tersedia'), findsOneWidget);
      expect(find.text('Riwayat Transaksi'), findsOneWidget);
      expect(find.text('Lihat Semua'), findsOneWidget);
      expect(find.text('Pendapatan order #51 siap dicairkan'), findsOneWidget);
      expect(find.text('27 Nov 2026, 10:07'), findsOneWidget);
      expect(find.text('+Rp 14.220'), findsOneWidget);

      // Toggle sembunyikan saldo
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Rp ••••••'), findsNWidgets(3));
    },
  );

  testWidgets(
    'TransactionDetailScreen menampilkan struk Bukti Transaksi bergerigi, rincian transaksi, Informasi, serta tombol Bagikan dan Selesai',
    (tester) async {
      final item = WalletHistoryItem(
        id: 'tx-51',
        kind: 'earning',
        title: 'Pendapatan order #51 siap dicairkan',
        amount: 14220,
        status: 'success',
        statusLabel: 'Berhasil',
        reference: 'ERN-ORD-51-2838-AVAIL',
        orderId: 51,
        createdAt: DateTime(2026, 11, 27, 10, 7),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: TransactionDetailScreen(item: item),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Detail Transaksi'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Bukti Transaksi'), findsOneWidget);
      expect(find.text('Pendapatan Pengiriman'), findsOneWidget);
      expect(find.text('Transaksi Berhasil'), findsOneWidget);
      expect(find.text('Pendapatan Order #51'), findsOneWidget);
      expect(find.text('Rp 14.220'), findsNWidgets(2));
      expect(find.text('Rincian Transaksi'), findsOneWidget);
      expect(find.text('Pendapatan pengiriman'), findsOneWidget);
      expect(find.text('ERN-ORD-51-2838-AVAIL'), findsOneWidget);
      expect(find.text('27 Nov 2026, 10:07 WIB'), findsNWidgets(2));
      expect(find.text('Informasi'), findsOneWidget);
      expect(
        find.text('Pendapatan dari penyelesaian order #51.'),
        findsOneWidget,
      );
      expect(find.text('Bagikan'), findsOneWidget);
      expect(find.text('Selesai'), findsOneWidget);

      await tester.tap(find.text('Bagikan'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        find.text('Rincian transaksi disalin, siap dibagikan.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'TransactionDetailScreen tombol Perbarui Status menyinkronkan penarikan processing v1 menjadi berhasil',
    (tester) async {
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/v1/courier/wallet/payouts/42') &&
            request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'id': 42,
                'reference': 'WD-CUR-8-20261127102137-EAEA',
                'owner_type': 'courier',
                'payout_type': 'courier_manual_withdrawal',
                'provider': 'xendit',
                'mode': 'sandbox',
                'is_simulated': false,
                'channel_code': 'ID_DANA',
                'account_number_masked': '******7890',
                'account_holder_name': 'Kurir Xendit',
                'amount': 20000,
                'fee': 0,
                'net_amount': 20000,
                'status': 'completed',
                'provider_reference': 'disb-eaea-001',
                'status_history': const [],
                'created_at': '2026-11-27T03:21:37Z',
                'completed_at': '2026-11-27T03:24:00Z',
              },
            }),
            200,
          );
        }
        return http.Response('{"success":false}', 404);
      });

      final v1Service = CourierWalletV1Service(
        client: client,
        baseUrl: 'https://example.test/api',
        tokenReader: () async => 'test-token',
      );

      final item = WalletHistoryItem(
        id: 'po-42',
        kind: 'withdrawal',
        title: 'Penarikan ke DANA',
        amount: -20000,
        status: 'processing',
        statusLabel: 'Diproses',
        reference: 'WD-CUR-8-20261127102137-EAEA',
        destination: '******7890',
        accountName: 'Kurir Xendit',
        provider: 'DANA',
        payoutId: 42,
        createdAt: DateTime(2026, 11, 27, 10, 21),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: TransactionDetailScreen(
            item: item,
            v1Service: v1Service,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Transaksi Diproses'), findsOneWidget);
      final syncFinder = find.text('Perbarui Status dari DANA');
      expect(syncFinder, findsOneWidget);

      await tester.ensureVisible(syncFinder);
      await tester.pumpAndSettle();
      await tester.tap(syncFinder);
      await tester.pumpAndSettle();

      expect(find.text('Transaksi Berhasil'), findsOneWidget);
      expect(find.text('Status terbaru: Berhasil'), findsOneWidget);
      expect(find.text('Perbarui Status dari DANA'), findsNothing);
    },
  );
}
