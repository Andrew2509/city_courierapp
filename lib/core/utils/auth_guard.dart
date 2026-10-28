import 'package:flutter/material.dart';
import 'package:city_courierapp/screens/landing_screen.dart';
import 'package:city_courierapp/services/token_store.dart';

/// Mekanisme konsisten untuk pengecekan status autentikasi (Guest vs Login)
/// dan pembatasan akses fitur di seluruh aplikasi.
class AuthGuard {
  AuthGuard._();

  /// Memeriksa apakah pengguna saat ini telah login (memiliki token aktif).
  static Future<bool> isAuthenticated() async {
    return await TokenStore.isLoggedIn();
  }

  /// Menjalankan [onAuthenticated] jika pengguna sudah login.
  /// Jika pengguna masih dalam Guest Mode, menampilkan dialog peringatan login.
  static Future<void> runWithAuth(
    BuildContext context, {
    required VoidCallback onAuthenticated,
  }) async {
    final loggedIn = await isAuthenticated();
    if (loggedIn) {
      onAuthenticated();
    } else {
      if (context.mounted) {
        await showLoginRequiredDialog(context);
      }
    }
  }

  /// Memproteksi halaman secara langsung (misal di initState).
  /// Jika bukan pengguna login, layar akan di-pop dan dialog login ditampilkan.
  /// Mengembalikan true jika terotentikasi, false jika ditolak.
  static Future<bool> guardScreen(BuildContext context) async {
    final loggedIn = await isAuthenticated();
    if (!loggedIn) {
      if (context.mounted) {
        Navigator.of(context).pop();
        await showLoginRequiredDialog(context);
      }
      return false;
    }
    return true;
  }

  /// Menampilkan dialog peringatan login sesuai ketentuan:
  /// - Judul: Login Diperlukan
  /// - Pesan: Silakan masuk terlebih dahulu untuk menggunakan fitur ini.
  /// - Tombol Batal: Menutup dialog tanpa berpindah halaman
  /// - Tombol OK: Mengarahkan pengguna ke halaman Login (LandingScreen)
  static Future<bool> showLoginRequiredDialog(BuildContext context) async {
    final bool? shouldLogin = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        final isDarkMode =
            Theme.of(dialogContext).brightness == Brightness.dark;
        const primaryColor = Color(0xFFEC5B13);

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor:
              isDarkMode ? const Color(0xFF1E293B) : Colors.white,
          title: Text(
            'Login Diperlukan',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: isDarkMode ? Colors.white : const Color(0xFF1F2937),
            ),
          ),
          content: Text(
            'Silakan masuk terlebih dahulu untuk menggunakan fitur ini.',
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode ? Colors.grey.shade300 : const Color(0xFF4B5563),
              height: 1.4,
            ),
          ),
          actionsPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: Text(
                'Batal',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isDarkMode
                      ? Colors.grey.shade400
                      : Colors.grey.shade600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              ),
              child: const Text(
                'OK',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    if (shouldLogin == true && context.mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LandingScreen()),
      );
      return true;
    }
    return false;
  }
}
