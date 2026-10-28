import 'package:city_courierapp/screens/home/shipping/widgets/city_courier_vehicle_bottom_sheet.dart';
import 'package:city_courierapp/services/shipping/city_courier_tariff_service.dart';
import 'package:flutter/material.dart';
import 'package:city_courierapp/core/utils/auth_guard.dart';
import 'package:city_courierapp/models/shipping/vehicle_capacity_config.dart';
import 'package:city_courierapp/screens/home/shipping/select_sender_screen.dart';
import 'package:city_courierapp/screens/home/shipping/item_info_screen.dart';
import 'package:city_courierapp/models/shipping/schedule_time_config.dart';
import 'package:city_courierapp/screens/home/shipping/confirmation_screen.dart';
import 'package:city_courierapp/screens/home/shipping/widgets/pickup_time_bottom_sheet.dart';

class PickupScreen extends StatefulWidget {
  const PickupScreen({super.key});

  @override
  State<PickupScreen> createState() => _PickupScreenState();
}

class _PickupScreenState extends State<PickupScreen> {
  bool isScheduledPickup = false;
  DateTime? selectedPickupDateTime;
  String? selectedPickupTime;
  String selectedVehicle = 'motor';
  bool isItemInfoSaved = false;
  String itemDeskripsi = '';
  String? itemKategori;
  double itemBerat = 0.0;
  double itemBeratVolumetrik = 0.0;
  double itemBeratPengiriman = 0.0;
  double itemPanjang = 30.0;
  double itemLebar = 20.0;
  double itemTinggi = 15.0;
  double itemVolumeCm3 = 9000.0;
  double itemVolumeLiter = 9.0;
  double itemBeratVolume = 0.0;
  int itemJumlah = 0;
  List<String> itemPhotoPaths = [];

  double get effectiveShippingWeight {
    if (itemBeratPengiriman > 0) return itemBeratPengiriman;
    final vol = VehicleCapacityConfig.calculateVolumetricWeight(
      length: itemPanjang,
      width: itemLebar,
      height: itemTinggi,
    );
    return VehicleCapacityConfig.calculateShippingWeight(
      actualWeight: itemBerat,
      volumetricWeight: vol,
    );
  }

  VehicleDetectionResult get currentDetection => VehicleCapacityConfig.detect(
        weight: itemBerat,
        length: itemPanjang,
        width: itemLebar,
        height: itemTinggi,
      );
  
  double _safeDouble(dynamic val, [double fallback = 0.0]) {
    if (val == null) return fallback;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val.trim()) ?? fallback;
    return fallback;
  }

  void _recalculateSelectedCourier([String? vehicle]) {
    final v = vehicle ?? selectedVehicle;
    final dist = CityCourierTariffService.calculateDistanceKm(
      originLat: senderData?['latitude'],
      originLng: senderData?['longitude'],
      destLat: receiverData?['latitude'],
      destLng: receiverData?['longitude'],
      originName: senderData?['city_name']?.toString(),
      destName: receiverData?['city_name']?.toString(),
    );
    final weight = effectiveShippingWeight > 0 ? effectiveShippingWeight : 1.0;
    final price = CityCourierTariffService.calculatePrice(
      vehicleType: v,
      distanceKm: dist,
      shippingWeightKg: weight,
    );
    final duration = CityCourierTariffService.calculateEstimationText(
      vehicleType: v,
      distanceKm: dist,
      isScheduled: isScheduledPickup,
      scheduledDateTime: selectedPickupDateTime,
    );
    selectedCourier = {
      'code': v,
      'courier_code': v,
      'name': v == 'mobil' ? 'Mobil' : 'Motor',
      'service': 'Instant',
      'price': price,
      'duration': duration,
      'vehicle': v,
      'vehicle_type': v,
      'isScheduled': isScheduledPickup,
      'scheduledDateTime': selectedPickupDateTime,
      'scheduledTimeText': selectedPickupTime,
    };
  }

  Future<void> _openVehicleBottomSheet(
    bool isDarkMode,
    Color primaryColor,
  ) async {
    if (!mounted) return;
    final distanceKm = CityCourierTariffService.calculateDistanceKm(
      originLat: senderData?['latitude'],
      originLng: senderData?['longitude'],
      destLat: receiverData?['latitude'],
      destLng: receiverData?['longitude'],
      originName: senderData?['city_name']?.toString(),
      destName: receiverData?['city_name']?.toString(),
    );

    final result = await CityCourierVehicleBottomSheet.show(
      context: context,
      initialVehicle: selectedCourier?['vehicle'] ?? selectedVehicle,
      shippingWeight: effectiveShippingWeight > 0 ? effectiveShippingWeight : 1.0,
      length: itemPanjang,
      width: itemLebar,
      height: itemTinggi,
      distanceKm: distanceKm,
      isScheduled: isScheduledPickup,
      scheduledDateTime: selectedPickupDateTime,
      scheduledTimeText: selectedPickupTime,
      primaryColor: primaryColor,
      isDarkMode: isDarkMode,
    );

    if (!mounted) return;
    if (result != null) {
      setState(() {
        selectedCourier = result;
        if (result['vehicle'] != null) {
          selectedVehicle = result['vehicle'];
        }
      });
    }
  }
  Map<String, dynamic>? senderData;
  Map<String, dynamic>? receiverData;

  Map<String, dynamic>? selectedCourier = {
    'code': 'motor',
    'name': 'Motor',
    'service': 'Instant',
    'duration': 'Estimasi 30–60 menit',
    'price': 12600,
    'vehicle': 'motor',
    'is_sameday': true,
    'icon': Icons.two_wheeler,
  };
  bool asuransiPengiriman = false;
  bool packingKayu = false;

  final TextEditingController senderController = TextEditingController();
  final TextEditingController receiverController = TextEditingController();

  @override
  void initState() {
    super.initState();
    isScheduledPickup = false;
    selectedPickupDateTime = null;
    selectedPickupTime = null;

    senderController.addListener(_onAddressChanged);
    receiverController.addListener(_onAddressChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AuthGuard.guardScreen(context);
    });
  }

  void _onToggleScheduledPickup(bool value) {
    setState(() {
      isScheduledPickup = value;
      if (value) {
        final initDt = ScheduleTimeConfig.getInitialPickupDateTime();
        selectedPickupDateTime = initDt;
        selectedPickupTime = ScheduleTimeConfig.format12Hour(initDt.hour, initDt.minute);
      } else {
        selectedPickupDateTime = null;
        selectedPickupTime = null;
      }
    });
  }

  void _onAddressChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    senderController.removeListener(_onAddressChanged);
    receiverController.removeListener(_onAddressChanged);
    senderController.dispose();
    receiverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFEC5B13);
    const bgLight = Color(0xFFF9FAFB);
    const bgDark = Color(0xFF0F172A);
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? bgDark : bgLight,
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 16,
                    bottom: 32,
                  ),
                  child: Transform.translate(
                    offset: const Offset(0, -24),
                    child: Column(
                      children: [
                        _buildAddressCard(context, isDarkMode, primaryColor),
                        const SizedBox(height: 12),
                        _buildJadwalPickupCard(
                          context,
                          isDarkMode,
                          primaryColor,
                        ),
                        if (senderController.text.isNotEmpty &&
                            receiverController.text.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _buildItemInfoButton(
                            context,
                            isDarkMode,
                            primaryColor,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              _buildBottomBar(context, isDarkMode, primaryColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 32,
        left: 20,
        right: 20,
        bottom: 48,
      ),
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFEC5B13), Color(0xFFEC5B13)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
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
                'Request Pickup',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Text(
            'Riwayat',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressCard(
    BuildContext context,
    bool isDarkMode,
    Color primaryColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Sender
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: const BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  Container(
                    width: 2,
                    height: 52, // Adjust height based on TextField + padding
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.grey.shade700
                          : Colors.grey.shade300,
                    ),
                    // For a dashed line effect, Flutter's CustomPaint is better,
                    // but a simple solid or dotted container works as a fallback without extra packages.
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
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode
                            ? Colors.grey.shade500
                            : Colors.grey.shade400,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SelectSenderScreen(),
                          ),
                        );
                        if (result != null && result is Map<String, dynamic>) {
                          String name = result['name'] ?? 'Pengirim';
                          String phone = result['phone'] ?? '';
                          String phoneShort = phone.length > 4
                              ? '${phone.substring(0, 4)}...'
                              : phone;

                           setState(() {
                            senderData = result;
                            senderController.text = '$name ($phoneShort)';
                          });
                        }
                      },
                      child: AbsorbPointer(
                        child: TextField(
                          controller: senderController,
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : Colors.black87,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Budi - Jakarta Selatan',
                            hintStyle: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 14,
                            ),
                            filled: true,
                            fillColor: isDarkMode
                                ? const Color(0xFF0F172A).withOpacity(0.5)
                                : Colors.grey.shade50,
                            suffixIcon: Icon(
                              Icons.contact_page,
                              color: primaryColor.withOpacity(0.7),
                              size: 18,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDarkMode
                                    ? Colors.grey.shade700
                                    : Colors.grey.shade100,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDarkMode
                                    ? Colors.grey.shade700
                                    : Colors.grey.shade100,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: primaryColor),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            isDense: true,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ],
          ),
          // Receiver
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PENERIMA',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode
                            ? Colors.grey.shade500
                            : Colors.grey.shade400,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SelectSenderScreen(),
                          ),
                        );
                        if (result != null && result is Map<String, dynamic>) {
                          String name = result['name'] ?? 'Penerima';
                          String phone = result['phone'] ?? '';
                          String phoneShort = phone.length > 4
                              ? '${phone.substring(0, 4)}...'
                              : phone;

                           setState(() {
                            receiverData = result;
                            receiverController.text = '$name ($phoneShort)';
                          });
                        }
                      },
                      child: AbsorbPointer(
                        child: TextField(
                          controller: receiverController,
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : Colors.black87,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Masukan informasi penerima',
                            hintStyle: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 14,
                            ),
                            filled: true,
                            fillColor: isDarkMode
                                ? const Color(0xFF0F172A).withOpacity(0.5)
                                : Colors.grey.shade50,
                            suffixIcon: Icon(
                              Icons.contact_page,
                              color: primaryColor.withOpacity(0.7),
                              size: 18,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDarkMode
                                    ? Colors.grey.shade700
                                    : Colors.grey.shade100,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDarkMode
                                    ? Colors.grey.shade700
                                    : Colors.grey.shade100,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: primaryColor),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            isDense: true,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInlineVehicleSelector(bool isDarkMode, Color primaryColor) {
    final bool isOver = isItemInfoSaved && currentDetection.isOverCapacity;
    final bool canUseMotor = !isItemInfoSaved || currentDetection.isMotor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  selectedVehicle == 'mobil'
                      ? Icons.directions_car
                      : Icons.two_wheeler,
                  size: 14,
                  color: primaryColor,
                ),
                const SizedBox(width: 6),
                Text(
                  'PILIHAN KENDARAAN',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade500,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            Text(
              selectedVehicle == 'mobil' ? 'Mobil (Kapasitas Besar)' : 'Motor (Maks. 20 kg)',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.orange.shade300 : primaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildVehicleOption(
                id: 'motor',
                title: 'Motor',
                subtitle: 'Maks. 20 kg',
                icon: Icons.two_wheeler,
                isSelected: selectedVehicle == 'motor' && !isOver,
                isDarkMode: isDarkMode,
                primaryColor: primaryColor,
                onTap: () {
                  if (isItemInfoSaved) {
                    if (currentDetection.isOverCapacity) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(VehicleCapacityConfig.messageOverCapacity),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    if (!canUseMotor) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(VehicleCapacityConfig.messageMobilAutoSelected),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }
                  }
                  if (selectedVehicle != 'motor') {
                    setState(() {
                      selectedVehicle = 'motor';
                      _recalculateSelectedCourier('motor');
                    });
                  }
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildVehicleOption(
                id: 'mobil',
                title: 'Mobil',
                subtitle: 'Kapasitas Besar',
                icon: Icons.directions_car,
                isSelected: selectedVehicle == 'mobil' && !isOver,
                isDarkMode: isDarkMode,
                primaryColor: primaryColor,
                onTap: () {
                  if (isItemInfoSaved && currentDetection.isOverCapacity) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(VehicleCapacityConfig.messageOverCapacity),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  if (selectedVehicle != 'mobil') {
                    setState(() {
                      selectedVehicle = 'mobil';
                      _recalculateSelectedCourier('mobil');
                    });
                  }
                },
              ),
            ),
          ],
        ),
        if (isItemInfoSaved) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isOver
                  ? (isDarkMode ? Colors.red.shade900.withOpacity(0.2) : Colors.red.shade50)
                  : (currentDetection.isMobil
                      ? (isDarkMode ? Colors.amber.shade900.withOpacity(0.2) : Colors.amber.shade50)
                      : (isDarkMode ? Colors.green.shade900.withOpacity(0.2) : Colors.green.shade50)),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isOver
                    ? (isDarkMode ? Colors.red.shade800 : Colors.red.shade300)
                    : (currentDetection.isMobil
                        ? (isDarkMode ? Colors.amber.shade800 : Colors.amber.shade300)
                        : (isDarkMode ? Colors.green.shade800 : Colors.green.shade300)),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isOver
                      ? Icons.warning_amber_rounded
                      : (currentDetection.isMobil ? Icons.directions_car : Icons.check_circle_outline),
                  size: 14,
                  color: isOver
                      ? Colors.red
                      : (currentDetection.isMobil ? Colors.orange.shade800 : Colors.green.shade700),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    currentDetection.message,
                    style: TextStyle(
                      fontSize: 10,
                      color: isOver
                          ? Colors.red
                          : (currentDetection.isMobil
                              ? (isDarkMode ? Colors.orange.shade200 : Colors.orange.shade900)
                              : (isDarkMode ? Colors.green.shade200 : Colors.green.shade900)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildVehicleOption({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required bool isDarkMode,
    required Color primaryColor,
    required VoidCallback onTap,
  }) {
    final activeBg = isDarkMode
        ? primaryColor.withOpacity(0.18)
        : primaryColor.withOpacity(0.08);
    final inactiveBg = isDarkMode
        ? const Color(0xFF0F172A)
        : const Color(0xFFF8FAFC);

    final activeBorder = primaryColor;
    final inactiveBorder = isDarkMode
        ? Colors.grey.shade700
        : Colors.grey.shade200;

    return InkWell(
      key: Key('vehicle_option_$id'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : inactiveBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? activeBorder : inactiveBorder,
            width: isSelected ? 1.8 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.12),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isSelected
                    ? primaryColor
                    : (isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 18,
                color: isSelected
                    ? Colors.white
                    : (isDarkMode ? Colors.grey.shade300 : Colors.grey.shade600),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? primaryColor
                          : (isDarkMode ? Colors.white : Colors.grey.shade800),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      color: isSelected
                          ? (isDarkMode ? Colors.orange.shade200 : primaryColor.withOpacity(0.85))
                          : (isDarkMode ? Colors.grey.shade400 : Colors.grey.shade500),
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? primaryColor : Colors.transparent,
                border: Border.all(
                  color: isSelected ? primaryColor : Colors.grey.shade400,
                  width: isSelected ? 2 : 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      size: 10,
                      color: Colors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPickupScheduleSheet(
    BuildContext context,
    Color primaryColor,
  ) async {
    final result = await showModalBottomSheet<dynamic>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return PickupTimeBottomSheet(
          primaryColor: primaryColor,
          initialDateTime: selectedPickupDateTime,
        );
      },
    );

    if (result != null && result is ScheduleTimeResult) {
      setState(() {
        selectedPickupDateTime = result.dateTime;
        selectedPickupTime = result.time12Hour;
      });
    }
  }

  Widget _buildJadwalPickupCard(
    BuildContext context,
    bool isDarkMode,
    Color primaryColor,
  ) {
    final availableDays = ScheduleTimeConfig.generateAvailableDays();
    final displayTime = selectedPickupDateTime != null
        ? ScheduleTimeConfig.format12Hour(
            selectedPickupDateTime!.hour,
            selectedPickupDateTime!.minute,
          )
        : (selectedPickupTime ?? 'Pilih Waktu');
    final displayFullDate = selectedPickupDateTime != null
        ? ScheduleTimeConfig.formatDateFull(selectedPickupDateTime!)
        : '-';

    return Container(
      key: const Key('jadwal_pickup_card'),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade100,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card Compact: Checkbox Jadwalkan Pickup + Status Badge
          InkWell(
            key: const Key('checkbox_jadwalkan_pickup'),
            borderRadius: BorderRadius.circular(8),
            onTap: () => _onToggleScheduledPickup(!isScheduledPickup),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    key: const Key('checkbox_jadwal_pickup_input'),
                    value: isScheduledPickup,
                    activeColor: primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    onChanged: (val) {
                      _onToggleScheduledPickup(val ?? false);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Jadwalkan Pickup',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Aktifkan jika ingin menentukan tanggal dan waktu pickup.',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isScheduledPickup
                        ? primaryColor.withOpacity(0.08)
                        : Colors.green.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isScheduledPickup ? 'Khusus' : 'Standar',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: isScheduledPickup ? primaryColor : Colors.green.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Tampilan Pickup Standar saat Checkbox TIDAK dicentang
          if (!isScheduledPickup) ...[
            const SizedBox(height: 8),
            Container(
              key: const Key('pickup_standar_info'),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.flash_on_rounded, size: 14, color: Colors.green.shade600),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Pickup Standar: Kurir akan melakukan pickup segera setelah pesanan dikonfirmasi.',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Pilihan Tanggal & Waktu Pickup saat Checkbox DICENTANG
          if (isScheduledPickup) ...[
            const SizedBox(height: 12),
            Divider(
              height: 1,
              color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
            ),
            const SizedBox(height: 10),

            // Header info badges for scheduled pickup
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tanggal Pickup',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Format 12 Jam',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Maksimal 2 Hari',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Pilihan Tanggal: Side-by-side Row (Compact)
            Row(
              children: availableDays.asMap().entries.map((entry) {
                final index = entry.key;
                final day = entry.value;
                final fullDate = day['fullDate'] as DateTime;
                final isSelected = selectedPickupDateTime != null &&
                    selectedPickupDateTime!.year == fullDate.year &&
                    selectedPickupDateTime!.month == fullDate.month &&
                    selectedPickupDateTime!.day == fullDate.day;
                final title = day['displayTitle'] as String;
                final dateFormatted = ScheduleTimeConfig.formatDate(fullDate);
                final isToday = day['isToday'] == true;

                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: index < availableDays.length - 1 ? 8.0 : 0.0,
                    ),
                    child: InkWell(
                      key: Key(isToday ? 'pickup_date_today' : 'pickup_date_tomorrow'),
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        setState(() {
                          final h = selectedPickupDateTime?.hour ?? 10;
                          final m = selectedPickupDateTime?.minute ?? 0;
                          DateTime newDt = DateTime(fullDate.year, fullDate.month, fullDate.day, h, m);
                          final (h12, min, period) = ScheduleTimeConfig.fromDateTime(newDt);
                          final isPast = ScheduleTimeConfig.isPickupInPast(fullDate, h12, min, period);
                          final within = ScheduleTimeConfig.isWithinOperatingHours(h12, period);
                          if (isPast || !within) {
                            newDt = ScheduleTimeConfig.getInitialPickupDateTime(targetDate: fullDate);
                          }
                          selectedPickupDateTime = newDt;
                          selectedPickupTime = ScheduleTimeConfig.format12Hour(newDt.hour, newDt.minute);
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? primaryColor.withOpacity(0.08)
                              : (isDarkMode ? const Color(0xFF0F172A) : Colors.grey.shade50),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? primaryColor
                                : (isDarkMode ? Colors.grey.shade700 : Colors.grey.shade200),
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                              size: 16,
                              color: isSelected ? primaryColor : Colors.grey.shade400,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? primaryColor
                                          : (isDarkMode ? Colors.white : Colors.grey.shade800),
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    dateFormatted,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),

            // Pilihan Waktu Pickup: Compact Row Selector
            InkWell(
              key: const Key('pickup_time_button'),
              borderRadius: BorderRadius.circular(10),
              onTap: () => _openPickupScheduleSheet(context, primaryColor),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF0F172A) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded, size: 16, color: primaryColor),
                        const SizedBox(width: 8),
                        Text(
                          'Waktu Pickup',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: primaryColor.withOpacity(0.3),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            displayTime,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.arrow_forward_ios_rounded, size: 12, color: primaryColor),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Ringkasan: Pickup dijadwalkan (Single line compact badge)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.white.withOpacity(0.04) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, size: 13, color: primaryColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: RichText(
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 11,
                          color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                        children: [
                          const TextSpan(text: 'Pickup dijadwalkan: '),
                          TextSpan(
                            text: '$displayFullDate • $displayTime',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ],
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

  Widget _buildItemInfoButton(
    BuildContext context,
    bool isDarkMode,
    Color primaryColor,
  ) {
    if (isItemInfoSaved) {
      return GestureDetector(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ItemInfoScreen(
                initialVehicle: selectedVehicle,
                initialBerat: isItemInfoSaved ? itemBerat : null,
                initialPanjang: isItemInfoSaved ? itemPanjang : null,
                initialLebar: isItemInfoSaved ? itemLebar : null,
                initialTinggi: isItemInfoSaved ? itemTinggi : null,
                initialJumlah: isItemInfoSaved ? itemJumlah : null,
                initialDeskripsi: itemDeskripsi.isNotEmpty ? itemDeskripsi : null,
                initialKategori: itemKategori,
                initialPhotoPaths: itemPhotoPaths,
              ),
            ),
          );
          if (result != null &&
              result is Map &&
              result['status'] == 'tersimpan') {
            setState(() {
              isItemInfoSaved = true;
              itemDeskripsi = result['deskripsi'] ?? 'Peralatan Rumah Tangga';
              itemKategori = result['kategori'];
              itemBerat = _safeDouble(result['beratAktual'] ?? result['berat'], 0.0);
              itemPanjang = _safeDouble(result['panjang'], 30.0);
              itemLebar = _safeDouble(result['lebar'], 20.0);
              itemTinggi = _safeDouble(result['tinggi'], 15.0);
              itemVolumeCm3 = _safeDouble(result['volumeCm3'], itemPanjang * itemLebar * itemTinggi);
              itemVolumeLiter = _safeDouble(result['volumeLiter'], itemVolumeCm3 / 1000.0);
              itemBeratVolumetrik = _safeDouble(
                result['beratVolumetrik'] ?? result['beratVolume'],
                VehicleCapacityConfig.calculateVolumetricWeight(
                  length: itemPanjang,
                  width: itemLebar,
                  height: itemTinggi,
                ),
              );
              itemBeratVolume = itemBeratVolumetrik;
              itemBeratPengiriman = _safeDouble(
                result['beratPengiriman'] ?? result['shippingWeight'],
                VehicleCapacityConfig.calculateShippingWeight(
                  actualWeight: itemBerat,
                  volumetricWeight: itemBeratVolumetrik,
                ),
              );
              itemJumlah = result['jumlahBarang'] ?? 1;
              if (result['vehicleType'] != null) {
                selectedVehicle = result['vehicleType'];
              }
              if (result['photoPaths'] != null) {
                itemPhotoPaths = List<String>.from(result['photoPaths']);
              }
              _recalculateSelectedCourier();
            });
            if (!mounted) return;
            await _openVehicleBottomSheet(isDarkMode, primaryColor);
          }
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDarkMode
                  ? Colors.grey.shade700.withOpacity(0.5)
                  : Colors.grey.shade100,
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.05),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? Colors.orange.shade900.withOpacity(0.2)
                              : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.inventory_2,
                          color: primaryColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'INFORMASI BARANG',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode
                                  ? Colors.grey.shade500
                                  : Colors.grey.shade400,
                              letterSpacing: 1,
                            ),
                          ),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            children: [
                              Text(
                                itemDeskripsi.isEmpty
                                    ? 'Peralatan Rumah Tangga'
                                    : itemDeskripsi,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode
                                      ? Colors.white
                                      : Colors.grey.shade800,
                                ),
                              ),
                              if (itemPhotoPaths.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.camera_alt, size: 10, color: primaryColor),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${itemPhotoPaths.length} Foto',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: primaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  Icon(Icons.check_circle, color: primaryColor, size: 20),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: isDarkMode
                          ? Colors.grey.shade700.withOpacity(0.5)
                          : Colors.grey.shade50,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.fitness_center,
                                size: 13,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'AKTUAL',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${itemBerat % 1 == 0 ? itemBerat.toInt() : itemBerat.toStringAsFixed(1)} kg',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode
                                  ? Colors.grey.shade200
                                  : Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      height: 24,
                      width: 1,
                      color: isDarkMode
                          ? Colors.grey.shade700.withOpacity(0.5)
                          : Colors.grey.shade100,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.square_foot,
                                size: 13,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'VOLUMETRIK',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${itemBeratVolumetrik % 1 == 0 ? itemBeratVolumetrik.toInt() : itemBeratVolumetrik.toStringAsFixed(1)} kg',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode
                                  ? Colors.grey.shade200
                                  : Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      height: 24,
                      width: 1,
                      color: isDarkMode
                          ? Colors.grey.shade700.withOpacity(0.5)
                          : Colors.grey.shade100,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.scale,
                                size: 13,
                                color: primaryColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'PENGIRIMAN',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${effectiveShippingWeight % 1 == 0 ? effectiveShippingWeight.toInt() : effectiveShippingWeight.toStringAsFixed(1)} kg',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _buildInlineVehicleSelector(isDarkMode, primaryColor),
            ],
          ),
        ),
      );
    }

    // Default Unsaved State
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode
              ? Colors.grey.shade700.withOpacity(0.5)
              : Colors.grey.shade100,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ItemInfoScreen(
                    initialVehicle: selectedVehicle,
                    initialBerat: isItemInfoSaved ? itemBerat : null,
                    initialPanjang: isItemInfoSaved ? itemPanjang : null,
                    initialLebar: isItemInfoSaved ? itemLebar : null,
                    initialTinggi: isItemInfoSaved ? itemTinggi : null,
                    initialJumlah: isItemInfoSaved ? itemJumlah : null,
                    initialDeskripsi: itemDeskripsi.isNotEmpty ? itemDeskripsi : null,
                    initialKategori: itemKategori,
                    initialPhotoPaths: itemPhotoPaths,
                  ),
                ),
              );
              if (result != null &&
                  result is Map &&
                  result['status'] == 'tersimpan') {
                setState(() {
                  isItemInfoSaved = true;
                  itemDeskripsi = result['deskripsi'] ?? 'Peralatan Rumah Tangga';
                  itemKategori = result['kategori'];
                  itemBerat = _safeDouble(result['beratAktual'] ?? result['berat'], 0.0);
                  itemPanjang = _safeDouble(result['panjang'], 30.0);
                  itemLebar = _safeDouble(result['lebar'], 20.0);
                  itemTinggi = _safeDouble(result['tinggi'], 15.0);
                  itemVolumeCm3 = _safeDouble(result['volumeCm3'], itemPanjang * itemLebar * itemTinggi);
                  itemVolumeLiter = _safeDouble(result['volumeLiter'], itemVolumeCm3 / 1000.0);
                  itemBeratVolumetrik = _safeDouble(
                    result['beratVolumetrik'] ?? result['beratVolume'],
                    VehicleCapacityConfig.calculateVolumetricWeight(
                      length: itemPanjang,
                      width: itemLebar,
                      height: itemTinggi,
                    ),
                  );
                  itemBeratVolume = itemBeratVolumetrik;
                  itemBeratPengiriman = _safeDouble(
                    result['beratPengiriman'] ?? result['shippingWeight'],
                    VehicleCapacityConfig.calculateShippingWeight(
                      actualWeight: itemBerat,
                      volumetricWeight: itemBeratVolumetrik,
                    ),
                  );
                  itemJumlah = result['jumlahBarang'] ?? 1;
                  if (result['vehicleType'] != null) {
                    selectedVehicle = result['vehicleType'];
                  }
                  if (result['photoPaths'] != null) {
                    itemPhotoPaths = List<String>.from(result['photoPaths']);
                  }
                  _recalculateSelectedCourier();
                });
                if (!mounted) return;
                await _openVehicleBottomSheet(isDarkMode, primaryColor);
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.orange.shade900.withOpacity(0.2)
                            : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.inventory_2, color: primaryColor, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Informasi Barang',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Isi detail paket Anda',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isDarkMode
                                ? Colors.grey.shade500
                                : Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Icon(
                  Icons.chevron_right,
                  color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade300,
                  size: 24,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Divider(
            height: 1,
            color: isDarkMode
                ? Colors.grey.shade700.withOpacity(0.5)
                : Colors.grey.shade100,
          ),
          const SizedBox(height: 12),
          _buildInlineVehicleSelector(isDarkMode, primaryColor),
        ],
      ),
    );
  }

  String _formatCurrency(int amount) {
    final str = amount.toString();
    return 'Rp${str.replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  Widget _buildBottomBar(
    BuildContext context,
    bool isDarkMode,
    Color primaryColor,
  ) {
    int totalHarga = 0;
    if (selectedCourier != null) {
      totalHarga += (selectedCourier!['price'] as int);
    }
    if (asuransiPengiriman) totalHarga += 2500;
    if (packingKayu) totalHarga += 50000;

    final curVehicle = selectedCourier?['vehicle'] ?? selectedVehicle;
    final isMobil = curVehicle.toString().toLowerCase() == 'mobil';
    final vehicleTitle = isMobil ? 'City Courier Mobil' : 'City Courier Motor';
    final durationText = selectedCourier?['duration']?.toString() ??
        (isMobil ? 'Estimasi 30–90 menit' : 'Estimasi 30–60 menit');

    if (isItemInfoSaved) {
      return Container(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 10,
          bottom: MediaQuery.of(context).padding.bottom + 12,
        ),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
          border: Border(
            top: BorderSide(
              color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle drag indicator (Ketuk untuk buka modal pemilihan kendaraan Gambar 2)
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Baris Preview Kendaraan Terpilih (Persis Gambar 1 GoSend)
            InkWell(
              onTap: () => _openVehicleBottomSheet(isDarkMode, primaryColor),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                child: Row(
                  children: [
                    // Icon Kendaraan
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isMobil ? Icons.directions_car : Icons.two_wheeler,
                        color: primaryColor,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Judul Layanan & Badge Estimasi Waktu
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vehicleTitle,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.white : Colors.grey.shade900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDarkMode
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDarkMode
                                    ? Colors.grey.shade700
                                    : Colors.grey.shade300,
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              durationText,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDarkMode
                                    ? Colors.grey.shade300
                                    : Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Harga & Link Ganti
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatCurrency(totalHarga),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: isDarkMode ? Colors.white : Colors.grey.shade900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              'Ganti',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: primaryColor,
                              ),
                            ),
                            Icon(
                              Icons.keyboard_arrow_down,
                              size: 14,
                              color: primaryColor,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Tombol Selanjutnya / Lanjut (Gambar 1 GoSend)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                key: const Key('btn_lanjut_pickup'),
                onPressed: () {
                  if (isItemInfoSaved && currentDetection.isOverCapacity) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(VehicleCapacityConfig.messageOverCapacity),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  if (isScheduledPickup && (selectedPickupDateTime == null || selectedPickupTime == null)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Silakan pilih tanggal dan waktu pickup terlebih dahulu.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ConfirmationScreen(
                        selectedCourier: selectedCourier,
                        itemDeskripsi: itemDeskripsi.isEmpty ? 'Peralatan Rumah Tangga' : itemDeskripsi,
                        itemBerat: itemBerat,
                        itemBeratVolume: itemBeratVolume,
                        itemBeratVolumetrik: itemBeratVolumetrik,
                        itemBeratPengiriman: effectiveShippingWeight,
                        itemPanjang: itemPanjang,
                        itemLebar: itemLebar,
                        itemTinggi: itemTinggi,
                        itemVolumeCm3: itemVolumeCm3,
                        itemJumlah: itemJumlah,
                        asuransiPengiriman: asuransiPengiriman,
                        packingKayu: packingKayu,
                        senderData: senderData,
                        receiverData: receiverData,
                        selectedVehicle: selectedVehicle,
                        isScheduledPickup: isScheduledPickup,
                        pickupScheduledAt: isScheduledPickup ? selectedPickupDateTime : null,
                        pickupTimeText: isScheduledPickup
                            ? (selectedPickupDateTime != null
                                ? ScheduleTimeConfig.formatFull(selectedPickupDateTime!)
                                : selectedPickupTime)
                            : null,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Selanjutnya',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF0F172A) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.payments, color: primaryColor, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'ESTIMASI',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode
                            ? Colors.grey.shade400
                            : Colors.grey.shade500,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Rp0',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: isDarkMode ? Colors.white : Colors.grey.shade900,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? const Color(0xFFEC5B13)
                    : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                'Selanjutnya',
                style: TextStyle(
                  color: isDarkMode
                      ? Colors.grey.shade500
                      : const Color(0xFF64748B),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
