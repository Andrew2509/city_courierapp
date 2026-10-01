import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:city_courierapp/services/courier/courier_profile_service.dart';

class DriverAccountInfoScreen extends StatefulWidget {
  const DriverAccountInfoScreen({super.key});

  @override
  State<DriverAccountInfoScreen> createState() => _DriverAccountInfoScreenState();
}

class _DriverAccountInfoScreenState extends State<DriverAccountInfoScreen> {
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;
  Map<String, dynamic>? _profileData;
  String? _errorMessage;
  File? _pickedImage;

  // Personal info controllers
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _nikController;
  late TextEditingController _addressController;
  late TextEditingController _cityController;

  // Vehicle info controllers
  String? _selectedVehicleType;
  late TextEditingController _brandController;
  late TextEditingController _modelController;
  late TextEditingController _plateController;
  late TextEditingController _colorController;
  late TextEditingController _yearController;

  final List<Map<String, String>> _vehicleTypes = [
    {'value': 'motor', 'label': 'Sepeda Motor', 'subtitle': 'Two-Wheeler'},
    {'value': 'mobil', 'label': 'Mobil', 'subtitle': 'Sedan / MPV / SUV'},
    {'value': 'pickup', 'label': 'Pickup', 'subtitle': 'Pickup Truck'},
    {'value': 'box', 'label': 'Box', 'subtitle': 'Box Truck'},
    {'value': 'truck', 'label': 'Truk', 'subtitle': 'Large Truck'},
    {'value': 'sepeda', 'label': 'Sepeda', 'subtitle': 'Bicycle'},
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _nikController = TextEditingController();
    _addressController = TextEditingController();
    _cityController = TextEditingController();
    _brandController = TextEditingController();
    _modelController = TextEditingController();
    _plateController = TextEditingController();
    _colorController = TextEditingController();
    _yearController = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _nikController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _plateController.dispose();
    _colorController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await CourierProfileService.getProfile();
      if (mounted) {
        setState(() {
          if (result['success'] == true) {
            _profileData = result['data'];
            _populateControllers();
          } else {
            _errorMessage = result['message'];
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _populateControllers() {
    final user = _profileData?['user'];
    final courier = _profileData?['courier_details'];

    // Personal info
    _nameController.text = user?['name'] ?? '';
    _phoneController.text = user?['phone'] ?? courier?['phone'] ?? '';
    _emailController.text = user?['email'] ?? '';
    _nikController.text = courier?['nik'] ?? '';
    _addressController.text = courier?['address'] ?? '';
    _cityController.text = courier?['city'] ?? '';

    // Vehicle info
    _selectedVehicleType = courier?['vehicle_type'];
    _brandController.text = courier?['vehicle_brand'] ?? '';
    _modelController.text = courier?['vehicle_model'] ?? '';
    _plateController.text = courier?['vehicle_plate'] ?? '';
    _colorController.text = courier?['vehicle_color'] ?? '';
    _yearController.text = courier?['vehicle_year'] ?? '';
  }

  void _showImageSourceActionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFFEC5B13)),
              title: const Text('Ambil Foto'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFFEC5B13)),
              title: const Text('Pilih dari Galeri'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source);
    if (image != null) {
      setState(() {
        _pickedImage = File(image.path);
      });
    }
  }

  Future<void> _handleSave() async {
    if (_nameController.text.trim().isEmpty) {
      _showSnackBar('Nama tidak boleh kosong', Colors.red);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final success = await CourierProfileService.updateProfile(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        nik: _nikController.text.trim(),
        address: _addressController.text.trim(),
        city: _cityController.text.trim(),
        vehicleType: _selectedVehicleType,
        vehicleBrand: _brandController.text.trim(),
        vehicleModel: _modelController.text.trim(),
        vehiclePlate: _plateController.text.trim(),
        vehicleColor: _colorController.text.trim(),
        vehicleYear: _yearController.text.trim(),
        photoPath: _pickedImage?.path,
      );

      if (mounted) {
        if (success) {
          _showSnackBar('Profil berhasil diperbarui', Colors.green);
          setState(() => _isEditing = false);
          _loadProfile();
        } else {
          _showSnackBar('Gagal memperbarui profil', Colors.red);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Terjadi kesalahan: $e', Colors.red);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String _getVehicleTypeName(String? value) {
    if (value == null) return '-';
    final type = _vehicleTypes.firstWhere(
      (t) => t['value'] == value,
      orElse: () => {'label': value},
    );
    return type['label'] ?? value;
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFEC5B13);
    const bgLight = Color(0xFFF8F9FA);
    final textMain = Colors.black87;
    final textMuted = Colors.grey[600]!;

    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.black87, size: 22),
        ),
        title: Text(
          'Informasi Akun',
          style: TextStyle(
            color: textMain,
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
        actions: [
          if (_isEditing)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _isSaving
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor),
                      ),
                    )
                  : TextButton(
                      onPressed: _handleSave,
                      style: TextButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text(
                        'Simpan',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: IconButton(
                onPressed: () => setState(() => _isEditing = true),
                icon: const Icon(Icons.edit, color: primaryColor, size: 20),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: $_errorMessage', style: TextStyle(color: textMain)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadProfile,
                        style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                        child: const Text('Coba Lagi', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadProfile,
                  color: primaryColor,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _buildAvatarSection(primaryColor, textMain),
                        const SizedBox(height: 24),

                        // Personal Info Section
                        _buildSectionHeader('INFORMASI PRIBADI', textMuted),
                        const SizedBox(height: 12),
                        _buildField('Nama Lengkap', _nameController, Icons.person_outline, primaryColor, textMuted),
                        const SizedBox(height: 10),
                        _buildField('NIK', _nikController, Icons.badge_outlined, primaryColor, textMuted, hint: 'Nomor Induk Kependudukan'),
                        const SizedBox(height: 10),
                        _buildField('Nomor Telepon', _phoneController, Icons.phone_outlined, primaryColor, textMuted, keyboardType: TextInputType.phone),
                        const SizedBox(height: 10),
                        _buildField('Email', _emailController, Icons.email_outlined, primaryColor, textMuted, keyboardType: TextInputType.emailAddress),
                        const SizedBox(height: 10),
                        _buildField('Kota', _cityController, Icons.location_city_outlined, primaryColor, textMuted, hint: 'Kota domisili'),
                        const SizedBox(height: 10),
                        _buildField('Alamat Lengkap', _addressController, Icons.location_on_outlined, primaryColor, textMuted, maxLines: 3),
                        const SizedBox(height: 24),

                        // Vehicle Info Section
                        _buildSectionHeader('INFORMASI KENDARAAN', textMuted),
                        const SizedBox(height: 12),
                        _buildVehicleTypeDropdown(primaryColor, textMuted),
                        const SizedBox(height: 10),

                        // Brand and Model in row
                        Row(
                          children: [
                            Expanded(
                              child: _buildField('MEREK', _brandController, Icons.business_outlined, primaryColor, textMuted, hint: 'Honda'),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildField('MODEL', _modelController, Icons.directions_car_outlined, primaryColor, textMuted, hint: 'Beat Street 110'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Plate Number
                        _buildPlateField(primaryColor, textMuted),
                        const SizedBox(height: 10),

                        // Color and Year in row
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: _buildField('WARNA', _colorController, Icons.palette_outlined, primaryColor, textMuted, hint: 'Hitam Matte'),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildField('TAHUN', _yearController, Icons.calendar_today_outlined, primaryColor, textMuted, hint: '2024', keyboardType: TextInputType.number),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Status Section
                        _buildSectionHeader('STATUS AKUN', textMuted),
                        const SizedBox(height: 12),
                        _buildStatusCard(primaryColor, textMain, textMuted),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildAvatarSection(Color primaryColor, Color textMain) {
    final user = _profileData?['user'];
    final courier = _profileData?['courier_details'];
    String photoUrl = user?['photo'] ?? '';

    if (photoUrl.isNotEmpty && !photoUrl.startsWith('http')) {
      photoUrl = 'https://citycourier.pabm.space/storage/$photoUrl';
    }

    final bool isVerified = courier?['is_verified'] ?? false;

    return Column(
      children: [
        Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.15),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: _pickedImage != null
                      ? Image.file(_pickedImage!, fit: BoxFit.cover)
                      : (photoUrl.isNotEmpty
                          ? Image.network(
                              photoUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: primaryColor.withOpacity(0.1),
                                child: Icon(Icons.person, size: 40, color: primaryColor),
                              ),
                            )
                          : Container(
                              color: primaryColor.withOpacity(0.1),
                              child: Icon(Icons.person, size: 40, color: primaryColor),
                            )),
                ),
              ),
              if (_isEditing)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _showImageSourceActionSheet,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: primaryColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          user?['name'] ?? 'Driver',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: textMain,
          ),
        ),
        const SizedBox(height: 4),
        if (isVerified)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified, color: Color(0xFF16A34A), size: 14),
                SizedBox(width: 4),
                Text(
                  'Kurir Terverifikasi',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF16A34A),
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.hourglass_top, color: Colors.orange, size: 14),
                SizedBox(width: 4),
                Text(
                  'Menunggu Verifikasi',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildStatusCard(Color primaryColor, Color textMain, Color textMuted) {
    final courier = _profileData?['courier_details'];
    final bool isVerified = courier?['is_verified'] ?? false;
    final bool isActive = courier?['is_active'] ?? false;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildStatusRow(
            icon: Icons.verified_outlined,
            label: 'Verifikasi',
            value: isVerified ? 'Terverifikasi' : 'Menunggu Verifikasi',
            valueColor: isVerified ? Colors.green : Colors.orange,
            iconColor: isVerified ? Colors.green : Colors.orange,
          ),
          const Divider(height: 20),
          _buildStatusRow(
            icon: Icons.toggle_on,
            label: 'Status Aktif',
            value: isActive ? 'Aktif' : 'Tidak Aktif',
            valueColor: isActive ? Colors.green : Colors.grey,
            iconColor: isActive ? Colors.green : Colors.grey,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow({
    required IconData icon,
    required String label,
    required String value,
    required Color valueColor,
    required Color iconColor,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: valueColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, Color textMuted) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: textMuted,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller,
    IconData icon,
    Color primaryColor,
    Color textMuted, {
    String? hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    if (_isEditing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textMuted,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: hint ?? 'Masukkan $label',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
              prefixIcon: maxLines == 1 ? Icon(icon, size: 18, color: primaryColor) : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: primaryColor.withOpacity(0.5), width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ],
      );
    }

    // View mode
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Icon(icon, color: textMuted, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  controller.text.isNotEmpty ? controller.text : '-',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: maxLines,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleTypeDropdown(Color primaryColor, Color textMuted) {
    if (_isEditing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'JENIS KENDARAAN',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textMuted,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedVehicleType,
                isExpanded: true,
                hint: Text(
                  'Pilih jenis kendaraan',
                  style: TextStyle(color: Colors.grey[400], fontSize: 13),
                ),
                icon: Icon(Icons.keyboard_arrow_down, color: primaryColor),
                items: _vehicleTypes.map((type) {
                  return DropdownMenuItem<String>(
                    value: type['value'],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          type['label']!,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          type['subtitle']!,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedVehicleType = value);
                },
              ),
            ),
          ),
        ],
      );
    }

    // View mode
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Icon(Icons.two_wheeler_outlined, color: textMuted, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'JENIS KENDARAAN',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _getVehicleTypeName(_selectedVehicleType),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlateField(Color primaryColor, Color textMuted) {
    if (_isEditing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'NOMOR POLISI',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: textMuted,
                ),
              ),
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Sesuai STNK',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _plateController,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: 'L 1234 AB',
              hintStyle: TextStyle(
                color: Colors.grey[400],
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
              prefixIcon: Container(
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.pin_outlined, size: 20, color: primaryColor),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: primaryColor.withOpacity(0.5), width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ],
      );
    }

    // View mode
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Icon(Icons.pin_outlined, color: textMuted, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NOMOR POLISI',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _plateController.text.isNotEmpty ? _plateController.text : '-',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          Text(
            'Sesuai STNK',
            style: TextStyle(
              fontSize: 10,
              color: primaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
