import 'package:flutter/material.dart';
import '../widgets/daftar_kurir_components.dart';
import '../widgets/daftar_kurir_constants.dart';

class TanggungJawabScreen extends StatelessWidget {
  const TanggungJawabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenLayout(
      title: 'Tanggung Jawab Kurir',
      bottomAction: PrimaryButton(
        text: 'Saya Mengerti & Lanjutkan',
        onPressed: () {
          Navigator.pop(context); // Go back to Informasi Pendaftaran to continue
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tanggung Jawab Mitra',
            style: DaftarKurirTextStyles.title,
          ),
          const SizedBox(height: 12),
          const Text(
            'Sebagai mitra CityCourier, Anda diharapkan untuk selalu menjaga profesionalitas dan pelayanan terbaik kepada pelanggan.',
            style: DaftarKurirTextStyles.subtitle,
          ),
          const SizedBox(height: 32),
          _buildResponsibilityItem(
            icon: Icons.inventory_2_outlined,
            title: 'Pengambilan & Pengiriman',
            description: 'Mengambil paket dari pengirim dan mengantarkan ke penerima dengan aman dan tepat waktu.',
          ),
          _buildResponsibilityItem(
            icon: Icons.security_outlined,
            title: 'Keamanan Barang',
            description: 'Bertanggung jawab penuh atas keutuhan dan keamanan barang selama proses pengiriman.',
          ),
          _buildResponsibilityItem(
            icon: Icons.update_outlined,
            title: 'Pembaruan Status',
            description: 'Selalu memperbarui status pengiriman di aplikasi secara real-time.',
          ),
          _buildResponsibilityItem(
            icon: Icons.chat_bubble_outline,
            title: 'Komunikasi',
            description: 'Menjaga komunikasi yang baik dan sopan dengan pelanggan.',
          ),
        ],
      ),
    );
  }

  Widget _buildResponsibilityItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: DaftarKurirColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: DaftarKurirColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: DaftarKurirTextStyles.label.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: DaftarKurirTextStyles.subtitle.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
