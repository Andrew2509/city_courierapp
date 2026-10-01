import 'package:latlong2/latlong.dart';

/// Status pengiriman standar CityCourier — harus match persis dengan backend
enum TrackingStatus {
  pending,
  confirmed,
  assigned,
  pickingUp,
  pickedUp,
  delivering,
  inTransit,
  delivered,
  cancelled,
  unknown;

  String get label {
    switch (this) {
      case TrackingStatus.pending:
        return 'Menunggu';
      case TrackingStatus.confirmed:
        return 'Pesanan Dikonfirmasi';
      case TrackingStatus.assigned:
        return 'Kurir Ditugaskan';
      case TrackingStatus.pickingUp:
        return 'Kurir Sedang Menjemput';
      case TrackingStatus.pickedUp:
        return 'Paket Dalam Perjalanan ke Penerima';
      case TrackingStatus.delivering:
        return 'Segera Tiba';
      case TrackingStatus.inTransit:
        return 'Dalam Perjalanan';
      case TrackingStatus.delivered:
        return 'Paket Diterima';
      case TrackingStatus.cancelled:
        return 'Dibatalkan';
      case TrackingStatus.unknown:
        return 'Status Tidak Diketahui';
    }
  }

  /// Step index for progress bar (0-based, 4 steps total):
  /// 0 = Dibuat, 1 = Dijemput, 2 = Dalam Perjalanan, 3 = Diterima
  int get progressIndex {
    switch (this) {
      case TrackingStatus.pending:
      case TrackingStatus.confirmed:
        return 0; // Dibuat
      case TrackingStatus.assigned:
      case TrackingStatus.pickingUp:
        return 1; // Dijemput
      case TrackingStatus.pickedUp:
      case TrackingStatus.delivering:
      case TrackingStatus.inTransit:
        return 2; // Perjalanan
      case TrackingStatus.delivered:
        return 3; // Diterima
      case TrackingStatus.cancelled:
      case TrackingStatus.unknown:
        return -1;
    }
  }

  bool get isTerminal =>
      this == TrackingStatus.delivered ||
      this == TrackingStatus.cancelled;

  static TrackingStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'pending':
        return TrackingStatus.pending;
      case 'confirmed':
        return TrackingStatus.confirmed;
      case 'assigned':
        return TrackingStatus.assigned;
      case 'picking_up':
        return TrackingStatus.pickingUp;
      case 'picked_up':
        return TrackingStatus.pickedUp;
      case 'delivering':
        return TrackingStatus.delivering;
      case 'in_transit':
        return TrackingStatus.inTransit;
      case 'delivered':
        return TrackingStatus.delivered;
      case 'cancelled':
        return TrackingStatus.cancelled;
      default:
        return TrackingStatus.unknown;
    }
  }
}

/// Model untuk data tracking dari backend
class TrackingModel {
  final String trackingNumber;
  final TrackingStatus status;
  final String statusLabel;
  final TrackingLocation? origin;
  final TrackingLocation? destination;
  final LatLng? currentLocation;
  final TrackingCourier? courier;
  final DateTime? estimatedDelivery;
  final List<TrackingTimelineItem> timeline;
  final String? courierService;
  final DateTime? orderDate;
  final DateTime? pickedUpAt;
  final DateTime? deliveredAt;
  final DateTime createdAt;

  const TrackingModel({
    required this.trackingNumber,
    required this.status,
    required this.statusLabel,
    this.origin,
    this.destination,
    this.currentLocation,
    this.courier,
    this.estimatedDelivery,
    this.timeline = const [],
    this.courierService,
    this.orderDate,
    this.pickedUpAt,
    this.deliveredAt,
    required this.createdAt,
  });

  factory TrackingModel.fromJson(Map<String, dynamic> json) {
    double? parseDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    // ── Origin (pickup location) ──
    // Backend returns: sender_address, sender_latitude, sender_longitude
    // Also handles: origin (Map), pickup_address, latitude_pickup
    TrackingLocation? origin;
    if (json['origin'] is Map) {
      final o = json['origin'] as Map<String, dynamic>;
      origin = TrackingLocation.fromJson(o);
    } else if (json['sender_address'] != null ||
        json['pickup_address'] != null) {
      // Try multiple field names for latitude/longitude
      final lat = parseDouble(json['sender_latitude']) ??
          parseDouble(json['latitude_pickup']) ??
          parseDouble(json['pickup_lat']) ??
          parseDouble(json['lat_pickup']);
      final lng = parseDouble(json['sender_longitude']) ??
          parseDouble(json['longitude_pickup']) ??
          parseDouble(json['pickup_lng']) ??
          parseDouble(json['lng_pickup']);
      origin = TrackingLocation(
        address: (json['sender_address'] ?? json['pickup_address'] ?? '').toString(),
        latitude: lat,
        longitude: lng,
      );
    }

    // ── Destination (delivery location) ──
    // Backend returns: receiver_address, receiver_latitude, receiver_longitude
    // Also handles: destination (Map), delivery_address, latitude_delivery
    TrackingLocation? destination;
    if (json['destination'] is Map) {
      final d = json['destination'] as Map<String, dynamic>;
      destination = TrackingLocation.fromJson(d);
    } else if (json['receiver_address'] != null ||
        json['delivery_address'] != null) {
      // Try multiple field names for latitude/longitude
      final lat = parseDouble(json['receiver_latitude']) ??
          parseDouble(json['latitude_delivery']) ??
          parseDouble(json['delivery_lat']) ??
          parseDouble(json['lat_delivery']);
      final lng = parseDouble(json['receiver_longitude']) ??
          parseDouble(json['longitude_delivery']) ??
          parseDouble(json['delivery_lng']) ??
          parseDouble(json['lng_delivery']);
      destination = TrackingLocation(
        address: (json['receiver_address'] ?? json['delivery_address'] ?? '').toString(),
        latitude: lat,
        longitude: lng,
      );
    }

    // ── Current location (kurir) ──
    // Prioritas key (backend memakai nama berbeda-beda):
    //   current_location (Map) — versi Flutter lama
    //   courier_location (Map) — key yang dikeluarkan TrackingService backend
    LatLng? currentLocation;
    final Map<String, dynamic>? locMap = json['current_location'] is Map
        ? json['current_location'] as Map<String, dynamic>
        : (json['courier_location'] is Map
            ? json['courier_location'] as Map<String, dynamic>
            : null);
    if (locMap != null) {
      final lat = parseDouble(locMap['latitude']);
      final lng = parseDouble(locMap['longitude']);
      if (lat != null && lng != null) currentLocation = LatLng(lat, lng);
    }

    // ── Courier ──
    TrackingCourier? courier;
    if (json['courier'] is Map) {
      courier = TrackingCourier.fromJson(json['courier'] as Map<String, dynamic>);
    } else if (json['courier_name'] != null) {
      courier = TrackingCourier(
        name: (json['courier_name'] ?? '').toString(),
        phone: json['courier_phone']?.toString(),
        photo: json['courier_photo']?.toString(),
      );
    }

    // ── Timeline / logs ──
    // Backend mengembalikan array logs dengan field:
    //   status, location, description, created_at
    List<TrackingTimelineItem> timeline = [];
    final logsData = json['logs'] ?? json['timeline'] ?? json['status_history'] ?? json['history'];
    if (logsData is List) {
      timeline = logsData
          .whereType<Map<String, dynamic>>()
          .map((e) => TrackingTimelineItem.fromJson(e))
          .toList();
    }

    // ── Status ──
    final status = TrackingStatus.fromString(json['status']);
    final statusLabel =
        (json['status_label'] ?? json['status_label_id'] ?? status.label).toString();

    // ── Tracking number ──
    final trackingNumber = (json['tracking_number'] ??
        json['shipment_number'] ??
        json['order_number'] ??
        '').toString();

    return TrackingModel(
      trackingNumber: trackingNumber,
      status: status,
      statusLabel: statusLabel,
      origin: origin,
      destination: destination,
      currentLocation: currentLocation,
      courier: courier,
      estimatedDelivery: parseDate(json['estimated_delivery']),
      timeline: timeline,
      courierService: json['courier_service']?.toString(),
      orderDate: parseDate(json['order_date']),
      pickedUpAt: parseDate(json['picked_up_at']),
      deliveredAt: parseDate(json['delivered_at']),
      createdAt: parseDate(json['created_at']) ?? DateTime.now(),
    );
  }
}

/// Lokasi pada tracking (pickup / destination)
class TrackingLocation {
  final String address;
  final double? latitude;
  final double? longitude;

  const TrackingLocation({
    required this.address,
    this.latitude,
    this.longitude,
  });

  LatLng? get latLng {
    if (latitude != null && longitude != null) {
      return LatLng(latitude!, longitude!);
    }
    return null;
  }

  factory TrackingLocation.fromJson(Map<String, dynamic> json) {
    double? parseDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    return TrackingLocation(
      address: (json['address'] ?? '').toString(),
      latitude: parseDouble(json['latitude']),
      longitude: parseDouble(json['longitude']),
    );
  }
}

/// Info kurir
class TrackingCourier {
  final String name;
  final String? phone;
  final String? photo;

  const TrackingCourier({
    required this.name,
    this.phone,
    this.photo,
  });

  factory TrackingCourier.fromJson(Map<String, dynamic> json) {
    return TrackingCourier(
      name: (json['name'] ?? '').toString(),
      phone: json['phone']?.toString(),
      photo: json['photo']?.toString(),
    );
  }
}

/// Item pada timeline pengiriman
class TrackingTimelineItem {
  final String status;
  final String? location;
  final String? description;
  final DateTime? createdAt;
  final bool isCurrent;

  const TrackingTimelineItem({
    required this.status,
    this.location,
    this.description,
    this.createdAt,
    this.isCurrent = false,
  });

  factory TrackingTimelineItem.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    return TrackingTimelineItem(
      status: (json['status'] ?? '').toString(),
      location: json['location']?.toString(),
      description: json['description']?.toString(),
      createdAt: parseDate(json['created_at']) ?? parseDate(json['timestamp']),
      isCurrent: json['is_current'] ?? false,
    );
  }

  String get statusLabel {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pesanan dibuat';
      case 'confirmed':
        return 'Pesanan dikonfirmasi';
      case 'assigned':
        return 'Kurir ditugaskan';
      case 'picking_up':
        return 'Kurir sedang menjemput paket';
      case 'picked_up':
        return 'Paket dalam perjalanan ke penerima';
      case 'delivering':
        return 'Kurir segera tiba';
      case 'in_transit':
        return 'Dalam perjalanan';
      case 'arriving':
        return 'Segera tiba';
      case 'delivered':
        return 'Paket diterima';
      case 'cancelled':
        return 'Pengiriman dibatalkan';
      default:
        return location ?? status;
    }
  }
}
