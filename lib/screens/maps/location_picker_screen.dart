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

/// GoSend-styled interactive location picker screen.
///
/// Visual features matching GoSend design:
/// - Orange circular center pin with white down arrow and ground target indicator
/// - White bottom sheet card titled "Set lokasi pengiriman"
/// - Orange down arrow badge next to bold street name and full address
/// - Full-width green "Lanjut" button
/// - Floating circular Back button at bottom-left above the sheet
/// - Floating circular GPS/My Location button at bottom-right above the sheet
/// - Subtle RajaOngkir region auto-matching
class LocationPickerScreen extends StatefulWidget {
  final Address? initialAddress;
  final String? regionHint;
  final String title;

  const LocationPickerScreen({
    super.key,
    this.initialAddress,
    this.regionHint,
    this.title = 'Set lokasi pengiriman',
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

  // ── Address Text Helpers (GoSend 2-tier format) ───────────────────

  String _getAddressPrimaryText(Address address) {
    final street = address.streetName;
    final houseNo = address.houseNumber;
    if (street != null && street.trim().isNotEmpty) {
      if (houseNo != null && houseNo.trim().isNotEmpty) {
        return '$street No. $houseNo';
      }
      return street;
    }
    final raw = address.formattedAddress.trim();
    if (raw.isNotEmpty) {
      final parts = raw.split(',');
      if (parts.isNotEmpty && parts.first.trim().isNotEmpty) {
        return parts.first.trim();
      }
      return raw;
    }
    return 'Titik Lokasi';
  }

  String _getAddressSecondaryText(Address address) {
    final parts = <String>[];
    if (address.village != null && address.village!.trim().isNotEmpty) {
      parts.add(address.village!.trim());
    }
    if (address.district != null && address.district!.trim().isNotEmpty) {
      parts.add('Kec. ${address.district!.trim()}');
    }
    if (address.city != null && address.city!.trim().isNotEmpty) {
      parts.add(address.city!.trim());
    }
    if (address.province != null && address.province!.trim().isNotEmpty) {
      parts.add(address.province!.trim());
    }
    if (parts.isNotEmpty) {
      return parts.join(', ');
    }
    return address.formattedAddress;
  }

  String get _addressMainTitle {
    if (_isReverseGeocoding) return 'Menentukan lokasi...';
    if (_currentAddress == null) return 'Pilih lokasi pada peta';

    return _getAddressPrimaryText(_currentAddress!);
  }

  String get _addressSubTitle {
    if (_isReverseGeocoding) return 'Sedang memuat alamat lengkap...';
    if (_currentAddress == null) {
      return 'Geser pin pada peta untuk menandai lokasi yang tepat';
    }
    return _currentAddress!.formattedAddress;
  }

  // ── Search (Photon search-as-you-type with proximity bias) ─────────

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    if (query.trim().isEmpty) {
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
        // Bias search results towards current map center via Photon
        List<Address> results = await _locationRepository.searchAddress(
          query.trim(),
          latitude: _currentCenter.latitude,
          longitude: _currentCenter.longitude,
          limit: 6,
        );

        if (results.isEmpty && widget.regionHint != null && widget.regionHint!.isNotEmpty) {
          final hintPart = widget.regionHint!.split(',').first.trim();
          if (!query.toLowerCase().contains(hintPart.toLowerCase())) {
            results = await _locationRepository.searchAddress(
              '$query, ${widget.regionHint}',
              latitude: _currentCenter.latitude,
              longitude: _currentCenter.longitude,
              limit: 6,
            );
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
      _searchErrorMessage = '';
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

  void _zoomIn() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_currentCenter, (currentZoom + 1).clamp(3.0, 19.0));
  }

  void _zoomOut() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_currentCenter, (currentZoom - 1).clamp(3.0, 19.0));
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
        postalCode: address?.postalCode,
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
      // Keep previous address on failure
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

  // ── Confirm Location ("Lanjut") ────────────────────────────────────

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
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // ── 1. Full-screen Map ──
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

          // ── 2. Center Pin (GoSend Orange Circle with White Down Arrow & Blue Ground Dot) ──
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEC5B13), // GoSend orange
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.28),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.arrow_downward_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7), // Blue ground target dot
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.35),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── 3. Floating Search Bar (Top) ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: Column(
              children: [
                Material(
                  elevation: 3,
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white,
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: _onSearchChanged,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Cari alamat, jalan, atau tempat...',
                      hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: _clearSearch,
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),

                // Search Loading
                if (_isSearching)
                  Card(
                    margin: const EdgeInsets.only(top: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Mencari alamat...',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Search Results (Kryonex & Photon styled suggestions)
                if (_showResults && _searchResults.isNotEmpty)
                  Card(
                    elevation: 6,
                    margin: const EdgeInsets.only(top: 4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 250),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: _searchResults.length,
                        separatorBuilder: (_, _) => Divider(height: 1, color: Colors.grey.shade200),
                        itemBuilder: (context, index) {
                          final address = _searchResults[index];
                          final primary = _getAddressPrimaryText(address);
                          final secondary = _getAddressSecondaryText(address);
                          return InkWell(
                            onTap: () => _onSelectSearchResult(address),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    margin: const EdgeInsets.only(top: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF7ED),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.location_on,
                                      color: Color(0xFFEC5B13),
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          primary,
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF111827),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          secondary,
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: Colors.grey.shade600,
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
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                // Search Not Found Message
                if (_showResults && !_isSearching && _searchErrorMessage.isNotEmpty)
                  Card(
                    margin: const EdgeInsets.only(top: 4),
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, size: 18, color: Colors.orange.shade800),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _searchErrorMessage,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Periksa kata kunci atau geser pin langsung pada peta ke titik tujuan.',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── 4. GPS Accuracy Warning (if any) ──
          if (_gpsAccuracyWarning)
            Positioned(
              top: MediaQuery.of(context).padding.top + 64,
              left: 16,
              right: 16,
              child: Card(
                color: Colors.amber.shade50,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800, size: 18),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Lokasi GPS kurang akurat. Geser pin ke titik tepat.',
                          style: TextStyle(fontSize: 11, color: Colors.black87),
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

          // ── 5. Floating Controls & GoSend Bottom Sheet Card ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Floating Action Buttons (Back on Left, Zoom & GPS on Right)
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _CircleMapButton(
                        icon: Icons.arrow_back,
                        onTap: () => Navigator.pop(context),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _CircleMapButton(
                            icon: Icons.add,
                            size: 38,
                            iconSize: 20,
                            onTap: _zoomIn,
                          ),
                          const SizedBox(height: 8),
                          _CircleMapButton(
                            icon: Icons.remove,
                            size: 38,
                            iconSize: 20,
                            onTap: _zoomOut,
                          ),
                          const SizedBox(height: 8),
                          _CircleMapButton(
                            icon: Icons.my_location,
                            isLoading: _isGettingGps,
                            onTap: _isGettingGps ? null : _useCurrentLocation,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // GoSend Bottom Sheet Card ("Set lokasi pengiriman")
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 16,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 20,
                    bottom: bottomInset + 16,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title: "Set lokasi pengiriman"
                      Text(
                        widget.title.isNotEmpty ? widget.title : 'Set lokasi pengiriman',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Address Row: [Orange Square with Down Arrow] + [Title & Subtitle]
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Orange square badge matching GoSend
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEC5B13),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.arrow_downward_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Address Text block
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Main Street/Place Title
                                Text(
                                  _addressMainTitle,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF111827),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),

                                // Subtitle Full Address
                                Text(
                                  _addressSubTitle,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: Colors.grey.shade600,
                                    height: 1.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),

                                // Subtle RajaOngkir region tag
                                if (_rajaOngkirMatch?['matched'] == true)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.check_circle,
                                          size: 13,
                                          color: Color(0xFF16A34A),
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            'Wilayah: ${_rajaOngkirMatch!['full_label'] ?? _rajaOngkirMatch!['district_name']}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF15803D),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else if (!_isReverseGeocoding &&
                                    !_isMatchingRegion &&
                                    _currentAddress != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.info_outline,
                                          size: 13,
                                          color: Color(0xFFD97706),
                                        ),
                                        const SizedBox(width: 4),
                                        const Expanded(
                                          child: Text(
                                            'Wilayah dipilih di langkah berikutnya',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF92400E),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Button "Lanjut" (GoSend Solid Green Pill Button)
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00880D), // GoSend Green
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          onPressed: _confirmLocation,
                          child: const Text(
                            'Lanjut',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Reusable circular white map button matching GoSend control buttons.
class _CircleMapButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool isLoading;
  final double size;
  final double iconSize;

  const _CircleMapButton({
    required this.icon,
    this.onTap,
    this.isLoading = false,
    this.size = 44,
    this.iconSize = 22,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: Colors.black26,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          child: isLoading
              ? SizedBox(
                  width: size * 0.45,
                  height: size * 0.45,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF00880D),
                  ),
                )
              : Icon(icon, size: iconSize, color: const Color(0xFF1F2937)),
        ),
      ),
    );
  }
}
