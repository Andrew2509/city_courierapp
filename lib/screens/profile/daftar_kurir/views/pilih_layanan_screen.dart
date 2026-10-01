import 'package:flutter/material.dart';
import '../widgets/daftar_kurir_components.dart';
import '../widgets/daftar_kurir_constants.dart';
import 'pilih_area_screen.dart';

class PilihLayananScreen extends StatefulWidget {
  const PilihLayananScreen({super.key});

  @override
  State<PilihLayananScreen> createState() => _PilihLayananScreenState();
}

class _PilihLayananScreenState extends State<PilihLayananScreen> {
  final Map<String, bool> _selectedServices = {
    'Pengiriman Paket': false,
    'Instant': false,
    'Same Day': false,
    'Pengiriman Dokumen': false,
  };

  bool get _hasSelection {
    return _selectedServices.values.any((isSelected) => isSelected);
  }

  @override
  Widget build(BuildContext context) {
    return ScreenLayout(
      title: 'Layanan',
      currentStep: 2, // Step 2 of 4 (Data Diri)
      totalSteps: 4,
      bottomAction: PrimaryButton(
        text: 'Lanjutkan',
        onPressed: _hasSelection
            ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PilihAreaScreen(),
                  ),
                );
              }
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pilih Layanan Pengiriman',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: DaftarKurirColors.textDark,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Silakan pilih satu atau lebih layanan yang ingin Anda jalankan sebagai kurir.',
            style: TextStyle(
              fontSize: 14,
              color: DaftarKurirColors.textMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),
          _buildServiceItem(
            title: 'Pengiriman Paket',
            subtitle: 'Layanan reguler untuk paket ukuran sedang.',
            icon: Icons.inventory_2_outlined,
          ),
          _buildServiceItem(
            title: 'Instant',
            subtitle: 'Pengiriman super cepat dalam hitungan jam.',
            icon: Icons.bolt,
          ),
          _buildServiceItem(
            title: 'Same Day',
            subtitle: 'Tiba di hari yang sama sebelum malam.',
            icon: Icons.schedule,
          ),
          _buildServiceItem(
            title: 'Pengiriman Dokumen',
            subtitle: 'Aman dan rahasia untuk dokumen penting.',
            icon: Icons.description_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildServiceItem({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _selectedServices[title] ?? false;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedServices[title] = !isSelected;
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
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
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
                  color: isSelected ? DaftarKurirColors.primary : DaftarKurirColors.textMuted,
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
                      subtitle,
                      style: const TextStyle(
                        fontSize: 14,
                        color: DaftarKurirColors.textMuted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSelected ? DaftarKurirColors.primary : DaftarKurirColors.border,
                    width: 2,
                  ),
                  color: isSelected ? DaftarKurirColors.primary : Colors.transparent,
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 16,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
