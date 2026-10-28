import 'dart:async';
import 'package:flutter/material.dart';
import 'package:city_courierapp/screens/home_screen.dart';
import 'package:city_courierapp/screens/widgets/landing/landing_widgets.dart';
import 'package:city_courierapp/services/api_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

enum LoginStep { phone, otp }

class LoginView extends StatefulWidget {
  final VoidCallback onBackToLanding;

  const LoginView({
    super.key,
    required this.onBackToLanding,
  });

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  LoginStep _currentStep = LoginStep.phone;
  int _timerValue = 0;
  Timer? _countdownTimer;
  bool _isLoading = false;

  final TextEditingController _phoneController = TextEditingController();
  final List<TextEditingController> _otpControllers =
      List.generate(4, (_) => TextEditingController());
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
    String phone = _phoneController.text.trim();
    if (phone.isEmpty) return;

    try {
      final result = await ApiService.requestOtp(phone);
      if (result != null && result['success'] == true) {
        _startTimer();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('OTP baru telah dikirim ke WhatsApp Anda')),
          );
        }
      } else {
        throw result?['message'] ?? 'Gagal mengirim ulang OTP.';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
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
    String phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan nomor HP Anda')),
      );
      return;
    }

    // Basic phone validation
    if (phone.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nomor HP minimal 10 digit')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Call Laravel backend to send WhatsApp OTP via Fonnte
      final result = await ApiService.requestOtp(phone);
      
      if (result != null && result['success'] == true) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _currentStep = LoginStep.otp;
            _startTimer();
          });
        }
      } else {
        throw result?['message'] ?? 'Gagal mengirim OTP. Pastikan nomor HP benar.';
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  Future<void> _signInWithPhoneNumber() async {
    String smsCode = _otpControllers.map((c) => c.text).join();
    if (smsCode.length != 4) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan 4 digit kode OTP')),
      );
      return;
    }
    
    setState(() => _isLoading = true);

    try {
      // Verify OTP with Laravel backend
      final result = await ApiService.verifyOtp(_phoneController.text.trim(), smsCode);
      
      if (result != null) {
        if (mounted) {
          // Check user role and navigate accordingly
          final role = result['user']?['role'] ?? 'customer';
          
          if (role == 'courier') {
            // Navigate to courier/driver home screen
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
              (route) => false,
            );
          } else {
            // Navigate to customer home screen
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
              (route) => false,
            );
          }
        }
      } else {
        throw 'Kode OTP salah atau sudah kadaluarsa.';
      }
    } catch (e) {
      setState(() => _isLoading = false);
      // Clear OTP fields on error
      for (var controller in _otpControllers) {
        controller.clear();
      }
      _otpFocusNodes[0].requestFocus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    try {
      setState(() => _isLoading = true);

      // 1. Trigger Google Sign-In
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      // 2. Authenticate with Firebase
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final String? idToken = await userCredential.user?.getIdToken();

      if (idToken != null) {
        // 3. Send ID Token and Photo URL to Laravel Backend
        bool success = await ApiService.loginWithGoogle(
          idToken,
          photoUrl: userCredential.user?.photoURL,
        );
        
        if (success) {
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
              (route) => false,
            );
          }
        } else {
          throw 'Gagal autentikasi dengan server backend.';
        }
      } else {
        throw 'Gagal mendapatkan token dari Firebase.';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terjadi kesalahan: $e')),
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
                  _currentStep == LoginStep.phone ? 'Masuk ke Akun' : 'Verifikasi OTP',
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
              'Masukkan nomor HP Anda untuk menerima kode verifikasi OTP.',
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
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
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
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.account_circle, color: Colors.blue, size: 20),
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
                    text: _phoneController.text.isNotEmpty ? 
                          _phoneController.text.replaceRange(4, 8, '****') : 
                          '0812****890',
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
                      onTap: _resendOtp,
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
