import 'package:flutter/material.dart';
import 'package:city_courierapp/screens/home/shipping/add_sender_screen.dart';
import 'package:city_courierapp/services/address_service.dart';

class SelectSenderScreen extends StatefulWidget {
  final String title;
  final String subtitle;

  const SelectSenderScreen({
    Key? key,
    this.title = 'Pilih Pengirim',
    this.subtitle = 'Pilih pengirim untuk pengiriman',
  }) : super(key: key);

  @override
  State<SelectSenderScreen> createState() => _SelectSenderScreenState();
}

class _SelectSenderScreenState extends State<SelectSenderScreen> {
  bool get isDarkMode => Theme.of(context).brightness == Brightness.dark;
  bool isShowAll = true;
  bool _isLoading = true;
  String _searchQuery = '';

  List<Map<String, dynamic>> _addresses = [];

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    setState(() => _isLoading = true);
    final result = await AddressService.getAddresses();
    if (mounted) {
      setState(() {
        _addresses = result;
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    var list = isShowAll
        ? _addresses
        : _addresses.where((a) => a['is_favorite'] == true).toList();

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where((a) =>
              (a['name'] ?? '').toString().toLowerCase().contains(q) ||
              (a['phone'] ?? '').toString().toLowerCase().contains(q) ||
              (a['address'] ?? '').toString().toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  Future<void> _toggleFavorite(Map<String, dynamic> addr) async {
    final id = addr['id'] as int;
    final ok = await AddressService.toggleFavorite(id);
    if (ok && mounted) {
      setState(() {
        addr['is_favorite'] = !(addr['is_favorite'] == true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFEC5B13);
    final bgLight = const Color(0xFFFFFFFF);
    final bgDark = const Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: isDarkMode ? bgDark : bgLight,
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(context, primaryColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      _buildSearchBar(isDarkMode, primaryColor),
                      const SizedBox(height: 24),
                      _buildFilterButtons(isDarkMode, primaryColor),
                      Expanded(
                        child: _isLoading
                            ? const Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFFEC5B13)),
                                ),
                              )
                            : _buildSenderList(isDarkMode, primaryColor),
                      ),
                    ],
                  ),
                ),
              ),
              _buildStickyBottomBar(context, isDarkMode, primaryColor),
            ],
          ),
        ],
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

  Widget _buildSearchBar(bool isDarkMode, Color primaryColor) {
    return Container(
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
        onChanged: (v) => setState(() => _searchQuery = v),
        style: TextStyle(
          color: isDarkMode ? Colors.white : Colors.black87,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          hintText: 'Cari nama, telepon, atau alamat...',
          hintStyle: TextStyle(
            color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400,
            fontSize: 14,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade400,
            size: 20,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildFilterButtons(bool isDarkMode, Color primaryColor) {
    return Row(
      children: [
        _filterBtn(
          isDarkMode,
          primaryColor,
          label: 'Semua',
          icon: Icons.group,
          active: isShowAll,
          onTap: () => setState(() => isShowAll = true),
        ),
        const SizedBox(width: 12),
        _filterBtn(
          isDarkMode,
          primaryColor,
          label: 'Favorit',
          icon: Icons.favorite,
          active: !isShowAll,
          onTap: () => setState(() => isShowAll = false),
        ),
      ],
    );
  }

  Widget _filterBtn(
    bool isDarkMode,
    Color primaryColor, {
    required String label,
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active
                ? primaryColor
                : (isDarkMode ? const Color(0xFF1E293B) : Colors.white),
            borderRadius: BorderRadius.circular(12),
            border: !active
                ? Border.all(
                    color: isDarkMode
                        ? Colors.grey.shade700
                        : Colors.grey.shade100,
                  )
                : null,
            boxShadow: active
                ? [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: active ? Colors.white : Colors.grey.shade500,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: active ? Colors.white : Colors.grey.shade500,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSenderList(bool isDarkMode, Color primaryColor) {
    final list = _filtered;

    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off, size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              isShowAll ? 'Belum ada alamat tersimpan' : 'Belum ada alamat favorit',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tekan "+ Tambah" untuk menambahkan.',
              style: TextStyle(
                color: Colors.grey.shade300,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAddresses,
      color: primaryColor,
      child: ListView.separated(
        padding: const EdgeInsets.only(top: 16, bottom: 24),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) =>
            _buildSenderCard(list[index], isDarkMode, primaryColor),
      ),
    );
  }

  Widget _buildSenderCard(
    Map<String, dynamic> sender,
    bool isDarkMode,
    Color primaryColor,
  ) {
    final name = sender['name'] ?? '';
    final phone = sender['phone'] ?? '';
    final address = sender['address'] ?? sender['city_name'] ?? '';
    final isFavorite = sender['is_favorite'] == true;
    // Normalize for pickup_screen compatibility
    final normalized = {
      ...sender,
      'isFavorite': isFavorite,
      'kecamatan_name': sender['subdistrict_name'],
    };

    return GestureDetector(
      onTap: () => Navigator.pop(context, normalized),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade50,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isDarkMode
                    ? primaryColor.withOpacity(0.2)
                    : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.person, color: primaryColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.grey.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    phone,
                    style: TextStyle(
                      color: isDarkMode
                          ? Colors.grey.shade400
                          : Colors.grey.shade500,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    address,
                    style: TextStyle(
                      color: isDarkMode
                          ? Colors.grey.shade500
                          : Colors.grey.shade400,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                GestureDetector(
                  onTap: () => _toggleFavorite(sender),
                  child: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: isFavorite
                        ? Colors.red.shade500
                        : Colors.grey.shade300,
                    size: 22,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStickyBottomBar(
    BuildContext context,
    bool isDarkMode,
    Color primaryColor,
  ) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: isDarkMode
            ? const Color(0xFF0F172A).withOpacity(0.9)
            : Colors.white.withOpacity(0.9),
        border: Border(
          top: BorderSide(
            color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
          ),
        ),
      ),
      child: GestureDetector(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddSenderScreen()),
          );
          if (result != null && result is Map<String, dynamic>) {
            // Reload from API after adding
            _loadAddresses();
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
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'Tambah Pengirim Baru',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
