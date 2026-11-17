import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:city_courierapp/data/models/address_model.dart';
import 'package:city_courierapp/screens/maps/location_picker_screen.dart';
import 'package:city_courierapp/services/api_service.dart';
import 'package:city_courierapp/services/maps/location_repository.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final LocationRepository? locationRepository;
  final Future<Map<String, dynamic>> Function({
    required String name,
    String? email,
    String? address,
    String? photoPath,
  })? onSaveProfile;

  const EditProfileScreen({
    super.key,
    required this.userData,
    this.locationRepository,
    this.onSaveProfile,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  late TextEditingController _otpController;
  File? _pickedImage;
  bool _isSaving = false;
  bool _isLoadingMap = false;
  Address? _selectedAddressModel;

  String _verifiedPhone = '';
  bool _phoneVerified = false;
  bool _otpSent = false;
  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;
  int _cooldown = 0;
  Timer? _cooldownTimer;

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

  String _normalizePhone(String value) {
    var digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('0062')) {
      digits = '0${digits.substring(4)}';
    } else if (digits.startsWith('62')) {
      digits = '0${digits.substring(2)}';
    }
    return digits;
  }

  bool get _isGoogleEmail {
    final email = _emailController.text.trim();
    return email.isNotEmpty && !email.contains('@citycourier.local');
  }

  bool get _isCurrentPhoneVerified {
    final current = _normalizePhone(_phoneController.text);
    return _phoneVerified &&
        current.isNotEmpty &&
        current == _normalizePhone(_verifiedPhone);
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: (widget.userData['name'] ?? '').toString(),
    );

    // Handle placeholder emails
    String email = (widget.userData['email'] ?? '').toString();
    if (email.contains('@citycourier.local')) {
      email = '';
    }
    _emailController = TextEditingController(text: email);
    _addressController = TextEditingController(
      text: (widget.userData['address'] ?? '').toString(),
    );
    final initialPhone = (widget.userData['phone'] ?? '').toString();
    _phoneController = TextEditingController(text: initialPhone);
    _otpController = TextEditingController();

    _phoneVerified = widget.userData['phone_verified'] == true;
    _verifiedPhone = _phoneVerified ? initialPhone : '';

    _phoneController.addListener(() {
      if (mounted) {
        setState(() {
          if (_otpSent &&
              _normalizePhone(_phoneController.text) != _verifiedPhone) {
            // Keep UI reactive when phone input changes
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _nameController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _startCooldown(int seconds) {
    _cooldownTimer?.cancel();
    final duration = seconds <= 0 ? 60 : seconds;
    if (!mounted) return;
    setState(() => _cooldown = duration);

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldown <= 1) {
        timer.cancel();
        setState(() => _cooldown = 0);
      } else {
        setState(() => _cooldown--);
      }
    });
  }

  Future<void> _requestPhoneOtp() async {
    if (_isSendingOtp || _isVerifyingOtp || _cooldown > 0) return;

    final normalized = _normalizePhone(_phoneController.text);
    if (!RegExp(r'^08[0-9]{8,11}$').hasMatch(normalized)) {
      _showSnackBar(
        'Masukkan nomor HP Indonesia yang valid, contoh 081234567890.',
        Colors.red,
      );
      return;
    }

    setState(() => _isSendingOtp = true);

    try {
      final result = await ApiService.requestPhoneOtp(
        _phoneController.text.trim(),
      );
      if (!mounted) return;

      if (result['success'] == true) {
        final alreadyVerified = result['already_verified'] == true;
        setState(() {
          _isSendingOtp = false;
          _otpSent = !alreadyVerified;
          if (alreadyVerified) {
            _phoneVerified = true;
            _verifiedPhone = normalized;
          }
        });
        _startCooldown((result['retry_after'] as num?)?.toInt() ?? 60);
        _showSnackBar(
          (result['message'] ?? 'Kode OTP telah dikirim ke nomor telepon Anda.')
              .toString(),
          slate800,
        );
      } else {
        final retryAfter = (result['retry_after'] as num?)?.toInt();
        if (retryAfter != null && retryAfter > 0) {
          _startCooldown(retryAfter);
        }
        setState(() => _isSendingOtp = false);
        _showSnackBar(
          (result['message'] ?? 'Gagal mengirim kode OTP.').toString(),
          Colors.red,
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSendingOtp = false);
      _showSnackBar('Tidak dapat terhubung ke server.', Colors.red);
    }
  }

  Future<void> _verifyPhoneOtp() async {
    if (_isVerifyingOtp || _isSendingOtp) return;

    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      _showSnackBar('Masukkan 6 digit kode OTP.', Colors.red);
      return;
    }

    setState(() => _isVerifyingOtp = true);

    try {
      final result = await ApiService.verifyPhoneOtp(
        _phoneController.text.trim(),
        otp,
      );
      if (!mounted) return;

      if (result['success'] == true) {
        final normalized = _normalizePhone(_phoneController.text);
        setState(() {
          _isVerifyingOtp = false;
          _phoneVerified = true;
          _verifiedPhone = normalized;
          _phoneController.text = normalized;
          _otpSent = false;
          _otpController.clear();
        });
        _showSnackBar(
          (result['message'] ?? 'Nomor telepon berhasil diverifikasi.')
              .toString(),
          Colors.green,
        );
      } else {
        setState(() => _isVerifyingOtp = false);
        _showSnackBar(
          (result['message'] ??
                  'Kode OTP yang Anda masukkan salah. Silakan coba lagi.')
              .toString(),
          Colors.red,
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isVerifyingOtp = false);
      _showSnackBar('Tidak dapat terhubung ke server.', Colors.red);
    }
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

    if (!_isCurrentPhoneVerified) {
      _showSnackBar(
        'Nomor telepon wajib diverifikasi dengan kode OTP terlebih dahulu.',
        Colors.red,
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final saveProfile = widget.onSaveProfile ?? ApiService.updateProfileResult;
      final result = await saveProfile(
        name: _nameController.text.trim(),
        email: _isGoogleEmail ? null : _emailController.text.trim(),
        address: _addressController.text.trim(),
        photoPath: _pickedImage?.path,
      );

      if (mounted) {
        if (result['success'] == true) {
          _showSnackBar('Profil berhasil diperbarui', Colors.green);
          Navigator.pop(context, true); // Return true to refresh parent
        } else {
          _showSnackBar(
            (result['message'] ?? 'Gagal memperbarui profil').toString(),
            Colors.red,
          );
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
                      readOnly: _isGoogleEmail,
                      suffixIcon: _isGoogleEmail
                          ? Icon(
                              Icons.lock_outline_rounded,
                              size: 18,
                              color: slate400,
                            )
                          : null,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Nomor Telepon / WhatsApp',
                      controller: _phoneController,
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      hint: 'Contoh: 081234567890',
                      suffixIcon: _isCurrentPhoneVerified
                          ? const Icon(
                              Icons.verified_rounded,
                              color: Color(0xFF059669),
                              size: 20,
                            )
                          : null,
                    ),
                    if (!_isCurrentPhoneVerified) ...[
                      const SizedBox(height: 12),
                      _buildPhoneOtpSection(),
                    ],
                    const SizedBox(height: 32),
                    _buildSectionHeader('ALAMAT'),
                    const SizedBox(height: 16),
                    _buildAddressField(),
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

  double? _parseCoordinate(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  Address _resolveAddressData(Address result) {
    final match = result is LocationPickerResult ? result.rajaOngkirMatch : null;
    final subdistrictFromMatch =
        (match != null &&
                match['subdistrict_name'] != null &&
                match['subdistrict_name'] != match['district_name'])
            ? match['subdistrict_name']?.toString()
            : null;

    final village = result.village ??
        result.neighbourhood ??
        match?['village']?.toString() ??
        subdistrictFromMatch;
    final district = result.district ??
        match?['district_name']?.toString() ??
        match?['kecamatan_name']?.toString();
    final city = result.city ??
        match?['city_name']?.toString() ??
        match?['kabupaten_name']?.toString();
    final province = result.province ??
        match?['province_name']?.toString() ??
        match?['provinsi_name']?.toString();
    final postalCode = result.postalCode ??
        match?['postal_code']?.toString() ??
        match?['map_postal_code']?.toString();

    return result.copyWith(
      village: village,
      district: district,
      city: city,
      province: province,
      postalCode: postalCode,
      latitude: result.latitude,
      longitude: result.longitude,
    );
  }

  String _formatSelectedAddress(Address address) {
    final rawBase = address.formattedAddress.trim();
    final isCoordinateFallback =
        RegExp(r'^Lokasi\s*\([-\d.,\s]+\)$').hasMatch(rawBase);
    final base = isCoordinateFallback ? '' : rawBase;
    final parts = <String>[];

    if (base.isNotEmpty) {
      parts.add(base);
    }

    final adminPrefixRegex = RegExp(
      r'^(provinsi|prov\.|kota\s+administrasi|kabupaten\s+administrasi|kabupaten|kab\.|kota|kecamatan|kec\.|kelurahan|kel\.|desa)\s+',
      caseSensitive: false,
    );

    String normalizeSegment(String value) {
      return value
          .toLowerCase()
          .replaceAll(adminPrefixRegex, '')
          .replaceAll(RegExp(r'\s+\d{5}$'), '')
          .trim();
    }

    bool containsPart(String candidate, {bool isStreet = false, bool isPostal = false}) {
      final lowerCandidate = normalizeSegment(candidate);
      if (lowerCandidate.isEmpty) return true;
      final segments = parts.expand((p) => p.split(',')).map((s) => s.trim());
      if (isPostal) {
        final postalRegex = RegExp('\\b${RegExp.escape(candidate.trim())}\\b');
        return segments.any((seg) => postalRegex.hasMatch(seg));
      }
      if (isStreet) {
        return segments.any(
          (seg) => seg.toLowerCase().contains(lowerCandidate),
        );
      }
      return segments.any((seg) => normalizeSegment(seg) == lowerCandidate);
    }

    if (address.streetName != null && address.streetName!.trim().isNotEmpty) {
      var street = address.streetName!.trim();
      if (address.houseNumber != null &&
          address.houseNumber!.trim().isNotEmpty &&
          !street.toLowerCase().contains(
                address.houseNumber!.trim().toLowerCase(),
              )) {
        street = '$street No. ${address.houseNumber!.trim()}';
      }
      if (!containsPart(street, isStreet: true)) {
        parts.add(street);
      }
    }

    final village = address.village ?? address.neighbourhood;
    if (village != null &&
        village.trim().isNotEmpty &&
        !containsPart(village)) {
      parts.add(village.trim());
    }

    if (address.district != null &&
        address.district!.trim().isNotEmpty &&
        !containsPart(address.district!)) {
      final dist = address.district!.trim();
      parts.add(dist.toLowerCase().startsWith('kec') ? dist : 'Kec. $dist');
    }

    if (address.city != null &&
        address.city!.trim().isNotEmpty &&
        !containsPart(address.city!)) {
      parts.add(address.city!.trim());
    }

    if (address.province != null &&
        address.province!.trim().isNotEmpty &&
        !containsPart(address.province!)) {
      parts.add(address.province!.trim());
    }

    if (address.postalCode != null &&
        address.postalCode!.trim().isNotEmpty &&
        !containsPart(address.postalCode!, isPostal: true)) {
      parts.add(address.postalCode!.trim());
    }

    return parts.join(', ');
  }

  Future<void> _openLocationPicker() async {
    if (_isLoadingMap) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoadingMap = true);

    try {
      Address initialAddr;
      if (_selectedAddressModel != null) {
        initialAddr = _selectedAddressModel!;
      } else if (_addressController.text.trim().isNotEmpty) {
        final lat = _parseCoordinate(widget.userData['latitude']) ?? -7.2575;
        final lng = _parseCoordinate(widget.userData['longitude']) ?? 112.7521;
        initialAddr = Address(
          latitude: lat,
          longitude: lng,
          formattedAddress: _addressController.text.trim(),
          streetName: widget.userData['street_name']?.toString(),
          village: (widget.userData['village'] ??
                  widget.userData['kelurahan_name'] ??
                  widget.userData['subdistrict_name'])
              ?.toString(),
          district: (widget.userData['district'] ??
                  widget.userData['kecamatan_name'] ??
                  widget.userData['district_name'])
              ?.toString(),
          city: (widget.userData['city'] ??
                  widget.userData['city_name'] ??
                  widget.userData['kabupaten_name'])
              ?.toString(),
          province: (widget.userData['province'] ??
                  widget.userData['province_name'] ??
                  widget.userData['provinsi_name'])
              ?.toString(),
          postalCode: (widget.userData['postal_code'] ??
                  widget.userData['zip_code'])
              ?.toString(),
          locationSource: 'provider',
        );
      } else {
        initialAddr = Address(
          latitude: -7.2575,
          longitude: 112.7521,
          formattedAddress: 'Surabaya, Jawa Timur',
          locationSource: 'provider',
        );
      }

      if (!mounted) return;

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LocationPickerScreen(
            initialAddress: initialAddr,
            title: 'Set lokasi pengiriman',
            locationRepository: widget.locationRepository,
          ),
        ),
      );

      if (!mounted || result == null) return;

      if (result is Address) {
        final resolved = _resolveAddressData(result);
        final formatted = _formatSelectedAddress(resolved);
        if (formatted.isEmpty) {
          _showSnackBar(
            'Lokasi gagal ditemukan. Silakan pilih titik lokasi lain.',
            Colors.red,
          );
          return;
        }
        setState(() {
          _selectedAddressModel = resolved;
          _addressController.text = formatted;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingMap = false);
      }
    }
  }

  Widget _buildAddressField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _openLocationPicker,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Alamat Lengkap',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: slate700,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1EB),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_on, size: 14, color: primaryOrange),
                    const SizedBox(width: 4),
                    Text(
                      'Pilih dari Peta',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: primaryOrange,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
            controller: _addressController,
            readOnly: true,
            onTap: _openLocationPicker,
            maxLines: 3,
            style: TextStyle(
              fontSize: 14,
              color: slate800,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: _isLoadingMap
                  ? 'Membuka Peta...'
                  : 'Masukkan alamat pengiriman utama',
              hintStyle: TextStyle(color: slate400, fontSize: 14),
              prefixIcon: Icon(
                Icons.location_on_outlined,
                size: 20,
                color: primaryOrange,
              ),
              suffixIcon: IconButton(
                icon: Icon(Icons.map_rounded, color: primaryOrange),
                onPressed: _openLocationPicker,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: primaryOrange.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),
      ],
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

  Widget _buildPhoneOtpSection() {
    if (!_otpSent) {
      return SizedBox(
        width: double.infinity,
        height: 46,
        child: ElevatedButton(
          onPressed: (_isSendingOtp || _isVerifyingOtp || _cooldown > 0)
              ? null
              : _requestPhoneOtp,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryOrange,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: _isSendingOtp
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  _cooldown > 0
                      ? 'Kirim OTP dalam ${_cooldown}s'
                      : 'Kirim OTP Verifikasi Nomor',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(
          label: 'Kode OTP (6 Digit)',
          controller: _otpController,
          icon: Icons.password_rounded,
          hint: 'Masukkan 6 digit kode OTP',
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: (_isVerifyingOtp || _isSendingOtp)
                    ? null
                    : _verifyPhoneOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryOrange,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isVerifyingOtp
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Verifikasi OTP',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            TextButton(
              onPressed: (_cooldown > 0 || _isSendingOtp || _isVerifyingOtp)
                  ? null
                  : _requestPhoneOtp,
              child: Text(
                _cooldown > 0 ? 'Ulang (${_cooldown}s)' : 'Kirim Ulang',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: primaryOrange,
                ),
              ),
            ),
          ],
        ),
      ],
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
      photoUrl = 'https://www.neonflux.my.id/storage$cleanPath';
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
                                  : 'https://www.neonflux.my.id/storage/$photoUrl', 
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
