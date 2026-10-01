import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:city_courierapp/core/config/app_typography.dart';
import 'package:city_courierapp/screens/courier/ci_word/delivery/driver_delivery_confirmation_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/delivery/driver_delivery_summary_screen.dart';
import 'package:city_courierapp/core/config/app_colors.dart';

class DriverDetailShipmentScreen extends StatefulWidget {
  final Map<String, dynamic> shipment;

  const DriverDetailShipmentScreen({super.key, required this.shipment});

  @override
  State<DriverDetailShipmentScreen> createState() =>
      _DriverDetailShipmentScreenState();
}

class _DriverDetailShipmentScreenState
    extends State<DriverDetailShipmentScreen> {
  bool _isLoading = false;
  late Map<String, dynamic> _shipmentDetail;

  @override
  void initState() {
    super.initState();
    final status = widget.shipment['status'] ?? 'pending';

    // Status mapping for display
    String displayStatus = status;
    if (status == 'assigned') displayStatus = 'Siap Dijemput';
    if (status == 'picking_up') displayStatus = 'Menjemput';
    if (status == 'delivering') displayStatus = 'Dalam Perjalanan';
    if (status == 'delivered') displayStatus = 'Selesai';
    if (status == 'cancelled') displayStatus = 'Dibatalkan';

    _shipmentDetail = {
      'id': widget.shipment['id'].toString(),
      'orderNumber': widget.shipment['id'].toString(),
      'status': displayStatus,
      'rawStatus': status,
      'sender': {
        'name': widget.shipment['sender_name'] ?? 'PT Jaya Abadi',
        'phone': widget.shipment['sender_phone'] ?? '+62 813-4332-3155',
        'address':
            widget.shipment['pickup_address'] ??
            'Gudang Sunter, Jl. Danau Sunter Utara Blok O 3, Tanjung Priok, Jakarta Utara, 14350',
        'location': widget.shipment['pickup_address'] ?? 'Gudang Sunter',
        'lat': double.tryParse(widget.shipment['pickup_latitude']?.toString() ?? '') ?? -6.1950,
        'lng': double.tryParse(widget.shipment['pickup_longitude']?.toString() ?? '') ?? 106.8230,
      },
      'receiver': {
        'name': widget.shipment['receiver_name'] ?? 'Budi Santoso',
        'phone': widget.shipment['receiver_phone'] ?? '+62 813-9876-5432',
        'address':
            widget.shipment['dropoff_address'] ??
            'Apartemen Puri Indah, Jl. Puri Indah Raya Blok U 1, Kembangan, Jakarta Barat, 11610',
        'location': widget.shipment['dropoff_address'] ?? 'Apartemen Puri Indah',
        'lat': double.tryParse(widget.shipment['dropoff_latitude']?.toString() ?? '') ?? -6.2146,
        'lng': double.tryParse(widget.shipment['dropoff_longitude']?.toString() ?? '') ?? 106.8231,
      },
      'package': {
        'type': widget.shipment['item_type'] ?? 'Paket Kardus',
        'weight': '${widget.shipment['weight'] ?? "5"} kg',
        'dimen': widget.shipment['dimensions'] ?? '40x40x20 cm',
      },
      'instructions': widget.shipment['notes'] ?? 'Pegangan hati-hati, barang pecah belah.',
      'history': _getHistoryByStatus(displayStatus),
    };
  }

  List<Map<String, dynamic>> _getHistoryByStatus(String status) {
    switch (status) {
      case 'Siap Dijemput':
        return [
          {'status': 'Pesanan Dibuat', 'time': '10:00', 'isCompleted': true},
          {'status': 'Siap Dijemput', 'time': '10:30', 'isCompleted': false},
        ];
      case 'Dalam Perjalanan':
        return [
          {'status': 'Pesanan Dibuat', 'time': '10:00', 'isCompleted': true},
          {'status': 'Siap Dijemput', 'time': '10:30', 'isCompleted': true},
          {'status': 'Dijemput Driver', 'time': '11:00', 'isCompleted': true},
          {'status': 'Dalam Perjalanan', 'time': '11:15', 'isCompleted': false},
        ];
      case 'Telah Diantar':
        return [
          {'status': 'Pesanan Dibuat', 'time': '10:00', 'isCompleted': true},
          {'status': 'Siap Dijemput', 'time': '10:30', 'isCompleted': true},
          {'status': 'Dijemput Driver', 'time': '11:00', 'isCompleted': true},
          {'status': 'Dalam Perjalanan', 'time': '11:15', 'isCompleted': true},
          {'status': 'Telah Diantar', 'time': '12:00', 'isCompleted': true},
        ];
      default:
        return [
          {'status': 'Pesanan Dibuat', 'time': '10:00', 'isCompleted': true},
          {'status': 'Siap Dijemput', 'time': '10:30', 'isCompleted': false},
        ];
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[\s\-\+]'), '');
    final uri = Uri.parse('tel:$cleanNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWhatsApp(String phoneNumber) async {
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[\s\-\+]'), '');
    String waNumber = cleanNumber.startsWith('0')
        ? '62${cleanNumber.substring(1)}'
        : cleanNumber;
    if (!waNumber.startsWith('62')) waNumber = '62$waNumber';

    final uri = Uri.parse('https://wa.me/$waNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _startDelivery() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      setState(() => _isLoading = false);
      final currentStatus = _shipmentDetail['status'];

      if (currentStatus == 'Siap Dijemput') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DriverDetailShipmentScreen(
              shipment: {...widget.shipment, 'status': 'Dalam Perjalanan'},
            ),
          ),
        );
      } else if (currentStatus == 'Dalam Perjalanan') {
        final result = await Navigator.push<String?>(
          context,
          MaterialPageRoute(
            builder: (context) => DriverDeliveryConfirmationScreen(
              order: {
                'orderNumber': _shipmentDetail['orderNumber'],
                'sender': _shipmentDetail['sender'],
                'receiver': _shipmentDetail['receiver'],
                'package': _shipmentDetail['package'],
                'instructions': _shipmentDetail['instructions'],
              },
            ),
          ),
        );

        if (result != null && mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => DriverDetailShipmentScreen(
                shipment: {
                  ...widget.shipment,
                  'status': 'Telah Diantar',
                  'proofPhotoPath': result,
                },
              ),
            ),
          );
        }
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Siap Dijemput':
        return AppColors.primaryOrange;
      case 'Dalam Perjalanan':
        return Colors.blueAccent;
      case 'Telah Diantar':
        return Colors.grey;
      default:
        return AppColors.primaryOrange;
    }
  }

  String _getMainButtonText() {
    final status = _shipmentDetail['status'];
    switch (status) {
      case 'Siap Dijemput':
        return 'Mulai Pengiriman';
      case 'Dalam Perjalanan':
        return 'Selesaikan Pengiriman';
      case 'Telah Diantar':
        return 'Lihat Ringkasan';
      default:
        return 'Mulai Pengiriman';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black,
            size: 20,
          ),
        ),
        title: Text(
          'Detail Pengiriman',
          style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOrderHeader(),

            if (_shipmentDetail['status'] == 'Telah Diantar' &&
                widget.shipment['proofPhotoPath'] != null)
              _buildProofPhotoSection()
            else
              _buildMapSection(),

            const SizedBox(height: 24),

            _buildContactCard(
              title: "LOKASI PENJEMPUTAN",
              name: _shipmentDetail['sender']['name'],
              address: _shipmentDetail['sender']['address'],
              phone: _shipmentDetail['sender']['phone'],
              isPickup: true,
            ),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Divider(thickness: 1, color: Color(0xFFF1F1F1)),
            ),

            _buildContactCard(
              title: "LOKASI TUJUAN",
              name: _shipmentDetail['receiver']['name'],
              address: _shipmentDetail['receiver']['address'],
              phone: _shipmentDetail['receiver']['phone'],
              isPickup: false,
            ),

            const SizedBox(height: 24),
            _buildPackageDetailSection(),

            const SizedBox(height: 24),
            _buildShipmentHistory(),

            const SizedBox(height: 120),
          ],
        ),
      ),
      bottomSheet: _buildBottomActions(),
    );
  }

  Widget _buildOrderHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NOMOR PESANAN',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[400],
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _shipmentDetail['orderNumber'],
                style: AppTypography.bodyLarge.copyWith(
                  fontWeight: FontWeight.w900,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _getStatusColor(
                _shipmentDetail['status'],
              ).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _shipmentDetail['status'].toUpperCase(),
              style: TextStyle(
                color: _getStatusColor(_shipmentDetail['status']),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapSection() {
    final senderLoc = LatLng(
      _shipmentDetail['sender']['lat'],
      _shipmentDetail['sender']['lng'],
    );
    final receiverLoc = LatLng(
      _shipmentDetail['receiver']['lat'],
      _shipmentDetail['receiver']['lng'],
    );

    return Container(
      height: 240,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(
                  (senderLoc.latitude + receiverLoc.latitude) / 2,
                  (senderLoc.longitude + receiverLoc.longitude) / 2,
                ),
                initialZoom: 13,
                maxZoom: 18.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.citycourier.app',
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [senderLoc, receiverLoc],
                      strokeWidth: 4,
                      color: AppColors.primaryOrange,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: senderLoc,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.location_on,
                        color: AppColors.primaryOrange,
                        size: 36,
                      ),
                    ),
                    Marker(
                      point: receiverLoc,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.redAccent,
                        size: 36,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton.extended(
                onPressed: () {},
                backgroundColor: AppColors.primaryOrange,
                label: const Text(
                  'Navigasi',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                icon: const Icon(
                  Icons.navigation_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                elevation: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProofPhotoSection() {
    final photoPath = widget.shipment['proofPhotoPath'];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 240,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        image: DecorationImage(
          image: FileImage(File(photoPath)),
          fit: BoxFit.cover,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
          ),
        ),
        padding: const EdgeInsets.all(20),
        alignment: Alignment.bottomLeft,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 14),
            ),
            const SizedBox(width: 10),
            const Text(
              'BUKTI PENGIRIMAN BERHASIL',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard({
    required String title,
    required String name,
    required String address,
    required String phone,
    required bool isPickup,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isPickup ? Icons.circle : Icons.location_on,
                size: 12,
                color: isPickup ? AppColors.primaryOrange : Colors.redAccent,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: Colors.grey[500],
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      address,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                children: [
                  GestureDetector(
                    onTap: () => _openWhatsApp(phone),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF25D366).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const FaIcon(
                        FontAwesomeIcons.whatsapp,
                        color: Color(0xFF25D366),
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _makePhoneCall(phone),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryOrange.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.phone_in_talk_rounded,
                        color: AppColors.primaryOrange,
                        size: 20,
                      ),
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

  Widget _buildPackageDetailSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFBFB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F1F1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "DETAIL BARANG",
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.grey[400],
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _detailBadge(
                Icons.inventory_2_rounded,
                _shipmentDetail['package']['type'],
              ),
              const SizedBox(width: 8),
              _detailBadge(
                Icons.scale_rounded,
                _shipmentDetail['package']['weight'],
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1, color: Color(0xFFEEEEEE)),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: Colors.amber,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _shipmentDetail['instructions'],
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primaryOrange),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildShipmentHistory() {
    final history = _shipmentDetail['history'] as List<Map<String, dynamic>>;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "RIWAYAT PENGIRIMAN",
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.grey[400],
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 24),
          ...history.asMap().entries.map((entry) {
            final isLast = entry.key == history.length - 1;
            final item = entry.value;
            final isCompleted = item['isCompleted'];

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? AppColors.primaryOrange
                            : Colors.grey[200],
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: isCompleted
                            ? [
                                BoxShadow(
                                  color: AppColors.primaryOrange.withOpacity(
                                    0.4,
                                  ),
                                  blurRadius: 6,
                                ),
                              ]
                            : [],
                      ),
                    ),
                    if (!isLast)
                      Container(
                        width: 2,
                        height: 40,
                        color: isCompleted
                            ? AppColors.primaryOrange.withOpacity(0.3)
                            : Colors.grey[100],
                      ),
                  ],
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['status'],
                        style: TextStyle(
                          fontWeight: isCompleted
                              ? FontWeight.w800
                              : FontWeight.w500,
                          color: isCompleted
                              ? Colors.black87
                              : Colors.grey[400],
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item['time'],
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 25,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading
            ? null
            : () {
                if (_shipmentDetail['status'] == 'Telah Diantar') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DriverDeliverySummaryScreen(
                        shipment: {
                          'orderNumber': _shipmentDetail['orderNumber'],
                          'receiver': _shipmentDetail['receiver']['name'],
                          'earnings': 25000,
                        },
                      ),
                    ),
                  );
                } else {
                  _startDelivery();
                }
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryOrange,
          minimumSize: const Size(double.infinity, 58),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              )
            : Text(
                _getMainButtonText(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }
}
