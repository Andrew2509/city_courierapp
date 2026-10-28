import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:city_courierapp/services/shipping/rajaongkir_service.dart';
import 'package:city_courierapp/services/shipping/city_courier_tariff_service.dart';
import 'package:city_courierapp/models/shipping/vehicle_capacity_config.dart';
import 'package:city_courierapp/models/shipping/schedule_time_config.dart';
import 'package:city_courierapp/screens/home/shipping/widgets/pickup_time_bottom_sheet.dart';

/// Halaman Pemilihan Kendaraan & Layanan Instan City Courier (konsep on-demand seperti GoSend).
/// Menampilkan kendaraan Motor dan Mobil sesuai kapasitas ukuran & berat barang.
class SelectCourierScreen extends StatefulWidget {
  final Map<String, dynamic>? currentCourier;
  final String? origin;
  final String? destination;
  final String? originName;
  final String? destinationName;
  final int? weight; // gram

  // Parameter pengiriman lengkap dari form pickup / informasi barang
  final Map<String, dynamic>? senderData;
  final Map<String, dynamic>? receiverData;
  final double? actualWeight; // kg
  final double? volumetricWeight; // kg
  final double? shippingWeight; // kg
  final double? length; // cm
  final double? width; // cm
  final double? height; // cm
  final String? selectedVehicle; // 'motor' atau 'mobil'
  final bool? isScheduledPickup;
  final DateTime? pickupScheduledAt;
  final String? pickupTimeText;
  final DateTime? referenceNow; // Untuk kemudahan testing & sinkronisasi waktu

  const SelectCourierScreen({
    super.key,
    this.currentCourier,
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
  State<SelectCourierScreen> createState() => _SelectCourierScreenState();
}

class _SelectCourierScreenState extends State<SelectCourierScreen> {
  bool get isDarkMode => Theme.of(context).brightness == Brightness.dark;

  late double _itemLength;
  late double _itemWidth;
  late double _itemHeight;
  late double _actualWeightKg;
  late double _volumetricWeightKg;
  late double _shippingWeightKg;

  late double _distanceKm;
  late VehicleDetectionResult _detection;

  String? _selectedVehicle; // 'motor' atau 'mobil'
  late bool _isScheduled;
  DateTime? _scheduledDateTime;
  String? _scheduledTimeText;


  DateTime get _now => widget.referenceNow ?? DateTime.now();

  @override
  void initState() {
    super.initState();

    // 1. Ekstraksi dimensi barang (default 30x20x15 jika tidak diinput)
    _itemLength = widget.length ?? 30.0;
    _itemWidth = widget.width ?? 20.0;
    _itemHeight = widget.height ?? 15.0;

    // 2. Ekstraksi berat barang
    if (widget.actualWeight != null && widget.actualWeight! > 0) {
      _actualWeightKg = widget.actualWeight!;
    } else if (widget.weight != null && widget.weight! > 0) {
      _actualWeightKg = widget.weight! / 1000.0;
    } else {
      _actualWeightKg = 1.0;
    }

    // 3. Perhitungan Berat Volumetrik: (P × L × T) ÷ 6000
    _volumetricWeightKg = widget.volumetricWeight ??
        CityCourierTariffService.calculateVolumetricWeight(
          length: _itemLength,
          width: _itemWidth,
          height: _itemHeight,
        );

    // 4. Berat Pengiriman: MAX(Berat Aktual, Berat Volumetrik)
    _shippingWeightKg = widget.shippingWeight ??
        CityCourierTariffService.calculateShippingWeight(
          actualWeight: _actualWeightKg,
          volumetricWeight: _volumetricWeightKg,
        );

    // 5. Evaluasi kapasitas kendaraan berdasarkan spesifikasi City Courier
    _detection = VehicleCapacityConfig.detect(
      weight: _actualWeightKg,
      length: _itemLength,
      width: _itemWidth,
      height: _itemHeight,
    );

    // 6. Inisialisasi jenis kendaraan terpilih
    if (_detection.isOverCapacity) {
      _selectedVehicle = null;
    } else if (widget.selectedVehicle != null) {
      final desired = widget.selectedVehicle!.toLowerCase();
      if (desired == 'motor' && _isMotorEligible) {
        _selectedVehicle = 'motor';
      } else if (desired == 'mobil' && _isMobilEligible) {
        _selectedVehicle = 'mobil';
      } else {
        _selectedVehicle = _detection.recommendedVehicle;
      }
    } else if (widget.currentCourier != null &&
        widget.currentCourier!['vehicle'] != null) {
      final curVeh = widget.currentCourier!['vehicle'].toString().toLowerCase();
      if (curVeh == 'mobil' && _isMobilEligible) {
        _selectedVehicle = 'mobil';
      } else if (curVeh == 'motor' && _isMotorEligible) {
        _selectedVehicle = 'motor';
      } else {
        _selectedVehicle = _detection.recommendedVehicle;
      }
    } else {
      _selectedVehicle = _detection.recommendedVehicle;
    }

    // 7. Inisialisasi jadwal pickup
    _isScheduled = widget.isScheduledPickup ?? false;
    _scheduledDateTime = widget.pickupScheduledAt;
    _scheduledTimeText = widget.pickupTimeText;

    // Jika di luar jam operasional dan pickup sekarang, defaultkan ke jadwal besok
    final isOperating = CityCourierTariffService.isOperatingNow(referenceNow: _now);
    if (!isOperating && !_isScheduled) {
      _isScheduled = true;
      _scheduledDateTime = ScheduleTimeConfig.getInitialPickupDateTime(referenceNow: _now);
      _scheduledTimeText = ScheduleTimeConfig.format12Hour(
        _scheduledDateTime!.hour,
        _scheduledDateTime!.minute,
      );
    } else if (_isScheduled && _scheduledDateTime == null) {
      _scheduledDateTime = ScheduleTimeConfig.getInitialPickupDateTime(referenceNow: _now);
      _scheduledTimeText = ScheduleTimeConfig.format12Hour(
        _scheduledDateTime!.hour,
        _scheduledDateTime!.minute,
      );
    }

    // 8. Hitung estimasi jarak pengiriman
    _distanceKm = CityCourierTariffService.calculateDistanceKm(
      originLat: widget.senderData?['latitude'],
      originLng: widget.senderData?['longitude'],
      destLat: widget.receiverData?['latitude'],
      destLng: widget.receiverData?['longitude'],
      originName: widget.originName ?? widget.senderData?['city_name']?.toString(),
      destName: widget.destinationName ?? widget.receiverData?['city_name']?.toString(),
    );

    // 9. Query referensi RajaOngkir di background jika ada endpoint origin/destination
    if (widget.origin != null && widget.destination != null) {
      _fetchRajaOngkirBackground();
    }
  }

  bool get _isMotorEligible {
    return VehicleCapacityConfig.motor.fits(
      weight: _shippingWeightKg,
      length: _itemLength,
      width: _itemWidth,
      height: _itemHeight,
    );
  }

  bool get _isMobilEligible {
    return VehicleCapacityConfig.mobil.fits(
      weight: _shippingWeightKg,
      length: _itemLength,
      width: _itemWidth,
      height: _itemHeight,
    );
  }

  String _getMotorIneligibilityReason() {
    if (_shippingWeightKg > VehicleCapacityConfig.motor.maxWeight) {
      return 'Berat ${_formatWeight(_shippingWeightKg)} melebihi batas motor (${VehicleCapacityConfig.motor.maxWeight.toInt()} kg)';
    }
    if (_itemLength > VehicleCapacityConfig.motor.maxLength) {
      return 'Panjang ${_itemLength.toStringAsFixed(0)} cm melebihi batas motor (${VehicleCapacityConfig.motor.maxLength.toInt()} cm)';
    }
    if (_itemWidth > VehicleCapacityConfig.motor.maxWidth) {
      return 'Lebar ${_itemWidth.toStringAsFixed(0)} cm melebihi batas motor (${VehicleCapacityConfig.motor.maxWidth.toInt()} cm)';
    }
    if (_itemHeight > VehicleCapacityConfig.motor.maxHeight) {
      return 'Tinggi ${_itemHeight.toStringAsFixed(0)} cm melebihi batas motor (${VehicleCapacityConfig.motor.maxHeight.toInt()} cm)';
    }
    return 'Melebihi batas kapasitas motor';
  }

  /// Poin 10: Query background RajaOngkir sebagai data referensi sistem
  Future<void> _fetchRajaOngkirBackground() async {
    try {
      final result = await RajaOngkirService.calculateCost(
        origin: widget.origin!,
        destination: widget.destination!,
        weight: (_shippingWeightKg * 1000).toInt(),
        courier: 'jne:pos:tiki:sicepat:jnt',
      );
      if (kDebugMode) {
        debugPrint('[CityCourier] RajaOngkir background sync success: ${result['success']}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[CityCourier] RajaOngkir background sync notice: $e');
      }
    }
  }

  String _formatCurrency(int amount) {
    final str = amount.toString();
    return 'Rp${str.replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  String _formatWeight(double val) {
    return val % 1 == 0 ? '${val.toInt()} kg' : '${val.toStringAsFixed(1)} kg';
  }

  int _getPriceForVehicle(String vehicle) {
    return CityCourierTariffService.calculatePrice(
      vehicleType: vehicle,
      distanceKm: _distanceKm,
      shippingWeightKg: _shippingWeightKg,
    );
  }

  String _getEstimationForVehicle(String vehicle) {
    return CityCourierTariffService.calculateEstimationText(
      vehicleType: vehicle,
      distanceKm: _distanceKm,
      isScheduled: _isScheduled,
      scheduledDateTime: _scheduledDateTime,
      referenceNow: _now,
    );
  }

  int get _currentPrice {
    if (_selectedVehicle == null) return 0;
    return _getPriceForVehicle(_selectedVehicle!);
  }

  String get _currentDuration {
    if (_selectedVehicle == null) return 'Estimasi tidak tersedia';
    return _getEstimationForVehicle(_selectedVehicle!);
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // RINGKASAN PENGIRIMAN
                      _buildSummaryCard(isDarkMode, primaryColor),
                      const SizedBox(height: 16),

                      // JADWAL PICKUP (SEKARANG / JADWALKAN)
                      _buildPickupScheduleSection(context, isDarkMode, primaryColor),
                      const SizedBox(height: 20),

                      // SECTION HEADER: PILIH KENDARAAN
                      _buildVehicleSectionHeader(isDarkMode),
                      const SizedBox(height: 12),

                      // PERINGATAN OVER CAPACITY
                      if (_detection.isOverCapacity)
                        _buildOverCapacityWarning(isDarkMode)
                      else ...[
                        // CARD MOTOR
                        _buildVehicleCard(
                          context: context,
                          vehicleId: 'motor',
                          name: 'Motor',
                          subtitle: 'Cocok untuk barang kecil',
                          capacityDesc: 'Maks. 20 kg • 40×40×50 cm',
                          icon: Icons.two_wheeler,
                          isEligible: _isMotorEligible,
                          ineligibleReason: _getMotorIneligibilityReason(),
                          isDarkMode: isDarkMode,
                          primaryColor: primaryColor,
                        ),
                        const SizedBox(height: 12),

                        // CARD MOBIL
                        _buildVehicleCard(
                          context: context,
                          vehicleId: 'mobil',
                          name: 'Mobil',
                          subtitle: 'Cocok untuk barang besar',
                          capacityDesc: 'Maks. 100 kg • 100×100×80 cm',
                          icon: Icons.directions_car,
                          isEligible: _isMobilEligible,
                          ineligibleReason: 'Melebihi kapasitas mobil (maks. 100 kg)',
                          isDarkMode: isDarkMode,
                          primaryColor: primaryColor,
                        ),
                      ],

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
            'PILIH KENDARAAN',
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

  // --- RINGKASAN PENGIRIMAN CARD ---
  Widget _buildSummaryCard(bool isDarkMode, Color primaryColor) {
    final senderText = widget.originName ??
        (widget.senderData != null
            ? '${widget.senderData!['name']} - ${widget.senderData!['city_name'] ?? 'SIDOARJO'}'
            : 'brightness - SIDOARJO');

    final receiverText = widget.destinationName ??
        (widget.receiverData != null
            ? '${widget.receiverData!['name']} - ${widget.receiverData!['city_name'] ?? 'SURABAYA'}'
            : 'andrew - SURABAYA');

    return Container(
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
      child: Column(
        children: [
          // Header Row: RINGKASAN PENGIRIMAN & Weight Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.description_outlined,
                    color: Color(0xFFEA580C),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'RINGKASAN PENGIRIMAN',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.grey.shade400 : const Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.orange.shade900.withOpacity(0.2)
                      : const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDarkMode
                        ? Colors.orange.shade800
                        : const Color(0xFFFFEDD5),
                  ),
                ),
                child: Text(
                  _formatWeight(_shippingWeightKg),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFEA580C),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Timeline Pengirim & Penerima
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  const SizedBox(height: 4),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEA580C),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(height: 3),
                  for (int i = 0; i < 3; i++)
                    Container(
                      width: 2.5,
                      height: 2.5,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.grey.shade600 : const Color(0xFFCBD5E1),
                        shape: BoxShape.circle,
                      ),
                    ),
                  const SizedBox(height: 3),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey.shade500 : const Color(0xFF94A3B8),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PENGIRIM',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.grey.shade400 : const Color(0xFF94A3B8),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      senderText,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'PENERIMA',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.grey.shade400 : const Color(0xFF94A3B8),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      receiverText,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Info Spesifikasi Tambahan (Jarak & Berat Volumetrik)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.route,
                    size: 14,
                    color: isDarkMode ? Colors.grey.shade400 : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Jarak: ±${_distanceKm.toStringAsFixed(1)} km',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDarkMode ? Colors.grey.shade400 : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              if (_volumetricWeightKg > _actualWeightKg)
                Text(
                  'Volumetrik: ${_formatWeight(_volumetricWeightKg)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: isDarkMode ? Colors.orange.shade300 : const Color(0xFFD97706),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // --- JADWAL PICKUP SECTION (Sesuai Poin 6, 7, 8) ---
  Widget _buildPickupScheduleSection(
    BuildContext context,
    bool isDarkMode,
    Color primaryColor,
  ) {
    final bool isOperatingNow = CityCourierTariffService.isOperatingNow(referenceNow: _now);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? Colors.grey.shade700 : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.access_time_filled,
                    color: primaryColor,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'WAKTU PICKUP',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.grey.shade400 : const Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              // Checkbox Jadwalkan Pickup
              InkWell(
                onTap: () {
                  setState(() {
                    if (!_isScheduled) {
                      // Aktifkan jadwalkan
                      _isScheduled = true;
                      _scheduledDateTime ??=
                          ScheduleTimeConfig.getInitialPickupDateTime(referenceNow: _now);
                      _scheduledTimeText = ScheduleTimeConfig.format12Hour(
                        _scheduledDateTime!.hour,
                        _scheduledDateTime!.minute,
                      );
                    } else {
                      // Hanya bisa matikan jika saat ini jam operasional buka
                      if (isOperatingNow) {
                        _isScheduled = false;
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Layanan pickup sekarang sudah berakhir hari ini. Silakan jadwalkan pickup.',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  });
                },
                child: Row(
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: Checkbox(
                        value: _isScheduled,
                        activeColor: primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _isScheduled = true;
                              _scheduledDateTime ??=
                                  ScheduleTimeConfig.getInitialPickupDateTime(referenceNow: _now);
                              _scheduledTimeText = ScheduleTimeConfig.format12Hour(
                                _scheduledDateTime!.hour,
                                _scheduledDateTime!.minute,
                              );
                            } else {
                              if (isOperatingNow) {
                                _isScheduled = false;
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Layanan pickup sekarang sudah berakhir hari ini. Silakan jadwalkan pickup.',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Jadwalkan Pickup',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Detail Waktu Pickup
          if (!_isScheduled) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.green.shade900.withOpacity(0.18)
                    : const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDarkMode
                      ? Colors.green.shade800
                      : const Color(0xFFA7F3D0),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.flash_on, color: Color(0xFF059669), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pickup: Sekarang',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF059669),
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'Kurir langsung menuju lokasi penjemputan paket kamu',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDarkMode ? Colors.grey.shade400 : const Color(0xFF065F46),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            GestureDetector(
              onTap: () async {
                final result = await showModalBottomSheet<dynamic>(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (ctx) => PickupTimeBottomSheet(
                    primaryColor: primaryColor,
                    initialDateTime: _scheduledDateTime,
                    referenceNow: _now,
                  ),
                );

                if (result != null && result is ScheduleTimeResult) {
                  setState(() {
                    _scheduledDateTime = result.dateTime;
                    _scheduledTimeText = result.time12Hour;
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.orange.shade900.withOpacity(0.18)
                      : const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDarkMode
                        ? Colors.orange.shade800
                        : const Color(0xFFFFEDD5),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_month, color: Color(0xFFEA580C), size: 18),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pickup: ${_formatScheduledPickupLabel()}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFEA580C),
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              'Ketuk untuk ubah tanggal & jam pickup',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDarkMode ? Colors.grey.shade400 : const Color(0xFF9A3412),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Icon(Icons.chevron_right, color: Color(0xFFEA580C), size: 20),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatScheduledPickupLabel() {
    if (_scheduledDateTime == null) return 'Pilih Jadwal';
    final now = _now;
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(
      _scheduledDateTime!.year,
      _scheduledDateTime!.month,
      _scheduledDateTime!.day,
    );
    final diffDays = target.difference(today).inDays;
    final timeStr = _scheduledTimeText ??
        ScheduleTimeConfig.format12Hour(
          _scheduledDateTime!.hour,
          _scheduledDateTime!.minute,
        );

    if (diffDays == 0) {
      return 'Hari ini, $timeStr';
    } else {
      return 'Besok, $timeStr';
    }
  }

  // --- SECTION HEADER: PILIH KENDARAAN ---
  Widget _buildVehicleSectionHeader(bool isDarkMode) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'PILIH KENDARAAN',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.grey.shade400 : const Color(0xFF64748B),
            letterSpacing: 0.5,
          ),
        ),
        Text(
          _detection.isOverCapacity ? 'Melebihi Kapasitas' : 'Layanan Instan City Courier',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: _detection.isOverCapacity ? Colors.red : const Color(0xFFEA580C),
          ),
        ),
      ],
    );
  }

  // --- PERINGATAN OVER CAPACITY ---
  Widget _buildOverCapacityWarning(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.red.shade900.withOpacity(0.25)
            : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? Colors.red.shade800 : const Color(0xFFFECACA),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tidak Dapat Dikirim',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Barang melebihi batas ukuran atau berat kendaraan yang tersedia (maksimal 100 kg atau 100×100×80 cm).',
            style: TextStyle(
              fontSize: 12.5,
              color: Color(0xFF991B1B),
              height: 1.4,
            ),
          ),
          if (_detection.exceededReasons.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final reason in _detection.exceededReasons)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  children: [
                    const Text('• ', style: TextStyle(color: Color(0xFFDC2626))),
                    Expanded(
                      child: Text(
                        reason,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFFB91C1C),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  // --- KARTU KENDARAAN (MOTOR / MOBIL) ---
  Widget _buildVehicleCard({
    required BuildContext context,
    required String vehicleId,
    required String name,
    required String subtitle,
    required String capacityDesc,
    required IconData icon,
    required bool isEligible,
    required String ineligibleReason,
    required bool isDarkMode,
    required Color primaryColor,
  }) {
    final bool isSelected = _selectedVehicle == vehicleId && isEligible;
    final int price = _getPriceForVehicle(vehicleId);
    final String duration = _getEstimationForVehicle(vehicleId);

    return GestureDetector(
      onTap: () {
        if (!isEligible) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(ineligibleReason),
              backgroundColor: Colors.orange.shade800,
            ),
          );
          return;
        }
        setState(() {
          _selectedVehicle = vehicleId;
        });
      },
      child: Opacity(
        opacity: isEligible ? 1.0 : 0.5,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? primaryColor
                  : (isDarkMode ? Colors.grey.shade700 : const Color(0xFFE2E8F0)),
              width: isSelected ? 2.0 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? primaryColor.withOpacity(0.08)
                    : Colors.black.withOpacity(isDarkMode ? 0.15 : 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon Box Kendaraan
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isDarkMode
                              ? Colors.orange.shade900.withOpacity(0.25)
                              : const Color(0xFFFFF7ED))
                          : (isDarkMode
                              ? const Color(0xFF0F172A).withOpacity(0.5)
                              : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? (isDarkMode ? Colors.orange.shade800 : const Color(0xFFFFEDD5))
                            : (isDarkMode ? Colors.grey.shade800 : const Color(0xFFE2E8F0)),
                      ),
                    ),
                    child: Icon(
                      icon,
                      color: isSelected ? primaryColor : const Color(0xFF64748B),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Informasi Nama & Deskripsi
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
                              ),
                            ),
                            Text(
                              _formatCurrency(price),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? primaryColor
                                    : (isDarkMode ? Colors.white : const Color(0xFF1E293B)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDarkMode ? Colors.grey.shade400 : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),

              // Baris Estimasi Waktu & Radio Indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_filled,
                        size: 14,
                        color: isSelected ? const Color(0xFF059669) : const Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        duration,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? const Color(0xFF059669)
                              : (isDarkMode ? Colors.grey.shade300 : const Color(0xFF334155)),
                        ),
                      ),
                    ],
                  ),
                  // Radio Selector Button
                  if (isSelected)
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 14,
                      ),
                    )
                  else
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDarkMode
                              ? Colors.grey.shade600
                              : const Color(0xFFCBD5E1),
                          width: 2,
                        ),
                      ),
                    ),
                ],
              ),

              // Keterangan jika kendaraan tidak memenuhi syarat
              if (!isEligible) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 13, color: Colors.red),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          ineligibleReason,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // --- STICKY FOOTER / BOTTOM BAR ---
  Widget _buildBottomBar(
    BuildContext context,
    Color primaryColor,
    bool isDarkMode,
  ) {
    final bool canProceed = !_detection.isOverCapacity && _selectedVehicle != null;

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
            // Row Biaya Pengiriman Terpilih
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Biaya Pengiriman Terpilih:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode ? Colors.grey.shade400 : const Color(0xFF64748B),
                  ),
                ),
                Text(
                  canProceed ? _formatCurrency(_currentPrice) : '-',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: canProceed ? const Color(0xFFEC5B13) : Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Tombol Pilih Kendaraan
            GestureDetector(
              onTap: canProceed
                  ? () {
                      final chosenVehicle = _selectedVehicle!;
                      final price = _currentPrice;
                      final duration = _currentDuration;

                      final result = {
                        'code': chosenVehicle,
                        'name': chosenVehicle == 'mobil' ? 'Mobil' : 'Motor',
                        'service': 'Instant',
                        'description': chosenVehicle == 'mobil'
                            ? 'Cocok untuk barang besar'
                            : 'Cocok untuk barang kecil',
                        'duration': duration,
                        'price': price,
                        'vehicle': chosenVehicle,
                        'is_sameday': true,
                        'icon': chosenVehicle == 'mobil'
                            ? Icons.directions_car
                            : Icons.two_wheeler,
                        'isScheduled': _isScheduled,
                        'scheduledDateTime': _scheduledDateTime,
                        'scheduledTimeText': _scheduledTimeText,
                        'shipping_weight': _shippingWeightKg,
                        'distance_km': _distanceKm,
                      };

                      Navigator.pop(context, result);
                    }
                  : null,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: canProceed ? primaryColor : Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: canProceed
                      ? [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Pilih Kendaraan',
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
