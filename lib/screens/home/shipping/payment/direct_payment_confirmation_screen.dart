import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:city_courierapp/screens/home_screen.dart';
import 'package:city_courierapp/screens/home/tracking/tracking_detail_screen.dart';
import 'package:city_courierapp/services/shipping/active_order_service.dart';

class DirectPaymentConfirmationScreen extends StatelessWidget {
  final String orderId;
  final String paymentMethod;
  final int amount;
  final String? barcodeData;
  final String? barcodeUrl;
  final String? senderName;
  final String? senderCity;
  final String? receiverName;
  final String? receiverCity;
  final String? vehicle;
  final String? trackingUrl;
  final Map<String, dynamic>? shipmentData;

  const DirectPaymentConfirmationScreen({
    super.key,
    required this.orderId,
    required this.paymentMethod,
    required this.amount,
    this.barcodeData,
    this.barcodeUrl,
    this.senderName,
    this.senderCity,
    this.receiverName,
    this.receiverCity,
    this.vehicle,
    this.trackingUrl,
    this.shipmentData,
  });

  Future<void> _shareToWhatsApp(BuildContext context) async {
    final sName = senderName ?? shipmentData?['sender_name'] ?? 'brightness';
    final sCity = senderCity ?? shipmentData?['origin_name'] ?? 'Sidoarjo';
    final rName = receiverName ?? shipmentData?['receiver_name'] ?? 'andrew';
    final rCity = receiverCity ?? shipmentData?['destination_name'] ?? 'Surabaya';
    
    final vRaw = (vehicle ?? shipmentData?['vehicle'] ?? shipmentData?['courier_name'] ?? 'motor').toString().toLowerCase();
    final veh = vRaw.contains('mobil') || vRaw.contains('car') ? 'Mobil' : 'Motor';
    
    final trackUrl = trackingUrl ?? 'https://citycourier.pabm.space/track/$orderId';
    final qrUrl = barcodeUrl ?? 'https://citycourier.pabm.space/track/$orderId/qrcode.png';

    final text = '📦 *Pesanan City Courier*\n\n'
        'Nomor Resi:\n$orderId\n\n'
        'Status:\nMenunggu Kurir\n\n'
        '📍 Pengirim:\n$sName - $sCity\n\n'
        '📍 Penerima:\n$rName - $rCity\n\n'
        '🚚 Kendaraan:\n$veh\n\n'
        '🔗 Live Tracking:\n$trackUrl\n\n'
        '📱 QR Code:\n$qrUrl';

    final uri = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(text)}');
    final webUri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } else {
        await Clipboard.setData(ClipboardData(text: text));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Teks pesanan disalin ke clipboard!'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Teks pesanan disalin ke clipboard!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _getPaymentBadge() {
    final method = paymentMethod.toUpperCase();
    if (method.contains('COD')) return 'COD';
    if (method.contains('TUNAI') || method.contains('CASH')) return 'TUNAI';
    if (method.contains('QRIS')) return 'QRIS';
    if (method.contains('VA') || method.contains('VIRTUAL')) return 'VA';
    return method.isEmpty ? 'COD' : method;
  }

  String _getPaymentMethodName() {
    final method = paymentMethod.toUpperCase();
    if (method.contains('COD') || method.contains('TUNAI') || method.contains('CASH')) {
      return 'Pembayaran Tunai';
    }
    return 'Pembayaran Non Tunai';
  }

  @override
  Widget build(BuildContext context) {
    const Color darkNavy = Color(0xFF0F172A);
    const Color orangeAccent = Color(0xFFEA580C);
    const Color orangeBg = Color(0xFFFFF7ED);
    const Color orangeBorder = Color(0xFFFED7AA);
    const Color waGreen = Color(0xFF00B761);

    // Otomatis simpan pesanan aktif agar langsung melayang di Beranda pengguna
    final destCity = receiverCity ?? shipmentData?['destination_name'] ?? 'Kebayoran Baru';
    final vRaw = (vehicle ?? shipmentData?['vehicle'] ?? shipmentData?['courier_name'] ?? 'motor').toString().toLowerCase();
    final veh = vRaw.contains('mobil') || vRaw.contains('car') ? 'Mobil' : 'Motor';
    ActiveOrderService.saveActiveOrder({
      'order_id': orderId,
      'status': 'Menunggu Kurir',
      'status_raw': 'pending',
      'estimated_time': 'Mencari...',
      'courier_name': 'Menunggu Kurir',
      'courier_vehicle': 'Sistem mencari kurir $veh terdekat...',
      'courier_phone': '',
      'destination': destCity,
      'status_message': 'Pesanan berhasil dibuat. Menunggu konfirmasi kurir terdekat.',
      'step': 0,
      'has_courier': false,
      'is_delivered': false,
      'shipment_data': shipmentData,
    });

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAFAFA),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: darkNavy,
            size: 22,
          ),
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
              (route) => false,
            );
          },
        ),
        title: const Text(
          'Pesanan Berhasil',
          style: TextStyle(
            color: darkNavy,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.help_outline_rounded,
              color: Color(0xFF64748B),
              size: 22,
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Bantuan: Hubungi customer service City Courier jika ada kendala.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),
              // Success green checkmark icon
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFDCFCE7),
                  border: Border.all(
                    color: const Color(0xFFBBF7D0),
                    width: 7,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.check_rounded,
                    color: Color(0xFF059669),
                    size: 42,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Menunggu Kurir',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: darkNavy,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Pesanan Anda berhasil dibuat dan kurir akan segera menjemput paket.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // White Card (Ticket style)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Top Pill: "Tunjukkan Resi / QR ini ke Kurir"
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Tunjukkan Resi / QR ini ke Kurir',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // QR Code with Dashed Rounded Border
                    DottedBorder(
                      options: const RoundedRectDottedBorderOptions(
                        radius: Radius.circular(16),
                        dashPattern: [6, 4],
                        color: Color(0xFFCBD5E1),
                        strokeWidth: 1.5,
                        padding: EdgeInsets.all(12),
                      ),
                      child: barcodeUrl != null && barcodeUrl!.isNotEmpty
                          ? Image.network(
                              barcodeUrl!,
                              width: 176,
                              height: 176,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  QrImageView(
                                data: barcodeData ?? orderId,
                                version: QrVersions.auto,
                                size: 176.0,
                                eyeStyle: const QrEyeStyle(
                                  eyeShape: QrEyeShape.square,
                                  color: darkNavy,
                                ),
                                dataModuleStyle: const QrDataModuleStyle(
                                  dataModuleShape: QrDataModuleShape.square,
                                  color: darkNavy,
                                ),
                              ),
                            )
                          : QrImageView(
                              data: barcodeData ?? orderId,
                              version: QrVersions.auto,
                              size: 176.0,
                              eyeStyle: const QrEyeStyle(
                                eyeShape: QrEyeShape.square,
                                color: darkNavy,
                              ),
                              dataModuleStyle: const QrDataModuleStyle(
                                dataModuleShape: QrDataModuleShape.square,
                                color: darkNavy,
                              ),
                            ),
                    ),
                    const SizedBox(height: 18),

                    // NOMOR RESI label
                    const Text(
                      'NOMOR RESI',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Resi container box
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            orderId,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                              color: darkNavy,
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: orderId));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Nomor resi disalin ke clipboard'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(
                                Icons.copy_rounded,
                                size: 18,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Dotted divider
                    CustomPaint(
                      size: const Size(double.infinity, 1),
                      painter: _DottedLinePainter(
                        color: const Color(0xFFE2E8F0),
                        dashWidth: 4,
                        dashSpace: 4,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Info row: Metode Pembayaran
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Metode Pembayaran',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFF10B981)),
                                ),
                                child: Text(
                                  _getPaymentBadge(),
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF059669),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  _getPaymentMethodName(),
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: darkNavy,
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
              ),

              const SizedBox(height: 20),

              // Action Buttons: [ 🚚 Live Tracking ] & [ 💬 Bagikan ke WA ]
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: orangeBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: orangeBorder, width: 1.2),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            key: const Key('button_live_tracking'),
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => TrackingDetailScreen(
                                    trackingNumber: orderId,
                                    shipmentData: shipmentData,
                                  ),
                                ),
                              );
                            },
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.local_shipping_outlined,
                                  size: 19,
                                  color: orangeAccent,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Live Tracking',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                    color: orangeAccent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: waGreen,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            key: const Key('button_share_whatsapp'),
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => _shareToWhatsApp(context),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                FaIcon(
                                  FontAwesomeIcons.whatsapp,
                                  size: 19,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Bagikan ke WA',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.of(context).padding.bottom > 0
              ? MediaQuery.of(context).padding.bottom
              : 16,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Color(0xFFF1F5F9), width: 1),
          ),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const HomeScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: darkNavy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Kembali ke Beranda',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DottedLinePainter extends CustomPainter {
  final Color color;
  final double dashWidth;
  final double dashSpace;

  _DottedLinePainter({
    required this.color,
    this.dashWidth = 4.0,
    this.dashSpace = 4.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    double startX = 0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
