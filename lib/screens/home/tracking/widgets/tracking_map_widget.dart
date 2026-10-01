import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:city_courierapp/models/shipping/tracking_model.dart';
import 'package:city_courierapp/models/shipping/route_model.dart';

/// Peta tracking: full-screen flutter_map dengan marker & route polyline.
/// Marker dan garis rute disesuaikan berdasarkan status pengiriman.
class TrackingMapWidget extends StatefulWidget {
  final TrackingModel tracking;
  final RouteModel? route;
  final bool isLoadingRoute;
  final MapController? mapController;

  const TrackingMapWidget({
    super.key,
    required this.tracking,
    this.route,
    this.isLoadingRoute = false,
    this.mapController,
  });

  @override
  State<TrackingMapWidget> createState() => _TrackingMapWidgetState();
}

class _TrackingMapWidgetState extends State<TrackingMapWidget> {
  late MapController _mapController;
  bool _hasInitialCenter = false;

  // Route colors
  static const _routeRemaining = Color(0xFF1976D2);
  static const _routeTraveled = Color(0xFF1565C0);
  static const _routeBorder = Color(0xFF0D47A1);

  /// Fase pengiriman berdasarkan status.
  /// - `pickup`: kurir sedang menuju pengirim (sebelum paket diambil)
  /// - `transit`: paket sudah diambil, kurir menuju penerima
  /// - `delivered`: paket sudah sampai
  /// - `other`: status lain (pending, cancelled, unknown)
  _ShipmentPhase get _phase {
    switch (widget.tracking.status) {
      case TrackingStatus.pending:
      case TrackingStatus.confirmed:
        return _ShipmentPhase.created;
      case TrackingStatus.assigned:
      case TrackingStatus.pickingUp:
        return _ShipmentPhase.pickup;
      case TrackingStatus.pickedUp:
      case TrackingStatus.delivering:
      case TrackingStatus.inTransit:
        return _ShipmentPhase.transit;
      case TrackingStatus.delivered:
        return _ShipmentPhase.delivered;
      case TrackingStatus.cancelled:
      case TrackingStatus.unknown:
        return _ShipmentPhase.other;
    }
  }

  @override
  void initState() {
    super.initState();
    _mapController = widget.mapController ?? MapController();
  }

  LatLng get _center {
    if (widget.tracking.origin?.latLng != null) {
      return widget.tracking.origin!.latLng!;
    }
    if (widget.tracking.destination?.latLng != null) {
      return widget.tracking.destination!.latLng!;
    }
    if (widget.tracking.currentLocation != null) {
      return widget.tracking.currentLocation!;
    }
    return const LatLng(-6.2088, 106.8456); // Jakarta fallback
  }

  @override
  void didUpdateWidget(covariant TrackingMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    final originChanged = oldWidget.tracking.origin?.latLng != widget.tracking.origin?.latLng;
    final destChanged = oldWidget.tracking.destination?.latLng != widget.tracking.destination?.latLng;
    final courierChanged = oldWidget.tracking.currentLocation != widget.tracking.currentLocation;
    final routeJustLoaded = oldWidget.route == null && widget.route != null;
    final statusChanged = oldWidget.tracking.status != widget.tracking.status;

    if (originChanged || destChanged || courierChanged || routeJustLoaded || statusChanged) {
      // Use addPostFrameCallback to ensure the map has been built before moving
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fitAllPoints();
      });
    }
  }

  void _fitAllPoints() {
    final points = <LatLng>[];

    // Only include points relevant to current phase
    if (widget.tracking.origin?.latLng != null) points.add(widget.tracking.origin!.latLng!);
    if (widget.tracking.currentLocation != null) points.add(widget.tracking.currentLocation!);
    if (widget.tracking.destination?.latLng != null) points.add(widget.tracking.destination!.latLng!);

    if (points.isEmpty) return;

    if (points.length == 1) {
      _mapController.move(points.first, 16);
    } else {
      final bounds = LatLngBounds.fromPoints(points);
      try {
        _mapController.fitCamera(
          CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60)),
        );
      } catch (_) {
        _mapController.move(bounds.center, 14);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // NO ValueKey — FlutterMap stays alive and markers persist.
    // Camera is moved via MapController in didUpdateWidget.
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _center,
        initialZoom: 16,
        // When the map first loads, center it properly
        onMapReady: () {
          if (!_hasInitialCenter) {
            _hasInitialCenter = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _fitAllPoints();
            });
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.citycourier.app',
        ),
        _buildPolylineLayer(),
        MarkerLayer(markers: _buildMarkers()),
      ],
    );
  }

  // ── Route Polyline ──
  Widget _buildPolylineLayer() {
    final courier = widget.tracking.currentLocation;
    final origin = widget.tracking.origin?.latLng;
    final destination = widget.tracking.destination?.latLng;

    // Determine the two endpoints for the line based on phase
    LatLng? lineStart;
    LatLng? lineEnd;

    switch (_phase) {
      case _ShipmentPhase.created:
        // Before courier assigned: no line needed (or optional: origin → destination overview)
        // Show light overview line from origin to destination if available
        if (origin != null && destination != null) {
          return PolylineLayer(
            polylines: [
              Polyline(
                points: [origin, destination],
                color: _routeRemaining.withOpacity(0.3),
                strokeWidth: 3,
              ),
            ],
          );
        }
        return const SizedBox.shrink();

      case _ShipmentPhase.pickup:
        // Courier heading to sender: line from courier → origin
        // If courier location is same as origin, offset it slightly
        if (courier != null && origin != null) {
          final dist = const Distance().as(LengthUnit.Meter, courier, origin);
          if (dist < 50) {
            // Courier is at origin location, offset slightly for visibility
            lineStart = LatLng(courier.latitude + 0.0002, courier.longitude + 0.0002);
          } else {
            lineStart = courier;
          }
        } else {
          lineStart = courier;
        }
        lineEnd = origin;
        break;

      case _ShipmentPhase.transit:
        // Courier heading to receiver: line from courier → destination
        lineStart = courier;
        lineEnd = destination;
        break;

      case _ShipmentPhase.delivered:
        // Delivered: no active line needed
        return const SizedBox.shrink();

      case _ShipmentPhase.other:
        // Fallback: show full route if available
        lineStart = origin;
        lineEnd = destination;
        break;
    }

    // If we have a loaded route and it's relevant, use it
    // BUT only during transit phase — during pickup, always use courier→origin line
    if (widget.route != null && widget.route!.coordinates.length >= 2) {
      if (_phase == _ShipmentPhase.transit) {
        return _buildRouteFromCoords(widget.route!.coordinates);
      }
    }

    // Straight-line between the two relevant points
    if (lineStart != null && lineEnd != null) {
      return PolylineLayer(
        polylines: [
          Polyline(
            points: [lineStart, lineEnd],
            color: _routeRemaining,
            strokeWidth: 5,
            borderColor: _routeBorder.withOpacity(0.5),
            borderStrokeWidth: 2,
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildRouteFromCoords(List<LatLng> coords) {
    final currentLoc = widget.tracking.currentLocation;
    List<LatLng> traveled;
    List<LatLng> remaining;

    if (currentLoc != null && coords.length >= 2) {
      int closestIndex = 0;
      double minDist = double.infinity;
      for (int i = 0; i < coords.length; i++) {
        final d = const Distance().as(LengthUnit.Meter, currentLoc, coords[i]);
        if (d < minDist) {
          minDist = d;
          closestIndex = i;
        }
      }
      traveled = coords.sublist(0, closestIndex + 1);
      remaining = coords.sublist(closestIndex);
    } else {
      traveled = [];
      remaining = coords;
    }

    return PolylineLayer(
      polylines: [
        if (traveled.length >= 2)
          Polyline(
            points: traveled,
            color: _routeTraveled.withOpacity(0.8),
            strokeWidth: 5,
            borderColor: _routeBorder.withOpacity(0.4),
            borderStrokeWidth: 2,
          ),
        if (remaining.length >= 2)
          Polyline(
            points: remaining,
            color: _routeRemaining,
            strokeWidth: 5,
            borderColor: _routeBorder.withOpacity(0.5),
            borderStrokeWidth: 2,
          ),
      ],
    );
  }

  // ── Markers ──
  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    final origin = widget.tracking.origin?.latLng;
    final destination = widget.tracking.destination?.latLng;
    final courier = widget.tracking.currentLocation;

    switch (_phase) {
      case _ShipmentPhase.created:
        // Status: Dibuat / Dikonfirmasi — hanya tampilkan Pengiriman
        if (origin != null) {
          markers.add(_buildLocationMarker(
            point: origin,
            color: const Color(0xFF388E3C),
            icon: Icons.inventory_2_rounded,
            label: 'Pengiriman',
          ));
        }
        break;

      case _ShipmentPhase.pickup:
        // Status: Kurir Ditugaskan / Sedang Menjemput — tampilkan Pengiriman + Kurir
        if (origin != null) {
          markers.add(_buildLocationMarker(
            point: origin,
            color: const Color(0xFF388E3C),
            icon: Icons.inventory_2_rounded,
            label: 'Pengiriman',
          ));
        }
        if (courier != null) {
          // If courier is at same location as origin, offset marker
          final markerPoint = (origin != null && const Distance().as(LengthUnit.Meter, courier, origin) < 50)
              ? LatLng(courier.latitude + 0.0002, courier.longitude + 0.0002)
              : courier;
          markers.add(_buildImageMarker(
            point: markerPoint,
            color: const Color(0xFF1976D2),
            assetPath: 'assets/Icon/Kurir.png',
            label: 'Kurir',
          ));
        }
        break;

      case _ShipmentPhase.transit:
        // Status: Dijalankan / Dalam Perjalanan — tampilkan Kurir + Penerima
        if (courier != null) {
          markers.add(_buildImageMarker(
            point: courier,
            color: const Color(0xFF1976D2),
            assetPath: 'assets/Icon/Kurir.png',
            label: 'Kurir',
          ));
        }
        if (destination != null) {
          markers.add(_buildLocationMarker(
            point: destination,
            color: const Color(0xFFE53935),
            icon: Icons.location_on_rounded,
            label: 'Penerima',
          ));
        }
        break;

      case _ShipmentPhase.delivered:
        // Status: Tiba — tampilkan Penerima
        if (destination != null) {
          markers.add(_buildLocationMarker(
            point: destination,
            color: const Color(0xFF388E3C),
            icon: Icons.check_circle_rounded,
            label: 'Diterima',
          ));
        }
        break;

      case _ShipmentPhase.other:
        // Status lain: tampilkan semua yang tersedia
        if (origin != null) {
          markers.add(_buildLocationMarker(
            point: origin,
            color: const Color(0xFF388E3C),
            icon: Icons.inventory_2_rounded,
            label: 'Pengiriman',
          ));
        }
        if (courier != null) {
          markers.add(_buildImageMarker(
            point: courier,
            color: const Color(0xFF1976D2),
            assetPath: 'assets/Icon/Kurir.png',
            label: 'Kurir',
          ));
        }
        if (destination != null) {
          markers.add(_buildLocationMarker(
            point: destination,
            color: const Color(0xFFE53935),
            icon: Icons.location_on_rounded,
            label: 'Penerima',
          ));
        }
        break;
    }

    return markers;
  }

  Marker _buildLocationMarker({
    required LatLng point,
    required Color color,
    required IconData icon,
    required String label,
  }) {
    return Marker(
      point: point,
      width: 120,
      height: 80,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Label above
          Positioned(
            top: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          // Circle with icon
          Positioned(
            top: 22,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Marker _buildImageMarker({
    required LatLng point,
    required Color color,
    required String assetPath,
    required String label,
  }) {
    return Marker(
      point: point,
      width: 120,
      height: 90,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Label above
          Positioned(
            top: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          // Circle with courier image
          Positioned(
            top: 22,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  assetPath,
                  fit: BoxFit.cover,
                  width: 38,
                  height: 38,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.motorcycle_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fase pengiriman untuk menentukan marker & garis rute mana yang ditampilkan.
enum _ShipmentPhase {
  /// Pesanan baru dibuat, belum ada kurir — tampilkan hanya Pengiriman.
  created,

  /// Kurir ditugaskan / sedang menjemput — tampilkan Pengiriman + Kurir.
  pickup,

  /// Paket sudah diambil, dalam perjalanan — tampilkan Kurir + Penerima.
  transit,

  /// Paket sudah sampai — tampilkan Penerima.
  delivered,

  /// Status lain (dibatalkan, tidak diketahui) — tampilkan semua.
  other,
}
