import 'package:flutter/material.dart';

class PickupRequestData {
  final String id;
  final String customerName;
  final String pickupAddress;
  final double distance;
  final int estimatedMinutes;
  final String itemType;
  final double estimatedWeight;
  final DateTime requestTime;
  final double? latitude;
  final double? longitude;

  PickupRequestData({
    required this.id,
    required this.customerName,
    required this.pickupAddress,
    required this.distance,
    required this.estimatedMinutes,
    required this.itemType,
    required this.estimatedWeight,
    required this.requestTime,
    this.latitude,
    this.longitude,
  });

  factory PickupRequestData.fromJson(Map<String, dynamic> json) {
    return PickupRequestData(
      id: json['id']?.toString() ?? '',
      customerName: json['customer_name'] ?? 'Pelanggan',
      pickupAddress: json['pickup_address'] ?? '-',
      distance: (json['distance'] ?? 0.0).toDouble(),
      estimatedMinutes: json['estimated_minutes'] ?? 0,
      itemType: json['item_type'] ?? 'Paket',
      estimatedWeight: (json['estimated_weight'] ?? 0.0).toDouble(),
      requestTime: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      latitude: json['latitude'],
      longitude: json['longitude'],
    );
  }
}

class PickupRequestNotification extends StatelessWidget {
  final PickupRequestData request;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const PickupRequestNotification({
    super.key,
    required this.request,
    required this.onAccept,
    required this.onReject,
  });

  static Future<bool?> show(
    BuildContext context, {
    required PickupRequestData request,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => PickupRequestNotification(
        request: request,
        onAccept: () => Navigator.pop(context, true),
        onReject: () => Navigator.pop(context, false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              children: [
                const Text(
                  'Permintaan Jemput Baru',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Dari Pelanggan: ${request.customerName}',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Container(
            height: 140,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey[200],
            ),
            child: const Center(
              child: Icon(Icons.map_outlined, size: 40, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Lokasi Jemput:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(request.pickupAddress),
                Text('${request.distance} km • ${request.estimatedMinutes} menit', style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: onReject,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                    child: const Text('Tolak'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onAccept,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                    child: const Text('Terima'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
