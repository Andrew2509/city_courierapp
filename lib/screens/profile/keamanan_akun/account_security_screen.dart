import 'dart:async';

import 'package:city_courierapp/models/security/account_security_models.dart';
import 'package:city_courierapp/screens/landing_screen.dart';
import 'package:city_courierapp/screens/profile/keamanan_akun/widgets/security_devices_screen.dart';
import 'package:city_courierapp/screens/profile/keamanan_akun/widgets/security_phone_screen.dart';
import 'package:city_courierapp/screens/profile/keamanan_akun/widgets/security_pin_screen.dart';
import 'package:city_courierapp/services/security/account_security_service.dart';
import 'package:city_courierapp/services/security/biometric_guard_service.dart';
import 'package:flutter/material.dart';

class AccountSecurityScreen extends StatefulWidget {
  final AccountSecurityService? securityService;
  final Map<String, dynamic>? initialUserData;
  final RequestPhoneOtpFn? onRequestPhoneOtp;
  final VerifyPhoneOtpFn? onVerifyPhoneOtp;

  const AccountSecurityScreen({
    super.key,
    this.securityService,
    this.initialUserData,
    this.onRequestPhoneOtp,
    this.onVerifyPhoneOtp,
  });

  @override
  State<AccountSecurityScreen> createState() => _AccountSecurityScreenState();
}

class _AccountSecurityScreenState extends State<AccountSecurityScreen> {
  static const Color _bgSlate = Color(0xFFF8FAFC);
  static const Color _primaryOrange = Color(0xFFF97316);
  static const Color _slate800 = Color(0xFF1E293B);
  static const Color _slate500 = Color(0xFF64748B);
  static const Color _slate400 = Color(0xFF94A3B8);

  late final AccountSecurityService _service =
      widget.securityService ?? AccountSecurityService.instance;

  late AccountSecurityOverview _overview;
  int _activeScreen = 0; // 0: main, 1: pin, 2: phone, 3: devices/logs
  int _devicesInitialTab = 0;
  bool _loading = true;
  bool _busyPreference = false;
  bool _revokingAll = false;
  String? _loadError;

  Timer? _toastTimer;
  String? _toastMessage;
  bool _toastError = false;
  bool _toastVisible = false;

  @override
  void initState() {
    super.initState();
    _overview = AccountSecurityOverview.fromUserFallback(widget.initialUserData);
    _loadOverview();
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadOverview({bool showSpinner = true}) async {
    if (showSpinner && mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }

    try {
      final overview = await _service.getOverview();
      if (!mounted) return;
      setState(() {
        _overview = overview;
        _loading = false;
        _loadError = null;
      });
    } on SecurityApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401) {
        _handleSessionExpired(e.message);
        return;
      }
      setState(() {
        _loading = false;
        _loadError = e.message;
      });
    } catch (e, st) {
      debugPrint('AccountSecurityScreen._loadOverview error: $e\n$st');
      final localBio = await BiometricGuardService.isLocallyEnabled();
      if (!mounted) return;
      setState(() {
        _overview = AccountSecurityOverview.fromUserFallback(
          widget.initialUserData,
          localBiometric: localBio,
        );
        _loading = false;
        _loadError = 'Gagal memuat sinkronisasi server. Menampilkan data lokal.';
      });
    }
  }

  void _handleSessionExpired(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LandingScreen()),
      (route) => false,
    );
  }

  void _showToast(String message, {bool isError = false}) {
    _toastTimer?.cancel();
    setState(() {
      _toastMessage = message;
      _toastError = isError;
      _toastVisible = true;
    });
    _toastTimer = Timer(const Duration(milliseconds: 2600), () {
      if (mounted) {
        setState(() => _toastVisible = false);
      }
    });
  }

  void _switchScreen(int index, {int devicesTab = 0}) {
    setState(() {
      _devicesInitialTab = devicesTab;
      _activeScreen = index;
    });
  }

  Future<void> _toggleBiometric(bool targetValue) async {
    if (_busyPreference) return;
    setState(() => _busyPreference = true);

    try {
      if (targetValue) {
        final availability = await BiometricGuardService.checkAvailability();
        if (!availability.supported) {
          _showToast(availability.hardwareLabel, isError: true);
          return;
        }
        final auth = await BiometricGuardService.authenticate(
          reason:
              'Verifikasi sidik jari atau kunci layar untuk mengaktifkan Masuk dengan Biometrik',
        );
        if (!auth.authenticated) {
          _showToast(
            auth.message ?? 'Verifikasi biometrik diperlukan untuk mengaktifkan fitur ini.',
            isError: true,
          );
          return;
        }
      }

      final res = await _service.updatePreferences(biometricEnabled: targetValue);
      if (!mounted) return;
      setState(() => _overview = res.overview);
      _showToast(
        targetValue
            ? 'Login Biometrik (Sidik Jari / Face ID) diaktifkan'
            : 'Login Biometrik dinonaktifkan',
      );
    } on SecurityApiException catch (e) {
      if (e.statusCode == 401 && mounted) {
        _handleSessionExpired(e.message);
        return;
      }
      _showToast(e.message, isError: true);
    } catch (_) {
      _showToast('Gagal menyimpan pengaturan biometrik.', isError: true);
    } finally {
      if (mounted) setState(() => _busyPreference = false);
    }
  }

  Future<void> _toggleSecurityAlerts(bool targetValue) async {
    if (_busyPreference) return;
    setState(() => _busyPreference = true);
    try {
      final res = await _service.updatePreferences(
        securityAlertsEnabled: targetValue,
      );
      if (!mounted) return;
      setState(() => _overview = res.overview);
      _showToast(
        targetValue
            ? 'Notifikasi Keamanan diaktifkan'
            : 'Notifikasi Keamanan dinonaktifkan',
      );
    } on SecurityApiException catch (e) {
      if (e.statusCode == 401 && mounted) {
        _handleSessionExpired(e.message);
        return;
      }
      _showToast(e.message, isError: true);
    } catch (_) {
      _showToast('Gagal memperbarui notifikasi keamanan.', isError: true);
    } finally {
      if (mounted) setState(() => _busyPreference = false);
    }
  }

  Future<void> _showBiometricDetailModal() async {
    final availability = await BiometricGuardService.checkAvailability();
    if (!mounted) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.fingerprint_rounded,
                      color: Color(0xFF2563EB),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Masuk dengan Biometrik',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: _slate800,
                          ),
                        ),
                        Text(
                          'Proteksi perangkat dengan Android BiometricPrompt',
                          style: TextStyle(fontSize: 11.5, color: _slate500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _DetailInfoTile(
                label: 'Sensor Tersedia',
                value: availability.hardwareLabel,
              ),
              const SizedBox(height: 8),
              _DetailInfoTile(
                label: 'Status Akun',
                value: _overview.preferences.biometricEnabled
                    ? 'Aktif • Meminta verifikasi biometrik perangkat'
                    : 'Nonaktif • Aktifkan lewat sakelar untuk perlindungan tambahan',
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final test = await BiometricGuardService.authenticate(
                      reason: 'Uji verifikasi biometrik City Courier',
                    );
                    if (!mounted) return;
                    _showToast(
                      test.authenticated
                          ? 'Sensor biometrik berfungsi dengan baik!'
                          : (test.message ?? 'Verifikasi dibatalkan.'),
                      isError: !test.authenticated,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Uji Sensor Biometrik Sekarang',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSecurityLayersModal() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Rincian Lapis Keamanan (${_overview.score.activeLayers}/${_overview.score.totalLayers})',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _slate800,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Lengkapi keempat lapis di bawah agar akun pelanggan Anda terlindungi maksimal.',
                style: TextStyle(fontSize: 12, color: _slate500),
              ),
              const SizedBox(height: 14),
              ..._overview.score.layers.map(
                (layer) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Navigator.pop(ctx);
                      if (layer.key == 'phone_verified') {
                        _switchScreen(2);
                      } else if (layer.key == 'transaction_pin') {
                        _switchScreen(1);
                      } else if (layer.key == 'biometric_login' &&
                          !layer.active) {
                        _toggleBiometric(true);
                      } else if (layer.key == 'security_alerts' &&
                          !layer.active) {
                        _toggleSecurityAlerts(true);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: layer.active
                            ? const Color(0xFFECFDF5)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: layer.active
                              ? const Color(0xFFA7F3D0)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            layer.active
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            color: layer.active
                                ? const Color(0xFF059669)
                                : const Color(0xFF94A3B8),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              layer.label,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _slate800,
                              ),
                            ),
                          ),
                          Text(
                            layer.active ? 'Aktif' : 'Aktifkan',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: layer.active
                                  ? const Color(0xFF059669)
                                  : const Color(0xFFEA580C),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLoginMethodsModal() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Metode Login & Otorisasi Akun',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _slate800,
                ),
              ),
              const SizedBox(height: 14),
              _DetailInfoTile(
                label: 'Akun Google Terhubung',
                value: _overview.user.hasGoogleAuth
                    ? (_overview.user.email ?? 'Terhubung via Google Sign-In')
                    : 'Belum terhubung dengan Google',
              ),
              const SizedBox(height: 10),
              _DetailInfoTile(
                label: 'Nomor Telepon & OTP WhatsApp',
                value: _overview.user.phoneVerified
                    ? '${_overview.user.phoneFormatted ?? _overview.user.phone} (Terverifikasi)'
                    : 'Belum terverifikasi OTP',
              ),
              const SizedBox(height: 10),
              _DetailInfoTile(
                label: 'PIN Transaksi Wallet',
                value: _overview.pin.hasPin
                    ? 'Aktif • Digunakan untuk konfirmasi transaksi City Wallet'
                    : 'Belum diatur',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmRevokeOtherDevices() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Keluar dari Semua Perangkat?',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'Keluar dari semua perangkat lain yang terhubung ke akun ini? Sesi login di ponsel ini tetap aktif.',
          style: TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryOrange,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Keluar Semua'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _revokingAll = true);
    try {
      final res = await _service.revokeOtherDevices();
      if (!mounted) return;
      setState(() => _overview = res.overview);
      _showToast(res.message);
    } on SecurityApiException catch (e) {
      if (e.statusCode == 401 && mounted) {
        _handleSessionExpired(e.message);
        return;
      }
      _showToast(e.message, isError: true);
    } catch (_) {
      _showToast('Gagal mengakhiri sesi perangkat lain.', isError: true);
    } finally {
      if (mounted) setState(() => _revokingAll = false);
    }
  }

  Future<void> _handleRemoveSingleDevice(TrustedDeviceSession device) async {
    try {
      final res = await _service.revokeDevice(device.id);
      if (!mounted) return;
      setState(() => _overview = res.overview);
      _showToast('Perangkat berhasil dihapus dari sesi tepercaya');
    } on SecurityApiException catch (e) {
      if (e.statusCode == 401 && mounted) {
        _handleSessionExpired(e.message);
        return;
      }
      _showToast(e.message, isError: true);
    } catch (_) {
      _showToast('Gagal menghapus perangkat.', isError: true);
    }
  }

  Future<({bool ok, String message, int retryAfter})>
      _handleRequestPinOtp() async {
    try {
      final res = await _service.requestPinResetOtp();
      return (ok: true, message: res.message, retryAfter: res.retryAfter);
    } on SecurityApiException catch (e) {
      return (
        ok: false,
        message: e.message,
        retryAfter: e.retryAfter ?? 0,
      );
    } catch (_) {
      return (
        ok: false,
        message: 'Tidak dapat terhubung ke server.',
        retryAfter: 0,
      );
    }
  }

  Future<({bool ok, String message})> _handleSubmitPin({
    required String newPin,
    required String confirmPin,
    String? currentPin,
    String? otp,
  }) async {
    try {
      final res = await _service.updatePin(
        pin: newPin,
        pinConfirmation: confirmPin,
        currentPin: currentPin,
        otp: otp,
      );
      if (mounted) {
        setState(() => _overview = res.overview);
      }
      return (ok: true, message: res.message);
    } on SecurityApiException catch (e) {
      return (ok: false, message: e.message);
    } catch (_) {
      return (ok: false, message: 'Gagal menyimpan PIN transaksi.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _activeScreen == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _activeScreen != 0) {
          _switchScreen(0);
        }
      },
      child: Scaffold(
        backgroundColor: _bgSlate,
        body: SafeArea(
          child: Stack(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  return Stack(
                    children: [
                      // 01: Main Screen
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                        left: _activeScreen == 0 ? 0 : -width * 0.25,
                        right: _activeScreen == 0 ? 0 : width * 0.25,
                        top: 0,
                        bottom: 0,
                        child: IgnorePointer(
                          ignoring: _activeScreen != 0,
                          child: ExcludeSemantics(
                            excluding: _activeScreen != 0,
                            child: _buildMainScreen(),
                          ),
                        ),
                      ),
                      // 02: Ubah PIN Screen
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                        left: _activeScreen == 1 ? 0 : width,
                        right: _activeScreen == 1 ? 0 : -width,
                        top: 0,
                        bottom: 0,
                        child: IgnorePointer(
                          ignoring: _activeScreen != 1,
                          child: ExcludeSemantics(
                            excluding: _activeScreen != 1,
                            child: SecurityPinScreen(
                              hasExistingPin: _overview.pin.hasPin,
                              hasVerifiedPhone: _overview.user.phoneVerified,
                              maskedPhone: _overview.user.phoneFormatted,
                              onVerifyCurrentPin: _service.verifyPin,
                              onRequestPinResetOtp: _handleRequestPinOtp,
                              onSubmitPin: _handleSubmitPin,
                              onBack: () => _switchScreen(0),
                              onNotify: (msg, {bool isError = false}) =>
                                  _showToast(msg, isError: isError),
                            ),
                          ),
                        ),
                      ),
                      // 03: Verifikasi Nomor HP Screen
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                        left: _activeScreen == 2 ? 0 : width,
                        right: _activeScreen == 2 ? 0 : -width,
                        top: 0,
                        bottom: 0,
                        child: IgnorePointer(
                          ignoring: _activeScreen != 2,
                          child: ExcludeSemantics(
                            excluding: _activeScreen != 2,
                            child: SecurityPhoneScreen(
                              user: _overview.user,
                              onRequestPhoneOtp: widget.onRequestPhoneOtp,
                              onVerifyPhoneOtp: widget.onVerifyPhoneOtp,
                              onPhoneUpdated: () =>
                                  _loadOverview(showSpinner: false),
                              onBack: () => _switchScreen(0),
                              onNotify: (msg, {bool isError = false}) =>
                                  _showToast(msg, isError: isError),
                            ),
                          ),
                        ),
                      ),
                      // 04: Perangkat Tepercaya & Riwayat Aktivitas
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                        left: _activeScreen == 3 ? 0 : width,
                        right: _activeScreen == 3 ? 0 : -width,
                        top: 0,
                        bottom: 0,
                        child: IgnorePointer(
                          ignoring: _activeScreen != 3,
                          child: ExcludeSemantics(
                            excluding: _activeScreen != 3,
                            child: SecurityDevicesScreen(
                              devices: _overview.devices,
                              logs: _overview.activityLogs,
                              initialTab: _devicesInitialTab,
                              onRemoveDevice: _handleRemoveSingleDevice,
                              onBack: () => _switchScreen(0),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),

              // Floating Toast Notification (matching HTML #toastNotification)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                bottom: _toastVisible ? 18 : -70,
                left: 20,
                right: 20,
                child: IgnorePointer(
                  ignoring: !_toastVisible,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _toastVisible ? 1 : 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFF334155),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _toastError ? '⚠️' : '✓',
                              style: TextStyle(
                                fontSize: 13,
                                color: _toastError
                                    ? const Color(0xFFFBBF24)
                                    : const Color(0xFF34D399),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _toastMessage ?? '',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainScreen() {
    final score = _overview.score;
    final badgeColors = switch (score.level) {
      'strong' => (
          bg: const Color(0xFFD1FAE5),
          fg: const Color(0xFF047857),
          border: const Color(0xFFA7F3D0),
        ),
      'medium' => (
          bg: const Color(0xFFFEF3C7),
          fg: const Color(0xFFB45309),
          border: const Color(0xFFFDE68A),
        ),
      _ => (
          bg: const Color(0xFFFFE4E6),
          fg: const Color(0xFFBE123C),
          border: const Color(0xFFFECDD3),
        ),
    };

    return Column(
      children: [
        // Top App Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Color(0xFFF1F5F9)),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: _slate800,
                ),
                tooltip: 'Kembali',
              ),
              const Expanded(
                child: Text(
                  'Keamanan Akun',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _slate800,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              Stack(
                children: [
                  IconButton(
                    onPressed: () => _switchScreen(3, devicesTab: 1),
                    icon: const Icon(
                      Icons.notifications_none_rounded,
                      color: Color(0xFF475569),
                    ),
                    tooltip: 'Notifikasi Keamanan',
                  ),
                  if (_overview.alertCount > 0)
                    Positioned(
                      right: 10,
                      top: 10,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: _primaryOrange,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),

        Expanded(
          child: RefreshIndicator(
            color: _primaryOrange,
            onRefresh: () => _loadOverview(showSpinner: false),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
              children: [
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: LinearProgressIndicator(
                      minHeight: 2,
                      color: _primaryOrange,
                      backgroundColor: Color(0xFFFFEDD5),
                    ),
                  ),
                if (_loadError != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Text(
                      _loadError!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF92400E),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                // Skor Keamanan Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFFFFF7ED),
                        const Color(0xFFFFEDD5).withValues(alpha: 0.65),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0xFFFED7AA).withValues(alpha: 0.9),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _primaryOrange,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: _primaryOrange.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.shield_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Skor Keamanan: ${score.label}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF431407),
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: badgeColors.bg,
                                    borderRadius: BorderRadius.circular(99),
                                    border: Border.all(
                                      color: badgeColors.border,
                                    ),
                                  ),
                                  child: Text(
                                    score.label,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      color: badgeColors.fg,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              score.subtitle,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: const Color(0xFF7C2D12)
                                    .withValues(alpha: 0.8),
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 10),
                            InkWell(
                              onTap: _showSecurityLayersModal,
                              borderRadius: BorderRadius.circular(9),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.92),
                                  borderRadius: BorderRadius.circular(9),
                                  border: Border.all(
                                    color: const Color(0xFFFED7AA)
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_rounded,
                                      size: 14,
                                      color: score.activeLayers >= 3
                                          ? const Color(0xFF059669)
                                          : const Color(0xFFD97706),
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        '${score.activeLayers} dari ${score.totalLayers} lapis keamanan aktif',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF334155),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Section Header: PENGATURAN & VERIFIKASI
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'PENGATURAN & VERIFIKASI',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: _slate400,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Prioritas Akun',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFEA580C),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      // Row 1: Verifikasi Akun
                      _SecuritySettingTile(
                        iconBg: _overview.user.phoneVerified
                            ? const Color(0xFFECFDF5)
                            : const Color(0xFFFFFBEB),
                        iconColor: _overview.user.phoneVerified
                            ? const Color(0xFF059669)
                            : const Color(0xFFD97706),
                        icon: Icons.verified_user_outlined,
                        title: 'Verifikasi Akun',
                        subtitle: _overview.user.phoneVerified
                            ? 'Nomor telepon terverifikasi'
                            : 'Nomor telepon belum terverifikasi',
                        onTap: () => _switchScreen(2),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _overview.user.phoneVerified
                                    ? const Color(0xFFECFDF5)
                                    : const Color(0xFFFFFBEB),
                                borderRadius: BorderRadius.circular(99),
                                border: Border.all(
                                  color: _overview.user.phoneVerified
                                      ? const Color(0xFFA7F3D0)
                                      : const Color(0xFFFDE68A),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _overview.user.phoneVerified
                                        ? Icons.check_rounded
                                        : Icons.priority_high_rounded,
                                    size: 12,
                                    color: _overview.user.phoneVerified
                                        ? const Color(0xFF059669)
                                        : const Color(0xFFD97706),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    _overview.user.phoneVerified
                                        ? 'Aktif'
                                        : 'Belum',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      color: _overview.user.phoneVerified
                                          ? const Color(0xFF059669)
                                          : const Color(0xFFD97706),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: _slate400,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                      const _DividerLine(),

                      // Row 2: Ubah PIN Transaksi
                      _SecuritySettingTile(
                        iconBg: const Color(0xFFFFF7ED),
                        iconColor: const Color(0xFFEA580C),
                        icon: Icons.lock_outline_rounded,
                        title: _overview.pin.hasPin
                            ? 'Ubah PIN Transaksi'
                            : 'Buat PIN Transaksi',
                        subtitle: _overview.pin.updatedHuman,
                        onTap: () => _switchScreen(1),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () => _switchScreen(1),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF7ED),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFFFED7AA),
                                  ),
                                ),
                                child: Text(
                                  _overview.pin.hasPin ? 'Ubah' : 'Atur',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFEA580C),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: _slate400,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                      const _DividerLine(),

                      // Row 3: Masuk dengan Biometrik
                      _SecuritySettingTile(
                        iconBg: const Color(0xFFEFF6FF),
                        iconColor: const Color(0xFF2563EB),
                        icon: Icons.fingerprint_rounded,
                        titleWidget: Row(
                          children: [
                            const Flexible(
                              child: Text(
                                'Masuk dengan Biometrik',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: _slate800,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: _showBiometricDetailModal,
                              child: const Text(
                                'Detail',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: 'Sidik jari / Face ID',
                        trailing: SizedBox(
                          height: 28,
                          child: Switch.adaptive(
                            value: _overview.preferences.biometricEnabled,
                            activeThumbColor: Colors.white,
                            activeTrackColor: _primaryOrange,
                            inactiveThumbColor: Colors.white,
                            inactiveTrackColor: const Color(0xFFCBD5E1),
                            onChanged: _busyPreference
                                ? null
                                : (val) => _toggleBiometric(val),
                          ),
                        ),
                      ),
                      const _DividerLine(),

                      // Row 4: Perangkat Tepercaya
                      _SecuritySettingTile(
                        iconBg: const Color(0xFFFAF5FF),
                        iconColor: const Color(0xFF9333EA),
                        icon: Icons.smartphone_rounded,
                        title: 'Perangkat Tepercaya',
                        subtitle:
                            '${_overview.trustedDeviceCount} perangkat terdaftar aktif',
                        onTap: () => _switchScreen(3, devicesTab: 0),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                '${_overview.trustedDeviceCount} Aktif',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: _slate400,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                      const _DividerLine(),

                      // Row 5: Metode Login
                      _SecuritySettingTile(
                        iconBg: const Color(0xFFFFFBEB),
                        iconColor: const Color(0xFFD97706),
                        icon: Icons.vpn_key_outlined,
                        title: 'Metode Login',
                        subtitle: _overview.user.loginMethodSummary,
                        onTap: _showLoginMethodsModal,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: _slate400,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Section Header: AKTIVITAS KEAMANAN
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'AKTIVITAS KEAMANAN',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: _slate400,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _switchScreen(3, devicesTab: 1),
                        child: const Text(
                          'Riwayat Lengkap',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFEA580C),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      _SecuritySettingTile(
                        iconBg: const Color(0xFFF1F5F9),
                        iconColor: const Color(0xFF475569),
                        icon: Icons.schedule_rounded,
                        title: 'Riwayat Aktivitas Login',
                        subtitle: _overview.latestLogin.summary,
                        onTap: () => _switchScreen(3, devicesTab: 1),
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          color: _slate400,
                          size: 18,
                        ),
                      ),
                      const _DividerLine(),
                      _SecuritySettingTile(
                        iconBg: const Color(0xFFF0F9FF),
                        iconColor: const Color(0xFF0284C7),
                        icon: Icons.notifications_none_rounded,
                        title: 'Notifikasi Keamanan',
                        subtitle: _overview.preferences.securityAlertsEnabled
                            ? 'Peringatan perangkat & sesi baru aktif'
                            : 'Peringatan perangkat & sesi baru nonaktif',
                        onTap: () => _toggleSecurityAlerts(
                          !_overview.preferences.securityAlertsEnabled,
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _overview.preferences.securityAlertsEnabled
                                ? const Color(0xFFECFDF5)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            _overview.preferences.securityAlertsEnabled
                                ? 'Aktif'
                                : 'Nonaktif',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: _overview.preferences.securityAlertsEnabled
                                  ? const Color(0xFF059669)
                                  : _slate500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                // Logout All Other Devices
                OutlinedButton.icon(
                  onPressed:
                      _revokingAll ? null : _confirmRevokeOtherDevices,
                  icon: _revokingAll
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFEA580C),
                          ),
                        )
                      : const Icon(Icons.logout_rounded, size: 17),
                  label: const Text(
                    'Keluar dari Semua Perangkat',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEA580C),
                    side: const BorderSide(color: _primaryOrange, width: 1.4),
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tindakan ini akan mengakhiri semua sesi login aktif kecuali di ponsel ini.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: _slate400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SecuritySettingTile extends StatelessWidget {
  final Color iconBg;
  final Color iconColor;
  final IconData icon;
  final String? title;
  final Widget? titleWidget;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  const _SecuritySettingTile({
    required this.iconBg,
    required this.iconColor,
    required this.icon,
    this.title,
    this.titleWidget,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  titleWidget ??
                      Text(
                        title ?? '',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _DividerLine extends StatelessWidget {
  const _DividerLine();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      color: Color(0xFFF1F5F9),
    );
  }
}

class _DetailInfoTile extends StatelessWidget {
  final String label;
  final String value;

  const _DetailInfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }
}
