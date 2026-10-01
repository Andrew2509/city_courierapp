import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:city_courierapp/services/api_service.dart';
import 'package:city_courierapp/screens/location/drop_point_picker_screen.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const EditProfileScreen({super.key, required this.userData});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  File? _pickedImage;
  bool _isSaving = false;

  // Colors
  final Color primaryOrange = const Color(0xFFEC5B13);
  final Color bgLight = const Color(0xFFF8F9FB);
  final Color slate100 = const Color(0xFFF1F5F9);
  final Color slate400 = const Color(0xFF94A3B8);
  final Color slate500 = const Color(0xFF64748B);
  final Color slate600 = const Color(0xFF475569);
  final Color slate700 = const Color(0xFF334155);
  final Color slate800 = const Color(0xFF1E293B);
  final Color slate900 = const Color(0xFF0F172A);

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.userData['name']);
    
    // Handle placeholder emails
    String email = widget.userData['email'] ?? '';
    if (email.contains('@citycourier.local')) {
      email = '';
    }
    _emailController = TextEditingController(text: email);
    _addressController = TextEditingController(text: widget.userData['address'] ?? '');
    _phoneController = TextEditingController(text: widget.userData['phone'] ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
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
              leading: const Icon(Icons.camera_alt),
              title: Text('Ambil Foto', style: TextStyle()),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text('Pilih dari Galeri', style: TextStyle()),
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
      final success = await ApiService.updateProfile(
        _nameController.text.trim(),
        _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        photoPath: _pickedImage?.path,
      );

      if (mounted) {
        if (success) {
          _showSnackBar('Profil berhasil diperbarui', Colors.green);
          Navigator.pop(context, true); // Return true to refresh parent
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
        content: Text(message, style: TextStyle()),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leadingWidth: 40,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back, color: slate700, size: 20),
        ),
        title: Text(
          'Profil Saya',
          style: TextStyle(
            color: slate800,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: _isSaving 
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: primaryOrange),
                  )
                : TextButton(
                    onPressed: _handleSave,
                    style: TextButton.styleFrom(
                      backgroundColor: primaryOrange.withValues(alpha: 0.1),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'Simpan',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: primaryOrange,
                      ),
                    ),
                  ),
            ),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              _buildAvatarSection(),
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('INFORMASI PRIBADI'),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Nama Lengkap',
                      controller: _nameController,
                      icon: Icons.person_outline_rounded,
                      hint: 'Masukkan nama lengkap',
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Email',
                      controller: _emailController,
                      icon: Icons.mail_outline_rounded,
                      hint: 'Masukkan alamat email',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Nomor Telepon',
                      controller: _phoneController,
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      hint: 'Masukkan nomor telepon',
                    ),
                    const SizedBox(height: 32),
                    _buildSectionHeader('ALAMAT'),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Alamat Lengkap',
                      controller: _addressController,
                      icon: Icons.location_on_outlined,
                      hint: 'Masukkan alamat pengiriman utama',
                      maxLines: 3,
                      suffixIcon: IconButton(
                        icon: Icon(Icons.map_rounded, color: primaryOrange),
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const DropPointPickerScreen(),
                            ),
                          );
                          
                          if (result != null && result['address'] != null) {
                            setState(() {
                              _addressController.text = result['address'];
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: slate500,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    TextEditingController? controller,
    String? initialValue,
    required IconData icon,
    required String hint,
    bool readOnly = false,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: slate700,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            initialValue: controller == null ? initialValue : null,
            readOnly: readOnly,
            keyboardType: keyboardType,
            maxLines: maxLines,
            style: TextStyle(
              fontSize: 14,
              color: readOnly ? slate500 : slate800,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: slate400, fontSize: 14),
              prefixIcon: Icon(icon, size: 20, color: readOnly ? slate400 : primaryOrange),
              suffixIcon: suffixIcon,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: primaryOrange.withValues(alpha: 0.5), width: 1.5),
              ),
              filled: true,
              fillColor: readOnly ? slate100.withValues(alpha: 0.5) : Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarSection() {
    String photoUrl = widget.userData['photo_url'] ?? '';

    // Handle relative URLs for existing photos
    if (photoUrl.isNotEmpty && !photoUrl.startsWith('http')) {
      final String cleanPath = photoUrl.startsWith('/') ? photoUrl : '/$photoUrl';
      photoUrl = 'https://citycourier.pabm.space/storage$cleanPath';
    }

    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(35),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(32),
              child: InkWell(
                onTap: _showImageSourceActionSheet,
                borderRadius: BorderRadius.circular(32),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: _pickedImage != null
                      ? Image.file(_pickedImage!, fit: BoxFit.cover)
                      : (photoUrl.isNotEmpty
                          ? Image.network(
                              photoUrl.startsWith('http')
                                  ? photoUrl
                                  : 'https://citycourier.pabm.space/storage/$photoUrl', 
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: bgLight,
                                child: Icon(Icons.person, size: 45, color: slate400),
                              ),
                            )
                          : Container(
                              color: bgLight,
                              child: Icon(Icons.person, size: 45, color: slate400),
                            )),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -5,
            right: -5,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _showImageSourceActionSheet,
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryOrange,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: primaryOrange.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
