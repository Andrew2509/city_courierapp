import 'package:flutter/material.dart';
import 'package:city_courierapp/screens/home/tracking/tracking_detail_screen.dart';
import 'package:city_courierapp/screens/home/tracking/barcode_scanner_screen.dart';
import 'package:city_courierapp/screens/home/tracking/scanner_guide_screen.dart';
import 'package:city_courierapp/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final TextEditingController trackingController = TextEditingController();

  Future<void> _performSearch(BuildContext context, String number) async {
    if (number.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nomor resi wajib diisi.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final trimmed = number.trim();

    // Navigate directly to detail screen which handles loading/error states
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TrackingDetailScreen(trackingNumber: trimmed),
      ),
    );

    // Save to history in background after navigation
    final data = await ApiService.trackShipment(trimmed);
    if (data != null && mounted) {
      _addToHistory(data);
    }
  }

  List<Map<String, dynamic>> searchHistory = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? historyJson = prefs.getString('tracking_history');
    if (historyJson != null) {
      setState(() {
        searchHistory = List<Map<String, dynamic>>.from(jsonDecode(historyJson));
      });
    }
  }

  Future<void> _addToHistory(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final String resi = data['tracking_number'] ?? data['shipment_number'] ?? data['id'].toString();
    
    // Remove if already exists to move it to the top
    searchHistory.removeWhere((item) => item['resi'] == resi);
    
    String displayStatus = 'Status: ${data['status']}';
    if (data['status'] == 'delivered') displayStatus = 'Selesai - Diterima';
    if (data['status'] == 'in_transit') displayStatus = 'Dalam Perjalanan';

    searchHistory.insert(0, {
      'resi': resi,
      'status': displayStatus,
      'type': data['status'] == 'delivered' ? 'completed' : 'active',
      'full_data': data, // Save full data for quick access
    });

    // Limit history to 5 items
    if (searchHistory.length > 5) {
      searchHistory = searchHistory.sublist(0, 5);
    }

    await prefs.setString('tracking_history', jsonEncode(searchHistory));
    setState(() {});
  }

  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('tracking_history');
    setState(() {
      searchHistory = [];
    });
  }

  // Tailwind Slate colors definitions
  static const Color slate50 = Color(0xFFF8FAFC);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate900 = Color(0xFF0F172A);


  @override
  void dispose() {
    trackingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    const primaryColor = Color(0xFFEC5B13);
    const bgLight = Color(0xFFF8F6F6);
    const bgDark = Color(0xFF221610);

    return Scaffold(
      backgroundColor: isDarkMode ? bgDark : bgLight,
      body: Column(
        children: [
          _buildHeader(context, primaryColor),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSearchSection(isDarkMode, primaryColor),
                  const SizedBox(height: 32),
                  _buildHistorySection(isDarkMode, primaryColor),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Color primaryColor) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        bottom: 40,
      ),
      width: double.infinity,
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.1),
                  padding: const EdgeInsets.all(8),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Lacak Paket',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ScannerGuideScreen(),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.help_outline, color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Panduan',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 56, top: 4),
            child: Text(
              'Pantau keberadaan kiriman Anda secara real-time',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSection(bool isDarkMode, Color primaryColor) {
    return Transform.translate(
      offset: const Offset(0, -20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDarkMode ? Colors.white10 : slate200,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nomor Resi',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? slate200 : slate700,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: isDarkMode ? const Color(0xFF0F172A) : slate50,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        bottomLeft: Radius.circular(12),
                      ),
                      border: Border.all(
                        color: isDarkMode ? Colors.white10 : slate200,
                      ),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 12),
                        Icon(
                          Icons.search,
                          color: slate400,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: trackingController,
                            style: TextStyle(
                              fontSize: 15,
                              color: isDarkMode ? Colors.white : slate900,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Masukkan nomor resi Anda',
                              hintStyle: TextStyle(
                                color: slate400,
                                fontSize: 14,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onSubmitted: (value) => _performSearch(context, value),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const BarcodeScannerScreen(),
                              ),
                            );
                          },
                          icon: Icon(
                            Icons.qr_code_scanner,
                            color: slate500,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => _performSearch(context, trackingController.text),
                  child: Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Cari',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.info_outline, color: slate400, size: 14),
                const SizedBox(width: 6),
                Text(
                  'Contoh: CC-123456789',
                  style: TextStyle(
                    color: slate400,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySection(bool isDarkMode, Color primaryColor) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Riwayat Pencarian',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : slate900,
              ),
            ),
            TextButton(
              onPressed: _clearHistory,
              child: Text(
                'Hapus Semua',
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...searchHistory.map(
          (item) => _buildHistoryItem(item, isDarkMode, primaryColor),
        ),
      ],
    );
  }

  Widget _buildHistoryItem(
    Map<String, dynamic> item,
    bool isDarkMode,
    Color primaryColor,
  ) {
    final bool isCompleted = item['type'] == 'completed';

    return GestureDetector(
      onTap: () {
        final resi = item['resi'] as String?;
        if (resi != null && resi.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TrackingDetailScreen(
                trackingNumber: resi,
              ),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDarkMode ? Colors.white10 : slate200,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isCompleted
                    ? Colors.green.withOpacity(0.1)
                    : primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isCompleted ? Icons.check_circle_outline : Icons.inventory_2_outlined,
                color: isCompleted ? Colors.green.shade600 : primaryColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['resi'],
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isDarkMode ? Colors.white : slate900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item['status'],
                    style: TextStyle(
                      color: isDarkMode ? slate400 : slate500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: slate400,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}
