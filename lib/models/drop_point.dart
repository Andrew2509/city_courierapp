class DropPoint {
  final int id;
  final String name;
  final String address;
  final String phone;
  final String schedule;
  final double rating;
  final double latitude;
  final double longitude;
  final bool isActive;

  DropPoint({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    required this.schedule,
    required this.rating,
    required this.latitude,
    required this.longitude,
    required this.isActive,
  });

  factory DropPoint.fromJson(Map<String, dynamic> json) {
    return DropPoint(
      id: json['id'],
      name: json['name'],
      address: json['address'],
      phone: json['phone'] ?? '',
      schedule: json['schedule'] ?? '08:00 - 21:00',
      rating: double.parse((json['rating'] ?? 5.0).toString()),
      latitude: double.parse((json['latitude'] ?? 0.0).toString()),
      longitude: double.parse((json['longitude'] ?? 0.0).toString()),
      isActive: json['is_active'] == 1 || json['is_active'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'phone': phone,
      'schedule': schedule,
      'rating': rating,
      'latitude': latitude,
      'longitude': longitude,
      'is_active': isActive,
    };
  }
}
