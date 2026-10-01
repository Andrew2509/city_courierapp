import 'package:flutter/material.dart';
import '../widgets/daftar_kurir_components.dart';
import '../widgets/daftar_kurir_constants.dart';
import 'verifikasi_otp_screen.dart';

class NomorHpScreen extends StatefulWidget {
  const NomorHpScreen({super.key});

  @override
  State<NomorHpScreen> createState() => _NomorHpScreenState();
}

class _NomorHpScreenState extends State<NomorHpScreen> {
  bool _isAgreed = false;
  final TextEditingController _phoneController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScreenLayout(
      title: 'Nomor HP',
      currentStep: 1, // Using 1 for now based on typical onboarding flows
      totalSteps: 4,
      bottomAction: PrimaryButton(
        text: 'Lanjutkan',
        onPressed: _isAgreed && _phoneController.text.isNotEmpty
            ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VerifikasiOtpScreen(
                      phoneNumber: _phoneController.text,
                    ),
                  ),
                );
              }
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Masukkan Nomor HP',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: DaftarKurirColors.textDark,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Kami akan mengirimkan kode OTP untuk verifikasi',
            style: TextStyle(
              fontSize: 16,
              color: DaftarKurirColors.textMuted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Nomor Handphone',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: DaftarKurirColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: DaftarKurirColors.border),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(
                    color: DaftarKurirColors.bgLight,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(8),
                      bottomLeft: Radius.circular(8),
                    ),
                    border: Border(
                      right: BorderSide(color: DaftarKurirColors.border),
                    ),
                  ),
                  child: const Text(
                    '+62',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: DaftarKurirColors.textDark,
                    ),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(
                      fontSize: 16,
                      color: DaftarKurirColors.textDark,
                    ),
                    onChanged: (value) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: '812 3456 7890',
                      hintStyle: TextStyle(
                        fontWeight: FontWeight.w400,
                        color: DaftarKurirColors.textMuted,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Pastikan nomor aktif untuk menerima SMS.',
            style: TextStyle(
              fontSize: 12,
              color: DaftarKurirColors.textMuted,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: _isAgreed,
                  activeColor: DaftarKurirColors.primary,
                  onChanged: (value) {
                    setState(() {
                      _isAgreed = value ?? false;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: RichText(
                  text: const TextSpan(
                    style: TextStyle(
                      fontSize: 14,
                      color: DaftarKurirColors.textDark,
                      height: 1.5,
                    ),
                    children: [
                      TextSpan(text: 'Saya menyetujui '),
                      TextSpan(
                        text: 'Syarat & Ketentuan',
                        style: TextStyle(
                          color: DaftarKurirColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      TextSpan(text: ' serta '),
                      TextSpan(
                        text: 'Kebijakan Privasi',
                        style: TextStyle(
                          color: DaftarKurirColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      TextSpan(text: ' yang berlaku.'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
