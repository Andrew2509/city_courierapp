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

class _ManeuverCheckpoint {
  final RouteStep step;
  final double triggerOffsetMeters;

  const _ManeuverCheckpoint({
    required this.step,
    required this.triggerOffsetMeters,
  });
}

class _PolylineProjection {
  final LatLng snappedPoint;
  final double distanceToPolylineMeters;
  final double remainingMeters;
  final double alongMeters;
  final double segmentBearing;

  const _PolylineProjection({
    required this.snappedPoint,
    required this.distanceToPolylineMeters,
    required this.remainingMeters,
    required this.alongMeters,
    required this.segmentBearing,
  });
}

/// Controller navigasi (PRD §35): memisahkan routing logic dari widget UI.
///
/// Menjalankan live location (GPS filtering + Android foreground service),
/// map matching kondisional, turn-by-turn dengan histeresis persimpangan,
/// progressive Indonesian TTS, deteksi off-route multi-pembacaan + rerouting,
/// dan arrival verification.
class NavigationController extends ChangeNotifier {
  final Map<String, dynamic> order;
  final RoutingService routingService;
  final double arrivalRadiusMeters;
  final double approachingRadiusMeters;
  final int requiredArrivalReadings;
  final int requiredOffRouteReadings;
  final String travelMode;
  final Duration rerouteCooldownDuration;

  /// Fase saat ini — dapat berubah setelah paket diambil (PRD §7).
  NavigationPhase phase;

  NavigationStatus status = NavigationStatus.initializing;
  Function(String command)? onVoiceCommand;

  LatLng? currentLocation;
  double? heading;
  double? gpsHeading;
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
  double currentSpeedMs = 0.0;

  /// Radius kedatangan (meter) default.
  static const double arrivalRadius = 40.0;

  /// Jarak penyimpangan dari jalur yang memicu rerouting (meter).
  static const double offRouteThreshold = 40.0;

  /// Jarak maksimal snap-to-road agar marker keluar jalur tidak dipaksa kembali ke polyline.
  static const double maxSnapDistanceMeters = 28.0;

  /// Cooldown antar rerouting agar tidak membanjiri API.
  static const Duration rerouteCooldown = Duration(seconds: 15);

  final Distance _distance = const Distance();
  StreamSubscription<Position>? _positionSub;
  StreamSubscription<CompassEvent>? _compassSub;
  DateTime? _lastRouteAt;
  DateTime? _lastValidFixAt;
  bool _rerouteInFlight = false;
  bool _disposed = false;
  LatLng? _bearingAnchor;

  List<double> _polyCumDist = const [];
  List<_ManeuverCheckpoint> _checkpoints = const [];
  int _activeCheckpointIdx = 0;
  int _routeVersion = 0;
  final Set<String> _spokenCueKeys = <String>{};

  _PolylineProjection? _lastProjection;
  int _consecutiveOffRouteCount = 0;
  int _consecutiveArrivalCount = 0;

  NavigationController({
    required this.order,
    required this.phase,
    RoutingService? routingService,
    this.arrivalRadiusMeters = arrivalRadius,
    this.approachingRadiusMeters = 120.0,
    this.requiredArrivalReadings = 2,
    this.requiredOffRouteReadings = 3,
    this.travelMode = 'motorcycle',
    this.rerouteCooldownDuration = rerouteCooldown,
  }) : routingService = routingService ?? CityCourierRoutingService() {
    VoiceService().onStatusChanged = (status) {
      if (status == 'notListening' && isMicEnabled) {
        isMicEnabled = false;
        notifyListeners();
      }
    };
  }

  /// True hanya ketika kurir masih berada di koridor jalan rute (<= 28 m).
  bool get isSnappedToRoute {
    final proj = _lastProjection;
    if (route == null || currentLocation == null || proj == null) return false;
    if (status == NavigationStatus.offRoute ||
        status == NavigationStatus.rerouting) {
      return false;
    }
    return proj.distanceToPolylineMeters <= maxSnapDistanceMeters;
  }

  /// Posisi marker di peta: snap ke garis bila masih di jalur, atau GPS aktual bila keluar jalur.
  LatLng? get snappedLocation {
    final cur = currentLocation;
    if (cur == null) return null;
    if (isSnappedToRoute && _lastProjection != null) {
      return _lastProjection!.snappedPoint;
    }
    return cur;
  }

  /// Arah (bearing) dari segmen rute terdekat saat ini.
  double? get routeHeading => _lastProjection?.segmentBearing;

  /// Prioritas arah kendaraan: GPS course/bearing saat bergerak, lalu segmen rute / kompas saat diam.
  double get effectiveVehicleHeading {
    if (speedKmH >= 3.5 && gpsHeading != null) {
      return gpsHeading!;
    }
    return routeHeading ?? gpsHeading ?? heading ?? deviceHeading ?? 0.0;
  }

  bool get hasRoute => route != null;
  bool get hasArrived => status == NavigationStatus.arrived;
  bool get isOnRoute => status == NavigationStatus.navigating;
  bool get isApproachingDestination =>
      status == NavigationStatus.navigating &&
      distanceRemaining > arrivalRadiusMeters &&
      distanceRemaining <= approachingRadiusMeters;
  int get offRouteReadingCount => _consecutiveOffRouteCount;
  int get arrivalReadingCount => _consecutiveArrivalCount;

  /// Peringatan GPS kurang akurat (PRD §25).
  bool get accuracyWarning {
    final a = gpsAccuracy;
    return a != null && a > 80.0;
  }

  String get title =>
      phase == NavigationPhase.pickup ? 'Menuju Pengirim' : 'Menuju Penerima';

  /// Progres 0..1 sepanjang rute aktual.
  double get progress {
    final r = route;
    if (r == null || r.coordinates.isEmpty) return 0;
    final total = _totalRouteDistanceMeters(r);
    if (total <= 0) return 0;
    final along = _lastProjection?.alongMeters ?? (total - distanceRemaining);
    return (along / total).clamp(0.0, 1.0);
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
    return _lastProjection?.remainingMeters ??
        _projectOntoPolyline(cur, route!.coordinates, _polyCumDist)
            .remainingMeters;
  }

  double? get durationRemainingSeconds {
    final r = route;
    if (r == null) return null;
    final totalDist = _totalRouteDistanceMeters(r);
    if (totalDist <= 0) return r.durationSeconds;
    final fracRemaining = (distanceRemaining / totalDist).clamp(0.0, 1.0);
    return r.durationSeconds * fracRemaining;
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
        if (lower.contains('selesai') ||
            lower.contains('tiba') ||
            lower.contains('sampai')) {
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

  /// Instruksi manuver berikutnya yang harus segera dijalankan kurir (dengan histeresis).
  RouteStep? get currentStep {
    if (_checkpoints.isNotEmpty) {
      return _checkpoints[_activeCheckpointIdx.clamp(0, _checkpoints.length - 1)]
          .step;
    }
    final r = route;
    if (r == null || r.steps.isEmpty) return null;
    return r.steps.first;
  }

  /// Jarak tersisa menuju titik belokan / manuver aktif (meter).
  double get distanceToNextManeuver {
    final r = route;
    if (r == null || _checkpoints.isEmpty) return 0;
    final idx = _activeCheckpointIdx.clamp(0, _checkpoints.length - 1);
    final trigger = _checkpoints[idx].triggerOffsetMeters;
    final along = _lastProjection?.alongMeters ?? (r.distanceMeters * progress);
    return math.max(0.0, trigger - along);
  }

  /// Manuver SETELAH belokan aktif ("Kemudian: ..."), untuk sub-panel hijau gelap ala Google Maps.
  RouteStep? get thenStep {
    if (_checkpoints.isEmpty) return null;
    final nextIdx = _activeCheckpointIdx + 1;
    if (nextIdx >= _checkpoints.length) return null;
    return _checkpoints[nextIdx].step;
  }

  /// Manuver berikutnya (alias konsisten untuk widget eksternal).
  RouteStep? get nextStep => thenStep ?? currentStep;

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

  LocationSettings _buildLocationSettings() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
        intervalDuration: const Duration(seconds: 1),
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: 'Navigasi City Courier Aktif',
          notificationText: phase == NavigationPhase.pickup
              ? 'Menuju lokasi penjemputan pengirim...'
              : 'Menuju alamat penerima paket...',
          notificationChannelName: 'Navigasi Kurir',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }

    return const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 5,
      timeLimit: Duration(seconds: 30),
    );
  }

  Future<void> _startListening() async {
    final settings = _buildLocationSettings();

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 20),
        ),
      );
      _onPosition(pos);
    } catch (_) {
      // Belum ada fix — stream akan memberikan posisi saat tersedia.
    }

    if (_disposed) return;
    await _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen(
      _onPosition,
      onError: (Object _) {
        if (!_disposed && currentLocation == null) {
          status = NavigationStatus.locationDisabled;
          notifyListeners();
        }
      },
    );

    await _compassSub?.cancel();
    _compassSub = FlutterCompass.events?.listen((CompassEvent event) {
      if (_disposed) return;
      if (event.heading != null) {
        final newHeading =
            event.heading! >= 0 ? event.heading! : 360 + event.heading!;
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
    headingAccuracy = p.headingAccuracy;
    ingestGpsSample(
      latitude: p.latitude,
      longitude: p.longitude,
      accuracy: p.accuracy,
      speedMs: p.speed,
      headingDeg: p.heading,
      timestamp: p.timestamp,
    );
  }

  /// Memproses pembacaan GPS dengan noise filtering, smoothing kecepatan/bearing,
  /// evaluasi progres turn-by-turn, rerouting multi-pembacaan, dan arrival verification.
  @visibleForTesting
  void ingestGpsSample({
    required double latitude,
    required double longitude,
    double accuracy = 10.0,
    double speedMs = 0.0,
    double headingDeg = -1.0,
    DateTime? timestamp,
  }) {
    if (_disposed || latitude.isNaN || longitude.isNaN) return;

    final now = timestamp ?? DateTime.now();
    final rawPoint = LatLng(latitude, longitude);
    gpsAccuracy = accuracy;

    // Abaikan pembacaan GPS yang sangat tidak akurat ketika posisi sebelumnya sudah ada.
    if (currentLocation != null && route != null && accuracy > 65.0) {
      notifyListeners();
      return;
    }

    // Tolak lompatan koordinat yang tidak masuk akal (GPS spike > 55 m/s saat akurasi buruk).
    if (currentLocation != null && _lastValidFixAt != null) {
      final dtSec = now.difference(_lastValidFixAt!).inMilliseconds / 1000.0;
      final jump = _distance.as(LengthUnit.Meter, currentLocation!, rawPoint);
      if (dtSec > 0 && dtSec <= 5.0 && (jump / dtSec) > 55.0 && accuracy > 20.0) {
        return;
      }

      // Perhalus jitter kecil ketika kendaraan berhenti / akurasi moderat.
      if (jump < 3.5 && accuracy > 15.0) {
        currentLocation = LatLng(
          currentLocation!.latitude * 0.65 + rawPoint.latitude * 0.35,
          currentLocation!.longitude * 0.65 + rawPoint.longitude * 0.35,
        );
      } else {
        currentLocation = rawPoint;
      }
    } else {
      currentLocation = rawPoint;
    }

    _lastValidFixAt = now;
    currentSpeedMs = speedMs >= 0 ? speedMs : 0.0;

    // Prioritaskan course/bearing GPS saat kendaraan bergerak sebelum fallback ke pergerakan/kompas.
    if (currentSpeedMs >= 1.5 && headingDeg >= 0 && headingDeg <= 360.0) {
      gpsHeading = _smoothAngleDeg(gpsHeading, headingDeg);
      heading = gpsHeading;
    } else if (_bearingAnchor != null) {
      final moved = _distance.as(LengthUnit.Meter, _bearingAnchor!, currentLocation!);
      if (moved >= 6.0 && accuracy <= 35.0) {
        final derived = _bearing(_bearingAnchor!, currentLocation!);
        gpsHeading = _smoothAngleDeg(gpsHeading, derived);
        heading = gpsHeading;
        _bearingAnchor = currentLocation!;
      }
    } else {
      _bearingAnchor = currentLocation!;
    }

    if (route == null) {
      unawaited(_requestRoute());
    } else {
      _evaluateNavigation();
    }
    notifyListeners();
  }

  static double _smoothAngleDeg(double? currentDeg, double targetDeg) {
    if (currentDeg == null) return (targetDeg + 360) % 360;
    var diff = (targetDeg - currentDeg + 540) % 360 - 180;
    return (currentDeg + diff * 0.45 + 360) % 360;
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

    if (r == null) {
      unawaited(_requestRoute());
      return;
    }

    final proj = _projectOntoPolyline(cur, r.coordinates, _polyCumDist);
    _lastProjection = proj;

    if (status == NavigationStatus.arrived) return;

    // 1. Cek kedatangan (butuh beberapa pembacaan valid berturut-turut untuk hindari false arrival).
    final destDist = _distance.as(LengthUnit.Meter, cur, dest);
    final validAccuracyForArrival = gpsAccuracy == null || gpsAccuracy! <= 50.0;
    if (destDist <= arrivalRadiusMeters && validAccuracyForArrival) {
      _consecutiveArrivalCount++;
      if (_consecutiveArrivalCount >= requiredArrivalReadings) {
        status = NavigationStatus.arrived;
        _consecutiveOffRouteCount = 0;
        _checkVoiceInstructions();
        return;
      }
    } else {
      _consecutiveArrivalCount = 0;
    }

    // 2. Maju step navigasi turn-by-turn secara monotonik (histeresis 14 meter setelah titik manuver).
    if (_checkpoints.isNotEmpty) {
      while (_activeCheckpointIdx < _checkpoints.length - 1) {
        final cp = _checkpoints[_activeCheckpointIdx];
        if (proj.alongMeters > cp.triggerOffsetMeters + 14.0) {
          _activeCheckpointIdx++;
        } else {
          break;
        }
      }
    }

    // 3. Deteksi keluar jalur (butuh akurasi memadai & beberapa pembacaan berturut-turut sebelum reroute).
    final offDist = proj.distanceToPolylineMeters;
    final validAccuracyForReroute = gpsAccuracy == null || gpsAccuracy! <= 45.0;
    if (offDist > offRouteThreshold && validAccuracyForReroute) {
      _consecutiveOffRouteCount++;
      if (_consecutiveOffRouteCount >= requiredOffRouteReadings && _canReroute()) {
        status = NavigationStatus.offRoute;
        _consecutiveOffRouteCount = 0;
        unawaited(_requestRoute(isReroute: true));
      }
    } else {
      _consecutiveOffRouteCount = 0;
      if (status == NavigationStatus.offRoute ||
          status == NavigationStatus.loadingRoute) {
        if (!_rerouteInFlight) {
          status = NavigationStatus.navigating;
        }
      }
    }

    _checkVoiceInstructions();
  }

  void _checkVoiceInstructions() {
    if (!soundEnabled) return;

    if (status == NavigationStatus.arrived) {
      final arrKey = 'arrived_${phase.name}_$_routeVersion';
      if (_spokenCueKeys.add(arrKey)) {
        final target = phase == NavigationPhase.pickup ? 'pengirim' : 'penerima';
        VoiceService().speak(
          'Anda telah tiba di lokasi $target.',
          interrupt: true,
        );
      }
      return;
    }

    if (isApproachingDestination) {
      final nearKey = 'approaching_${phase.name}_$_routeVersion';
      if (_spokenCueKeys.add(nearKey)) {
        final target = phase == NavigationPhase.pickup ? 'pengirim' : 'penerima';
        VoiceService().speak('Anda sudah dekat dengan lokasi $target.');
        return;
      }
    }

    final step = currentStep;
    if (step == null || _checkpoints.isEmpty) return;

    final idx = _activeCheckpointIdx;
    final dist = distanceToNextManeuver;

    if (dist <= 35.0) {
      final nowKey = 'now_${_routeVersion}_$idx';
      if (_spokenCueKeys.add(nowKey)) {
        VoiceService().speak(step.instruction, interrupt: true);
      }
      return;
    }

    if (dist <= 150.0 && dist >= 65.0) {
      final prepKey = 'prep_${_routeVersion}_$idx';
      if (_spokenCueKeys.add(prepKey)) {
        final rounded = (dist / 10).round() * 10;
        VoiceService().speak('Dalam $rounded meter, ${step.instruction}');
      }
      return;
    }

    if (dist <= 480.0 && dist >= 240.0) {
      final farKey = 'far_${_routeVersion}_$idx';
      if (_spokenCueKeys.add(farKey)) {
        final rounded = (dist / 50).round() * 50;
        VoiceService().speak('Dalam $rounded meter, ${step.instruction}');
      }
    }
  }

  bool _canReroute() {
    if (_rerouteInFlight) return false;
    if (_lastRouteAt == null) return true;
    return DateTime.now().difference(_lastRouteAt!) >= rerouteCooldownDuration;
  }

  Future<void> _requestRoute({bool isReroute = false}) async {
    if (_rerouteInFlight) return;
    final cur = currentLocation;
    final dest = destination;
    if (cur == null || dest == null) return;

    _rerouteInFlight = true;
    final isFirst = route == null && !isReroute;
    status = isFirst ? NavigationStatus.loadingRoute : NavigationStatus.rerouting;
    notifyListeners();

    try {
      final r = await routingService.getRoute(
        origin: cur,
        destination: dest,
        profile: travelMode,
      );
      if (_disposed) return;

      _assignActiveRoute(r, fromReroute: isReroute);
      _lastRouteAt = DateTime.now();

      final destDist = _distance.as(LengthUnit.Meter, cur, dest);
      if (destDist <= arrivalRadiusMeters) {
        _consecutiveArrivalCount = requiredArrivalReadings;
        status = NavigationStatus.arrived;
        _checkVoiceInstructions();
      } else {
        status = NavigationStatus.navigating;
        if (isReroute && soundEnabled) {
          final rerouteKey = 'reroute_$_routeVersion';
          if (_spokenCueKeys.add(rerouteKey)) {
            VoiceService().speak('Rute diperbarui.', interrupt: true);
          }
        }
        _evaluateNavigation();
      }
    } catch (e) {
      if (_disposed) return;
      if (route == null) {
        errorMessage = e is RoutingException
            ? e.message
            : 'Tidak dapat menentukan rute.\nPeriksa koneksi internet Anda dan coba lagi.';
        status = NavigationStatus.error;
      } else {
        status = NavigationStatus.navigating;
      }
    } finally {
      _rerouteInFlight = false;
      if (!_disposed) notifyListeners();
    }
  }

  void _assignActiveRoute(RouteModel r, {bool fromReroute = false}) {
    route = r;
    _routeVersion++;
    _activeCheckpointIdx = 0;
    _consecutiveOffRouteCount = 0;
    _consecutiveArrivalCount = 0;
    _spokenCueKeys.clear();
    if (!fromReroute) {
      // Jangan putar suara duplikat saat baru masuk
    }
    _polyCumDist = _buildCumulativeDistances(r.coordinates);
    _checkpoints = _buildManeuverCheckpoints(r);
    if (currentLocation != null && r.coordinates.isNotEmpty) {
      _lastProjection =
          _projectOntoPolyline(currentLocation!, r.coordinates, _polyCumDist);
      // Skip checkpoint awal yang sudah terlewati oleh posisi start.
      while (_activeCheckpointIdx < _checkpoints.length - 1 &&
          _lastProjection!.alongMeters >
              _checkpoints[_activeCheckpointIdx].triggerOffsetMeters + 14.0) {
        _activeCheckpointIdx++;
      }
    } else {
      _lastProjection = null;
    }
  }

  List<_ManeuverCheckpoint> _buildManeuverCheckpoints(RouteModel r) {
    final steps = r.steps;
    if (steps.isEmpty) return const [];

    final totalDist = _totalRouteDistanceMeters(r);
    final checkpoints = <_ManeuverCheckpoint>[];
    final usesTomTomOffsets = steps.any((s) => s.isTomTomStep);

    if (usesTomTomOffsets) {
      double fallbackCum = 0.0;
      for (int i = 0; i < steps.length; i++) {
        final s = steps[i];
        final offset = s.routeOffsetMeters ?? fallbackCum;
        fallbackCum += s.distanceMeters;
        final isTrivialDepart =
            i == 0 && steps.length > 1 && offset <= 10.0 && (steps[1].routeOffsetMeters ?? 0) > 15.0;
        if (isTrivialDepart) continue;
        checkpoints.add(
          _ManeuverCheckpoint(
            step: s,
            triggerOffsetMeters: offset.clamp(0.0, totalDist > 0 ? totalDist : offset),
          ),
        );
      }
    } else {
      if (steps.length == 1) {
        checkpoints.add(
          _ManeuverCheckpoint(
            step: steps.first,
            triggerOffsetMeters: totalDist,
          ),
        );
      } else {
        double cum = 0.0;
        for (int i = 0; i < steps.length - 1; i++) {
          cum += math.max(0.0, steps[i].distanceMeters);
          checkpoints.add(
            _ManeuverCheckpoint(
              step: steps[i + 1],
              triggerOffsetMeters: cum.clamp(0.0, totalDist > 0 ? totalDist : cum),
            ),
          );
        }
      }
    }

    if (checkpoints.isEmpty) {
      checkpoints.add(
        _ManeuverCheckpoint(
          step: steps.last,
          triggerOffsetMeters: totalDist,
        ),
      );
    }

    return checkpoints;
  }

  /// Menerapkan rute alternatif atau rute simulasi/eksternal yang dipilih secara sadar oleh kurir.
  void applyAlternativeRoute(RouteModel selectedRoute) {
    if (_disposed || selectedRoute.coordinates.length < 2) return;
    _assignActiveRoute(selectedRoute);
    _lastRouteAt = DateTime.now();
    status = NavigationStatus.navigating;
    _evaluateNavigation();
    if (soundEnabled) {
      final routeKey = 'reroute_$_routeVersion';
      if (_spokenCueKeys.add(routeKey)) {
        VoiceService().speak('Rute alternatif diaktifkan.', interrupt: true);
      }
    }
    notifyListeners();
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

  double _totalRouteDistanceMeters(RouteModel r) {
    if (r.distanceMeters > 0) return r.distanceMeters;
    if (_polyCumDist.isNotEmpty) return _polyCumDist.last;
    return _geomLength(r.coordinates);
  }

  static double _geomLength(List<LatLng> pts) {
    if (pts.length < 2) return 0;
    const d = Distance();
    double sum = 0;
    for (var i = 0; i < pts.length - 1; i++) {
      sum += d.as(LengthUnit.Meter, pts[i], pts[i + 1]);
    }
    return sum;
  }

  List<double> _buildCumulativeDistances(List<LatLng> pts) {
    if (pts.isEmpty) return const [];
    final cum = List<double>.filled(pts.length, 0.0);
    for (var i = 1; i < pts.length; i++) {
      cum[i] = cum[i - 1] + _distance.as(LengthUnit.Meter, pts[i - 1], pts[i]);
    }
    return cum;
  }

  /// Proyeksi tunggal GPS ke polyline rute: jarak tegak lurus, titik snap,
  /// jarak tempuh dari awal, sisa jarak ke tujuan, dan bearing segmen.
  _PolylineProjection _projectOntoPolyline(
    LatLng p,
    List<LatLng> pts,
    List<double> cumDist,
  ) {
    if (pts.isEmpty) {
      return _PolylineProjection(
        snappedPoint: p,
        distanceToPolylineMeters: 0.0,
        remainingMeters: 0.0,
        alongMeters: 0.0,
        segmentBearing: heading ?? 0.0,
      );
    }
    if (pts.length == 1) {
      final d = _distance.as(LengthUnit.Meter, p, pts.first);
      return _PolylineProjection(
        snappedPoint: pts.first,
        distanceToPolylineMeters: d,
        remainingMeters: d,
        alongMeters: 0.0,
        segmentBearing: heading ?? 0.0,
      );
    }

    const mPerDegLat = 111320.0;
    final latRad = p.latitude * math.pi / 180.0;
    final mPerDegLng = 111320.0 * math.cos(latRad);

    double sx(LatLng c) => (c.longitude - p.longitude) * mPerDegLng;
    double sy(LatLng c) => (c.latitude - p.latitude) * mPerDegLat;

    final totalDist = cumDist.length == pts.length ? cumDist.last : _geomLength(pts);
    double minDist = double.infinity;
    LatLng snapped = pts.first;
    double alongBest = 0.0;
    double bestBearing = heading ?? 0.0;

    for (var i = 0; i < pts.length - 1; i++) {
      final a = pts[i];
      final b = pts[i + 1];
      final segStartAlong = i < cumDist.length ? cumDist[i] : 0.0;
      final segEndAlong = (i + 1) < cumDist.length ? cumDist[i + 1] : totalDist;
      final segLen = math.max(0.0, segEndAlong - segStartAlong);

      final ax = sx(a);
      final ay = sy(a);
      final bx = sx(b);
      final by = sy(b);
      final dx = bx - ax;
      final dy = by - ay;
      final lenSq = dx * dx + dy * dy;

      final double t = lenSq == 0
          ? 0.0
          : (((-ax) * dx + (-ay) * dy) / lenSq).clamp(0.0, 1.0);
      final cx = ax + t * dx;
      final cy = ay + t * dy;
      final d = math.sqrt(cx * cx + cy * cy);

      if (d < minDist) {
        minDist = d;
        snapped = LatLng(
          a.latitude + t * (b.latitude - a.latitude),
          a.longitude + t * (b.longitude - a.longitude),
        );
        alongBest = segStartAlong + (t * segLen);
        bestBearing = _bearing(a, b);
      }
    }

    return _PolylineProjection(
      snappedPoint: snapped,
      distanceToPolylineMeters: minDist,
      remainingMeters: math.max(0.0, totalDist - alongBest),
      alongMeters: alongBest,
      segmentBearing: bestBearing,
    );
  }

  /// Hentikan tracking GPS & panduan suara ketika navigasi berakhir.
  void stopTracking() {
    VoiceService().stopSpeaking();
    VoiceService().stopListening();
    _positionSub?.cancel();
    _positionSub = null;
    _compassSub?.cancel();
    _compassSub = null;
  }

  @override
  void dispose() {
    stopTracking();
    _disposed = true;
    super.dispose();
  }
}