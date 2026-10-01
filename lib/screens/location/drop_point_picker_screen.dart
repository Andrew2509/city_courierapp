import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../../services/shipping/map_service.dart';

class DropPointPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;

  const DropPointPickerScreen({super.key, this.initialLocation});

  @override
  State<DropPointPickerScreen> createState() => _DropPointPickerScreenState();
}

class _DropPointPickerScreenState extends State<DropPointPickerScreen> {
  MapLibreMapController? _mapController;
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

  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
    
    // Dengarkan saat kamera peta berhenti bergerak untuk reverse geocoding
    _mapController!.addListener(() {
      if (!_mapController!.isCameraMoving) {
        final center = _mapController!.cameraPosition?.target;
        if (center != null) {
          setState(() {
            _selectedLocation = center;
          });
          _getAddress(center);
        }
      }
    });
  }

  Future<void> _determinePosition() async {
    setState(() => _isLocating = true);
    try {
      Position position = await Geolocator.getCurrentPosition();
      LatLng currentLatLng = LatLng(position.latitude, position.longitude);
      
      setState(() {
        _selectedLocation = currentLatLng;
        _isLocating = false;
      });

      if (_mapController != null) {
        _mapController!.animateCamera(CameraUpdate.newLatLngZoom(currentLatLng, 15.0));
      }
      _getAddress(currentLatLng);
    } catch (e) {
      setState(() => _isLocating = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mendapatkan lokasi GPS: $e')),
      );
    }
  }

  Future<void> _getAddress(LatLng location) async {
    setState(() => _isLoading = true);
    try {
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=${location.latitude}&lon=${location.longitude}&zoom=18');
      
      final response = await http.get(url, headers: {'User-Agent': 'CityCourierApp'});

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _address = data['display_name'] ?? 'Alamat tidak ditemukan';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _address = 'Gagal memuat detail alamat';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryOrange = const Color(0xFFEC5B13);

    return Scaffold(
      appBar: AppBar(
        title: Text('Pilih Titik Antar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _determinePosition,
            icon: Icon(Icons.my_location, color: _isLocating ? primaryOrange : Colors.grey),
          )
        ],
      ),
      body: Stack(
        children: [
          // Menggunakan MapLibre GL Native
          MapLibreMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: _selectedLocation,
              zoom: 15.0,
            ),
            // Mengambil Style JSON yang diproxy dan diamankan oleh Laravel
            styleString: MapService.getStyleUrl('sleek-dark'),
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
