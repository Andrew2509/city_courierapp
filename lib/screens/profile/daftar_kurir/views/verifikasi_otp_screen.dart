import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/daftar_kurir_components.dart';
import '../widgets/daftar_kurir_constants.dart';
import 'pilih_kota_screen.dart';

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

  bool get _isOtpComplete {
    return _controllers.every((controller) => controller.text.isNotEmpty);
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScreenLayout(
      title: 'Verifikasi',
      currentStep: 1, // Using 1 for Data Diri step based on Stitch
      totalSteps: 4,
      bottomAction: PrimaryButton(
        text: 'Verifikasi',
        onPressed: _isOtpComplete
            ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PilihKotaScreen(),
                  ),
                );
              }
            : null,
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
                  text: '+62 ${widget.phoneNumber}',
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
              text: const TextSpan(
                style: TextStyle(
                  fontSize: 14,
                  color: DaftarKurirColors.textMuted,
                ),
                children: [
                  TextSpan(text: 'Belum menerima kode? '),
                  TextSpan(
                    text: 'Kirim ulang kode ',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: DaftarKurirColors.primary,
                    ),
                  ),
                  TextSpan(
                    text: '(00:59)',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: DaftarKurirColors.primary,
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
