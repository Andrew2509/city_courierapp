import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../widgets/daftar_kurir_components.dart';
import '../widgets/daftar_kurir_constants.dart';
import '../daftar_kurir_data.dart';
import 'package:city_courierapp/services/shipping/rajaongkir_service.dart';
import 'pilih_kendaraan_screen.dart';

class PilihAreaScreen extends StatefulWidget {
  const PilihAreaScreen({super.key});

  @override
  State<PilihAreaScreen> createState() => _PilihAreaScreenState();
}

class _PilihAreaScreenState extends State<PilihAreaScreen> {
  bool _isLoading = true;
  bool _isDetectingLocation = true;
  String? _detectedProvince;
  int? _detectedProvinceId;
  List<Map<String, dynamic>> _cities = [];
  String _searchQuery = '';
  String? _selectedCity;

  @override
  void initState() {
    super.initState();
    _detectLocationAndLoadCities();
  }

  Future<void> _detectLocationAndLoadCities() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _isLoading = false;
          _isDetectingLocation = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isLoading = false;
            _isDetectingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isLoading = false;
          _isDetectingLocation = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      final result = await RajaOngkirService.reverseGeocode(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      if (result['success'] == true && result['data'] != null) {
        final data = result['data'] as Map<String, dynamic>;
        final provinceName = data['province'] as String?;

        if (provinceName != null && provinceName.isNotEmpty) {
          final provincesResult = await RajaOngkirService.getProvinces();
          if (provincesResult['success'] == true && provincesResult['data'] != null) {
            final List<dynamic> provinces = provincesResult['data'] as List<dynamic>;
            Map<String, dynamic>? matchedProvince;
            for (final p in provinces) {
              final pMap = p as Map<String, dynamic>;
              final pName = (pMap['province'] ?? '').toString().toLowerCase();
              if (pName == provinceName.toLowerCase() ||
                  pName.contains(provinceName.toLowerCase()) ||
                  provinceName.toLowerCase().contains(pName)) {
                matchedProvince = pMap;
                break;
              }
            }

            if (matchedProvince != null) {
              final provinceId = int.tryParse(matchedProvince['province_id'].toString());
              if (provinceId != null) {
                final citiesResult = await RajaOngkirService.getCities(provinceId);
                if (citiesResult['success'] == true && citiesResult['data'] != null) {
                  final List<dynamic> rawCities = citiesResult['data'] as List<dynamic>;
                  setState(() {
                    _detectedProvince = provinceName;
                    _detectedProvinceId = provinceId;
                    _cities = rawCities.map((c) => c as Map<String, dynamic>).toList();
                    _isLoading = false;
                    _isDetectingLocation = false;
                  });
                  return;
                }
              }
            }
          }

          setState(() {
            _detectedProvince = provinceName;
            _isLoading = false;
            _isDetectingLocation = false;
          });
        } else {
          setState(() {
            _isLoading = false;
            _isDetectingLocation = false;
          });
        }
      } else {
        setState(() {
          _isLoading = false;
          _isDetectingLocation = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isDetectingLocation = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredCities {
    if (_searchQuery.isEmpty) return _cities;
    return _cities
        .where((c) => (c['city_name'] ?? c['name'] ?? '')
            .toString()
            .toLowerCase()
            .contains(_searchQuery.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return ScreenLayout(
      title: 'Pilih Area Operasional',
      currentStep: 2,
      totalSteps: 4,
      bottomAction: PrimaryButton(
        text: 'Lanjutkan',
        onPressed: _selectedCity != null
            ? () {
                context.read<DaftarKurirData>().area = _selectedCity;
                context.read<DaftarKurirData>().city = _selectedCity;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PilihKendaraanScreen(),
                  ),
                );
              }
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          if (_isDetectingLocation)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: DaftarKurirColors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: DaftarKurirColors.primary.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: DaftarKurirColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Mendeteksi lokasi Anda...',
                      style: TextStyle(
                        fontSize: 14,
                        color: DaftarKurirColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (_detectedProvince != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.green, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Lokasi terdeteksi: ${_detectedProvince}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (!_isDetectingLocation) ...[
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: DaftarKurirColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                style: const TextStyle(
                  fontSize: 16,
                  color: DaftarKurirColors.textDark,
                ),
                decoration: const InputDecoration(
                  hintText: 'Cari Kota',
                  hintStyle: TextStyle(
                    color: DaftarKurirColors.textMuted,
                    fontSize: 16,
                  ),
                  prefixIcon: Icon(Icons.search, color: DaftarKurirColors.textMuted),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_filteredCities.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    _cities.isEmpty
                        ? 'Tidak ada kota ditemukan. Coba lagi atau pilih area lain.'
                        : 'Kota tidak ditemukan',
                    style: const TextStyle(color: DaftarKurirColors.textSub),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: DaftarKurirColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                padding: const EdgeInsets.all(8),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _filteredCities.length,
                  itemBuilder: (context, index) {
                    final city = _filteredCities[index];
                    final name = city['city_name'] ?? city['name'] ?? '';
                    final isSelected = _selectedCity == name;

                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedCity = name;
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected ? DaftarKurirColors.bgLight : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: DaftarKurirColors.textDark,
                                ),
                              ),
                            ),
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? DaftarKurirColors.primary : DaftarKurirColors.border,
                                  width: isSelected ? 6 : 2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ],
      ),
    );
  }
}
