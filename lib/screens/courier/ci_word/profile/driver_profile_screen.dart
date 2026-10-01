import 'package:flutter/material.dart';
import 'package:city_courierapp/core/config/app_colors.dart';
import 'package:city_courierapp/screens/courier/ci_word/home/driver_home_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/earnings/driver_earnings_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/shipment/driver_shipment_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/widgets/driver_bottom_navigation.dart';
import 'package:city_courierapp/services/courier/courier_profile_service.dart';
import 'package:city_courierapp/screens/courier/ci_word/profile/driver_account_info_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/profile/driver_help_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/profile/driver_settings_screen.dart';

class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _profileData;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await CourierProfileService.getProfile();
      if (mounted) {
        setState(() {
          if (result['success'] == true) {
            _profileData = result['data'];
          } else {
            _errorMessage = result['message'];
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFEC5B13);
    const bgLight = Color(0xFFF8F9FA);
    final textMain = Colors.black87;
    final textMuted = Colors.grey[600]!;
    final borderColor = const Color(0xFFE5E7EB);

    return Scaffold(
      backgroundColor: bgLight,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryOrange))
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: $_errorMessage',
                          style: TextStyle(color: textMain)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadProfile,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor),
                        child: const Text('Coba Lagi',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadProfile,
                  color: primaryColor,
                  child: SafeArea(
                    child: Column(
                      children: [
                        // Custom Header
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Profile',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: textMain,
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.settings_outlined,
                                    color: textMain),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            const DriverSettingsScreen()),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),

                        Expanded(
                          child: SingleChildScrollView(
                            physics:
                                const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),                              child: Column(
                              children: [
                                _buildProfileCard(primaryColor),
                                const SizedBox(height: 16),
                                if (_hasEmptyFields()) _buildCompleteProfileBanner(primaryColor, textMain, textMuted),
                                const SizedBox(height: 20),
                                _buildInformasiAkunSection(
                                    primaryColor,
                                    borderColor,
                                    textMain,
                                    textMuted),
                                const SizedBox(height: 20),
                                _buildAkunSection(
                                    primaryColor,
                                    borderColor,
                                    textMain,
                                    textMuted),
                                const SizedBox(height: 20),
                                _buildLogoutButton(primaryColor),
                                const SizedBox(height: 80),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
      bottomNavigationBar: DriverBottomNavigation(
        currentIndex: 3,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) => const DriverHomeScreen()),
            );
          } else if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) => const DriverShipmentScreen()),
            );
          } else if (index == 2) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) => const DriverEarningsScreen()),
            );
          }
        },
      ),
    );
  }

  Widget _buildProfileCard(Color primaryColor) {
    final user = _profileData?['user'];
    final stats = _profileData?['stats'];

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        image: const DecorationImage(
          image: AssetImage('assets/images/bg2.png'),
          fit: BoxFit.cover,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              color: Colors.white,
            ),
            child: ClipOval(
              child: (user?['photo_url'] != null ||
                      user?['photo'] != null)
                  ? Image.network(
                      (user?['photo_url'] ?? user?['photo'])
                                  .toString()
                                  .startsWith('http')
                          ? (user?['photo_url'] ?? user?['photo'])
                          : 'https://citycourier.pabm.space/storage/${user?['photo_url'] ?? user?['photo']}',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          Image.network(
                        'https://ui-avatars.com/api/?name=${Uri.encodeComponent(user?['name'] ?? 'Driver')}&background=F1F5F9&color=1A1A1A&size=100',
                        fit: BoxFit.cover,
                      ),
                    )
                  : Image.network(
                      'https://ui-avatars.com/api/?name=${Uri.encodeComponent(user?['name'] ?? 'Driver')}&background=F1F5F9&color=1A1A1A&size=100',
                      fit: BoxFit.cover,
                    ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?['name'] ?? 'Driver',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.star,
                        color: Color(0xFFFCD34D), size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '${stats?['rating'] ?? "4.9"} (${stats?['total_ratings'] ?? "128"} Rating)',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF16A34A),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Kurir Aktif',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _hasEmptyFields() {
    final courier = _profileData?['courier_details'];
    final city = courier?['city'] ?? '';
    final address = courier?['address'] ?? '';
    final vehicleBrand = courier?['vehicle_brand'] ?? '';
    final vehicleModel = courier?['vehicle_model'] ?? '';
    return city.isEmpty || address.isEmpty || vehicleBrand.isEmpty || vehicleModel.isEmpty;
  }

  Widget _buildCompleteProfileBanner(Color primaryColor, Color textMain, Color textMuted) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const DriverAccountInfoScreen()),
        ).then((_) => _loadProfile());
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: primaryColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: primaryColor.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.info_outline, color: primaryColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lengkapi Profil Anda',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: textMain,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Isi data kota, alamat, dan kendaraan Anda',
                    style: TextStyle(
                      fontSize: 11,
                      color: textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: primaryColor, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInformasiAkunSection(
      Color primaryColor, Color borderColor, Color textMain, Color textMuted) {
    final user = _profileData?['user'];
    final courier = _profileData?['courier_details'];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Informasi Akun',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: textMain,
                ),
              ),
              IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            const DriverAccountInfoScreen()),
                  ).then((_) => _loadProfile());
                },
                icon: Icon(Icons.chevron_right, color: textMuted, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildListItem(
            icon: Icons.person_outline,
            label: 'Nama Lengkap',
            value: user?['name'] ?? '-',
            borderColor: borderColor,
            textMain: textMain,
            textMuted: textMuted,
            showBorder: true,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        const DriverAccountInfoScreen()),
              ).then((_) => _loadProfile());
            },
          ),
          _buildListItem(
            icon: Icons.phone_outlined,
            label: 'Nomor Telepon',
            value: user?['phone'] ?? '-',
            borderColor: borderColor,
            textMain: textMain,
            textMuted: textMuted,
            showBorder: true,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        const DriverAccountInfoScreen()),
              ).then((_) => _loadProfile());
            },
          ),
          _buildListItem(
            icon: Icons.email_outlined,
            label: 'Email',
            value: user?['email'] ?? '-',
            borderColor: borderColor,
            textMain: textMain,
            textMuted: textMuted,
            showBorder: true,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        const DriverAccountInfoScreen()),
              ).then((_) => _loadProfile());
            },
          ),
          _buildListItem(
            icon: Icons.two_wheeler_outlined,
            label: 'Kendaraan',
            value: _getVehicleDisplay(courier),
            borderColor: borderColor,
            textMain: textMain,
            textMuted: textMuted,
            showBorder: false,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        const DriverAccountInfoScreen()),
              ).then((_) => _loadProfile());
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAkunSection(
      Color primaryColor, Color borderColor, Color textMain, Color textMuted) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Akun',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: textMain,
            ),
          ),
          const SizedBox(height: 12),
          _buildListItem(
            icon: Icons.help_outline,
            label: 'Bantuan & FAQ',
            value: '',
            borderColor: borderColor,
            textMain: textMain,
            textMuted: textMuted,
            showBorder: true,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        const DriverHelpScreen()),
              );
            },
          ),
          _buildListItem(
            icon: Icons.settings_outlined,
            label: 'Pengaturan',
            value: '',
            borderColor: borderColor,
            textMain: textMain,
            textMuted: textMuted,
            showBorder: false,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        const DriverSettingsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildListItem({
    required IconData icon,
    required String label,
    required String value,
    required Color borderColor,
    required Color textMain,
    required Color textMuted,
    required bool showBorder,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: showBorder
              ? Border(bottom: BorderSide(color: borderColor))
              : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: textMuted, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textMain,
              ),
            ),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: textMuted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: textMuted, size: 16),
          ],
        ),
      ),
    );
  }

  String _getVehicleDisplay(Map<String, dynamic>? courier) {
    if (courier == null) return '-';
    final brand = courier['vehicle_brand'] ?? '';
    final model = courier['vehicle_model'] ?? '';
    final plate = courier['vehicle_plate'] ?? '';
    if (brand.isNotEmpty && model.isNotEmpty) return '$brand $model';
    if (brand.isNotEmpty) return brand;
    if (plate.isNotEmpty) return plate;
    return '-';
  }

  Widget _buildLogoutButton(Color primaryColor) {
    return InkWell(
      onTap: () {
        _showLogoutDialog(primaryColor);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: primaryColor),
          color: Colors.transparent,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout, color: primaryColor, size: 18),
            const SizedBox(width: 8),
            Text(
              'Keluar',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(Color primaryColor) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Keluar dari Akun?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'Anda akan keluar dari aplikasi CityCourier.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: TextStyle(color: Colors.grey[600])),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Handle logout
            },
            child: Text(
              'Keluar',
              style: TextStyle(
                  color: primaryColor, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
