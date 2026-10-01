import 'package:flutter/material.dart';
import '../widgets/daftar_kurir_components.dart';
import '../widgets/daftar_kurir_constants.dart';
import 'pilih_layanan_screen.dart';

class PilihTipeKurirScreen extends StatefulWidget {
  const PilihTipeKurirScreen({super.key});

  @override
  State<PilihTipeKurirScreen> createState() => _PilihTipeKurirScreenState();
}

class _PilihTipeKurirScreenState extends State<PilihTipeKurirScreen> {
  String? _selectedType;

  @override
  Widget build(BuildContext context) {
    return ScreenLayout(
      title: 'Tipe Kurir',
      currentStep: 2, // Step 2 of 4 based on Stitch design
      totalSteps: 4,
      bottomAction: PrimaryButton(
        text: 'Lanjutkan',
        onPressed: _selectedType != null
            ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PilihLayananScreen(),
                  ),
                );
              }
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pilih Tipe Kurir',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: DaftarKurirColors.textDark,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Silakan pilih jenis layanan kurir yang ingin Anda jalankan.',
            style: TextStyle(
              fontSize: 14,
              color: DaftarKurirColors.textMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),
          _buildTypeCard(
            id: 'umum',
            icon: Icons.local_shipping,
            title: 'Kurir Umum',
            description: 'Dapat menerima berbagai jenis pengiriman barang sehari-hari.',
          ),
          const SizedBox(height: 16),
          _buildTypeCard(
            id: 'spesialis',
            icon: Icons.ac_unit,
            title: 'Kurir Spesialis',
            description: 'Berfokus pada jenis layanan tertentu (contoh: barang pecah belah, makanan dingin).',
          ),
        ],
      ),
    );
  }

  Widget _buildTypeCard({
    required String id,
    required IconData icon,
    required String title,
    required String description,
  }) {
    final isSelected = _selectedType == id;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedType = id;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? DaftarKurirColors.primary : DaftarKurirColors.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: DaftarKurirColors.bgLight,
                shape: BoxShape.circle,
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
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: DaftarKurirColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: DaftarKurirColors.textMuted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: DaftarKurirColors.primary,
              ),
          ],
        ),
      ),
    );
  }
}
