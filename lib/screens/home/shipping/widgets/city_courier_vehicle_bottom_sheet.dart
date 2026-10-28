import 'package:flutter/material.dart';
import 'package:city_courierapp/models/shipping/vehicle_capacity_config.dart';
import 'package:city_courierapp/services/shipping/city_courier_tariff_service.dart';

/// Modal Bottom Sheet Pemilihan Kendaraan & Layanan Instan City Courier.
/// Menyesuaikan dengan konsep UX & layout GoSend (Gambar 2):
/// - Desain kartu kendaraan Motor & Mobil dengan badge kapasitas (Maks. 20 kg / 100 kg)
/// - Label durasi instan (Estimasi waktu) & deskripsi layanan
/// - Harga dinamis berbasis jarak & berat
/// - Warna dan tema tetap konsisten dengan identitas brand City Courier
class CityCourierVehicleBottomSheet extends StatefulWidget {
  final String initialVehicle;
  final double shippingWeight;
  final double length;
  final double width;
  final double height;
  final double distanceKm;
  final bool isScheduled;
  final DateTime? scheduledDateTime;
  final String? scheduledTimeText;
  final Color primaryColor;
  final bool isDarkMode;
  final DateTime? referenceNow;

  const CityCourierVehicleBottomSheet({
    super.key,
    required this.initialVehicle,
    required this.shippingWeight,
    required this.length,
    required this.width,
    required this.height,
    required this.distanceKm,
    this.isScheduled = false,
    this.scheduledDateTime,
    this.scheduledTimeText,
    required this.primaryColor,
    required this.isDarkMode,
    this.referenceNow,
  });

  /// Menampilkan modal bottom sheet pilihan kendaraan secara mudah
  static Future<Map<String, dynamic>?> show({
    required BuildContext context,
    required String initialVehicle,
    required double shippingWeight,
    required double length,
    required double width,
    required double height,
    required double distanceKm,
    bool isScheduled = false,
    DateTime? scheduledDateTime,
    String? scheduledTimeText,
    required Color primaryColor,
    required bool isDarkMode,
    DateTime? referenceNow,
  }) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CityCourierVehicleBottomSheet(
        initialVehicle: initialVehicle,
        shippingWeight: shippingWeight,
        length: length,
        width: width,
        height: height,
        distanceKm: distanceKm,
        isScheduled: isScheduled,
        scheduledDateTime: scheduledDateTime,
        scheduledTimeText: scheduledTimeText,
        primaryColor: primaryColor,
        isDarkMode: isDarkMode,
        referenceNow: referenceNow,
      ),
    );
  }

  @override
  State<CityCourierVehicleBottomSheet> createState() =>
      _CityCourierVehicleBottomSheetState();
}

class _CityCourierVehicleBottomSheetState
    extends State<CityCourierVehicleBottomSheet> {
  late String _selectedVehicle;

  bool get _isMotorEligible {
    return VehicleCapacityConfig.motor.fits(
      weight: widget.shippingWeight,
      length: widget.length,
      width: widget.width,
      height: widget.height,
    );
  }

  bool get _isMobilEligible {
    return VehicleCapacityConfig.mobil.fits(
      weight: widget.shippingWeight,
      length: widget.length,
      width: widget.width,
      height: widget.height,
    );
  }

  bool get _isOverCapacity => !_isMotorEligible && !_isMobilEligible;

  @override
  void initState() {
    super.initState();
    final init = widget.initialVehicle.toLowerCase();
    if (init == 'mobil' && _isMobilEligible) {
      _selectedVehicle = 'mobil';
    } else if (init == 'motor' && _isMotorEligible) {
      _selectedVehicle = 'motor';
    } else if (_isMotorEligible) {
      _selectedVehicle = 'motor';
    } else if (_isMobilEligible) {
      _selectedVehicle = 'mobil';
    } else {
      _selectedVehicle = 'motor';
    }
  }

  int _getPrice(String vehicle) {
    return CityCourierTariffService.calculatePrice(
      vehicleType: vehicle,
      distanceKm: widget.distanceKm,
      shippingWeightKg: widget.shippingWeight,
    );
  }

  String _getDuration(String vehicle) {
    return CityCourierTariffService.calculateEstimationText(
      vehicleType: vehicle,
      distanceKm: widget.distanceKm,
      isScheduled: widget.isScheduled,
      scheduledDateTime: widget.scheduledDateTime,
      referenceNow: widget.referenceNow,
    );
  }

  String _formatCurrency(int amount) {
    final str = amount.toString();
    return 'Rp${str.replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  String _formatWeight(double val) {
    return val % 1 == 0 ? '${val.toInt()} kg' : '${val.toStringAsFixed(1)} kg';
  }

  String _getMotorIneligibilityReason() {
    if (widget.shippingWeight > VehicleCapacityConfig.motor.maxWeight) {
      return 'Berat ${_formatWeight(widget.shippingWeight)} melebihi batas motor (${VehicleCapacityConfig.motor.maxWeight.toInt()} kg)';
    }
    if (widget.length > VehicleCapacityConfig.motor.maxLength) {
      return 'Panjang ${widget.length.toStringAsFixed(0)} cm melebihi batas motor (${VehicleCapacityConfig.motor.maxLength.toInt()} cm)';
    }
    if (widget.width > VehicleCapacityConfig.motor.maxWidth) {
      return 'Lebar ${widget.width.toStringAsFixed(0)} cm melebihi batas motor (${VehicleCapacityConfig.motor.maxWidth.toInt()} cm)';
    }
    if (widget.height > VehicleCapacityConfig.motor.maxHeight) {
      return 'Tinggi ${widget.height.toStringAsFixed(0)} cm melebihi batas motor (${VehicleCapacityConfig.motor.maxHeight.toInt()} cm)';
    }
    return 'Melebihi batas kapasitas motor';
  }

  @override
  Widget build(BuildContext context) {
    final bgCard = widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final textMain = widget.isDarkMode ? Colors.white : Colors.grey.shade900;
    final textSub = widget.isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600;

    return Container(
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        top: 12,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Drag Handle
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: widget.isDarkMode
                    ? Colors.grey.shade700
                    : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 2. Header Info Layanan
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PILIH KENDARAAN',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: textMain,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Jarak ~${widget.distanceKm} km • Berat: ${_formatWeight(widget.shippingWeight)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: textSub,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Kurir Instan',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: widget.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 3. Status Over Capacity Warning
          if (_isOverCapacity) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade700, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      VehicleCapacityConfig.messageOverCapacity,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.red.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // 4. Daftar Kartu Kendaraan (Layout Konsep GoSend Image 2)
          _buildVehicleCard(
            key: const Key('vehicle_sheet_motor'),
            vehicleId: 'motor',
            title: 'City Courier Motor',
            capacityDesc: 'Maks. 20 kg',
            dimensionDesc: '40×40×50 cm',
            icon: Icons.two_wheeler,
            tagBadge: 'CEPAT',
            subDescription: 'Langsung dijemput & dikirim',
            isEligible: _isMotorEligible,
            ineligibleReason: _getMotorIneligibilityReason(),
          ),
          const SizedBox(height: 12),

          _buildVehicleCard(
            key: const Key('vehicle_sheet_mobil'),
            vehicleId: 'mobil',
            title: 'City Courier Mobil',
            capacityDesc: 'Maks. 100 kg',
            dimensionDesc: '100×100×80 cm',
            icon: Icons.directions_car,
            tagBadge: 'MUATAN BESAR',
            subDescription: 'Cocok untuk barang besar & banyak',
            isEligible: _isMobilEligible,
            ineligibleReason: 'Melebihi kapasitas mobil (maks. 100 kg)',
          ),
          const SizedBox(height: 14),

          // 5. Promo / Keunggulan Info Banner (Sesuai Gambar 2 GoSend)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: widget.primaryColor.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.primaryColor.withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: widget.primaryColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.local_offer_outlined,
                    color: widget.primaryColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tarif Transparan & Terjangkau',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: textMain,
                        ),
                      ),
                      Text(
                        'Pengiriman instan aman dan bergaransi di dalam kota',
                        style: TextStyle(
                          fontSize: 11,
                          color: textSub,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: widget.primaryColor,
                  size: 20,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 6. Tombol Aksi "Lanjut" (Gambar 2 GoSend)
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              key: const Key('btn_lanjut_vehicle_sheet'),
              onPressed: _isOverCapacity
                  ? null
                  : () {
                      final selectedPrice = _getPrice(_selectedVehicle);
                      final selectedDuration = _getDuration(_selectedVehicle);
                      final courierData = {
                        'code': _selectedVehicle,
                        'courier_code': _selectedVehicle,
                        'name': _selectedVehicle == 'mobil' ? 'Mobil' : 'Motor',
                        'service': 'Instant',
                        'price': selectedPrice,
                        'duration': selectedDuration,
                        'vehicle': _selectedVehicle,
                        'vehicle_type': _selectedVehicle,
                        'isScheduled': widget.isScheduled,
                        'scheduledDateTime': widget.scheduledDateTime,
                        'scheduledTimeText': widget.scheduledTimeText,
                      };
                      Navigator.pop(context, courierData);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.primaryColor,
                disabledBackgroundColor: Colors.grey.shade400,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Lanjut',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET KARTU KENDARAAN (PERSIS SEPERTI GAMBAR 2 GOSEND) ---
  Widget _buildVehicleCard({
    Key? key,
    required String vehicleId,
    required String title,
    required String capacityDesc,
    required String dimensionDesc,
    required IconData icon,
    required String tagBadge,
    required String subDescription,
    required bool isEligible,
    required String ineligibleReason,
  }) {
    final isSelected = _selectedVehicle == vehicleId && isEligible;
    final price = _getPrice(vehicleId);
    final duration = _getDuration(vehicleId);

    final borderColor = isSelected
        ? widget.primaryColor
        : (widget.isDarkMode ? Colors.grey.shade700 : const Color(0xFFE2E8F0));
    final bgColor = isSelected
        ? widget.primaryColor.withOpacity(0.05)
        : (widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white);

    return Opacity(
      opacity: isEligible ? 1.0 : 0.55,
      child: GestureDetector(
        key: key,
        onTap: isEligible
            ? () {
                setState(() {
                  _selectedVehicle = vehicleId;
                });
              }
            : null,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: borderColor,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: widget.primaryColor.withOpacity(0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Icon, Title, Capacity, Price & Radio Indicator
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Vehicle Icon
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? widget.primaryColor.withOpacity(0.15)
                          : (widget.isDarkMode
                              ? Colors.grey.shade800
                              : Colors.grey.shade100),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      color: isSelected
                          ? widget.primaryColor
                          : (widget.isDarkMode
                              ? Colors.grey.shade400
                              : Colors.grey.shade700),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Title & Capacity
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: widget.isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$capacityDesc • $dimensionDesc',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: widget.isDarkMode
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Price & Radio Selector (Sesuai Gambar 2 GoSend)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatCurrency(price),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: isSelected
                              ? widget.primaryColor
                              : (widget.isDarkMode
                                  ? Colors.white
                                  : Colors.grey.shade900),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? widget.primaryColor
                                : Colors.grey.shade400,
                            width: 2,
                          ),
                          color: isSelected
                              ? widget.primaryColor
                              : Colors.transparent,
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 14,
                              )
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Row 2: Badge Estimasi & Sub-deskripsi (Persis GoSend Gambar 2)
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: widget.primaryColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      tagBadge,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: widget.primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: widget.isDarkMode
                          ? Colors.grey.shade800
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: widget.isDarkMode
                            ? Colors.grey.shade700
                            : Colors.grey.shade300,
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      duration,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: widget.isDarkMode
                            ? Colors.grey.shade300
                            : Colors.grey.shade800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      subDescription,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: widget.isDarkMode
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),

              // Peringatan jika melebihi batas motor/mobil
              if (!isEligible) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 14, color: Colors.red.shade600),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        ineligibleReason,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.red.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

