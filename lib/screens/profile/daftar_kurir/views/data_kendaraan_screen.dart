import 'package:flutter/material.dart';
import '../widgets/daftar_kurir_components.dart';
import '../widgets/daftar_kurir_constants.dart';
import 'upload_dokumen_screen.dart';

class DataKendaraanScreen extends StatefulWidget {
  const DataKendaraanScreen({super.key});

  @override
  State<DataKendaraanScreen> createState() => _DataKendaraanScreenState();
}

class _DataKendaraanScreenState extends State<DataKendaraanScreen> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return ScreenLayout(
      currentStep: 2,
      totalSteps: 5,
      bottomAction: PrimaryButton(
        text: 'Lanjutkan',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const UploadDokumenScreen(),
            ),
          );
        },
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Data Kendaraan',
              style: DaftarKurirTextStyles.title,
            ),
            const SizedBox(height: 12),
            const Text(
              'Masukkan informasi kendaraan yang akan digunakan untuk operasional.',
              style: DaftarKurirTextStyles.subtitle,
            ),
            const SizedBox(height: 32),
            CustomTextField(
              label: 'Merek Kendaraan',
              hintText: 'Contoh: Honda',
              prefixIcon: Icons.directions_car_outlined,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              label: 'Tipe Kendaraan',
              hintText: 'Contoh: Vario 150',
              prefixIcon: Icons.two_wheeler_outlined,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              label: 'Tahun Pembuatan',
              hintText: 'Contoh: 2020',
              prefixIcon: Icons.calendar_today_outlined,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              label: 'Nomor Polisi (Plat)',
              hintText: 'Contoh: L 1234 AB',
              prefixIcon: Icons.pin_outlined,
            ),
          ],
        ),
      ),
    );
  }
}
