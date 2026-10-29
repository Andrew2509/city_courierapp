import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:geolocator/geolocator.dart';
import '../../data/models/address_model.dart';
import '../../services/maps/location_repository.dart';
import '../../services/shipping/rajaongkir_matcher_service.dart';
import '../../core/config/map_config.dart';
import 'dart:async';

/// Extended result from LocationPickerScreen that holds address details,
/// benchmark / patokan notes, and RajaOngkir matched region ID/data.
class LocationPickerResult extends Address {
  final Map<String, dynamic>? rajaOngkirMatch;
  final bool isRajaOngkirMatched;
  final String? benchmarkNote;

  LocationPickerResult({
    required Address address,
    required super.latitude,
    required super.longitude,
    this.rajaOngkirMatch,
    this.isRajaOngkirMatched = false,
    this.benchmarkNote,
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
          addressDetail: benchmarkNote ?? address.addressDetail,
          poiName: address.poiName,
          category: address.category,
        );
}

/// POI-First interactive location picker screen.
///
/// Redesigned to match Stitch & GoSend POI-first standards:
/// - Prioritizes organization / institution / POI names over technical street names.
/// - Floating rounded search bar with auto-detected POI card below it.
/// - Center map pin with floating tooltip: "Titik Jemput: Gerbang Utama UNTAG".
/// - Clean floating navigation controls (Back on left, GPS on right).
/// - Comprehensive bottom sheet with "Akurasi Tinggi" badge, clear POI title,
///   detail address, verified region badge, courier landmark/patokan note,
///   and solid green "Lanjut →" CTA button.
class LocationPickerScreen extends StatefulWidget {
  final Address? initialAddress;
  final String? regionHint;
  final String title;

  const LocationPickerScreen({
    super.key,
    this.initialAddress,
    this.regionHint,
    this.title = 'Set lokasi penjemputan',
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

  // Benchmark / Patokan Kurir state
  String _benchmarkNote = 'Di depan Pos Satpam Gerbang Utama';

  // Dynamic bottom sheet height tracking for floating button positioning
  final GlobalKey _bottomSheetKey = GlobalKey();
  double _measuredSheetHeight = 0;

  // Search state
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<Address> _searchResults = [];
  bool _isSearching = false;
  bool _showResults = false;
  String _searchErrorMessage = '';
  Timer? _debounce;

  // Curated popular POIs for instant responsive matching
  static final List<Address> _knownPOIs = [
    Address(
      formattedAddress:
          'Gerbang Masuk Utama, Jl. Semolowaru No.45, Menur Pumpungan, Kec. Sukolilo, Surabaya, Jawa Timur 60118',
      poiName: 'Universitas 17 Agustus 1945 Surabaya',
      streetName: 'Jl. Semolowaru No.45',
      village: 'Menur Pumpungan',
      district: 'Sukolilo',
      city: 'Surabaya',
      province: 'Jawa Timur',
      postalCode: '60118',
      country: 'Indonesia',
      latitude: -7.298285,
      longitude: 112.767175,
      locationSource: 'preset_poi',
      category: 'KAMPUS / INSTANSI',
      addressDetail: 'Di depan Pos Satpam Gerbang Utama',
    ),
    Address(
      formattedAddress:
          'Kampus ITS Sukolilo, Jl. Raya ITS, Keputih, Kec. Sukolilo, Surabaya, Jawa Timur 60111',
      poiName: 'Institut Teknologi Sepuluh Nopember (ITS)',
      streetName: 'Jl. Raya ITS',
      village: 'Keputih',
      district: 'Sukolilo',
      city: 'Surabaya',
      province: 'Jawa Timur',
      postalCode: '60111',
      country: 'Indonesia',
      latitude: -7.282356,
      longitude: 112.794445,
      locationSource: 'preset_poi',
      category: 'KAMPUS / INSTANSI',
      addressDetail: 'Gerbang Utama Bundaran ITS',
    ),
    Address(
      formattedAddress:
          'Kampus B UNAIR, Jl. Airlangga No.4-6, Airlangga, Kec. Gubeng, Surabaya, Jawa Timur 60286',
      poiName: 'Universitas Airlangga (UNAIR)',
      streetName: 'Jl. Airlangga No.4-6',
      village: 'Airlangga',
      district: 'Gubeng',
      city: 'Surabaya',
      province: 'Jawa Timur',
      postalCode: '60286',
      country: 'Indonesia',
      latitude: -7.268754,
      longitude: 112.759324,
      locationSource: 'preset_poi',
      category: 'KAMPUS / INSTANSI',
      addressDetail: 'Lobby Gedung Rektorat Kampus B',
    ),
    Address(
      formattedAddress:
          'Kampus Ketintang, Jl. Ketintang, Ketintang, Kec. Gayungan, Surabaya, Jawa Timur 60231',
      poiName: 'Universitas Negeri Surabaya (UNESA)',
      streetName: 'Jl. Ketintang',
      village: 'Ketintang',
      district: 'Gayungan',
      city: 'Surabaya',
      province: 'Jawa Timur',
      postalCode: '60231',
      country: 'Indonesia',
      latitude: -7.311756,
      longitude: 112.727891,
      locationSource: 'preset_poi',
      category: 'KAMPUS / INSTANSI',
      addressDetail: 'Gerbang Ketintang Depan Pos Satpam',
    ),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialAddress != null) {
      _currentCenter = LatLng(
        widget.initialAddress!.latitude,
        widget.initialAddress!.longitude,
      );
      _currentAddress = widget.initialAddress;
      if (widget.initialAddress!.addressDetail != null &&
          widget.initialAddress!.addressDetail!.trim().isNotEmpty) {
        _benchmarkNote = widget.initialAddress!.addressDetail!.trim();
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _matchRajaOngkir(_currentAddress, _currentCenter);
      });
    } else {
      // Default to UNTAG Surabaya area as showcased in screenshot
      final untagPreset = _knownPOIs.first;
      _currentCenter = LatLng(untagPreset.latitude, untagPreset.longitude);
      _currentAddress = untagPreset;
      _searchController.text = 'universitas 17 agustus 1945 surabaya';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _matchRajaOngkir(_currentAddress, _currentCenter);
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

  // ── POI & Address Helpers (POI-First Architecture) ───────────────

  String _getPoiName(Address address) {
    if (address.poiName != null && address.poiName!.trim().isNotEmpty) {
      return address.poiName!.trim();
    }
    final raw = address.formattedAddress.trim();
    if (raw.isNotEmpty) {
      final firstPart = raw.split(',').first.trim();
      final lower = firstPart.toLowerCase();
      if (!lower.startsWith('jl') &&
          !lower.startsWith('jalan') &&
          !lower.startsWith('gang') &&
          !lower.startsWith('g.') &&
          !lower.startsWith('rt ') &&
          !lower.startsWith('rw ')) {
        return firstPart;
      }
    }
    if (address.streetName != null && address.streetName!.trim().isNotEmpty) {
      if (address.houseNumber != null && address.houseNumber!.trim().isNotEmpty) {
        return '${address.streetName} No. ${address.houseNumber}';
      }
      return address.streetName!;
    }
    return 'Titik Lokasi';
  }

  String _getPoiCategory(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('universitas') ||
        lower.contains('kampus') ||
        lower.contains('institut') ||
        lower.contains('sekolah') ||
        lower.contains('politeknik') ||
        lower.contains('untag') ||
        lower.contains('its') ||
        lower.contains('unair') ||
        lower.contains('unesa') ||
        lower.contains('ubaya') ||
        lower.contains('upn') ||
        lower.contains('akademi') ||
        lower.contains('sma') ||
        lower.contains('smp') ||
        lower.contains('sd')) {
      return 'KAMPUS / INSTANSI';
    }
    if (lower.contains('rumah sakit') ||
        lower.contains('rsud') ||
        lower.contains('rs ') ||
        lower.contains('klinik') ||
        lower.contains('puskesmas') ||
        lower.contains('apotek')) {
      return 'KESEHATAN';
    }
    if (lower.contains('mall') ||
        lower.contains('plaza') ||
        lower.contains('pasar') ||
        lower.contains('square') ||
        lower.contains('supermarket')) {
      return 'PUSAT BELANJA';
    }
    if (lower.contains('gedung') ||
        lower.contains('kantor') ||
        lower.contains('menara') ||
        lower.contains('tower') ||
        lower.contains('office') ||
        lower.contains('pt ') ||
        lower.contains('cv ')) {
      return 'KANTOR / BISNIS';
    }
    if (lower.contains('masjid') ||
        lower.contains('gereja') ||
        lower.contains('pura') ||
        lower.contains('vihara')) {
      return 'TEMPAT IBADAH';
    }
    if (lower.contains('apartemen') ||
        lower.contains('hotel') ||
        lower.contains('residence') ||
        lower.contains('wisma') ||
        lower.contains('perumahan')) {
      return 'HUNIAN / PROPERTI';
    }
    return 'TEMPAT / POI';
  }

  String _getDetailAddress(Address address) {
    final parts = <String>[];
    if (address.streetName != null && address.streetName!.trim().isNotEmpty) {
      final s = address.streetName!.trim();
      if (!parts.contains(s)) parts.add(s);
    }
    if (address.village != null && address.village!.trim().isNotEmpty) {
      final v = address.village!.trim();
      if (!parts.contains(v)) parts.add(v);
    }
    if (address.district != null && address.district!.trim().isNotEmpty) {
      final d = address.district!.trim();
      if (!parts.contains(d)) parts.add('Kec. $d');
    }
    if (address.city != null && address.city!.trim().isNotEmpty) {
      final c = address.city!.trim();
      if (!parts.contains(c)) parts.add(c);
    }
    if (address.postalCode != null && address.postalCode!.trim().isNotEmpty) {
      parts.add(address.postalCode!.trim());
    }
    if (parts.isNotEmpty) {
      return parts.join(', ');
    }
    return address.formattedAddress;
  }

  String get _pickupTooltipTitle {
    if (_currentAddress == null) return 'Titik Penjemputan';
    final poi = _getPoiName(_currentAddress!);
    final lower = poi.toLowerCase();
    if (lower.contains('untag') || lower.contains('17 agustus')) {
      return 'Gerbang Utama UNTAG';
    }
    if (lower.contains('its')) {
      return 'Bundaran Utama ITS';
    }
    if (lower.contains('unair')) {
      return 'Lobby Gedung Rektorat UNAIR';
    }
    if (poi != 'Titik Lokasi' && !lower.startsWith('jl')) {
      return 'Gerbang / Pintu $poi';
    }
    return poi;
  }

  String get _addressMainTitle {
    if (_isReverseGeocoding) return 'Menentukan lokasi...';
    if (_currentAddress == null) return 'Pilih lokasi pada peta';
    return _getPoiName(_currentAddress!);
  }

  String get _addressSubTitle {
    if (_isReverseGeocoding) return 'Sedang memuat alamat lengkap...';
    if (_currentAddress == null) {
      return 'Geser pin pada peta untuk menandai lokasi yang tepat';
    }
    return _getDetailAddress(_currentAddress!);
  }

  // ── Search (Photon search-as-you-type with POI-First filtering) ──

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
        final queryClean = query.trim().toLowerCase();

        // 1. Check instant known POI matches
        final matchedPresets = _knownPOIs.where((p) {
          final pName = (p.poiName ?? '').toLowerCase();
          final fAddr = p.formattedAddress.toLowerCase();
          return pName.contains(queryClean) || fAddr.contains(queryClean);
        }).toList();

        // 2. Query Photon API
        List<Address> results = await _locationRepository.searchAddress(
          query.trim(),
          latitude: _currentCenter.latitude,
          longitude: _currentCenter.longitude,
          limit: 6,
        );

        // Combine preset matches first
        final combined = <Address>[...matchedPresets];
        for (final r in results) {
          if (!combined.any((c) =>
              c.formattedAddress.toLowerCase() == r.formattedAddress.toLowerCase())) {
            combined.add(r);
          }
        }

        if (mounted) {
          setState(() {
            _searchResults = combined;
            _isSearching = false;
            if (combined.isEmpty) {
              _searchErrorMessage = 'Alamat atau instansi tidak ditemukan';
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
    _searchController.text = address.poiName ?? address.streetName ?? _getAddressPrimaryText(address);
    _searchFocusNode.unfocus();
    setState(() {
      _searchResults = [];
      _showResults = false;
      _searchErrorMessage = '';
      _currentCenter = LatLng(address.latitude, address.longitude);
      _currentAddress = address;

      if (address.addressDetail != null && address.addressDetail!.isNotEmpty) {
        _benchmarkNote = address.addressDetail!;
      } else if (address.poiName != null) {
        final lower = address.poiName!.toLowerCase();
        if (lower.contains('untag') || lower.contains('17 agustus')) {
          _benchmarkNote = 'Di depan Pos Satpam Gerbang Utama';
        } else {
          _benchmarkNote = 'Di depan Gerbang / Lobby Utama';
        }
      }
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

  String _getAddressPrimaryText(Address address) {
    return _getPoiName(address);
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
      // Check if near known POI (e.g. UNTAG Surabaya)
      Address? matchedPreset;
      for (final p in _knownPOIs) {
        final dLat = (p.latitude - _currentCenter.latitude).abs();
        final dLng = (p.longitude - _currentCenter.longitude).abs();
        if (dLat < 0.002 && dLng < 0.002) {
          matchedPreset = p;
          break;
        }
      }

      final address = matchedPreset ??
          await _locationRepository.reverseGeocode(
            _currentCenter.latitude,
            _currentCenter.longitude,
          );

      if (address != null && mounted) {
        setState(() {
          _currentAddress = address;
          if (address.poiName != null) {
            _searchController.text = address.poiName!;
          }
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
        if (mounted) _showLocationServiceDisabled();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (mounted) _showPermissionDenied();
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) _showPermissionPermanentlyDenied();
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
          'Layanan lokasi GPS belum aktif.\n'
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
          'Izin lokasi ditolak. Silakan aktifkan izin lokasi atau pilih lokasi di peta.',
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
          'Izin lokasi diperlukan untuk menggunakan GPS.\n'
          'Silakan aktifkan izin lokasi di pengaturan perangkat.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
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

  // ── Edit Benchmark Note Bottom Sheet ───────────────────────────────

  void _openEditBenchmarkSheet() {
    final noteController = TextEditingController(text: _benchmarkNote);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Catatan Patokan untuk Kurir',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Bantu kurir menemukan titik jemput Anda lebih cepat dan akurat.',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: noteController,
                autofocus: true,
                maxLines: 2,
                style: const TextStyle(fontSize: 13.5),
                decoration: InputDecoration(
                  hintText: 'Contoh: Di depan Pos Satpam Gerbang Utama, Lobby Barat...',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFEA580C), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  'Di depan Pos Satpam Gerbang Utama',
                  'Lobby Utama Kampus',
                  'Pintu Masuk Barat',
                  'Dekat Gedung Rektorat',
                  'Di depan Perpustakaan',
                ].map((preset) {
                  return InkWell(
                    onTap: () {
                      noteController.text = preset;
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        preset,
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155)),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00880C),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    setState(() {
                      _benchmarkNote = noteController.text.trim();
                    });
                    Navigator.pop(ctx);
                  },
                  child: const Text(
                    'Simpan Patokan',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Confirm Location ("Lanjut →") ──────────────────────────────────

  void _confirmLocation() {
    final Address baseAddr;
    if (_currentAddress != null) {
      baseAddr = _currentAddress!.copyWith(
        latitude: _currentCenter.latitude,
        longitude: _currentCenter.longitude,
        locationSource: 'manual_pin',
        addressDetail: _benchmarkNote.isNotEmpty ? _benchmarkNote : null,
      );
    } else {
      baseAddr = Address(
        formattedAddress:
            'Lokasi (${_currentCenter.latitude.toStringAsFixed(6)}, ${_currentCenter.longitude.toStringAsFixed(6)})',
        latitude: _currentCenter.latitude,
        longitude: _currentCenter.longitude,
        locationSource: 'manual_pin',
        addressDetail: _benchmarkNote.isNotEmpty ? _benchmarkNote : null,
      );
    }

    final result = LocationPickerResult(
      address: baseAddr,
      latitude: _currentCenter.latitude,
      longitude: _currentCenter.longitude,
      rajaOngkirMatch: _rajaOngkirMatch,
      isRajaOngkirMatched: _rajaOngkirMatch?['matched'] == true,
      benchmarkNote: _benchmarkNote.isNotEmpty ? _benchmarkNote : null,
    );

    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final topInset = MediaQuery.of(context).padding.top;

    // Check if identified POI is active
    final activePoiName = _currentAddress?.poiName ??
        (_currentAddress != null && !_currentAddress!.formattedAddress.toLowerCase().startsWith('jl')
            ? _currentAddress!.formattedAddress.split(',').first.trim()
            : null);
    final activeCategory = _currentAddress?.category ?? _getPoiCategory(activePoiName ?? '');

    // Formatted region badge text
    String regionBadgeText = 'Sukolilo, SURABAYA';
    if (_isMatchingRegion) {
      regionBadgeText = 'Mencocokkan wilayah...';
    } else if (_rajaOngkirMatch?['matched'] == true) {
      final kec = _rajaOngkirMatch!['district_name'] ?? _rajaOngkirMatch!['kecamatan_name'];
      final city = _rajaOngkirMatch!['city_name'] ?? _rajaOngkirMatch!['kabupaten_name'];
      if (kec != null && city != null) {
        regionBadgeText = '$kec, ${city.toString().toUpperCase()}';
      } else if (city != null) {
        regionBadgeText = city.toString().toUpperCase();
      }
    } else if (_currentAddress?.district != null && _currentAddress?.city != null) {
      regionBadgeText = '${_currentAddress!.district}, ${_currentAddress!.city!.toUpperCase()}';
    }

    // Measure dynamic sheet height to place floating action buttons safely above it
    final double defaultSheetHeight = bottomInset + 315;
    final double effectiveSheetHeight =
        _measuredSheetHeight > 0 ? _measuredSheetHeight : defaultSheetHeight;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _bottomSheetKey.currentContext;
      if (ctx != null) {
        final renderBox = ctx.findRenderObject() as RenderBox?;
        if (renderBox != null && renderBox.hasSize) {
          final h = renderBox.size.height;
          if (h > 0 && (_measuredSheetHeight - h).abs() > 2.0) {
            setState(() {
              _measuredSheetHeight = h;
            });
          }
        }
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // ── 1. Full-screen OpenStreetMap Canvas ──
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

          // ── 2. Center Pin with Floating Tooltip & Target Ground Dot ──
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 48.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Floating Tooltip Bubble
                  Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width - 48,
                    ),
                    margin: const EdgeInsets.only(bottom: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A), // Dark slate
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Pulse Emerald Dot
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Titik Jemput: $_pickupTooltipTitle',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Downward Triangle Pointer
                  CustomPaint(
                    size: const Size(10, 6),
                    painter: _TrianglePainter(color: const Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 2),

                  // Pin Icon Marker (Orange with White Down Arrow)
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF5C00), // Vibrant Orange
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF5C00).withOpacity(0.38),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.18),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.arrow_downward_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),

                  // Base Ground Contact Dot
                  Container(
                    width: 9,
                    height: 9,
                    margin: const EdgeInsets.only(top: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── 3. Top Search & Identified Organization / POI Card ──
          Positioned(
            top: topInset + 8,
            left: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Search Bar (Pill Shape)
                Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 14),
                      const Icon(
                        Icons.search_rounded,
                        color: Color(0xFF64748B),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          onChanged: _onSearchChanged,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A),
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Cari alamat, jalan, atau tempat...',
                            hintStyle: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF94A3B8),
                              fontWeight: FontWeight.normal,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF94A3B8)),
                          onPressed: _clearSearch,
                        )
                      else
                        const SizedBox(width: 12),
                    ],
                  ),
                ),

                // Identified POI Card (Underneath Search Bar)
                if (activePoiName != null && !_showResults)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Left Building Icon Box
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7ED),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFFEDD5)),
                          ),
                          child: const Icon(
                            Icons.account_balance_outlined,
                            color: Color(0xFFD97706),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Center POI Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF3C7),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        activeCategory,
                                        style: const TextStyle(
                                          color: Color(0xFF9A3412),
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    '• Populer',
                                    style: TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 10.5,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                activePoiName,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                _addressSubTitle,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),

                        // Right Chevron
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: Color(0xFF94A3B8),
                          size: 20,
                        ),
                      ],
                    ),
                  ),

                // Search Loading Indicator
                if (_isSearching)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00880C)),
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Mencari instansi atau alamat...',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),

                // Search Results Dropdown (POI-First Architecture)
                if (_showResults && _searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    constraints: const BoxConstraints(maxHeight: 280),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      itemBuilder: (context, index) {
                        final address = _searchResults[index];
                        final poi = address.poiName ?? _getPoiName(address);
                        final category = address.category ?? _getPoiCategory(poi);
                        final sub = _getDetailAddress(address);

                        return InkWell(
                          onTap: () => _onSelectSearchResult(address),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF7ED),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFFFEDD5)),
                                  ),
                                  child: Icon(
                                    category.contains('KAMPUS')
                                        ? Icons.account_balance_outlined
                                        : Icons.location_on_outlined,
                                    color: const Color(0xFFEA580C),
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFEF3C7),
                                              borderRadius: BorderRadius.circular(3),
                                            ),
                                            child: Text(
                                              category,
                                              style: const TextStyle(
                                                color: Color(0xFF9A3412),
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Text(
                                            '• Populer',
                                            style: TextStyle(
                                              color: Color(0xFF64748B),
                                              fontSize: 9.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        poi,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0F172A),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        sub,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF64748B),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: Color(0xFFCBD5E1),
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                // Search Not Found Message
                if (_showResults && !_isSearching && _searchErrorMessage.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 18, color: Color(0xFFD97706)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _searchErrorMessage,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // ── 4. GPS Accuracy Warning (if any) ──
          if (_gpsAccuracyWarning)
            Positioned(
              top: topInset + 115,
              left: 16,
              right: 16,
              child: Card(
                color: Colors.amber.shade50,
                elevation: 2,
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

          // ── 5. Floating Navigation Buttons (Comfortably above bottom sheet) ──
          Positioned(
            bottom: effectiveSheetHeight + 16,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Back Button (Left)
                _CircleMapButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.pop(context),
                ),

                // My Location Button (Right)
                _CircleMapButton(
                  icon: Icons.my_location_rounded,
                  isLoading: _isGettingGps,
                  onTap: _isGettingGps ? null : _useCurrentLocation,
                ),
              ],
            ),
          ),

          // ── 6. Bottom Sheet "Set lokasi penjemputan" ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              key: _bottomSheetKey,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 24,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 10,
                bottom: bottomInset + 14,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Grab Bar Handle
                  Center(
                    child: Container(
                      width: 42,
                      height: 4.5,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),

                  // Header Row: Title & Akurasi Tinggi Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          widget.title.isNotEmpty ? widget.title : 'Set lokasi penjemputan',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Akurasi Tinggi',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF15803D),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Destination Details Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Orange Square with Down Arrow Badge
                        Container(
                          width: 44,
                          height: 44,
                          margin: const EdgeInsets.only(top: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF5C00), // Vibrant Orange
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.arrow_downward_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Destination Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _addressMainTitle,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _addressSubTitle,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF475569),
                                  height: 1.35,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),

                              // Verified Region Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFBBF7D0)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      size: 13,
                                      color: Color(0xFF16A34A),
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        'Wilayah: $regionBadgeText',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF15803D),
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
                  ),
                  const SizedBox(height: 10),

                  // Benchmark Note for Driver (Patokan)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.edit_note_rounded,
                          size: 20,
                          color: Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Patokan: $_benchmarkNote',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF334155),
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        InkWell(
                          onTap: _openEditBenchmarkSheet,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Text(
                              'Ubah',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFF5C00),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Primary CTA Button ("Lanjut →")
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00880D), // Solid Green
                        foregroundColor: Colors.white,
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      onPressed: _confirmLocation,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Lanjut',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                        ],
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

/// Custom painter for the downward pointing tooltip arrow
class _TrianglePainter extends CustomPainter {
  final Color color;
  const _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Reusable circular white map button matching mobile ride-hailing design.
class _CircleMapButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool isLoading;

  const _CircleMapButton({
    required this.icon,
    this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    const double size = 44;
    const double iconSize = 22;

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
              ? const SizedBox(
                  width: size * 0.45,
                  height: size * 0.45,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF00880C),
                  ),
                )
              : Icon(icon, size: iconSize, color: const Color(0xFF1F2937)),
        ),
      ),
    );
  }
}
