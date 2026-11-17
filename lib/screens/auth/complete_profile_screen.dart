import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:city_courierapp/screens/home_screen.dart';
import 'package:city_courierapp/screens/landing_screen.dart';
import 'package:city_courierapp/services/api_service.dart';

/// Halaman wajib setelah registrasi/login Google bila profil belum lengkap.
///
/// Nama dan email berasal dari Google (email tidak dapat diubah). Nomor
/// telepon hanya dianggap valid setelah backend memverifikasi kode OTP.
class CompleteProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const CompleteProfileScreen({super.key, required this.userData});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  static const Color _primary = Color(0xFFEC5B13);
  static const Color _bgLight = Color(0xFFF8F9FB);
  static const Color _slate400 = Color(0xFF94A3B8);
  static const Color _slate500 = Color(0xFF64748B);
  static const Color _slate700 = Color(0xFF334155);
  static const Color _slate800 = Color(0xFF1E293B);

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _phoneController;
  late final TextEditingController _otpController;

  Timer? _cooldownTimer;
  int _cooldown = 0;
  bool _otpSent = false;
  bool _phoneVerified = false;
  bool _isSendingOtp = false;
  bool _isVerifying = false;
  String _lastOtpPhone = '';

  String _email = '';
  String _photoUrl = '';

  static String _sanitizeInitialName(String raw) {
    final trimmed = raw.trim();
    if (trimmed == 'Google User' || trimmed.startsWith('User ')) {
      return '';
    }
    return trimmed;
  }

  @override
  void initState() {
    super.initState();
    _email = (widget.userData['email'] ?? '').toString();
    _photoUrl = (widget.userData['photo_url'] ?? '').toString();
    _nameController = TextEditingController(
      text: _sanitizeInitialName((widget.userData['name'] ?? '').toString()),
    );
    _addressController = TextEditingController(
      text: (widget.userData['address'] ?? '').toString(),
    );
    _phoneController = TextEditingController(
      text: (widget.userData['phone'] ?? '').toString(),
    );
    _otpController = TextEditingController();
    _phoneVerified = widget.userData['phone_verified'] == true;

    _nameController.addListener(_onNameChanged);
    _phoneController.addListener(_onPhoneChanged);

    if (_email.isEmpty || _nameController.text.isEmpty) {
      _syncLatestProfile();
    }
  }

  void _onNameChanged() {
    if (mounted) setState(() {});
  }

  void _onPhoneChanged() {
    if (_otpSent && _normalizePhone(_phoneController.text) != _lastOtpPhone) {
      setState(() {
        _otpSent = false;
        _otpController.clear();
      });
    }
  }

  Future<void> _syncLatestProfile() async {
    try {
      final profile = await ApiService.getProfile();
      if (!mounted || profile == null) return;
      final user = profile['user'];
      if (user is! Map) return;

      setState(() {
        if (_email.isEmpty) {
          _email = (user['email'] ?? '').toString();
        }
        if (_photoUrl.isEmpty) {
          _photoUrl = (user['photo_url'] ?? '').toString();
        }
        if (_nameController.text.trim().isEmpty) {
          _nameController.text = _sanitizeInitialName(
            (user['name'] ?? '').toString(),
          );
        }
        if (_addressController.text.trim().isEmpty) {
          _addressController.text = (user['address'] ?? '').toString();
        }
        if (_phoneController.text.trim().isEmpty) {
          _phoneController.text = (user['phone'] ?? '').toString();
        }
        if (profile['phone_verified'] == true || user['phone_verified'] == true) {
          _phoneVerified = true;
        }
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _nameController.removeListener(_onNameChanged);
    _phoneController.removeListener(_onPhoneChanged);
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? const Color(0xFFDC2626) : _slate800,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  void _startCooldown(int seconds) {
    _cooldownTimer?.cancel();
    final duration = seconds <= 0 ? 60 : seconds;

    if (!mounted) return;
    setState(() => _cooldown = duration);

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_cooldown <= 1) {
        timer.cancel();
        setState(() => _cooldown = 0);
      } else {
        setState(() => _cooldown--);
      }
    });
  }

  /// Normalisasi ringan untuk validasi tampilan. Backend tetap melakukan
  /// normalisasi dan validasi final.
  String _normalizePhone(String value) {
    var digits = value.replaceAll(RegExp(r'\D'), '');

    if (digits.startsWith('0062')) {
      digits = '0${digits.substring(4)}';
    } else if (digits.startsWith('62')) {
      digits = '0${digits.substring(2)}';
    }

    return digits;
  }

  String? _validatePhone(String? value) {
    final normalized = _normalizePhone(value ?? '');

    if (normalized.isEmpty) {
      return 'Nomor telepon wajib diisi.';
    }

    if (!RegExp(r'^08[0-9]{8,11}$').hasMatch(normalized)) {
      return 'Masukkan nomor HP Indonesia yang valid, contoh 081234567890.';
    }

    return null;
  }

  Future<bool> _saveProfileDetails({bool silent = false}) async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return false;
    }

    final result = await ApiService.updateProfileResult(
      name: _nameController.text.trim(),
      address: _addressController.text.trim(),
    );

    if (result['success'] != true && !silent) {
      _showMessage(
        (result['message'] ?? 'Gagal menyimpan data diri.').toString(),
        isError: true,
      );
    }

    return result['success'] == true;
  }

  Future<void> _requestOtp() async {
    if (_isSendingOtp || _isVerifying || _cooldown > 0) return;

    final phoneError = _validatePhone(_phoneController.text);
    if (phoneError != null) {
      _showMessage(phoneError, isError: true);
      return;
    }

    setState(() => _isSendingOtp = true);

    try {
      final result = await ApiService.requestPhoneOtp(
        _phoneController.text.trim(),
      );

      if (!mounted) return;

      if (result['success'] == true) {
        final alreadyVerified = result['already_verified'] == true;

        setState(() {
          _lastOtpPhone = _normalizePhone(_phoneController.text);
          _otpSent = !alreadyVerified;
          _phoneVerified = alreadyVerified;
          _isSendingOtp = false;
        });

        _startCooldown((result['retry_after'] as num?)?.toInt() ?? 60);

        _showMessage(
          (result['message'] ?? 'Kode OTP telah dikirim ke nomor telepon Anda.')
              .toString(),
        );
        return;
      }

      final retryAfter = (result['retry_after'] as num?)?.toInt();
      if (retryAfter != null && retryAfter > 0) {
        _startCooldown(retryAfter);
      }

      setState(() => _isSendingOtp = false);
      _showMessage(
        (result['message'] ?? 'Gagal mengirim kode OTP.').toString(),
        isError: true,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSendingOtp = false);
      _showMessage(
        'Tidak dapat terhubung ke server. Silakan coba lagi.',
        isError: true,
      );
    }
  }

  Future<void> _verifyOtp() async {
    if (_isVerifying || _isSendingOtp) return;

    final phoneError = _validatePhone(_phoneController.text);
    if (phoneError != null) {
      _showMessage(phoneError, isError: true);
      return;
    }

    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      _showMessage('Masukkan 6 digit kode OTP.', isError: true);
      return;
    }

    setState(() => _isVerifying = true);

    try {
      // Pastikan nama/alamat tersimpan sebelum status profil dicek backend.
      final saved = await _saveProfileDetails(silent: true);
      if (!mounted) return;

      if (!saved) {
        setState(() => _isVerifying = false);
        _showMessage(
          'Gagal menyimpan data diri. Silakan coba lagi.',
          isError: true,
        );
        return;
      }

      final result = await ApiService.verifyPhoneOtp(
        _phoneController.text.trim(),
        otp,
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
      );

      if (!mounted) return;

      if (result['success'] == true) {
        setState(() {
          _phoneVerified = true;
          _otpSent = false;
          _isVerifying = false;
        });

        _showMessage(
          (result['message'] ?? 'Nomor telepon berhasil diverifikasi.')
              .toString(),
        );

        // Beri kesempatan pesan sukses terlihat sebelum berpindah halaman.
        await Future<void>.delayed(const Duration(milliseconds: 700));
        if (!mounted) return;
        _goHome();
        return;
      }

      setState(() => _isVerifying = false);

      if (result['code'] == 'OTP_TOO_MANY' || result['code'] == 'OTP_EXPIRED') {
        _otpController.clear();
      }

      _showMessage(
        (result['message'] ??
                'Kode OTP yang Anda masukkan salah. Silakan coba lagi.')
            .toString(),
        isError: true,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isVerifying = false);
      _showMessage(
        'Tidak dapat terhubung ke server. Silakan coba lagi.',
        isError: true,
      );
    }
  }

  /// Dipakai saat nomor sudah terverifikasi tetapi profil masih belum lengkap
  /// (misalnya nama masih kosong).
  Future<void> _continueWithVerifiedPhone() async {
    if (_isVerifying || _isSendingOtp) return;

    final phoneError = _validatePhone(_phoneController.text);
    if (phoneError != null) {
      _showMessage(phoneError, isError: true);
      return;
    }

    setState(() => _isVerifying = true);

    try {
      final saved = await _saveProfileDetails(silent: true);
      if (!mounted) return;

      if (!saved) {
        setState(() => _isVerifying = false);
        _showMessage(
          'Gagal menyimpan data diri. Silakan coba lagi.',
          isError: true,
        );
        return;
      }

      final profile = await ApiService.getProfile();
      if (!mounted) return;

      setState(() => _isVerifying = false);

      if (profile != null && profile['profile_completed'] == true) {
        _goHome();
      } else {
        _showMessage(
          'Masih ada data wajib yang belum lengkap. Silakan periksa kembali.',
          isError: true,
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isVerifying = false);
      _showMessage(
        'Tidak dapat terhubung ke server. Silakan coba lagi.',
        isError: true,
      );
    }
  }

  void _goHome() {
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Keluar dari akun?'),
        content: const Text(
          'Data diri yang belum lengkap tidak akan tersimpan. '
          'Anda dapat masuk kembali kapan saja.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: _primary),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await ApiService.logout();
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LandingScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_isVerifying) {
          _handleLogout();
        }
      },
      child: Scaffold(
        backgroundColor: _bgLight,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          automaticallyImplyLeading: false,
          title: const Text(
            'Lengkapi Data Diri',
            style: TextStyle(
              color: _slate800,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          actions: [
            IconButton(
              onPressed: _isVerifying ? null : _handleLogout,
              tooltip: 'Keluar',
              icon: const Icon(
                Icons.logout_rounded,
                color: _slate500,
                size: 22,
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sedikit lagi!',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: _slate800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Lengkapi data diri dan verifikasi nomor telepon untuk '
                    'menggunakan seluruh layanan City Courier.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: _slate500,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildGoogleCard(),
                  const SizedBox(height: 24),
                  _buildSectionLabel('DATA DIRI'),
                  const SizedBox(height: 12),
                  _buildNameField(),
                  const SizedBox(height: 16),
                  _buildEmailField(),
                  const SizedBox(height: 16),
                  _buildAddressField(),
                  const SizedBox(height: 28),
                  _buildSectionLabel('VERIFIKASI NOMOR TELEPON'),
                  const SizedBox(height: 12),
                  _buildPhoneField(),
                  const SizedBox(height: 12),
                  if (_phoneVerified)
                    _buildVerifiedBanner()
                  else
                    _buildOtpArea(),
                  const SizedBox(height: 24),
                  _buildSecurityNote(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleCard() {
    final initial =
        (_nameController.text.trim().isNotEmpty
                ? _nameController.text.trim()
                : 'U')
            .substring(0, 1)
            .toUpperCase();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF7ED), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFEDD5)),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFEDD5),
              border: Border.all(color: Colors.white, width: 2),
            ),
            clipBehavior: Clip.antiAlias,
            child: _photoUrl.isNotEmpty
                ? Image.network(
                    _photoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Center(
                      child: Text(
                        initial,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _primary,
                        ),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      initial,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _primary,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _nameController.text.trim().isEmpty
                      ? 'Pengguna Google'
                      : _nameController.text.trim(),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _slate800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(
                      Icons.lock_outline_rounded,
                      size: 13,
                      color: _slate400,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _email.isEmpty ? 'Email Google' : _email,
                        style: const TextStyle(fontSize: 12, color: _slate500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFFEDD5)),
            ),
            child: const Row(
              children: [
                Icon(Icons.verified_user_outlined, size: 12, color: _primary),
                SizedBox(width: 4),
                Text(
                  'Google',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: _slate500,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildNameField() {
    return _buildTextField(
      label: 'Nama Lengkap',
      controller: _nameController,
      hint: 'Masukkan nama lengkap',
      icon: Icons.person_outline_rounded,
      textCapitalization: TextCapitalization.words,
      validator: (value) {
        final trimmed = (value ?? '').trim();
        if (trimmed.isEmpty) {
          return 'Nama lengkap wajib diisi.';
        }
        if (trimmed == 'Google User' || trimmed.startsWith('User ')) {
          return 'Silakan masukkan nama lengkap asli Anda.';
        }
        return null;
      },
    );
  }

  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Email',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _slate700,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.mail_outline_rounded,
                size: 20,
                color: _slate400,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _email.isEmpty ? '-' : _email,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _slate500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(
                Icons.lock_outline_rounded,
                size: 16,
                color: _slate400,
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Email dari akun Google tidak dapat diubah.',
          style: TextStyle(fontSize: 11, color: _slate400),
        ),
      ],
    );
  }

  Widget _buildAddressField() {
    return _buildTextField(
      label: 'Alamat (opsional)',
      controller: _addressController,
      hint: 'Masukkan alamat pengiriman utama',
      icon: Icons.location_on_outlined,
      maxLines: 2,
      textCapitalization: TextCapitalization.sentences,
    );
  }

  Widget _buildPhoneField() {
    return _buildTextField(
      label: 'Nomor Telepon / WhatsApp',
      controller: _phoneController,
      hint: 'Contoh: 081234567890',
      icon: Icons.phone_outlined,
      keyboardType: TextInputType.phone,
      readOnly: _phoneVerified,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s\-]')),
        LengthLimitingTextInputFormatter(18),
      ],
      validator: _validatePhone,
    );
  }

  Widget _buildOtpArea() {
    if (!_otpSent) {
      return SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: (_isSendingOtp || _isVerifying || _cooldown > 0)
              ? null
              : _requestOtp,
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFFFED7AA),
            disabledForegroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: _isSendingOtp
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  _cooldown > 0 ? 'Kirim OTP dalam ${_cooldown}s' : 'Kirim OTP',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(
          label: 'Kode OTP',
          controller: _otpController,
          hint: 'Masukkan 6 digit kode OTP',
          icon: Icons.password_rounded,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Icon(Icons.info_outline_rounded, size: 14, color: _slate400),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'Kode berlaku 5 menit dan hanya dapat digunakan sekali.',
                style: TextStyle(fontSize: 11, color: _slate400),
              ),
            ),
            TextButton(
              onPressed: (_cooldown > 0 || _isSendingOtp || _isVerifying)
                  ? null
                  : _requestOtp,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                _cooldown > 0 ? 'Kirim ulang (${_cooldown}s)' : 'Kirim ulang',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: (_isVerifying || _isSendingOtp) ? null : _verifyOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFFFED7AA),
              disabledForegroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _isVerifying
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Verifikasi & Simpan',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildVerifiedBanner() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFA7F3D0)),
          ),
          child: const Row(
            children: [
              Icon(Icons.verified_rounded, size: 20, color: Color(0xFF059669)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Nomor telepon sudah terverifikasi.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF047857),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: (_isVerifying || _isSendingOtp)
                ? null
                : _continueWithVerifiedPhone,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFFFED7AA),
              disabledForegroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _isVerifying
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Lanjutkan ke Beranda',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, size: 18, color: _slate400),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Nomor telepon diverifikasi langsung oleh server City Courier. '
              'Kode OTP tidak pernah disimpan dalam bentuk teks biasa.',
              style: TextStyle(fontSize: 11, height: 1.5, color: _slate500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    int maxLines = 1,
    bool readOnly = false,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _slate700,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: readOnly ? const Color(0xFFF1F5F9) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              if (!readOnly)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            readOnly: readOnly,
            keyboardType: keyboardType,
            textCapitalization: textCapitalization,
            maxLines: maxLines,
            inputFormatters: inputFormatters,
            validator: validator,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: readOnly ? _slate500 : _slate800,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                fontSize: 13,
                color: _slate400,
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: Icon(icon, size: 20, color: _slate400),
              suffixIcon: readOnly
                  ? const Icon(
                      Icons.lock_outline_rounded,
                      size: 16,
                      color: _slate400,
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _primary, width: 1.4),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFDC2626)),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: Color(0xFFDC2626),
                  width: 1.4,
                ),
              ),
              filled: true,
              fillColor: Colors.transparent,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 15,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
