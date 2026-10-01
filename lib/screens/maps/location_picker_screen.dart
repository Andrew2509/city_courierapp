import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../data/models/address_model.dart';
import '../../services/maps/location_repository.dart';
import '../../core/config/map_config.dart';
import 'dart:async';

/// Comprehensive location picker screen (PRD §13–§18, §31).
///
/// Features:
/// - Address search with Nominatim → Photon fallback (PRD §5, §44)
/// - Autocomplete with debounce (PRD §7, §8)
/// - Manual pin placement (PRD §14)
/// - Current GPS location (PRD §16)
/// - Reverse geocoding on map move (PRD §17)
/// - Accuracy warning (PRD §18)
/// - Confirm location (PRD §15)
class LocationPickerScreen extends StatefulWidget {
  final Address? initialAddress;
  final String? regionHint;
  final String title;

  const LocationPickerScreen({
    Key? key,
    this.initialAddress,
    this.regionHint,
    this.title = 'Pilih Lokasi',
  }) : super(key: key);

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final MapController _mapController = MapController();
  final LocationRepository _locationRepository = LocationRepository();
  late LatLng _currentCenter;
  Address? _currentAddress;
  bool _isReverseGeocoding = false;
  bool _isGettingGps = false;
  bool _gpsAccuracyWarning = false;

  // Search state
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<Address> _searchResults = [];
  bool _isSearching = false;
  bool _showResults = false;
  String _searchErrorMessage = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    if (widget.initialAddress != null) {
      _currentCenter = LatLng(
        widget.initialAddress!.latitude,
        widget.initialAddress!.longitude,
      );
      _currentAddress = widget.initialAddress;
    } else {
      _currentCenter = const LatLng(
        MapConfig.defaultLatitude,
        MapConfig.defaultLongitude,
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounce?.cancel();
    _locationRepository.dispose();
    super.dispose();
  }

  // ── Search (PRD §6, §7, §8, §9) ──────────────────────────────────

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _showResults = false;
        _searchErrorMessage = '';
      });
      return;
    }

    _debounce = Timer(MapConfig.searchDebounceDuration, () async {
      setState(() {
        _isSearching = true;
        _searchErrorMessage = '';
        _showResults = true;
      });

      try {
        // 1) Search WITHOUT region hint first
        List<Address> results = await _locationRepository.searchAddress(query);

        // 2) If no results, try WITH region hint
        if (results.isEmpty && widget.regionHint != null && widget.regionHint!.isNotEmpty) {
          if (!query.toLowerCase().contains(widget.regionHint!.toLowerCase().split(',').first)) {
            results = await _locationRepository.searchAddress('$query, ${widget.regionHint}');
          }
        }

        if (mounted) {
          setState(() {
            _searchResults = results;
            _isSearching = false;
            if (results.isEmpty) {
              _searchErrorMessage = 'Alamat tidak ditemukan';
            }
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _searchResults = [];
            _isSearching = false;
            _searchErrorMessage = 'Pencarian gagal. Silakan coba lagi.';
          });
        }
      }
    });
  }

  void _onSelectSearchResult(Address address) {
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      _searchResults = [];
      _showResults = false;
      _currentCenter = LatLng(address.latitude, address.longitude);
      _currentAddress = address;
    });
    _mapController.move(_currentCenter, MapConfig.searchResultZoom);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchResults = [];
      _showResults = false;
      _searchErrorMessage = '';
    });
  }

  // ── Reverse Geocoding (PRD §17) ──────────────────────────────────

  Future<void> _updateAddressFromMap() async {
    if (_isReverseGeocoding) return;

    setState(() {
      _isReverseGeocoding = true;
    });

    try {
      final address = await _locationRepository.reverseGeocode(
        _currentCenter.latitude,
        _currentCenter.longitude,
      );

      if (address != null && mounted) {
        setState(() {
          _currentAddress = address;
        });
      }
    } catch (_) {
      // Reverse geocoding failed — keep previous address
    } finally {
      if (mounted) {
        setState(() {
          _isReverseGeocoding = false;
        });
      }
    }
  }

  // ── Current Location (PRD §16) ──────────────────────────────────

  Future<void> _useCurrentLocation() async {
    setState(() {
      _isGettingGps = true;
      _gpsAccuracyWarning = false;
    });

    try {
      // Check permission first
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          _showLocationServiceDisabled();
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (mounted) {
          _showPermissionDenied();
        }
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          _showPermissionPermanentlyDenied();
        }
        return;
      }

      // Get position with accuracy (PRD §18)
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final gpsLocation = LatLng(position.latitude, position.longitude);

      // Check accuracy (PRD §18)
      bool accurate = true;
      if (position.accuracy > MapConfig.gpsAccuracyWarningMeters) {
        accurate = false;
      }

      if (mounted) {
        setState(() {
          _currentCenter = gpsLocation;
          _gpsAccuracyWarning = !accurate;
        });

        _mapController.move(gpsLocation, MapConfig.searchResultZoom);

        // Reverse geocode to get address
        await _updateAddressFromMap();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal mendapatkan lokasi. Silakan coba lagi.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGettingGps = false;
        });
      }
    }
  }

  void _showLocationServiceDisabled() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lokasi Non-aktif'),
        content: const Text(
          'Layanan lokasi perangkat belum aktif.\n'
          'Silakan aktifkan GPS atau pilih lokasi secara manual di peta.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Geolocator.openLocationSettings();
            },
            child: const Text('Aktifkan GPS'),
          ),
        ],
      ),
    );
  }

  void _showPermissionDenied() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Izin lokasi ditolak. Silakan aktifkan izin lokasi atau pilih lokasi secara manual.',
        ),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 4),
      ),
    );
  }

  void _showPermissionPermanentlyDenied() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Izin Lokasi Diperlukan'),
        content: const Text(
          'Izin lokasi diperlukan untuk menggunakan fitur ini.\n'
          'Silakan aktifkan izin lokasi di pengaturan perangkat atau pilih lokasi secara manual.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Pilih Manual'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Geolocator.openAppSettings();
            },
            child: const Text('Buka Pengaturan'),
          ),
        ],
      ),
    );
  }

  // ── Confirm Location (PRD §15) ──────────────────────────────────

  void _confirmLocation() {
    // Build address with coordinates (PRD §15)
    final Address confirmedAddress;
    if (_currentAddress != null) {
      confirmedAddress = _currentAddress!.copyWith(
        latitude: _currentCenter.latitude,
        longitude: _currentCenter.longitude,
        locationSource: 'manual_pin',
      );
    } else {
      confirmedAddress = Address(
        formattedAddress: 'Lokasi yang dipilih',
        latitude: _currentCenter.latitude,
        longitude: _currentCenter.longitude,
        locationSource: 'manual_pin',
      );
    }

    Navigator.pop(context, confirmedAddress);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Map (PRD §13) ──
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentCenter,
              initialZoom: MapConfig.defaultZoom,
              onPositionChanged: (MapCamera camera, bool hasGesture) {
                if (hasGesture) {
                  _currentCenter = camera.center;
                }
              },
              onMapEvent: (MapEvent event) {
                if (event is MapEventMoveEnd) {
                  _updateAddressFromMap();
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.citycourier.app',
              ),
            ],
          ),

          // ── Center Pin (PRD §14) ──
          const Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 32.0),
              child: Icon(
                Icons.location_pin,
                size: 56,
                color: Colors.red,
              ),
            ),
          ),

          // ── Back button ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            child: _CircleButton(
              icon: Icons.arrow_back,
              onTap: () => Navigator.pop(context),
            ),
          ),

          // ── Search Bar (PRD §6) ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 64,
            right: 16,
            child: Column(
              children: [
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Cari alamat, jalan, tempat...',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: _clearSearch,
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),

                // ── Loading indicator ──
                if (_isSearching)
                  const Card(
                    margin: EdgeInsets.only(top: 4),
                    child: Padding(
                      padding: EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Mencari alamat...',
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),

                // ── Search error ──
                if (_searchErrorMessage.isNotEmpty && !_isSearching)
                  Card(
                    margin: const EdgeInsets.only(top: 4),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _searchErrorMessage,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.red,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Coba:\n• Periksa ejaan\n• Masukkan nama jalan\n• Pilih lokasi langsung di peta',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // ── Search results (PRD §7) ──
                if (_showResults && _searchResults.isNotEmpty)
                  Card(
                    elevation: 4,
                    margin: const EdgeInsets.only(top: 4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 250),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: _searchResults.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final address = _searchResults[index];
                          return ListTile(
                            dense: true,
                            leading: const Icon(
                              Icons.location_on,
                              color: Colors.grey,
                              size: 20,
                            ),
                            title: Text(
                              address.streetName ?? address.formattedAddress,
                              style: const TextStyle(fontSize: 13),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              [
                                address.district,
                                address.city,
                              ].where((e) => e != null).join(', '),
                              style: const TextStyle(fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => _onSelectSearchResult(address),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Current Location Button (PRD §16) ──
          Positioned(
            right: 16,
            bottom: 200,
            child: Column(
              children: [
                _CircleButton(
                  icon: Icons.my_location,
                  onTap: _isGettingGps ? null : _useCurrentLocation,
                  isLoading: _isGettingGps,
                ),
              ],
            ),
          ),

          // ── GPS Accuracy Warning (PRD §18) ──
          if (_gpsAccuracyWarning)
            Positioned(
              top: MediaQuery.of(context).padding.top + 80,
              left: 16,
              right: 16,
              child: Card(
                color: Colors.amber.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.amber.shade700, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Lokasi GPS kurang akurat. Silakan pindahkan pin untuk menentukan lokasi yang lebih tepat.',
                          style: TextStyle(fontSize: 12, color: Colors.black87),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => setState(() => _gpsAccuracyWarning = false),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── Bottom Info Card (PRD §15) ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).padding.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Loading indicator for reverse geocoding
                  if (_isReverseGeocoding) const LinearProgressIndicator(),

                  // Address display
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currentAddress?.formattedAddress ??
                                  'Memuat alamat...',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Koordinat: ${_currentCenter.latitude.toStringAsFixed(5)}, ${_currentCenter.longitude.toStringAsFixed(5)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Confirm button (PRD §15, §31)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEC5B13),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      onPressed: _confirmLocation,
                      child: const Text(
                        'KONFIRMASI LOKASI',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
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
    );
  }
}

/// Reusable circle button for map controls.
class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool isLoading;

  const _CircleButton({
    required this.icon,
    this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(icon, size: 20, color: Colors.grey.shade800),
        ),
      ),
    );
  }
}
