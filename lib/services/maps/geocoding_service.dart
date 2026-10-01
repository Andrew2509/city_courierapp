import '../../data/models/address_model.dart';

/// Abstract geocoding service — providers can be swapped without changing UI (PRD §12, §43).
abstract class GeocodingService {
  Future<List<Address>> searchAddress(String query);
  Future<Address?> reverseGeocode(double lat, double lng);
  Future<Address?> getPlaceDetails(String placeId);
}
