import 'package:flutter/material.dart';
import 'package:city_courierapp/services/api_service.dart';
import 'package:city_courierapp/screens/home_screen.dart';

class ProfileLogoutButton extends StatelessWidget {
  final Color surfaceColor;

  const ProfileLogoutButton({
    super.key,
    required this.surfaceColor,
  });

  /// Menampilkan dialog konfirmasi logout:
  /// - Judul: Keluar dari Akun?
  /// - Pesan: Apakah kamu yakin ingin keluar dari akun ini?
  /// - Tombol Batal: Menutup dialog tanpa mengubah status login
  /// - Tombol Keluar: Mengonfirmasi logout
  static Future<bool> showLogoutConfirmationDialog(BuildContext context) async {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final bool? confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor:
            isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        title: Text(
          'Keluar dari Akun?',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: isDarkMode ? Colors.white : const Color(0xFF1F2937),
          ),
        ),
        content: Text(
          'Apakah kamu yakin ingin keluar dari akun ini?',
          style: TextStyle(
            fontSize: 14,
            color: isDarkMode
                ? Colors.grey.shade300
                : const Color(0xFF4B5563),
            height: 1.4,
          ),
        ),
        actionsPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Batal',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDarkMode
                    ? Colors.grey.shade400
                    : Colors.grey.shade600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 10,
              ),
            ),
            child: const Text(
              'Keluar',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    return confirm ?? false;
  }

  Future<void> _handleLogout(BuildContext context) async {
    final bool confirm = await showLogoutConfirmationDialog(context);

    if (confirm) {
      await ApiService.logout();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
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
