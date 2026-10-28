import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/daftar_kurir_components.dart';
import '../widgets/daftar_kurir_constants.dart';
import '../daftar_kurir_data.dart';
import 'data_diri_screen.dart';

class PilihKendaraanScreen extends StatefulWidget {
  const PilihKendaraanScreen({super.key});

  @override
  State<PilihKendaraanScreen> createState() => _PilihKendaraanScreenState();
}

class _PilihKendaraanScreenState extends State<PilihKendaraanScreen> {
  String? _selectedKendaraan;

  @override
  Widget build(BuildContext context) {
    return ScreenLayout(
      title: 'Jenis Kendaraan',
      currentStep: 2,
      totalSteps: 4,
      bottomAction: PrimaryButton(
        text: 'Pilih & Lanjutkan',
        onPressed: _selectedKendaraan != null
            ? () {
                context.read<DaftarKurirData>().vehicleType = _selectedKendaraan;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DataDiriScreen(),
                  ),
                );
              }
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pilih jenis kendaraan yang akan Anda gunakan untuk melakukan pengiriman.',
            style: TextStyle(
              fontSize: 16,
              color: DaftarKurirColors.textMuted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          _buildVehicleCard(
            id: 'motor',
            icon: Icons.two_wheeler,
            title: 'Motor',
            description: 'Kendaraan roda dua, cocok untuk pengiriman cepat barang kecil.',
          ),
          const SizedBox(height: 16),
          _buildVehicleCard(
            id: 'mobil',
            icon: Icons.directions_car,
            title: 'Mobil',
            description: 'Kendaraan roda empat, ideal untuk pengiriman barang besar atau banyak.',
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleCard({
    required String id,
    required IconData icon,
    required String title,
    required String description,
  }) {
    final isSelected = _selectedKendaraan == id;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedKendaraan = id;
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
                color: DaftarKurirColors.primary,
                size: 28,
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
                      fontSize: 20,
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
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? DaftarKurirColors.primary : DaftarKurirColors.textMuted,
                  width: isSelected ? 6 : 2, // If selected, thick border looks like a filled radio button
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
