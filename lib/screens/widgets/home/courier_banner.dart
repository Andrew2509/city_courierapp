import 'package:flutter/material.dart';
import 'package:city_courierapp/core/utils/auth_guard.dart';
import 'package:city_courierapp/screens/courier/ci_word/home/driver_home_screen.dart';
import 'package:city_courierapp/screens/profile/daftar_kurir/views/informasi_pendaftaran_screen.dart';
import 'package:city_courierapp/services/courier/courier_api_service.dart';

class CourierBanner extends StatelessWidget {
  final Map<String, dynamic>? userData;
  const CourierBanner({super.key, this.userData});

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFFEC5B13);

    return Padding(
      padding: const EdgeInsets.only(top: 24, left: 20, right: 20),
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              AuthGuard.runWithAuth(
                context,
                onAuthenticated: () => _handleCourierNavigation(context),
              );
            },
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset(
                  'assets/images/Banner4.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 150,
                    color: Colors.grey.shade200,
                    child: const Center(
                      child: Icon(Icons.image_not_supported_rounded),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 24,
                height: 6,
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.grey.shade600
                      : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleCourierNavigation(BuildContext context) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEC5B13)),
        ),
      ),
    );

    try {
      final result = await CourierApiService.getCourierStatus();

      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog

        if (result['success'] == true) {
          final isVerified = result['data']['is_verified'] == true ||
              result['data']['is_verified'] == 1;

          if (isVerified) {
            // User is already a courier and verified, go to dashboard
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const DriverHomeScreen()),
            );
          } else {
            // Courier exists but not yet verified
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.hourglass_empty, color: Color(0xFFEC5B13)),
                    SizedBox(width: 10),
                    Text('Menunggu Verifikasi'),
                  ],
                ),
                content: const Text(
                  'Pendaftaran Anda sedang ditinjau oleh admin. Silakan cek kembali nanti atau hubungi bantuan jika sudah lebih dari 2x24 jam.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Tutup'),
                  ),
                ],
              ),
            );
          }
        } else {
          // User is not a courier, go to new registration screen from profile
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const InformasiPendaftaranScreen(),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Terjadi kesalahan: $e')));
      }
    }
  }
}
