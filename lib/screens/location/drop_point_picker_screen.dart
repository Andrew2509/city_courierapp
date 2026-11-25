import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:maplibre/maplibre.dart' as ml;
import '../../services/shipping/map_service.dart';

class DropPointPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;

  const DropPointPickerScreen({super.key, this.initialLocation});

  @override
  State<DropPointPickerScreen> createState() => _DropPointPickerScreenState();
}

class _DropPointPickerScreenState extends State<DropPointPickerScreen> {
  ml.MapController? _mapController;
  LatLng _selectedLocation = const LatLng(-6.2000, 106.8166); // Default Jakarta
  String _address = 'Mencari alamat...';
  bool _isLoading = false;
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialLocation != null) {
      _selectedLocation = widget.initialLocation!;
    } else {
      _determinePosition();
    }
  }

  void _handleMapEvent(ml.MapEvent event) {
    if (event is ml.MapEventMapCreated) {
      _mapController = event.mapController;
    } else if (event is ml.MapEventCameraIdle || event is ml.MapEventIdle) {
      final center = _mapController?.getCamera().center;
      if (center != null && mounted) {
        final next = LatLng(center.lat, center.lon);
        setState(() {
          _selectedLocation = next;
        });
        _getAddress(next);
      }
    }
  }

  Future<void> _determinePosition() async {
    setState(() => _isLocating = true);
    try {
      final Position position = await Geolocator.getCurrentPosition();
      final LatLng currentLatLng = LatLng(
        position.latitude,
        position.longitude,
      );

      if (!mounted) return;
      setState(() {
        _selectedLocation = currentLatLng;
        _isLocating = false;
      });

      final ctrl = _mapController;
      if (ctrl != null) {
        unawaited(
          ctrl
              .animateCamera(
                center: ml.Geographic(
                  lon: currentLatLng.longitude,
                  lat: currentLatLng.latitude,
                ),
                zoom: 15.0,
              )
              .catchError((_) {}),
        );
      }
      await _getAddress(currentLatLng);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLocating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mendapatkan lokasi GPS: $e')),
      );
    }
  }

  Future<void> _getAddress(LatLng location) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${location.latitude}&lon=${location.longitude}&zoom=18',
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': 'CityCourierApp'},
      );

      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _address = data['display_name'] ?? 'Alamat tidak ditemukan';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _address = 'Gagal memuat detail alamat';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryOrange = Color(0xFFEC5B13);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Pilih Titik Antar',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _determinePosition,
            icon: Icon(
              Icons.my_location,
              color: _isLocating ? primaryOrange : Colors.grey,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Menggunakan MapLibre Native SDK
          ml.MapLibreMap(
            options: ml.MapOptions(
              initCenter: ml.Geographic(
                lon: _selectedLocation.longitude,
                lat: _selectedLocation.latitude,
              ),
              initZoom: 15.0,
              initStyle: MapService.getStyleUrl('sleek-dark'),
            ),
            onEvent: _handleMapEvent,
          ),
          
          // Fixed Center Pin Overlay
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 36),
              child: Icon(Icons.location_on, color: primaryOrange, size: 48),
            ),
          ),

          // Card Informasi & Konfirmasi Alamat Terpilih
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 6,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.location_searching, color: primaryOrange, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Lokasi Terpilih (MapLibre)',
                                style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 4),
                              _isLoading
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : Text(
                                      _address,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                    ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : () {
                          Navigator.pop(context, {
                            'address': _address,
                            'latitude': _selectedLocation.latitude,
                            'longitude': _selectedLocation.longitude,
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryOrange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Konfirmasi Alamat', style: TextStyle(fontWeight: FontWeight.bold)),
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
}
