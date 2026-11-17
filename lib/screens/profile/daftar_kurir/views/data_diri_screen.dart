import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../daftar_kurir_data.dart';
import '../daftar_kurir_validators.dart';
import '../widgets/daftar_kurir_components.dart';
import '../widgets/daftar_kurir_constants.dart';
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
  final _birthPlaceController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();

  DateTime? _birthDate;
  String? _gender;

  /// Validasi baru dijalankan setelah pengguna menekan "Lanjutkan", lalu
  /// otomatis diperbarui saat pengguna memperbaiki isian.
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  @override
  void initState() {
    super.initState();
    final data = context.read<DaftarKurirData>();
    _nameController.text = data.name ?? '';
    _nikController.text = data.nik ?? '';
    _birthPlaceController.text = data.birthPlace ?? '';
    _emailController.text = data.email ?? '';
    _addressController.text = data.address ?? '';
    _cityController.text = data.city ?? '';
    _gender = data.gender;

    _birthDate = data.birthDate == null
        ? null
        : DateTime.tryParse(data.birthDate!);
    if (_birthDate != null) {
      _birthDateController.text = DateFormat('dd/MM/yyyy').format(_birthDate!);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nikController.dispose();
    _birthPlaceController.dispose();
    _birthDateController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 17, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Pilih Tanggal Lahir',
    );
    if (picked == null || !mounted) return;

    setState(() {
      _birthDate = picked;
      _birthDateController.text = DateFormat('dd/MM/yyyy').format(picked);
    });
  }

  void _handleNext() {
    final isValid = _formKey.currentState?.validate() ?? false;
    setState(() {
      _autovalidateMode = AutovalidateMode.onUserInteraction;
    });

    if (!isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mohon lengkapi semua data.')),
      );
      return;
    }

    final data = context.read<DaftarKurirData>();
    data.name = _nameController.text.trim();
    data.nik = _nikController.text.trim();
    data.birthPlace = _birthPlaceController.text.trim();
    data.birthDate = _birthDate == null
        ? null
        : DateFormat('yyyy-MM-dd').format(_birthDate!);
    data.gender = _gender;
    data.email = _emailController.text.trim();
    data.address = _addressController.text.trim();
    if (_cityController.text.trim().isNotEmpty) {
      data.city = _cityController.text.trim();
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DataKendaraanScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScreenLayout(
      title: 'Data Diri',
      currentStep: 2,
      totalSteps: 4,
      bottomAction: PrimaryButton(text: 'Lanjutkan', onPressed: _handleNext),
      child: Form(
        key: _formKey,
        autovalidateMode: _autovalidateMode,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            const Text(
              'Mohon lengkapi data diri Anda dengan benar sesuai identitas resmi.',
              style: TextStyle(fontSize: 16, color: DaftarKurirColors.textDark),
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
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomTextField(
                    label: 'Nama Lengkap',
                    hintText: 'Budi Santoso',
                    helperText: 'Masukkan nama lengkap sesuai identitas resmi.',
                    prefixIcon: Icons.person_outline,
                    controller: _nameController,
                    validator: DaftarKurirValidators.name,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),

                  CustomTextField(
                    label: 'Nomor Induk Kependudukan (NIK)',
                    hintText: '16 digit NIK',
                    helperText: 'Masukkan 16 digit NIK sesuai KTP.',
                    keyboardType: TextInputType.number,
                    prefixIcon: Icons.badge_outlined,
                    controller: _nikController,
                    validator: DaftarKurirValidators.nik,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(16),
                    ],
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: CustomTextField(
                          label: 'Tempat Lahir',
                          hintText: 'Kota Lahir',
                          helperText: 'Masukkan kota tempat Anda dilahirkan.',
                          prefixIcon: Icons.location_on_outlined,
                          controller: _birthPlaceController,
                          validator: DaftarKurirValidators.birthPlace,
                          textInputAction: TextInputAction.next,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: CustomTextField(
                          label: 'Tanggal Lahir',
                          hintText: 'DD/MM/YYYY',
                          helperText:
                              'Pilih tanggal lahir sesuai identitas resmi.',
                          keyboardType: TextInputType.datetime,
                          prefixIcon: Icons.calendar_today_outlined,
                          controller: _birthDateController,
                          validator: DaftarKurirValidators.birthDate,
                          readOnly: true,
                          onTap: _pickBirthDate,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  CustomDropdownField<String>(
                    label: 'Jenis Kelamin',
                    hintText: 'Pilih jenis kelamin',
                    helperText: 'Pilih sesuai identitas resmi.',
                    value: _gender,
                    items: const [
                      DropdownMenuItem(value: 'l', child: Text('Laki-laki')),
                      DropdownMenuItem(value: 'p', child: Text('Perempuan')),
                    ],
                    validator: DaftarKurirValidators.gender,
                    onChanged: (value) {
                      setState(() {
                        _gender = value;
                      });
                    },
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
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomTextField(
                    label: 'Alamat Email',
                    hintText: 'contoh@email.com',
                    helperText: 'Gunakan email aktif untuk verifikasi akun.',
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: Icons.mail_outline,
                    controller: _emailController,
                    validator: DaftarKurirValidators.email,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    label: 'Alamat Lengkap',
                    hintText: 'Jl. Contoh No. 123, RT/RW, Kelurahan',
                    prefixIcon: Icons.home_outlined,
                    controller: _addressController,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    label: 'Kota',
                    hintText: 'Isi kota sesuai area operasional',
                    prefixIcon: Icons.location_city_outlined,
                    controller: _cityController,
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
