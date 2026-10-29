import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:city_courierapp/data/models/address_model.dart';
import 'package:city_courierapp/services/maps/photon_geocoding_service.dart';
import 'package:city_courierapp/services/maps/location_repository.dart';
import 'package:city_courierapp/screens/maps/location_picker_screen.dart';

void main() {
  group('PhotonGeocodingService Tests', () {
    test('searchAddress constructs URL with proximity bias (lat/lon) and parses GeoJSON', () async {
      Uri? requestedUri;
      Map<String, String>? requestedHeaders;

      final mockClient = MockClient((request) async {
        requestedUri = request.url;
        requestedHeaders = request.headers;

        final mockResponse = {
          'type': 'FeatureCollection',
          'features': [
            {
              'type': 'Feature',
              'geometry': {
                'type': 'Point',
                'coordinates': [112.7900, -7.2780],
              },
              'properties': {
                'osm_id': 1234567,
                'osm_type': 'W',
                'osm_key': 'highway',
                'osm_value': 'residential',
                'name': 'Jl. Semolowaru',
                'street': 'Jl. Semolowaru',
                'housenumber': '25',
                'locality': 'Semolowaru',
                'district': 'Sukolilo',
                'city': 'Surabaya',
                'state': 'Jawa Timur',
                'postcode': '60119',
                'country': 'Indonesia',
              },
            },
          ],
        };

        return http.Response(jsonEncode(mockResponse), 200, headers: {
          'content-type': 'application/json; charset=utf-8',
        });
      });

      final service = PhotonGeocodingService(client: mockClient);
      final results = await service.searchAddress(
        'Semolowaru',
        latitude: -7.2780,
        longitude: 112.7900,
        limit: 5,
      );

      // Verify query params
      expect(requestedUri, isNotNull);
      expect(requestedUri!.queryParameters['q'], 'Semolowaru');
      expect(requestedUri!.queryParameters['lat'], '-7.278');
      expect(requestedUri!.queryParameters['lon'], '112.79');
      expect(requestedUri!.queryParameters['limit'], '5');
      expect(requestedUri!.queryParameters['lang'], 'id');
      expect(requestedHeaders?['user-agent']?.contains('CityCourierApp'), isTrue);

      // Verify mapped Address
      expect(results.length, 1);
      final addr = results.first;
      expect(addr.latitude, -7.2780);
      expect(addr.longitude, 112.7900);
      expect(addr.streetName, 'Jl. Semolowaru');
      expect(addr.houseNumber, '25');
      expect(addr.village, 'Semolowaru');
      expect(addr.district, 'Sukolilo');
      expect(addr.city, 'Surabaya');
      expect(addr.province, 'Jawa Timur');
      expect(addr.postalCode, '60119');
      expect(addr.formattedAddress, contains('Jl. Semolowaru No. 25'));
    });

    test('searchAddress does not fabricate house numbers if missing', () async {
      final mockClient = MockClient((request) async {
        final mockResponse = {
          'type': 'FeatureCollection',
          'features': [
            {
              'type': 'Feature',
              'geometry': {
                'type': 'Point',
                'coordinates': [112.7521, -7.2575],
              },
              'properties': {
                'osm_id': 9876543,
                'name': 'Wisma Waru Indah',
                'street': 'Jl. Garuda',
                'district': 'Waru',
                'city': 'Sidoarjo',
                'state': 'Jawa Timur',
                'country': 'Indonesia',
              },
            },
          ],
        };

        return http.Response(jsonEncode(mockResponse), 200);
      });

      final service = PhotonGeocodingService(client: mockClient);
      final results = await service.searchAddress('Wisma Waru');

      expect(results.length, 1);
      final addr = results.first;
      expect(addr.houseNumber, isNull);
      expect(addr.formattedAddress, isNot(contains('No.')));
      expect(addr.formattedAddress, contains('Wisma Waru Indah'));
      expect(addr.district, 'Waru');
      expect(addr.city, 'Sidoarjo');
    });

    test('reverseGeocode parses coordinates to structured Address', () async {
      final mockClient = MockClient((request) async {
        final mockResponse = {
          'type': 'FeatureCollection',
          'features': [
            {
              'type': 'Feature',
              'geometry': {
                'type': 'Point',
                'coordinates': [112.7521, -7.2575],
              },
              'properties': {
                'name': 'Monumen Kapal Selam',
                'street': 'Jl. Pemuda',
                'housenumber': '39',
                'district': 'Genteng',
                'city': 'Surabaya',
                'state': 'Jawa Timur',
                'country': 'Indonesia',
              },
            },
          ],
        };

        return http.Response(jsonEncode(mockResponse), 200);
      });

      final service = PhotonGeocodingService(client: mockClient);
      final address = await service.reverseGeocode(-7.2575, 112.7521);

      expect(address, isNotNull);
      expect(address!.streetName, 'Jl. Pemuda');
      expect(address.houseNumber, '39');
      expect(address.city, 'Surabaya');
    });
  });

  group('LocationRepository Tests', () {
    test('Prioritizes Photon for autocomplete search and caches result', () async {
      int photonCalls = 0;

      final mockPhotonClient = MockClient((request) async {
        photonCalls++;
        final mockResponse = {
          'type': 'FeatureCollection',
          'features': [
            {
              'geometry': {
                'type': 'Point',
                'coordinates': [112.75, -7.25],
              },
              'properties': {
                'name': 'Tunjungan Plaza',
                'city': 'Surabaya',
              },
            },
          ],
        };
        return http.Response(jsonEncode(mockResponse), 200);
      });

      final photonService = PhotonGeocodingService(client: mockPhotonClient);
      final repository = LocationRepository(photon: photonService);

      // First query
      final results1 = await repository.searchAddress(
        'Tunjungan',
        latitude: -7.25,
        longitude: 112.75,
      );
      expect(results1.length, 1);
      expect(photonCalls, 1);

      // Second query with same cache key hits in-memory cache without hitting Photon
      final results2 = await repository.searchAddress(
        'Tunjungan',
        latitude: -7.25,
        longitude: 112.75,
      );
      expect(results2.length, 1);
      expect(photonCalls, 1); // Not incremented, cache hit!
    });
  });

  group('LocationPickerResult Tests', () {
    test('Preserves RajaOngkir matched region ID and metadata alongside Address', () {
      final baseAddress = Address(
        formattedAddress: 'Jl. Semolowaru No. 25, Sukolilo, Surabaya',
        latitude: -7.2780,
        longitude: 112.7900,
        locationSource: 'manual_pin',
      );

      final rajaOngkirData = {
        'matched': true,
        'rajaongkir_region_id': 60119,
        'rajaongkir_subdistrict_id': 5432,
        'rajaongkir_city_id': 444,
        'district_name': 'Sukolilo',
        'city_name': 'Surabaya',
        'province_name': 'Jawa Timur',
      };

      final result = LocationPickerResult(
        address: baseAddress,
        latitude: -7.2780,
        longitude: 112.7900,
        rajaOngkirMatch: rajaOngkirData,
        isRajaOngkirMatched: true,
      );

      expect(result.latitude, -7.2780);
      expect(result.longitude, 112.7900);
      expect(result.isRajaOngkirMatched, isTrue);
      expect(result.rajaOngkirMatch?['rajaongkir_subdistrict_id'], 5432);
      expect(result.rajaOngkirMatch?['rajaongkir_city_id'], 444);
    });
  });
}
