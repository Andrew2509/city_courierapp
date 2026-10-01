import 'package:flutter/material.dart';
import 'package:city_courierapp/screens/widgets/home/theme_toggle_fab.dart';
import 'package:city_courierapp/screens/home/shipping/select_district_screen.dart';
import 'package:city_courierapp/services/shipping/rajaongkir_service.dart';

class SelectRegencyScreen extends StatefulWidget {
  final int provinsiId;
  final String provinsiName;

  const SelectRegencyScreen({
    Key? key,
    required this.provinsiId,
    required this.provinsiName,
  }) : super(key: key);

  @override
  State<SelectRegencyScreen> createState() => _SelectRegencyScreenState();
}

class _SelectRegencyScreenState extends State<SelectRegencyScreen> {
  bool isDarkMode = false;
  String? selectedKabupatenId;
  String? selectedKabupatenName;
  List<dynamic> listKabupaten = [];
  List<dynamic> filteredList = [];
  TextEditingController searchController = TextEditingController();
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCities();
  }

  Future<void> _fetchCities() async {
    setState(() => isLoading = true);
    final result = await RajaOngkirService.getCities(widget.provinsiId);
    if (result['success'] == true) {
      setState(() {
        listKabupaten = result['data'];
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
      filteredList = listKabupaten.where((item) {
        final name = (item['city_name'] ?? item['name'] ?? '').toString().toLowerCase();
        final type = (item['type'] ?? '').toString().toLowerCase();
        return name.contains(query.toLowerCase()) || type.contains(query.toLowerCase());
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
    final primaryColor = const Color(0xFFEC5B13);
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
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: _buildSearchBar(isDarkMode, primaryColor),
                      ),
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'PILIH KABUPATEN/KOTA',
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
                      Expanded(
                        child: isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : filteredList.isEmpty
                                ? const Center(child: Text('Data tidak tersedia'))
                                : ListView.separated(
                                    padding: const EdgeInsets.symmetric(horizontal: 24),
                                    itemCount: filteredList.length,
                                    separatorBuilder: (context, index) =>
                                        const SizedBox(height: 8),
                                    itemBuilder: (context, index) {
                                      final kabupaten = filteredList[index];
                                      final cId = kabupaten['city_id']?.toString() ?? 
                                                  kabupaten['id']?.toString() ?? '';
                                      final cName = kabupaten['city_name'] ?? 
                                                    kabupaten['name'] ?? '';
                                      final cType = kabupaten['type'] ?? '';
                                      
                                      final isSelected = selectedKabupatenId == cId;
                                      return _buildKabupatenItem(
                                        "$cType $cName".trim(),
                                        cId,
                                        isSelected,
                                        isDarkMode,
                                        primaryColor,
                                      );
                                    },
                                  ),
                      ),
                    ],
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
                _buildStepItem('Kabupaten', true),
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
          hintText: 'Cari kabupaten/kota...',
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

  Widget _buildKabupatenItem(
    String title,
    String id,
    bool isSelected,
    bool isDarkMode,
    Color primaryColor,
  ) {
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedKabupatenId = id;
          selectedKabupatenName = title;
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
                ? (isDarkMode
                      ? Colors.grey.shade800
                      : primaryColor.withOpacity(0.2))
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
          if (selectedKabupatenId == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Pilih kabupaten/kota terlebih dahulu')),
            );
            return;
          }
          // For RajaOngkir Starter/Basic, we usually only select up to City level for calculations.
          // If City Courier uses Subdistrict level, we'd need Pro account or separate subdistrict API.
          // Returning the selected city data back.
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SelectDistrictScreen(
                provinsiId: widget.provinsiId,
                provinsiName: widget.provinsiName,
                kabupatenId: int.parse(selectedKabupatenId!),
                kabupatenName: selectedKabupatenName!,
              ),
            ),
          );
          if (result != null) {
            // Pass the selected region back (containing subdistrict/kecamatan)
            Navigator.pop(context, result);
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
}
