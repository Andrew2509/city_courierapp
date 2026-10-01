import 'package:flutter/material.dart';
import 'package:city_courierapp/screens/courier/ci_word/wallet/dompet_screen.dart';

/// This screen now redirects to the new DompetScreen design.
/// The old earnings UI has been replaced by the Stitch-based wallet design.
class DriverEarningsScreen extends StatelessWidget {
  const DriverEarningsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DompetScreen();
  }
}
