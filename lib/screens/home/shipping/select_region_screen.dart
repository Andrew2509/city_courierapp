import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:city_courierapp/screens/widgets/home/theme_toggle_fab.dart';
import 'package:city_courierapp/screens/home/shipping/select_regency_screen.dart';
import 'package:city_courierapp/screens/home/shipping/select_district_screen.dart';
import 'package:city_courierapp/services/shipping/rajaongkir_service.dart';

class SelectRegionScreen extends StatefulWidget {
  const SelectRegionScreen({Key? key}) : super(key: key);

  @override
  State<SelectRegionScreen> createState() => _SelectRegionScreenState();
}

class _SelectRegionScreenState extends State<SelectRegionScreen> {
  bool isDarkMode = false;
  String? selectedProvinsiId;
  String? selectedProvinsiName;
  List<dynamic> listProvinsi = [];
  List<dynamic> filteredList = [];
  TextEditingController searchController = TextEditingController();
  bool isLoading = true;
  bool isDetectingLocation = false;

  @override
  void initState() {
    super.initState();
    _fetchProvinces();
  }

  Future<void> _fetchProvinces() async {
    setState(() => isLoading = true);
    final result = await RajaOngkirService.getProvinces();
    if (result['success'] == true) {
      setState(() {
        listProvinsi = result['data'];
        filteredList = result['data'];
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Gagal mengambil data')),
        );
      }
    }
  }

  void _filterList(String query) {
    setState(() {
      filteredList = listProvinsi.where((item) {
        final name = (item['province'] ?? item['province_name'] ?? item['name'] ?? '').toString().toLowerCase();
        return name.contains(query.toLowerCase());
      }).toList();
    });
  }

  @override
  void dispose() {
    searchController.dispose();
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
                  child: NestedScrollView(
                    headerSliverBuilder: (context, innerBoxIsScrolled) {
                      return [
                        SliverToBoxAdapter(
                          child: Column(
                            children: [
                              const SizedBox(height: 24),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                child: Column(
                                  children: [
                                    _buildInfoBanner(isDarkMode, primaryColor),
                                    const SizedBox(height: 16),
                                    _buildLocationButton(isDarkMode, primaryColor),
                                    const SizedBox(height: 24),
                                    _buildDivider(isDarkMode),
                                    const SizedBox(height: 24),
                                    _buildSearchBar(isDarkMode, primaryColor),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'PILIH PROVINSI',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: isDarkMode
                                          ? Colors.grey.shade500
                                          : Colors.grey.shade400,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ];
                    },
                    body: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : filteredList.isEmpty
                            ? const Center(child: Text('Data tidak tersedia'))
                            : ListView.separated(
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                itemCount: filteredList.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final provinsi = filteredList[index];
                                  final pId = provinsi['province_id']?.toString() ?? 
                                              provinsi['id']?.toString() ?? '';
                                  final pName = provinsi['province'] ?? 
                                                provinsi['province_name'] ?? 
                                                provinsi['name'] ?? '';
                                  
                                  final isSelected = selectedProvinsiId == pId;
                                  return _buildProvinsiItem(
                                    pName,
                                    pId,
                                    isSelected,
                                    isDarkMode,
                                    primaryColor,
                                  );
                                },
                              ),
                  ),
                ),
                _buildBottomBar(isDarkMode, primaryColor),
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
        bottom: 24,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pilih Wilayah',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tentukan lokasi pengiriman',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStepItem('Provinsi', true),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  color: Colors.white.withOpacity(0.4),
                  size: 16,
                ),
                const SizedBox(width: 8),
                _buildStepItem('Kabupaten', false),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  color: Colors.white.withOpacity(0.4),
                  size: 16,
                ),
                const SizedBox(width: 8),
                _buildStepItem('Kecamatan/Kelurahan', false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem(String title, bool isActive) {
    return Text(
      title,
      style: TextStyle(
        color: isActive ? Colors.white : Colors.white.withOpacity(0.6),
        fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
        fontSize: 12,
      ),
    );
  }

  Widget _buildSearchBar(bool isDarkMode, Color primaryColor) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode
            ? const Color(0xFF0F172A).withValues(alpha: 0.5)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
        ),
      ),
      child: TextField(
        controller: searchController,
        onChanged: _filterList,
        style: TextStyle(
          color: isDarkMode ? Colors.white : Colors.black87,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          hintText: 'Cari provinsi...',
          hintStyle: TextStyle(
            color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400,
            fontSize: 14,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade400,
            size: 20,
          ),
          suffixIcon: searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    searchController.clear();
                    _filterList('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildProvinsiItem(
    String title,
    String id,
    bool isSelected,
    bool isDarkMode,
    Color primaryColor,
  ) {
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedProvinsiId = id;
          selectedProvinsiName = title;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDarkMode
                    ? const Color(0xFF0F172A).withOpacity(0.5)
                    : Colors.grey.shade50)
              : (isDarkMode ? Colors.transparent : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : (isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                color: isDarkMode ? Colors.grey.shade200 : Colors.grey.shade700,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? primaryColor : Colors.transparent,
                border: Border.all(
                  color: isSelected ? primaryColor : Colors.grey.shade300,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(bool isDarkMode, Color primaryColor) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF0F172A) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
          ),
        ),
      ),
      child: GestureDetector(
        onTap: () async {
          if (selectedProvinsiId == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Pilih provinsi terlebih dahulu')),
            );
            return;
          }
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SelectRegencyScreen(
                provinsiId: int.parse(selectedProvinsiId!),
                provinsiName: selectedProvinsiName!,
              ),
            ),
          );
          if (result != null) {
            // Pass the selected region back
            if (mounted) {
              Navigator.pop(context, result);
            }
          }
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: primaryColor,
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
              const Text(
                'Lanjutkan',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBanner(bool isDarkMode, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.blue.withOpacity(0.1) : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode ? Colors.blue.withOpacity(0.3) : Colors.blue.shade200,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            color: isDarkMode ? Colors.blue.shade400 : Colors.blue.shade700,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Layanan Dalam Kota',
                  style: TextStyle(
                    color: isDarkMode ? Colors.blue.shade300 : Colors.blue.shade800,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Gunakan deteksi lokasi untuk memuat area dalam kota Anda secara otomatis.',
                  style: TextStyle(
                    color: isDarkMode ? Colors.blue.shade200 : Colors.blue.shade700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationButton(bool isDarkMode, Color primaryColor) {
    return GestureDetector(
      onTap: isDetectingLocation ? null : _useCurrentLocation,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: isDarkMode
              ? const Color(0xFF0F172A).withOpacity(0.5)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
          ),
          boxShadow: isDarkMode ? null : [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDetectingLocation 
                    ? Colors.orange.withOpacity(0.1) 
                    : primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: isDetectingLocation
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                      ),
                    )
                  : Icon(
                      Icons.my_location,
                      color: primaryColor,
                      size: 20,
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isDetectingLocation ? 'Mencari lokasi...' : 'Gunakan Lokasi Saat Ini',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isDetectingLocation ? 'Mohon tunggu sebentar' : 'Deteksi otomatis area Anda',
                    style: TextStyle(
                      color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDarkMode) {
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
            thickness: 1,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'ATAU PILIH MANUAL',
            style: TextStyle(
              color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade400,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ),
        Expanded(
          child: Divider(
            color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
            thickness: 1,
          ),
        ),
      ],
    );
  }

  Future<void> _useCurrentLocation() async {
    setState(() => isDetectingLocation = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'Layanan lokasi tidak aktif.';
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Izin lokasi ditolak.';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw 'Izin lokasi ditolak permanen.';
      }

      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium);

      List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude, position.longitude);

      if (placemarks.isEmpty) {
        throw 'Gagal mendapatkan nama wilayah dari lokasi.';
      }

      Placemark place = placemarks[0];
      String detectedProv = place.administrativeArea ?? '';
      String detectedCity = place.subAdministrativeArea ?? '';
      
      String searchProv = detectedProv.replaceAll(RegExp(r'Provinsi\s+', caseSensitive: false), '').trim();
      String searchCity = detectedCity.replaceAll(RegExp(r'Kota\s+|Kabupaten\s+', caseSensitive: false), '').trim();

      final provResult = await RajaOngkirService.getProvinces();
      if (provResult['success'] != true) {
        throw 'Gagal memuat data provinsi.';
      }

      List<dynamic> provinces = provResult['data'];
      dynamic foundProv = provinces.firstWhere(
        (p) => (p['province'] ?? '').toString().toLowerCase().contains(searchProv.toLowerCase()),
        orElse: () => null,
      );

      if (foundProv == null) {
        throw 'Provinsi $searchProv tidak ditemukan.';
      }

      String provId = foundProv['province_id'].toString();
      String provName = foundProv['province'];

      final cityResult = await RajaOngkirService.getCities(int.parse(provId));
      if (cityResult['success'] != true) {
        throw 'Gagal memuat data kota.';
      }

      List<dynamic> cities = cityResult['data'];
      dynamic foundCity = cities.firstWhere(
        (c) {
          String cName = (c['city_name'] ?? '').toString().toLowerCase();
          return cName.contains(searchCity.toLowerCase()) || searchCity.toLowerCase().contains(cName);
        },
        orElse: () => null,
      );

      if (foundCity == null) {
        throw 'Kota $searchCity tidak ditemukan.';
      }

      int cityId = int.parse(foundCity['city_id'].toString());
      String cityName = foundCity['city_name'];
      String cityType = foundCity['type'] ?? '';

      if (mounted) {
        setState(() => isDetectingLocation = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lokasi terdeteksi: $cityType $cityName, $provName'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SelectDistrictScreen(
              provinsiId: int.parse(provId),
              provinsiName: provName,
              kabupatenId: cityId,
              kabupatenName: '$cityType $cityName',
            ),
          ),
        );

        if (result != null && mounted) {
          Navigator.pop(context, result);
        }
      }

    } catch (e) {
      if (mounted) {
        setState(() => isDetectingLocation = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
