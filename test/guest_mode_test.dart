import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:city_courierapp/core/utils/auth_guard.dart';
import 'package:city_courierapp/services/token_store.dart';
import 'package:city_courierapp/screens/widgets/home/bottom_nav_bar.dart';
import 'package:city_courierapp/screens/widgets/home/pickup_dropoff.dart';
import 'package:city_courierapp/screens/widgets/home/other_features_section.dart';
import 'package:city_courierapp/screens/home/cek_ongkir/cek_ongkir_screen.dart';
import 'package:city_courierapp/screens/home/drop_point/drop_point_screen.dart';
import 'package:city_courierapp/screens/home_screen.dart';
import 'package:city_courierapp/screens/widgets/home/home_header.dart';
import 'package:city_courierapp/screens/widgets/profile/profile_logout_button.dart';
import 'package:city_courierapp/screens/courier/ci_word/profile/driver_profile_screen.dart';
import 'package:city_courierapp/screens/profile/profile_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await TokenStore.clear();
  });

  group('TokenStore & AuthGuard authentication checks', () {
    test('TokenStore.isLoggedIn returns false initially (Guest Mode)', () async {
      expect(await TokenStore.isLoggedIn(), isFalse);
      expect(await AuthGuard.isAuthenticated(), isFalse);
    });

    test('TokenStore.isLoggedIn returns true after token is saved', () async {
      await TokenStore.save('valid_test_token');
      expect(await TokenStore.isLoggedIn(), isTrue);
      expect(await AuthGuard.isAuthenticated(), isTrue);
    });

    test('TokenStore.clear resets state to false (Guest Mode)', () async {
      await TokenStore.save('valid_test_token');
      expect(await TokenStore.isLoggedIn(), isTrue);

      await TokenStore.clear();
      expect(await TokenStore.isLoggedIn(), isFalse);
      expect(await AuthGuard.isAuthenticated(), isFalse);
    });
  });

  group('AuthGuard dialog tests', () {
    testWidgets('Dialog displays title, message, and Batal / OK buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => AuthGuard.showLoginRequiredDialog(context),
                child: const Text('Buka Dialog'),
              ),
            ),
          ),
        ),
      );

      // Tap to trigger dialog
      await tester.tap(find.text('Buka Dialog'));
      await tester.pumpAndSettle();

      // Check Dialog contents
      expect(find.text('Login Diperlukan'), findsOneWidget);
      expect(
        find.text('Silakan masuk terlebih dahulu untuk menggunakan fitur ini.'),
        findsOneWidget,
      );
      expect(find.text('Batal'), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);

      // Tap Batal
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();

      // Dialog should be dismissed
      expect(find.text('Login Diperlukan'), findsNothing);
      expect(find.text('Buka Dialog'), findsOneWidget);
    });

    testWidgets('AuthGuard.runWithAuth triggers onAuthenticated when logged in', (tester) async {
      await TokenStore.save('auth_token_123');

      bool actionExecuted = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  AuthGuard.runWithAuth(
                    context,
                    onAuthenticated: () {
                      actionExecuted = true;
                    },
                  );
                },
                child: const Text('Aksi Proteksi'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Aksi Proteksi'));
      await tester.pumpAndSettle();

      expect(actionExecuted, isTrue);
      expect(find.text('Login Diperlukan'), findsNothing);
    });

    testWidgets('AuthGuard.runWithAuth shows dialog when guest', (tester) async {
      await TokenStore.clear();

      bool actionExecuted = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  AuthGuard.runWithAuth(
                    context,
                    onAuthenticated: () {
                      actionExecuted = true;
                    },
                  );
                },
                child: const Text('Aksi Proteksi'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Aksi Proteksi'));
      await tester.pumpAndSettle();

      expect(actionExecuted, isFalse);
      expect(find.text('Login Diperlukan'), findsOneWidget);
    });
  });

  group('Guest Mode Widget Restrictions', () {
    testWidgets('BottomNavBar: tapping Riwayat as guest triggers Login Diperlukan dialog', (tester) async {
      await TokenStore.clear();

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                BottomNavBar(activeIndex: 0),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.text('Riwayat'));
      await tester.pumpAndSettle();

      expect(find.text('Login Diperlukan'), findsOneWidget);
    });

    testWidgets('BottomNavBar: tapping Profile as guest triggers Login Diperlukan dialog', (tester) async {
      await TokenStore.clear();

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                BottomNavBar(activeIndex: 0),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      expect(find.text('Login Diperlukan'), findsOneWidget);
    });

    testWidgets('PickupDropoff: tapping Pickup as guest triggers Login Diperlukan dialog', (tester) async {
      await TokenStore.clear();

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PickupDropoff(),
          ),
        ),
      );

      await tester.tap(find.text('Pickup'));
      await tester.pumpAndSettle();

      expect(find.text('Login Diperlukan'), findsOneWidget);
    });

    testWidgets('PickupDropoff: tapping Dropoff as guest triggers Login Diperlukan dialog', (tester) async {
      await TokenStore.clear();

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PickupDropoff(),
          ),
        ),
      );

      await tester.tap(find.text('Dropoff'));
      await tester.pumpAndSettle();

      expect(find.text('Login Diperlukan'), findsOneWidget);
    });

    testWidgets('OtherFeaturesSection: tapping Cek Ongkir is accessible as guest', (tester) async {
      await TokenStore.clear();

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OtherFeaturesSection(),
          ),
        ),
      );

      await tester.tap(find.text('Cek Ongkir'));
      await tester.pumpAndSettle();

      // Should NOT show login dialog
      expect(find.text('Login Diperlukan'), findsNothing);
      // Should navigate to Cek Ongkir screen
      expect(find.byType(CekOngkirScreen), findsOneWidget);
    });

    testWidgets('OtherFeaturesSection: tapping Drop Point is accessible as guest', (tester) async {
      await TokenStore.clear();

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OtherFeaturesSection(),
          ),
        ),
      );

      await tester.tap(find.text('Drop Point'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Should NOT show login dialog
      expect(find.text('Login Diperlukan'), findsNothing);
      // Should navigate to Drop Point screen
      expect(find.byType(DropPointScreen), findsOneWidget);
    });

    testWidgets('HomeHeader: does not display "Selamat Datang" or greeting when in guest mode (userData == null)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HomeHeader(userData: null),
          ),
        ),
      );

      expect(find.text('Selamat Datang'), findsNothing);
      expect(find.text('di City Courier'), findsNothing);
      expect(find.text('Tamu'), findsNothing);
    });

    testWidgets('HomeHeader: displays "Selamat Datang" and user name when authenticated', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HomeHeader(userData: {'name': 'Budi Santoso'}),
          ),
        ),
      );

      expect(find.text('Selamat Datang'), findsOneWidget);
      expect(find.text('Budi Santoso'), findsOneWidget);
    });
  });

  group('Logout Confirmation Dialog & Flow tests', () {
    testWidgets('1. Menekan tombol Keluar di Profile menampilkan dialog konfirmasi', (tester) async {
      await TokenStore.save('valid_session_token');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProfileLogoutButton(surfaceColor: Colors.white),
          ),
        ),
      );

      // Pastikan tombol Keluar ada dan ditekan
      final logoutBtnFinder = find.widgetWithText(OutlinedButton, 'Keluar');
      expect(logoutBtnFinder, findsOneWidget);
      await tester.tap(logoutBtnFinder);
      await tester.pumpAndSettle();

      // Dialog harus muncul dengan judul, pesan, dan tombol sesuai ketentuan
      expect(find.text('Keluar dari Akun?'), findsOneWidget);
      expect(
        find.text('Apakah kamu yakin ingin keluar dari akun ini?'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextButton, 'Batal'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Keluar'), findsOneWidget);
    });

    testWidgets('2. Menekan Batal menutup dialog tanpa mengeluarkan pengguna dari akun', (tester) async {
      await TokenStore.save('active_session_token');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProfileLogoutButton(surfaceColor: Colors.white),
          ),
        ),
      );

      // Buka dialog konfirmasi
      await tester.tap(find.widgetWithText(OutlinedButton, 'Keluar'));
      await tester.pumpAndSettle();

      expect(find.text('Keluar dari Akun?'), findsOneWidget);

      // Tekan tombol Batal
      await tester.tap(find.widgetWithText(TextButton, 'Batal'));
      await tester.pumpAndSettle();

      // Dialog tertutup
      expect(find.text('Keluar dari Akun?'), findsNothing);

      // Pengguna tetap dalam kondisi login (token tidak terhapus)
      expect(await TokenStore.isLoggedIn(), isTrue);
      expect(await AuthGuard.isAuthenticated(), isTrue);
    });

    testWidgets('3 & 4. Menekan Keluar menjalankan proses logout, mengosongkan sesi, dan mengarahkan ke HomeScreen (Guest Mode)', (tester) async {
      await TokenStore.save('token_to_be_cleared');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProfileLogoutButton(surfaceColor: Colors.white),
          ),
        ),
      );

      // Buka dialog konfirmasi
      await tester.tap(find.widgetWithText(OutlinedButton, 'Keluar'));
      await tester.pumpAndSettle();

      expect(find.text('Keluar dari Akun?'), findsOneWidget);

      // Tekan tombol Keluar di dialog
      await tester.tap(find.widgetWithText(ElevatedButton, 'Keluar'));
      await tester.pumpAndSettle();

      // Sesi/token harus terhapus
      expect(await TokenStore.isLoggedIn(), isFalse);
      expect(await AuthGuard.isAuthenticated(), isFalse);

      // Pengguna diarahkan ke HomeScreen
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('5. Setelah logout, fitur yang membutuhkan login tidak dapat diakses tanpa login', (tester) async {
      await TokenStore.clear();

      bool actionExecuted = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  AuthGuard.runWithAuth(
                    context,
                    onAuthenticated: () {
                      actionExecuted = true;
                    },
                  );
                },
                child: const Text('Akses Fitur Terproteksi'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Akses Fitur Terproteksi'));
      await tester.pumpAndSettle();

      // Fitur terproteksi tidak boleh dijalankan
      expect(actionExecuted, isFalse);
      // Dialog Login Diperlukan harus muncul
      expect(find.text('Login Diperlukan'), findsOneWidget);
    });
  });

  group('Driver Profile Mode Switch tests', () {
    testWidgets('DriverProfileScreen menampilkan tombol Akun Personal dan Akun Kurir', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DriverProfileScreen(
            initialProfileData: {
              'user': {'name': 'Driver Andrew'},
              'stats': {'rating': '4.8', 'total_ratings': 7},
            },
          ),
        ),
      );

      // Biarkan frame awal ter-render
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Harus ada tombol Akun Personal dan Akun Kurir seperti di profil personal
      expect(find.text('Akun Personal'), findsOneWidget);
      expect(find.text('Akun Kurir'), findsOneWidget);
    });

    testWidgets('DriverProfileScreen menekan Akun Personal berpindah kembali ke ProfileScreen', (tester) async {
      await TokenStore.save('valid_driver_session');

      await tester.pumpWidget(
        MaterialApp(
          home: const ProfileScreen(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Push DriverProfileScreen
      final context = tester.element(find.byType(ProfileScreen));
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const DriverProfileScreen(
            fromPersonalProfile: true,
            initialProfileData: {
              'user': {'name': 'Driver Andrew'},
              'stats': {'rating': '4.8', 'total_ratings': 7},
            },
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(DriverProfileScreen), findsOneWidget);

      // Tekan tombol Akun Personal di profil kurir
      final personalBtnInDriver = find.descendant(
        of: find.byType(DriverProfileScreen),
        matching: find.text('Akun Personal'),
      );
      expect(personalBtnInDriver, findsOneWidget);
      await tester.tap(personalBtnInDriver);
      await tester.pumpAndSettle();

      // Harus kembali ke ProfileScreen
      expect(find.byType(ProfileScreen), findsOneWidget);
    });
  });
}

