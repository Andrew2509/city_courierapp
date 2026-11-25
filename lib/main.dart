import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:city_courierapp/screens/home_screen.dart';
import 'package:city_courierapp/services/chat/chat_notification_service.dart';
import 'package:city_courierapp/services/courier/courier_status_service.dart';
import 'package:city_courierapp/services/deep_link_service.dart';
import 'package:city_courierapp/services/token_store.dart';
import 'package:city_courierapp/screens/courier/ci_word/wallet/dompet_screen.dart';
import 'package:city_courierapp/screens/profile/daftar_kurir/daftar_kurir_data.dart';
import 'package:city_courierapp/providers/call_provider.dart';
import 'package:city_courierapp/providers/chat_provider.dart';

/// Global route observer â€“ screens can subscribe to detect when they become
/// visible again (e.g. after Navigator.pop from a child screen).
final RouteObserver<ModalRoute> routeObserver = RouteObserver<ModalRoute>();

/// Global navigator key â€“ dipakai router global (cold-start deep link).
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e, st) {
    debugPrint('[Main] Firebase.initializeApp warning: $e\n$st');
  }

  // Siapkan deep link sebelum runApp agar cold-start tidak terlewat (PRD Â§32).
  await DeepLinkService.instance.init();
  final initialLink = await DeepLinkService.instance.getInitialLink();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CourierStatusService()),
        ChangeNotifierProvider(create: (_) => DaftarKurirData()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProxyProvider<ChatProvider, CallProvider>(
          create: (ctx) => CallProvider(
            realtimeService: ctx.read<ChatProvider>().realtimeService,
            navigatorKey: navigatorKey,
          ),
          update: (_, chat, previous) =>
              previous ??
              CallProvider(
                realtimeService: chat.realtimeService,
                navigatorKey: navigatorKey,
              ),
        ),
      ],
      child: const MyApp(),
    ),
  );

  unawaited(ChatNotificationService.instance.init(navigatorKey: navigatorKey));

  if (initialLink != null) {
    _openColdStartWalletLink(initialLink);
  }
}

/// Cold start dari deep link citycourier://dana/binding/{success,failed}
/// â†’ arahkan langsung ke dompet kurir agar status koneksi terlihat.
Future<void> _openColdStartWalletLink(Uri uri) async {
  final isOvo = DeepLinkService.instance.isOvoSuccess(uri) || DeepLinkService.instance.isOvoFailed(uri);
  final isDana = DeepLinkService.instance.isDanaSuccess(uri) || DeepLinkService.instance.isDanaFailed(uri);
  if (!isOvo && !isDana) {
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

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  CallProvider? _tryReadCallProvider() {
    try {
      return context.read<CallProvider>();
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final callProvider = _tryReadCallProvider();
      if (callProvider != null) {
        ChatNotificationService.instance.attachCallPushHandler(callProvider.handleIncomingPushData);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      final callProvider = _tryReadCallProvider();
      if (callProvider != null) {
        unawaited(callProvider.checkIncomingCalls());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'City Courier',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFEC5B13),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF9FAFB),
      ),
      navigatorObservers: [routeObserver],
      navigatorKey: navigatorKey,
      home: const HomeScreen(),
    );
  }
}

