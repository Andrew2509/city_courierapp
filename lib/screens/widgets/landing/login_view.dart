import 'dart:async';
import 'package:flutter/material.dart';
import 'package:city_courierapp/screens/auth/complete_profile_screen.dart';
import 'package:city_courierapp/screens/home_screen.dart';
import 'package:city_courierapp/screens/widgets/landing/landing_widgets.dart';
import 'package:city_courierapp/services/api_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

enum LoginStep { phone, otp }

/// Pesan validasi ketika nomor belum terdaftar melalui Google.
const String kPhoneNotRegisteredMessage =
    'Nomor telepon belum terdaftar. Silakan gunakan nomor telepon yang sudah '
    'terdaftar melalui Google. Jika belum memiliki akun, silakan daftar '
    'terlebih dahulu menggunakan Google.';

class LoginView extends StatefulWidget {
  final VoidCallback onBackToLanding;

  const LoginView({super.key, required this.onBackToLanding});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  LoginStep _currentStep = LoginStep.phone;
  int _timerValue = 0;
  Timer? _countdownTimer;
  bool _isLoading = false;

  final TextEditingController _phoneController = TextEditingController();
  final List<TextEditingController> _otpControllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _otpFocusNodes = List.generate(4, (_) => FocusNode());

  @override
  void dispose() {
    _stopTimer();
    _phoneController.dispose();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _otpFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    setState(() => _timerValue = 30);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerValue > 0) {
        setState(() => _timerValue--);
      } else {
        _stopTimer();
      }
    });
  }

  void _stopTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  Future<void> _resendOtp() async {
    if (_isLoading) return;

    String phone = _phoneController.text.trim();
    if (phone.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final result = await ApiService.requestOtp(phone);
      if (!mounted) return;

      setState(() => _isLoading = false);

      if (result['success'] == true) {
        _startTimer();
        _showMessage('OTP baru telah dikirim ke WhatsApp Anda');
      } else {
        _showMessage(result['message'] ?? 'Gagal mengirim ulang OTP.');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage('Tidak dapat terhubung ke server. Silakan coba lagi.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _handleBack() {
    if (_currentStep == LoginStep.otp) {
      setState(() {
        _currentStep = LoginStep.phone;
        _stopTimer();
      });
    } else {
      widget.onBackToLanding();
    }
  }

  Future<void> _verifyPhoneNumber() async {
    if (_isLoading) return;

    String phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      _showMessage('Masukkan nomor HP Anda');
      return;
    }

    // Validasi dasar sebelum memanggil backend.
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) {
      _showMessage('Nomor HP minimal 10 digit');
      return;
    }
    if (digits.length > 15) {
      _showMessage('Nomor HP tidak valid');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Backend memvalidasi bahwa nomor sudah terdaftar melalui Google.
      final result = await ApiService.requestOtp(phone);
      if (!mounted) return;

      if (result['success'] == true) {
        setState(() {
          _isLoading = false;
          _currentStep = LoginStep.otp;
          _startTimer();
        });
        return;
      }

      setState(() => _isLoading = false);

      if (result['code'] == 'PHONE_NOT_REGISTERED') {
        await _showPhoneNotRegisteredSheet();
      } else {
        _showMessage(
          result['message'] ??
              'Gagal mengirim OTP. Periksa kembali nomor HP Anda.',
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage('Tidak dapat terhubung ke server. Silakan coba lagi.');
    }
  }

  Future<void> _signInWithPhoneNumber() async {
    if (_isLoading) return;

    String smsCode = _otpControllers.map((c) => c.text).join();
    if (smsCode.length != 4) {
      _showMessage('Masukkan 4 digit kode OTP');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Verify OTP with Laravel backend
      final result = await ApiService.verifyOtp(
        _phoneController.text.trim(),
        smsCode,
      );
      if (!mounted) return;

      if (result['success'] == true) {
        final user = result['user'] is Map
            ? Map<String, dynamic>.from(result['user'] as Map)
            : <String, dynamic>{};
        user['phone_verified'] ??= result['phone_verified'] == true;
        final requiresCompletion =
            result['requires_profile_completion'] == true ||
            result['profile_completed'] == false;

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => requiresCompletion
                ? CompleteProfileScreen(userData: user)
                : const HomeScreen(),
          ),
          (route) => false,
        );
        return;
      }

      setState(() => _isLoading = false);
      _clearOtpFields();

      if (result['code'] == 'PHONE_NOT_REGISTERED') {
        // Kembali ke langkah nomor agar pengguna bisa mendaftar via Google
        // atau mencoba nomor lain.
        setState(() {
          _currentStep = LoginStep.phone;
          _stopTimer();
        });
        await _showPhoneNotRegisteredSheet();
      } else {
        _showMessage(
          result['message'] ?? 'Kode OTP salah atau sudah kadaluarsa.',
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _clearOtpFields();
      _showMessage('Tidak dapat terhubung ke server. Silakan coba lagi.');
    }
  }

  void _clearOtpFields() {
    for (var controller in _otpControllers) {
      controller.clear();
    }
    _otpFocusNodes[0].requestFocus();
  }

  /// Tampilkan pesan bahwa nomor belum terdaftar melalui Google beserta
  /// pilihan untuk mendaftar lewat Google atau mencoba lagi.
  Future<void> _showPhoneNotRegisteredSheet() async {
    if (!mounted) return;

    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFF7ED),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_search_rounded,
                        color: Color(0xFFEA580C),
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Nomor Belum Terdaftar',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      kPhoneNotRegisteredMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6B7280),
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(sheetContext, 'google'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF97316),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.account_circle, size: 20),
                            SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                'Daftar dengan Google',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetContext, 'retry'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFEA580C),
                          side: const BorderSide(color: Color(0xFFFED7AA)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Coba Lagi',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    if (!mounted) return;

    if (action == 'google') {
      await _handleGoogleSignIn();
    }
    // 'retry' cukup menutup sheet; nomor tetap diisi agar pengguna bisa
    // memperbaiki format atau mencoba lagi tanpa mengetik ulang.
  }

  Future<void> _handleGoogleSignIn() async {
    if (_isLoading) return;

    try {
      setState(() => _isLoading = true);

      // 1. Trigger Google Sign-In
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // 2. Authenticate with Firebase
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);
      final String? idToken = await userCredential.user?.getIdToken();

      if (idToken != null) {
        // 3. Send ID Token to Laravel Backend
        final result = await ApiService.loginWithGoogle(
          idToken,
          photoUrl: userCredential.user?.photoURL,
        );

        if (result['success'] == true) {
          if (mounted) {
            final user = result['user'] is Map
                ? Map<String, dynamic>.from(result['user'] as Map)
                : <String, dynamic>{};
            user['phone_verified'] ??= result['phone_verified'] == true;
            final requiresCompletion =
                result['requires_profile_completion'] == true ||
                result['profile_completed'] != true ||
                result['phone_verified'] != true;

            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => requiresCompletion
                    ? CompleteProfileScreen(userData: user)
                    : const HomeScreen(),
              ),
              (route) => false,
            );
          }
        } else {
          if (mounted) {
            _showMessage(
              (result['message'] ??
                      'Gagal masuk dengan Google. Silakan coba lagi.')
                  .toString(),
            );
          }
        }
      } else {
        throw 'Gagal mendapatkan token dari Firebase.';
      }
    } catch (_) {
      // Jangan tampilkan detail teknis (stack trace / platform exception)
      // kepada pengguna.
      if (mounted) {
        _showMessage(
          'Gagal masuk dengan Google. Silakan coba lagi beberapa saat lagi.',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _handleBack,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.chevron_left_rounded,
                    color: Color(0xFFEA580C),
                    size: 24,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  _currentStep == LoginStep.phone
                      ? 'Masuk ke Akun'
                      : 'Verifikasi OTP',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_currentStep == LoginStep.phone) ...[
            Text(
              'Masukkan nomor HP yang sudah terdaftar melalui Google untuk '
              'menerima kode verifikasi OTP.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 24),
            LandingInputField(
              label: 'Nomor HP',
              hint: '0812xxxxxxx',
              icon: Icons.smartphone_rounded,
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              suffix: Padding(
                padding: const EdgeInsets.all(8.0),
                child: GestureDetector(
                  onTap: _isLoading ? null : _verifyPhoneNumber,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _isLoading ? Colors.grey : const Color(0xFFF97316),
                      shape: BoxShape.circle,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: Divider(color: Colors.grey[200])),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Atau masuk dengan',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[400],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: Colors.grey[200])),
              ],
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: _isLoading ? null : _handleGoogleSignIn,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                side: BorderSide(color: Colors.grey[200]!),
                backgroundColor: Colors.white,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.network(
                    'https://developers.google.com/identity/images/g-logo.png',
                    height: 20,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.account_circle,
                      color: Colors.blue,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      'Lanjutkan dengan Google',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                  height: 1.6,
                ),
                children: [
                  const TextSpan(text: 'Kode OTP telah dikirim ke nomor '),
                  TextSpan(
                    text: _phoneController.text.isNotEmpty
                        ? _phoneController.text.replaceRange(4, 8, '****')
                        : '0812****890',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(4, (index) {
                return SizedBox(
                  width: 60,
                  height: 64,
                  child: TextField(
                    controller: _otpControllers[index],
                    focusNode: _otpFocusNodes[index],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 1,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      contentPadding: EdgeInsets.zero,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFF3F4F6)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFF97316)),
                      ),
                    ),
                    onChanged: (value) {
                      if (value.isNotEmpty && index < 3) {
                        _otpFocusNodes[index + 1].requestFocus();
                      } else if (value.isEmpty && index > 0) {
                        _otpFocusNodes[index - 1].requestFocus();
                      }

                      // Auto-submit if all 4 digits filled
                      if (index == 3 && value.isNotEmpty) {
                        _signInWithPhoneNumber();
                      }
                    },
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),
            Center(
              child: _timerValue > 0
                  ? RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[400],
                        ),
                        children: [
                          const TextSpan(text: 'Kirim ulang dalam '),
                          TextSpan(
                            text: '$_timerValue detik',
                            style: const TextStyle(
                              color: Color(0xFFEA580C),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )
                  : GestureDetector(
                      onTap: _isLoading ? null : _resendOtp,
                      child: Text(
                        'Kirim Ulang Kode',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFEA580C),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 24),
            LandingPrimaryButton(
              title: _isLoading ? 'Memverifikasi...' : 'Verifikasi & Masuk',
              onTap: _isLoading ? () {} : _signInWithPhoneNumber,
            ),
          ],
          const SizedBox(height: 32),
          Center(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[400],
                ),
                children: [
                  const TextSpan(text: 'Butuh bantuan? '),
                  TextSpan(
                    text: 'Hubungi Kami',
                    style: const TextStyle(
                      color: Color(0xFFEA580C),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
