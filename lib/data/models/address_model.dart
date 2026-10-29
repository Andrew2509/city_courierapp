class Address {
  final String? id;
  final String? placeId;
  final String? osmType;
  final String? osmId;
  final String formattedAddress;
  final String? houseNumber;
  final String? streetName;
  final String? neighbourhood;
  final String? village;
  final String? district;
  final String? city;
  final String? province;
  final String? postalCode;
  final String? country;
  final double latitude;
  final double longitude;
  final double? accuracy;
  final String locationSource; // e.g. provider, gps, manual_pin
  final String? addressDetail;
  final String? poiName;
  final String? category;

  Address({
    this.id,
    this.placeId,
    this.osmType,
    this.osmId,
    required this.formattedAddress,
    this.houseNumber,
    this.streetName,
    this.neighbourhood,
    this.village,
    this.district,
    this.city,
    this.province,
    this.postalCode,
    this.country,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    required this.locationSource,
    this.addressDetail,
    this.poiName,
    this.category,
  });

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      id: json['id'],
      placeId: json['place_id']?.toString(),
      osmType: json['osm_type'],
      osmId: json['osm_id']?.toString(),
      formattedAddress: json['formatted_address'] ?? '',
      houseNumber: json['house_number'],
      streetName: json['street_name'],
      neighbourhood: json['neighbourhood'],
      village: json['village'],
      district: json['district'],
      city: json['city'],
      province: json['province'],
      postalCode: json['postal_code'],
      country: json['country'],
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      locationSource: json['location_source'] ?? 'provider',
      addressDetail: json['address_detail'],
      poiName: json['poi_name'],
      category: json['category'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'place_id': placeId,
      'osm_type': osmType,
      'osm_id': osmId,
      'formatted_address': formattedAddress,
      'house_number': houseNumber,
      'street_name': streetName,
      'neighbourhood': neighbourhood,
      'village': village,
      'district': district,
      'city': city,
      'province': province,
      'postal_code': postalCode,
      'country': country,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'location_source': locationSource,
      'address_detail': addressDetail,
      'poi_name': poiName,
      'category': category,
    };
  }

  Address copyWith({
    String? id,
    String? placeId,
    String? osmType,
    String? osmId,
    String? formattedAddress,
    String? houseNumber,
    String? streetName,
    String? neighbourhood,
    String? village,
    String? district,
    String? city,
    String? province,
    String? postalCode,
    String? country,
    double? latitude,
    double? longitude,
    double? accuracy,
    String? locationSource,
    String? addressDetail,
    String? poiName,
    String? category,
  }) {
    return Address(
      id: id ?? this.id,
      placeId: placeId ?? this.placeId,
      osmType: osmType ?? this.osmType,
      osmId: osmId ?? this.osmId,
      formattedAddress: formattedAddress ?? this.formattedAddress,
      houseNumber: houseNumber ?? this.houseNumber,
      streetName: streetName ?? this.streetName,
      neighbourhood: neighbourhood ?? this.neighbourhood,
      village: village ?? this.village,
      district: district ?? this.district,
      city: city ?? this.city,
      province: province ?? this.province,
      postalCode: postalCode ?? this.postalCode,
      country: country ?? this.country,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracy: accuracy ?? this.accuracy,
      locationSource: locationSource ?? this.locationSource,
      addressDetail: addressDetail ?? this.addressDetail,
      poiName: poiName ?? this.poiName,
      category: category ?? this.category,
    );
  }
}
