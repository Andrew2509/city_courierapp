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
import 'package:city_courierapp/screens/home_screen.dart';
import 'package:city_courierapp/screens/profile/profile_screen.dart';
import 'package:city_courierapp/services/api_service.dart';
import 'package:city_courierapp/widgets/common/city_courier_icon.dart';

class DriverProfileScreen extends StatefulWidget {
  final bool fromPersonalProfile;
  final Map<String, dynamic>? initialProfileData;

  const DriverProfileScreen({
    super.key,
    this.fromPersonalProfile = false,
    this.initialProfileData,
  });

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _profileData;
  String? _errorMessage;
  bool _isCourierMode = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialProfileData != null) {
      _profileData = widget.initialProfileData;
      _isLoading = false;
    }
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (_profileData == null) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final result = await CourierProfileService.getProfile();
      if (mounted) {
        setState(() {
          if (result['success'] == true) {
            _profileData = result['data'];
            _errorMessage = null;
          } else if (_profileData == null) {
            _errorMessage = result['message'];
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (_profileData == null) {
            _errorMessage = e.toString();
          }
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
                                icon: const CityCourierCustomIcon(
                                  CourierIconKind.settingsGear,
                                  size: 26,
                                ),
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
      child: Column(
        children: [
          Row(
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
                          : 'https://www.neonflux.my.id/storage/${user?['photo_url'] ?? user?['photo']}',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          Container(
                        color: const Color(0xFFF1F5F9),
                        child: Center(
                          child: Text(
                            (user?['name'] as String?)?.isNotEmpty == true
                                ? (user!['name'] as String)
                                    .substring(0, 1)
                                    .toUpperCase()
                                : 'D',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ),
                      ),
                    )
                  : Container(
                      color: const Color(0xFFF1F5F9),
                      child: Center(
                        child: Text(
                          (user?['name'] as String?)?.isNotEmpty == true
                              ? (user!['name'] as String)
                                  .substring(0, 1)
                                  .toUpperCase()
                              : 'D',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                      ),
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
                    const CityCourierCustomIcon(
                      CourierIconKind.rateApp,
                      size: 17,
                    ),
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
      const SizedBox(height: 16),
      // Bottom Section: Mode Switch (Akun Personal vs Akun Kurir)
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (!_isCourierMode) return;
                  setState(() => _isCourierMode = false);
                  if (widget.fromPersonalProfile && Navigator.canPop(context)) {
                    Navigator.pop(context);
                  } else {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProfileScreen(),
                      ),
                      (route) => route.isFirst,
                    );
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: !_isCourierMode
                        ? primaryColor
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(100),
                    boxShadow: !_isCourierMode
                        ? [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ]
                        : [],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CityCourierCustomIcon(
                        CourierIconKind.personalAccount,
                        color: !_isCourierMode
                            ? Colors.white
                            : const Color(0xFF9CA3AF),
                        size: 15,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Akun Personal',
                        style: TextStyle(
                          color: !_isCourierMode
                              ? Colors.white
                              : const Color(0xFF9CA3AF),
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (_isCourierMode) return;
                  setState(() => _isCourierMode = true);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _isCourierMode
                        ? primaryColor
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(100),
                    boxShadow: _isCourierMode
                        ? [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ]
                        : [],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CityCourierCustomIcon(
                        CourierIconKind.courierAccount,
                        color: _isCourierMode
                            ? Colors.white
                            : const Color(0xFF9CA3AF),
                        size: 15,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Akun Kurir',
                        style: TextStyle(
                          color: _isCourierMode
                              ? Colors.white
                              : const Color(0xFF9CA3AF),
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
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
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const CityCourierCustomIcon(
                CourierIconKind.infoBadge,
                size: 26,
              ),
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
            CityCourierCustomIcon(
              CourierIconKind.chevronRight,
              color: primaryColor,
              size: 16,
            ),
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
                icon: CityCourierCustomIcon(
                  CourierIconKind.chevronRight,
                  color: textMuted,
                  size: 17,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildListItem(
            iconKind: CourierIconKind.editProfile,
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
            iconKind: CourierIconKind.phoneContact,
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
            iconKind: CourierIconKind.emailContact,
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
            iconKind: CourierIconKind.motorcycle,
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
            iconKind: CourierIconKind.helpCenter,
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
            iconKind: CourierIconKind.settingsGear,
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
    required CourierIconKind iconKind,
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
            CityCourierCustomIcon(iconKind, size: 25),
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
            CityCourierCustomIcon(
              CourierIconKind.chevronRight,
              color: textMuted,
              size: 14,
            ),
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
            CityCourierCustomIcon(
              CourierIconKind.logout,
              color: primaryColor,
              size: 18,
            ),
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
      builder: (dialogContext) => AlertDialog(
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
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Batal', style: TextStyle(color: Colors.grey[600])),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await ApiService.logout();
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const HomeScreen()),
                (route) => false,
              );
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
