import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/daftar_kurir_components.dart';
import '../widgets/daftar_kurir_constants.dart';
import '../daftar_kurir_data.dart';
import 'data_kendaraan_screen.dart';

class DataDiriScreen extends StatefulWidget {
  const DataDiriScreen({super.key});

  @override
  State<DataDiriScreen> createState() => _DataDiriScreenState();
}

class _DataDiriScreenState extends State<DataDiriScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _nikController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _nikController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final existingData = context.read<DaftarKurirData>();
    if (_cityController.text.isEmpty && existingData.city != null) {
      _cityController.text = existingData.city!;
    }
    return ScreenLayout(
      title: 'Data Diri',
      currentStep: 2,
      totalSteps: 4,
      bottomAction: PrimaryButton(
        text: 'Lanjutkan',
        onPressed: () {
          if (_nameController.text.isEmpty || _nikController.text.isEmpty || _emailController.text.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mohon lengkapi semua data.')));
            return;
          }
          final data = context.read<DaftarKurirData>();
          data.name = _nameController.text;
          data.nik = _nikController.text;
          data.email = _emailController.text;
          data.address = _addressController.text;
          if (_cityController.text.isNotEmpty) {
            data.city = _cityController.text;
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const DataKendaraanScreen(),
            ),
          );
        },
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            const Text(
              'Mohon lengkapi data diri Anda dengan benar sesuai identitas resmi.',
              style: TextStyle(
                fontSize: 16,
                color: DaftarKurirColors.textDark,
              ),
            ),
            const SizedBox(height: 24),
            
            // Informasi Pribadi Card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: DaftarKurirColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomTextField(
                    label: 'Nama Lengkap',
                    hintText: 'Sesuai KTP',
                    prefixIcon: Icons.person_outline,
                    controller: _nameController,
                    isRequired: false,
                  ),
                  const SizedBox(height: 16),

                  CustomTextField(
                    label: 'Nomor Induk Kependudukan (NIK)',
                    hintText: '16 digit NIK',
                    keyboardType: TextInputType.number,
                    prefixIcon: Icons.badge_outlined,
                    controller: _nikController,
                    isRequired: false,
                  ),
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: CustomTextField(
                          label: 'Tempat Lahir',
                          hintText: 'Kota Lahir',
                          isRequired: false,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: CustomTextField(
                          label: 'Tanggal Lahir',
                          hintText: 'DD/MM/YYYY',
                          keyboardType: TextInputType.datetime,
                          prefixIcon: Icons.calendar_today_outlined,
                          isRequired: false,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Dropdown for Jenis Kelamin
                  const Text(
                    'Jenis Kelamin',
                    style: DaftarKurirTextStyles.label,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: DaftarKurirColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: DaftarKurirColors.border),
                      ),
                    ),
                    hint: const Text(
                      'Pilih Jenis Kelamin',
                      style: TextStyle(color: DaftarKurirColors.textMuted),
                    ),
                    icon: const Icon(Icons.arrow_drop_down, color: DaftarKurirColors.textMuted),
                    items: const [
                      DropdownMenuItem(value: 'l', child: Text('Laki-laki')),
                      DropdownMenuItem(value: 'p', child: Text('Perempuan')),
                    ],
                    onChanged: (value) {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Informasi Kontak Card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: DaftarKurirColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomTextField(
                    label: 'Alamat Email',
                    hintText: 'contoh@email.com',
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: Icons.mail_outline,
                    controller: _emailController,
                    isRequired: false,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Gunakan email aktif untuk verifikasi akun.',
                    style: TextStyle(
                      fontSize: 12,
                      color: DaftarKurirColors.textSub,
                    ),
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    label: 'Alamat Lengkap',
                    hintText: 'Jl. Contoh No. 123, RT/RW, Kelurahan',
                    prefixIcon: Icons.home_outlined,
                    controller: _addressController,
                    isRequired: false,
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    label: 'Kota',
                    hintText: 'Isi kota sesuai area operasional',
                    prefixIcon: Icons.location_city_outlined,
                    controller: _cityController,
                    isRequired: false,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
