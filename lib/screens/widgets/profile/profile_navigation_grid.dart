import 'package:flutter/material.dart';
import 'package:city_courierapp/screens/profile/favorite_address_screen.dart';
import 'package:city_courierapp/screens/profile/keamanan_akun/account_security_screen.dart';
import 'package:city_courierapp/screens/profile/daftar_kurir/views/informasi_pendaftaran_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/home/driver_home_screen.dart';
import 'package:city_courierapp/services/courier/courier_api_service.dart';
import 'package:city_courierapp/screens/help/help_screen.dart';

class ProfileNavigationGrid extends StatelessWidget {
  final Color primaryColor;
  final Color surfaceColor;
  final Color borderColor;
  final Map<String, dynamic>? userData;

  const ProfileNavigationGrid({
    Key? key,
    required this.primaryColor,
    required this.surfaceColor,
    required this.borderColor,
    this.userData,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final navItems = [
      {'icon': Icons.location_on, 'label': 'Alamat Favorit'},
      {'icon': Icons.security, 'label': 'Keamanan Akun'},
      {'icon': Icons.people_alt, 'label': 'Daftar Kurir'},
      {'icon': Icons.calendar_today, 'label': 'Reward Harian'},
      {'icon': Icons.privacy_tip, 'label': 'Kebijakan Privasi'},
      {'icon': Icons.help, 'label': 'Pusat Bantuan'},
    ];

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisExtent: 80, // Reduced from 100
          crossAxisSpacing: 1,
          mainAxisSpacing: 1,
        ),
        itemCount: navItems.length,
        itemBuilder: (context, index) {
          return Container(
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(
                  color: index % 3 != 2 ? borderColor : Colors.transparent,
                ),
                bottom: BorderSide(
                  color: index < 3 ? borderColor : Colors.transparent,
                ),
              ),
            ),
            child: InkWell(
              onTap: () {
                // ... logic same
                if (navItems[index]['label'] == 'Alamat Favorit') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const FavoriteAddressScreen(),
                    ),
                  );
                } else if (navItems[index]['label'] == 'Keamanan Akun') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AccountSecurityScreen(),
                    ),
                  );
                } else if (navItems[index]['label'] == 'Daftar Kurir') {
                  _handleCourierRegistration(context);
                } else if (navItems[index]['label'] == 'Pusat Bantuan') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HelpScreen(),
                    ),
                  );
                }
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    navItems[index]['icon'] as IconData,
                    color: primaryColor,
                    size: 20, // Slightly smaller
                  ),
                  const SizedBox(height: 6),
                  Text(
                    navItems[index]['label'] as String,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 9, // Slightly smaller
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleCourierRegistration(BuildContext context) async {
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
          final isVerified = result['data']['is_verified'] == true || result['data']['is_verified'] == 1;
          
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
          // User is not a courier, go to registration screen
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terjadi kesalahan: $e')),
        );
      }
    }
  }
}
