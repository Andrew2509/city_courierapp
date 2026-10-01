import 'package:flutter/material.dart';
import 'package:city_courierapp/screens/home/shipping/select_courier_screen.dart';

class SelectServiceScreen extends StatefulWidget {
  final Map<String, dynamic>? initialCourier;
  final bool asuransiPengiriman;
  final bool packingKayu;

  final String? origin;
  final String? destination;
  final String? originName;
  final String? destinationName;
  final int? weight;

  const SelectServiceScreen({
    super.key,
    this.initialCourier,
    this.asuransiPengiriman = false,
    this.packingKayu = false,
    this.origin,
    this.destination,
    this.originName,
    this.destinationName,
    this.weight,
  });

  @override
  State<SelectServiceScreen> createState() => _SelectServiceScreenState();
}

class _SelectServiceScreenState extends State<SelectServiceScreen> {
  bool get isDarkMode => Theme.of(context).brightness == Brightness.dark;
  bool isAsuransi = false;
  bool isPackingKayu = false;

  Map<String, dynamic> selectedCourier = {
    'code': 'regular',
    'name': 'City Regular',
    'service': 'REGULAR',
    'duration': '1-2 Hari',
    'price': 15000,
    'icon': Icons.local_shipping,
  };

  @override
  void initState() {
    super.initState();
    isAsuransi = widget.asuransiPengiriman;
    isPackingKayu = widget.packingKayu;
    if (widget.initialCourier != null) {
      selectedCourier = widget.initialCourier!;
    }
  }

  String _formatCurrency(int amount) {
    final str = amount.toString();
    return 'Rp${str.replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFEC5B13);
    final bgLight = const Color(0xFFF9FAFB);
    final bgDark = const Color(0xFF0F172A);

    return Scaffold(
        backgroundColor: isDarkMode ? bgDark : bgLight,
        body: Stack(
          children: [
            Column(
              children: [
                _buildHeader(context, primaryColor),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 12,
                      bottom: 120,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPilihKurirSection(
                          context,
                          isDarkMode,
                          primaryColor,
                        ),
                        const SizedBox(height: 16),
                        _buildOpsiTambahanSection(isDarkMode, primaryColor),
                        const SizedBox(height: 16),
                        _buildInfoBox(isDarkMode),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            _buildBottomBar(context, primaryColor, isDarkMode),
          ],
        ),
      );
  }

  Widget _buildHeader(BuildContext context, Color primaryColor) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 20,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      width: double.infinity,
      color: primaryColor,
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Pilih Layanan',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPilihKurirSection(
    BuildContext context,
    bool isDarkMode,
    Color primaryColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'PILIH KURIR',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade400,
              letterSpacing: 1,
            ),
          ),
        ),
        GestureDetector(
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    SelectCourierScreen(
                      currentCourier: selectedCourier,
                      origin: widget.origin,
                      destination: widget.destination,
                      originName: widget.originName,
                      destinationName: widget.destinationName,
                      weight: widget.weight,
                    ),
              ),
            );
            if (result != null && result is Map<String, dynamic>) {
              setState(() {
                selectedCourier = result;
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade100,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.orange.shade900.withValues(alpha: 0.2)
                            : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        selectedCourier['icon'] ?? Icons.local_shipping,
                        color: primaryColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Pilih Kurir',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white : Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      '${selectedCourier['name'].split(' ').last} - ${_formatCurrency(selectedCourier['price'])}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right,
                      color: Colors.grey.shade400,
                      size: 20,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOpsiTambahanSection(bool isDarkMode, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'OPSI TAMBAHAN',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade400,
              letterSpacing: 1,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade100,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
              ),
            ],
          ),
          child: Column(
            children: [
              // Asuransi Switch
              Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? Colors.green.shade900.withValues(alpha: 0.2)
                                : Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.shield,
                            color: Colors.green.shade600,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Asuransi Pengiriman',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode
                                    ? Colors.white
                                    : Colors.grey.shade800,
                              ),
                            ),
                            Text(
                              'Rp2.500',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w500,
                                color: isDarkMode
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Switch(
                      value: isAsuransi,
                      activeColor: Colors.white,
                      activeTrackColor: primaryColor,
                      inactiveThumbColor: Colors.white,
                      inactiveTrackColor: isDarkMode
                          ? Colors.grey.shade700
                          : Colors.grey.shade200,
                      onChanged: (val) {
                        setState(() {
                          isAsuransi = val;
                        });
                      },
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade100,
              ),
              // Packing Kayu Switch
              Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? Colors.amber.shade900.withValues(alpha: 0.2)
                                : Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.inventory_2,
                            color: Colors.amber.shade600,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Packing Kayu',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode
                                    ? Colors.white
                                    : Colors.grey.shade800,
                              ),
                            ),
                            Text(
                              'Rp50.000',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w500,
                                color: isDarkMode
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Switch(
                      value: isPackingKayu,
                      activeColor: Colors.white,
                      activeTrackColor: primaryColor,
                      inactiveThumbColor: Colors.white,
                      inactiveTrackColor: isDarkMode
                          ? Colors.grey.shade700
                          : Colors.grey.shade200,
                      onChanged: (val) {
                        setState(() {
                          isPackingKayu = val;
                        });
                      },
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

  Widget _buildInfoBox(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.blue.shade900.withValues(alpha: 0.1)
            : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info, color: Colors.blue.shade500, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Pilih layanan sesuai kebutuhan. Estimasi waktu terhitung sejak kurir menjemput paket.',
              style: TextStyle(
                fontSize: 9,
                color: isDarkMode ? Colors.blue.shade300 : Colors.blue.shade700,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(
    BuildContext context,
    Color primaryColor,
    bool isDarkMode,
  ) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
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
          onTap: () {
            // Return to pickup screen with selection detail
            Navigator.pop(context, {
              'status': 'tersimpan',
              'courier': selectedCourier,
              'asuransi': isAsuransi,
              'packingKayu': isPackingKayu,
            });
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Text(
              'Konfirmasi',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
