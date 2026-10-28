import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../data/models/address_model.dart';
import '../../services/maps/location_repository.dart';
import '../../services/shipping/rajaongkir_matcher_service.dart';
import '../../core/config/map_config.dart';
import 'dart:async';

/// Extended result from LocationPickerScreen that holds address details
/// and RajaOngkir matched region ID/data.
class LocationPickerResult extends Address {
  final Map<String, dynamic>? rajaOngkirMatch;
  final bool isRajaOngkirMatched;

  LocationPickerResult({
    required Address address,
    required super.latitude,
    required super.longitude,
    this.rajaOngkirMatch,
    this.isRajaOngkirMatched = false,
  }) : super(
          id: address.id,
          placeId: address.placeId,
          osmType: address.osmType,
          osmId: address.osmId,
          formattedAddress: address.formattedAddress,
          houseNumber: address.houseNumber,
          streetName: address.streetName,
          neighbourhood: address.neighbourhood,
          village: address.village,
          district: address.district,
          city: address.city,
          province: address.province,
          postalCode: address.postalCode,
          country: address.country,
          accuracy: address.accuracy,
          locationSource: address.locationSource,
          addressDetail: address.addressDetail,
        );
}

/// Comprehensive location picker screen (PRD §13–§18, §31).
///
/// Features:
/// - Address search with Nominatim → Photon fallback (PRD §5, §44)
/// - Autocomplete with debounce (PRD §7, §8)
/// - Manual pin placement (PRD §14)
/// - Current GPS location (PRD §16)
/// - Reverse geocoding on map move (PRD §17)
/// - RajaOngkir region auto-matching
/// - Location Preview Card with statuses and action buttons
class LocationPickerScreen extends StatefulWidget {
  final Address? initialAddress;
  final String? regionHint;
  final String title;

  const LocationPickerScreen({
    super.key,
    this.initialAddress,
    this.regionHint,
    this.title = 'Pilih Lokasi',
  });

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

  // RajaOngkir matching state
  Map<String, dynamic>? _rajaOngkirMatch;
  bool _isMatchingRegion = false;

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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _matchRajaOngkir(_currentAddress, _currentCenter);
      });
    } else {
      _currentCenter = const LatLng(
        MapConfig.defaultLatitude,
        MapConfig.defaultLongitude,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateAddressFromMap();
      });
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

  // ── Search ──────────────────────────────────────────────────────────

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
    _matchRajaOngkir(address, _currentCenter);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchResults = [];
      _showResults = false;
      _searchErrorMessage = '';
    });
  }

  // ── RajaOngkir Region Matching ─────────────────────────────────────

  Future<void> _matchRajaOngkir(Address? address, LatLng point) async {
    if (!mounted) return;
    setState(() {
      _isMatchingRegion = true;
    });

    try {
      final match = await RajaOngkirMatcherService.match(
        latitude: point.latitude,
        longitude: point.longitude,
        fullAddress: address?.formattedAddress,
        village: address?.village ?? address?.neighbourhood,
        district: address?.district,
        city: address?.city,
        province: address?.province,
      );

      if (mounted) {
        setState(() {
          _rajaOngkirMatch = match;
          _isMatchingRegion = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _rajaOngkirMatch = null;
          _isMatchingRegion = false;
        });
      }
    }
  }

  // ── Reverse Geocoding ──────────────────────────────────────────────

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
        await _matchRajaOngkir(address, _currentCenter);
      } else if (mounted) {
        await _matchRajaOngkir(_currentAddress, _currentCenter);
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

  // ── Current Location (GPS) ─────────────────────────────────────────

  Future<void> _useCurrentLocation() async {
    setState(() {
      _isGettingGps = true;
      _gpsAccuracyWarning = false;
    });

    try {
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

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final gpsLocation = LatLng(position.latitude, position.longitude);

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

  // ── Confirm Location ───────────────────────────────────────────────

  void _confirmLocation() {
    final Address baseAddr;
    if (_currentAddress != null) {
      baseAddr = _currentAddress!.copyWith(
        latitude: _currentCenter.latitude,
        longitude: _currentCenter.longitude,
        locationSource: 'manual_pin',
      );
    } else {
      baseAddr = Address(
        formattedAddress:
            'Lokasi (${_currentCenter.latitude.toStringAsFixed(6)}, ${_currentCenter.longitude.toStringAsFixed(6)})',
        latitude: _currentCenter.latitude,
        longitude: _currentCenter.longitude,
        locationSource: 'manual_pin',
      );
    }

    final result = LocationPickerResult(
      address: baseAddr,
      latitude: _currentCenter.latitude,
      longitude: _currentCenter.longitude,
      rajaOngkirMatch: _rajaOngkirMatch,
      isRajaOngkirMatched: _rajaOngkirMatch?['matched'] == true,
    );

    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Map ──
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

          // ── Center Pin ──
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

          // ── Search Bar ──
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

                // ── Search results ──
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
                        separatorBuilder: (_, _) => const Divider(height: 1),
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

          // ── Tombol: 📍 Gunakan Lokasi Saya ──
          Positioned(
            right: 16,
            bottom: 300,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(24),
              color: Colors.white,
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: _isGettingGps ? null : _useCurrentLocation,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isGettingGps)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFEC5B13),
                          ),
                        )
                      else
                        const Icon(
                          Icons.my_location,
                          size: 18,
                          color: Color(0xFFEC5B13),
                        ),
                      const SizedBox(width: 8),
                      const Text(
                        '📍 Gunakan Lokasi Saya',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFEC5B13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── GPS Accuracy Warning ──
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

          // ── Preview Lokasi Card (Section 8) ──
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
                    blurRadius: 16,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              padding: EdgeInsets.only(
                left: 18,
                right: 18,
                top: 16,
                bottom: MediaQuery.of(context).padding.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Loading Indicator Bar
                  if (_isReverseGeocoding || _isMatchingRegion)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: const LinearProgressIndicator(
                          minHeight: 3,
                          backgroundColor: Color(0xFFFFE0B2),
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEC5B13)),
                        ),
                      ),
                    ),

                  // Header: Lokasi Pengiriman
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEC5B13).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.local_shipping,
                          color: Color(0xFFEC5B13),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Lokasi Pengiriman',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const Spacer(),
                      if (_isReverseGeocoding || _isMatchingRegion)
                        const Row(
                          children: [
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFFEC5B13),
                              ),
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Memperbarui...',
                              style: TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 📍 Alamat
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.place, color: Color(0xFFEC5B13), size: 18),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Alamat',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _currentAddress?.formattedAddress ?? 'Memuat alamat...',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                                height: 1.25,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Wilayah RajaOngkir
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.apartment_rounded, color: Colors.blueGrey, size: 18),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Wilayah RajaOngkir',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _isMatchingRegion
                                  ? 'Mencocokkan wilayah...'
                                  : (_rajaOngkirMatch?['matched'] == true
                                      ? (_rajaOngkirMatch!['full_label'] ??
                                          '${_rajaOngkirMatch!['district_name']}, ${_rajaOngkirMatch!['city_name']}')
                                      : 'Wilayah belum dapat dicocokkan otomatis'),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _rajaOngkirMatch?['matched'] == true
                                    ? const Color(0xFF15803D)
                                    : Colors.orange.shade800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Koordinat
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.explore_outlined, color: Colors.grey, size: 18),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Koordinat',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_currentCenter.latitude.toStringAsFixed(6)}, ${_currentCenter.longitude.toStringAsFixed(6)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Status Badges (Section 8)
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      // Badge 1: Lokasi ditemukan
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF86EFAC)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle, size: 14, color: Color(0xFF16A34A)),
                            SizedBox(width: 4),
                            Text(
                              'Lokasi ditemukan',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF166534),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Badge 2: Wilayah RajaOngkir cocok
                      if (_rajaOngkirMatch?['matched'] == true)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF86EFAC)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle, size: 14, color: Color(0xFF16A34A)),
                              SizedBox(width: 4),
                              Text(
                                'Wilayah RajaOngkir cocok',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF166534),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFCD34D)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFD97706)),
                              SizedBox(width: 4),
                              Text(
                                'Wilayah belum cocok otomatis',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF92400E),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),

                  // Fallback warning if not matched
                  if (_rajaOngkirMatch != null &&
                      _rajaOngkirMatch?['matched'] != true &&
                      !_isMatchingRegion)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Color(0xFFB45309)),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Wilayah belum dapat dicocokkan secara otomatis. Silakan pilih wilayah secara manual di form.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF92400E),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 14),

                  // Action Buttons: [Ubah Lokasi] and [Gunakan Lokasi Ini]
                  Row(
                    children: [
                      // Ubah Lokasi Button
                      Expanded(
                        flex: 2,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey.shade700,
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Geser peta atau cari alamat di atas untuk mengubah lokasi.',
                                ),
                                duration: Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          child: const Text(
                            'Ubah Lokasi',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Gunakan Lokasi Ini Button
                      Expanded(
                        flex: 3,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.check, size: 18),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEC5B13),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            elevation: 2,
                          ),
                          onPressed: _confirmLocation,
                          label: const Text(
                            'Gunakan Lokasi Ini',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
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

  const _CircleButton({
    required this.icon,
    this.onTap,
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
          child: Icon(icon, size: 20, color: Colors.grey.shade800),
        ),
      ),
    );
  }
}
