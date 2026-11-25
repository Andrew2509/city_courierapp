import 'package:city_courierapp/models/wallet/wallet_models.dart';
import 'package:city_courierapp/screens/courier/ci_word/profile/driver_profile_screen.dart';
import 'package:city_courierapp/screens/widgets/landing/landing_widgets.dart';
import 'package:city_courierapp/screens/widgets/landing/welcome_view.dart';
import 'package:city_courierapp/screens/widgets/profile/clear_cache_dialog.dart';
import 'package:city_courierapp/screens/widgets/profile/profile_header.dart';
import 'package:city_courierapp/screens/widgets/profile/profile_invite_banner.dart';
import 'package:city_courierapp/screens/widgets/profile/profile_logout_button.dart';
import 'package:city_courierapp/screens/widgets/profile/profile_navigation_grid.dart';
import 'package:city_courierapp/screens/widgets/profile/profile_settings_list.dart';
import 'package:city_courierapp/screens/widgets/profile/profile_stats_grid.dart';
import 'package:city_courierapp/screens/widgets/profile/profile_wallet_card.dart';
import 'package:city_courierapp/services/storage/app_cache_service.dart';
import 'package:city_courierapp/widgets/common/city_courier_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Seluruh komponen Profile memakai CityCourierCustomIcon tanpa Material Icon',
      (tester) async {
    final wallet = CustomerWalletSummary.fromJson({
      'wallet_id': 10,
      'wallet_type': 'customer',
      'currency': 'IDR',
      'status': 'active',
      'is_frozen': false,
      'available_balance': 150000,
      'reserved_balance': 0,
      'total_credited': 150000,
      'total_debited': 0,
      'topup_min_idr': 10000,
      'topup_max_idr': 10000000,
      'topup_provider_enabled': true,
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                const ProfileHeader(
                  primaryColor: Color(0xFFEC5B13),
                  userData: {'name': 'Budi', 'phone': '+628123456789'},
                ),
                ProfileWalletCard(
                  primaryColor: const Color(0xFFEC5B13),
                  surfaceColor: Colors.white,
                  borderColor: const Color(0xFFE5E7EB),
                  wallet: wallet,
                ),
                const ProfileStatsGrid(
                  primaryColor: Color(0xFFEC5B13),
                  surfaceColor: Colors.white,
                  borderColor: Color(0xFFE5E7EB),
                  isDarkMode: false,
                ),
                const ProfileNavigationGrid(
                  primaryColor: Color(0xFFEC5B13),
                  surfaceColor: Colors.white,
                  borderColor: Color(0xFFE5E7EB),
                ),
                const ProfileSettingsList(
                  surfaceColor: Colors.white,
                  borderColor: Color(0xFFE5E7EB),
                  cacheSizeLabel: '12 MB',
                ),
                const ProfileInviteBanner(primaryColor: Color(0xFFEC5B13)),
                const ProfileLogoutButton(surfaceColor: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(Icon), findsNothing);
    expect(find.byType(CityCourierCustomIcon), findsWidgets);

    // Label pada box Lacak Pesanan harus berada di luar kotak ikon (seperti Beranda).
    for (final statusLabel in const [
      'Belum Bayar',
      'Dikonfirmasi',
      'Diambil',
      'Perjalanan',
      'Terkirim',
      'Batal',
    ]) {
      final boxFinder = find.byKey(ValueKey('stat_icon_box_$statusLabel'));
      expect(boxFinder, findsOneWidget);
      expect(find.text(statusLabel), findsOneWidget);
      expect(
        find.descendant(of: boxFinder, matching: find.text(statusLabel)),
        findsNothing,
      );
    }

    final cacheService = AppCacheService(directoriesProvider: () async => []);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClearCacheDialog(
            cacheService: cacheService,
            cacheSizeLabel: '12 MB',
          ),
        ),
      ),
    );
    expect(find.byType(Icon), findsNothing);
    expect(find.byType(CityCourierCustomIcon), findsNWidgets(2));
  });

  testWidgets('DriverProfileScreen memakai CityCourierCustomIcon tanpa Material Icon',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DriverProfileScreen(
          initialProfileData: {
            'user': {
              'name': 'Kurir Jaya',
              'phone': '081234567890',
              'email': 'kurir@example.com',
            },
            'courier_details': {
              'city': '',
              'address': '',
              'vehicle_brand': '',
              'vehicle_model': '',
            },
            'stats': {'rating': '4.9', 'total_ratings': '10'},
          },
        ),
      ),
    );
    await tester.pump();

    expect(
      find.descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.byType(Icon),
      ),
      findsNothing,
    );
    expect(find.byType(CityCourierCustomIcon), findsWidgets);
  });

  testWidgets('Semua CourierIconKind dapat dirender bersih pada mode terang dan gelap',
      (tester) async {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: Scaffold(
            body: Wrap(
              children: [
                for (final kind in CourierIconKind.values)
                  CityCourierCustomIcon(kind, size: 24),
              ],
            ),
          ),
        ),
      );
      expect(
        find.byType(CityCourierCustomIcon),
        findsNWidgets(CourierIconKind.values.length),
      );
    }
  });

  testWidgets('3 ikon aksi pada halaman login (WelcomeView) memakai CityCourierCustomIcon bergaya Beranda',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: WelcomeView(onPhoneLoginTap: () {}),
          ),
        ),
      ),
    );

    expect(find.byType(LandingActionBox), findsNWidgets(3));
    expect(find.byIcon(Icons.search_rounded), findsNothing);
    expect(find.byIcon(Icons.calculate_rounded), findsNothing);
    expect(find.byIcon(Icons.headset_mic_rounded), findsNothing);
    expect(
      find.descendant(
        of: find.byType(LandingActionBox),
        matching: find.byType(CityCourierCustomIcon),
      ),
      findsNWidgets(3),
    );
    expect(find.text('Lacak'), findsOneWidget);
    expect(find.text('Tarif'), findsOneWidget);
    expect(find.text('Bantuan'), findsOneWidget);
  });
}
