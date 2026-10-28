import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:city_courierapp/screens/home_screen.dart';
import 'package:city_courierapp/screens/home/tracking/tracking_detail_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF0F172A);
    const Color orangeAccent = Color(0xFFEC5B13);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Pesanan Berhasil',
          style: TextStyle(
            color: primaryColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false, // Prevent going back
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 64,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Menunggu Kurir',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Pesanan Anda berhasil dibuat dan kurir akan segera menjemput paket.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),

              // QR Code and Receipt Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'Tunjukkan Resi / QR ini ke Kurir',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 20),
                    barcodeUrl != null && barcodeUrl!.isNotEmpty
                        ? Image.network(
                            barcodeUrl!,
                            height: 200,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                QrImageView(
                              data: barcodeData ?? orderId,
                              version: QrVersions.auto,
                              size: 200.0,
                            ),
                          )
                        : QrImageView(
                            data: barcodeData ?? orderId,
                            version: QrVersions.auto,
                            size: 200.0,
                          ),
                    const SizedBox(height: 20),
                    Text(
                      'Nomor Resi',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          orderId,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            color: primaryColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: orderId));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Nomor resi disalin'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          icon: Icon(
                            Icons.copy_rounded,
                            size: 20,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Metode Pembayaran',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            paymentMethod.toUpperCase() == 'COD' ? 'Bayar di Tempat (COD)' : 'Pembayaran Tunai',
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Action Buttons: [ 🚚 Live Tracking ] & [ 📱 Bagikan ke WhatsApp ]
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('button_live_tracking'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TrackingDetailScreen(
                              trackingNumber: orderId,
                            ),
                          ),
                        );
                      },
                      icon: const Text('🚚', style: TextStyle(fontSize: 16)),
                      label: const Text(
                        'Live Tracking',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: orangeAccent,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: orangeAccent,
                        side: const BorderSide(color: orangeAccent, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      key: const Key('button_share_whatsapp'),
                      onPressed: () => _shareToWhatsApp(context),
                      icon: const Text('📱', style: TextStyle(fontSize: 16)),
                      label: const Text(
                        'Bagikan ke WA',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366), // WA Green
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Colors.grey.shade100),
          ),
        ),
        child: ElevatedButton(
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
              (route) => false,
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: const Text(
            'Kembali ke Beranda',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
