import 'package:flutter/material.dart';
import 'package:city_courierapp/core/config/app_typography.dart';
import 'package:city_courierapp/screens/profile/favorite_address_screen.dart';
import 'package:city_courierapp/screens/profile/keamanan_akun/account_security_screen.dart';
import 'package:city_courierapp/screens/profile/daftar_kurir/views/informasi_pendaftaran_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/home/driver_home_screen.dart';
import 'package:city_courierapp/services/courier/courier_api_service.dart';
import 'package:city_courierapp/core/utils/auth_guard.dart';
import 'package:city_courierapp/screens/help/help_screen.dart';
import 'package:city_courierapp/screens/wallet/customer_wallet_dashboard_screen.dart';

class ProfileNavigationGrid extends StatelessWidget {
  final Color primaryColor;
  final Color surfaceColor;
  final Color borderColor;
  final Map<String, dynamic>? userData;
  final bool showWalletCard;

  const ProfileNavigationGrid({
    super.key,
    required this.primaryColor,
    required this.surfaceColor,
    required this.borderColor,
    this.userData,
    this.showWalletCard = true,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final navItems = [
      {'icon': Icons.location_on, 'label': 'Alamat Favorit'},
      {'icon': Icons.security, 'label': 'Keamanan Akun'},
      {'icon': Icons.people_alt, 'label': 'Daftar Kurir'},
      {'icon': Icons.calendar_today, 'label': 'Reward Harian'},
      {'icon': Icons.privacy_tip, 'label': 'Kebijakan Privasi'},
      {'icon': Icons.help, 'label': 'Pusat Bantuan'},
    ];

    return Column(
      children: [
        if (showWalletCard)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => AuthGuard.runWithAuth(
                  context,
                  onAuthenticated: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CustomerWalletDashboardScreen(),
                    ),
                  ),
                ),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.account_balance_wallet_rounded,
                          color: primaryColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'City Wallet',
                              style: AppTypography.titleSmall.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isDarkMode
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Top-up saldo, bayar pesanan, & refund',
                              style: AppTypography.caption.copyWith(
                                fontSize: 11.5,
                                color: isDarkMode
                                    ? Colors.grey.shade400
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: isDarkMode
                            ? Colors.grey.shade500
                            : const Color(0xFF94A3B8),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.08)
                  : borderColor.withValues(alpha: 0.7),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: isDarkMode ? 0.2 : 0.03,
                ),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisExtent: 90,
              crossAxisSpacing: 0,
              mainAxisSpacing: 0,
            ),
            itemCount: navItems.length,
            itemBuilder: (context, index) {
              return Container(
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(
                      color: index % 3 != 2
                          ? borderColor.withValues(alpha: 0.7)
                          : Colors.transparent,
                    ),
                    bottom: BorderSide(
                      color: index < 3
                          ? borderColor.withValues(alpha: 0.7)
                          : Colors.transparent,
                    ),
                  ),
                ),
                child: InkWell(
                  onTap: () {
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
                          builder: (context) => AccountSecurityScreen(
                            initialUserData: userData,
                          ),
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
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 10,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          navItems[index]['icon'] as IconData,
                          color: primaryColor,
                          size: 25,
                        ),
                        const SizedBox(height: 8),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            navItems[index]['label'] as String,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            style: AppTypography.caption.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDarkMode
                                  ? Colors.white.withValues(alpha: 0.9)
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
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
