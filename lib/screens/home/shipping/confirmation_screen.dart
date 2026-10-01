import 'package:flutter/material.dart';
import 'package:city_courierapp/screens/home/shipping/payment_method_screen.dart';
import 'package:city_courierapp/services/api_service.dart';

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

      final body = {
        'customer_name': sender?['name'] ?? 'Pengirim',
        'customer_phone': sender?['phone'] ?? '',
        'sender_name': sender?['name'] ?? 'Pengirim',
        'sender_phone': sender?['phone'] ?? '',
        'sender_address': (sender?['address'] ?? '').toString().trim(),
        'sender_latitude': sender?['latitude'],
        'sender_longitude': sender?['longitude'],
        'origin_name': sender?['kecamatan_name'] ?? sender?['subdistrict_name'] ?? sender?['city_name'] ?? '',
        'origin_id': (sender?['subdistrict_id'] ?? sender?['city_id'])?.toString() ?? '',
        'receiver_name': receiver?['name'] ?? 'Penerima',
        'receiver_phone': receiver?['phone'] ?? '',
        'receiver_address': (receiver?['address'] ?? '').toString().trim(),
        'receiver_latitude': receiver?['latitude'],
        'receiver_longitude': receiver?['longitude'],
        'destination_name': receiver?['kecamatan_name'] ?? receiver?['subdistrict_name'] ?? receiver?['city_name'] ?? '',
        'destination_id': (receiver?['subdistrict_id'] ?? receiver?['city_id'])?.toString() ?? '',
        'package_description': widget.itemDeskripsi,
        'package_weight': widget.itemBerat,
        'courier_code': courier?['code'] ?? '',
        'courier_name': courier?['name'] ?? courier?['courier_name'] ?? 'Kurir',
        'courier_service': courier?['service'] ?? courier?['courier_service'] ?? 'REG',
        'etd': courier?['duration'] ?? '',
        'shipping_cost': courier?['price'] ?? 0,
        'insurance': widget.asuransiPengiriman,
        'wood_packing': widget.packingKayu,
        'total_cost': totalPrice,
      };

      print('DEBUG: Shipment Payload: $body');

      final response = await ApiService.post('/shipments', body);

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
                              
        // Ambil data barcode/QR dari backend (bisa berupa teks atau URL)
        final barcodeData = response['data']?['barcode'] ?? 
                           response['data']?['qr_code'] ?? 
                           response['data']?['qr_string'];
                           
        final barcodeUrl = response['data']?['barcode_url'] ?? 
                          response['data']?['qr_url'];
                              
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentMethodScreen(
              totalAmount: totalPrice,
              shipmentId: shipmentId,
              trackingNumber: trackingNumber.toString(),
              barcodeData: barcodeData?.toString(),
              barcodeUrl: barcodeUrl?.toString(),
              senderCity: widget.senderData?['city_name'],
              receiverCity: widget.receiverData?['city_name'],
            ),
          ),
        );
      } else {
        // Show error from server
        String errorMessage = response?['message'] ?? 'Gagal membuat pesanan pengiriman';
        
        // Handle Laravel validation errors
        if (response?['errors'] != null) {
          final Map<String, dynamic> errors = response!['errors'];
          if (errors.isNotEmpty) {
            final firstErrorList = errors.values.first;
            if (firstErrorList is List && firstErrorList.isNotEmpty) {
              errorMessage = firstErrorList.first.toString();
            }
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Terjadi kesalahan: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
                              ((widget.senderData?['address'] ?? '') + (widget.senderData?['kecamatan_name'] != null ? ', ' + widget.senderData!['kecamatan_name'] : '')).trim().isEmpty ? 'Alamat Pengirim' : ((widget.senderData?['address'] ?? '') + (widget.senderData?['kecamatan_name'] != null ? ', ' + widget.senderData!['kecamatan_name'] : '')),
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
                              ((widget.receiverData?['address'] ?? '') + (widget.receiverData?['kecamatan_name'] != null ? ', ' + widget.receiverData!['kecamatan_name'] : '')).trim().isEmpty ? 'Alamat Penerima' : ((widget.receiverData?['address'] ?? '') + (widget.receiverData?['kecamatan_name'] != null ? ', ' + widget.receiverData!['kecamatan_name'] : '')),
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
                child: Column(
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
                    Row(
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.monitor_weight_outlined,
                              size: 10,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${widget.itemBerat} kg',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.straighten,
                              size: 10,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${widget.itemBeratVolume.toStringAsFixed(1)} kg (Vol)',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade500,
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
                        'Estimasi $courierDur sampai',
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
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
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

