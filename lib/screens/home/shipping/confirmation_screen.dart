import 'package:flutter/material.dart';
import 'package:city_courierapp/screens/home/shipping/payment_method_screen.dart';
import 'package:city_courierapp/services/api_service.dart';
import 'package:city_courierapp/services/shipping/shipment_service.dart';
import 'package:city_courierapp/models/shipping/shipment_model.dart';
import 'package:city_courierapp/screens/history/shipping_history_screen.dart';
import 'package:city_courierapp/models/shipping/schedule_time_config.dart';

class DashedLinePainter extends CustomPainter {
  final Color color;

  DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    double dashWidth = 4, dashSpace = 4, startY = 0;
    while (startY < size.height) {
      canvas.drawLine(Offset(0, startY), Offset(0, startY + dashWidth), paint);
      startY += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class ConfirmationScreen extends StatefulWidget {
  final Map<String, dynamic>? selectedCourier;
  final String itemDeskripsi;
  final double itemBerat;
  final double itemBeratVolume;
  final int itemJumlah;
  final bool asuransiPengiriman;
  final bool packingKayu;
  final Map<String, dynamic>? senderData;
  final Map<String, dynamic>? receiverData;
  final String selectedVehicle;
  final double? itemPanjang;
  final double? itemLebar;
  final double? itemTinggi;
  final double? itemVolumeCm3;
  final double? itemBeratVolumetrik;
  final double? itemBeratPengiriman;
  final bool isScheduledPickup;
  final DateTime? pickupScheduledAt;
  final DateTime? estimatedDelivery;
  final String? pickupTimeText;
  final String? deliveryTimeText;
  final bool isDeliveryCrossDay;

  const ConfirmationScreen({
    super.key,
    required this.selectedCourier,
    required this.itemDeskripsi,
    required this.itemBerat,
    required this.itemBeratVolume,
    required this.itemJumlah,
    required this.asuransiPengiriman,
    required this.packingKayu,
    this.senderData,
    this.receiverData,
    this.selectedVehicle = 'motor',
    this.itemPanjang,
    this.itemLebar,
    this.itemTinggi,
    this.itemVolumeCm3,
    this.itemBeratVolumetrik,
    this.itemBeratPengiriman,
    this.isScheduledPickup = false,
    this.pickupScheduledAt,
    this.estimatedDelivery,
    this.pickupTimeText,
    this.deliveryTimeText,
    this.isDeliveryCrossDay = false,
  });

  @override
  State<ConfirmationScreen> createState() => _ConfirmationScreenState();
}

class _ConfirmationScreenState extends State<ConfirmationScreen> {
  bool get isDarkMode => Theme.of(context).brightness == Brightness.dark;
  bool _isSubmitting = false;

  String _formatCurrency(int amount) {
    final str = amount.toString();
    return 'Rp${str.replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  Future<void> _submitShipment(BuildContext context, int totalPrice) async {
    if (_isSubmitting) return;
    
    // Simple validation
    final senderPhone = widget.senderData?['phone'] ?? '';
    final receiverPhone = widget.receiverData?['phone'] ?? '';
    
    if (senderPhone.isEmpty || receiverPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nomor telepon pengirim dan penerima harus diisi'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (widget.selectedCourier == null || (widget.selectedCourier?['service'] == null && widget.selectedCourier?['courier_service'] == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan pilih kurir dan layanan terlebih dahulu'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final courier = widget.selectedCourier;
      final sender = widget.senderData;
      final receiver = widget.receiverData;

      final double actualWeight = widget.itemBerat;
      final double volumetricWeight = widget.itemBeratVolumetrik ?? widget.itemBeratVolume;
      final double shippingWeight = widget.itemBeratPengiriman ??
          (actualWeight > volumetricWeight ? actualWeight : volumetricWeight);

      // Ambil etd bersih (misal "1-2" dari API) agar tidak mengirim string panjang "Estimasi 1–2 hari"
      final rawEtd = (courier?['etd'] ?? '').toString().trim();
      final cleanEtd = rawEtd.isNotEmpty ? rawEtd : (courier?['duration'] ?? '');

      final originId = sender?['subdistrict_id'] ?? sender?['city_id'];
      final destId = receiver?['subdistrict_id'] ?? receiver?['city_id'];

      final body = {
        'customer_name': sender?['name'] ?? 'Pengirim',
        'customer_phone': sender?['phone'] ?? '',
        'sender_name': sender?['name'] ?? 'Pengirim',
        'sender_phone': sender?['phone'] ?? '',
        'sender_address': (sender?['address'] ?? '').toString().trim(),
        if (sender?['latitude'] != null) 'sender_latitude': sender!['latitude'],
        if (sender?['longitude'] != null) 'sender_longitude': sender!['longitude'],
        'origin_name': sender?['kecamatan_name'] ?? sender?['subdistrict_name'] ?? sender?['city_name'] ?? '',
        if (originId != null && originId.toString().trim().isNotEmpty)
          'origin_id': originId.toString(),
        'receiver_name': receiver?['name'] ?? 'Penerima',
        'receiver_phone': receiver?['phone'] ?? '',
        'receiver_address': (receiver?['address'] ?? '').toString().trim(),
        if (receiver?['latitude'] != null) 'receiver_latitude': receiver!['latitude'],
        if (receiver?['longitude'] != null) 'receiver_longitude': receiver!['longitude'],
        'destination_name': receiver?['kecamatan_name'] ?? receiver?['subdistrict_name'] ?? receiver?['city_name'] ?? '',
        if (destId != null && destId.toString().trim().isNotEmpty)
          'destination_id': destId.toString(),
        'package_description': widget.itemDeskripsi,
        'package_weight': shippingWeight,
        'actual_weight': actualWeight,
        'volumetric_weight': volumetricWeight,
        'shipping_weight': shippingWeight,
        'chargeable_weight': shippingWeight,
        'courier_code': (() {
          for (final candidate in [
            courier?['code'],
            courier?['courier_code'],
            courier?['vehicle'],
            widget.selectedVehicle,
          ]) {
            final s = candidate?.toString().trim() ?? '';
            if (s.isNotEmpty) return s;
          }
          return 'motor';
        })(),
        'courier_name': (() {
          for (final candidate in [
            courier?['name'],
            courier?['courier_name'],
          ]) {
            final s = candidate?.toString().trim() ?? '';
            if (s.isNotEmpty) return s;
          }
          return widget.selectedVehicle == 'mobil' ? 'Mobil' : 'Motor';
        })(),
        'courier_service': (() {
          for (final candidate in [
            courier?['service'],
            courier?['courier_service'],
          ]) {
            final s = candidate?.toString().trim() ?? '';
            if (s.isNotEmpty) return s;
          }
          return 'Instant';
        })(),
        'vehicle_type': widget.selectedVehicle.isNotEmpty ? widget.selectedVehicle : 'motor',
        'vehicle': widget.selectedVehicle.isNotEmpty ? widget.selectedVehicle : 'motor',
        if (widget.itemPanjang != null) 'length': widget.itemPanjang,
        if (widget.itemLebar != null) 'width': widget.itemLebar,
        if (widget.itemTinggi != null) 'height': widget.itemTinggi,
        if (widget.itemVolumeCm3 != null) 'volume': widget.itemVolumeCm3,
        'etd': cleanEtd,
        'duration': courier?['duration'] ?? cleanEtd,
        'shipping_cost': courier?['price'] ?? 0,
        'insurance': widget.asuransiPengiriman,
        'wood_packing': widget.packingKayu,
        'total_cost': totalPrice,
        'scheduled_pickup': widget.isScheduledPickup,
        if (widget.isScheduledPickup && widget.pickupScheduledAt != null) ...{
          'pickup_scheduled_at': widget.pickupScheduledAt!.toIso8601String(),
          'pickup_date': widget.pickupScheduledAt!.toIso8601String().substring(0, 10),
          if (widget.pickupTimeText != null) 'pickup_time': widget.pickupTimeText,
        },
        'estimated_delivery': (widget.estimatedDelivery ??
                ScheduleTimeConfig.calculateEstimatedDeliveryDate(
                  widget.pickupScheduledAt ?? DateTime.now(),
                  courier?['duration'],
                ))
            .toIso8601String(),
      };

      debugPrint('DEBUG: Shipment Payload: $body');

      // Gunakan timeout 60 detik untuk operasi pembuatan shipment di backend
      final response = await ApiService.post(
        '/shipments',
        body,
        timeout: const Duration(seconds: 60),
      );

      if (!mounted) return;

      if (response != null && response['success'] == true) {
        // Navigate to payment after successful save
        final shipmentId = (response['data']?['id'] ?? '').toString();
        if (shipmentId.isEmpty) {
          throw Exception('Gagal mendapatkan ID pengiriman dari server');
        }
        
        // Ambil tracking number (resi) dari backend
        final trackingNumber = response['data']?['tracking_number'] ?? 
                              response['data']?['order_number'] ?? 
                              response['data']?['shipment_number'] ?? 
                              shipmentId;
                               
        final barcodeData = response['data']?['barcode'] ?? 
                           response['data']?['qr_code'] ?? 
                           response['data']?['qr_string'];
                           
        final barcodeUrl = response['data']?['barcode_url'] ?? 
                          response['data']?['qr_url'];
                              
        if (!context.mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentMethodScreen(
              totalAmount: totalPrice,
              shipmentId: shipmentId,
              trackingNumber: trackingNumber.toString(),
              barcodeData: barcodeData?.toString(),
              barcodeUrl: barcodeUrl?.toString(),
              senderName: widget.senderData?['name'],
              senderCity: widget.senderData?['kecamatan_name'] ?? widget.senderData?['city_name'],
              receiverName: widget.receiverData?['name'],
              receiverCity: widget.receiverData?['kecamatan_name'] ?? widget.receiverData?['city_name'],
              vehicle: widget.selectedVehicle,
              trackingUrl: response['data']?['tracking_url']?.toString(),
              shipmentData: response['data'] is Map<String, dynamic> ? (response['data'] as Map<String, dynamic>) : null,
            ),
          ),
        );
      } else {
        // Cek jika kegagalan karena timeout jaringan
        if (response?['is_timeout'] == true) {
          // Recovery check: Periksa apakah pesanan sebenarnya sempat terbuat di server
          try {
            final recentResult = await ShipmentService.getUserShipments(
              status: 'pending',
              page: 1,
              perPage: 5,
            ).timeout(const Duration(seconds: 10));

            if (recentResult['success'] == true &&
                recentResult['data'] is List &&
                (recentResult['data'] as List).isNotEmpty) {
              final List<ShipmentModel> list =
                  recentResult['data'] as List<ShipmentModel>;
              final now = DateTime.now();
              ShipmentModel? matched;
              for (final s in list) {
                final diff = now.difference(s.createdAt).inMinutes.abs();
                if (diff <= 5) {
                  matched = s;
                  break;
                }
              }

              if (matched != null) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Pesanan berhasil tercatat di server. Membuka pembayaran...'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 3),
                  ),
                );

                final shipmentId = matched.id.toString();
                final trackingNumber = matched.trackingNumber ?? matched.orderNumber;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PaymentMethodScreen(
                      totalAmount: totalPrice,
                      shipmentId: shipmentId,
                      trackingNumber: trackingNumber,
                      barcodeData: trackingNumber,
                      senderCity: widget.senderData?['city_name'],
                      receiverCity: widget.receiverData?['city_name'],
                    ),
                  ),
                );
                return;
              }
            }
          } catch (_) {}

          // Jika recovery tidak menemukan pesanan baru, tampilkan dialog aksi
          if (!context.mounted) return;
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.schedule, color: Colors.orange, size: 24),
                  SizedBox(width: 8),
                  Text('Koneksi Timeout', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: const Text(
                'Server memerlukan waktu lebih lama dari biasanya untuk memproses pesanan pengiriman.\n\nSilakan cek Riwayat Pesanan untuk melihat apakah pesanan Anda sudah tercatat, atau coba kembali.',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ShippingHistoryScreen()),
                    );
                  },
                  child: const Text('Cek Riwayat Pesanan'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEC5B13),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _submitShipment(context, totalPrice);
                  },
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          );
          return;
        }

        // Show error from server
        String errorMessage = response?['message'] ?? 'Gagal membuat pesanan pengiriman';
        
        // Handle Laravel validation errors
        if (response?['errors'] != null) {
          final Map<String, dynamic> errors = response!['errors'];
          if (errors.isNotEmpty) {
            final firstErrorList = errors.values.first;
            if (firstErrorList is List && firstErrorList.isNotEmpty) {
              errorMessage = firstErrorList.first.toString();
            } else if (firstErrorList is String) {
              errorMessage = firstErrorList;
            }
          }
        }

        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Terjadi kesalahan: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFEC5B13);
    final bgLight = const Color(0xFFF9FAFB);
    final bgDark = const Color(0xFF0F172A);

    int courierPrice = widget.selectedCourier?['price'] ?? 0;
    int asuransiPrice = widget.asuransiPengiriman ? 2500 : 0;
    int packingPrice = widget.packingKayu ? 50000 : 0;
    int totalPrice = courierPrice + asuransiPrice + packingPrice;

    return Scaffold(
      backgroundColor: isDarkMode ? bgDark : bgLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: isDarkMode ? Colors.white : Colors.black87,
            size: 20,
          ),
        ),
        title: const Text(
          'Konfirmasi Pesanan',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: 120,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInformasiPengiriman(isDarkMode, primaryColor),
                const SizedBox(height: 16),
                _buildJadwalPengirimanCard(isDarkMode, primaryColor),
                const SizedBox(height: 16),
                _buildKendaraanCard(isDarkMode, primaryColor),
                const SizedBox(height: 16),
                _buildDetailBarang(isDarkMode, primaryColor),
                const SizedBox(height: 16),
                _buildLayananKurir(isDarkMode, primaryColor),
                const SizedBox(height: 16),
                _buildRincianBiaya(
                  isDarkMode,
                  primaryColor,
                  courierPrice,
                  asuransiPrice,
                  packingPrice,
                  totalPrice,
                ),
                const SizedBox(height: 16),
                _buildInfoBox(isDarkMode, primaryColor),
              ],
            ),
          ),
          _buildBottomBar(context, primaryColor, isDarkMode, totalPrice),
        ],
      ),
    );
  }


  Widget _buildJadwalPengirimanCard(bool isDarkMode, Color primaryColor) {
    final bool isScheduled = widget.isScheduledPickup;
    final DateTime baseDate = (isScheduled && widget.pickupScheduledAt != null)
        ? widget.pickupScheduledAt!
        : DateTime.now();

    final estDeliveryDate = widget.pickupScheduledAt != null
        ? ScheduleTimeConfig.calculateEstimatedDeliveryDate(
            widget.pickupScheduledAt!,
            widget.selectedCourier?['duration'],
          )
        : ScheduleTimeConfig.calculateEstimatedDeliveryDate(
            baseDate,
            widget.selectedCourier?['duration'],
          );

    final rawDuration = widget.selectedCourier?['duration'] ?? '30–60 menit';
    final cleanDuration = rawDuration.startsWith('Estimasi ')
        ? rawDuration.substring(9)
        : rawDuration;
    final String estDeliveryText = widget.deliveryTimeText ??
        '${ScheduleTimeConfig.formatDate(estDeliveryDate)} (Estimasi $cleanDuration)';

    final String pickupDisplay = isScheduled
        ? (widget.pickupTimeText ??
            (widget.pickupScheduledAt != null
                ? ScheduleTimeConfig.formatFull(widget.pickupScheduledAt!)
                : 'Pickup Standar'))
        : 'Pickup Standar (Segera Diproses)';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'JADWAL PENGIRIMAN',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade400,
                  letterSpacing: 1,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isScheduled
                      ? primaryColor.withValues(alpha: 0.1)
                      : Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isScheduled ? 'Format 12 Jam' : 'Pickup Standar',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: isScheduled ? primaryColor : Colors.green.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(14),
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
              // Waktu Pickup
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.orange.shade900.withValues(alpha: 0.25)
                          : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.access_time_rounded, color: primaryColor, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'WAKTU PICKUP',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade500,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          pickupDisplay,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Divider(
                  height: 1,
                  color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade100,
                ),
              ),
              // Estimasi Pengantaran (Otomatis dari Sistem Kurir)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.blue.shade900.withValues(alpha: 0.25)
                          : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.local_shipping_outlined, color: Colors.blue.shade700, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'ESTIMASI PENGANTARAN',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade500,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.blue.withValues(alpha: 0.3), width: 0.5),
                              ),
                              child: Text(
                                widget.isDeliveryCrossDay ? 'Hari Berikutnya' : 'Otomatis Sistem',
                                style: const TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          estDeliveryText,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Waktu pengantaran ditentukan sistem kurir setelah pickup.',
                          style: TextStyle(
                            fontSize: 9.5,
                            color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKendaraanCard(bool isDarkMode, Color primaryColor) {
    final isMobil = widget.selectedVehicle.toLowerCase() == 'mobil';
    final vehicleName = isMobil ? 'Mobil' : 'Motor';
    final vehicleDesc = isMobil
        ? 'Kapasitas besar / banyak barang'
        : 'Standar reguler (Maks. 20 kg)';
    final vehicleIcon = isMobil ? Icons.directions_car : Icons.two_wheeler;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'JENIS KENDARAAN',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade400,
              letterSpacing: 1,
            ),
          ),
        ),
        Container(
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
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.orange.shade900.withValues(alpha: 0.2)
                          : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(vehicleIcon, color: primaryColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vehicleName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode
                              ? Colors.white
                              : Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        vehicleDesc,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDarkMode
                              ? Colors.grey.shade400
                              : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? primaryColor.withValues(alpha: 0.15)
                      : primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, size: 12, color: primaryColor),
                    const SizedBox(width: 4),
                    Text(
                      'Dipilih',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: primaryColor,
                      ),
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

  Widget _buildInformasiPengiriman(bool isDarkMode, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'INFORMASI PENGIRIMAN',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade400,
              letterSpacing: 1,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
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
          child: Stack(
            children: [
              // Dashed line background connecting sender and receiver markers
              Positioned(
                left: 9.5,
                top: 24,
                bottom: 24,
                width: 1,
                child: CustomPaint(
                  painter: DashedLinePainter(
                    color: isDarkMode
                        ? Colors.grey.shade600
                        : Colors.grey.shade200,
                  ),
                ),
              ),
              Column(
                children: [
                  // SENDER
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? Colors.orange.shade900.withValues(alpha: 0.3)
                              : Colors.orange.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: primaryColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PENGIRIM',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade400,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.senderData?['name'] ?? 'Pengirim',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode
                                    ? Colors.white
                                    : Colors.grey.shade800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              ((widget.senderData?['address'] ?? '') + (widget.senderData?['kecamatan_name'] != null ? ', ${widget.senderData!['kecamatan_name']}' : '')).trim().isEmpty ? 'Alamat Pengirim' : ((widget.senderData?['address'] ?? '') + (widget.senderData?['kecamatan_name'] != null ? ', ${widget.senderData!['kecamatan_name']}' : '')),
                              style: TextStyle(
                                fontSize: 12,
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
                  const SizedBox(height: 24),
                  // RECEIVER
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? Colors.blue.shade900.withValues(alpha: 0.3)
                              : Colors.blue.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            Icons.location_on,
                            color: Colors.blue.shade600,
                            size: 12,
                          ),
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
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade400,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.receiverData?['name'] ?? 'Penerima',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode
                                    ? Colors.white
                                    : Colors.grey.shade800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              ((widget.receiverData?['address'] ?? '') + (widget.receiverData?['kecamatan_name'] != null ? ', ${widget.receiverData!['kecamatan_name']}' : '')).trim().isEmpty ? 'Alamat Penerima' : ((widget.receiverData?['address'] ?? '') + (widget.receiverData?['kecamatan_name'] != null ? ', ${widget.receiverData!['kecamatan_name']}' : '')),
                              style: TextStyle(
                                fontSize: 12,
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
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailBarang(bool isDarkMode, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'DETAIL BARANG',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade400,
              letterSpacing: 1,
            ),
          ),
        ),
        Container(
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
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? const Color(0xFF0F172A)
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Icon(
                    Icons.inventory_2_outlined,
                    color: Colors.grey.shade400,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Builder(
                  builder: (context) {
                    final double actualWeight = widget.itemBerat;
                    final double volumetricWeight = widget.itemBeratVolumetrik ?? widget.itemBeratVolume;
                    final double shippingWeight = widget.itemBeratPengiriman ??
                        (actualWeight > volumetricWeight ? actualWeight : volumetricWeight);
                    final String formatActual = actualWeight % 1 == 0 ? '${actualWeight.toInt()}' : actualWeight.toStringAsFixed(1);
                    final String formatVol = volumetricWeight % 1 == 0 ? '${volumetricWeight.toInt()}' : volumetricWeight.toStringAsFixed(1);
                    final String formatShip = shippingWeight % 1 == 0 ? '${shippingWeight.toInt()}' : shippingWeight.toStringAsFixed(1);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.itemDeskripsi,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 10,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.scale,
                                  size: 11,
                                  color: primaryColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Berat: $formatShip kg',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '(Aktual $formatActual kg • Vol $formatVol kg)',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (widget.itemPanjang != null && widget.itemLebar != null && widget.itemTinggi != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.straighten,
                                size: 10,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${widget.itemPanjang!.toInt()}×${widget.itemLebar!.toInt()}×${widget.itemTinggi!.toInt()} cm',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLayananKurir(bool isDarkMode, Color primaryColor) {
    String courierName = widget.selectedCourier?['name'] ?? 'Regular';
    String courierDur = widget.selectedCourier?['duration'] ?? '1-2 Hari';
    IconData courierIcon =
        widget.selectedCourier?['icon'] ?? Icons.local_shipping;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'LAYANAN & KURIR',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade400,
              letterSpacing: 1,
            ),
          ),
        ),
        Container(
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
                    child: Icon(courierIcon, color: primaryColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        courierName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode
                              ? Colors.white
                              : Colors.grey.shade800,
                        ),
                      ),
                      Text(
                        courierDur.startsWith('Estimasi') || courierDur.startsWith('Tiba')
                            ? courierDur
                            : 'Estimasi $courierDur sampai',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDarkMode
                              ? Colors.grey.shade400
                              : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Text(
                widget.selectedCourier != null
                    ? _formatCurrency(widget.selectedCourier!['price'] ?? 0)
                    : 'Rp0',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRincianBiaya(
    bool isDarkMode,
    Color primaryColor,
    int courierPrice,
    int asuransiPrice,
    int packingPrice,
    int totalPrice,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'RINCIAN BIAYA',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade400,
              letterSpacing: 1,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Ongkos Kirim (${widget.itemBerat}kg)',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    _formatCurrency(courierPrice),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDarkMode ? Colors.white : Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
              if (widget.asuransiPengiriman) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Asuransi Pengiriman',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      _formatCurrency(asuransiPrice),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDarkMode ? Colors.white : Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
              ],
              if (widget.packingKayu) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Packing Kayu',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      _formatCurrency(packingPrice),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDarkMode ? Colors.white : Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Divider(
                color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade100,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Pembayaran',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.grey.shade800,
                    ),
                  ),
                  Text(
                    _formatCurrency(totalPrice),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoBox(bool isDarkMode, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.blue.shade900.withValues(alpha: 0.1)
            : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_user, color: Colors.blue.shade500, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Dengan menekan tombol bayar, Anda menyetujui syarat dan ketentuan pengiriman yang berlaku.',
              style: TextStyle(
                fontSize: 10,
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
    int totalPrice,
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
          bottom: MediaQuery.of(context).padding.bottom + 32,
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
          onTap: () => _submitShipment(context, totalPrice),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: _isSubmitting ? primaryColor.withValues(alpha: 0.6) : primaryColor,
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
            child: _isSubmitting
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Memproses Pesanan...',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  )
                : const Text(
                    'Bayar Sekarang',
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

