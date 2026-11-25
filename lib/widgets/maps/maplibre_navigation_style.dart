import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:maplibre/maplibre.dart' as ml;

import 'package:city_courierapp/core/config/app_colors.dart';
import 'package:city_courierapp/models/maps/traffic_models.dart';

/// Konfigurasi style vector tile & builder GeoJSON/layer 3D MapLibre untuk
/// halaman navigasi City Courier.
///
/// Sumber peta dasar menggunakan vector tiles OpenFreeMap (skema OpenMapTiles,
/// data OpenStreetMap ODbL) yang memuat geometri dan tinggi bangunan (`building`
/// dengan `render_height` dan `render_min_height`) tanpa API key rahasia.
class MapLibreNavigationStyle {
  MapLibreNavigationStyle._();

  /// URL Style JSON produksi gratis OpenFreeMap (OpenMapTiles Liberty).
  /// Mendukung komersial Android tanpa API key; atribusi wajib ditampilkan.
  static const String openFreeMapLibertyStyleUrl =
      'https://tiles.openfreemap.org/styles/liberty';

  /// Fallback style JSON ringan berbasis OSM raster bila style vektor gagal
  /// dimuat (tetap menampilkan rute & penanda navigasi dengan aman).
  static const String osmRasterFallbackStyleJson = '''
{
  "version": 8,
  "name": "City Courier OSM Fallback",
  "sources": {
    "osm-raster": {
      "type": "raster",
      "tiles": ["https://tile.openstreetmap.org/{z}/{x}/{y}.png"],
      "tileSize": 256,
      "attribution": "© OpenStreetMap contributors"
    }
  },
  "layers": [
    {
      "id": "osm-raster-layer",
      "type": "raster",
      "source": "osm-raster",
      "minzoom": 0,
      "maxzoom": 22
    }
  ]
}
''';

  static const String openMapTilesSourceId = 'openmaptiles';
  static const String buildingSourceLayerId = 'building';
  static const String defaultBuilding3dLayerId = 'building-3d';
  static const String customBuilding3dLayerId = 'city_courier_buildings_3d';
  static const String firstRoadLabelAnchorLayerId = 'highway-name-minor';

  static const String routeSourceId = 'city_courier_route_source';
  static const String routeTrafficSourceId =
      'city_courier_route_traffic_source';
  static const String trafficIncidentsSourceId =
      'city_courier_traffic_incidents_source';
  static const String selectedRoadSourceId =
      'city_courier_selected_road_source';

  static const String routeCasingLayerId = 'city_courier_route_casing';
  static const String routeLineLayerId = 'city_courier_route_line';
  static const String routeTrafficLayerId = 'city_courier_route_traffic';
  static const String trafficIncidentsLayerId =
      'city_courier_traffic_incidents';
  static const String selectedRoadCasingLayerId =
      'city_courier_selected_road_casing';
  static const String selectedRoadLineLayerId =
      'city_courier_selected_road_line';

  static const String attributionLabel =
      'OpenFreeMap © OpenMapTiles • Data © OpenStreetMap';

  static const String emptyFeatureCollectionJson =
      '{"type":"FeatureCollection","features":[]}';

  /// Layer ekstrusi bangunan 3D (`FillExtrusionStyleLayer`) berbasis data OSM.
  ///
  /// Memanfaatkan atribut `render_height`/`height`, `render_min_height`/`min_height`,
  /// serta estimasi `building:levels * 3.5m` (dan fallback visual `6.0m` bila data
  /// tinggi belum terisi di OSM) dengan palet natural agar jalan tetap fokus.
  static ml.FillExtrusionStyleLayer build3dBuildingExtrusionLayer() {
    return const ml.FillExtrusionStyleLayer(
      id: customBuilding3dLayerId,
      sourceId: openMapTilesSourceId,
      sourceLayerId: buildingSourceLayerId,
      minZoom: 14.0,
      filter: [
        '!',
        ['has', 'hide_3d'],
      ],
      paint: {
        'fill-extrusion-color': [
          'interpolate',
          ['linear'],
          ['coalesce', ['get', 'render_height'], ['get', 'height'], 8],
          0,
          '#EAE6DF',
          18,
          '#E0DDD5',
          45,
          '#D4D8DF',
          90,
          '#C7CFD9',
        ],
        'fill-extrusion-height': [
          'interpolate',
          ['linear'],
          ['zoom'],
          14.0,
          0.0,
          14.8,
          [
            'case',
            ['has', 'render_height'],
            ['get', 'render_height'],
            ['has', 'height'],
            ['get', 'height'],
            ['has', 'building:levels'],
            [
              '*',
              ['to-number', ['get', 'building:levels'], 2],
              3.5,
            ],
            6.0,
          ],
        ],
        'fill-extrusion-base': [
          'coalesce',
          ['get', 'render_min_height'],
          ['get', 'min_height'],
          0.0,
        ],
        'fill-extrusion-opacity': 0.78,
        'fill-extrusion-vertical-gradient': true,
      },
    );
  }

  /// Mendaftarkan seluruh layer bangunan 3D, rute navigasi, dan overlay
  /// lalu lintas TomTom ke [ml.StyleController] dengan urutan z-order yang tepat
  /// (bangunan 3D tidak pernah menutupi garis rute).
  static Future<bool> setupNavigationStyleLayers({
    required ml.StyleController style,
    required String routeGeoJson,
    required String routeTrafficGeoJson,
    required String incidentsGeoJson,
    required String selectedRoadGeoJson,
    bool enable3dBuildings = true,
  }) async {
    bool has3dBuildings = false;

    // 1. Ganti layer bawaan 'building-3d' dengan layer ekstrusi bertahap City Courier.
    if (enable3dBuildings) {
      for (final oldId in const [
        customBuilding3dLayerId,
        defaultBuilding3dLayerId,
      ]) {
        try {
          await style.removeLayer(oldId);
        } catch (_) {}
      }
      try {
        final extrusionLayer = build3dBuildingExtrusionLayer();
        try {
          await style.addLayer(
            extrusionLayer,
            belowLayerId: firstRoadLabelAnchorLayerId,
          );
        } catch (_) {
          await style.addLayer(extrusionLayer);
        }
        has3dBuildings = true;
      } catch (e) {
        debugPrint('MapLibre 3D building layer setup skipped: $e');
        has3dBuildings = false;
      }
    }

    // 2. Sumber GeoJSON untuk rute & TomTom Traffic (idempotent bila reload style).
    for (final layerId in const [
      routeTrafficLayerId,
      routeLineLayerId,
      routeCasingLayerId,
      trafficIncidentsLayerId,
      selectedRoadLineLayerId,
      selectedRoadCasingLayerId,
    ]) {
      try {
        await style.removeLayer(layerId);
      } catch (_) {}
    }
    for (final sourceId in const [
      routeTrafficSourceId,
      routeSourceId,
      trafficIncidentsSourceId,
      selectedRoadSourceId,
    ]) {
      try {
        await style.removeSource(sourceId);
      } catch (_) {}
    }

    await style.addSource(
      ml.GeoJsonSource(id: routeSourceId, data: routeGeoJson),
    );
    await style.addSource(
      ml.GeoJsonSource(id: routeTrafficSourceId, data: routeTrafficGeoJson),
    );
    await style.addSource(
      ml.GeoJsonSource(id: trafficIncidentsSourceId, data: incidentsGeoJson),
    );
    await style.addSource(
      ml.GeoJsonSource(id: selectedRoadSourceId, data: selectedRoadGeoJson),
    );

    // 3. Tambahkan layer garis DI ATAS layer bangunan 3D agar jalur & lalu lintas
    // selalu terlihat jelas pada kamera 3D miring.
    await style.addLayer(
      const ml.LineStyleLayer(
        id: selectedRoadCasingLayerId,
        sourceId: selectedRoadSourceId,
        layout: {'line-cap': 'round', 'line-join': 'round'},
        paint: {'line-color': '#FFFFFF', 'line-width': 11.0, 'line-opacity': 0.9},
      ),
    );
    await style.addLayer(
      const ml.LineStyleLayer(
        id: selectedRoadLineLayerId,
        sourceId: selectedRoadSourceId,
        layout: {'line-cap': 'round', 'line-join': 'round'},
        paint: {
          'line-color': ['get', 'color'],
          'line-width': 6.5,
        },
      ),
    );

    await style.addLayer(
      const ml.LineStyleLayer(
        id: trafficIncidentsLayerId,
        sourceId: trafficIncidentsSourceId,
        layout: {'line-cap': 'round', 'line-join': 'round'},
        paint: {
          'line-color': ['get', 'color'],
          'line-width': ['get', 'width'],
          'line-opacity': 0.88,
        },
      ),
    );

    await style.addLayer(
      const ml.LineStyleLayer(
        id: routeCasingLayerId,
        sourceId: routeSourceId,
        layout: {'line-cap': 'round', 'line-join': 'round'},
        paint: {
          'line-color': '#FFFFFF',
          'line-opacity': 0.92,
          'line-width': [
            'interpolate',
            ['linear'],
            ['zoom'],
            12.0,
            6.5,
            14.0,
            8.5,
            17.5,
            12.5,
            20.0,
            15.0,
          ],
        },
      ),
    );

    await style.addLayer(
      ml.LineStyleLayer(
        id: routeLineLayerId,
        sourceId: routeSourceId,
        layout: const {'line-cap': 'round', 'line-join': 'round'},
        paint: {
          'line-color': colorToHexRgb(AppColors.primaryBlue),
          'line-opacity': 0.96,
          'line-width': const [
            'interpolate',
            ['linear'],
            ['zoom'],
            12.0,
            4.0,
            14.0,
            5.5,
            17.5,
            9.0,
            20.0,
            11.0,
          ],
        },
      ),
    );

    await style.addLayer(
      const ml.LineStyleLayer(
        id: routeTrafficLayerId,
        sourceId: routeTrafficSourceId,
        layout: {'line-cap': 'round', 'line-join': 'round'},
        paint: {
          'line-color': ['get', 'color'],
          'line-opacity': 0.96,
          'line-width': [
            'interpolate',
            ['linear'],
            ['zoom'],
            12.0,
            4.0,
            14.0,
            5.5,
            17.5,
            9.0,
            20.0,
            11.0,
          ],
        },
      ),
    );

    return has3dBuildings;
  }

  /// Memperbarui data sumber GeoJSON secara aman tanpa rebuild widget peta.
  static Future<void> syncGeoJsonSources({
    required ml.StyleController style,
    required String routeGeoJson,
    required String routeTrafficGeoJson,
    required String incidentsGeoJson,
    required String selectedRoadGeoJson,
  }) async {
    await Future.wait([
      style.updateGeoJsonSource(id: routeSourceId, data: routeGeoJson),
      style.updateGeoJsonSource(
        id: routeTrafficSourceId,
        data: routeTrafficGeoJson,
      ),
      style.updateGeoJsonSource(
        id: trafficIncidentsSourceId,
        data: incidentsGeoJson,
      ),
      style.updateGeoJsonSource(
        id: selectedRoadSourceId,
        data: selectedRoadGeoJson,
      ),
    ]);
  }

  /// Membangun GeoJSON FeatureCollection untuk garis rute utama.
  static String buildRouteGeoJson(List<LatLng> coordinates) {
    if (coordinates.length < 2) return emptyFeatureCollectionJson;
    return jsonEncode({
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'properties': {'kind': 'route'},
          'geometry': {
            'type': 'LineString',
            'coordinates': [
              for (final p in coordinates) [p.longitude, p.latitude],
            ],
          },
        },
      ],
    });
  }

  /// Membangun GeoJSON FeatureCollection untuk sub-segmen TomTom Traffic pada rute
  /// aktif (kuning, oranye, merah) terurut dari kepadatan rendah ke tinggi.
  static String buildRouteTrafficGeoJson({
    required List<LatLng> coordinates,
    required List<RouteTrafficSegment> segments,
    required bool trafficEnabled,
  }) {
    if (!trafficEnabled || coordinates.length < 2 || segments.isEmpty) {
      return emptyFeatureCollectionJson;
    }

    final highlighted = segments
        .where((s) => s.shouldHighlightOnRoute)
        .toList()
      ..sort(
        (a, b) => _severityOrder(a.classification.level).compareTo(
          _severityOrder(b.classification.level),
        ),
      );

    final features = <Map<String, Object?>>[];
    final maxIdx = coordinates.length - 1;
    for (final seg in highlighted) {
      int s = seg.startIndex.clamp(0, maxIdx);
      int e = seg.endIndex.clamp(s, maxIdx);
      if (e == s) {
        if (e + 1 <= maxIdx) {
          e = e + 1;
        } else if (s > 0) {
          s = s - 1;
        } else {
          continue;
        }
      }
      final subPoints = coordinates.sublist(s, e + 1);
      if (subPoints.length < 2) continue;
      features.add({
        'type': 'Feature',
        'properties': {
          'color': colorToHexRgb(seg.routeLineColor),
          'level': seg.classification.statusKey,
        },
        'geometry': {
          'type': 'LineString',
          'coordinates': [
            for (final p in subPoints) [p.longitude, p.latitude],
          ],
        },
      });
    }

    return jsonEncode({'type': 'FeatureCollection', 'features': features});
  }

  /// Membangun GeoJSON FeatureCollection untuk koridor insiden lalu lintas.
  static String buildIncidentsGeoJson({
    required List<TrafficIncident> incidents,
    required bool trafficEnabled,
  }) {
    if (!trafficEnabled || incidents.isEmpty) return emptyFeatureCollectionJson;
    final features = <Map<String, Object?>>[];
    for (final inc in incidents) {
      if (inc.coordinates.length < 2) continue;
      features.add({
        'type': 'Feature',
        'properties': {
          'color': colorToHexRgb(inc.markerColor),
          'width': inc.category == 'road_closed' ? 7.0 : 5.5,
        },
        'geometry': {
          'type': 'LineString',
          'coordinates': [
            for (final p in inc.coordinates) [p.longitude, p.latitude],
          ],
        },
      });
    }
    return jsonEncode({'type': 'FeatureCollection', 'features': features});
  }

  /// Membangun GeoJSON FeatureCollection untuk ruas jalan yang dipilih pengguna.
  static String buildSelectedRoadGeoJson({
    required TrafficFlowSegment? selectedRoad,
    required bool trafficEnabled,
  }) {
    if (!trafficEnabled ||
        selectedRoad == null ||
        selectedRoad.coordinates.length < 2) {
      return emptyFeatureCollectionJson;
    }
    return jsonEncode({
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'properties': {
            'color': colorToHexRgb(selectedRoad.classification.color),
          },
          'geometry': {
            'type': 'LineString',
            'coordinates': [
              for (final p in selectedRoad.coordinates)
                [p.longitude, p.latitude],
            ],
          },
        },
      ],
    });
  }

  static String colorToHexRgb(Color color) {
    final rgb = color.toARGB32() & 0x00FFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  static int _severityOrder(TrafficConditionLevel level) {
    switch (level) {
      case TrafficConditionLevel.moderate:
        return 1;
      case TrafficConditionLevel.heavy:
        return 2;
      case TrafficConditionLevel.congested:
        return 3;
      case TrafficConditionLevel.roadClosed:
        return 4;
      case TrafficConditionLevel.smooth:
      case TrafficConditionLevel.unknown:
        return 0;
    }
  }
}
