import 'package:flutter/material.dart';
import 'package:city_courierapp/services/api_service.dart';
import 'package:city_courierapp/screens/landing_screen.dart';

class ProfileLogoutButton extends StatelessWidget {
  final Color surfaceColor;

  const ProfileLogoutButton({
    Key? key,
    required this.surfaceColor,
  }) : super(key: key);

  Future<void> _handleLogout(BuildContext context) async {
    // Show confirmation dialog
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar'),
        content: const Text('Apakah Anda yakin ingin keluar dari akun?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Keluar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ApiService.logout();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LandingScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _handleLogout(context),
            icon: const Icon(Icons.logout, size: 18), // Smaller icon
            label: const Text(
              'Keluar',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13), // Smaller text
            ),
            style: OutlinedButton.styleFrom(
              backgroundColor: surfaceColor,
              foregroundColor: Colors.red,
              side: const BorderSide(color: Color(0xFFFFCDD2)),
              padding: const EdgeInsets.symmetric(vertical: 12), // Reduced padding
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'City Courier App v2.4.0',
          style: TextStyle(
            fontSize: 9, // Smaller
            color: Colors.blueGrey[200],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
