import 'package:flutter/material.dart';

class ScannerGuideScreen extends StatelessWidget {
  const ScannerGuideScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFFEC5B13);
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF0F172A) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDarkMode ? const Color(0xFF0F172A) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: isDarkMode ? Colors.white : Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Panduan Scan Barcode',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
        shape: Border(
          bottom: BorderSide(
            color: isDarkMode ? Colors.white10 : Colors.grey.shade100,
            width: 1,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                children: [
                  // Hero Illustration
                  _buildHeroIllustration(primaryColor),
                  const SizedBox(height: 48),
                  
                  // Tips List
                  _buildGuideItem(
                    icon: Icons.lightbulb_outline,
                    title: 'Pencahayaan Cukup',
                    description: 'Pastikan barcode mendapat cahaya yang terang dan hindari bayangan agar sensor kamera dapat membaca kode dengan jelas.',
                    primaryColor: primaryColor,
                    isDarkMode: isDarkMode,
                  ),
                  const SizedBox(height: 32),
                  _buildGuideItem(
                    icon: Icons.crop_free,
                    title: 'Posisikan di Dalam Bingkai',
                    description: 'Letakkan seluruh bagian barcode tepat di tengah kotak pemindai. Beri sedikit jarak agar fokus kamera tetap optimal.',
                    primaryColor: primaryColor,
                    isDarkMode: isDarkMode,
                  ),
                  const SizedBox(height: 32),
                  _buildGuideItem(
                    icon: Icons.pan_tool_outlined,
                    title: 'Jaga Kamera Tetap Stabil',
                    description: 'Pegang ponsel dengan stabil dan hindari gerakan mendadak saat memindai untuk mencegah gambar menjadi buram.',
                    primaryColor: primaryColor,
                    isDarkMode: isDarkMode,
                  ),
                ],
              ),
            ),
          ),
          
          // Footer Button
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 8,
                  shadowColor: primaryColor.withOpacity(0.4),
                ),
                child: const Text(
                  'Saya Mengerti',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroIllustration(Color primaryColor) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: primaryColor, width: 2),
      ),
      child: Center(
        child: Icon(
          Icons.qr_code_scanner,
          size: 64,
          color: primaryColor,
        ),
      ),
    );
  }

  Widget _buildGuideItem({
    required IconData icon,
    required String title,
    required String description,
    required Color primaryColor,
    required bool isDarkMode,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.05),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: primaryColor, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.grey.shade900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
