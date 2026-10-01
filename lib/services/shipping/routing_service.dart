import 'package:latlong2/latlong.dart';

import 'package:city_courierapp/models/shipping/route_model.dart';
import 'package:city_courierapp/services/shipping/map_service.dart';

/// Exception ketika routing gagal atau response tidak dapat diparsing.
class RoutingException implements Exception {
  final String message;
  const RoutingException(this.message);

  @override
  String toString() => message;
}

/// Abstraksi routing engine (PRD §36) — provider dapat diganti tanpa
/// membongkar UI.
abstract class RoutingService {
  Future<RouteModel> getRoute({
    required LatLng origin,
    required LatLng destination,
    List<LatLng> waypoints = const [],
    String profile = 'motorcycle',
  });
}

/// Provider resmi CityCourier — memakai endpoint backend
/// `POST /shipping/map/routing` (lihat [MapService.getRouting]).
class CityCourierRoutingService implements RoutingService {
  @override
  Future<RouteModel> getRoute({
    required LatLng origin,
    required LatLng destination,
    List<LatLng> waypoints = const [],
    String profile = 'motorcycle',
  }) async {
    final raw = await MapService.getRouting(
      '${origin.longitude},${origin.latitude}',
      '${destination.longitude},${destination.latitude}',
      vias: waypoints
          .map((w) => '${w.longitude},${w.latitude}')
          .toList(),
    );
    if (raw == null) {
      throw const RoutingException('Tidak dapat menentukan rute');
    }
    return RouteParser.parse(raw, origin: origin, destination: destination);
  }
}

/// Parser toleran untuk response routing dari berbagai provider:
/// Google Directions, OSRM, GraphHopper, Valhalla, maupun struktur
/// flat/custom milik backend.
class RouteParser {
  RouteParser._();

  static const double _defaultSpeedMps = 6.7; // ~24 km/jam (motor)
  static const double _maxPlausibleSpeedMps = 25.0; // ~90 km/jam

  static RouteModel parse(
    dynamic json, {
    required LatLng origin,
    required LatLng destination,
  }) {
    if (json is List) {
      final coords = _fromCoordPairs(json);
      if (coords.isNotEmpty) return _buildFlat(coords, origin: origin);
      throw const RoutingException('Rute tidak tersedia. Silakan coba lagi.');
    }
    if (json is! Map) {
      throw const RoutingException('Rute tidak tersedia. Silakan coba lagi.');
    }

    final data = _unwrap(json.cast<String, dynamic>());

    final routesList = _asList(data['routes']) ?? _asList(data['paths']);
    if (routesList != null && routesList.isNotEmpty) {
      for (final r in routesList) {
        if (r is! Map) continue;
        final route = _parseRouteCandidate(
          r.cast<String, dynamic>(),
          origin: origin,
          destination: destination,
        );
        if (route != null) return route;
      }
    }

    final trip = data['trip'];
    if (trip is Map) {
      final route = _parseValhalla(
        trip.cast<String, dynamic>(),
        origin: origin,
      );
      if (route != null) return route;
    }

    final flat = _parseRouteCandidate(
      data,
      origin: origin,
      destination: destination,
    );
    if (flat != null) return flat;

    // Beberapa backend membungkus lagi seperti { route: {...} }.
    for (final key in const ['route', 'result', 'path']) {
      final nested = data[key];
      if (nested is Map) {
        final route = _parseRouteCandidate(
          nested.cast<String, dynamic>(),
          origin: origin,
          destination: destination,
        );
        if (route != null) return route;
      }
    }

    throw const RoutingException('Rute tidak tersedia. Silakan coba lagi.');
  }

  /// Menghapus wrapper berulang `data`/`result` jika objek tersebut hanya
  /// membungkus payload lain.
  static Map<String, dynamic> _unwrap(Map<String, dynamic> m) {
    var d = m;
    var guard = 0;
    while (guard++ < 5) {
      final data = d['data'];
      if (data is Map &&
          (d.length == 1 ||
              (d.length <= 3 &&
                  (d.containsKey('success') || d.containsKey('message'))))) {
        d = data.cast<String, dynamic>();
        continue;
      }
      if (d.containsKey('result') &&
          d['result'] is Map &&
          (d.length == 1 || !d.keys.any(_isPayloadKey))) {
        d = (d['result'] as Map).cast<String, dynamic>();
        continue;
      }
      break;
    }
    return d;
  }

  static bool _isPayloadKey(String k) =>
      const {'routes', 'paths', 'trip', 'route', 'geometry', 'coordinates'}
          .contains(k);

  static RouteModel _buildFlat(
    List<LatLng> coords, {
    required LatLng origin,
  }) {
    var c = _normalizeOrder(coords, origin: origin);
    final dist = _geomLength(c);
    return RouteModel(
      coordinates: c,
      distanceMeters: dist,
      durationSeconds: dist / _defaultSpeedMps,
    );
  }

  static RouteModel? _parseRouteCandidate(
    Map<String, dynamic> r, {
    required LatLng origin,
    required LatLng destination,
  }) {
    final coordsRaw = _readCoordinates(r);
    if (coordsRaw == null || coordsRaw.isEmpty) return null;
    var coords = _normalizeOrder(coordsRaw, origin: origin);

    final geomLen = _geomLength(coords);

    var dist = _anyNumber(r['distance']) ??
        _nestedNumber(r['distance']) ??
        _anyNumber(r['distance_m']) ??
        _anyNumber(r['distance_km']);

    final distKm = _anyNumber(r['distance_km']);
    if (distKm != null) dist = distKm * 1000;

    var dur = _anyNumber(r['duration']) ??
        _nestedNumber(r['duration']) ??
        _anyNumber(r['duration_s']) ??
        _anyNumber(r['duration_seconds']);
    final durMin = _anyNumber(r['duration_minutes']) ??
        _anyNumber(r['duration_min']) ??
        _anyNumber(r['duration_min_rounded']);
    final timeMs = _anyNumber(r['time']) ??
        _nestedNumber(r['time']); // GraphHopper: time dalam milidetik
    if (dur == null && timeMs != null) dur = timeMs / 1000.0;

    // legs (Google Directions / OSRM)
    double legDist = 0;
    double legDur = 0;
    double legTrafficDur = 0;
    final legs = _asList(r['legs']);
    if (legs != null) {
      for (final leg in legs) {
        if (leg is! Map) continue;
        legDist += _anyNumber(leg['distance']) ??
            _nestedNumber(leg['distance']) ??
            0;
        legDur +=
            _anyNumber(leg['duration']) ?? _nestedNumber(leg['duration']) ?? 0;
        legTrafficDur += _anyNumber(leg['traffic_duration']) ??
            _nestedNumber(leg['traffic_duration']) ??
            0;
      }
    }
    if (legDist > 0) dist = legDist;
    if (legDur > 0) dur = legDur;

    // Heuristik satuan jarak: jika nilai jauh lebih kecil dari panjang
    // geometry, kemungkinan dalam kilometer.
    if (dist != null && dist > 0 && geomLen > 0 && dist < geomLen * 0.5) {
      dist = dist * 1000;
    }
    if (dist == null || dist <= 0) {
      dist = geomLen > 0 ? geomLen : 0;
    }

    if (durMin != null && (dur == null || dur <= 1)) dur = durMin * 60;

    // Heuristik satuan durasi: kecepatan mustahil (>25 m/s) berarti menit.
    if (dist > 0 && dur != null && dur > 0) {
      final speedMps = dist / dur;
      if (speedMps > _maxPlausibleSpeedMps) dur = dur * 60;
    }

    if (dur == null || dur <= 0) {
      dur = dist / _defaultSpeedMps;
    }

    final traffic = _anyNumber(r['traffic_duration']) ??
        _nestedNumber(r['traffic_duration']) ??
        (legTrafficDur > 0 ? legTrafficDur : null);

    final summaryRaw = r['summary'];
    String? summary;
    if (summaryRaw is String && summaryRaw.isNotEmpty) {
      summary = summaryRaw;
    } else if (summaryRaw is Map) {
      final text = summaryRaw['text'];
      final key = summaryRaw['key'];
      if (text is String && text.isNotEmpty) summary = text;
      if (key is String && key.isNotEmpty) summary = key;
    }

    final steps = _parseSteps(r);

    return RouteModel(
      coordinates: coords,
      distanceMeters: dist,
      durationSeconds: dur.roundToDouble(),
      trafficDurationSeconds: traffic,
      summary: summary,
      steps: steps,
    );
  }

  static List<LatLng>? _readCoordinates(Map<String, dynamic> m) {
    final geom = m['geometry'];
    if (geom is Map && geom['coordinates'] is List) {
      return _fromCoordPairs(geom['coordinates'] as List);
    }
    if (geom is String) return decodePolyline(geom, precisionFactor: 1e5);
    if (geom is List) return _fromCoordPairs(geom);

    final ovp = m['overview_polyline'];
    if (ovp is Map && ovp['points'] is String) {
      return decodePolyline(ovp['points'] as String, precisionFactor: 1e5);
    }

    final points = m['points'];
    if (points is String) return decodePolyline(points, precisionFactor: 1e5);
    if (points is Map && points['coordinates'] is List) {
      return _fromCoordPairs(points['coordinates'] as List);
    }
    if (points is List) return _fromCoordPairs(points);

    if (m['shape'] is String) {
      return decodePolyline(m['shape'] as String, precisionFactor: 1e6);
    }

    if (m['coordinates'] is List) return _fromCoordPairs(m['coordinates'] as List);
    if (m['polyline'] is String) {
      return decodePolyline(m['polyline'] as String, precisionFactor: 1e5);
    }
    if (m['polyline'] is List) return _fromCoordPairs(m['polyline'] as List);
    if (m['route'] is String) {
      return decodePolyline(m['route'] as String, precisionFactor: 1e5);
    }
    if (m['route'] is List) return _fromCoordPairs(m['route'] as List);
    if (m['path'] is List) return _fromCoordPairs(m['path'] as List);
    return null;
  }

  static List<LatLng> _fromCoordPairs(List raw) {
    final out = <LatLng>[];
    for (final item in raw) {
      if (item is List && item.length >= 2) {
        final a = _anyNumber(item[0]);
        final b = _anyNumber(item[1]);
        if (a != null && b != null) out.add(LatLng(a, b));
      } else if (item is Map) {
        final lat = _anyNumber(item['lat']) ?? _anyNumber(item['latitude']);
        final lng = _anyNumber(item['lng']) ??
            _anyNumber(item['lon']) ??
            _anyNumber(item['longitude']);
        if (lat != null && lng != null) out.add(LatLng(lat, lng));
      }
    }
    return out;
  }

  /// Menormalkan urutan koordinat. Sebagian provider mengembalikan [lng, lat],
  /// sebagian lagi [lat, lng]. Dibandingkan dengan titik origin.
  static List<LatLng> _normalizeOrder(
    List<LatLng> coords, {
    required LatLng origin,
  }) {
    if (coords.isEmpty) return coords;
    final d = const Distance();
    final asIs = d.as(LengthUnit.Meter, origin, coords.first);
    final swapped = d.as(
      LengthUnit.Meter,
      origin,
      LatLng(coords.first.longitude, coords.first.latitude),
    );
    if (swapped < asIs * 0.5) {
      return coords.map((c) => LatLng(c.longitude, c.latitude)).toList();
    }
    return coords;
  }

  static double _geomLength(List<LatLng> pts) {
    if (pts.length < 2) return 0;
    final d = const Distance();
    double sum = 0;
    for (var i = 0; i < pts.length - 1; i++) {
      sum += d.as(LengthUnit.Meter, pts[i], pts[i + 1]);
    }
    return sum;
  }

  static List<RouteStep> _parseSteps(Map<String, dynamic> m) {
    final steps = <RouteStep>[];
    final legs = _asList(m['legs']);
    if (legs != null && legs.isNotEmpty) {
      for (final leg in legs) {
        if (leg is! Map) continue;
        final stepList = _asList(leg['steps']);
        if (stepList == null) continue;
        for (final s in stepList) {
          if (s is! Map) continue;
          final step = _parseStep(s as Map<String, dynamic>);
          if (step != null) steps.add(step);
        }
      }
    }
    if (steps.isEmpty) {
      final instructions = _asList(m['instructions']);
      if (instructions != null) {
        for (final s in instructions) {
          if (s is! Map) continue;
          final step = _parseStep(s as Map<String, dynamic>);
          if (step != null) steps.add(step);
        }
      }
    }
    return steps;
  }

  static RouteStep? _parseStep(Map<String, dynamic> s) {
    final dist = _anyNumber(s['distance']) ??
        _nestedNumber(s['distance']) ??
        0.0;

    double dur = 0;
    final hasTimeOnly = s.containsKey('time') && !s.containsKey('duration');
    final durRaw = _anyNumber(s['duration']) ??
        _nestedNumber(s['duration']) ??
        _anyNumber(s['time']);
    if (durRaw != null) {
      dur = hasTimeOnly ? durRaw / 1000.0 : durRaw;
    }

    String? type;
    String? modifier;
    String? instruction;
    final mvr = s['maneuver'];
    if (mvr is String) {
      type = mvr;
    } else if (mvr is Map) {
      type = mvr['type'] as String?;
      modifier = mvr['modifier'] as String?;
      final ins = mvr['instruction'];
      if (ins is String) instruction = ins;
    }
    String? signType;
    if (s['sign'] is num) {
      signType = _graphHopperSignLabel((s['sign'] as num).toInt());
    }

    final streetNames = _asList(s['street_names']);
    String roadName = '';
    if (s['name'] is String && (s['name'] as String).isNotEmpty) {
      roadName = s['name'] as String;
    } else if (s['street_name'] is String) {
      roadName = s['street_name'] as String;
    } else if (streetNames != null && streetNames.isNotEmpty) {
      final first = streetNames.first;
      if (first is String && first.isNotEmpty) roadName = first;
    }

    var text = s['html_instructions'];
    if (text is String) {
      text = text.replaceAll(RegExp(r'<[^>]*>'), '').replaceAll('&nbsp;', ' ');
      text = text.trim();
    }

    final fallback = _buildInstruction(
      type ?? signType,
      modifier,
      roadName,
    );
    if (text == null || text.isEmpty) text = instruction;
    if (text == null || text.isEmpty) text = fallback;
    if (text == null || text.isEmpty) return null;

    return RouteStep(
      instruction: text,
      maneuver: modifier ?? signType ?? type,
      roadName: roadName.isEmpty ? null : roadName,
      distanceMeters: dist,
      durationSeconds: dur,
    );
  }

  static String _graphHopperSignLabel(int sign) {
    switch (sign) {
      case -8:
        return 'uturn';
      case -3:
        return 'turn-sharp-right';
      case -2:
        return 'turn-right';
      case -1:
        return 'turn-slight-right';
      case 0:
        return 'continue';
      case 1:
        return 'turn-slight-left';
      case 2:
        return 'turn-left';
      case 3:
        return 'turn-sharp-left';
      case 4:
        return 'arrive';
      case 5:
        return 'via';
      case 6:
        return 'roundabout';
      default:
        return '';
    }
  }

  static String _buildInstruction(
    String? type,
    String? modifier,
    String roadName,
  ) {
    final roadPart =
        roadName.isEmpty ? '' : '${type == 'arrive' ? 'Di lokasi ' : 'ke '}$roadName';
    switch (type) {
      case 'depart':
        return 'Mulai perjalanan';
      case 'arrive':
        return 'Tiba$roadPart';
      case 'turn':
        if (modifier != null) {
          return 'Belok ${_modifierLabel(modifier)}$roadPart';
        }
        return 'Belok$roadPart';
      case 'turn-right':
        return 'Belok kanan$roadPart';
      case 'turn-left':
        return 'Belok kiri$roadPart';
      case 'turn-sharp-right':
        return 'Belok tajam ke kanan$roadPart';
      case 'turn-sharp-left':
        return 'Belok tajam ke kiri$roadPart';
      case 'turn-slight-right':
        return 'Belok perlahan ke kanan$roadPart';
      case 'turn-slight-left':
        return 'Belok perlahan ke kiri$roadPart';
      case 'uturn':
        return 'Putar balik$roadPart';
      case 'continue':
        return 'Tetap di jalan$roadPart';
      case 'merge':
        return 'Gabung$roadPart';
      case 'roundabout':
        return 'Masuk bundaran$roadPart';
      case 'exit-roundabout':
        return 'Keluar dari bundaran$roadPart';
      case 'fork':
        return 'Ikuti arah$roadPart';
      case 'end-of-road':
        return 'Ikuti jalan$roadPart';
      default:
        return 'Lanjutkan perjalanan$roadPart';
    }
  }

  static String _modifierLabel(String modifier) {
    switch (modifier) {
      case 'right':
        return 'kanan';
      case 'left':
        return 'kiri';
      case 'straight':
        return 'lurus';
      case 'slight-right':
        return 'perlahan ke kanan';
      case 'slight-left':
        return 'perlahan ke kiri';
      case 'sharp-right':
        return 'tajam ke kanan';
      case 'sharp-left':
        return 'tajam ke kiri';
      default:
        return modifier;
    }
  }

  static RouteModel? _parseValhalla(
    Map<String, dynamic> trip, {
    required LatLng origin,
  }) {
    final legs = _asList(trip['legs']);
    if (legs == null || legs.isEmpty) return null;

    final coords = <LatLng>[];
    final steps = <RouteStep>[];
    double distKm = 0;
    double durS = 0;

    for (final leg in legs) {
      if (leg is! Map) continue;
      final shape = leg['shape'];
      if (shape is String && shape.isNotEmpty) {
        final legCoords = decodePolyline(shape, precisionFactor: 1e6);
        if (coords.isEmpty) {
          coords.addAll(legCoords);
        } else if (legCoords.isNotEmpty) {
          final last = coords.last;
          final first = legCoords.first;
          final duplicatesJoin =
              last.latitude == first.latitude && last.longitude == first.longitude;
          coords.addAll(duplicatesJoin ? legCoords.skip(1) : legCoords);
        }
      }

      final summary = leg['summary'];
      if (summary is Map) {
        distKm += _anyNumber(summary['length']) ?? 0;
        durS += _anyNumber(summary['time']) ?? 0;
      }

      final maneuvers = _asList(leg['maneuvers']);
      for (final mv in maneuvers ?? const []) {
        if (mv is! Map) continue;
        final streetNames = _asList(mv['street_names']);
        String? roadName;
        if (streetNames != null && streetNames.isNotEmpty) {
          final first = streetNames.first;
          if (first is String) roadName = first;
        }
        final ins = mv['instruction'];
        if (ins is String && ins.isNotEmpty) {
          steps.add(RouteStep(
            instruction: ins,
            maneuver: _valhallaTypeLabel(mv['type']),
            roadName: roadName,
            distanceMeters: (_anyNumber(mv['length']) ?? 0) * 1000,
            durationSeconds: _anyNumber(mv['time']) ?? 0,
          ));
        }
      }
    }

    if (coords.isEmpty) return null;
    var c = _normalizeOrder(coords, origin: origin);
    final geomLen = _geomLength(c);
    var dist = distKm * 1000;
    if (dist <= 0) dist = geomLen;
    if (durS <= 0) durS = dist / _defaultSpeedMps;

    String? summaryText;
    final summary = trip['summary'];
    if (summary is Map) {
      final t = summary['text'];
      if (t is String && t.isNotEmpty) summaryText = t;
    }

    return RouteModel(
      coordinates: c,
      distanceMeters: dist,
      durationSeconds: durS.roundToDouble(),
      trafficDurationSeconds: null,
      summary: summaryText,
      steps: steps,
    );
  }

  static String? _valhallaTypeLabel(dynamic type) {
    if (type is! num) return null;
    switch (type.toInt()) {
      case 1:
      case 2:
      case 3:
        return 'depart';
      case 4:
      case 5:
      case 6:
        return 'arrive';
      case 8:
        return 'continue';
      case 9:
        return 'merge';
      case 10:
        return 'ferry';
      case 11:
      case 13:
        return 'roundabout';
      case 12:
        return 'exit-roundabout';
      default:
        return null;
    }
  }

  /// Decode **encoded polyline** (algoritma Google).
  ///
  /// - Google/OSRM/GraphHopper menggunakan faktor 1e5 (polyline5).
  /// - Valhalla menggunakan faktor 1e6 (polyline6).
  static List<LatLng> decodePolyline(
    String encoded, {
    double precisionFactor = 1e5,
  }) {
    final poly = <LatLng>[];
    int index = 0;
    final len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int result = 0;
      int shift = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      poly.add(LatLng(lat / precisionFactor, lng / precisionFactor));
    }
    return poly;
  }

  static List<dynamic>? _asList(dynamic v) => v is List ? v : null;

  static double? _anyNumber(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static double? _nestedNumber(dynamic v) {
    if (v is Map && v['value'] != null) return _anyNumber(v['value']);
    return null;
  }
}