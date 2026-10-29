import 'package:flutter/material.dart';
import 'package:city_courierapp/screens/widgets/home/theme_toggle_fab.dart';
import 'package:city_courierapp/screens/home/shipping/select_region_screen.dart';
import 'package:city_courierapp/services/address_service.dart';
import 'package:city_courierapp/data/models/address_model.dart';
import 'package:city_courierapp/screens/maps/location_picker_screen.dart';
import 'package:city_courierapp/services/maps/location_repository.dart';
import 'package:city_courierapp/services/maps/nominatim_geocoding_service.dart';
import 'package:city_courierapp/core/utils/address_region.dart';

class AddSenderScreen extends StatefulWidget {
  final String title;
  final String subtitle;
  final String pickerTitle;
  final bool isReceiver;

  const AddSenderScreen({
    super.key,
    this.title = 'Tambah Pengirim Baru',
    this.subtitle = 'Lengkapi data pengirim & alamat pengiriman',
    this.pickerTitle = 'Set lokasi pengiriman',
    this.isReceiver = false,
  });

  @override
  State<AddSenderScreen> createState() => _AddSenderScreenState();
}

class _AddSenderScreenState extends State<AddSenderScreen> {
  bool isDarkMode = false;
  bool _isSaving = false;
  bool _isLoadingMap = false;
  bool _isAutoMatchedRegion = false;
  bool _showUnmatchedWarning = false;

  Map<String, dynamic>? selectedCity;
  Address? selectedAddressModel;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController addressController = TextEditingController();

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFEC5B13);
    final bgLight = const Color(0xFFFFFFFF);
    final bgDark = const Color(0xFF0F172A);

    return Theme(
      data: isDarkMode
          ? ThemeData.dark().copyWith(
              scaffoldBackgroundColor: bgDark,
              colorScheme: ColorScheme.dark(
                primary: primaryColor,
                surface: const Color(0xFF1E293B),
              ),
            )
          : ThemeData.light().copyWith(
              scaffoldBackgroundColor: bgLight,
              colorScheme: ColorScheme.light(
                primary: primaryColor,
                surface: Colors.white,
              ),
            ),
      child: Scaffold(
        backgroundColor: isDarkMode ? bgDark : bgLight,
        body: Stack(
          children: [
            Column(
              children: [
                _buildHeader(context, primaryColor),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 28),

                        // 1. Nama Lengkap
                        _buildInputField(
                          controller: nameController,
                          label: 'Nama Lengkap',
                          hintText: 'Masukkan nama lengkap',
                          icon: Icons.person_outline,
                          isDarkMode: isDarkMode,
                          primaryColor: primaryColor,
                        ),
                        const SizedBox(height: 20),

                        // 2. Nomor Telepon
                        _buildInputField(
                          controller: phoneController,
                          label: 'Nomor Telepon',
                          hintText: 'Contoh: 081234567890',
                          icon: Icons.call_outlined,
                          keyboardType: TextInputType.phone,
                          isDarkMode: isDarkMode,
                          primaryColor: primaryColor,
                        ),
                        const SizedBox(height: 20),

                        // 3. Alamat Lengkap with [📍 Pilih dari Peta]
                        _buildAddressField(
                          context: context,
                          controller: addressController,
                          label: 'Alamat Lengkap',
                          hintText: 'Masukkan alamat lengkap (Nama Jalan, No Rumah, RT/RW)',
                          icon: Icons.home_outlined,
                          maxLines: 3,
                          isDarkMode: isDarkMode,
                          primaryColor: primaryColor,
                        ),

                        // Koordinat badge if location picked
                        if (selectedAddressModel != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isDarkMode
                                    ? const Color(0xFF1E293B)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isDarkMode
                                      ? Colors.grey.shade800
                                      : Colors.grey.shade300,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.my_location,
                                    size: 16,
                                    color: Color(0xFFEC5B13),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Koordinat: ${selectedAddressModel!.latitude.toStringAsFixed(6)}, ${selectedAddressModel!.longitude.toStringAsFixed(6)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontFamily: 'monospace',
                                        color: isDarkMode
                                            ? Colors.grey.shade300
                                            : Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: _openLocationPicker,
                                    child: const Text(
                                      'Ubah di Peta',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFEC5B13),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        const SizedBox(height: 20),

                        // 4. Field Wilayah RajaOngkir (Section 5 & 6)
                        _buildRegionField(
                          context: context,
                          isDarkMode: isDarkMode,
                          primaryColor: primaryColor,
                        ),

                        const SizedBox(height: 28),

                        // 5. Tombol Simpan
                        _buildSaveButton(primaryColor),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            ThemeToggleFab(
              onToggle: () {
                setState(() {
                  isDarkMode = !isDarkMode;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Color primaryColor) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 24,
        bottom: 28,
        left: 24,
        right: 24,
      ),
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.subtitle,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    TextEditingController? controller,
    required String label,
    required String hintText,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    required bool isDarkMode,
    required Color primaryColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: TextStyle(
              color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDarkMode
                ? const Color(0xFF0F172A).withOpacity(0.5)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
            ),
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black87,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(
                color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400,
                fontSize: 14,
              ),
              prefixIcon: Padding(
                padding: EdgeInsets.only(
                  bottom: maxLines > 1 ? (maxLines * 16.0) - 24 : 0,
                ),
                child: Icon(
                  icon,
                  color: isDarkMode
                      ? Colors.grey.shade500
                      : Colors.grey.shade400,
                  size: 20,
                ),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Alamat Lengkap with [📍 Pilih dari Peta] Button ────────────────
  Widget _buildAddressField({
    required BuildContext context,
    TextEditingController? controller,
    required String label,
    required String hintText,
    required IconData icon,
    int maxLines = 3,
    required bool isDarkMode,
    required Color primaryColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              // Tombol Header: 📍 Pilih dari Peta
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: _openLocationPicker,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_on, size: 14, color: Color(0xFFEC5B13)),
                      SizedBox(width: 4),
                      Text(
                        'Pilih dari Peta',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFEC5B13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDarkMode
                ? const Color(0xFF0F172A).withOpacity(0.5)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
            ),
          ),
          child: Stack(
            children: [
              TextField(
                controller: controller,
                maxLines: maxLines,
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black87,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: _isLoadingMap ? 'Membuka Peta...' : hintText,
                  hintStyle: TextStyle(
                    color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400,
                    fontSize: 14,
                  ),
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(
                      bottom: maxLines > 1 ? (maxLines * 16.0) - 24 : 0,
                    ),
                    child: Icon(
                      icon,
                      color: isDarkMode
                          ? Colors.grey.shade500
                          : Colors.grey.shade400,
                      size: 20,
                    ),
                  ),
                  // Icon 📍 di sebelah kanan input
                  suffixIcon: _isLoadingMap
                      ? Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: primaryColor,
                            ),
                          ),
                        )
                      : Tooltip(
                          message: 'Pilih dari Peta',
                          child: IconButton(
                            icon: const Icon(
                              Icons.location_on,
                              color: Color(0xFFEC5B13),
                              size: 26,
                            ),
                            onPressed: _openLocationPicker,
                          ),
                        ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Field Wilayah RajaOngkir (Section 5 & 6) ──────────────────────
  Widget _buildRegionField({
    required BuildContext context,
    required bool isDarkMode,
    required Color primaryColor,
  }) {
    final regionLabel = selectedCity != null
        ? (selectedCity!['kelurahan_name'] != null
            ? '${selectedCity!['kelurahan_name']}, ${selectedCity!['kecamatan_name']}, ${selectedCity!['kabupaten_name']}'
            : (selectedCity!['subdistrict_name'] != null
                ? '${selectedCity!['subdistrict_name']}, ${selectedCity!['city_name']}'
                : selectedCity!['city_name']))
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Wilayah (RajaOngkir)',
                style: TextStyle(
                  color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (selectedCity != null)
                InkWell(
                  onTap: () async {
                    await _openManualRegionPicker();
                  },
                  child: const Text(
                    'Ubah Wilayah',
                    style: TextStyle(
                      color: Color(0xFFEC5B13),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Box Wilayah
        GestureDetector(
          onTap: () async {
            await _openManualRegionPicker();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? const Color(0xFF0F172A).withOpacity(0.5)
                  : (_isAutoMatchedRegion
                      ? const Color(0xFFF0FDF4)
                      : Colors.grey.shade50),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isAutoMatchedRegion
                    ? const Color(0xFF86EFAC)
                    : (isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.apartment_rounded,
                  color: _isAutoMatchedRegion
                      ? const Color(0xFF16A34A)
                      : (isDarkMode ? Colors.grey.shade500 : Colors.grey.shade400),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        regionLabel ?? 'Pilih Kelurahan atau Kecamatan',
                        style: TextStyle(
                          color: regionLabel != null
                              ? (isDarkMode ? Colors.white : Colors.black87)
                              : (isDarkMode
                                  ? Colors.grey.shade600
                                  : Colors.grey.shade400),
                          fontSize: 14,
                          fontWeight: regionLabel != null
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                      if (_isAutoMatchedRegion)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            '✓ Wilayah terdeteksi otomatis',
                            style: TextStyle(
                              color: Color(0xFF15803D),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down,
                  color: isDarkMode
                      ? Colors.grey.shade500
                      : Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),

        // Fallback Warning jika wilayah belum dapat dicocokkan otomatis (Section 6)
        if (_showUnmatchedWarning && selectedCity == null)
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFD97706),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Wilayah belum dapat dicocokkan secara otomatis. Silakan pilih wilayah secara manual.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF92400E),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: _openManualRegionPicker,
                        child: const Text(
                          'Pilih Wilayah Manual Sekarang →',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFFB45309),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _openManualRegionPicker() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SelectRegionScreen(),
      ),
    );
    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        selectedCity = result;
        _isAutoMatchedRegion = false;
        _showUnmatchedWarning = false;
      });
    }
  }

  // ── Tombol Simpan ─────────────────────────────────────────────────
  Widget _buildSaveButton(Color primaryColor) {
    return GestureDetector(
      onTap: _isSaving ? null : () async {
        if (nameController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nama lengkap tidak boleh kosong')),
          );
          return;
        }

        if (phoneController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nomor telepon tidak boleh kosong')),
          );
          return;
        }

        if (addressController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Alamat lengkap tidak boleh kosong')),
          );
          return;
        }

        // Gate wilayah: Wilayah RajaOngkir harus terisi untuk kebutuhan ongkir
        if (selectedCity == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Silakan pilih wilayah RajaOngkir terlebih dahulu (dari peta atau manual)',
              ),
            ),
          );
          await _openManualRegionPicker();
          if (!mounted || selectedCity == null) return;
        }

        setState(() => _isSaving = true);

        String fullAddress = addressController.text.replaceAll(RegExp(r',\s*$'), '').trim();

        Address? resolvedAddress = selectedAddressModel;
        if (resolvedAddress == null) {
          final repo = LocationRepository();
          var results = await _searchGeocodeSafe(repo, fullAddress.trim());
          if (results.isEmpty) {
            final region = extractRegion(fullAddress);
            if (region.isNotEmpty) {
              results = await _searchGeocodeSafe(repo, region);
            }
          }
          if (results.isNotEmpty) {
            resolvedAddress = results.first;
          }
        }

        final body = {
          'name': nameController.text.trim(),
          'phone': phoneController.text.trim(),
          'address': fullAddress.trim(),
          'city_id': selectedCity?['city_id'] ?? selectedCity?['kabupaten_id'] ?? selectedCity?['rajaongkir_city_id'],
          'city_name': selectedCity?['city_name'] ?? selectedCity?['kabupaten_name'],
          'province_id': selectedCity?['province_id'] ?? selectedCity?['provinsi_id'],
          'province_name': selectedCity?['province_name'] ?? selectedCity?['provinsi_name'],
          'subdistrict_id': selectedCity?['subdistrict_id'] ?? selectedCity?['kecamatan_id'] ?? selectedCity?['rajaongkir_subdistrict_id'] ?? selectedCity?['rajaongkir_region_id'],
          'subdistrict_name': selectedCity?['subdistrict_name'] ?? selectedCity?['kecamatan_name'] ?? selectedCity?['kelurahan_name'],
          'latitude': resolvedAddress?.latitude,
          'longitude': resolvedAddress?.longitude,
          'is_favorite': false,
        };

        final saved = await AddressService.saveAddress(body);

        if (!mounted) return;
        setState(() => _isSaving = false);

        if (saved != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pengirim dan alamat berhasil disimpan'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, saved);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal menyimpan alamat. Coba lagi.')),
          );
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: _isSaving ? primaryColor.withOpacity(0.6) : primaryColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              _isSaving ? 'Menyimpan...' : 'Gunakan & Simpan Lokasi',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Buka LocationPicker untuk menandai titik lokasi di peta.
  Future<void> _openLocationPicker() async {
    if (mounted) setState(() => _isLoadingMap = true);

    try {
      Address initialAddr;
      if (selectedAddressModel != null) {
        initialAddr = selectedAddressModel!;
      } else if (selectedCity != null) {
        final parts = [
          selectedCity!['kelurahan_name'] ?? selectedCity!['subdistrict_name'],
          selectedCity!['kecamatan_name'],
          selectedCity!['kabupaten_name'] ?? selectedCity!['city_name'],
        ].where((e) => e != null && e.toString().trim().isNotEmpty).toList();

        final regionStr = parts.join(', ');
        final geoService = NominatimGeocodingService();
        final results = await geoService.searchAddress(regionStr.trim());

        if (results.isNotEmpty) {
          initialAddr = results.first;
        } else {
          initialAddr = Address(
            latitude: -7.2575, // Surabaya default
            longitude: 112.7521,
            formattedAddress: regionStr.trim(),
            locationSource: 'provider',
          );
        }
      } else {
        // Default to Surabaya/current center
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
            title: widget.pickerTitle,
          ),
        ),
      );

      if (result != null) {
        if (result is LocationPickerResult) {
          setState(() {
            selectedAddressModel = result;
            addressController.text = result.formattedAddress;

            if (result.isRajaOngkirMatched && result.rajaOngkirMatch != null) {
              final match = result.rajaOngkirMatch!;
              _isAutoMatchedRegion = true;
              _showUnmatchedWarning = false;
              selectedCity = {
                'kelurahan_name': match['subdistrict_name'] ?? match['village'],
                'kecamatan_name': match['district_name'] ?? match['kecamatan_name'],
                'kabupaten_name': match['city_name'] ?? match['kabupaten_name'],
                'provinsi_name': match['province_name'] ?? match['provinsi_name'],
                'subdistrict_id': match['rajaongkir_subdistrict_id'] ?? match['rajaongkir_region_id'],
                'city_id': match['rajaongkir_city_id'] ?? match['city_id'],
                'province_id': match['province_id'],
                'subdistrict_name': match['subdistrict_name'] ?? match['district_name'],
                'city_name': match['city_name'],
                'province_name': match['province_name'],
              };

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '✓ Wilayah RajaOngkir cocok: ${match['full_label'] ?? match['district_name']}',
                  ),
                  backgroundColor: const Color(0xFF15803D),
                  duration: const Duration(seconds: 3),
                ),
              );
            } else {
              _isAutoMatchedRegion = false;
              _showUnmatchedWarning = true;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Wilayah belum dapat dicocokkan secara otomatis. Silakan pilih wilayah secara manual.',
                  ),
                  backgroundColor: Color(0xFFD97706),
                  duration: Duration(seconds: 4),
                ),
              );
            }
          });
        } else if (result is Address) {
          setState(() {
            selectedAddressModel = result;
            addressController.text = result.formattedAddress;
            _showUnmatchedWarning = selectedCity == null;
          });
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingMap = false);
      }
    }
  }

  /// Geocode search yang aman (tak melempar) memakai LocationRepository.
  Future<List<Address>> _searchGeocodeSafe(
    LocationRepository repo,
    String query,
  ) async {
    try {
      return await repo.searchAddress(query, minResults: 1);
    } catch (_) {
      return const <Address>[];
    }
  }
}
