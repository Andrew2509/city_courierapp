import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:city_courierapp/screens/home/shipping/select_regency_screen.dart';
import 'package:city_courierapp/services/shipping/rajaongkir_service.dart';
import 'package:city_courierapp/services/shipping/rajaongkir_matcher_service.dart';

class SelectRegionScreen extends StatefulWidget {
  const SelectRegionScreen({super.key});

  @override
  State<SelectRegionScreen> createState() => _SelectRegionScreenState();
}

class _SelectRegionScreenState extends State<SelectRegionScreen> {
  String? selectedProvinsiId;
  String? selectedProvinsiName;
  List<dynamic> listProvinsi = [];
  List<dynamic> filteredList = [];
  final TextEditingController searchController = TextEditingController();
  bool isLoading = true;
  bool isDetectingLocation = false;

  // Kota/Kabupaten count map per provinsi (matches official Stitch design specification)
  static const Map<String, String> _provinceCityCounts = {
    'aceh': '23 Kota / Kabupaten',
    'sumatera utara': '33 Kota / Kabupaten',
    'sumatera barat': '19 Kota / Kabupaten',
    'riau': '12 Kota / Kabupaten',
    'kepulauan riau': '7 Kota / Kabupaten',
    'jambi': '11 Kota / Kabupaten',
    'sumatera selatan': '17 Kota / Kabupaten',
    'kepulauan bangka belitung': '7 Kota / Kabupaten',
    'bengkulu': '10 Kota / Kabupaten',
    'lampung': '15 Kota / Kabupaten',
    'dki jakarta': '6 Kota Administratif',
    'jawa barat': '27 Kota / Kabupaten',
    'banten': '8 Kota / Kabupaten',
    'jawa tengah': '35 Kota / Kabupaten',
    'di yogyakarta': '5 Kota / Kabupaten',
    'jawa timur': '38 Kota / Kabupaten',
    'bali': '9 Kota / Kabupaten',
    'nusa tenggara barat': '10 Kota / Kabupaten',
    'nusa tenggara timur': '22 Kota / Kabupaten',
    'kalimantan barat': '14 Kota / Kabupaten',
    'kalimantan tengah': '14 Kota / Kabupaten',
    'kalimantan selatan': '13 Kota / Kabupaten',
    'kalimantan timur': '10 Kota / Kabupaten',
    'kalimantan utara': '5 Kota / Kabupaten',
    'sulawesi utara': '15 Kota / Kabupaten',
    'gorontalo': '6 Kota / Kabupaten',
    'sulawesi tengah': '13 Kota / Kabupaten',
    'sulawesi barat': '6 Kota / Kabupaten',
    'sulawesi selatan': '24 Kota / Kabupaten',
    'sulawesi tenggara': '17 Kota / Kabupaten',
    'maluku': '11 Kota / Kabupaten',
    'maluku utara': '10 Kota / Kabupaten',
    'papua': '9 Kota / Kabupaten',
    'papua barat': '7 Kota / Kabupaten',
    'papua tengah': '8 Kota / Kabupaten',
    'papua pegunungan': '8 Kota / Kabupaten',
    'papua selatan': '4 Kota / Kabupaten',
    'papua barat daya': '6 Kota / Kabupaten',
  };

  // Quick chips: Sering dicari
  final List<String> _popularProvinces = [
    'DKI Jakarta',
    'Jawa Timur',
    'Jawa Barat',
    'Jawa Tengah',
    'Banten',
    'Bali',
  ];

  @override
  void initState() {
    super.initState();
    _fetchProvinces();
  }

  Future<void> _fetchProvinces() async {
    setState(() => isLoading = true);
    final result = await RajaOngkirService.getProvinces();
    if (result['success'] == true) {
      if (mounted) {
        setState(() {
          listProvinsi = result['data'];
          filteredList = result['data'];
          isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Gagal mengambil data provinsi')),
        );
      }
    }
  }

  void _filterList(String query) {
    setState(() {
      filteredList = listProvinsi.where((item) {
        final name = (item['province'] ?? item['province_name'] ?? item['name'] ?? '')
            .toString()
            .toLowerCase();
        return name.contains(query.toLowerCase());
      }).toList();
    });
  }

  String _getCityCountLabel(String provName) {
    final clean = provName.toLowerCase().replaceAll(RegExp(r'^provinsi\s+'), '').trim();
    return _provinceCityCounts[clean] ?? 'Kota / Kabupaten';
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const brandOrange = Color(0xFFF97316);
    const bgSurface = Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: bgSurface,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Header dengan Stepper 4 Tahap ──
            _buildTopHeader(),

            // ── Konten Scrollable ──
            Expanded(
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(brandOrange),
                      ),
                    )
                  : RefreshIndicator(
                      color: brandOrange,
                      onRefresh: _fetchProvinces,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. GPS Card: Gunakan Lokasi Saat Ini
                            _buildGpsCard(),
                            const SizedBox(height: 12),

                            // 2. Search Field
                            _buildSearchBar(),
                            const SizedBox(height: 10),

                            // 3. Quick Chips: Sering dicari
                            _buildPopularChips(),
                            const SizedBox(height: 14),

                            // 4. Card Container: Daftar Provinsi
                            _buildProvinceListCard(),
                            const SizedBox(height: 100), // Spasi untuk floating bottom bar
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
      bottomSheet: _buildBottomBar(),
    );
  }

  // ── 1. Top Header dengan Stepper Breadcrumbs ───────────────────────
  Widget _buildTopHeader() {
    return Container(
      padding: const EdgeInsets.only(top: 8, bottom: 10, left: 12, right: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      child: Column(
        children: [
          // Baris Navigasi Utama: Back Button, Title, Right Action
          Row(
            children: [
              InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.chevron_left_rounded,
                    color: Color(0xFF334155),
                    size: 26,
                  ),
                ),
              ),
              const Expanded(
                child: Text(
                  'Pilih Wilayah',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              const SizedBox(width: 36), // Menjaga judul tetap di tengah presisi
            ],
          ),
          const SizedBox(height: 8),

          // Stepper Breadcrumbs: 1 Provinsi > 2 Kota/Kab > 3 Kecamatan > 4 Kelurahan
          Container(
            padding: const EdgeInsets.only(top: 8),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0xFFF1F5F9), width: 1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStepItem(stepNumber: '1', label: 'Provinsi', isActive: true),
                _buildStepArrow(),
                _buildStepItem(stepNumber: '2', label: 'Kota/Kab', isActive: false),
                _buildStepArrow(),
                _buildStepItem(stepNumber: '3', label: 'Kecamatan', isActive: false),
                _buildStepArrow(),
                _buildStepItem(stepNumber: '4', label: 'Kelurahan', isActive: false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem({
    required String stepNumber,
    required String label,
    required bool isActive,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 15,
          height: 15,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? const Color(0xFFF97316) : const Color(0xFFE2E8F0),
          ),
          alignment: Alignment.center,
          child: Text(
            stepNumber,
            style: TextStyle(
              color: isActive ? Colors.white : const Color(0xFF64748B),
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: isActive ? const Color(0xFFEA580C) : const Color(0xFF94A3B8),
            fontSize: 11,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildStepArrow() {
    return const Icon(
      Icons.chevron_right_rounded,
      size: 13,
      color: Color(0xFFCBD5E1),
    );
  }

  // ── 2. GPS Card: Gunakan Lokasi Saat Ini ───────────────────────────
  Widget _buildGpsCard() {
    return InkWell(
      onTap: isDetectingLocation ? null : _useCurrentLocation,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x080F172A),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.my_location_rounded,
                color: Color(0xFFEA580C),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Gunakan Lokasi Saat Ini',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Deteksi otomatis via GPS',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(8),
              ),
              child: isDetectingLocation
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEA580C)),
                      ),
                    )
                  : const Text(
                      'Aktifkan',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFEA580C),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 3. Search Bar ──────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: searchController,
        onChanged: _filterList,
        style: const TextStyle(
          color: Color(0xFF1E293B),
          fontSize: 13,
        ),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Cari provinsi...',
          hintStyle: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 13,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF94A3B8),
            size: 20,
          ),
          suffixIcon: searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF94A3B8)),
                  onPressed: () {
                    searchController.clear();
                    _filterList('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        ),
      ),
    );
  }

  // ── 4. Quick Chips: Sering Dicari ──────────────────────────────────
  Widget _buildPopularChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          const Text(
            'Sering dicari: ',
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          ..._popularProvinces.map((prov) {
            final isCurrentSearch = searchController.text.toLowerCase() == prov.toLowerCase();
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: InkWell(
                onTap: () {
                  searchController.text = prov;
                  _filterList(prov);
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isCurrentSearch ? const Color(0xFFFFF7ED) : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isCurrentSearch ? const Color(0xFFF97316) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Text(
                    prov,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isCurrentSearch ? FontWeight.w600 : FontWeight.w500,
                      color: isCurrentSearch ? const Color(0xFFEA580C) : const Color(0xFF475569),
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── 5. Card Container: Daftar Provinsi ─────────────────────────────
  Widget _buildProvinceListCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card: Daftar Provinsi & Jumlah
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: const Color(0xFFF8FAFC),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Daftar Provinsi',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF334155),
                  ),
                ),
                Text(
                  '${filteredList.length} Provinsi',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Items List
          if (filteredList.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 36, horizontal: 16),
              child: Center(
                child: Text(
                  'Provinsi tidak ditemukan',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredList.length,
              separatorBuilder: (context, index) => const Divider(
                height: 1,
                color: Color(0xFFF1F5F9),
                indent: 14,
                endIndent: 14,
              ),
              itemBuilder: (context, index) {
                final provinsi = filteredList[index];
                final pId = provinsi['province_id']?.toString() ??
                    provinsi['id']?.toString() ??
                    '';
                final pName = provinsi['province'] ??
                    provinsi['province_name'] ??
                    provinsi['name'] ??
                    '';
                final isSelected = selectedProvinsiId == pId;
                final cityCountText = _getCityCountLabel(pName);

                return _buildProvinceRow(
                  id: pId,
                  name: pName,
                  cityCountText: cityCountText,
                  isSelected: isSelected,
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildProvinceRow({
    required String id,
    required String name,
    required String cityCountText,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () {
        setState(() {
          selectedProvinsiId = id;
          selectedProvinsiName = name;
        });
      },
      child: Container(
        color: isSelected ? const Color(0xFFFFF7ED).withOpacity(0.5) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected ? const Color(0xFFEA580C) : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    cityCountText,
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            // Custom Radio Button
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xFFF97316) : const Color(0xFFCBD5E1),
                  width: isSelected ? 2 : 1.5,
                ),
                color: Colors.white,
              ),
              alignment: Alignment.center,
              child: isSelected
                  ? Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFF97316),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // ── 6. Fixed Floating Bottom Navigation Bar ───────────────────────
  Widget _buildBottomBar() {
    final hasSelection = selectedProvinsiId != null;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, -3),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom > 0
            ? MediaQuery.of(context).padding.bottom + 6
            : 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Baris Status Pilihan & Tahap
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: RichText(
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    children: [
                      const TextSpan(text: 'Pilihan: '),
                      TextSpan(
                        text: selectedProvinsiName ?? '-',
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFED7AA)),
                ),
                child: const Text(
                  'Tahap 1 dari 4',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFEA580C),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Tombol Lanjutkan ke Kota/Kab
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: hasSelection
                  ? () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SelectRegencyScreen(
                            provinsiId: int.parse(selectedProvinsiId!),
                            provinsiName: selectedProvinsiName!,
                          ),
                        ),
                      );
                      if (result != null && mounted) {
                        Navigator.pop(context, result);
                      }
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF97316),
                disabledBackgroundColor: const Color(0xFFE2E8F0),
                foregroundColor: Colors.white,
                disabledForegroundColor: const Color(0xFF94A3B8),
                elevation: hasSelection ? 2 : 0,
                shadowColor: const Color(0x40F97316),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text(
                    'Lanjutkan ke Kota/Kab',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 7. Deteksi Otomatis Lokasi GPS & Kode Pos Langsung ───────────
  Future<void> _useCurrentLocation() async {
    setState(() => isDetectingLocation = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'Layanan lokasi (GPS) tidak aktif. Silakan aktifkan GPS perangkat Anda.';
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Izin akses lokasi ditolak.';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw 'Izin lokasi ditolak permanen. Silakan aktifkan lewat Pengaturan.';
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      Placemark? place;
      if (placemarks.isNotEmpty) {
        place = placemarks.first;
      }

      final fullAddress = [
        place?.street,
        place?.subLocality,
        place?.locality,
        place?.subAdministrativeArea,
        place?.administrativeArea,
        place?.postalCode,
      ].where((s) => s != null && s.toString().trim().isNotEmpty).join(', ');

      // Cocokkan koordinat & petunjuk alamat ke data resmi RajaOngkir lengkap sampai kode pos
      final match = await RajaOngkirMatcherService.match(
        latitude: position.latitude,
        longitude: position.longitude,
        village: place?.subLocality,
        district: place?.locality,
        city: place?.subAdministrativeArea,
        province: place?.administrativeArea,
        postalCode: place?.postalCode,
        fullAddress: fullAddress.isNotEmpty ? fullAddress : null,
      );

      if (!mounted) return;
      setState(() => isDetectingLocation = false);

      // JIKA BERHASIL COCOK: Kembalikan langsung data hierarki lengkap sampai kode pos!
      if (match['matched'] == true) {
        final verifiedZip = match['postal_code'] ?? place?.postalCode;
        final village = match['village'] ??
            (match['subdistrict_name'] != match['district_name'] ? match['subdistrict_name'] : null) ??
            place?.subLocality;
        final district = match['district_name'] ?? place?.locality;
        final city = match['city_name'] ?? place?.subAdministrativeArea;
        final province = match['province_name'] ?? place?.administrativeArea;

        final summaryList = [
          if (village != null && village.toString().isNotEmpty) village,
          if (district != null && district.toString().isNotEmpty) district,
          if (city != null && city.toString().isNotEmpty) city,
          if (province != null && province.toString().isNotEmpty) province,
          if (verifiedZip != null && verifiedZip.toString().isNotEmpty) verifiedZip,
        ];

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✓ Lokasi & kode pos terdeteksi otomatis:\n${summaryList.join(', ')}',
            ),
            backgroundColor: const Color(0xFF16A34A),
            duration: const Duration(seconds: 3),
          ),
        );

        Navigator.pop(context, {
          'provinsi_id': match['province_id'],
          'provinsi_name': province,
          'province_name': province,
          'kabupaten_id': match['rajaongkir_city_id'] ?? match['city_id'],
          'kabupaten_name': city,
          'city_id': match['rajaongkir_city_id'] ?? match['city_id'],
          'city_name': city,
          'kecamatan_id': match['rajaongkir_subdistrict_id'] ?? match['rajaongkir_region_id'],
          'kecamatan_name': district,
          'district_name': district,
          'kelurahan_id': match['rajaongkir_subdistrict_id'],
          'kelurahan_name': village,
          'subdistrict_name': village ?? district,
          'zip_code': verifiedZip,
          'postal_code': verifiedZip,
          'postal_code_verified': match['postal_code_verified'] == true || verifiedZip != null,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'is_gps_detected': true,
        });
        return;
      }

      // Fallback jika belum cocok sempurna: Arahkan pengguna ke tahap konfirmasi
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lokasi GPS terdeteksi. Silakan konfirmasi wilayah Anda.'),
          backgroundColor: Color(0xFFD97706),
        ),
      );

      if (place?.administrativeArea != null) {
        final provGuess = place!.administrativeArea!
            .replaceAll(RegExp(r'Provinsi\s+', caseSensitive: false), '')
            .trim();
        searchController.text = provGuess;
        _filterList(provGuess);
      }
    } catch (e) {
      if (mounted) {
        setState(() => isDetectingLocation = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }
}
