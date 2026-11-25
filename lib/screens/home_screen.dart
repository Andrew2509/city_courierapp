import 'dart:async';
import 'package:flutter/material.dart';
import 'package:city_courierapp/main.dart' show routeObserver;
import 'package:city_courierapp/screens/widgets/home/home_header.dart';
import 'package:city_courierapp/screens/widgets/home/search_bar_widget.dart';
import 'package:city_courierapp/screens/widgets/home/services_section.dart';
import 'package:city_courierapp/screens/widgets/home/pickup_dropoff.dart';
import 'package:city_courierapp/screens/widgets/home/courier_banner.dart';
import 'package:city_courierapp/screens/widgets/home/other_features_section.dart';
import 'package:city_courierapp/screens/widgets/home/bottom_nav_bar.dart';
import 'package:city_courierapp/screens/widgets/home/floating_active_order_widget.dart';
import 'package:city_courierapp/services/shipping/active_order_service.dart';
import 'package:city_courierapp/services/api_service.dart';
import 'package:city_courierapp/services/security/biometric_guard_service.dart';
import 'package:city_courierapp/services/token_store.dart';
import 'package:city_courierapp/screens/auth/complete_profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  Map<String, dynamic>? _userData;
  bool _biometricLocked = false;
  bool _unlockingBiometric = false;
  String? _biometricHint;

  @override
  void initState() {
    super.initState();
    ActiveOrderService.init();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkBiometricLockOnLaunch();
      _checkProfileCompletion();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    ActiveOrderService.init();
    _checkBiometricLockOnLaunch();
    _checkProfileCompletion();
  }

  Future<void> _checkBiometricLockOnLaunch() async {
    final loggedIn = await TokenStore.isLoggedIn();
    if (!loggedIn) {
      if (mounted && _biometricLocked) {
        setState(() {
          _biometricLocked = false;
          _biometricHint = null;
        });
      }
      return;
    }

    final localBio = await BiometricGuardService.isLocallyEnabled();
    if (localBio && !BiometricGuardService.isSessionUnlocked) {
      if (mounted && !_biometricLocked) {
        setState(() => _biometricLocked = true);
      }
      await _unlockAppWithBiometric();
    }
  }

  Future<void> _unlockAppWithBiometric() async {
    if (_unlockingBiometric || BiometricGuardService.isSessionUnlocked) return;
    _unlockingBiometric = true;
    try {
      final res = await BiometricGuardService.authenticate(
        reason: 'Verifikasi sidik jari atau wajah untuk masuk ke City Courier',
      );
      if (!mounted) return;
      setState(() {
        _biometricLocked = !res.authenticated;
        _biometricHint = res.authenticated ? null : res.message;
      });
    } finally {
      _unlockingBiometric = false;
    }
  }

  Future<void> _logoutFromBiometricLock() async {
    await ApiService.logout();
    if (!mounted) return;
    setState(() {
      _userData = null;
      _biometricLocked = false;
      _biometricHint = null;
    });
  }

  Future<void> _checkProfileCompletion() async {
    final profileData = await ApiService.getProfile();

    if (profileData != null && profileData['user'] is Map) {
      final user = Map<String, dynamic>.from(profileData['user'] as Map);
      user['phone_verified'] ??= profileData['phone_verified'] == true;

      final bool serverBiometric =
          user['biometric_enabled'] == true ||
          profileData['biometric_enabled'] == true;
      await BiometricGuardService.setLocalEnabled(
        serverBiometric,
        userId: (user['id'] as num?)?.toInt(),
      );

      final String name = (user['name'] ?? '').toString().trim();
      final String email = (user['email'] ?? '').toString().trim();
      final String phone = (user['phone'] ?? '').toString().trim();
      final bool phoneVerified =
          profileData['phone_verified'] == true ||
          user['phone_verified'] == true;

      final bool isIncomplete =
          profileData['requires_profile_completion'] == true ||
          profileData['profile_completed'] == false ||
          name.isEmpty ||
          name.startsWith('User ') ||
          name == 'Google User' ||
          email.isEmpty ||
          email.contains('@citycourier.local') ||
          phone.isEmpty ||
          !phoneVerified;

      if (mounted) {
        setState(() {
          _userData = user;
          if (!serverBiometric) {
            _biometricLocked = false;
            _biometricHint = null;
          } else if (!BiometricGuardService.isSessionUnlocked) {
            _biometricLocked = true;
          }
        });
      }

      if (serverBiometric &&
          !BiometricGuardService.isSessionUnlocked &&
          !_unlockingBiometric &&
          !isIncomplete) {
        unawaited(_unlockAppWithBiometric());
      }

      if (isIncomplete && mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => CompleteProfileScreen(userData: user),
          ),
          (route) => false,
        );
      }
    } else {
      if (mounted && (_userData != null || _biometricLocked)) {
        setState(() {
          _userData = null;
          _biometricLocked = false;
          _biometricHint = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_biometricLocked) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEC5B13).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(
                      Icons.fingerprint_rounded,
                      color: Color(0xFFEC5B13),
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Verifikasi Biometrik Diperlukan',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _biometricHint ??
                        'Gunakan sidik jari atau wajah untuk masuk ke akun City Courier Anda.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _unlockAppWithBiometric,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEC5B13),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.fingerprint_rounded),
                      label: const Text(
                        'Masuk dengan Biometrik',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _logoutFromBiometricLock,
                    child: const Text(
                      'Keluar Akun',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          RefreshIndicator(
            color: const Color(0xFFEC5B13),
            onRefresh: () async {
              await Future.wait([
                _checkProfileCompletion(),
                ActiveOrderService.syncFromBackend(),
              ]);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  HomeHeader(userData: _userData),
                  const SearchBarWidget(),
                  const PickupDropoff(),
                  const ServicesSection(),
                  CourierBanner(userData: _userData),
                  OtherFeaturesSection(userData: _userData),
                  const SizedBox(height: 220), // Ensure content is scrollable above the floating card and nav bar
                ],
              ),
            ),
          ),
          // Floating active order delivery card (Melayang di atas bottom navigation bar)
          const FloatingActiveOrderWidget(),
          const BottomNavBar(activeIndex: 0),
        ],
      ),
    );
  }
}
