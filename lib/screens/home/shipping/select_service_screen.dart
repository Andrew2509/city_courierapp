import 'package:flutter/material.dart';
import 'package:city_courierapp/screens/home/shipping/select_courier_screen.dart';
import 'package:city_courierapp/services/shipping/city_courier_tariff_service.dart';

class SelectServiceScreen extends StatefulWidget {
  final Map<String, dynamic>? initialCourier;
  final bool asuransiPengiriman;
  final bool packingKayu;

  final String? origin;
  final String? destination;
  final String? originName;
  final String? destinationName;
  final int? weight;

  // Parameter pengiriman instan & kendaraan lengkap
  final Map<String, dynamic>? senderData;
  final Map<String, dynamic>? receiverData;
  final double? actualWeight;
  final double? volumetricWeight;
  final double? shippingWeight;
  final double? length;
  final double? width;
  final double? height;
  final String? selectedVehicle;
  final bool? isScheduledPickup;
  final DateTime? pickupScheduledAt;
  final String? pickupTimeText;
  final DateTime? referenceNow;

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
    this.senderData,
    this.receiverData,
    this.actualWeight,
    this.volumetricWeight,
    this.shippingWeight,
    this.length,
    this.width,
    this.height,
    this.selectedVehicle,
    this.isScheduledPickup,
    this.pickupScheduledAt,
    this.pickupTimeText,
    this.referenceNow,
  });

  @override
  State<SelectServiceScreen> createState() => _SelectServiceScreenState();
}

class _SelectServiceScreenState extends State<SelectServiceScreen> {
  bool get isDarkMode => Theme.of(context).brightness == Brightness.dark;
  bool isAsuransi = false;
  bool isPackingKayu = false;

  late Map<String, dynamic> selectedCourier;

  @override
  void initState() {
    super.initState();
    isAsuransi = widget.asuransiPengiriman;
    isPackingKayu = widget.packingKayu;

    if (widget.initialCourier != null) {
      selectedCourier = Map<String, dynamic>.from(widget.initialCourier!);
    } else {
      final isMobil = (widget.selectedVehicle ?? '').toLowerCase() == 'mobil';
      final defaultDist = CityCourierTariffService.calculateDistanceKm(
        originLat: widget.senderData?['latitude'],
        originLng: widget.senderData?['longitude'],
        destLat: widget.receiverData?['latitude'],
        destLng: widget.receiverData?['longitude'],
        originName: widget.originName ?? widget.senderData?['city_name']?.toString(),
        destName: widget.destinationName ?? widget.receiverData?['city_name']?.toString(),
      );

      final weightKg = widget.shippingWeight ??
          ((widget.weight != null && widget.weight! > 0)
              ? widget.weight! / 1000.0
              : 1.0);

      final vType = isMobil ? 'mobil' : 'motor';
      final price = CityCourierTariffService.calculatePrice(
        vehicleType: vType,
        distanceKm: defaultDist,
        shippingWeightKg: weightKg,
      );
      final duration = CityCourierTariffService.calculateEstimationText(
        vehicleType: vType,
        distanceKm: defaultDist,
        isScheduled: widget.isScheduledPickup ?? false,
        scheduledDateTime: widget.pickupScheduledAt,
        referenceNow: widget.referenceNow,
      );

      selectedCourier = {
        'code': vType,
        'name': isMobil ? 'Mobil' : 'Motor',
        'service': 'Instant',
        'description': isMobil ? 'Cocok untuk barang besar' : 'Cocok untuk barang kecil',
        'duration': duration,
        'price': price,
        'vehicle': vType,
        'is_sameday': true,
        'icon': isMobil ? Icons.directions_car : Icons.two_wheeler,
        'isScheduled': widget.isScheduledPickup ?? false,
        'scheduledDateTime': widget.pickupScheduledAt,
        'scheduledTimeText': widget.pickupTimeText,
      };
    }
  }

  int get courierPrice => (selectedCourier['price'] as int?) ?? 12600;
  int get asuransiPrice => isAsuransi ? 2500 : 0;
  int get packingKayuPrice => isPackingKayu ? 50000 : 0;
  int get totalPrice => courierPrice + asuransiPrice + packingKayuPrice;

  String _formatCurrency(int amount) {
    final str = amount.toString();
    return 'Rp${str.replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  String get _courierNameLabel {
    final rawName = selectedCourier['name']?.toString() ?? 'Motor';
    if (rawName.toLowerCase().contains('mobil')) return 'Mobil';
    return 'Motor';
  }

  String get _courierServiceLabel {
    return 'Instant';
  }

  String get _courierDurationLabel {
    final raw = selectedCourier['duration']?.toString();
    if (raw != null && raw.isNotEmpty && !raw.contains('UNKNOWN') && !raw.contains('day hari')) {
      return raw;
    }
    return 'Estimasi 30–60 menit';
  }

  IconData get _courierIcon {
    final code = (selectedCourier['vehicle'] ?? selectedCourier['code'] ?? '')
        .toString()
        .toLowerCase();
    if (code.contains('mobil') || code.contains('car')) {
      return Icons.directions_car;
    }
    return Icons.two_wheeler;
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFEC5B13);
    const bgLight = Color(0xFFF8FAFC);
    const bgDark = Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: isDarkMode ? bgDark : bgLight,
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(context, primaryColor),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // SECTION 1: PILIH KENDARAAN
                      _buildPilihKendaraanSection(context, isDarkMode, primaryColor),
                      const SizedBox(height: 22),

                      // SECTION 2: OPSI TAMBAHAN
                      _buildOpsiTambahanSection(isDarkMode, primaryColor),
                      const SizedBox(height: 20),

                      // SECTION 3: INFO BOX
                      _buildInfoBox(isDarkMode),
                      const SizedBox(height: 120),
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

  // --- HEADER SCREEN ---
  Widget _buildHeader(BuildContext context, Color primaryColor) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        bottom: 16,
        left: 16,
        right: 16,
      ),
      color: primaryColor,
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 14),
          const Text(
            'Pilih Layanan',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // --- SECTION 1: PILIH KENDARAAN (Sesuai Poin 11) ---
  Widget _buildPilihKendaraanSection(
    BuildContext context,
    bool isDarkMode,
    Color primaryColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PILIH KENDARAAN',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.grey.shade400 : const Color(0xFF64748B),
                  letterSpacing: 0.8,
                ),
              ),
              const Text(
                'Tersedia 2 Opsi Kendaraan',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFEA580C),
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SelectCourierScreen(
                  currentCourier: selectedCourier,
                  origin: widget.origin,
                  destination: widget.destination,
                  originName: widget.originName,
                  destinationName: widget.destinationName,
                  weight: widget.weight,
                  senderData: widget.senderData,
                  receiverData: widget.receiverData,
                  actualWeight: widget.actualWeight,
                  volumetricWeight: widget.volumetricWeight,
                  shippingWeight: widget.shippingWeight,
                  length: widget.length,
                  width: widget.width,
                  height: widget.height,
                  selectedVehicle: selectedCourier['vehicle'] ?? widget.selectedVehicle,
                  isScheduledPickup: selectedCourier['isScheduled'] ?? widget.isScheduledPickup,
                  pickupScheduledAt: selectedCourier['scheduledDateTime'] ?? widget.pickupScheduledAt,
                  pickupTimeText: selectedCourier['scheduledTimeText'] ?? widget.pickupTimeText,
                  referenceNow: widget.referenceNow,
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
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDarkMode ? Colors.grey.shade700 : const Color(0xFFE2E8F0),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDarkMode ? 0.15 : 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Icon Box
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.orange.shade900.withOpacity(0.2)
                        : const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDarkMode
                          ? Colors.orange.shade800
                          : const Color(0xFFFFEDD5),
                    ),
                  ),
                  child: Icon(
                    _courierIcon,
                    color: const Color(0xFFEC5B13),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),

                // Title & Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _courierNameLabel,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _courierDurationLabel,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),

                // Service & Price
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _courierServiceLabel,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFEC5B13),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatCurrency(courierPrice),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 6),

                // Chevron
                Icon(
                  Icons.chevron_right,
                  color: Colors.grey.shade400,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- SECTION 2: OPSI TAMBAHAN ---
  Widget _buildOpsiTambahanSection(bool isDarkMode, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(
            'OPSI TAMBAHAN',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.grey.shade400 : const Color(0xFF64748B),
              letterSpacing: 0.8,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDarkMode ? Colors.grey.shade700 : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDarkMode ? 0.15 : 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Opsi 1: Asuransi Pengiriman
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.blue.shade900.withOpacity(0.2)
                            : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.verified_user_outlined,
                        color: Color(0xFF2563EB),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Asuransi Pengiriman',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 3),
                          RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade500,
                              ),
                              children: const [
                                TextSpan(
                                  text: '+Rp2.500',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2563EB),
                                  ),
                                ),
                                TextSpan(
                                  text: ' • Perlindungan hingga Rp10.000.000',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: isAsuransi,
                      activeColor: Colors.white,
                      activeTrackColor: primaryColor,
                      inactiveThumbColor: Colors.white,
                      inactiveTrackColor: isDarkMode
                          ? Colors.grey.shade700
                          : const Color(0xFFE2E8F0),
                      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
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
                color: isDarkMode ? Colors.grey.shade800 : const Color(0xFFF1F5F9),
              ),

              // Opsi 2: Packing Kayu
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.amber.shade900.withOpacity(0.2)
                            : const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.inventory_2_outlined,
                        color: Color(0xFFD97706),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Packing Kayu',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 3),
                          RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade500,
                              ),
                              children: const [
                                TextSpan(
                                  text: '+Rp50.000',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFD97706),
                                  ),
                                ),
                                TextSpan(
                                  text: ' • Khusus barang pecah belah',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: isPackingKayu,
                      activeColor: Colors.white,
                      activeTrackColor: primaryColor,
                      inactiveThumbColor: Colors.white,
                      inactiveTrackColor: isDarkMode
                          ? Colors.grey.shade700
                          : const Color(0xFFE2E8F0),
                      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
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

  // --- SECTION 3: INFO BOX ---
  Widget _buildInfoBox(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.blue.shade900.withOpacity(0.18)
            : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDarkMode
              ? Colors.blue.shade800.withOpacity(0.4)
              : const Color(0xFFDBEAFE),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info, color: Color(0xFF3B82F6), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Layanan instan City Courier mengirimkan paket secara langsung dalam kota. Estimasi waktu terhitung sejak penjemputan paket.',
              style: TextStyle(
                fontSize: 11.5,
                color: isDarkMode ? Colors.blue.shade200 : const Color(0xFF1E40AF),
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- STICKY FOOTER / BOTTOM BAR ---
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
          top: 14,
          bottom: MediaQuery.of(context).padding.bottom + 14,
        ),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF0F172A) : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDarkMode ? Colors.grey.shade800 : const Color(0xFFF1F5F9),
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Row Estimasi Biaya
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Estimasi Biaya Ongkir & Tambahan',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode ? Colors.grey.shade400 : const Color(0xFF64748B),
                  ),
                ),
                Text(
                  _formatCurrency(totalPrice),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Tombol Konfirmasi dengan Panah Kanan
            GestureDetector(
              onTap: () {
                Navigator.pop(context, {
                  'status': 'tersimpan',
                  'courier': selectedCourier,
                  'asuransi': isAsuransi,
                  'packingKayu': isPackingKayu,
                  if (selectedCourier['vehicle'] != null)
                    'vehicle': selectedCourier['vehicle'],
                  if (selectedCourier['isScheduled'] != null)
                    'isScheduled': selectedCourier['isScheduled'],
                  if (selectedCourier['scheduledDateTime'] != null)
                    'scheduledDateTime': selectedCourier['scheduledDateTime'],
                  if (selectedCourier['scheduledTimeText'] != null)
                    'scheduledTimeText': selectedCourier['scheduledTimeText'],
                });
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Konfirmasi',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward,
                      color: Colors.white,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
