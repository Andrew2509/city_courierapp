import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:city_courierapp/services/courier/courier_registration_service.dart';
import '../widgets/daftar_kurir_components.dart';
import '../widgets/daftar_kurir_constants.dart';
import '../daftar_kurir_data.dart';
import 'pilih_area_screen.dart';

class VerifikasiOtpScreen extends StatefulWidget {
  final String phoneNumber;

  const VerifikasiOtpScreen({
    super.key,
    required this.phoneNumber,
  });

  @override
  State<VerifikasiOtpScreen> createState() => _VerifikasiOtpScreenState();
}

class _VerifikasiOtpScreenState extends State<VerifikasiOtpScreen> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (index) => TextEditingController(),
  );

  final List<FocusNode> _focusNodes = List.generate(
    6,
    (index) => FocusNode(),
  );

  bool _isVerifying = false;
  int _resendSeconds = 60;
  Timer? _resendTimer;

  bool get _isOtpComplete {
    return _controllers.every((controller) => controller.text.isNotEmpty);
  }

  String get _otpCode =>
      _controllers.map((controller) => controller.text).join();

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String get _formattedTimer {
    final minutes = (_resendSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_resendSeconds % 60).toString().padLeft(2, '0');
    return '($minutes:$seconds)';
  }

  Future<void> _resendOtp() async {
    if (_resendSeconds > 0) return;

    final result = await CourierRegistrationService.requestPhoneOtp(
      widget.phoneNumber,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      _showMessage('Kode verifikasi telah dikirim ulang ke WhatsApp.');
      _startResendTimer();
    } else {
      _showMessage(result['message']?.toString() ?? 'Gagal mengirim ulang kode.');
    }
  }

  Future<void> _verifyOtp() async {
    if (!_isOtpComplete) return;

    setState(() => _isVerifying = true);

    final result = await CourierRegistrationService.verifyPhoneOtp(
      widget.phoneNumber,
      _otpCode,
    );

    if (!mounted) return;
    setState(() => _isVerifying = false);

    if (result['success'] == true) {
      context.read<DaftarKurirData>().phone = widget.phoneNumber;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const PilihAreaScreen(),
        ),
      );
    } else {
      _showMessage(result['message']?.toString() ?? 'Kode OTP salah.');
      for (var controller in _controllers) {
        controller.clear();
      }
      _focusNodes.first.requestFocus();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenLayout(
      title: 'Verifikasi',
      currentStep: 1, // Using 1 for Data Diri step based on Stitch
      totalSteps: 4,
      bottomAction: PrimaryButton(
        text: 'Verifikasi',
        isLoading: _isVerifying,
        onPressed: _isOtpComplete ? _verifyOtp : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'Masukkan Kode OTP',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: DaftarKurirColors.textDark,
              height: 1.25,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: const TextStyle(
                fontSize: 16,
                color: DaftarKurirColors.textMuted,
                height: 1.5,
              ),
              children: [
                const TextSpan(text: 'Kode verifikasi telah dikirimkan melalui WhatsApp ke\n'),
                TextSpan(
                  text: '+${widget.phoneNumber}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: DaftarKurirColors.textDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              6,
              (index) => Container(
                width: 48,
                height: 56,
                margin: EdgeInsets.only(right: index == 5 ? 0 : (index == 2 ? 16.0 : 8.0)),
                child: TextField(
                  controller: _controllers[index],
                  focusNode: _focusNodes[index],
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(1),
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: DaftarKurirColors.textDark,
                  ),
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: DaftarKurirColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: DaftarKurirColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: DaftarKurirColors.primary, width: 1),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (value) {
                    if (value.isNotEmpty && index < 5) {
                      _focusNodes[index + 1].requestFocus();
                    }
                    if (value.isEmpty && index > 0) {
                      _focusNodes[index - 1].requestFocus();
                    }
                    setState(() {});
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Center(
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 14,
                  color: DaftarKurirColors.textMuted,
                ),
                children: [
                  const TextSpan(text: 'Belum menerima kode? '),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: GestureDetector(
                      onTap: _resendSeconds == 0 ? _resendOtp : null,
                      child: Text(
                        'Kirim ulang kode ',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _resendSeconds == 0
                              ? DaftarKurirColors.primary
                              : DaftarKurirColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                  TextSpan(
                    text: _formattedTimer,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _resendSeconds == 0
                          ? DaftarKurirColors.primary
                          : DaftarKurirColors.textMuted,
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
