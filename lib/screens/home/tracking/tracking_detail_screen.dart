import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:city_courierapp/models/shipping/tracking_model.dart';
import 'package:city_courierapp/data/models/address_model.dart';
import 'package:city_courierapp/models/shipping/route_model.dart' as shipping_route;
import 'package:city_courierapp/services/shipping/tracking_service.dart';
import 'package:city_courierapp/services/shipping/routing_service.dart';
import 'package:city_courierapp/screens/home/tracking/widgets/tracking_map_widget.dart';
import 'package:city_courierapp/core/config/map_config.dart';
import 'package:city_courierapp/core/utils/address_region.dart';
import 'package:city_courierapp/services/maps/location_repository.dart';

/// UI state untuk TrackingDetailScreen
enum TrackingViewState { initial, loading, loaded, error, notFound }

/// Halaman detail tracking: full-screen map + draggable bottom sheet.
class TrackingDetailScreen extends StatefulWidget {
  final Map<String, dynamic>? trackingData;
  final String? trackingNumber;

  const TrackingDetailScreen({
    super.key,
    this.trackingData,
    this.trackingNumber,
  });

  @override
  State<TrackingDetailScreen> createState() => _TrackingDetailScreenState();
}

class _TrackingDetailScreenState extends State<TrackingDetailScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();

  TrackingModel? _tracking;
  TrackingViewState _viewState = TrackingViewState.initial;
  String? _errorMessage;
  bool _isLoadingRoute = false;

  shipping_route.RouteModel? _route;
  Timer? _pollingTimer;

  // Bottom sheet state
  late AnimationController _sheetAnimController;
  late Animation<double> _sheetAnimation;
  bool _isSheetExpanded = false;

  String get _resi =>
      widget.trackingNumber ??
      widget.trackingData?['tracking_number'] ??
      widget.trackingData?['shipment_number'] ??
      '';

  @override
  void initState() {
    super.initState();
    _sheetAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _sheetAnimation = CurvedAnimation(
      parent: _sheetAnimController,
      curve: Curves.easeOutCubic,
    );
    _initTracking();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _sheetAnimController.dispose();
    super.dispose();
  }

  Future<void> _initTracking() async {
    if (widget.trackingData != null) {
      try {
        _tracking = TrackingModel.fromJson(widget.trackingData!);
        _viewState = TrackingViewState.loaded;
      } catch (e) {
        _viewState = TrackingViewState.error;
        _errorMessage = 'Gagal memproses data tracking.';
      }
    } else if (_resi.isNotEmpty) {
      await _fetchTracking();
    } else {
      _viewState = TrackingViewState.error;
      _errorMessage = 'Nomor resi tidak tersedia.';
    }

    if (mounted) setState(() {});

    if (_tracking != null) {
      _loadRoute();
      _startPollingIfNeeded();
    }
  }

  Future<void> _fetchTracking() async {
    setState(() => _viewState = TrackingViewState.loading);
    final result = await TrackingService.trackPackage(_resi);
    if (!mounted) return;

    if (result.type == TrackingResultType.success && result.model != null) {
      setState(() {
        _tracking = result.model;
        _viewState = TrackingViewState.loaded;
      });
    } else if (result.type == TrackingResultType.notFound) {
      setState(() => _viewState = TrackingViewState.notFound);
    } else {
      setState(() {
        _viewState = TrackingViewState.error;
        _errorMessage = result.errorMessage ?? 'Terjadi kesalahan.';
      });
    }
  }

  Future<void> _loadRoute() async {
    if (_tracking == null) return;

    // ── Geocode addresses when lat/lng are missing ──
    await _geocodeIfNeeded();

    final origin = _tracking!.origin?.latLng;
    final destination = _tracking!.destination?.latLng;

    // ignore: avoid_print
    print('DEBUG ROUTE: After geocode — origin=$origin, destination=$destination');

    if (origin == null && destination == null) {
      // ignore: avoid_print
      print('DEBUG ROUTE: Both null — skipping route load');
      return;
    }

    // If only one point is available (geocoded), skip route but still center map
    if (origin == null || destination == null) {
      // ignore: avoid_print
      print('DEBUG ROUTE: Only one point available — showing map without route');
      // Center map on the available point
      final centerPoint = origin ?? destination;
      if (centerPoint != null) {
        try {
          _mapController.move(centerPoint, 16);
        } catch (_) {}
      }
      if (mounted) setState(() => _isLoadingRoute = false);
      return;
    }

    setState(() => _isLoadingRoute = true);
    // ignore: avoid_print
    print('DEBUG ROUTE: Loading route from ${origin.latitude},${origin.longitude} to ${destination.latitude},${destination.longitude}');

    // 1. Try backend routing service first
    try {
      final route = await CityCourierRoutingService().getRoute(
        origin: origin,
        destination: destination,
      );
      // ignore: avoid_print
      print('DEBUG ROUTE: Backend route loaded — ${route.coordinates.length} points, ${route.distanceMeters}m');
      if (mounted) setState(() { _route = route; _isLoadingRoute = false; });
      return;
    } catch (e) {
      // ignore: avoid_print
      print('DEBUG ROUTE: Backend routing failed: $e — trying OSRM fallback');
    }

    // 2. Fallback: direct OSRM public API
    try {
      final route = await _getRouteFromOSRM(origin, destination);
      if (route != null) {
        // ignore: avoid_print
        print('DEBUG ROUTE: OSRM fallback route loaded — ${route.coordinates.length} points, ${route.distanceMeters}m');
        if (mounted) setState(() { _route = route; _isLoadingRoute = false; });
        return;
      }
    } catch (e) {
      // ignore: avoid_print
      print('DEBUG ROUTE: OSRM fallback also failed: $e');
    }

    // 3. Final fallback: straight-line between points
    // ignore: avoid_print
    print('DEBUG ROUTE: All routing failed — using straight-line fallback');
    if (mounted) {
      setState(() {
        _route = shipping_route.RouteModel(
          coordinates: [origin, destination],
          distanceMeters: const Distance().as(LengthUnit.Meter, origin, destination),
          durationSeconds: 0,
        );
        _isLoadingRoute = false;
      });
    }
  }

  /// Geocode origin/destination addresses when lat/lng are null
  Future<void> _geocodeIfNeeded() async {
    if (_tracking == null) return;

    final origin = _tracking!.origin;
    final destination = _tracking!.destination;

    final needsOriginGeocode = origin != null && origin.latLng == null && origin.address.isNotEmpty;
    final needsDestGeocode = destination != null && destination.latLng == null && destination.address.isNotEmpty;

    if (!needsOriginGeocode && !needsDestGeocode) return;

    // ignore: avoid_print
    print('DEBUG GEOCODE: Geocoding missing coordinates — origin needs: $needsOriginGeocode, dest needs: $needsDestGeocode');

    // Pakai LocationRepository (Backend → Nominatim → Photon) agar lebih
    // tahan banting; geocode berusaha dengan alamat lengkap, lalu mencoba
    // ulang hanya memakai wilayah (kecamatan/kota) bila gagal.
    final repo = LocationRepository();

    // Target berisi (TrackingLocation asli, String query).
    final targets = <(TrackingLocation, String)>[];
    if (needsOriginGeocode) targets.add((origin, origin.address));
    if (needsDestGeocode) targets.add((destination, destination.address));

    final isOrigin = <bool>[];
    final addresses = <TrackingLocation>[];
    if (needsOriginGeocode) { isOrigin.add(true); addresses.add(origin); }
    if (needsDestGeocode) { isOrigin.add(false); addresses.add(destination); }

    // Kumpulkan hasil koordinat per slot (index sama dengan daftar isOrigin).
    final latLngs = <(double, double)?>[];

    for (final t in targets) {
      var result = await _geocodeBestEffort(repo, t.$2);
      latLngs.add(result);
    }

    int idx = 0;
    for (final loc in addresses) {
      final coord = latLngs[idx];
      if (coord != null) {
        // ignore: avoid_print
        print('DEBUG GEOCODE: Geocoded ${isOrigin[idx] ? 'origin' : 'destination'} to ${coord.$1}, ${coord.$2}');
        if (isOrigin[idx]) {
          _tracking = _rebuildTracking(
            origin: TrackingLocation(
              address: loc.address,
              latitude: coord.$1,
              longitude: coord.$2,
            ),
          );
        } else {
          _tracking = _rebuildTracking(
            destination: TrackingLocation(
              address: loc.address,
              latitude: coord.$1,
              longitude: coord.$2,
            ),
          );
        }
      } else {
        // ignore: avoid_print
        print('DEBUG GEOCODE: Failed to geocode ${isOrigin[idx] ? 'origin' : 'destination'} address: ${loc.address}');
      }
      idx++;
    }

    if (mounted) setState(() {});

    // Re-center map on available coordinates after geocoding
    final firstPoint = _tracking?.origin?.latLng ?? _tracking?.destination?.latLng;
    if (firstPoint != null) {
      try {
        // ignore: avoid_print
        print('DEBUG GEOCODE: Centering map on ${firstPoint.latitude}, ${firstPoint.longitude}');
        _mapController.move(firstPoint, 15);
      } catch (_) {}
    }
  }

  /// Coba geocode dengan berbagai strategi bertingkat:
  /// 1. Alamat lengkap
  /// 2. Hapus duplikasi & coba lagi
  /// 3. Ambil jalan + kota saja
  /// 4. Ambil kecamatan + kota
  /// 5. Hanya kota + provinsi
  Future<(double, double)?> _geocodeBestEffort(
    LocationRepository repo,
    String address,
  ) async {
    final fullQuery = address.trim();
    
    // Strategy 1: Full address
    var results = await _searchSafe(repo, fullQuery);
    if (results.isNotEmpty) {
      return (results.first.latitude, results.first.longitude);
    }

    // Strategy 2: Remove duplicated parts at the end
    final deduped = _removeDuplicateParts(fullQuery);
    if (deduped != fullQuery) {
      // ignore: avoid_print
      print('DEBUG GEOCODE: Retrying with deduped address: $deduped');
      results = await _searchSafe(repo, deduped);
      if (results.isNotEmpty) {
        return (results.first.latitude, results.first.longitude);
      }
    }

    // Strategy 3: Extract street name + city
    final streetCity = _extractStreetAndCity(fullQuery);
    if (streetCity.isNotEmpty && streetCity != fullQuery) {
      // ignore: avoid_print
      print('DEBUG GEOCODE: Retrying with street+city: $streetCity');
      results = await _searchSafe(repo, streetCity);
      if (results.isNotEmpty) {
        return (results.first.latitude, results.first.longitude);
      }
    }

    // Strategy 4: Kecamatan + Kabupaten/Kota
    final kecKota = _extractKecamatanAndCity(fullQuery);
    if (kecKota.isNotEmpty && kecKota != fullQuery) {
      // ignore: avoid_print
      print('DEBUG GEOCODE: Retrying with kec+kota: $kecKota');
      results = await _searchSafe(repo, kecKota);
      if (results.isNotEmpty) {
        return (results.first.latitude, results.first.longitude);
      }
    }

    // Strategy 3b: Simplified street name + kabupaten
    final simplified = _simplifyAddress(fullQuery);
    if (simplified.isNotEmpty && simplified != fullQuery && simplified != streetCity) {
      // ignore: avoid_print
      print('DEBUG GEOCODE: Retrying with simplified: $simplified');
      results = await _searchSafe(repo, simplified);
      if (results.isNotEmpty) {
        return (results.first.latitude, results.first.longitude);
      }
    }

    // Strategy 4b: Street + Kecamatan + City
    final streetKecKota = _extractStreetKecKota(fullQuery);
    if (streetKecKota.isNotEmpty && streetKecKota != fullQuery) {
      // ignore: avoid_print
      print('DEBUG GEOCODE: Retrying with street+kec+kota: $streetKecKota');
      results = await _searchSafe(repo, streetKecKota);
      if (results.isNotEmpty) {
        return (results.first.latitude, results.first.longitude);
      }
    }

    // Strategy 5: City + Province only
    final region = extractRegion(fullQuery);
    if (region.isNotEmpty && region != fullQuery) {
      // ignore: avoid_print
      print('DEBUG GEOCODE: Retrying with region: $region');
      results = await _searchSafe(repo, region);
      if (results.isNotEmpty) {
        return (results.first.latitude, results.first.longitude);
      }
    }

    return null;
  }

  /// Remove duplicated and overly complex parts from an address.
  /// Also strips trailing postal codes and normalizes case for dedup.
  String _removeDuplicateParts(String address) {
    final parts = address.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final seen = <String>{};
    final unique = <String>[];
    
    for (final part in parts) {
      // Normalize: lowercase, remove extra whitespace, strip trailing numbers (postal codes)
      var lower = part.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
      // Remove trailing postal codes like '61256' or '60236'
      final stripped = lower.replaceAll(RegExp(r'\s*\d{4,6}$'), '').trim();
      final key = stripped.isNotEmpty ? stripped : lower;
      
      if (!seen.contains(key)) {
        seen.add(key);
        unique.add(part);
      }
    }
    
    return unique.join(', ');
  }

  /// Extract street name and city from address
  String _extractStreetAndCity(String address) {
    final parts = address.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    
    // Find street (usually first or second part with Jalan/Gang)
    String street = '';
    for (final part in parts) {
      if (part.toLowerCase().startsWith('jalan ') || 
          part.toLowerCase().startsWith('gang ') ||
          part.toLowerCase().startsWith('jl ') ||
          part.toLowerCase().startsWith('jl.')) {
        // Remove house numbers for simpler geocoding
        street = part.replaceAll(RegExp(r'No\.?\s*\d+.*', caseSensitive: false), '').trim();
        if (street.isEmpty) street = part;
        break;
      }
    }
    
    // Find city (Kota/Kabupaten)
    String city = '';
    for (final part in parts) {
      final lower = part.toLowerCase();
      if (lower.contains('surabaya') || lower.contains('sidoarjo') ||
          lower.contains('malang') || lower.contains('gresik') ||
          lower.contains('mojokerto') || lower.contains('lamongan') ||
          lower.contains('tuban') || lower.contains('bojonegoro')) {
        city = part.trim();
        break;
      }
    }
    
    if (street.isNotEmpty && city.isNotEmpty) {
      return '$street, $city';
    }
    return '';
  }

  /// Extract kecamatan and city
  String _extractKecamatanAndCity(String address) {
    final parts = address.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    
    String kec = '';
    String kota = '';
    
    for (final part in parts) {
      final lower = part.toLowerCase();
      if (lower.contains('kec.') || lower.contains('kecamatan')) {
        kec = part.replaceAll(RegExp(r'^Kec\.\s*', caseSensitive: false), '').trim();
      }
      if (lower.contains('surabaya') || lower.contains('sidoarjo') ||
          lower.contains('malang') || lower.contains('gresik')) {
        kota = part.trim();
      }
    }
    
    if (kec.isNotEmpty && kota.isNotEmpty) {
      return 'Kec. $kec, $kota';
    }
    return '';
  }

  /// Extract street + kecamatan + city (more specific than just street+city)
  String _extractStreetKecKota(String address) {
    final parts = address.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    
    String street = '';
    String kec = '';
    String kota = '';
    
    for (final part in parts) {
      final lower = part.toLowerCase();
      // Get street name (first part with Jalan/Gang)
      if (street.isEmpty && (lower.startsWith('jalan ') || lower.startsWith('gang ') ||
          lower.startsWith('jl ') || lower.startsWith('jl.'))) {
        // Remove house numbers and complex details
        street = part.replaceAll(RegExp(r'No\.?\s*\d+.*', caseSensitive: false), '').trim();
        if (street.isEmpty) street = part;
      }
      // Get kecamatan
      if (lower.contains('kec.') || lower.contains('kecamatan')) {
        kec = part.replaceAll(RegExp(r'^Kec\.\s*', caseSensitive: false), '').trim();
      }
      // Get kota
      if (lower.contains('surabaya') || lower.contains('sidoarjo') ||
          lower.contains('malang') || lower.contains('gresik')) {
        kota = part.trim();
      }
    }
    
    final parts2 = <String>[];
    if (street.isNotEmpty) parts2.add(street);
    if (kec.isNotEmpty) parts2.add('Kec. $kec');
    if (kota.isNotEmpty) parts2.add(kota);
    
    return parts2.join(', ');
  }

  /// Simplify address to just street name + city name.
  String _simplifyAddress(String address) {
    final parts = address.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    String street = '';
    String kota = '';
    for (final part in parts) {
      final lower = part.toLowerCase();
      if (street.isEmpty && (lower.startsWith('jalan ') || lower.startsWith('gang ') || lower.startsWith('jl '))) {
        street = part.replaceAll(RegExp(r'No\.?\s*\d+.*', caseSensitive: false), '').trim();
        if (street.isEmpty) street = part;
      }
      if (lower.contains('surabaya') || lower.contains('sidoarjo') || lower.contains('malang') || lower.contains('gresik')) {
        kota = part.trim();
      }
    }
    if (street.isNotEmpty && kota.isNotEmpty) return '$street, $kota';
    return '';
  }

  Future<List<Address>> _searchSafe(LocationRepository repo, String query) async {
    try {
      final r = await repo.searchAddress(query, minResults: 1);
      return r;
    } catch (_) {
      return const <Address>[];
    }
  }

  /// Rebuild TrackingModel with updated origin/destination
  TrackingModel _rebuildTracking({
    TrackingLocation? origin,
    TrackingLocation? destination,
  }) {
    final t = _tracking!;
    return TrackingModel(
      trackingNumber: t.trackingNumber,
      status: t.status,
      statusLabel: t.statusLabel,
      origin: origin ?? t.origin,
      destination: destination ?? t.destination,
      currentLocation: t.currentLocation,
      courier: t.courier,
      estimatedDelivery: t.estimatedDelivery,
      timeline: t.timeline,
      courierService: t.courierService,
      orderDate: t.orderDate,
      pickedUpAt: t.pickedUpAt,
      deliveredAt: t.deliveredAt,
      createdAt: t.createdAt,
    );
  }

  /// Fallback routing using OSRM public API
  Future<shipping_route.RouteModel?> _getRouteFromOSRM(LatLng origin, LatLng destination) async {
    final coords = '${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}';
    final url = Uri.parse('${MapConfig.osrmBaseUrl}/route/v1/driving/$coords').replace(
      queryParameters: {
        'overview': 'full',
        'geometries': 'geojson',
        'steps': 'false',
      },
    );

    final response = await http.get(url).timeout(MapConfig.networkTimeout);
    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body);
    if (data['code'] != 'Ok' || data['routes'] == null || (data['routes'] as List).isEmpty) {
      return null;
    }

    final routeData = data['routes'][0] as Map<String, dynamic>;
    final geometry = routeData['geometry'] as Map<String, dynamic>?;

    List<LatLng> coordinates = [];
    if (geometry != null && geometry['coordinates'] is List) {
      // GeoJSON format
      for (var coord in geometry['coordinates'] as List) {
        if (coord is List && coord.length >= 2) {
          coordinates.add(LatLng(coord[1].toDouble(), coord[0].toDouble()));
        }
      }
    }

    if (coordinates.isEmpty) return null;

    final distance = (routeData['distance'] as num?)?.toDouble() ?? 0.0;
    final duration = (routeData['duration'] as num?)?.toDouble() ?? 0.0;

    return shipping_route.RouteModel(
      coordinates: coordinates,
      distanceMeters: distance,
      durationSeconds: duration,
    );
  }

  void _startPollingIfNeeded() {
    if (_tracking == null || _tracking!.status.isTerminal) return;
    _pollingTimer = Timer.periodic(
      TrackingService.pollingInterval,
      (_) => _refreshTracking(),
    );
  }

  Future<void> _refreshTracking() async {
    if (_resi.isEmpty) return;
    final result = await TrackingService.trackPackage(_resi);
    if (!mounted) return;
    if (result.type == TrackingResultType.success && result.model != null) {
      final oldStatus = _tracking?.status;
      // Preserve geocoded lat/lng from the old model when the new
      // API response does not include coordinates (address-only).
      final merged = _mergeTrackingCoordinates(_tracking, result.model!);
      setState(() { _tracking = merged; });
      if (oldStatus != merged.status) _loadRoute();
      if (merged.status.isTerminal) _pollingTimer?.cancel();
    }
  }

  /// Merge fresh API data with previously geocoded coordinates.
  /// When the API returns address-only origin/destination (no lat/lng),
  /// keep the coordinates we already have so markers don't disappear.
  TrackingModel _mergeTrackingCoordinates(
    TrackingModel? oldModel,
    TrackingModel newModel,
  ) {
    if (oldModel == null) return newModel;

    TrackingLocation? mergeLocation(TrackingLocation? oldLoc, TrackingLocation? newLoc) {
      if (newLoc == null) return oldLoc;
      // If new data already has coordinates, use it as-is
      if (newLoc.latitude != null && newLoc.longitude != null) return newLoc;
      // Otherwise, carry over the old coordinates if the address is the same
      if (oldLoc != null &&
          oldLoc.latitude != null &&
          oldLoc.longitude != null &&
          oldLoc.address == newLoc.address) {
        return TrackingLocation(
          address: newLoc.address,
          latitude: oldLoc.latitude,
          longitude: oldLoc.longitude,
        );
      }
      return newLoc;
    }

    final mergedOrigin = mergeLocation(oldModel.origin, newModel.origin);
    final mergedDestination = mergeLocation(oldModel.destination, newModel.destination);

    return TrackingModel(
      trackingNumber: newModel.trackingNumber,
      status: newModel.status,
      statusLabel: newModel.statusLabel,
      origin: mergedOrigin,
      destination: mergedDestination,
      currentLocation: newModel.currentLocation,
      courier: newModel.courier,
      estimatedDelivery: newModel.estimatedDelivery,
      timeline: newModel.timeline,
      courierService: newModel.courierService,
      orderDate: newModel.orderDate,
      pickedUpAt: newModel.pickedUpAt,
      deliveredAt: newModel.deliveredAt,
      createdAt: newModel.createdAt,
    );
  }

  void _toggleSheet() {
    setState(() => _isSheetExpanded = !_isSheetExpanded);
    if (_isSheetExpanded) {
      _sheetAnimController.forward();
    } else {
      _sheetAnimController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFf0f3f5),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_viewState) {
      case TrackingViewState.loading:
        return _buildLoadingState();
      case TrackingViewState.error:
        return _buildErrorState();
      case TrackingViewState.notFound:
        return _buildNotFoundState();
      case TrackingViewState.loaded:
        return _tracking != null ? _buildTrackingView() : const SizedBox.shrink();
      default:
        return _buildLoadingState();
    }
  }

  // ── Loading ──
  Widget _buildLoadingState() {
    return Container(
      color: const Color(0xFFF9FAFB),
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
              ],
            ),
            child: const Column(
              children: [
                CircularProgressIndicator(color: Color(0xFFa83900)),
                SizedBox(height: 16),
                Text(
                  'Memuat data tracking...',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF271812)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Error ──
  Widget _buildErrorState() {
    return Container(
      color: const Color(0xFFF9FAFB),
      width: double.infinity,
      child: Column(
        children: [
          _buildSimpleHeader(),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(color: Color(0xFFFEE2E2), shape: BoxShape.circle),
                      child: const Icon(Icons.error_outline, size: 48, color: Color(0xFFba1a1a)),
                    ),
                    const SizedBox(height: 24),
                    const Text('Terjadi Kesalahan', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF271812))),
                    const SizedBox(height: 8),
                    Text(_errorMessage ?? 'Tidak dapat memuat data.', textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Color(0xFF575e70))),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity, height: 52,
                      child: ElevatedButton(
                        onPressed: () { _pollingTimer?.cancel(); _initTracking(); },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFa83900), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                        child: const Text('Coba Lagi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kembali', style: TextStyle(color: Color(0xFF575e70)))),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Not Found ──
  Widget _buildNotFoundState() {
    return Container(
      color: const Color(0xFFF9FAFB),
      width: double.infinity,
      child: Column(
        children: [
          _buildSimpleHeader(),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(color: Color(0xFFFFF7ED), shape: BoxShape.circle),
                      child: const Icon(Icons.inventory_2_outlined, size: 48, color: Color(0xFFa83900)),
                    ),
                    const SizedBox(height: 24),
                    const Text('Paket Tidak Ditemukan', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF271812))),
                    const SizedBox(height: 8),
                    const Text('Nomor resi yang Anda masukkan\ntidak ditemukan.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Color(0xFF575e70))),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity, height: 52,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFa83900), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                        child: const Text('Coba Lagi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleHeader() {
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 8, left: 12, right: 12, bottom: 12),
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))),
      child: Row(
        children: [
          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back), style: IconButton.styleFrom(backgroundColor: Colors.grey.shade100)),
          const SizedBox(width: 8),
          const Text('Lacak Paket', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ── Main Tracking View ──
  Widget _buildTrackingView() {
    return Stack(
      children: [
        // Full-screen map
        TrackingMapWidget(
          tracking: _tracking!,
          route: _route,
          isLoadingRoute: _isLoadingRoute,
          mapController: _mapController,
        ),

        // Gradient scrims
        Positioned(top: 0, left: 0, right: 0, height: 128, child: IgnorePointer(child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withOpacity(0.3), Colors.transparent]))))),
        Positioned(bottom: 0, left: 0, right: 0, height: 192, child: IgnorePointer(child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withOpacity(0.2), Colors.transparent]))))),

        // TopAppBar
        Positioned(
          top: 0, left: 0, right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  _buildMapCircleButton(
                    icon: Icons.arrow_back,
                    onTap: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Track Shipment',
                      style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.02,
                        color: Colors.white,
                        shadows: [Shadow(blurRadius: 4, color: Colors.black26)],
                      ),
                    ),
                  ),
                  _buildMapCircleButton(
                    icon: Icons.refresh,
                    onTap: _refreshTracking,
                  ),
                ],
              ),
            ),
          ),
        ),

        // Floating action - center map
        Positioned(
          right: 20,
          bottom: 170,
          child: _buildMapCircleButton(
            icon: Icons.my_location,
            onTap: () {
              if (_tracking?.currentLocation != null) {
                _mapController.move(_tracking!.currentLocation!, 16);
              }
            },
          ),
        ),

        // Bottom Sheet
        AnimatedBuilder(
          animation: _sheetAnimation,
          builder: (context, child) {
            return _buildBottomSheet();
          },
        ),
      ],
    );
  }

  Widget _buildMapCircleButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.8),
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8)],
        ),
        child: Icon(icon, color: const Color(0xFF271812), size: 22),
      ),
    );
  }

  Widget _buildBottomSheet() {
    final screenHeight = MediaQuery.of(context).size.height;
    final collapsedHeight = 220.0;
    final expandedHeight = screenHeight * 0.82;

    final currentHeight = _isSheetExpanded ? expandedHeight : collapsedHeight;

    return Positioned(
      left: 0, right: 0, bottom: 0,
      child: GestureDetector(
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null) {
            if (details.primaryVelocity! < -300 && !_isSheetExpanded) {
              _toggleSheet();
            } else if (details.primaryVelocity! > 300 && _isSheetExpanded) {
              _toggleSheet();
            }
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          height: currentHeight,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8F6),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 30, offset: const Offset(0, -8))],
          ),
          child: Column(
            children: [
              // Drag handle
              GestureDetector(
                onTap: _toggleSheet,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(top: 12, bottom: 4),
                  child: Center(
                    child: Container(
                      width: 48, height: 6,
                      decoration: BoxDecoration(
                        color: const Color(0xFFe4beb1),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),

              // Collapsed summary - always visible
              _buildCollapsedSummary(),

              // Expanded content - shown when expanded
              Expanded(
                child: AnimatedOpacity(
                  opacity: _isSheetExpanded ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: _isSheetExpanded
                      ? _buildExpandedContent()
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsedSummary() {
    final t = _tracking!;

    return GestureDetector(
      onTap: _toggleSheet,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          children: [
            // Status + Tracking number
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status
                      Row(
                        children: [
                          Container(
                            width: 10, height: 10,
                            decoration: BoxDecoration(
                              color: _getStatusColor(t.status),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            t.statusLabel,
                            style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700,
                              color: Color(0xFF271812),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Tracking number
                      Row(
                        children: [
                          Text(
                            t.trackingNumber,
                            style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600,
                              color: Color(0xFF5b4137),
                              letterSpacing: 0.02,
                            ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: t.trackingNumber));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Nomor resi berhasil disalin.')),
                              );
                            },
                            child: Icon(Icons.content_copy, size: 16, color: const Color(0xFFa83900)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ETA
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Tiba', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF5b4137))),
                    const SizedBox(height: 2),
                    Text(
                      t.estimatedDelivery != null ? '${t.estimatedDelivery!.hour.toString().padLeft(2, '0')}:${t.estimatedDelivery!.minute.toString().padLeft(2, '0')}' : '--:--',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFFa83900)),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Progress bar
            _buildProgressBar(t.status),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(TrackingStatus status) {
    final steps = ['Dibuat', 'Dijemput', 'Jalan', 'Tiba'];
    final activeIdx = status.progressIndex;
    final isCancelled = status == TrackingStatus.cancelled;

    // Determine active step index for progress line
    int filledSteps;
    if (isCancelled || activeIdx < 0) {
      filledSteps = 0;
    } else if (activeIdx >= 3) {
      filledSteps = 3;
    } else {
      filledSteps = activeIdx;
    }

    const primaryContainer = Color(0xFFff5a00);
    const surfaceVariant = Color(0xFFfadcd2);
    const surface = Color(0xFFFFF8F6);
    const onSurface = Color(0xFF271812);
    const outline = Color(0xFF907065);

    return SizedBox(
      height: 52,
      child: Stack(
        children: [
          // Background line
          Positioned(
            left: 24, right: 24, top: 10,
            child: Container(height: 2, color: surfaceVariant),
          ),

          // Filled line
          if (filledSteps > 0)
            Positioned(
              left: 24,
              top: 10,
              width: _calcLineWidth(context, filledSteps),
              child: Container(height: 2, color: primaryContainer),
            ),

          // Step dots
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(4, (i) {
              final isCompleted = !isCancelled && activeIdx >= 0 && i < filledSteps;
              final isCurrent = !isCancelled && activeIdx >= 0 && i == filledSteps;
              final isPending = i > filledSteps || isCancelled;

              return Column(
                children: [
                  if (isCurrent)
                    // Active step - larger with shadow
                    Container(
                      width: 24, height: 24,
                      decoration: BoxDecoration(
                        color: surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: primaryContainer, width: 4),
                        boxShadow: [BoxShadow(color: primaryContainer.withOpacity(0.3), blurRadius: 6, spreadRadius: 1)],
                      ),
                      child: Center(
                        child: Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(color: primaryContainer, shape: BoxShape.circle),
                        ),
                      ),
                    )
                  else
                    // Completed or pending
                    Container(
                      width: 16, height: 16,
                      decoration: BoxDecoration(
                        color: isCompleted ? primaryContainer : (isCancelled ? const Color(0xFFba1a1a) : surfaceVariant),
                        shape: BoxShape.circle,
                        border: Border.all(color: surface, width: 2),
                      ),
                      child: isCompleted
                          ? const Icon(Icons.check, color: Colors.white, size: 10)
                          : null,
                    ),

                  const SizedBox(height: 4),

                  Text(
                    steps[i],
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600,
                      color: isCurrent
                          ? const Color(0xFFa83900)
                          : (isPending ? outline : onSurface),
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  double _calcLineWidth(BuildContext context, int filledSteps) {
    final totalWidth = MediaQuery.of(context).size.width - 48;
    final stepWidth = totalWidth / 3;
    return stepWidth * filledSteps;
  }

  Widget _buildExpandedContent() {
    final t = _tracking!;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Divider
          Container(
            height: 1, width: double.infinity,
            color: const Color(0xFFe4beb1),
          ),

          // Courier info
          const SizedBox(height: 24),
          _buildCourierCard(t),

          // Timeline
          const SizedBox(height: 32),
          _buildTimelineSection(t),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildCourierCard(TrackingModel t) {
    const primaryContainer = Color(0xFFff5a00);
    const surfaceContainerLow = Color(0xFFfff1ec);
    const surfaceVariant = Color(0xFFfadcd2);

    final courier = t.courier;
    final hasCourier = courier != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: surfaceVariant),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 48, height: 48,
                decoration: const BoxDecoration(color: Color(0xFFd9dff5), shape: BoxShape.circle),
                child: hasCourier && courier.photo != null
                    ? ClipOval(child: Image.network(courier.photo!, width: 48, height: 48, fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, color: Color(0xFF5c6274), size: 28)))
                    : const Icon(Icons.person, color: Color(0xFF5c6274), size: 28),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Kurir Anda', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF5b4137))),
                  const SizedBox(height: 2),
                  Text(
                    hasCourier ? courier.name : 'Kurir sedang ditentukan...',
                    style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700,
                      color: hasCourier ? const Color(0xFF271812) : const Color(0xFF907065),
                      fontStyle: hasCourier ? FontStyle.normal : FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Call button
          if (hasCourier && courier.phone != null)
            GestureDetector(
              onTap: () async {
                final uri = Uri(scheme: 'tel', path: courier.phone!);
                // ignore: avoid_print
                print('Call: $uri');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: primaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.call, color: Colors.white, size: 18),
                    SizedBox(width: 6),
                    Text('Hubungi', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimelineSection(TrackingModel t) {
    const primaryContainer = Color(0xFFff5a00);
    const surfaceVariant = Color(0xFFfadcd2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Riwayat Pengiriman',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF271812)),
        ),
        const SizedBox(height: 24),

        if (t.timeline.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Belum ada riwayat pengiriman.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              ),
            ),
          )
        else
          ...List.generate(t.timeline.length, (index) {
            final item = t.timeline[index];
            final isLast = index == t.timeline.length - 1;
            final isFirst = index == 0;
            final isCurrent = isFirst || item.isCurrent;

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dot + line
                  Column(
                    children: [
                      Container(
                        width: 12, height: 12,
                        decoration: BoxDecoration(
                          color: isCurrent ? primaryContainer : surfaceVariant,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFFFF8F6), width: 3),
                          boxShadow: isCurrent ? [BoxShadow(color: primaryContainer.withOpacity(0.3), blurRadius: 4)] : null,
                        ),
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 2,
                            color: isFirst ? primaryContainer : surfaceVariant,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),

                  // Content
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Opacity(
                        opacity: isCurrent ? 1.0 : (index == 1 ? 0.75 : 0.5),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.statusLabel,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600,
                                color: const Color(0xFF271812),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatTimelineDate(item.createdAt),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF5b4137)),
                            ),
                            if (item.description != null && item.description!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFffe9e3),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  item.description!,
                                  style: const TextStyle(fontSize: 13, color: Color(0xFF5b4137)),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  String _formatTimelineDate(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
    final time = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    if (isToday) return 'Hari ini, $time';
    return '${date.day}/${date.month}/${date.year}, $time';
  }

  Color _getStatusColor(TrackingStatus status) {
    switch (status) {
      case TrackingStatus.delivered:
        return const Color(0xFF10B981);
      case TrackingStatus.cancelled:
        return const Color(0xFFba1a1a);
      default:
        return const Color(0xFF10B981); // Green dot like mockup
    }
  }
}
