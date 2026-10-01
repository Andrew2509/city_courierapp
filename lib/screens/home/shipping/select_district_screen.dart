import 'package:flutter/material.dart';
import 'package:city_courierapp/screens/widgets/home/theme_toggle_fab.dart';
import 'package:city_courierapp/screens/home/shipping/select_subdistrict_screen.dart';
import 'package:city_courierapp/services/shipping/rajaongkir_service.dart';

class SelectDistrictScreen extends StatefulWidget {
  final int provinsiId;
  final String provinsiName;
  final int kabupatenId;
  final String kabupatenName;

  const SelectDistrictScreen({
    super.key,
    required this.provinsiId,
    required this.provinsiName,
    required this.kabupatenId,
    required this.kabupatenName,
  });

  @override
  State<SelectDistrictScreen> createState() => _SelectDistrictScreenState();
}

class _SelectDistrictScreenState extends State<SelectDistrictScreen> {
  bool isDarkMode = false;
  String? selectedKecamatanId;
  String? selectedKecamatanName;
  List<dynamic> listKecamatan = [];
  List<dynamic> filteredList = [];
  TextEditingController searchController = TextEditingController();
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDistricts();
  }

  Future<void> _fetchDistricts() async {
    setState(() => isLoading = true);
    final result = await RajaOngkirService.getDistricts(widget.kabupatenId);
    if (result['success'] == true) {
      setState(() {
        listKecamatan = result['data'];
        filteredList = result['data'];
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message'] ?? 'Gagal mengambil data kecamatan',
            ),
          ),
        );
      }
    }
  }

  void _filterList(String query) {
    setState(() {
      filteredList = listKecamatan.where((item) {
        final name = (item['subdistrict_name'] ?? item['name'] ?? '').toString().toLowerCase();
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
                            'PILIH KECAMATAN/KELURAHAN',
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
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                    ),
                                    itemCount: filteredList.length,
                                    separatorBuilder: (context, index) =>
                                        const SizedBox(height: 8),
                                    itemBuilder: (context, index) {
                                      final kecamatan = filteredList[index];
                                  final kId = kecamatan['subdistrict_id']?.toString() ?? '';
                                  final kName = kecamatan['subdistrict_name'] ?? '';
                                  
                                  final isSelected = selectedKecamatanId == kId;
                                  return _buildKecamatanItem(
                                    kName,
                                    kId,
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
            color: primaryColor.withValues(alpha: 0.2),
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
                      color: Colors.white.withValues(alpha: 0.8),
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
                  color: Colors.white.withValues(alpha: 0.4),
                  size: 16,
                ),
                const SizedBox(width: 8),
                _buildStepItem('Kabupaten', true),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  color: Colors.white.withValues(alpha: 0.4),
                  size: 16,
                ),
                const SizedBox(width: 8),
                _buildStepItem('Kecamatan/Kelurahan', true),
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
        color: Colors
            .white, // In step 3 all 3 steps show as active/completed (fully white)
        fontWeight: FontWeight.bold,
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
          hintText: 'Cari kecamatan atau kelurahan...',
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

  Widget _buildKecamatanItem(
    String title,
    String id,
    bool isSelected,
    bool isDarkMode,
    Color primaryColor,
  ) {
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedKecamatanId = id;
          selectedKecamatanName = title;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDarkMode
                    ? const Color(0xFF0F172A).withValues(alpha: 0.5)
                    : Colors.grey.shade50)
              : (isDarkMode ? Colors.transparent : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? (isDarkMode
                      ? Colors.grey.shade800
                      : primaryColor.withValues(alpha: 0.2))
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
          if (selectedKecamatanId == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Pilih kecamatan terlebih dahulu')),
            );
            return;
          }
          // Pass the combined region back
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SelectSubDistrictScreen(
                provinsiId: widget.provinsiId,
                provinsiName: widget.provinsiName,
                kabupatenId: widget.kabupatenId,
                kabupatenName: widget.kabupatenName,
                kecamatanId: int.parse(selectedKecamatanId!),
                kecamatanName: selectedKecamatanName!,
              ),
            ),
          );
          if (result != null && mounted) {
            // Pass the selected region back (containing kelurahan/desa)
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
                color: primaryColor.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Selesai',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
