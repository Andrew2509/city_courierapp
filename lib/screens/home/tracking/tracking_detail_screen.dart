import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
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

/// Halaman Live Delivery Tracking City Courier:
/// Desain berbasis kartu sesuai panduan visual modern City Courier.
class TrackingDetailScreen extends StatefulWidget {
  final Map<String, dynamic>? trackingData;
  final String? trackingNumber;
  final Map<String, dynamic>? shipmentData;

  const TrackingDetailScreen({
    super.key,
    this.trackingData,
    this.trackingNumber,
    this.shipmentData,
  });

  @override
  State<TrackingDetailScreen> createState() => _TrackingDetailScreenState();
}

class _TrackingDetailScreenState extends State<TrackingDetailScreen> {
  final MapController _mapController = MapController();

  TrackingModel? _tracking;
  TrackingViewState _viewState = TrackingViewState.initial;
  String? _errorMessage;
  bool _isLoadingRoute = false;

  shipping_route.RouteModel? _route;
  Timer? _pollingTimer;
  String _lastUpdatedTime = '';

  String get _resi =>
      widget.trackingNumber ??
      widget.trackingData?['tracking_number'] ??
      widget.trackingData?['shipment_number'] ??
      widget.shipmentData?['tracking_number'] ??
      widget.shipmentData?['shipment_number'] ??
      '';

  @override
  void initState() {
    super.initState();
    _lastUpdatedTime = DateFormat('h:mm:ss a').format(DateTime.now());
    _initTracking();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
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
        _lastUpdatedTime = DateFormat('h:mm:ss a').format(DateTime.now());
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

  void _startPollingIfNeeded() {
    if (_tracking == null || _tracking!.status.isTerminal) return;
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) => _pollUpdate());
  }

  Future<void> _pollUpdate() async {
    if (!mounted || _resi.isEmpty) return;
    final result = await TrackingService.trackPackage(_resi);
    if (!mounted) return;
    if (result.type == TrackingResultType.success && result.model != null) {
      final oldStatus = _tracking?.status;
      final merged = _mergeTrackingCoordinates(_tracking, result.model!);
      setState(() {
        _tracking = merged;
        _lastUpdatedTime = DateFormat('h:mm:ss a').format(DateTime.now());
      });
      if (oldStatus != merged.status) _loadRoute();
      if (merged.status.isTerminal) _pollingTimer?.cancel();
    }
  }

  TrackingModel _mergeTrackingCoordinates(
    TrackingModel? oldModel,
    TrackingModel newModel,
  ) {
    if (oldModel == null) return newModel;

    TrackingLocation? mergeLocation(TrackingLocation? oldLoc, TrackingLocation? newLoc) {
      if (newLoc == null) return oldLoc;
      if (newLoc.latitude != null && newLoc.longitude != null) return newLoc;
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
      senderName: newModel.senderName ?? oldModel.senderName,
      senderPhone: newModel.senderPhone ?? oldModel.senderPhone,
      receiverName: newModel.receiverName ?? oldModel.receiverName,
      receiverPhone: newModel.receiverPhone ?? oldModel.receiverPhone,
      vehicle: newModel.vehicle ?? oldModel.vehicle,
      packageWeight: newModel.packageWeight ?? oldModel.packageWeight,
      paymentMethod: newModel.paymentMethod ?? oldModel.paymentMethod,
      totalCost: newModel.totalCost ?? oldModel.totalCost,
      scheduleText: newModel.scheduleText ?? oldModel.scheduleText,
      qrCodeUrl: newModel.qrCodeUrl ?? oldModel.qrCodeUrl,
      rawJson: newModel.rawJson ?? oldModel.rawJson,
    );
  }

  Future<void> _loadRoute() async {
    if (_tracking == null) return;
    await _geocodeIfNeeded();

    final origin = _tracking!.origin?.latLng;
    final destination = _tracking!.destination?.latLng;

    if (origin == null && destination == null) return;
    if (origin == null || destination == null) {
      final centerPoint = origin ?? destination;
      if (centerPoint != null) {
        try {
          _mapController.move(centerPoint, 15);
        } catch (_) {}
      }
      return;
    }

    setState(() => _isLoadingRoute = true);

    try {
      final route = await CityCourierRoutingService().getRoute(
        origin: origin,
        destination: destination,
      );
      if (mounted) setState(() { _route = route; _isLoadingRoute = false; });
      return;
    } catch (_) {}

    try {
      final route = await _getRouteFromOSRM(origin, destination);
      if (route != null && mounted) {
        setState(() { _route = route; _isLoadingRoute = false; });
        return;
      }
    } catch (_) {}

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

  Future<void> _geocodeIfNeeded() async {
    if (_tracking == null) return;
    final origin = _tracking!.origin;
    final destination = _tracking!.destination;

    final needsOrigin = origin != null && origin.latLng == null && origin.address.isNotEmpty;
    final needsDest = destination != null && destination.latLng == null && destination.address.isNotEmpty;

    if (!needsOrigin && !needsDest) return;

    final repo = LocationRepository();
    final targets = <(TrackingLocation, String)>[];
    if (needsOrigin) targets.add((origin, origin.address));
    if (needsDest) targets.add((destination, destination.address));

    final isOrigin = <bool>[];
    final addresses = <TrackingLocation>[];
    if (needsOrigin) { isOrigin.add(true); addresses.add(origin); }
    if (needsDest) { isOrigin.add(false); addresses.add(destination); }

    final latLngs = <(double, double)?>[];
    for (final t in targets) {
      final res = await _geocodeBestEffort(repo, t.$2);
      latLngs.add(res);
    }

    int idx = 0;
    for (final loc in addresses) {
      final coord = latLngs[idx];
      if (coord != null) {
        if (isOrigin[idx]) {
          _tracking = _rebuildTracking(
            origin: TrackingLocation(address: loc.address, latitude: coord.$1, longitude: coord.$2),
          );
        } else {
          _tracking = _rebuildTracking(
            destination: TrackingLocation(address: loc.address, latitude: coord.$1, longitude: coord.$2),
          );
        }
      }
      idx++;
    }

    if (mounted) setState(() {});
    final firstPoint = _tracking?.origin?.latLng ?? _tracking?.destination?.latLng;
    if (firstPoint != null) {
      try { _mapController.move(firstPoint, 14); } catch (_) {}
    }
  }

  Future<(double, double)?> _geocodeBestEffort(LocationRepository repo, String address) async {
    final fullQuery = address.trim();
    var results = await _searchSafe(repo, fullQuery);
    if (results.isNotEmpty) return (results.first.latitude, results.first.longitude);

    final deduped = _removeDuplicateParts(fullQuery);
    if (deduped != fullQuery) {
      results = await _searchSafe(repo, deduped);
      if (results.isNotEmpty) return (results.first.latitude, results.first.longitude);
    }

    final region = extractRegion(fullQuery);
    if (region.isNotEmpty && region != fullQuery) {
      results = await _searchSafe(repo, region);
      if (results.isNotEmpty) return (results.first.latitude, results.first.longitude);
    }
    return null;
  }

  String _removeDuplicateParts(String address) {
    final parts = address.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final seen = <String>{};
    final unique = <String>[];
    for (final part in parts) {
      final lower = part.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
      final stripped = lower.replaceAll(RegExp(r'\s*\d{4,6}$'), '').trim();
      final key = stripped.isNotEmpty ? stripped : lower;
      if (!seen.contains(key)) {
        seen.add(key);
        unique.add(part);
      }
    }
    return unique.join(', ');
  }

  Future<List<Address>> _searchSafe(LocationRepository repo, String query) async {
    if (query.trim().isEmpty) return [];
    try {
      return await repo.searchAddress(query).timeout(const Duration(seconds: 4));
    } catch (_) {
      return [];
    }
  }

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
      senderName: t.senderName,
      senderPhone: t.senderPhone,
      receiverName: t.receiverName,
      receiverPhone: t.receiverPhone,
      vehicle: t.vehicle,
      packageWeight: t.packageWeight,
      paymentMethod: t.paymentMethod,
      totalCost: t.totalCost,
      scheduleText: t.scheduleText,
      qrCodeUrl: t.qrCodeUrl,
      rawJson: t.rawJson,
    );
  }

  Future<shipping_route.RouteModel?> _getRouteFromOSRM(LatLng origin, LatLng destination) async {
    final coords = '${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}';
    final url = Uri.parse('${MapConfig.osrmBaseUrl}/route/v1/driving/$coords').replace(
      queryParameters: {'overview': 'full', 'geometries': 'geojson', 'steps': 'false'},
    );
    final response = await http.get(url).timeout(MapConfig.networkTimeout);
    if (response.statusCode != 200) return null;
    final data = jsonDecode(response.body);
    if (data['code'] != 'Ok' || data['routes'] == null || (data['routes'] as List).isEmpty) {
      return null;
    }
    final routeData = data['routes'][0] as Map<String, dynamic>;
    final geometry = routeData['geometry'] as Map<String, dynamic>?;

    final List<LatLng> coordinates = [];
    if (geometry != null && geometry['coordinates'] is List) {
      for (final coord in geometry['coordinates'] as List) {
        if (coord is List && coord.length >= 2) {
          coordinates.add(LatLng(coord[1].toDouble(), coord[0].toDouble()));
        }
      }
    }

    final distance = (routeData['distance'] as num?)?.toDouble() ?? 0.0;
    final duration = (routeData['duration'] as num?)?.toDouble() ?? 0.0;

    return shipping_route.RouteModel(
      coordinates: coordinates,
      distanceMeters: distance,
      durationSeconds: duration,
    );
  }

  void _centerMap() {
    final points = <LatLng>[];
    if (_tracking?.origin?.latLng != null) points.add(_tracking!.origin!.latLng!);
    if (_tracking?.currentLocation != null) points.add(_tracking!.currentLocation!);
    if (_tracking?.destination?.latLng != null) points.add(_tracking!.destination!.latLng!);

    if (points.isEmpty) return;
    if (points.length == 1) {
      _mapController.move(points.first, 15);
    } else {
      final bounds = LatLngBounds.fromPoints(points);
      try {
        _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(40)));
      } catch (_) {
        _mapController.move(bounds.center, 13);
      }
    }
  }

  Future<void> _shareTracking() async {
    final trackNum = _resi;
    final sName = _getSenderName();
    final rName = _getReceiverName();
    final veh = _getVehicleName();
    final status = _tracking?.statusLabel ?? 'Menunggu Kurir';
    final trackUrl = 'https://citycourier.pabm.space/track/$trackNum';

    final text = '📦 *Live Tracking City Courier*\n\n'
        'Nomor Resi: $trackNum\n'
        'Status: $status\n\n'
        '📍 Pengirim: $sName\n'
        '📍 Penerima: $rName\n'
        '🚚 Kendaraan: $veh\n\n'
        '🔗 Cek posisi kurir secara live di sini:\n$trackUrl';

    final uri = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(text)}');
    final webUri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        final launched = await launchUrl(webUri, mode: LaunchMode.externalApplication);
        if (!launched) {
          throw Exception('Could not launch WhatsApp web');
        }
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tautan tracking disalin ke clipboard!'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _contactSupport() async {
    final text = 'Halo Customer Service City Courier, saya butuh bantuan terkait pesanan nomor resi $_resi';
    final url = Uri.parse('https://wa.me/6281343323155?text=${Uri.encodeComponent(text)}');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hubungi CS: +62 813-4332-2155'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  String _getSenderName() =>
      _tracking?.senderName ??
      widget.shipmentData?['sender_name'] ??
      widget.trackingData?['sender_name'] ??
      'brightness';

  String _getSenderPhone() =>
      _tracking?.senderPhone ??
      widget.shipmentData?['sender_phone'] ??
      widget.trackingData?['sender_phone'] ??
      '813 4332 2155';

  String _getSenderAddress() =>
      _tracking?.origin?.address ??
      widget.shipmentData?['sender_address'] ??
      'Wedoro, Waru, Sidoarjo, Jawa Timur';

  String _getReceiverName() =>
      _tracking?.receiverName ??
      widget.shipmentData?['receiver_name'] ??
      widget.trackingData?['receiver_name'] ??
      'andrew';

  String _getReceiverPhone() =>
      _tracking?.receiverPhone ??
      widget.shipmentData?['receiver_phone'] ??
      widget.trackingData?['receiver_phone'] ??
      '813 4332 2155';

  String _getReceiverAddress() =>
      _tracking?.destination?.address ??
      widget.shipmentData?['receiver_address'] ??
      'Universitas 17 Agustus 1945 Surabaya';

  String _getVehicleName() {
    final raw = (_tracking?.vehicle ?? widget.shipmentData?['vehicle'] ?? widget.shipmentData?['vehicle_type'] ?? 'motor').toString().toLowerCase();
    return raw.contains('mobil') || raw.contains('car') ? 'Mobil' : 'Motor';
  }

  String _getPackageWeight() {
    final w = _tracking?.packageWeight ??
        widget.shipmentData?['package_weight'] ??
        widget.shipmentData?['actual_weight'] ??
        1.5;
    final numVal = (w is num) ? w.toDouble() : double.tryParse(w.toString()) ?? 1.5;
    return '${numVal.toStringAsFixed(2)} kg';
  }

  String _getPaymentMethod() {
    final m = (_tracking?.paymentMethod ?? widget.shipmentData?['payment_method'] ?? 'TUNAI').toString().toUpperCase();
    return m.isEmpty ? 'TUNAI' : m;
  }

  String _getTotalCost() {
    final c = _tracking?.totalCost ??
        widget.shipmentData?['total_cost'] ??
        widget.shipmentData?['total_amount'] ??
        widget.shipmentData?['amount'] ??
        18200;
    final intVal = (c is num) ? c.toInt() : int.tryParse(c.toString()) ?? 18200;
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0).format(intVal);
  }

  String _getScheduleText() =>
      _tracking?.scheduleText ??
      widget.shipmentData?['schedule_pickup_text'] ??
      'Sekarang';

  @override
  Widget build(BuildContext context) {
    const Color bgScaffold = Color(0xFFF8FAFC);
    const Color darkNavy = Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: bgScaffold,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: darkNavy, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/Logo_City_Courier.png',
              height: 32,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFEC5B13),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'CC',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'City Courier',
                  style: TextStyle(color: darkNavy, fontSize: 14.5, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Live Delivery Tracking',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 10.5, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('●', style: TextStyle(color: Color(0xFF10B981), fontSize: 9)),
                    SizedBox(width: 5),
                    Text(
                      'Live',
                      style: TextStyle(
                        color: Color(0xFF059669),
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_viewState) {
      case TrackingViewState.loading:
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFFEC5B13)),
              SizedBox(height: 16),
              Text('Memuat data live tracking...', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
            ],
          ),
        );
      case TrackingViewState.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
                const SizedBox(height: 12),
                Text(_errorMessage ?? 'Gagal memuat tracking.', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _initTracking,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A)),
                  child: const Text('Coba Lagi', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        );
      case TrackingViewState.notFound:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.search_off_rounded, color: Colors.orange, size: 48),
                const SizedBox(height: 12),
                const Text('Nomor resi tidak ditemukan.', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A)),
                  child: const Text('Kembali', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        );
      case TrackingViewState.loaded:
      default:
        return _buildLoadedContent();
    }
  }

  Widget _buildLoadedContent() {
    const Color darkNavy = Color(0xFF0F172A);
    const Color orangeAccent = Color(0xFFEA580C);

    final isCourierAssigned = _tracking?.courier != null ||
        (_tracking?.status != TrackingStatus.pending &&
            _tracking?.status != TrackingStatus.confirmed &&
            _tracking?.status != TrackingStatus.cancelled);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── CARD 1: Status & Resi ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFF1F5F9)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Nomor Resi',
                            style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  _resi,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: darkNavy,
                                    letterSpacing: 0.5,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              InkWell(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: _resi));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Nomor resi disalin ke clipboard!'),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(4),
                                child: const Padding(
                                  padding: EdgeInsets.all(2),
                                  child: Icon(Icons.copy_rounded, size: 16, color: Color(0xFF64748B)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Status Badge Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFFED7AA)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.access_time_rounded, size: 14, color: orangeAccent),
                          const SizedBox(width: 5),
                          Text(
                            _tracking?.statusLabel ?? 'Menunggu Kurir',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: orangeAccent),
                          ),
                          const SizedBox(width: 3),
                          const Icon(Icons.chevron_right_rounded, size: 14, color: orangeAccent),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Notice Banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFEF3C7)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: orangeAccent,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          isCourierAssigned ? '🛵' : '⏱',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isCourierAssigned
                                  ? 'Kurir Ditugaskan: ${_tracking?.courier?.name ?? "Kurir City Courier"}'
                                  : 'Menunggu kurir menerima pesanan.',
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: darkNavy),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isCourierAssigned
                                  ? 'Kurir sedang dalam proses penjemputan/pengantaran paket Anda.'
                                  : 'Lokasi kurir akan muncul secara live setelah kurir mengambil tugas ini.',
                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── CARD 2: Peta Rute & Posisi Kurir ──
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFF1F5F9)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('●', style: TextStyle(color: orangeAccent, fontSize: 10)),
                            SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Peta Rute & Posisi Kurir',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: darkNavy),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 4),
                          Text(
                            'Diperbarui: $_lastUpdatedTime',
                            style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  child: SizedBox(
                    height: 280,
                    child: Stack(
                      children: [
                        // Map
                        _tracking != null
                            ? TrackingMapWidget(
                                tracking: _tracking!,
                                route: _route,
                                isLoadingRoute: _isLoadingRoute,
                                mapController: _mapController,
                              )
                            : Container(color: Colors.grey.shade100),

                        // Zoom Buttons Top-Left
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Column(
                            children: [
                              _buildMiniIconButton(
                                icon: Icons.add,
                                onTap: () {
                                  final currentZoom = _mapController.camera.zoom;
                                  _mapController.move(_mapController.camera.center, currentZoom + 1);
                                },
                              ),
                              const SizedBox(height: 4),
                              _buildMiniIconButton(
                                icon: Icons.remove,
                                onTap: () {
                                  final currentZoom = _mapController.camera.zoom;
                                  _mapController.move(_mapController.camera.center, currentZoom - 1);
                                },
                              ),
                            ],
                          ),
                        ),

                        // Center Map Floating Button Bottom-Right
                        Positioned(
                          bottom: 12,
                          right: 12,
                          child: Material(
                            color: Colors.white,
                            elevation: 3,
                            borderRadius: BorderRadius.circular(20),
                            child: InkWell(
                              onTap: _centerMap,
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.near_me_outlined, size: 14, color: orangeAccent),
                                    SizedBox(width: 4),
                                    Text(
                                      'Pusatkan',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        color: darkNavy,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── CARD 3: Informasi Pengiriman ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFF1F5F9)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Informasi Pengiriman',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: darkNavy),
                ),
                const SizedBox(height: 14),

                // Pickup & Destination
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Lokasi Pickup
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Text('●', style: TextStyle(color: Color(0xFF10B981), fontSize: 10)),
                              SizedBox(width: 5),
                              Text(
                                'Lokasi Pickup',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getSenderName(),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: darkNavy),
                          ),
                          const SizedBox(height: 2),
                          InkWell(
                            onTap: () {
                              final p = _getSenderPhone().replaceAll(RegExp(r'\s+'), '');
                              launchUrl(Uri.parse('tel:$p'));
                            },
                            child: Row(
                              children: [
                                const Icon(Icons.phone_outlined, size: 11, color: Color(0xFF64748B)),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    '(${_getSenderPhone()})',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getSenderAddress(),
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.3),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('📦', style: TextStyle(fontSize: 10)),
                                const SizedBox(width: 4),
                                Text(
                                  'Jadwal: ${_getScheduleText()}',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Divider
                    Container(width: 1, height: 110, color: const Color(0xFFF1F5F9)),
                    const SizedBox(width: 12),

                    // Lokasi Tujuan
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Text('●', style: TextStyle(color: Color(0xFFEF4444), fontSize: 10)),
                              SizedBox(width: 5),
                              Text(
                                'Lokasi Tujuan',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getReceiverName(),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: darkNavy),
                          ),
                          const SizedBox(height: 2),
                          InkWell(
                            onTap: () {
                              final p = _getReceiverPhone().replaceAll(RegExp(r'\s+'), '');
                              launchUrl(Uri.parse('tel:$p'));
                            },
                            child: Row(
                              children: [
                                const Icon(Icons.phone_outlined, size: 11, color: Color(0xFF64748B)),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    '(${_getReceiverPhone()})',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getReceiverAddress(),
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.3),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 4-Box Specs Grid
                Row(
                  children: [
                    _buildSpecBox(label: 'Kendaraan', icon: '🛵', value: _getVehicleName()),
                    const SizedBox(width: 8),
                    _buildSpecBox(label: 'Berat Barang', icon: '⚖️', value: _getPackageWeight()),
                    const SizedBox(width: 8),
                    _buildSpecBox(label: 'Pembayaran', icon: '💳', value: _getPaymentMethod()),
                    const SizedBox(width: 8),
                    _buildSpecBox(
                      label: 'Total Biaya',
                      icon: '💰',
                      value: _getTotalCost(),
                      isHighlight: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── CARD 4: Riwayat Perjalanan ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFF1F5F9)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Riwayat Perjalanan',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: darkNavy),
                    ),
                    Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF94A3B8)),
                  ],
                ),
                const SizedBox(height: 14),

                _buildTimelineList(),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── CARD 5: QR Code Pesanan & Action Buttons ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFF1F5F9)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    // QR Code Box with Bracket Accents
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: orangeAccent, width: 1.5),
                      ),
                      padding: const EdgeInsets.all(6),
                      child: QrImageView(
                        data: _resi,
                        version: QrVersions.auto,
                        size: 72,
                        eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: darkNavy),
                        dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: darkNavy),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // QR Texts
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'QR Code Pesanan',
                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: darkNavy),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Tunjukkan QR Code ini kepada kurir saat proses pickup.',
                            style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.3),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Text(
                              _resi,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                                color: darkNavy,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Color(0xFFF1F5F9), height: 1),
                const SizedBox(height: 12),

                // Buttons: [ 💬 Bantuan ] & [ 🔗 Bagikan Resi ]
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _contactSupport,
                        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: darkNavy),
                        label: const Text(
                          'Bantuan',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: darkNavy),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _shareTracking,
                        icon: const Icon(Icons.share_rounded, size: 16, color: Colors.white),
                        label: const Text(
                          'Bagikan Resi',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: orangeAccent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ── FOOTER ──
          const Center(
            child: Text(
              '© 2026 City Courier • Pengiriman Kilat Dalam Kota',
              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ),
          const SizedBox(height: 18),
        ],
      ),
    );
  }

  Widget _buildSpecBox({
    required String label,
    required String icon,
    required String value,
    bool isHighlight = false,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: isHighlight ? const Color(0xFFFFF7ED) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isHighlight ? const Color(0xFFFED7AA) : const Color(0xFFF1F5F9),
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(icon, style: const TextStyle(fontSize: 10)),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w500,
                      color: isHighlight ? const Color(0xFFEA580C) : const Color(0xFF64748B),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isHighlight ? const Color(0xFFEA580C) : const Color(0xFF0F172A),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineList() {
    final timeline = _tracking?.timeline ?? [];
    if (timeline.isEmpty) {
      return Column(
        children: [
          _buildTimelineNode(
            title: 'Pesanan Dikonfirmasi',
            desc: 'Pesanan dikonfirmasi! Menunggu penjemputan oleh kurir.',
            time: DateFormat('d MMM yyyy, HH:mm').format(DateTime.now()),
            isFirst: true,
            isLast: false,
          ),
          _buildTimelineNode(
            title: 'Pesanan Dibuat',
            desc: 'Pesanan berhasil dibuat di sistem.',
            time: DateFormat('d MMM yyyy, HH:mm').format(DateTime.now()),
            isFirst: false,
            isLast: true,
          ),
        ],
      );
    }

    return Column(
      children: List.generate(timeline.length, (idx) {
        final item = timeline[idx];
        final timeStr = item.createdAt != null
            ? DateFormat('d MMM yyyy, HH:mm').format(item.createdAt!)
            : '-';
        return _buildTimelineNode(
          title: item.statusLabel,
          desc: item.description ?? 'Pembaruan status pengiriman.',
          time: timeStr,
          isFirst: idx == 0,
          isLast: idx == timeline.length - 1,
        );
      }),
    );
  }

  Widget _buildTimelineNode({
    required String title,
    required String desc,
    required String time,
    required bool isFirst,
    required bool isLast,
  }) {
    const Color darkNavy = Color(0xFF0F172A);
    const Color orangeAccent = Color(0xFFEA580C);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Indicator & vertical line
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFirst ? orangeAccent : const Color(0xFF94A3B8),
                    border: isFirst ? Border.all(color: const Color(0xFFFFEDD5), width: 2) : null,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      color: const Color(0xFFE2E8F0),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: darkNavy),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    time,
                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniIconButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Icon(icon, size: 16, color: const Color(0xFF475569)),
        ),
      ),
    );
  }
}
