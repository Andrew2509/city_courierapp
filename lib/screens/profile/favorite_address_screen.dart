import 'package:flutter/material.dart';
import 'package:city_courierapp/services/address_service.dart';
import 'package:city_courierapp/screens/home/shipping/add_sender_screen.dart';

class FavoriteAddressScreen extends StatefulWidget {
  const FavoriteAddressScreen({Key? key}) : super(key: key);

  @override
  State<FavoriteAddressScreen> createState() => _FavoriteAddressScreenState();
}

class _FavoriteAddressScreenState extends State<FavoriteAddressScreen> {
  static const primaryColor = Color(0xFFEC5B13);

  bool get isDarkMode => Theme.of(context).brightness == Brightness.dark;
  bool _isLoading = true;
  List<Map<String, dynamic>> _addresses = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final result = await AddressService.getAddresses();
    if (mounted) setState(() { _addresses = result; _isLoading = false; });
  }

  Future<void> _toggleFavorite(Map<String, dynamic> addr) async {
    final ok = await AddressService.toggleFavorite(addr['id'] as int);
    if (ok && mounted) {
      setState(() => addr['is_favorite'] = !(addr['is_favorite'] == true));
    }
  }

  Future<void> _delete(Map<String, dynamic> addr) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Alamat'),
        content: Text('Hapus alamat "${addr['name']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final ok = await AddressService.deleteAddress(addr['id'] as int);
      if (ok && mounted) {
        setState(() => _addresses.removeWhere((a) => a['id'] == addr['id']));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alamat dihapus')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF9FAFB);

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                    ),
                  )
                : _addresses.isEmpty
                    ? _buildEmpty()
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: primaryColor,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(20),
                          itemCount: _addresses.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (_, i) =>
                              _buildCard(_addresses[i]),
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primaryColor,
        onPressed: _openAddScreen,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Tambah Alamat',
            style: TextStyle(color: Colors.white,)),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 20,
        right: 20,
        bottom: 20,
      ),
      decoration: const BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 14),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Alamat Favorit',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Kelola alamat pengiriman tersimpan',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_off_outlined, size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'Belum ada alamat tersimpan',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tekan tombol "+" untuk menambahkan alamat baru',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade300,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> addr) {
    final isFav = addr['is_favorite'] == true;
    final surface = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final border = isDarkMode ? Colors.grey.shade700 : Colors.grey.shade100;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.person, color: primaryColor, size: 26),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          addr['name'] ?? '',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isDarkMode ? Colors.white : Colors.grey.shade800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isFav)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.favorite, size: 10, color: Colors.red.shade400),
                              const SizedBox(width: 3),
                              Text('Favorit',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.red.shade400,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                    ],
                  ),
                  if ((addr['phone'] ?? '').isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      addr['phone'],
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade500,
                      ),
                    ),
                  ],
                  if ((addr['address'] ?? '').isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      addr['address'],
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade400,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if ((addr['city_name'] ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Icon(Icons.location_on,
                              size: 11,
                              color: primaryColor.withOpacity(0.7)),
                          const SizedBox(width: 3),
                          Text(
                            addr['city_name'],
                            style: TextStyle(
                              fontSize: 11,
                              color: primaryColor.withOpacity(0.8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Actions
            Column(
              children: [
                IconButton(
                  icon: Icon(
                    isFav ? Icons.favorite : Icons.favorite_border,
                    color: isFav ? Colors.red.shade400 : Colors.grey.shade300,
                    size: 22,
                  ),
                  onPressed: () => _toggleFavorite(addr),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(height: 8),
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      color: Colors.grey.shade300, size: 22),
                  onPressed: () => _delete(addr),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAddScreen() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddSenderScreen()),
    );
    if (result != null) _load();
  }
}
