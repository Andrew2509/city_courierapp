import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:city_courierapp/models/wallet/wallet_models.dart';
import 'package:city_courierapp/screens/profile/profile_screen.dart';
import 'package:city_courierapp/screens/widgets/profile/clear_cache_dialog.dart';
import 'package:city_courierapp/screens/widgets/profile/profile_settings_list.dart';
import 'package:city_courierapp/services/provider_availability_service.dart';
import 'package:city_courierapp/services/storage/app_cache_service.dart';
import 'package:city_courierapp/services/token_store.dart';
import 'package:city_courierapp/services/wallet/customer_wallet_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeImageCache extends ImageCache {
  int _fakeBytes;
  bool cleared = false;
  bool clearedLive = false;

  _FakeImageCache(this._fakeBytes);

  @override
  int get currentSizeBytes => _fakeBytes;

  @override
  void clear() {
    cleared = true;
    _fakeBytes = 0;
    super.clear();
  }

  @override
  void clearLiveImages() {
    clearedLive = true;
    super.clearLiveImages();
  }
}

class _FakeWalletService extends CustomerWalletService {
  final int availableBalance;
  final List<WalletTransactionV1> history;

  _FakeWalletService({
    this.availableBalance = 250000,
    List<WalletTransactionV1>? history,
  })  : history = history ??
            [
              WalletTransactionV1(
                id: 1,
                type: 'topup',
                direction: 'credit',
                amount: 250000,
                signedAmount: 250000,
                balanceAfter: 250000,
                status: 'settled',
                referenceId: 'TU-001',
                description: 'Top-Up QRIS',
                mode: 'sandbox',
                metadata: const {},
                createdAt: DateTime(2026, 11, 20),
              ),
            ],
        super(
          client: MockClient((_) async => http.Response('{}', 200)),
          baseUrl: 'http://127.0.0.1',
        );

  @override
  Future<CustomerWalletSummary> getWallet() async {
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
      activePaymentProvider: 'mock',
      withdrawalEnabled: true,
      withdrawalMinIdr: 10000,
      withdrawalMaxIdr: 5000000,
      topupMinIdr: 10000,
      topupMaxIdr: 10000000,
    );
  }

  @override
  Future<({List<WalletTransactionV1> items, int currentPage, int lastPage})>
      getTransactions({
    int page = 1,
    int perPage = 15,
    String type = 'all',
    String status = 'all',
  }) async {
    return (items: history, currentPage: 1, lastPage: 1);
  }
}

void main() {
  late Directory sandboxRoot;
  late Directory cacheDir;
  late Directory docsDir;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({
      'active_order_cache': jsonEncode({'id': 99, 'status': 'delivering'}),
      'tracking_search_history': ['CC-123456'],
      'user_preferred_theme': 'light',
    });
    await TokenStore.save('session_token_rahasia_123');
    ProviderAvailabilityService.clearCache();

    sandboxRoot = Directory.systemTemp.createTempSync('cc_cache_test_');
    cacheDir = Directory('${sandboxRoot.path}${Platform.pathSeparator}cache')
      ..createSync(recursive: true);
    docsDir = Directory('${sandboxRoot.path}${Platform.pathSeparator}docs')
      ..createSync(recursive: true);
  });

  tearDown(() async {
    ProviderAvailabilityService.clearCache();
    if (sandboxRoot.existsSync()) {
      sandboxRoot.deleteSync(recursive: true);
    }
  });

  void populateTempFiles({int fileSizeBytes = 2048}) {
    final nestedDir = Directory(
      '${cacheDir.path}${Platform.pathSeparator}image_temp',
    )..createSync(recursive: true);
    File('${cacheDir.path}${Platform.pathSeparator}http_tmp.bin')
        .writeAsBytesSync(List<int>.filled(fileSizeBytes, 65));
    File('${nestedDir.path}${Platform.pathSeparator}preview.jpg')
        .writeAsBytesSync(List<int>.filled(fileSizeBytes, 66));
  }

  File createProtectedDocument() {
    final doc = File(
      '${docsDir.path}${Platform.pathSeparator}resi_penting_001.pdf',
    )..writeAsStringSync('DOKUMEN RESI PENTING');
    return doc;
  }

  Future<void> flushRealAsync(
    WidgetTester tester, {
    int hops = 8,
    bool settle = true,
  }) async {
    for (int i = 0; i < hops; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
    }
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  Future<void> pumpProfileWithCache(
    WidgetTester tester, {
    required AppCacheService cacheService,
    required _FakeWalletService walletService,
  }) async {
    tester.view.physicalSize = const Size(520, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(
          walletService: walletService,
          cacheService: cacheService,
        ),
      ),
    );
    await flushRealAsync(tester);
  }

  Future<void> scrollAndTapClearCacheMenu(WidgetTester tester) async {
    final menuFinder = find.text('Bersihkan Cache');
    await tester.scrollUntilVisible(
      menuFinder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    // Pastikan item tidak tertutup oleh overlay BottomNavBar di bagian bawah layar.
    if (tester.getRect(menuFinder).bottom > 1000) {
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -240),
      );
      await tester.pumpAndSettle();
    }
    await tester.tap(menuFinder);
    await flushRealAsync(tester);
  }

  group('AppCacheService unit tests', () {
    test('menghitung dan membersihkan cache tanpa menyentuh dokumen/token/prefs',
        () async {
      populateTempFiles(fileSizeBytes: 1536); // Total 3072 B = 3 KB
      final protectedDoc = createProtectedDocument();
      final imageCache = _FakeImageCache(1024); // + 1 KB => 4 KB total

      final service = AppCacheService(
        directoriesProvider: () async => [cacheDir],
        imageCacheProvider: () => imageCache,
      );

      final before = await service.inspectCache();
      expect(before.diskBytes, 3072);
      expect(before.imageCacheBytes, 1024);
      expect(before.totalBytes, 4096);
      expect(before.formattedSize, '4 KB');

      final result = await service.clearCache();
      expect(result.success, isTrue);
      expect(result.previousBytes, 4096);
      expect(result.freedBytes, 4096);
      expect(result.remainingBytes, 0);
      expect(result.formattedRemainingSize, '0 B');
      expect(cacheDir.existsSync(), isTrue);
      expect(cacheDir.listSync(), isEmpty);
      expect(imageCache.cleared, isTrue);
      expect(imageCache.clearedLive, isTrue);

      // Data penting wajib utuh.
      expect(protectedDoc.existsSync(), isTrue);
      expect(await TokenStore.isLoggedIn(), isTrue);
      expect(await TokenStore.read(), 'session_token_rahasia_123');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('active_order_cache'), isNotNull);
      expect(prefs.getStringList('tracking_search_history'), ['CC-123456']);
      expect(prefs.getString('user_preferred_theme'), 'light');
    });

    test('aman saat cache sudah kosong (0 B)', () async {
      final imageCache = _FakeImageCache(0);
      final service = AppCacheService(
        directoriesProvider: () async => [cacheDir],
        imageCacheProvider: () => imageCache,
      );

      final before = await service.inspectCache();
      expect(before.totalBytes, 0);
      expect(before.formattedSize, '0 B');

      final result = await service.clearCache();
      expect(result.success, isTrue);
      expect(result.freedBytes, 0);
      expect(result.remainingBytes, 0);
      expect(result.formattedRemainingSize, '0 B');
    });

    test('menangani kegagalan penghapusan file tanpa crash', () async {
      populateTempFiles(fileSizeBytes: 1024);
      final imageCache = _FakeImageCache(512);
      final service = AppCacheService(
        directoriesProvider: () async => [cacheDir],
        imageCacheProvider: () => imageCache,
        deleteEntity: (_) async =>
            throw const FileSystemException('Permission denied'),
      );

      final result = await service.clearCache();
      expect(result.success, isFalse);
      expect(result.errorMessage, isNotNull);
      expect(await TokenStore.isLoggedIn(), isTrue);
    });

    test('formatBytes memformat B, KB, MB, dan GB dengan benar', () {
      expect(AppCacheService.formatBytes(0), '0 B');
      expect(AppCacheService.formatBytes(512), '512 B');
      expect(AppCacheService.formatBytes(2048), '2 KB');
      expect(AppCacheService.formatBytes(25 * 1024 * 1024), '25 MB');
      expect(AppCacheService.formatBytes(1536 * 1024), '1.5 MB');
    });
  });

  group('Bersihkan Cache UI & Alur Profil', () {
    testWidgets(
      '1-2. Membuka dialog Bersihkan Cache dan Batal tidak mengubah file/ukuran cache',
      (tester) async {
        populateTempFiles(fileSizeBytes: 2048); // 4096 B = 4 KB
        final protectedDoc = createProtectedDocument();
        final imageCache = _FakeImageCache(0);
        final walletService = _FakeWalletService(availableBalance: 250000);
        final cacheService = AppCacheService(
          directoriesProvider: () async => [cacheDir],
          imageCacheProvider: () => imageCache,
        );

        await pumpProfileWithCache(
          tester,
          cacheService: cacheService,
          walletService: walletService,
        );

        expect(find.text('4 KB'), findsOneWidget);
        expect(find.text('Rp 250.000'), findsOneWidget);

        await scrollAndTapClearCacheMenu(tester);

        expect(find.text('Bersihkan Cache?'), findsOneWidget);
        expect(find.text('Cache aplikasi saat ini: 4 KB.'), findsOneWidget);
        expect(
          find.textContaining('file sementara dan cache aplikasi'),
          findsOneWidget,
        );
        expect(find.widgetWithText(TextButton, 'Batal'), findsOneWidget);
        expect(
          find.widgetWithText(ElevatedButton, 'Bersihkan Cache'),
          findsOneWidget,
        );

        await tester.tap(find.widgetWithText(TextButton, 'Batal'));
        await tester.pumpAndSettle();

        expect(find.text('Bersihkan Cache?'), findsNothing);
        expect(cacheDir.listSync(), hasLength(2));
        expect(imageCache.cleared, isFalse);
        expect(find.text('4 KB'), findsOneWidget);
        expect(protectedDoc.existsSync(), isTrue);
      },
    );

    testWidgets(
      '3-8. Konfirmasi tampilkan loading, cegah double-tap, bersihkan cache, jaga login/saldo/riwayat, & tetap stabil',
      (tester) async {
        populateTempFiles(fileSizeBytes: 5120); // 10240 B = 10 KB
        final protectedDoc = createProtectedDocument();
        final imageCache = _FakeImageCache(0);
        final walletService = _FakeWalletService(availableBalance: 250000);

        final completer = Completer<void>();
        int deleteCalls = 0;

        final cacheService = AppCacheService(
          directoriesProvider: () async => [cacheDir],
          imageCacheProvider: () => imageCache,
          deleteEntity: (entity) async {
            deleteCalls++;
            if (!completer.isCompleted) {
              await completer.future;
            }
            await entity.delete(recursive: true);
          },
        );

        await pumpProfileWithCache(
          tester,
          cacheService: cacheService,
          walletService: walletService,
        );

        expect(find.text('10 KB'), findsOneWidget);

        await scrollAndTapClearCacheMenu(tester);

        final confirmBtn =
            find.widgetWithText(ElevatedButton, 'Bersihkan Cache');
        expect(confirmBtn, findsOneWidget);

        // Tekan tombol bersihkan dua kali cepat -> harus hanya memicu sekali.
        await tester.tap(confirmBtn);
        await flushRealAsync(tester, hops: 4, settle: false);

        expect(find.text('Membersihkan...'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(ClearCacheDialog),
            matching: find.byType(CircularProgressIndicator),
          ),
          findsOneWidget,
        );

        // Tombol Batal & konfirmasi nonaktif saat loading.
        final busyBtn = tester.widget<ElevatedButton>(
          find.ancestor(
            of: find.text('Membersihkan...'),
            matching: find.byType(ElevatedButton),
          ),
        );
        expect(busyBtn.onPressed, isNull);

        await tester.tap(find.text('Membersihkan...'), warnIfMissed: false);
        await tester.pump();
        expect(deleteCalls, 1);

        // Selesaikan penghapusan async.
        completer.complete();
        await flushRealAsync(tester);

        expect(find.text('Bersihkan Cache?'), findsNothing);
        expect(
          find.text(
            'Cache berhasil dibersihkan. Penyimpanan sementara aplikasi telah diperbarui.',
          ),
          findsOneWidget,
        );
        expect(cacheDir.listSync(), isEmpty);
        expect(imageCache.cleared, isTrue);
        expect(find.text('0 B'), findsOneWidget);

        // 5. Pengguna tetap login.
        expect(await TokenStore.isLoggedIn(), isTrue);
        expect(await TokenStore.read(), 'session_token_rahasia_123');

        // 6 & 7. Saldo City Wallet & riwayat transaksi tetap utuh.
        expect(find.text('Rp 250.000'), findsOneWidget);
        final walletAfter = await walletService.getWallet();
        expect(walletAfter.availableBalance, 250000);
        final txAfter = await walletService.getTransactions();
        expect(txAfter.items, hasLength(1));
        expect(txAfter.items.first.referenceId, 'TU-001');
        expect(protectedDoc.existsSync(), isTrue);

        // 8. Halaman tetap normal bila dibuka lagi setelah dibersihkan.
        await scrollAndTapClearCacheMenu(tester);
        expect(find.text('Bersihkan Cache?'), findsOneWidget);
        expect(find.text('Cache aplikasi saat ini: 0 B.'), findsOneWidget);
        await tester.tap(find.widgetWithText(TextButton, 'Batal'));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      '9. Kondisi cache sudah kosong (0 B) tetap aman dibersihkan',
      (tester) async {
        final imageCache = _FakeImageCache(0);
        final walletService = _FakeWalletService(availableBalance: 250000);
        final cacheService = AppCacheService(
          directoriesProvider: () async => [cacheDir],
          imageCacheProvider: () => imageCache,
        );

        await pumpProfileWithCache(
          tester,
          cacheService: cacheService,
          walletService: walletService,
        );

        expect(find.text('0 B'), findsOneWidget);
        await scrollAndTapClearCacheMenu(tester);
        expect(find.text('Cache aplikasi saat ini: 0 B.'), findsOneWidget);

        await tester.tap(find.widgetWithText(ElevatedButton, 'Bersihkan Cache'));
        await flushRealAsync(tester);

        expect(
          find.text(
            'Cache berhasil dibersihkan. Penyimpanan sementara aplikasi telah diperbarui.',
          ),
          findsOneWidget,
        );
        expect(find.text('0 B'), findsOneWidget);
        expect(await TokenStore.isLoggedIn(), isTrue);
      },
    );

    testWidgets(
      '10. Menangani kegagalan pembersihan cache dengan aman tanpa logout',
      (tester) async {
        populateTempFiles(fileSizeBytes: 2048);
        final imageCache = _FakeImageCache(0);
        final walletService = _FakeWalletService(availableBalance: 250000);
        final cacheService = AppCacheService(
          directoriesProvider: () async => [cacheDir],
          imageCacheProvider: () => imageCache,
          deleteEntity: (_) async =>
              throw const FileSystemException('Access denied'),
        );

        await pumpProfileWithCache(
          tester,
          cacheService: cacheService,
          walletService: walletService,
        );

        await scrollAndTapClearCacheMenu(tester);
        await tester.tap(find.widgetWithText(ElevatedButton, 'Bersihkan Cache'));
        await flushRealAsync(tester);

        expect(find.text('Bersihkan Cache?'), findsNothing);
        expect(
          find.text('Proses pembersihan cache tidak selesai sepenuhnya.'),
          findsOneWidget,
        );
        expect(await TokenStore.isLoggedIn(), isTrue);
        expect(find.text('Rp 250.000'), findsOneWidget);
      },
    );

    testWidgets(
      'Desain dialog memenuhi standar sudut membulat & tombol #FF5A00',
      (tester) async {
        final imageCache = _FakeImageCache(0);
        final cacheService = AppCacheService(
          directoriesProvider: () async => [cacheDir],
          imageCacheProvider: () => imageCache,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => Center(
                  child: ProfileSettingsList(
                    surfaceColor: Colors.white,
                    borderColor: const Color(0xFFE5E7EB),
                    cacheSizeLabel: '25 MB',
                    onTapClearCache: () => ClearCacheDialog.show(
                      ctx,
                      cacheService: cacheService,
                      cacheSizeLabel: '25 MB',
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Bersihkan Cache'));
        await tester.pumpAndSettle();

        final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
        final shape = dialog.shape as RoundedRectangleBorder;
        expect(shape.borderRadius, BorderRadius.circular(20));

        final confirmButton = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Bersihkan Cache'),
        );
        expect(
          confirmButton.style?.backgroundColor?.resolve({}),
          const Color(0xFFFF5A00),
        );
      },
    );
  });
}
