import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:city_courierapp/services/courier/courier_registration_service.dart';


class CourierRegistrationFormScreen extends StatefulWidget {
  final Map<String, dynamic>? userData;
  const CourierRegistrationFormScreen({super.key, this.userData});

  @override
  State<CourierRegistrationFormScreen> createState() =>
      _CourierRegistrationFormScreenState();
}

class _CourierRegistrationFormScreenState
    extends State<CourierRegistrationFormScreen> {
  // Personal Data Controllers
  final _nameController = TextEditingController();
  final _nikController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();

  // Vehicle Info Controllers
  final _vehicleBrandController = TextEditingController();
  final _vehicleYearController = TextEditingController();
  final _vehiclePlateController = TextEditingController();

  String selectedVehicle = 'Motor';
  bool hasAgreed = false;
  bool _isLoading = false;

  // File Paths
  String? _photoPath;
  String? _idCardPath;
  String? _licensePath;
  String? _skckPath;

  final _picker = ImagePicker();
  
  @override
  void initState() {
    super.initState();
    if (widget.userData != null) {
      _nameController.text = widget.userData!['name'] ?? '';
      _emailController.text = widget.userData!['email'] ?? '';
      // Removing +62 if present since the field has a prefix
      String phone = widget.userData!['phone'] ?? '';
      if (phone.startsWith('+62')) {
        phone = phone.substring(3);
      } else if (phone.startsWith('62')) {
        phone = phone.substring(2);
      } else if (phone.startsWith('0')) {
        phone = phone.substring(1);
      }
      _phoneController.text = phone;
      _addressController.text = widget.userData!['address'] ?? '';
      _cityController.text = widget.userData!['city'] ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nikController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _vehicleBrandController.dispose();
    _vehicleYearController.dispose();
    _vehiclePlateController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(String type) async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (image != null) {
      setState(() {
        switch (type) {
          case 'photo':
            _photoPath = image.path;
            break;
          case 'id_card':
            _idCardPath = image.path;
            break;
          case 'license':
            _licensePath = image.path;
            break;
          case 'skck':
            _skckPath = image.path;
            break;
        }
      });
    }
  }

  Future<void> _submitRegistration() async {
    if (!hasAgreed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Anda harus menyetujui Syarat & Ketentuan')),
      );
      return;
    }

    if (_photoPath == null || _idCardPath == null || _licensePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mohon lengkapi semua dokumen wajib')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await CourierRegistrationService.register(
        name: _nameController.text,
        email: _emailController.text,
        password: _passwordController.text,
        passwordConfirmation: _passwordConfirmController.text,
        nik: _nikController.text,
        phone: _phoneController.text,
        address: _addressController.text,
        city: _cityController.text,
        vehicleType: selectedVehicle,
        vehicleBrand: _vehicleBrandController.text,
        vehicleYear: _vehicleYearController.text,
        vehiclePlate: _vehiclePlateController.text,
        photoPath: _photoPath!,
        idCardPath: _idCardPath!,
        licensePath: _licensePath!,
        skckPath: _skckPath,
      );

      if (mounted) {
        setState(() => _isLoading = false);

        if (result['success']) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Registrasi Berhasil'),
              content: Text(result['message']),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Back to previous screen
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        } else {
          String errorMessage = result['message'];
          if (result['errors'] != null) {
            final errors = result['errors'] as Map<String, dynamic>;
            errorMessage = errors.values.expand((e) => e as List).join('\n');
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terjadi kesalahan: $e')),
        );
      }
    }
  }

  bool get isDarkMode => Theme.of(context).brightness == Brightness.dark;

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFEC5B13);
    final bgColor = isDarkMode ? const Color(0xFF0F172A) : Colors.white;
    final borderColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.1)
        : const Color(0xFFE2E8F0);
    final textColor = isDarkMode ? Colors.white : const Color(0xFF0F172A);
    final subTextColor = isDarkMode ? Colors.white70 : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: isDarkMode
          ? const Color(0xFF221610)
          : const Color(0xFFF8F6F6),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          color: bgColor,
          child: Column(
            children: [
              _buildAppBar(context, textColor, borderColor),
              _buildProgressBar(primaryColor, subTextColor),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      _buildPersonalDataSection(
                        primaryColor,
                        textColor,
                        borderColor,
                      ),
                      _buildDivider(),
                      // _buildEducationSection(
                      //   primaryColor,
                      //   textColor,
                      //   borderColor,
                      // ),
                      _buildDivider(),
                      _buildVehicleInfoSection(
                        primaryColor,
                        textColor,
                        borderColor,
                        subTextColor,
                      ),
                      _buildDivider(),
                      _buildUploadDocsSection(
                        primaryColor,
                        textColor,
                        borderColor,
                        subTextColor,
                      ),
                      _buildAgreementSection(primaryColor, subTextColor),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildStickyFooter(primaryColor),
    );
  }

  Widget _buildAppBar(
    BuildContext context,
    Color textColor,
    Color borderColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Icon(Icons.arrow_back, color: Color(0xFFEC5B13)),
            ),
            const SizedBox(width: 16),
            Text(
              'Registrasi Kurir City Courier',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(Color primaryColor, Color subTextColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Langkah 1 dari 4',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: subTextColor,
                ),
              ),
              Text(
                '25% Selesai',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 8,
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.white10 : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(10),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: 0.25,
              child: Container(
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalDataSection(
    Color primaryColor,
    Color textColor,
    Color borderColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            Icons.person,
            'Data Pribadi',
            primaryColor,
            textColor,
          ),
          const SizedBox(height: 16),
          _buildInputField(
            'Nama Lengkap',
            'Sesuai KTP',
            textColor,
            borderColor,
            controller: _nameController,
          ),
          const SizedBox(height: 16),
          _buildInputField(
            'NIK (Nomor Induk Kependudukan)',
            '16 digit nomor NIK',
            textColor,
            borderColor,
            keyboardType: TextInputType.number,
            controller: _nikController,
          ),
          const SizedBox(height: 16),
          _buildPhoneField(textColor, borderColor),
          const SizedBox(height: 16),
          _buildInputField(
            'Email Aktif',
            'contoh@email.com',
            textColor,
            borderColor,
            keyboardType: TextInputType.emailAddress,
            controller: _emailController,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildInputField(
                  'Password',
                  'Min 8 karakter',
                  textColor,
                  borderColor,
                  isPassword: true,
                  controller: _passwordController,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInputField(
                  'Konfirmasi',
                  'Ulangi password',
                  textColor,
                  borderColor,
                  isPassword: true,
                  controller: _passwordConfirmController,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInputField(
            'Alamat Lengkap',
            'Jl. Nama Jalan No. XX',
            textColor,
            borderColor,
            controller: _addressController,
          ),
          const SizedBox(height: 16),
          _buildInputField(
            'Kota / Kabupaten',
            'Contoh: Jakarta Selatan',
            textColor,
            borderColor,
            controller: _cityController,
          ),
        ],
      ),
    );
  }

  // Widget _buildEducationSection(
  //   Color primaryColor,
  //   Color textColor,
  //   Color borderColor,
  // ) {
  //   return Container(
  //     padding: const EdgeInsets.all(16),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         _buildSectionHeader(
  //           Icons.school,
  //           'Pendidikan',
  //           primaryColor,
  //           textColor,
  //         ),
  //         const SizedBox(height: 16),
  //         Text(
  //           'Pendidikan Terakhir',
  //           style: TextStyle(
  //             fontSize: 14,
  //             fontWeight: FontWeight.w500,
  //             color: textColor,
  //
  //           ),
  //         ),
  //         const SizedBox(height: 8),
  //         _buildDropdownField(
  //           'Pilih Pendidikan',
  //           [
  //             'SMA / SMK / Sederajat',
  //             'Diploma (D3)',
  //             'Sarjana (S1)',
  //             'Lainnya',
  //           ],
  //           textColor,
  //           borderColor,
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildVehicleInfoSection(
    Color primaryColor,
    Color textColor,
    Color borderColor,
    Color subTextColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            Icons.directions_car,
            'Informasi Kendaraan',
            primaryColor,
            textColor,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildVehicleToggle(
                  'Motor',
                  Icons.two_wheeler,
                  primaryColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildVehicleToggle(
                  'Mobil Pickup',
                  Icons.local_shipping_outlined,
                  primaryColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildVehicleToggle(
                  'Mobil Box',
                  Icons.inventory_2_outlined,
                  primaryColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildVehicleToggle(
                  'Truck',
                  Icons.local_shipping,
                  primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInputField(
            'Merek & Tipe Kendaraan',
            'Contoh: Honda Vario 150',
            textColor,
            borderColor,
            controller: _vehicleBrandController,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildInputField(
                  'Tahun Produksi',
                  '2020',
                  textColor,
                  borderColor,
                  keyboardType: TextInputType.number,
                  controller: _vehicleYearController,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInputField(
                  'Nomor Plat (TNKB)',
                  'B 1234 ABC',
                  textColor,
                  borderColor,
                  controller: _vehiclePlateController,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUploadDocsSection(
    Color primaryColor,
    Color textColor,
    Color borderColor,
    Color subTextColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            Icons.cloud_upload,
            'Unggah Dokumen',
            primaryColor,
            textColor,
          ),
          const SizedBox(height: 4),
          Text(
            'Pastikan foto terlihat jelas, tidak buram, dan tidak terpotong.',
            style: TextStyle(
              fontSize: 12,
              color: subTextColor,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.2,
            children: [
              _buildUploadBox(
                Icons.badge,
                'Foto KTP',
                _idCardPath != null ? 'Terpilih' : 'JPG/PNG, Max 2MB',
                _idCardPath != null ? primaryColor : borderColor,
                textColor,
                onTap: () => _pickImage('id_card'),
                previewPath: _idCardPath,
              ),
              _buildUploadBox(
                Icons.badge_outlined,
                'Foto SIM',
                _licensePath != null ? 'Terpilih' : 'Aktif & Sesuai',
                _licensePath != null ? primaryColor : borderColor,
                textColor,
                onTap: () => _pickImage('license'),
                previewPath: _licensePath,
              ),
              _buildUploadBox(
                Icons.verified_user,
                'SKCK',
                _skckPath != null ? 'Terpilih' : 'Masih Berlaku',
                _skckPath != null ? primaryColor : borderColor,
                textColor,
                onTap: () => _pickImage('skck'),
                previewPath: _skckPath,
              ),
              _buildUploadBox(
                Icons.account_circle,
                'Pas Foto 4x6',
                _photoPath != null ? 'Terpilih' : 'Latar Merah/Biru',
                _photoPath != null ? primaryColor : borderColor,
                textColor,
                onTap: () => _pickImage('photo'),
                previewPath: _photoPath,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAgreementSection(Color primaryColor, Color subTextColor) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: hasAgreed,
            activeColor: primaryColor,
            onChanged: (val) => setState(() => hasAgreed = val ?? false),
          ),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 14,
                  color: subTextColor,
                  height: 1.5,
                ),
                children: [
                  const TextSpan(text: 'Saya menyetujui '),
                  TextSpan(
                    text: 'Syarat & Ketentuan',
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  const TextSpan(text: ' serta '),
                  TextSpan(
                    text: 'Kebijakan Privasi',
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  const TextSpan(
                    text:
                        ' yang berlaku di City Courier. Saya menjamin bahwa data yang saya berikan adalah benar.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    IconData icon,
    String title,
    Color primaryColor,
    Color textColor,
  ) {
    return Row(
      children: [
        Icon(icon, color: primaryColor, size: 24),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildInputField(
    String label,
    String hint,
    Color textColor,
    Color borderColor, {
    TextInputType? keyboardType,
    TextEditingController? controller,
    bool isPassword = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: textColor,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: isPassword,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: textColor.withValues(alpha: 0.4),
              fontSize: 14,
            ),
            filled: true,
            fillColor: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: const Color(0xFFEC5B13)),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneField(Color textColor, Color borderColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Nomor WhatsApp',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: textColor,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            prefixIcon: Container(
              width: 50,
              alignment: Alignment.center,
              child: Text(
                '+62',
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.6),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            hintText: '812xxxxxx',
            hintStyle: TextStyle(
              color: textColor.withValues(alpha: 0.4),
              fontSize: 14,
            ),
            filled: true,
            fillColor: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: const Color(0xFFEC5B13)),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleToggle(String label, IconData icon, Color primaryColor) {
    bool isSelected = selectedVehicle == label;
    return GestureDetector(
      onTap: () => setState(() => selectedVehicle = label),
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withValues(alpha: 0.1)
              : (isDarkMode ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? primaryColor
                : (isDarkMode ? Colors.white10 : Colors.grey[200]!),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? primaryColor : Colors.grey[400],
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 8,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? primaryColor : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadBox(
    IconData icon,
    String title,
    String subtitle,
    Color borderColor,
    Color textColor, {
    VoidCallback? onTap,
    String? previewPath,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: previewPath != null ? 2 : 1),
          image: previewPath != null
              ? DecorationImage(
                  image: FileImage(File(previewPath)),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withValues(alpha: 100 / 255),
                    BlendMode.darken,
                  ),
                )
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              previewPath != null ? Icons.check_circle : icon,
              color: previewPath != null ? Colors.white : Colors.grey[400],
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: previewPath != null ? Colors.white : textColor,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: previewPath != null ? Colors.white70 : Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 8,
      color: isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
    );
  }

  Widget _buildStickyFooter(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 480),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDarkMode ? Colors.white10 : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: _isLoading ? null : _submitRegistration,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 4,
            shadowColor: primaryColor.withValues(alpha: 0.3),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text(
                      'Kirim Pendaftaran',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.send, size: 18),
                  ],
                ),
        ),
      ),
    );
  }
}
