import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'package:city_courierapp/models/shipping/route_model.dart';
import 'package:city_courierapp/services/shipping/routing_service.dart';
import 'package:city_courierapp/services/voice_service.dart';

/// Fase perjalanan — menentukan destination navigasi (PRD §34).
enum NavigationPhase { pickup, delivery }

/// Status navigasi (PRD §31).
enum NavigationStatus {
  /// Persiapan awal / cek GPS.
  initializing,

  /// GPS perangkat non-aktif.
  locationDisabled,

  /// Izin lokasi ditolak.
  permissionDenied,

  /// Menunggu fix GPS pertama.
  locating,

  /// Meminta rute ke routing engine.
  loadingRoute,

  /// Rute ditemukan — perjalanan aktif.
  navigating,

  /// Kurir keluar dari jalur, menunggu threshold.
  offRoute,

  /// Menghitung ulang rute.
  rerouting,

  /// Berada dalam radius arrival dari tujuan.
  arrived,

  /// Rute tidak dapat ditentukan / koneksi bermasalah.
  error,
}

/// Controller navigasi (PRD §35): memisahkan routing logic dari widget UI.
///
/// Menjalankan live location, deteksi off-route, rerouting dengan cooldown,
/// ETA, dan progress perjalanan.
class NavigationController extends ChangeNotifier {
  final Map<String, dynamic> order;
  final RoutingService routingService;

  /// Fase saat ini — dapat berubah setelah paket diambil (PRD §7).
  NavigationPhase phase;

  NavigationStatus status = NavigationStatus.initializing;
  Function(String command)? onVoiceCommand;

  LatLng? currentLocation;
  
  LatLng? get snappedLocation {
    final cur = currentLocation;
    if (cur == null) return null;
    final pts = route?.coordinates;
    if (pts == null || pts.isEmpty) return cur;
    return _snapToPolyline(cur, pts);
  }

  /// Mendapatkan arah (bearing) dari segmen rute saat ini agar peta bisa diluruskan dengan garis biru
  double? get routeHeading {
    final cur = currentLocation;
    final pts = route?.coordinates;
    if (cur == null || pts == null || pts.length < 2) return null;

    const mPerDegLat = 111320.0;
    final latRad = cur.latitude * math.pi / 180.0;
    final mPerDegLng = 111320.0 * math.cos(latRad);

    double sx(LatLng c) => (c.longitude - cur.longitude) * mPerDegLng;
    double sy(LatLng c) => (c.latitude - cur.latitude) * mPerDegLat;

    double minDist = double.infinity;
    double? heading;

    for (var i = 0; i < pts.length - 1; i++) {
      final a = pts[i];
      final b = pts[i + 1];

      final ax = sx(a);
      final ay = sy(a);
      final bx = sx(b);
      final by = sy(b);
      final dx = bx - ax;
      final dy = by - ay;
      final lenSq = dx * dx + dy * dy;
      
      double d;
      if (lenSq == 0) {
        d = math.sqrt(ax * ax + ay * ay);
      } else {
        var t = ((-ax) * dx + (-ay) * dy) / lenSq;
        t = t.clamp(0.0, 1.0);
        final cx = ax + t * dx;
        final cy = ay + t * dy;
        d = math.sqrt(cx * cx + cy * cy);
      }

      if (d < minDist) {
        minDist = d;
        heading = _bearing(a, b);
      }
    }
    return heading;
  }

  double? heading;
  double? gpsAccuracy;
  double? headingAccuracy;
  
  double? deviceHeading;
  double deviceHeadingTurns = 0.0;

  LatLng? destination;
  LatLng? pickupLocation;
  String? destinationLabel;

  RouteModel? route;
  String errorMessage = '';
  bool permissionPermanentlyDenied = false;

  /// Control status untuk UI
  bool soundEnabled = true;
  bool isCompassHeadingUp = true;
  bool isMicEnabled = false;
  double currentSpeedMs = 0.0; // speed in meters per second


  /// Radius kedatangan (meter) — hanya untuk menampilkan "Anda telah tiba",
  /// tidak otomatis menyelesaikan pengiriman (PRD §32).
  static const double arrivalRadius = 40.0;

  /// Jarak penyimpangan dari jalur yang memicu rerouting (PRD §15).
  static const double offRouteThreshold = 40.0;

  /// Cooldown antar rerouting agar tidak membanjiri API (PRD §16).
  static const Duration rerouteCooldown = Duration(seconds: 15);

  final Distance _distance = const Distance();
  StreamSubscription<Position>? _positionSub;
  StreamSubscription<CompassEvent>? _compassSub;
  DateTime? _lastRouteAt;
  bool _rerouteInFlight = false;
  bool _disposed = false;
  double? _lastLat;
  double? _lastLng;
  RouteStep? _lastSpokenStep;

  NavigationController({
    required this.order,
    required this.phase,
    RoutingService? routingService,
  }) : routingService = routingService ?? CityCourierRoutingService() {
    VoiceService().onStatusChanged = (status) {
      if (status == 'notListening' && isMicEnabled) {
        isMicEnabled = false;
        notifyListeners();
      }
    };
  }

  bool get hasRoute => route != null;
  bool get hasArrived => status == NavigationStatus.arrived;
  bool get isOnRoute => status == NavigationStatus.navigating;

  /// Peringatan GPS kurang akurat (PRD §25).
  bool get accuracyWarning {
    final a = gpsAccuracy;
    return a != null && a > 80.0;
  }

  String get title =>
      phase == NavigationPhase.pickup ? 'Menuju Pengirim' : 'Menuju Penerima';

  /// Progres 0..1 sepanjang rute.
  double get progress {
    final r = route;
    final cur = currentLocation;
    if (r == null || cur == null || r.coordinates.isEmpty) return 0;
    final remaining = _routeRemainingMeters(cur, r.coordinates);
    final total = r.distanceMeters > 0
        ? r.distanceMeters
        : _geomLength(r.coordinates);
    if (total <= 0) return 0;
    return ((total - remaining) / total).clamp(0.0, 1.0);
  }

  /// Jarak tersisa menuju tujuan (meter).
  double get distanceRemaining {
    final cur = currentLocation;
    final dest = destination;
    if (route == null || cur == null || dest == null) {
      return cur != null && dest != null
          ? _distance.as(LengthUnit.Meter, cur, dest)
          : 0;
    }
    return _routeRemainingMeters(cur, route!.coordinates);
  }

  double? get durationRemainingSeconds {
    final r = route;
    if (r == null) return null;
    return r.durationSeconds * (1 - progress);
  }

  DateTime? get eta {
    final d = durationRemainingSeconds;
    if (d == null) return null;
    return DateTime.now().add(Duration(seconds: d.round()));
  }

  String get formattedEta {
    final t = eta;
    if (t == null) return '--:--';
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  double get speedKmH => currentSpeedMs * 3.6;

  void toggleSound() {
    soundEnabled = !soundEnabled;
    if (!soundEnabled) {
      VoiceService().stopSpeaking();
    }
    notifyListeners();
  }

  void toggleCompassMode() {
    isCompassHeadingUp = !isCompassHeadingUp;
    notifyListeners();
  }
  
  void toggleMic() {
    isMicEnabled = !isMicEnabled;
    if (isMicEnabled) {
      VoiceService().startListening((text) {
        final lower = text.toLowerCase();
        if (lower.contains('selesai') || lower.contains('tiba') || lower.contains('sampai')) {
          onVoiceCommand?.call('arrive');
        }
      }).then((started) {
        if (!started) {
          isMicEnabled = false;
          notifyListeners();
        }
      });
    } else {
      VoiceService().stopListening();
    }
    notifyListeners();
  }

  /// Instruksi turun berikutnya (P1 turn-by-turn, dasar dari steps).
  RouteStep? get currentStep {
    final r = route;
    if (r == null || r.steps.isEmpty) return null;
    final traveled = r.distanceMeters * progress.clamp(0.0, 1.0);
    double cum = 0;
    for (final s in r.steps) {
      if (s.distanceMeters > 0) {
        cum += s.distanceMeters;
        if (traveled <= cum) return s;
      }
    }
    return r.steps.last;
  }

  /// Jarak tersisa di step saat ini (menuju maneuver berikutnya)
  double get distanceToNextManeuver {
    final r = route;
    if (r == null || r.steps.isEmpty) return 0;
    final traveled = r.distanceMeters * progress.clamp(0.0, 1.0);
    double cum = 0;
    for (final s in r.steps) {
      if (s.distanceMeters > 0) {
        cum += s.distanceMeters;
        if (traveled <= cum) {
          return (cum - traveled).clamp(0.0, s.distanceMeters);
        }
      }
    }
    return 0;
  }

  /// Step berikutnya (maneuver yang akan datang)
  RouteStep? get nextStep {
    final r = route;
    if (r == null || r.steps.isEmpty) return null;
    final traveled = r.distanceMeters * progress.clamp(0.0, 1.0);
    double cum = 0;
    for (int i = 0; i < r.steps.length; i++) {
      final s = r.steps[i];
      if (s.distanceMeters > 0) {
        cum += s.distanceMeters;
        if (traveled <= cum) {
          if (i + 1 < r.steps.length) {
            return r.steps[i + 1];
          }
          return s; // If it's the last step, just return it
        }
      }
    }
    return r.steps.last;
  }

  /// Memulai alur navigasi: cek GPS, minta izin, ambil posisi, request rute.
  Future<void> start() async {
    await _resolveDestination();
    if (_disposed) return;
    if (destination == null) {
      errorMessage = phase == NavigationPhase.pickup
          ? 'Lokasi pengirim tidak dapat ditemukan.\n'
              'Silakan periksa alamat atau hubungi pengirim untuk mendapatkan lokasi yang benar.'
          : 'Lokasi penerima tidak dapat ditemukan.\n'
              'Silakan periksa alamat atau hubungi penerima untuk mendapatkan lokasi yang benar.';
      status = NavigationStatus.error;
      notifyListeners();
      return;
    }

    status = NavigationStatus.initializing;
    notifyListeners();

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      status = NavigationStatus.locationDisabled;
      notifyListeners();
      return;
    }

    final granted = await _requestLocationAccess();
    if (_disposed || !granted) return;

    status = NavigationStatus.locating;
    notifyListeners();

    await _startListening();
  }

  /// Mengganti fase (mis. setelah "Paket Sudah Diambil") → reroute ke
  /// lokasi penerima (PRD §7, §34).
  Future<void> switchPhase(NavigationPhase newPhase) async {
    if (newPhase == phase) return;
    phase = newPhase;
    route = null;
    await _resolveDestination();
    if (_disposed) return;
    if (destination == null) {
      errorMessage = 'Lokasi penerima tidak dapat ditemukan.\n'
          'Silakan periksa alamat atau hubungi penerima dengan lokasi yang benar.';
      status = NavigationStatus.error;
      notifyListeners();
      return;
    }
    status = NavigationStatus.loadingRoute;
    notifyListeners();
    await _requestRoute();
  }

  /// Tombol "Izinkan Lokasi".
  Future<void> allowLocation() async {
    final granted = await _requestLocationAccess();
    if (_disposed || !granted) return;
    status = NavigationStatus.locating;
    notifyListeners();
    await _startListening();
  }

  /// Tombol "Buka Pengaturan".
  Future<void> openSettings() async {
    await Geolocator.openAppSettings();
    final granted = await _requestLocationAccess();
    if (_disposed || !granted) return;
    status = NavigationStatus.locating;
    notifyListeners();
    await _startListening();
  }

  /// Tombol "Coba Lagi" pada state error.
  Future<void> retry() async {
    if (currentLocation == null) {
      await start();
      return;
    }
    status = NavigationStatus.loadingRoute;
    notifyListeners();
    await _requestRoute();
  }

  /// Melakukan rerouting secara manual (mis. dropdown "hitung ulang").
  Future<void> recalculate() async {
    if (currentLocation == null) return;
    status = NavigationStatus.loadingRoute;
    notifyListeners();
    await _requestRoute();
  }

  Future<bool> _requestLocationAccess() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      permissionPermanentlyDenied = false;
      status = NavigationStatus.permissionDenied;
      notifyListeners();
      return false;
    }
    if (permission == LocationPermission.deniedForever) {
      permissionPermanentlyDenied = true;
      status = NavigationStatus.permissionDenied;
      notifyListeners();
      return false;
    }
    return true;
  }

  Future<void> _startListening() async {
    const settings = LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 8,
      timeLimit: Duration(seconds: 30),
    );

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: settings,
      );
      _onPosition(pos);
    } catch (_) {
      // Belum ada fix — stream akan memberikan posisi saat tersedia.
    }

    if (_disposed) return;
    _positionSub = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 8,
      ),
    ).listen(
      _onPosition,
      onError: (Object _) {
        if (!_disposed && currentLocation == null) {
          status = NavigationStatus.locationDisabled;
          notifyListeners();
        }
      },
    );

    _compassSub = FlutterCompass.events?.listen((CompassEvent event) {
      if (_disposed) return;
      if (event.heading != null) {
        final newHeading = event.heading! >= 0 ? event.heading! : 360 + event.heading!;
        deviceHeading = newHeading;
        
        // Calculate shortest path for turns
        if (deviceHeadingTurns == 0.0) {
          deviceHeadingTurns = newHeading / 360.0;
        } else {
          final currentDeg = (deviceHeadingTurns % 1.0) * 360.0;
          var diff = newHeading - currentDeg;
          if (diff > 180) {
            diff -= 360;
          } else if (diff < -180) {
            diff += 360;
          }
          deviceHeadingTurns += diff / 360.0;
        }
        notifyListeners();
      }
    });
  }

  void _onPosition(Position p) {
    if (_disposed) return;
    currentLocation = LatLng(p.latitude, p.longitude);
    gpsAccuracy = p.accuracy;
    headingAccuracy = p.headingAccuracy;
    currentSpeedMs = p.speed;

    if (p.heading >= 0) {
      heading = p.heading;
    }
    final derived = _deriveHeadingFromMovement();
    if (derived != null) heading = derived;

    _lastLat = p.latitude;
    _lastLng = p.longitude;

    if (route == null) {
      unawaited(_requestRoute());
    } else {
      _evaluateNavigation();
    }
    notifyListeners();
  }

  double? _deriveHeadingFromMovement() {
    final lat = _lastLat;
    final lng = _lastLng;
    final cur = currentLocation;
    if (lat == null || lng == null || cur == null) return null;
    final moved = _distance.as(LengthUnit.Meter, LatLng(lat, lng), cur);
    if (moved < 5) return null;
    return _bearing(LatLng(lat, lng), cur);
  }

  static double _bearing(LatLng a, LatLng b) {
    final lat1 = _deg2rad(a.latitude);
    final lat2 = _deg2rad(b.latitude);
    final dLng = _deg2rad(b.longitude - a.longitude);
    final y = math.sin(dLng) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    final brng = math.atan2(y, x) * 180 / math.pi;
    return (brng + 360) % 360;
  }

  static double _deg2rad(double deg) => deg * math.pi / 180.0;

  void _evaluateNavigation() {
    final cur = currentLocation;
    final dest = destination;
    final r = route;
    if (cur == null || dest == null) return;

    final destDist = _distance.as(LengthUnit.Meter, cur, dest);
    if (destDist <= arrivalRadius) {
      status = NavigationStatus.arrived;
      return;
    }

    if (r == null) {
      unawaited(_requestRoute());
      return;
    }

    if (status == NavigationStatus.arrived) return;

    final offDist = _distanceFromPolylineMeters(cur, r.coordinates);
    if (offDist > offRouteThreshold && _canReroute()) {
      status = NavigationStatus.offRoute;
      unawaited(_requestRoute());
    } else if (status == NavigationStatus.offRoute ||
        status == NavigationStatus.rerouting) {
      // Tetap menampilkan banner selama proses validasi/rerouting.
      if (status != NavigationStatus.rerouting) {
        status = NavigationStatus.navigating;
      }
    } else if (status == NavigationStatus.loadingRoute) {
      status = NavigationStatus.navigating;
    }

    _checkVoiceInstructions();
  }

  RouteStep? _lastSpokenNextStep;

  void _checkVoiceInstructions() {
    if (!soundEnabled) return;
    final step = currentStep;
    if (step != null && _lastSpokenStep != step) {
      // Bacakan instruksi jalan saat ini (misal "Terus di Jalan A")
      VoiceService().speak(step.instruction);
      _lastSpokenStep = step;
    }
    
    // Bacakan peringatan belokan saat jarak mendekati 100 meter
    final next = nextStep;
    final dist = distanceToNextManeuver;
    if (next != null && dist > 0 && dist < 100) {
      if (_lastSpokenNextStep != next) {
        VoiceService().speak("Dalam ${dist.round()} meter, ${next.instruction}");
        _lastSpokenNextStep = next;
      }
    }
  }

  bool _canReroute() {
    if (_rerouteInFlight) return false;
    if (_lastRouteAt == null) return true;
    return DateTime.now().difference(_lastRouteAt!) >= rerouteCooldown;
  }

  Future<void> _requestRoute() async {
    if (_rerouteInFlight) return;
    final cur = currentLocation;
    final dest = destination;
    if (cur == null || dest == null) return;

    _rerouteInFlight = true;
    final isFirst = route == null;
    status = isFirst ? NavigationStatus.loadingRoute : NavigationStatus.rerouting;
    notifyListeners();

    try {
      final r = await routingService.getRoute(origin: cur, destination: dest);
      if (_disposed) return;
      route = r;
      _lastRouteAt = DateTime.now();

      if (_distance.as(LengthUnit.Meter, cur, dest) <= arrivalRadius) {
        status = NavigationStatus.arrived;
      } else {
        status = NavigationStatus.navigating;
      }
    } catch (e) {
      if (_disposed) return;
      if (route == null) {
        errorMessage = e is RoutingException
            ? e.message
            : 'Tidak dapat menentukan rute.\nPeriksa koneksi internet Anda dan coba lagi.';
        status = NavigationStatus.error;
      } else {
        // Rerouting gagal → tetap pakai rute lama.
        status = NavigationStatus.navigating;
      }
    } finally {
      _rerouteInFlight = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> _resolveDestination() async {
    if (phase == NavigationPhase.pickup) {
      pickupLocation = _orderLatLng(order, prefix: 'pickup');
      destinationLabel =
          (order['sender_name'] ?? order['pickup_name'] ?? 'Lokasi Pengirim')
              .toString();
      if (pickupLocation != null) {
        destination = pickupLocation;
        return;
      }
      destination = await _geocodeAddress(order['pickup_address']?.toString());
    } else {
      final dropoff = _orderLatLng(order, prefix: 'dropoff');
      destinationLabel =
          (order['receiver_name'] ?? order['dropoff_name'] ?? 'Lokasi Penerima')
              .toString();
      if (dropoff != null) {
        destination = dropoff;
        return;
      }
      destination = await _geocodeAddress(order['dropoff_address']?.toString());
    }
  }

  LatLng? _orderLatLng(
    Map<String, dynamic> order, {
    required String prefix,
  }) {
    final lat = _tryNum(order['${prefix}_latitude']) ??
        _tryNum(order['latitude_$prefix']);
    final lng = _tryNum(order['${prefix}_longitude']) ??
        _tryNum(order['longitude_$prefix']);
    if (lat != null && lng != null) return LatLng(lat, lng);

    final nested = order['${prefix}_location'];
    if (nested is Map) {
      final nLat = _tryNum(nested['lat']) ?? _tryNum(nested['latitude']);
      final nLng = _tryNum(nested['lng']) ??
          _tryNum(nested['lon']) ??
          _tryNum(nested['longitude']);
      if (nLat != null && nLng != null) return LatLng(nLat, nLng);
    }
    return null;
  }

  static double? _tryNum(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  Future<LatLng?> _geocodeAddress(String? address) async {
    if (address == null || address.trim().isEmpty) return null;
    try {
      final locations = await locationFromAddress(address.trim());
      if (locations.isNotEmpty) {
        return LatLng(locations.first.latitude, locations.first.longitude);
      }
    } catch (_) {
      // abaikan — fallback null
    }
    return null;
  }

  // ---------------------------------------------------------------- jarak

  static double _geomLength(List<LatLng> pts) {
    if (pts.length < 2) return 0;
    const d = Distance();
    double sum = 0;
    for (var i = 0; i < pts.length - 1; i++) {
      sum += d.as(LengthUnit.Meter, pts[i], pts[i + 1]);
    }
    return sum;
  }

  /// Jarak (meter) dari titik ke polyline rute.
  double _distanceFromPolylineMeters(LatLng p, List<LatLng> pts) {
    if (pts.length < 2) {
      return pts.isEmpty ? 0 : _distance.as(LengthUnit.Meter, p, pts.first);
    }
    double min = double.infinity;
    for (var i = 0; i < pts.length - 1; i++) {
      final d = _pointSegmentMeters(p, pts[i], pts[i + 1]);
      if (d < min) min = d;
    }
    return min;
  }

  /// Jarak (meter) titik ke ruas garis AB (proyeksi ekuirektangular lokal).
  double _pointSegmentMeters(LatLng p, LatLng a, LatLng b) {
    const mPerDegLat = 111320.0;
    final latRad = p.latitude * math.pi / 180.0;
    final mPerDegLng = 111320.0 * math.cos(latRad);

    double sx(LatLng c) => (c.longitude - p.longitude) * mPerDegLng;
    double sy(LatLng c) => (c.latitude - p.latitude) * mPerDegLat;

    final ax = sx(a);
    final ay = sy(a);
    final bx = sx(b);
    final by = sy(b);
    final dx = bx - ax;
    final dy = by - ay;
    final lenSq = dx * dx + dy * dy;

    if (lenSq == 0) {
      return math.sqrt(ax * ax + ay * ay);
    }

    var t = ((-ax) * dx + (-ay) * dy) / lenSq;
    t = t.clamp(0.0, 1.0);
    final cx = ax + t * dx;
    final cy = ay + t * dy;
    return math.sqrt(cx * cx + cy * cy);
  }

  /// Jarak sisa (meter) di sepanjang polyline dari titik terdekat.
  double _routeRemainingMeters(LatLng p, List<LatLng> pts) {
    if (pts.isEmpty) return 0;
    if (pts.length == 1) return _distance.as(LengthUnit.Meter, p, pts.first);

    const mPerDegLat = 111320.0;
    final latRad = p.latitude * math.pi / 180.0;
    final mPerDegLng = 111320.0 * math.cos(latRad);

    double sx(LatLng c) => (c.longitude - p.longitude) * mPerDegLng;
    double sy(LatLng c) => (c.latitude - p.latitude) * mPerDegLat;

    final segs = <double>[];
    for (var i = 0; i < pts.length - 1; i++) {
      segs.add(_distance.as(LengthUnit.Meter, pts[i], pts[i + 1]));
    }
    final suffix = List<double>.filled(segs.length, 0);
    double acc = 0;
    for (var i = segs.length - 1; i >= 0; i--) {
      suffix[i] = acc;
      acc += segs[i];
    }

    double minDist = double.infinity;
    double remaining = acc; // total panjang rute sebagai default

    for (var i = 0; i < pts.length - 1; i++) {
      final a = pts[i];
      final b = pts[i + 1];
      final segLen = segs[i];

      // jarak titik ke segmen
      final ax = sx(a);
      final ay = sy(a);
      final bx = sx(b);
      final by = sy(b);
      final dx = bx - ax;
      final dy = by - ay;
      final lenSq = dx * dx + dy * dy;
      double d;
      if (lenSq == 0) {
        d = math.sqrt(ax * ax + ay * ay);
      } else {
        var t = ((-ax) * dx + (-ay) * dy) / lenSq;
        t = t.clamp(0.0, 1.0);
        final cx = ax + t * dx;
        final cy = ay + t * dy;
        d = math.sqrt(cx * cx + cy * cy);
      }

      if (d < minDist) {
        minDist = d;
        double along = 0;
        if (segLen > 0) {
          // proyeksi jarak dari a
          double alongT;
          if (lenSq == 0) {
            alongT = 0;
          } else {
            alongT = ((-ax) * dx + (-ay) * dy) / lenSq;
            alongT = alongT.clamp(0.0, 1.0);
          }
          along = alongT * segLen;
        }
        remaining = (segLen - along) + suffix[i];
      }
    }
    return math.max(0.0, remaining);
  }

  /// Memproyeksikan (snap) posisi ke garis rute terdekat
  LatLng _snapToPolyline(LatLng p, List<LatLng> pts) {
    if (pts.length < 2) return pts.isNotEmpty ? pts.first : p;

    const mPerDegLat = 111320.0;
    final latRad = p.latitude * math.pi / 180.0;
    final mPerDegLng = 111320.0 * math.cos(latRad);

    double sx(LatLng c) => (c.longitude - p.longitude) * mPerDegLng;
    double sy(LatLng c) => (c.latitude - p.latitude) * mPerDegLat;

    double minDist = double.infinity;
    LatLng snapped = p;

    for (var i = 0; i < pts.length - 1; i++) {
      final a = pts[i];
      final b = pts[i + 1];

      final ax = sx(a);
      final ay = sy(a);
      final bx = sx(b);
      final by = sy(b);
      final dx = bx - ax;
      final dy = by - ay;
      final lenSq = dx * dx + dy * dy;
      
      double d;
      double t;
      if (lenSq == 0) {
        d = math.sqrt(ax * ax + ay * ay);
        t = 0;
      } else {
        t = ((-ax) * dx + (-ay) * dy) / lenSq;
        t = t.clamp(0.0, 1.0);
        final cx = ax + t * dx;
        final cy = ay + t * dy;
        d = math.sqrt(cx * cx + cy * cy);
      }

      if (d < minDist) {
        minDist = d;
        snapped = LatLng(
          a.latitude + t * (b.latitude - a.latitude),
          a.longitude + t * (b.longitude - a.longitude),
        );
      }
    }
    
    // Snap ke rute (jangan gunakan offRouteThreshold agar selalu di garis biru)
    return snapped;
  }

  @override
  void dispose() {
    VoiceService().stopSpeaking();
    VoiceService().stopListening();
    _disposed = true;
    _positionSub?.cancel();
    _compassSub?.cancel();
    super.dispose();
  }
}