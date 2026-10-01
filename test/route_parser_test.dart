import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:city_courierapp/services/shipping/routing_service.dart';

void main() {
  final origin = const LatLng(-6.2000, 106.8500);
  final destination = const LatLng(-6.2146, 106.8451);

  group('RouteParser - Mapbox Directions v5 (format backend CityCourier)', () {
    test('memparsing respons Mapbox standar (geojson geometry)', () {
      final json = {
        'code': 'Ok',
        'routes': [
          {
            'legs': [
              {
                'summary': 'Jl. Contoh',
                'weight': 151.4,
                'duration': 150.0,
                'distance': 1200.0,
                'steps': [
                  {
                    'maneuver': {
                      'type': 'turn',
                      'modifier': 'right',
                      'instruction': 'Turn right onto Jl. Contoh',
                    },
                    'name': 'Jl. Contoh',
                    'distance': 800.0,
                    'duration': 100.0,
                  },
                  {
                    'maneuver': {
                      'type': 'arrive',
                      'instruction': 'Arrive at your destination',
                    },
                    'name': '',
                    'distance': 0.0,
                    'duration': 0.0,
                  },
                ],
              },
            ],
            'weight_name': 'routability',
            'geometry': {
              'type': 'LineString',
              'coordinates': [
                [106.8500, -6.2000],
                [106.8490, -6.2050],
                [106.8451, -6.2146],
              ],
            },
            'distance': 1200.0,
            'duration': 150.0,
          },
        ],
      };

      final route = RouteParser.parse(
        json,
        origin: origin,
        destination: destination,
      );

      expect(route.coordinates.length, 3);
      // Koordinat mapbox [lng,lat] dinormalisasi menjadi latlong.
      expect(route.coordinates.first.latitude, closeTo(-6.2000, 1e-6));
      expect(route.coordinates.first.longitude, closeTo(106.8500, 1e-6));
      expect(route.coordinates.last.latitude, closeTo(-6.2146, 1e-6));
      // distance = meter, duration = detik (tanpa heuristik salah).
      expect(route.distanceMeters, 1200.0);
      expect(route.durationSeconds, closeTo(150.0, 1e-6));
      expect(route.steps.length, 2);
      expect(route.steps.first.maneuver, 'right');
      expect(route.steps.first.instruction, 'Turn right onto Jl. Contoh');
      expect(route.steps.first.roadName, 'Jl. Contoh');
      expect(route.steps.last.maneuver, 'arrive');
    });

    test('menembus envelope {success, data} hasil MapApiController', () {
      final json = {
        'success': true,
        'data': {
          'code': 'Ok',
          'routes': [
            {
              'geometry': {
                'type': 'LineString',
                'coordinates': [
                  [106.8500, -6.2000],
                  [106.8451, -6.2146],
                ],
              },
              'distance': 1900.0,
              'duration': 300.0,
            },
          ],
        },
      };

      final route = RouteParser.parse(
        json,
        origin: origin,
        destination: destination,
      );

      expect(route.coordinates.length, 2);
      expect(route.distanceMeters, 1900.0);
      expect(route.durationSeconds, closeTo(300.0, 1e-6));
    });
  });

  group('RouteParser - toleransi provider lain', () {
    test('OSRM: overview_polyline polyline5 + distance km-ish tetap meter', () {
      final json = {
        'code': 'Ok',
        'routes': [
          {
            'overview_polyline': {
              'points':
                  // polyline5 mulai dari origin secara [lat,lng].
                  encodeForTest(),
            },
            'distance': 1900.0,
            'duration': 300.0,
            'legs': [
              {
                'steps': [
                  {
                    'maneuver': {'type': 'turn', 'modifier': 'left'},
                    'name': 'Jl. Baru',
                    'distance': 500.0,
                  },
                ],
              },
            ],
          },
        ],
      };

      final route = RouteParser.parse(
        json,
        origin: origin,
        destination: destination,
      );

      expect(route.coordinates.length, greaterThanOrEqualTo(2));
      expect(
        route.coordinates.first.latitude,
        closeTo(origin.latitude, 1e-4),
      );
      expect(route.distanceMeters, 1900.0);
      expect(route.durationSeconds, closeTo(300.0, 1e-6));
      expect(route.steps.single.maneuver, 'left');
      expect(route.steps.single.roadName, 'Jl. Baru');
    });

    test('GraphHopper: polyline5 flat + time dalam milliseconds', () {
      final json = {
        'paths': [
          {
            'points': encodeForTest(),
            'distance': 1900.0,
            'time': 300000, // ms
          },
        ],
      };

      final route = RouteParser.parse(
        json,
        origin: origin,
        destination: destination,
      );

      expect(route.distanceMeters, 1900.0);
      expect(route.durationSeconds, closeTo(300.0, 1e-6));
    });

    test('Valhalla: polyline6 (shape) di dalam trip', () {
      final json = {
        'trip': {
          'legs': [
            {
              'shape': encodeForTest(precision: 1e6),
              'summary': {'length': 1.9, 'time': 300.0},
            },
          ],
          'summary': {'text': 'Jalan Contoh'},
        },
      };

      final route = RouteParser.parse(
        json,
        origin: origin,
        destination: destination,
      );

      expect(route.coordinates.length, greaterThanOrEqualTo(2));
      expect(route.coordinates.first.latitude, closeTo(origin.latitude, 1e-5));
      expect(route.distanceMeters, closeTo(1900.0, 1.0));
      expect(route.durationSeconds, closeTo(300.0, 1e-6));
      expect(route.summary, 'Jalan Contoh');
    });
  });
}

/// Encoder minim untuk polyline Google — titik sesuai [origin] → [destination].
String encodeForTest({double precision = 1e5}) {
  final points = [
    const LatLng(-6.2000, 106.8500),
    const LatLng(-6.2070, 106.8560),
    const LatLng(-6.2146, 106.8451),
  ];
  final buffer = StringBuffer();
  int prevLat = 0;
  int prevLng = 0;

  String encodeValue(int value) {
    var v = value < 0 ? ~(value << 1) : (value << 1);
    final out = StringBuffer();
    while (v >= 0x20) {
      out.writeCharCode((0x20 | (v & 0x1f)) + 63);
      v >>= 5;
    }
    out.writeCharCode(v + 63);
    return out.toString();
  }

  for (final p in points) {
    final lat = (p.latitude * precision).round();
    final lng = (p.longitude * precision).round();
    buffer.write(encodeValue(lat - prevLat));
    buffer.write(encodeValue(lng - prevLng));
    prevLat = lat;
    prevLng = lng;
  }
  return buffer.toString();
}