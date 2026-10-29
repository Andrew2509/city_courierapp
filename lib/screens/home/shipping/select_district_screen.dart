import 'package:flutter/material.dart';
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
  String? selectedKecamatanId;
  String? selectedKecamatanName;
  List<dynamic> listKecamatan = [];
  List<dynamic> filteredList = [];
  final TextEditingController searchController = TextEditingController();
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
      if (mounted) {
        setState(() {
          listKecamatan = result['data'];
          filteredList = result['data'];
          isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Gagal mengambil data kecamatan'),
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
                      onRefresh: _fetchDistricts,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Context Info Card: Kabupaten/Kota Terpilih
                            _buildContextCard(),
                            const SizedBox(height: 12),

                            // Search Field
                            _buildSearchBar(),
                            const SizedBox(height: 14),

                            // Card Container: Daftar Kecamatan
                            _buildDistrictListCard(),
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
      color: Colors.white,
      padding: const EdgeInsets.only(top: 8, bottom: 10, left: 12, right: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      child: Column(
        children: [
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
              const SizedBox(width: 36),
            ],
          ),
          const SizedBox(height: 8),

          // Stepper: 1 Provinsi ✓ > 2 Kota/Kab ✓ > 3 Kecamatan (Aktif) > 4 Kelurahan
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
                _buildStepItem(stepNumber: '1', label: 'Provinsi', isCompleted: true, isActive: false),
                _buildStepArrow(),
                _buildStepItem(stepNumber: '2', label: 'Kota/Kab', isCompleted: true, isActive: false),
                _buildStepArrow(),
                _buildStepItem(stepNumber: '3', label: 'Kecamatan', isCompleted: false, isActive: true),
                _buildStepArrow(),
                _buildStepItem(stepNumber: '4', label: 'Kelurahan', isCompleted: false, isActive: false),
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
    required bool isCompleted,
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
            color: isActive
                ? const Color(0xFFF97316)
                : (isCompleted ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0)),
          ),
          alignment: Alignment.center,
          child: isCompleted
              ? const Icon(Icons.check, size: 10, color: Colors.white)
              : Text(
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
            color: isActive
                ? const Color(0xFFEA580C)
                : (isCompleted ? const Color(0xFF16A34A) : const Color(0xFF94A3B8)),
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

  // ── 2. Context Card: Menampilkan Kabupaten & Provinsi Terpilih ─────
  Widget _buildContextCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.location_city_outlined,
              size: 16,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                children: [
                  const TextSpan(text: 'Wilayah: '),
                  TextSpan(
                    text: '${widget.kabupatenName}, ${widget.provinsiName}',
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
          hintText: 'Cari kecamatan...',
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

  // ── 4. Card Container: Daftar Kecamatan ────────────────────────────
  Widget _buildDistrictListCard() {
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: const Color(0xFFF8FAFC),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Daftar Kecamatan',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF334155),
                  ),
                ),
                Text(
                  '${filteredList.length} Kecamatan',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          if (filteredList.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 36, horizontal: 16),
              child: Center(
                child: Text(
                  'Kecamatan tidak ditemukan',
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
                final item = filteredList[index];
                final dId = item['subdistrict_id']?.toString() ?? item['id']?.toString() ?? '';
                final dName = item['subdistrict_name'] ?? item['name'] ?? '';
                final isSelected = selectedKecamatanId == dId;

                return InkWell(
                  onTap: () {
                    setState(() {
                      selectedKecamatanId = dId;
                      selectedKecamatanName = dName;
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
                                dName,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                  color: isSelected ? const Color(0xFFEA580C) : const Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Kecamatan',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isSelected ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ),
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
              },
            ),
        ],
      ),
    );
  }

  // ── 5. Fixed Floating Bottom Navigation Bar ───────────────────────
  Widget _buildBottomBar() {
    final hasSelection = selectedKecamatanId != null;

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
                        text: selectedKecamatanName ?? '-',
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
                  'Tahap 3 dari 4',
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

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: hasSelection
                  ? () async {
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
                    'Lanjutkan ke Kelurahan',
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
}
