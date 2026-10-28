import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:city_courierapp/screens/home_screen.dart';
import 'package:city_courierapp/screens/widgets/home/theme_toggle_fab.dart';
import 'package:city_courierapp/services/courier/courier_status_service.dart';
import 'package:city_courierapp/services/deep_link_service.dart';
import 'package:city_courierapp/services/token_store.dart';
import 'package:city_courierapp/screens/courier/ci_word/wallet/dompet_screen.dart';
import 'package:city_courierapp/screens/profile/daftar_kurir/daftar_kurir_data.dart';

/// Global route observer – screens can subscribe to detect when they become
/// visible again (e.g. after Navigator.pop from a child screen).
final RouteObserver<ModalRoute> routeObserver = RouteObserver<ModalRoute>();

/// Global navigator key – dipakai router global (cold-start deep link).
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Siapkan deep link sebelum runApp agar cold-start tidak terlewat (PRD §32).
  await DeepLinkService.instance.init();
  final initialLink = await DeepLinkService.instance.getInitialLink();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CourierStatusService()),
        ChangeNotifierProvider(create: (_) => DaftarKurirData()),
      ],
      child: const MyApp(),
    ),
  );

  if (initialLink != null) {
    _openColdStartDanaLink(initialLink);
  }
}

/// Cold start dari deep link citycourier://dana/binding/{success,failed}
/// → arahkan langsung ke dompet kurir agar status koneksi terlihat.
Future<void> _openColdStartDanaLink(Uri uri) async {
  if (!DeepLinkService.instance.isDanaSuccess(uri) &&
      !DeepLinkService.instance.isDanaFailed(uri)) {
    return;
  }

  // Butuh sesi login. Jika belum login, biarkan landing screen menangani.
  final token = await TokenStore.read();
  if (token == null) return;

  await WidgetsBinding.instance.endOfFrame;

  final navigator = navigatorKey.currentState;
  if (navigator == null) return;

  navigator.pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const DompetScreen()),
    (route) => route.isFirst,
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, child) {
        return MaterialApp(
          title: 'City Courier',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFEC5B13),
              brightness: Brightness.light,
            ),
            scaffoldBackgroundColor: const Color(0xFFF9FAFB),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.dark(
              primary: const Color(0xFFEC5B13),
              secondary: const Color(0xFFFF8A00),
              surface: const Color(0xFF1E293B),
            ),
            scaffoldBackgroundColor: const Color(0xFF0F172A),
          ),
          navigatorObservers: [routeObserver],
          navigatorKey: navigatorKey,
          home: const HomeScreen(),
        );
      },
    );
  }
}
