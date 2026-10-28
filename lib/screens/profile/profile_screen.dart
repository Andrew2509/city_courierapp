import 'package:flutter/material.dart';
import 'package:city_courierapp/core/utils/auth_guard.dart';
import 'package:city_courierapp/screens/widgets/home/bottom_nav_bar.dart';
import 'package:city_courierapp/screens/widgets/profile/profile_header.dart';
import 'package:city_courierapp/screens/widgets/profile/profile_stats_grid.dart';
import 'package:city_courierapp/screens/widgets/profile/profile_invite_banner.dart';
import 'package:city_courierapp/screens/widgets/profile/profile_navigation_grid.dart';
import 'package:city_courierapp/screens/widgets/profile/profile_settings_list.dart';
import 'package:city_courierapp/screens/widgets/profile/profile_logout_button.dart';
import 'package:city_courierapp/services/api_service.dart';
import 'package:city_courierapp/screens/profile/edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool get isDarkMode => Theme.of(context).brightness == Brightness.dark;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final isAuthed = await AuthGuard.guardScreen(context);
    if (!isAuthed) return;

    try {
      final profile = await ApiService.getProfile();
      if (mounted) {
        setState(() {
          _userData = profile?['user'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showEditProfile() async {
    if (_userData == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(userData: _userData!),
      ),
    );

    if (result == true) {
      _fetchProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFEC5B13);
    const bgLight = Color(0xFFF8F9FA);
    const bgDark = Color(0xFF0F172A);
    final surfaceColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDarkMode
        ? Colors.white.withOpacity(0.05)
        : const Color(0xFFE5E7EB);

    return Scaffold(
      backgroundColor: isDarkMode ? bgDark : bgLight,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _fetchProfile,
            displacement: 80,
            color: primaryColor,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Section
                  ProfileHeader(
                    primaryColor: primaryColor,
                    userData: _userData,
                    isLoading: _isLoading,
                    onEditProfile: _showEditProfile,
                  ),

                  // Order Status (Stats Grid)
                  // Let's make it sit slightly overlap the header
                  ProfileStatsGrid(
                    primaryColor: primaryColor,
                    surfaceColor: surfaceColor,
                    borderColor: borderColor,
                    isDarkMode: isDarkMode,
                  ),

                  // Content Sections
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0), // Added top padding
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Invite banner removed as per HTML design
                        
                        _buildSectionHeader('Akun & Keamanan'),
                        const SizedBox(height: 12), // Increased from 8
                        ProfileNavigationGrid(
                          primaryColor: primaryColor,
                          surfaceColor: surfaceColor,
                          borderColor: borderColor,
                          userData: _userData,
                        ),

                        const SizedBox(height: 20), // Increased from 12
                        
                        _buildSectionHeader('Pengaturan Aplikasi'),
                        const SizedBox(height: 12), // Increased from 8
                        ProfileSettingsList(
                          surfaceColor: surfaceColor,
                          borderColor: borderColor,
                          onTapEditProfile: _showEditProfile,
                        ),

                        const SizedBox(height: 24), // Increased from 12
                        
                        // Logout section
                        ProfileLogoutButton(surfaceColor: surfaceColor),

                        const SizedBox(height: 120), // Space for bottom nav
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const BottomNavBar(activeIndex: 3),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: isDarkMode ? Colors.white70 : Colors.blueGrey[800],
        ),
      ),
    );
  }
}
