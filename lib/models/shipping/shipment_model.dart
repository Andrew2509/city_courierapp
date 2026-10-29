class ShipmentModel {
  final int id;
  final String orderNumber;
  final String? trackingNumber;
  final String senderName;
  final String? senderPhone;
  final String recipientName;
  final String recipientPhone;
  final String pickupAddress;
  final String deliveryAddress;
  final double weight;
  final String? itemType;
  final double? itemLength;
  final double? itemWidth;
  final double? itemHeight;
  final double? distance;
  final double totalPrice;
  final String status;
  final String statusLabel;
  final String? courierName;
  final String? courierPhone;
  final String? courierPhoto;
  final String? courierVehicleBrand;
  final String? courierVehicleModel;
  final String? courierVehiclePlate;
  final DateTime? orderDate;

  /// Deskripsi kendaraan kurir (e.g. "Honda Vario • B 4920 SDC")
  String get courierVehicleDescription {
    final brandModel = [
      if (courierVehicleBrand != null && courierVehicleBrand!.trim().isNotEmpty)
        courierVehicleBrand!.trim(),
      if (courierVehicleModel != null && courierVehicleModel!.trim().isNotEmpty)
        courierVehicleModel!.trim(),
    ].join(' ');

    final plate = courierVehiclePlate?.trim() ?? '';

    if (brandModel.isNotEmpty && plate.isNotEmpty) {
      return '$brandModel • $plate';
    } else if (brandModel.isNotEmpty) {
      return brandModel;
    } else if (plate.isNotEmpty) {
      return plate;
    }
    return '';
  }
  final DateTime? pickupScheduledAt;
  final DateTime? estimatedDelivery;
  final DateTime? pickedUpAt;
  final DateTime? deliveredAt;
  final String? notes;
  final double? latitudePickup;
  final double? longitudePickup;
  final double? latitudeDelivery;
  final double? longitudeDelivery;
  final DateTime createdAt;
  final DateTime updatedAt;
  final PaymentInfo? paymentInfo;
  final String? vehicleType;
  final bool? scheduledPickup;
  final String? pickupTime;

  ShipmentModel({
    required this.id,
    required this.orderNumber,
    this.trackingNumber,
    required this.senderName,
    this.senderPhone,
    required this.recipientName,
    required this.recipientPhone,
    required this.pickupAddress,
    required this.deliveryAddress,
    required this.weight,
    this.itemType,
    this.itemLength,
    this.itemWidth,
    this.itemHeight,
    this.distance,
    required this.totalPrice,
    required this.status,
    required this.statusLabel,
    this.courierName,
    this.courierPhone,
    this.courierPhoto,
    this.courierVehicleBrand,
    this.courierVehicleModel,
    this.courierVehiclePlate,
    this.orderDate,
    this.pickupScheduledAt,
    this.estimatedDelivery,
    this.pickedUpAt,
    this.deliveredAt,
    this.notes,
    this.latitudePickup,
    this.longitudePickup,
    this.latitudeDelivery,
    this.longitudeDelivery,
    required this.createdAt,
    required this.updatedAt,
    this.paymentInfo,
    this.vehicleType,
    this.scheduledPickup,
    this.pickupTime,
  });

  factory ShipmentModel.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return ShipmentModel(
      id: json['id'] ?? 0,
      orderNumber: json['shipment_number'] ?? json['order_number'] ?? '',
      trackingNumber: json['tracking_number'],
      senderName: json['sender_name'] ?? 'N/A',
      senderPhone: json['sender_phone'],
      recipientName: json['receiver_name'] ?? json['recipient_name'] ?? '',
      recipientPhone: json['receiver_phone'] ?? json['recipient_phone'] ?? '',
      pickupAddress: json['sender_address'] ?? json['pickup_address'] ?? '',
      deliveryAddress: json['receiver_address'] ?? json['delivery_address'] ?? '',
      weight: parseDouble(json['package_weight'] ?? json['weight']),
      itemType: json['package_description'] ?? json['item_type'],
      itemLength: json['item_length'] != null ? parseDouble(json['item_length']) : null,
      itemWidth: json['item_width'] != null ? parseDouble(json['item_width']) : null,
      itemHeight: json['item_height'] != null ? parseDouble(json['item_height']) : null,
      distance: json['distance'] != null ? parseDouble(json['distance']) : null,
      totalPrice: parseDouble(json['total_cost'] ?? json['total_price']),
      status: json['status'] ?? 'pending',
      statusLabel: json['status_label'] ?? 'Sedang Diproses',
      courierName: json['courier_name'] ?? (json['courier'] is Map ? json['courier']['name'] : null),
      courierPhone: json['courier_phone'] ?? (json['courier'] is Map ? json['courier']['phone'] : null),
      courierPhoto: json['courier_photo'] ??
          json['courier_avatar'] ??
          json['photo_url'] ??
          (json['courier'] is Map
              ? (json['courier']['photo'] ??
                  json['courier']['avatar'] ??
                  json['courier']['photo_url'] ??
                  json['courier']['profile_photo_url'])
              : null),
      courierVehicleBrand: json['courier_vehicle_brand'] ??
          json['vehicle_brand'] ??
          (json['courier'] is Map
              ? (json['courier']['vehicle_brand'] ??
                  (json['courier']['courier_details'] is Map ? json['courier']['courier_details']['vehicle_brand'] : null))
              : null) ??
          (json['courier_details'] is Map ? json['courier_details']['vehicle_brand'] : null),
      courierVehicleModel: json['courier_vehicle_model'] ??
          json['vehicle_model'] ??
          (json['courier'] is Map
              ? (json['courier']['vehicle_model'] ??
                  (json['courier']['courier_details'] is Map ? json['courier']['courier_details']['vehicle_model'] : null))
              : null) ??
          (json['courier_details'] is Map ? json['courier_details']['vehicle_model'] : null),
      courierVehiclePlate: json['courier_vehicle_plate'] ??
          json['vehicle_plate'] ??
          json['plate_number'] ??
          json['courier_plate'] ??
          (json['courier'] is Map
              ? (json['courier']['vehicle_plate'] ??
                  json['courier']['plate_number'] ??
                  (json['courier']['courier_details'] is Map ? json['courier']['courier_details']['vehicle_plate'] : null))
              : null) ??
          (json['courier_details'] is Map ? json['courier_details']['vehicle_plate'] : null),
      orderDate: json['order_date'] != null
          ? DateTime.parse(json['order_date'])
          : null,
      pickupScheduledAt: json['pickup_scheduled_at'] != null
          ? DateTime.parse(json['pickup_scheduled_at'])
          : null,
      estimatedDelivery: json['estimated_delivery'] != null
          ? DateTime.parse(json['estimated_delivery'])
          : null,
      pickedUpAt: json['picked_up_at'] != null
          ? DateTime.parse(json['picked_up_at'])
          : null,
      deliveredAt: json['delivered_at'] != null
          ? DateTime.parse(json['delivered_at'])
          : null,
      notes: json['notes'],
      latitudePickup: json['latitude_pickup'] != null ? parseDouble(json['latitude_pickup']) : null,
      longitudePickup: json['longitude_pickup'] != null ? parseDouble(json['longitude_pickup']) : null,
      latitudeDelivery: json['latitude_delivery'] != null ? parseDouble(json['latitude_delivery']) : null,
      longitudeDelivery: json['longitude_delivery'] != null ? parseDouble(json['longitude_delivery']) : null,
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated_at'] ?? DateTime.now().toIso8601String()),
      paymentInfo: json['payment_info'] != null 
          ? PaymentInfo.fromJson(json['payment_info']) 
          : null,
      vehicleType: json['vehicle_type']?.toString() ?? json['vehicle']?.toString(),
      scheduledPickup: json['scheduled_pickup'] == true ||
          json['is_scheduled_pickup'] == true ||
          json['scheduled_pickup'] == 1,
      pickupTime: json['pickup_time']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_number': orderNumber,
      'tracking_number': trackingNumber,
      'sender_name': senderName,
      'sender_phone': senderPhone,
      'recipient_name': recipientName,
      'recipient_phone': recipientPhone,
      'pickup_address': pickupAddress,
      'delivery_address': deliveryAddress,
      'weight': weight,
      'item_type': itemType,
      'item_length': itemLength,
      'item_width': itemWidth,
      'item_height': itemHeight,
      'distance': distance,
      'total_price': totalPrice,
      'status': status,
      'status_label': statusLabel,
      'courier_name': courierName,
      'courier_phone': courierPhone,
      'courier_photo': courierPhoto,
      'courier_vehicle_brand': courierVehicleBrand,
      'courier_vehicle_model': courierVehicleModel,
      'courier_vehicle_plate': courierVehiclePlate,
      'order_date': orderDate?.toIso8601String(),
      'scheduled_pickup': scheduledPickup ?? false,
      if (scheduledPickup == true && pickupScheduledAt != null)
        'pickup_scheduled_at': pickupScheduledAt!.toIso8601String(),
      if (scheduledPickup == true && pickupScheduledAt != null)
        'pickup_date': pickupScheduledAt!.toIso8601String().substring(0, 10),
      if (scheduledPickup == true && pickupTime != null) 'pickup_time': pickupTime,
      'estimated_delivery': estimatedDelivery?.toIso8601String(),
      'picked_up_at': pickedUpAt?.toIso8601String(),
      'delivered_at': deliveredAt?.toIso8601String(),
      'notes': notes,
      'latitude_pickup': latitudePickup,
      'longitude_pickup': longitudePickup,
      'latitude_delivery': latitudeDelivery,
      'longitude_delivery': longitudeDelivery,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'payment_info': paymentInfo?.toJson(),
      'vehicle_type': vehicleType,
    };
  }
}

class PaymentInfo {
  final String? vaNumber;
  final String? bankName;
  final double amount;
  final DateTime? expiredAt;
  final String? paymentUrl;
  final String? qrString;

  PaymentInfo({
    this.vaNumber,
    this.bankName,
    required this.amount,
    this.expiredAt,
    this.paymentUrl,
    this.qrString,
  });

  factory PaymentInfo.fromJson(Map<String, dynamic> json) {
    return PaymentInfo(
      vaNumber: json['va_number'],
      bankName: json['bank_name'],
      amount: (json['amount'] ?? 0).toDouble(),
      expiredAt: json['expired_at'] != null 
          ? DateTime.parse(json['expired_at']) 
          : null,
      paymentUrl: json['payment_url'],
      qrString: json['qr_string'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'va_number': vaNumber,
      'bank_name': bankName,
      'amount': amount,
      'expired_at': expiredAt?.toIso8601String(),
      'payment_url': paymentUrl,
      'qr_string': qrString,
    };
  }
}
