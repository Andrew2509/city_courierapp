import 'package:flutter/material.dart';
import 'package:city_courierapp/screens/home_screen.dart';
import 'package:city_courierapp/screens/home/tracking/tracking_screen.dart';
import 'package:city_courierapp/screens/home/cek_ongkir/cek_ongkir_screen.dart';
import 'package:city_courierapp/screens/help/help_screen.dart';
import 'package:city_courierapp/screens/widgets/landing/landing_widgets.dart';
import 'package:city_courierapp/services/auth_service.dart';
import 'package:city_courierapp/services/api_service.dart';

class WelcomeView extends StatefulWidget {
  final VoidCallback onPhoneLoginTap;

  const WelcomeView({
    super.key,
    required this.onPhoneLoginTap,
  });

  @override
  State<WelcomeView> createState() => _WelcomeViewState();
}

class _WelcomeViewState extends State<WelcomeView> {
  bool _isLoading = false;

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    try {
      // 1. Dapatkan Token ID dari Google/Firebase
      final idToken = await AuthService.getGoogleIdToken();

      if (idToken == null) {
        // User membatalkan login
        setState(() => _isLoading = false);
        return;
      }

      // 2. Kirim ke Backend Laravel untuk autentikasi
      final success = await ApiService.loginWithGoogle(idToken);

      if (success && mounted) {
        // Berhasil login, arahkan ke Home
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const HomeScreen(),
          ),
        );
      } else if (mounted) {
        // Gagal di sisi backend
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal menghubungkan dengan server. Silakan coba lagi.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = 'Terjadi kesalahan saat login Google.';
        if (e.toString().contains('network_error')) {
          errorMsg = 'Kesalahan jaringan. Pastikan koneksi internet stabil.';
        } else if (e.toString().contains('PlatformException(7,')) {
          errorMsg = 'Kesalahan konfigurasi (SHA-1). Hubungi pengembang.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          _isLoading
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEA580C)),
                  ),
                )
              : LandingSocialButton(
                  label: 'Lanjutkan dengan Google',
                  isGoogle: true,
                  onTap: _handleGoogleSignIn,
                ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Divider(color: Colors.grey[200], thickness: 1),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'ATAU',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[400],
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              Expanded(
                child: Divider(color: Colors.grey[200], thickness: 1),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LandingSocialButton(
            label: 'Masuk dengan Nomor HP',
            isGoogle: false,
            onTap: widget.onPhoneLoginTap,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 24, bottom: 32),
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[400],
                  height: 1.5,
                ),
                children: [
                  const TextSpan(text: 'Dengan masuk, Anda menyetujui '),
                  TextSpan(
                    text: 'Syarat & Ketentuan',
                    style: TextStyle(
                      color: const Color(0xFFEA580C),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const TextSpan(text: ' serta '),
                  TextSpan(
                    text: 'Kebijakan Privasi',
                    style: TextStyle(
                      color: const Color(0xFFEA580C),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const TextSpan(text: ' kami.'),
                ],
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              LandingActionBox(
                label: 'Lacak',
                icon: Icons.search_rounded,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TrackingScreen(),
                    ),
                  );
                },
              ),
              LandingActionBox(
                label: 'Tarif',
                icon: Icons.calculate_rounded,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CekOngkirScreen(),
                    ),
                  );
                },
              ),
              LandingActionBox(
                label: 'Bantuan',
                icon: Icons.headset_mic_rounded,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HelpScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
