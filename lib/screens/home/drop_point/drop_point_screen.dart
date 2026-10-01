import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:city_courierapp/screens/home/drop_point/drop_point_detail_screen.dart';
import 'package:city_courierapp/services/api_service.dart';
import 'package:city_courierapp/models/drop_point.dart';
import 'package:url_launcher/url_launcher.dart';

class DropPointScreen extends StatefulWidget {
  const DropPointScreen({super.key});

  @override
  State<DropPointScreen> createState() => _DropPointScreenState();
}

class _DropPointScreenState extends State<DropPointScreen> {
  final MapController _mapController = MapController();
  LatLng? _currentLocation;
  bool _isLoadingLocation = false;

  bool get isDarkMode => Theme.of(context).brightness == Brightness.dark;
  String selectedView = 'map'; // 'map' or 'list'
  String selectedFilter = 'Semua';

  @override
  void initState() {
    super.initState();
    _determinePosition();
    _fetchDropPoints();
  }

  List<DropPoint> _dropPoints = [];
  bool _isLoadingPoints = false;

  Future<void> _fetchDropPoints() async {
    setState(() => _isLoadingPoints = true);
    try {
      final data = await ApiService.getDropPoints();
      if (mounted) {
        setState(() {
          _dropPoints = data.map((e) => DropPoint.fromJson(e)).toList();
          _isLoadingPoints = false;
        });

        // Auto-center on first drop point if found
        if (_dropPoints.isNotEmpty) {
          _mapController.move(
            LatLng(_dropPoints[0].latitude, _dropPoints[0].longitude),
            13.0,
          );
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingPoints = false);
    }
  }

  List<DropPoint> get _filteredPoints {
    List<DropPoint> filtered = List.from(_dropPoints);

    // Apply Search
    // Note: Implementation of search can be added here if needed

    // Apply Category Filter
    if (selectedFilter == '24 Jam') {
      filtered = filtered.where((p) => p.schedule.contains('24')).toList();
    } else if (selectedFilter == 'Terdekat') {
      if (_currentLocation != null) {
        filtered.sort((a, b) {
          double distA = Geolocator.distanceBetween(
            _currentLocation!.latitude,
            _currentLocation!.longitude,
            a.latitude,
            a.longitude,
          );
          double distB = Geolocator.distanceBetween(
            _currentLocation!.latitude,
            _currentLocation!.longitude,
            b.latitude,
            b.longitude,
          );
          return distA.compareTo(distB);
        });
      }
    } else if (selectedFilter == 'Rating') {
      filtered.sort((a, b) => b.rating.compareTo(a.rating));
    }

    return filtered;
  }

  Future<void> _openDirections(double lat, double lng) async {
    final Uri googleMapsUrl = Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lng");
    final Uri appleMapsUrl = Uri.parse("https://maps.apple.com/?q=$lat,$lng");

    try {
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(appleMapsUrl)) {
        await launchUrl(appleMapsUrl, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tidak dapat membuka aplikasi peta.')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error launching map: $e');
    }
  }

  Future<void> _determinePosition() async {
    setState(() => _isLoadingLocation = true);

    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Layanan lokasi tidak aktif.')),
        );
      }
      setState(() => _isLoadingLocation = false);
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _isLoadingLocation = false);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() => _isLoadingLocation = false);
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
          _isLoadingLocation = false;
        });
        _mapController.move(_currentLocation!, 14.0);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFEC5B13);
    final bgLight = const Color(0xFFF9FAFB);
    final bgDark = const Color(0xFF0F172A);
    return Scaffold(
        body: Stack(
          children: [
            // Background
            if (selectedView == 'map') 
              _buildMapBackground()
            else
              Container(color: isDarkMode ? bgDark : bgLight),

            // Content
            Column(
              children: [
                _buildHeader(context, primaryColor, isDarkMode),
                _buildSearchAndFilters(primaryColor, isDarkMode),
                if (selectedView == 'map') ...[
                  const Spacer(),
                  _buildNearbyCarousel(primaryColor, isDarkMode),
                  const SizedBox(height: 20),
                ] else
                  Expanded(child: _buildListView(primaryColor, isDarkMode)),
              ],
            ),

            // My Location Button
            if (selectedView == 'map')
              Positioned(
                right: 16,
                bottom: 220, // Above the carousel
                child: FloatingActionButton(
                  onPressed: _determinePosition,
                  backgroundColor: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                  mini: true,
                  child: Icon(
                    Icons.my_location,
                    color: primaryColor,
                    size: 20,
                  ),
                ),
              ),


          ],
        ),
      );
  }

  Widget _buildMapBackground() {
    return FlutterMap(
      mapController: _mapController,
      options: const MapOptions(
        initialCenter: LatLng(-6.185, 106.79), // Default West Jakarta
        initialZoom: 13.0,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.citycourier.app',
          tileProvider: NetworkTileProvider(
            headers: {
              'User-Agent': 'CityCourierApp/1.0',
            },
          ),
        ),
        MarkerLayer(
          markers: [
            // User Current Location Marker
            if (_currentLocation != null)
              Marker(
                point: _currentLocation!,
                width: 60,
                height: 60,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 25,
                      height: 25,
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Container(
                      width: 15,
                      height: 15,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withValues(alpha: 0.5),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Drop Points Markers
            ..._filteredPoints.map((point) {
              final latLng = LatLng(point.latitude, point.longitude);
              return Marker(
                point: latLng,
                width: 40,
                height: 40,
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            DropPointDetailScreen(point: point.toMap()),
                      ),
                    );
                  },
                  child: Icon(
                    Icons.location_on,
                    color: const Color(0xFFEC5B13),
                    size: 40,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, Color primaryColor, bool isDarkMode) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 8,
        left: 16,
        right: 16,
      ),
      decoration: BoxDecoration(
        color: (isDarkMode ? const Color(0xFF0F172A) : Colors.white)
            .withValues(alpha: 0.6),
        border: Border(
          bottom: BorderSide(
            color: primaryColor.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(
              Icons.arrow_back,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const Expanded(
            child: Text(
              'Drop Point',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(
            width: 48,
            child: _isLoadingLocation
                ? const Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFEC5B13),
                      ),
                    ),
                  )
                : const SizedBox(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(Color primaryColor, bool isDarkMode) {
    return Container(
      color: (isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF9FAFB))
          .withValues(alpha: selectedView == 'map' ? 0.0 : 1.0),
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 8),
      child: Column(
        children: [
          // Search Bar
          Container(
            height: 50,
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDarkMode ? Colors.white10 : Colors.grey.shade200,
              ),
              boxShadow: [
                if (selectedView == 'map')
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                else
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 4,
                  ),
              ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                Icon(Icons.search, color: primaryColor, size: 24),
                const SizedBox(width: 12),
                const Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Find by location or name',
                      border: InputBorder.none,
                      hintStyle: TextStyle(fontSize: 14),
                    ),
                  ),
                ),
                Container(
                  height: 30,
                  width: 1,
                  color: isDarkMode ? Colors.white12 : Colors.grey.shade200,
                ),
                IconButton(
                  onPressed: _fetchDropPoints,
                  icon: Icon(Icons.refresh, color: primaryColor, size: 20),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // View Toggle
          Container(
            height: 44,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => selectedView = 'map'),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selectedView == 'map' ? primaryColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Map View',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: selectedView == 'map' ? Colors.white : (isDarkMode ? Colors.grey.shade400 : Colors.grey.shade500),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => selectedView = 'list'),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selectedView == 'list' ? primaryColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'List View',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: selectedView == 'list' ? Colors.white : primaryColor,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['Semua', '24 Jam', 'Terdekat', 'Rating'].map((filter) {
                bool isSelected = selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => selectedFilter = filter),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? primaryColor : (isDarkMode ? const Color(0xFF1E293B) : Colors.white),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? primaryColor : (isDarkMode ? Colors.white10 : Colors.grey.shade200),
                        ),
                        boxShadow: [
                          if (isSelected)
                            BoxShadow(
                              color: primaryColor.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          if (!isSelected && selectedView == 'map')
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 4,
                            ),
                        ],
                      ),
                      child: Row(
                        children: [
                          if (filter == 'Rating')
                            Icon(Icons.star, size: 14, color: isSelected ? Colors.white : primaryColor),
                          if (filter == 'Rating') const SizedBox(width: 4),
                          Text(
                            filter,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : (isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNearbyCarousel(Color primaryColor, bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: (isDarkMode ? const Color(0xFF1E293B) : Colors.white).withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Nearby Drop Points',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 180, // Increased height to prevent overflow
          child: _isLoadingPoints 
            ? const Center(child: CircularProgressIndicator())
            : _filteredPoints.isEmpty
              ? Center(child: Text('Tidak ada drop point ditemukan', style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black54)))
              : ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _filteredPoints.length,
            itemBuilder: (context, index) {
              final point = _filteredPoints[index];
              final pointMap = point.toMap();
              
              // Calculate real distance if location is available
              if (_currentLocation != null) {
                double distanceInMeters = Geolocator.distanceBetween(
                  _currentLocation!.latitude,
                  _currentLocation!.longitude,
                  point.latitude,
                  point.longitude,
                );
                pointMap['distance'] = distanceInMeters > 1000 
                  ? '${(distanceInMeters / 1000).toStringAsFixed(1)} km'
                  : '${distanceInMeters.round()} m';
              }

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DropPointDetailScreen(point: pointMap),
                    ),
                  );
                },
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.85,
                  margin: const EdgeInsets.only(right: 16, bottom: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: primaryColor.withValues(alpha: 0.1)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: _buildPointCardContent(pointMap, primaryColor, isDarkMode, isCarousel: true),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildListView(Color primaryColor, bool isDarkMode) {
    return _isLoadingPoints 
      ? const Center(child: CircularProgressIndicator())
      : _filteredPoints.isEmpty
        ? Center(child: Text('Tidak ada drop point ditemukan', style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black54)))
        : RefreshIndicator(
            onRefresh: _fetchDropPoints,
            color: primaryColor,
            child: ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _filteredPoints.length + 1, // +1 for the header text
      itemBuilder: (context, index) {
        if (index == 0) {
          return const Padding(
            padding: EdgeInsets.only(top: 8, bottom: 16),
            child: Text(
              'Nearby Drop Points',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }
        final point = _filteredPoints[index - 1];
        final pointMap = point.toMap();

        // Calculate real distance if location is available
        if (_currentLocation != null) {
          double distanceInMeters = Geolocator.distanceBetween(
            _currentLocation!.latitude,
            _currentLocation!.longitude,
            point.latitude,
            point.longitude,
          );
          pointMap['distance'] = distanceInMeters > 1000 
            ? '${(distanceInMeters / 1000).toStringAsFixed(1)} km'
            : '${distanceInMeters.round()} m';
        }

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DropPointDetailScreen(point: pointMap),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDarkMode ? Colors.white10 : Colors.grey.shade100),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _buildPointCardContent(pointMap, primaryColor, isDarkMode, isCarousel: false),
          ),
        );
      },
            ),
          );
  }

  Widget _buildPointCardContent(Map<String, dynamic> point, Color primaryColor, bool isDarkMode, {required bool isCarousel}) {
    return Column(
      mainAxisSize: MainAxisSize.min, // Essential to prevent layout errors
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    point['name'] ?? '',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isCarousel ? 16 : 17,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    point['address'] ?? '',
                    style: TextStyle(
                      fontSize: isCarousel ? 12 : 13,
                      color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade500,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                point['distance'] ?? '',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        if (!isCarousel) const SizedBox(height: 24) else const Spacer(),
        Padding(
          padding: EdgeInsets.only(top: isCarousel ? 4 : 12),
          child: Divider(color: isDarkMode ? Colors.white10 : Colors.grey.shade100, height: 1),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(Icons.schedule, size: 18, color: primaryColor),
            const SizedBox(width: 4),
            Text(
              point['schedule'] ?? '',
              style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600),
            ),
            const SizedBox(width: 12),
            Icon(Icons.star, size: 18, color: primaryColor),
            const SizedBox(width: 4),
            Text(
              (point['rating'] ?? 0.0).toString(),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () => _openDirections(point['latitude'], point['longitude']),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.directions, size: 16),
                  const SizedBox(width: 4),
                  const Text('Petunjuk Arah', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

}
