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
  final String? cityId;
  final String? subdistrictId;
  final String? cityName;
  final String? subdistrictName;
  final String? postalCode;

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
    this.cityId,
    this.subdistrictId,
    this.cityName,
    this.subdistrictName,
    this.postalCode,
  });

  factory DropPoint.fromJson(Map<String, dynamic> json) {
    final parsedId = json['id'] is int
        ? json['id'] as int
        : int.tryParse((json['id'] ?? '0').toString()) ?? 0;

    return DropPoint(
      id: parsedId,
      name: (json['name'] ?? '').toString(),
      address: (json['address'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      schedule: (json['schedule'] ?? '08:00 - 21:00').toString(),
      rating: double.tryParse((json['rating'] ?? '5.0').toString()) ?? 5.0,
      latitude: double.tryParse((json['latitude'] ?? '0.0').toString()) ?? 0.0,
      longitude:
          double.tryParse((json['longitude'] ?? '0.0').toString()) ?? 0.0,
      isActive: json['is_active'] == null ||
          json['is_active'] == 1 ||
          json['is_active'] == true,
      cityId: (json['city_id'] ?? json['rajaongkir_city_id'])?.toString(),
      subdistrictId: (json['subdistrict_id'] ??
              json['kecamatan_id'] ??
              json['rajaongkir_subdistrict_id'])
          ?.toString(),
      cityName: json['city_name']?.toString(),
      subdistrictName:
          (json['subdistrict_name'] ?? json['kecamatan_name'])?.toString(),
      postalCode: (json['postal_code'] ?? json['zip_code'])?.toString(),
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
      if (cityId != null && cityId!.isNotEmpty) 'city_id': cityId,
      if (subdistrictId != null && subdistrictId!.isNotEmpty)
        'subdistrict_id': subdistrictId,
      if (cityName != null && cityName!.isNotEmpty) 'city_name': cityName,
      if (subdistrictName != null && subdistrictName!.isNotEmpty)
        'subdistrict_name': subdistrictName,
      if (postalCode != null && postalCode!.isNotEmpty)
        'postal_code': postalCode,
    };
  }
}
