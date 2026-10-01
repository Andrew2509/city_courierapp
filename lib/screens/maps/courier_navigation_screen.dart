import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../controllers/navigation_controller.dart';
import '../../core/config/map_config.dart';

/// Courier navigation screen (PRD §25–§31).
///
/// Features:
/// - Turn-by-turn instructions (PRD §26)
/// - GPS tracking with marker movement
/// - Off-route detection + rerouting (PRD §27, §28)
/// - Rerouting UI feedback (PRD §29)
/// - Destination arrival detection (PRD §30)
/// - Recenter / follow mode (PRD §48)
/// - All buttons functional (PRD §31)
class CourierNavigationScreen extends StatefulWidget {
  final Map<String, dynamic> order;
  final NavigationPhase initialPhase;

  const CourierNavigationScreen({
    Key? key,
    required this.order,
    this.initialPhase = NavigationPhase.pickup,
  }) : super(key: key);

  @override
  State<CourierNavigationScreen> createState() =>
      _CourierNavigationScreenState();
}

class _CourierNavigationScreenState extends State<CourierNavigationScreen> {
  late NavigationController _navController;
  final MapController _mapController = MapController();
  bool _isFollowingMode = true;

  @override
  void initState() {
    super.initState();
    _navController = NavigationController(
      order: widget.order,
      phase: widget.initialPhase,
    );
    _navController.addListener(_onNavUpdate);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navController.start();
    });
  }

  @override
  void dispose() {
    _navController.removeListener(_onNavUpdate);
    _navController.dispose();
    super.dispose();
  }

  void _onNavUpdate() {
    if (!mounted) return;

    // Update map camera in follow mode
    if (_isFollowingMode && _navController.currentLocation != null) {
        _mapController.move(
        _navController.currentLocation!,
        17.0,
      );
    }

    setState(() {});
  }

  void _toggleFollowMode() {
    setState(() {
      _isFollowingMode = !_isFollowingMode;
    });
    if (_isFollowingMode && _navController.currentLocation != null) {
      _mapController.move(_navController.currentLocation!, 17.0);
    }
  }

  void _cancelNavigation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar Navigasi?'),
        content: const Text('Apakah Anda yakin ingin menghentikan navigasi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close navigation
            },
            child: const Text(
              'Keluar',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _navController,
          builder: (context, _) {
            return _buildBody();
          },
        ),
      ),
    );
  }

  Widget _buildBody() {
    // ── Loading State ──
    if (_navController.status == NavigationStatus.initializing ||
        _navController.status == NavigationStatus.locating ||
        _navController.status == NavigationStatus.loadingRoute) {
      return _buildLoadingState();
    }

    // ── Permission Denied ──
    if (_navController.status == NavigationStatus.permissionDenied) {
      return _buildPermissionState();
    }

    // ── Location Disabled ──
    if (_navController.status == NavigationStatus.locationDisabled) {
      return _buildLocationDisabledState();
    }

    // ── Error State ──
    if (_navController.status == NavigationStatus.error) {
      return _buildErrorState();
    }

    // ── Navigation Mode ──
    return _buildNavigationMode();
  }

  // ── Loading ──
  Widget _buildLoadingState() {
    return Center(
      child: Container(
        color: Colors.white,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                children: [
                  CircularProgressIndicator(
                    color: Color(0xFFEC5B13),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Menghitung rute tercepat...',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Mohon tunggu sebentar',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Permission Denied ──
  Widget _buildPermissionState() {
    return Container(
      color: Colors.white,
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.location_off,
            size: 64,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          const Text(
            'Izin Lokasi Diperlukan',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Lokasi diperlukan untuk navigasi kurir.\n'
            'Silakan berikan izin lokasi atau pilih lokasi manual.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          if (!_navController.permissionPermanentlyDenied) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEC5B13),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => _navController.allowLocation(),
                child: const Text('Izinkan Lokasi'),
              ),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => _navController.openSettings(),
              child: const Text('Buka Pengaturan'),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Pilih Lokasi Manual'),
          ),
        ],
      ),
    );
  }

  // ── Location Disabled ──
  Widget _buildLocationDisabledState() {
    return Container(
      color: Colors.white,
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.gps_off,
            size: 64,
            color: Colors.orange,
          ),
          const SizedBox(height: 16),
          const Text(
            'GPS Non-aktif',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Layanan lokasi perangkat belum aktif.\n'
            'Silakan aktifkan GPS untuk navigasi.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEC5B13),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => _navController.allowLocation(),
              child: const Text('Aktifkan GPS'),
            ),
          ),
        ],
      ),
    );
  }

  // ── Error ──
  Widget _buildErrorState() {
    return Container(
      color: Colors.white,
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          const Text(
            'Terjadi Kesalahan',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _navController.errorMessage.isNotEmpty
                ? _navController.errorMessage
                : 'Tidak dapat menentukan rute.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEC5B13),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => _navController.retry(),
              child: const Text('Coba Lagi'),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kembali'),
          ),
        ],
      ),
    );
  }

  // ── Navigation Mode (PRD §25) ──
  Widget _buildNavigationMode() {
    final currentLoc = _navController.currentLocation;
    final route = _navController.route;
    final step = _navController.currentStep;
    final distRemaining = _navController.distanceRemaining;
    final durRemaining = _navController.durationRemainingSeconds;
    final isOffRoute = _navController.status == NavigationStatus.offRoute ||
        _navController.status == NavigationStatus.rerouting;
    final hasArrived = _navController.status == NavigationStatus.arrived;

    return Stack(
      children: [
        // ── Map ──
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: currentLoc ??
                LatLng(
                  MapConfig.defaultLatitude,
                  MapConfig.defaultLongitude,
                ),
            initialZoom: 17.0,
            onPositionChanged: (MapCamera camera, bool hasGesture) {
              if (hasGesture && _isFollowingMode) {
                setState(() {
                  _isFollowingMode = false;
                });
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.citycourier.app',
            ),

            // ── Route Polyline (PRD §24) ──
            if (route != null)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: route.coordinates,
                    color: const Color(0xFF3B82F6),
                    strokeWidth: 6.0,
                  ),
                ],
              ),

            // ── Markers ──
            MarkerLayer(markers: [
              // Pickup marker
              if (_navController.pickupLocation != null)
                Marker(
                  point: _navController.pickupLocation!,
                  width: 40,
                  height: 40,
                  child: const Icon(
                    Icons.inbox,
                    color: Colors.orange,
                    size: 32,
                  ),
                ),

              // Destination marker
              if (_navController.destination != null)
                Marker(
                  point: _navController.destination!,
                  width: 40,
                  height: 40,
                  child: const Icon(
                    Icons.flag,
                    color: Colors.green,
                    size: 32,
                  ),
                ),

              // Current position marker
              if (currentLoc != null)
                Marker(
                  point: currentLoc,
                  width: 40,
                  height: 40,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.navigation,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
            ]),
          ],
        ),

        // ── Off-Route Banner (PRD §29) ──
        if (isOffRoute)
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Rute diperbarui...\nMencari rute terbaik',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // ── Arrived Banner (PRD §30) ──
        if (hasArrived)
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Anda telah tiba di tujuan.',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // ── Top Direction Panel (PRD §26) ──
        if (step != null && !hasArrived)
          Positioned(
            top: isOffRoute ? 80 : 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getManeuverIcon(step.maneuver),
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          step.instruction,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_navController.distanceToNextManeuver > 0)
                          Text(
                            'Dalam ${_formatDistance(_navController.distanceToNextManeuver)}',
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

        // ── Recenter Button (PRD §31, §48) ──
        if (!_isFollowingMode)
          Positioned(
            right: 16,
            bottom: 220,
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              elevation: 4,
              child: InkWell(
                onTap: _toggleFollowMode,
                customBorder: const CircleBorder(),
                child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(
                    Icons.my_location,
                    size: 20,
                    color: Color(0xFF3B82F6),
                  ),
                ),
              ),
            ),
          ),

        // ── Cancel Navigation Button (PRD §31) ──
        Positioned(
          left: 16,
          bottom: hasArrived ? 170 : 130,
          child: Material(
            color: Colors.white,
            shape: const CircleBorder(),
            elevation: 4,
            child: InkWell(
              onTap: _cancelNavigation,
              customBorder: const CircleBorder(),
              child: const SizedBox(
                width: 44,
                height: 44,
                child: Icon(
                  Icons.close,
                  size: 20,
                  color: Colors.red,
                ),
              ),
            ),
          ),
        ),

        // ── Bottom Info Card ──
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 12,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(context).padding.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Target info
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.local_shipping,
                        color: Color(0xFFEC5B13),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _navController.title,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                          Text(
                            _navController.destinationLabel ?? 'Tujuan',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (_navController.route != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _formatDuration(durRemaining),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFEC5B13),
                            ),
                          ),
                          Text(
                            _formatDistance(distRemaining),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                // Arrived button (PRD §30, §31)
                if (hasArrived)
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 2,
                      ),
                      onPressed: () {
                        Navigator.pop(context, true);
                      },
                      icon: const Icon(Icons.check, size: 20),
                      label: const Text(
                        'KONFIRMASI TIBA',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  )
                else
                  // Start navigation / pickup button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEC5B13),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 2,
                      ),
                      onPressed: () {
                        if (_navController.phase == NavigationPhase.pickup) {
                          // After arriving at pickup, switch to delivery phase
                          _navController.switchPhase(NavigationPhase.delivery);
                        }
                      },
                      icon: const Icon(Icons.local_shipping, size: 20),
                      label: Text(
                        _navController.phase == NavigationPhase.pickup
                            ? 'PAKET SUDAH DIAMBIL'
                            : 'MENJALAN NAVIGASI',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Helpers ──

  IconData _getManeuverIcon(String? maneuver) {
    switch (maneuver) {
      case 'right':
        return Icons.turn_right;
      case 'left':
        return Icons.turn_left;
      case 'slight-right':
        return Icons.subdirectory_arrow_right;
      case 'slight-left':
        return Icons.subdirectory_arrow_left;
      case 'sharp-right':
        return Icons.turn_right;
      case 'sharp-left':
        return Icons.turn_left;
      case 'uturn':
        return Icons.u_turn_left;
      case 'arrive':
        return Icons.flag;
      case 'roundabout':
        return Icons.roundabout_right;
      default:
        return Icons.straight;
    }
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.round()} m';
  }

  String _formatDuration(double? seconds) {
    if (seconds == null) return '--:--';
    final mins = (seconds / 60).round();
    if (mins < 60) return '$mins mnt';
    final hours = mins ~/ 60;
    final remainMins = mins % 60;
    return '$hours j $remainMins mnt';
  }
}
