import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:city_courierapp/main.dart' show routeObserver;
import 'package:city_courierapp/providers/call_provider.dart';
import 'package:city_courierapp/providers/chat_provider.dart';
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
import 'package:city_courierapp/screens/auth/complete_profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    ActiveOrderService.init();
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
    _checkProfileCompletion();
  }

  Future<void> _checkProfileCompletion() async {
    final profileData = await ApiService.getProfile();

    if (profileData != null && profileData['user'] is Map) {
      final user = Map<String, dynamic>.from(profileData['user'] as Map);
      user['phone_verified'] ??= profileData['phone_verified'] == true;

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
        });
        final parsedUserId = int.tryParse((user['id'] ?? '').toString());
        if (parsedUserId != null && parsedUserId > 0) {
          unawaited(context.read<ChatProvider>().bindAuthenticatedUser(parsedUserId));
          unawaited(context.read<CallProvider>().bindAuthenticatedUser(parsedUserId));
        }
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
      if (mounted && _userData != null) {
        setState(() {
          _userData = null;
        });
        unawaited(context.read<ChatProvider>().clearOnLogout());
        unawaited(context.read<CallProvider>().clearOnLogout());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
