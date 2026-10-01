import 'package:flutter/material.dart';
import 'package:city_courierapp/screens/widgets/home/theme_toggle_fab.dart';
import 'package:city_courierapp/services/shipping/rajaongkir_service.dart';

class SelectCourierScreen extends StatefulWidget {
  final Map<String, dynamic>? currentCourier;
  final String? origin;
  final String? destination;
  final String? originName;
  final String? destinationName;
  final int? weight;

  const SelectCourierScreen({
    super.key,
    this.currentCourier,
    this.origin,
    this.destination,
    this.originName,
    this.destinationName,
    this.weight,
  });

  @override
  State<SelectCourierScreen> createState() => _SelectCourierScreenState();
}

class _SelectCourierScreenState extends State<SelectCourierScreen> {
  bool isDarkMode = false;
  String selectedCourierCode = 'regular';
  bool isLoading = true;
  String? errorMessage;

  List<Map<String, dynamic>> availableCouriers = [
    {
      'code': 'express',
      'name': 'City Express',
      'service': 'EXPRESS',
      'duration': 'Besok Sampai',
      'price': 25000,
      'icon': Icons.bolt,
    },
    {
      'code': 'regular',
      'name': 'City Regular',
      'service': 'REGULAR',
      'duration': '1-2 Hari',
      'price': 15000,
      'icon': Icons.local_shipping,
    },
    {
      'code': 'cargo',
      'name': 'City Cargo',
      'service': 'CARGO',
      'duration': '3-5 Hari',
      'price': 55000,
      'icon': Icons.inventory_2,
    },
  ];

  @override
  void initState() {
    super.initState();
    if (widget.currentCourier != null) {
      selectedCourierCode = widget.currentCourier!['code'] ?? 'regular';
    }
    _fetchShippingCosts();
  }

  Future<void> _fetchShippingCosts() async {
    if (widget.origin == null || widget.destination == null) {
      setState(() {
        isLoading = false;
        errorMessage = 'Data lokasi pengiriman tidak lengkap';
      });
      return;
    }

    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      // Backend now returns all available couriers in one call
      final result = await RajaOngkirService.calculateCost(
        origin: widget.origin!,
        destination: widget.destination!,
        weight: widget.weight ?? 1000,
        courier: 'jne:pos:tiki', // Request multiple couriers
      );

      final List<Map<String, dynamic>> newCouriers = [];

      if (result['success'] == true && result['data'] != null) {
        final List<dynamic> couriersData = result['data'];
        
        for (var courier in couriersData) {
          final String courierCode = courier['code'] ?? '';
          final String courierName = courier['name'] ?? '';
          final List<dynamic> costs = courier['costs'] ?? [];

          for (var service in costs) {
            final String serviceName = service['service'] ?? '';
            final dynamic costDetail = service['cost'][0];
            
            newCouriers.add({
              'code': courierCode,
              'name': '$courierName $serviceName',
              'service': serviceName,
              'duration': costDetail['etd'].toString().contains('HARI') 
                  ? costDetail['etd'] 
                  : '${costDetail['etd']} Hari',
              'price': (costDetail['value'] as num).toInt(),
              'icon': _getCourierIcon(courierCode),
            });
          }
        }
      }

      setState(() {
        if (newCouriers.isNotEmpty) {
          availableCouriers = newCouriers;
          // Select first one if current not in list
          bool exists = availableCouriers.any((c) => c['code'] == selectedCourierCode);
          if (!exists) {
            selectedCourierCode = availableCouriers.first['code'];
          }
        } else if (result['success'] == false) {
          errorMessage = result['message'] ?? 'Tidak ada layanan pengiriman tersedia';
        }
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Gagal mengambil biaya pengiriman: $e';
      });
    }
  }

  IconData _getCourierIcon(String code) {
    switch (code.toLowerCase()) {
      case 'jne': return Icons.local_shipping;
      case 'pos': return Icons.mail;
      case 'tiki': return Icons.delivery_dining;
      case 'sicepat': return Icons.bolt;
      case 'jnt': return Icons.rocket_launch;
      default: return Icons.local_shipping;
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
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 12,
                      bottom: 120,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSummaryCard(isDarkMode, primaryColor),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 8,
                          ),
                          child: Text(
                            'LAYANAN TERSEDIA',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode
                                  ? Colors.grey.shade500
                                  : Colors.grey.shade400,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        if (isLoading)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32.0),
                              child: CircularProgressIndicator(color: Color(0xFFEC5B13)),
                            ),
                          )
                        else if (errorMessage != null)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Column(
                                children: [
                                  Icon(Icons.error_outline, color: Colors.red.shade300, size: 48),
                                  const SizedBox(height: 16),
                                  Text(
                                    errorMessage!,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: isDarkMode ? Colors.white70 : Colors.black54,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _fetchShippingCosts,
                                    child: const Text('Coba Lagi'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ...availableCouriers
                              .map(
                                (courier) => _buildCourierItem(
                                  courier,
                                  isDarkMode,
                                  primaryColor,
                                ),
                              )
                              .toList(),
                        const SizedBox(height: 12),
                _buildInfoBox(isDarkMode),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            _buildBottomBar(context, primaryColor, isDarkMode),
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
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        bottom: 12,
      ),
      width: double.infinity,
      color: primaryColor,
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'PILIH KURIR',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(bool isDarkMode, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade100,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'RINGKASAN PENGIRIMAN',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade400,
                  letterSpacing: 1,
                ),
              ),
              Text(
                widget.weight != null ? '${(widget.weight! / 1000).toStringAsFixed(1)} kg' : '1.0 kg',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  const SizedBox(height: 6),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: primaryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Container(
                    width: 2,
                    height: 20,
                    color: isDarkMode
                        ? Colors.grey.shade700
                        : Colors.grey.shade100,
                  ),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.originName ?? 'Lokasi Pengirim',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode
                          ? Colors.grey.shade200
                          : Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.destinationName ?? 'Lokasi Penerima',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode
                          ? Colors.grey.shade200
                          : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCourierItem(
    Map<String, dynamic> courier,
    bool isDarkMode,
    Color primaryColor,
  ) {
    bool isSelected = selectedCourierCode == courier['code'];
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedCourierCode = courier['code'];
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? primaryColor
                : (isDarkMode ? Colors.grey.shade700 : Colors.grey.shade100),
            width: isSelected ? 2 : 1,
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
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isDarkMode
                                ? Colors.orange.shade900.withValues(alpha: 0.2)
                                : Colors.orange.shade50)
                          : (isDarkMode
                                ? const Color(0xFF0F172A).withValues(alpha: 0.4)
                                : Colors.grey.shade50),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      courier['icon'],
                      color: isSelected ? primaryColor : Colors.grey.shade400,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                courier['name'],
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode
                                      ? Colors.white
                                      : Colors.grey.shade800,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.info, size: 12, color: Colors.grey.shade300),
                          ],
                        ),
                        Text(
                          courier['duration'],
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: isDarkMode
                                ? Colors.grey.shade400
                                : Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatCurrency(courier['price']),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: primaryColor,
                  ),
                ),
                if (isSelected)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBox(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.blue.shade900.withValues(alpha: 0.1)
            : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info, color: Colors.blue.shade500, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Harga estimasi real-time berdasarkan berat paket & jarak tempuh.',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                color: isDarkMode ? Colors.blue.shade300 : Colors.blue.shade700,
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
          left: 12,
          right: 12,
          top: 12,
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
            final selected = availableCouriers.firstWhere(
              (c) => c['code'] == selectedCourierCode,
            );
            Navigator.pop(context, selected);
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: BorderRadius.circular(8),
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
              'Pilih Kurir',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
