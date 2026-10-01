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
  const AddSenderScreen({Key? key}) : super(key: key);

  @override
  State<AddSenderScreen> createState() => _AddSenderScreenState();
}

class _AddSenderScreenState extends State<AddSenderScreen> {
  bool isDarkMode = false;
  bool _isSaving = false;
  bool _isLoadingMap = false;
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
                        const SizedBox(height: 32),
                        _buildInputField(
                          controller: nameController,
                          label: 'Nama Lengkap',
                          hintText: 'Masukkan nama lengkap',
                          icon: Icons.person,
                          isDarkMode: isDarkMode,
                          primaryColor: primaryColor,
                        ),
                        const SizedBox(height: 24),
                        _buildInputField(
                          controller: phoneController,
                          label: 'Nomor Telepon',
                          hintText: 'Contoh: 081234567890',
                          icon: Icons.call,
                          keyboardType: TextInputType.phone,
                          isDarkMode: isDarkMode,
                          primaryColor: primaryColor,
                        ),
                        const SizedBox(height: 24),
                        _buildDropdownField(
                          context: context,
                          label: 'Pilih Kelurahan/Kecamatan',
                          hintText: 'Pilih Kelurahan atau Kecamatan',
                          icon: Icons.location_on,
                          isDarkMode: isDarkMode,
                          primaryColor: primaryColor,
                        ),
                        const SizedBox(height: 24),
                        _buildAddressField(
                          context: context,
                          controller: addressController,
                          label: 'Alamat Lengkap',
                          hintText: 'Masukkan alamat lengkap pengirim (No Rumah, RT/RW)',
                          icon: Icons.home,
                          maxLines: 3,
                          isDarkMode: isDarkMode,
                          primaryColor: primaryColor,
                        ),
                        const SizedBox(height: 24),
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
        bottom: 32,
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
              const Text(
                'Tambah Pengirim Baru',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Lengkapi data pengirim paket',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
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
              color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
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

  Widget _buildAddressField({
    required BuildContext context,
    TextEditingController? controller,
    required String label,
    required String hintText,
    required IconData icon,
    int maxLines = 1,
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
              color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
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
                      : IconButton(
                          icon: Icon(
                            Icons.map,
                            color: primaryColor,
                            size: 24,
                          ),
                          onPressed: () async {
                            await _openLocationPicker();
                          },
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

  Widget _buildDropdownField({
    required BuildContext context,
    required String label,
    required String hintText,
    required IconData icon,
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
        GestureDetector(
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SelectRegionScreen(),
              ),
            );
            if (result != null && result is Map<String, dynamic>) {
              setState(() {
                selectedCity = result;
              });
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: isDarkMode
                  ? const Color(0xFF0F172A).withOpacity(0.5)
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isDarkMode
                      ? Colors.grey.shade500
                      : Colors.grey.shade400,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    selectedCity != null
                        ? (selectedCity!['kelurahan_name'] != null
                            ? '${selectedCity!['kelurahan_name']}, ${selectedCity!['kecamatan_name']}, ${selectedCity!['kabupaten_name']}'
                            : (selectedCity!['subdistrict_name'] != null
                                ? '${selectedCity!['subdistrict_name']}, ${selectedCity!['city_name']}'
                                : selectedCity!['city_name']))
                        : hintText,
                    style: TextStyle(
                      color: selectedCity != null
                          ? (isDarkMode ? Colors.white : Colors.black87)
                          : (isDarkMode
                                ? Colors.grey.shade600
                                : Colors.grey.shade400),
                      fontSize: 14,
                    ),
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
      ],
    );
  }

  Widget _buildSaveButton(Color primaryColor) {
    return GestureDetector(
      onTap: _isSaving ? null : () async {
        if (nameController.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nama tidak boleh kosong')),
          );
          return;
        }

        // Gate wajib-pilih-lokasi-peta: pengguna harus menandai titik lokasi
        // pengiriman di peta agar koordinat yang tersimpan akurat. Kalau
        // belum, buka picker lokasi secara langsung.
        if (selectedAddressModel == null) {
          if (selectedCity == null) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Pilih Kelurahan/Kecamatan terlebih dahulu dari dropdown di atas')),
              );
            }
            return;
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Tandai lokasi pengiriman di peta terlebih dahulu (ikon peta di kolom alamat)')),
            );
          }
          await _openLocationPicker();
          if (!mounted || selectedAddressModel == null) return;
        }

        setState(() => _isSaving = true);

        String fullAddress = addressController.text.replaceAll(RegExp(r',\s*$'), '').trim();
        if (selectedCity != null) {
          List<String> parts = [];
          
          String kelurahan = selectedCity!['kelurahan_name'] ?? '';
          String kecamatan = selectedCity!['kecamatan_name'] ?? selectedCity!['subdistrict_name'] ?? '';
          String kota = selectedCity!['kabupaten_name'] ?? selectedCity!['city_name'] ?? '';
          String provinsi = selectedCity!['provinsi_name'] ?? selectedCity!['province_name'] ?? '';
          String zip = selectedCity!['zip_code'] ?? '';

          if (kelurahan.isNotEmpty) parts.add(kelurahan);
          if (kecamatan.isNotEmpty) parts.add('Kec. $kecamatan');
          if (kota.isNotEmpty) parts.add(kota);
          
          String provZip = [provinsi, zip].where((e) => e.isNotEmpty).join(' ');
          if (provZip.isNotEmpty) parts.add(provZip);

          if (parts.isNotEmpty) {
            fullAddress += ', ' + parts.join(', ');
          }
        }

        // Ambil / cari koordinat secara otomatis bila pengguna belum menandai
        // lokasi di peta. Prioritas: titik dari LocationPicker → geocode alamat
        // penuh → geocode wilayah (kecamatan/kota) sebagai cadangan.
        Address? resolvedAddress = selectedAddressModel;
        if (resolvedAddress == null) {
          final repo = LocationRepository();
          var results = await _searchGeocodeSafe(repo, fullAddress.trim());
          if (results.isEmpty) {
            final region = extractRegion(fullAddress);
            if (region.isNotEmpty) {
              // ignore: avoid_print
              print('DEBUG GEOCODE(save): retrying with region: $region');
              results = await _searchGeocodeSafe(repo, region);
            }
          }
          if (results.isNotEmpty) {
            resolvedAddress = results.first;
          }
        }

        final body = {
          'name':             nameController.text,
          'phone':            phoneController.text,
          'address':          fullAddress.trim(),
          'city_id':          selectedCity?['city_id'] ?? selectedCity?['kabupaten_id'],
          'city_name':        selectedCity?['city_name'] ?? selectedCity?['kabupaten_name'],
          'province_id':      selectedCity?['province_id'] ?? selectedCity?['provinsi_id'],
          'province_name':    selectedCity?['province_name'] ?? selectedCity?['provinsi_name'],
          'subdistrict_id':   selectedCity?['subdistrict_id'] ?? selectedCity?['kecamatan_id'],
          'subdistrict_name': selectedCity?['subdistrict_name'] ?? selectedCity?['kecamatan_name'],
          'latitude':         resolvedAddress?.latitude,
          'longitude':        resolvedAddress?.longitude,
          'is_favorite':      false,
        };

        final saved = await AddressService.saveAddress(body);

        if (!mounted) return;
        setState(() => _isSaving = false);

        if (saved != null) {
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
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              _isSaving ? 'Menyimpan...' : 'Simpan Pengirim',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Buka LocationPicker untuk menandai titik lokasi di peta.
  ///
  /// Mengembalikan Address yang dipilih, atau null bila dibatalkan. Dipakai
  /// baik oleh tombol peta di kolom alamat, maupun gate wajib-pilih-lokasi.
  Future<Address?> _openLocationPicker() async {
    if (selectedCity == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pilih Kelurahan/Kecamatan terlebih dahulu dari dropdown di atas')),
        );
      }
      return null;
    }

    if (mounted) setState(() => _isLoadingMap = true);

    try {
      final parts = [
        selectedCity!['kelurahan_name'] ?? selectedCity!['subdistrict_name'],
        selectedCity!['kecamatan_name'],
        selectedCity!['kabupaten_name'] ?? selectedCity!['city_name'],
      ].where((e) => e != null && e.toString().trim().isNotEmpty).toList();

      final regionStr = parts.join(', ');

      // Geocode wilayah untuk memusatkan peta di lokasi pesanan yang sesuai.
      final geoService = NominatimGeocodingService();
      final results = await geoService.searchAddress(regionStr.trim());

      Address initialAddr;
      if (results.isNotEmpty) {
        initialAddr = results.first;
      } else {
        initialAddr = Address(
          latitude: -6.2088,
          longitude: 106.8456,
          formattedAddress: regionStr.trim(),
          locationSource: 'provider',
        );
      }

      if (!mounted) return null;

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LocationPickerScreen(
            initialAddress: initialAddr,
            regionHint: regionStr.trim(),
          ),
        ),
      );

      if (result != null && result is Address) {
        setState(() {
          selectedAddressModel = result;
          addressController.text = result.formattedAddress;
        });
        return result;
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingMap = false);
      }
    }

    return null;
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
