import 'package:flutter/material.dart';

import 'package:city_courierapp/controllers/navigation_controller.dart';
import 'package:city_courierapp/screens/courier/ci_word/delivery/driver_navigation_screen.dart';

/// Delegasi ke [DriverNavigationScreen] dengan fase delivery.
class DriverNavigationDeliveryScreen extends StatelessWidget {
  final Map<String, dynamic> order;

  const DriverNavigationDeliveryScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return DriverNavigationScreen(
      order: order,
      phase: NavigationPhase.delivery,
    );
  }
}