import 'package:city_courierapp/core/config/app_typography.dart';
import 'package:city_courierapp/core/utils/auth_guard.dart';
import 'package:city_courierapp/models/wallet/wallet_models.dart';
import 'package:city_courierapp/screens/profile/edit_profile_screen.dart';
import 'package:city_courierapp/screens/widgets/home/bottom_nav_bar.dart';
import 'package:city_courierapp/screens/widgets/profile/clear_cache_dialog.dart';
import 'package:city_courierapp/screens/widgets/profile/profile_header.dart';
import 'package:city_courierapp/screens/widgets/profile/profile_logout_button.dart';
import 'package:city_courierapp/screens/widgets/profile/profile_navigation_grid.dart';
import 'package:city_courierapp/screens/widgets/profile/profile_settings_list.dart';
import 'package:city_courierapp/screens/widgets/profile/profile_stats_grid.dart';
import 'package:city_courierapp/screens/widgets/profile/profile_wallet_card.dart';
import 'package:city_courierapp/services/api_service.dart';
import 'package:city_courierapp/services/storage/app_cache_service.dart';
import 'package:city_courierapp/services/wallet/customer_wallet_service.dart';
import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  final CustomerWalletService? walletService;
  final AppCacheService? cacheService;

  const ProfileScreen({
    super.key,
    this.walletService,
    this.cacheService,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool get isDarkMode => Theme.of(context).brightness == Brightness.dark;
  late final CustomerWalletService _walletService =
      widget.walletService ?? CustomerWalletService.instance;
  late final AppCacheService _cacheService =
      widget.cacheService ?? AppCacheService.instance;

  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _courierData;
  CustomerWalletSummary? _walletSummary;
  bool _isLoading = true;
  bool _isWalletLoading = true;
  String _cacheSizeLabel = '0 B';
  bool _isClearingCache = false;

  /// Pilihan "Akun Kurir" hanya muncul untuk pengguna yang benar-benar sudah
  /// terdaftar sebagai kurir dan disetujui admin (`is_verified`).
  bool get _isVerifiedCourier {
    final courier = _courierData;
    if (courier == null) return false;
    final verified = courier['is_verified'];
    return verified == true || verified == 1 || verified == '1';
  }

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final isAuthed = await AuthGuard.guardScreen(context);
    if (!isAuthed) return;

    await Future.wait([
      _fetchProfile(),
      _fetchWallet(),
      _refreshCacheSize(),
    ]);
  }

  Future<void> _refreshCacheSize() async {
    final info = await _cacheService.inspectCache(silentOnError: true);
    if (!mounted) return;
    setState(() {
      _cacheSizeLabel = info.formattedSize;
    });
  }

  Future<void> _handleClearCache() async {
    if (_isClearingCache) return;
    setState(() => _isClearingCache = true);

    try {
      final latestInfo = await _cacheService.inspectCache(silentOnError: true);
      if (!mounted) return;
      setState(() {
        _cacheSizeLabel = latestInfo.formattedSize;
      });

      final result = await ClearCacheDialog.show(
        context,
        cacheService: _cacheService,
        cacheSizeLabel: latestInfo.formattedSize,
      );

      if (!mounted) return;
      if (result == null) return;

      setState(() {
        _cacheSizeLabel = result.formattedRemainingSize;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor: result.success
                ? const Color(0xFF16A34A)
                : const Color(0xFFDC2626),
            content: Text(
              result.success
                  ? 'Cache berhasil dibersihkan. Penyimpanan sementara aplikasi telah diperbarui.'
                  : (result.errorMessage ??
                      'Gagal membersihkan cache aplikasi. Silakan coba lagi.'),
              style: AppTypography.bodySmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
    } finally {
      if (mounted) {
        setState(() => _isClearingCache = false);
      }
    }
  }

  Future<void> _fetchProfile() async {
    try {
      final profile = await ApiService.getProfile();
      if (mounted) {
        setState(() {
          _userData = profile?['user'];
          _courierData = profile?['courier'] is Map
              ? Map<String, dynamic>.from(profile!['courier'] as Map)
              : null;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchWallet() async {
    try {
      final summary = await _walletService.getWallet();
      if (mounted) {
        setState(() {
          _walletSummary = summary;
          _isWalletLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isWalletLoading = false);
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
    const bgLight = Color(0xFFF6F7F9);
    const bgDark = Color(0xFF0F172A);
    final surfaceColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE5E7EB);

    return Scaffold(
      backgroundColor: isDarkMode ? bgDark : bgLight,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _loadAll,
            displacement: 80,
            color: primaryColor,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProfileHeader(
                    primaryColor: primaryColor,
                    userData: _userData,
                    isLoading: _isLoading,
                    onEditProfile: _showEditProfile,
                    isCourier: _isVerifiedCourier,
                  ),
                  ProfileWalletCard(
                    primaryColor: primaryColor,
                    surfaceColor: surfaceColor,
                    borderColor: borderColor,
                    wallet: _walletSummary,
                    isLoading: _isWalletLoading,
                    walletService: _walletService,
                    onWalletUpdated: _fetchWallet,
                  ),
                  ProfileStatsGrid(
                    primaryColor: primaryColor,
                    surfaceColor: surfaceColor,
                    borderColor: borderColor,
                    isDarkMode: isDarkMode,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader('Akun & Keamanan'),
                        const SizedBox(height: 10),
                        ProfileNavigationGrid(
                          primaryColor: primaryColor,
                          surfaceColor: surfaceColor,
                          borderColor: borderColor,
                          userData: _userData,
                          showWalletCard: false,
                        ),
                        const SizedBox(height: 20),
                        _buildSectionHeader('Pengaturan Aplikasi'),
                        const SizedBox(height: 10),
                        ProfileSettingsList(
                          surfaceColor: surfaceColor,
                          borderColor: borderColor,
                          onTapEditProfile: _showEditProfile,
                          cacheSizeLabel: _cacheSizeLabel,
                          onTapClearCache: _handleClearCache,
                        ),
                        const SizedBox(height: 22),
                        ProfileLogoutButton(surfaceColor: surfaceColor),
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const BottomNavBar(activeIndex: 2),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        title,
        style: AppTypography.titleMedium.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
        ),
      ),
    );
  }
}
