import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/daftar_kurir_components.dart';
import '../widgets/daftar_kurir_constants.dart';
import '../daftar_kurir_data.dart';
import 'upload_dokumen_screen.dart';

class DataKendaraanScreen extends StatefulWidget {
  const DataKendaraanScreen({super.key});

  @override
  State<DataKendaraanScreen> createState() => _DataKendaraanScreenState();
}

class _DataKendaraanScreenState extends State<DataKendaraanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _brandController = TextEditingController();
  final _yearController = TextEditingController();
  final _plateController = TextEditingController();

  @override
  void dispose() {
    _brandController.dispose();
    _yearController.dispose();
    _plateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScreenLayout(
      currentStep: 2,
      totalSteps: 5,
      bottomAction: PrimaryButton(
        text: 'Lanjutkan',
        onPressed: () {
          if (_brandController.text.isEmpty || _yearController.text.isEmpty || _plateController.text.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mohon lengkapi semua data kendaraan.')));
            return;
          }
          final data = context.read<DaftarKurirData>();
          data.vehicleBrand = _brandController.text;
          data.vehicleYear = _yearController.text;
          data.vehiclePlate = _plateController.text;
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
              controller: _brandController,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              label: 'Tahun Pembuatan',
              hintText: 'Contoh: 2020',
              prefixIcon: Icons.calendar_today_outlined,
              keyboardType: TextInputType.number,
              controller: _yearController,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              label: 'Nomor Polisi (Plat)',
              hintText: 'Contoh: L 1234 AB',
              prefixIcon: Icons.pin_outlined,
              controller: _plateController,
            ),
          ],
        ),
      ),
    );
  }
}
