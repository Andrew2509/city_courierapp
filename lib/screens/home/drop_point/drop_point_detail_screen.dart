import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

class DropPointDetailScreen extends StatefulWidget {
  final Map<String, dynamic> point;

  const DropPointDetailScreen({
    super.key,
    required this.point,
  });

  @override
  State<DropPointDetailScreen> createState() => _DropPointDetailScreenState();
}

class _DropPointDetailScreenState extends State<DropPointDetailScreen> {
  final TextEditingController _reviewController = TextEditingController();
  int _rating = 4;

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _openDirections() async {
    final lat = double.parse((widget.point['latitude'] ?? 0.0).toString());
    final lng = double.parse((widget.point['longitude'] ?? 0.0).toString());
    
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

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    const primaryColor = Color(0xFFEC5B13);
    final bgLight = const Color(0xFFF8F6F6);
    final bgDark = const Color(0xFF0F172A);
    final surfaceColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDarkMode ? Colors.white.withOpacity(0.1) : const Color(0xFFF1F5F9);

    return Scaffold(
      backgroundColor: isDarkMode ? bgDark : bgLight,
      body: Stack(
        children: [
          // 1. Fixed Base Layer: Interactive Map Section
          SizedBox(
            height: 280,
            width: double.infinity,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(
                  double.parse((widget.point['latitude'] ?? 0.0).toString()),
                  double.parse((widget.point['longitude'] ?? 0.0).toString()),
                ),
                initialZoom: 15.0,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none, // Disable interaction to keep it as a header
                ),
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
                    Marker(
                      point: LatLng(
                        double.parse((widget.point['latitude'] ?? 0.0).toString()),
                        double.parse((widget.point['longitude'] ?? 0.0).toString()),
                      ),
                      width: 45,
                      height: 45,
                      child: const Icon(
                        Icons.location_on,
                        color: Color(0xFFEC5B13),
                        size: 45,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. Middle Layer: Scrolling Content
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Spacer to allow visibility of the fixed map
              const SliverToBoxAdapter(
                child: SizedBox(height: 240),
              ),

              // Main Content (BottomSheet Style transition)
              SliverToBoxAdapter(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDarkMode ? bgDark : bgLight,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 30,
                        offset: const Offset(0, -10),
                      ),
                    ],
                  ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Handle
                        Center(
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 16),
                            height: 6,
                            width: 48,
                            decoration: BoxDecoration(
                              color: isDarkMode ? Colors.blueGrey[700] : Colors.blueGrey[300],
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),

                        // Header Info
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.point['name'] ?? 'City Courier - Location',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: isDarkMode ? Colors.white : Colors.blueGrey[900],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      widget.point['address'] ?? '',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isDarkMode ? Colors.blueGrey[400] : Colors.blueGrey[600],
                                        height: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(Icons.near_me_outlined, size: 14, color: primaryColor),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${widget.point['distance'] ?? '0 km'} away',
                                          style: TextStyle(
                                            color: primaryColor,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(isDarkMode ? 0.2 : 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      (widget.point['rating'] ?? 0.0).toString(),
                                      style: TextStyle(
                                        color: primaryColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                    Row(
                                      children: List.generate(5, (index) {
                                        return Icon(
                                          Icons.star,
                                          size: 10,
                                          color: primaryColor,
                                        );
                                      }),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Action Button
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: ElevatedButton.icon(
                            onPressed: _openDirections,
                            icon: const Icon(Icons.near_me, size: 20),
                            label: const Text(
                              'Petunjuk Arah',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 56),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 8,
                              shadowColor: primaryColor.withOpacity(0.4),
                            ),
                          ),
                        ),

                        // Operating Hours
                        _buildSectionHeader(Icons.schedule, 'Jam Operasional', isDarkMode),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: surfaceColor,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: borderColor),
                            ),
                            child: Column(
                              children: [
                                _buildHourRow('Senin - Jumat', widget.point['schedule'] ?? '08:00 - 21:00', isDarkMode, false),
                                _buildHourRow('Sabtu', '09:00 - 18:00', isDarkMode, false),
                                _buildHourRow('Minggu', 'Tutup', isDarkMode, true),
                              ],
                            ),
                          ),
                        ),

                        // User Reviews
                        const SizedBox(height: 32),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.reviews_outlined, color: Colors.blueGrey[400], size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Ulasan Pelanggan',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold, 
                                      color: isDarkMode ? Colors.white : Colors.blueGrey[900],
                                    ),
                                  ),
                                ],
                              ),
                              TextButton(
                                onPressed: () {},
                                child: Text(
                                  'Lihat Semua',
                                  style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Write Review Form
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: surfaceColor,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: borderColor),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tulis Ulasan',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isDarkMode ? Colors.white : Colors.blueGrey[900],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: List.generate(5, (index) {
                                    return GestureDetector(
                                      onTap: () => setState(() => _rating = index + 1),
                                      child: Icon(
                                        Icons.star,
                                        size: 28,
                                        color: index < _rating ? primaryColor : (isDarkMode ? Colors.blueGrey[700] : Colors.blueGrey[200]),
                                      ),
                                    );
                                  }),
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _reviewController,
                                  maxLines: 3,
                                  decoration: InputDecoration(
                                    hintText: 'Ceritakan pengalaman Anda di sini...',
                                    hintStyle: TextStyle(color: Colors.blueGrey[400], fontSize: 13),
                                    fillColor: isDarkMode ? Colors.white.withOpacity(0.05) : const Color(0xFFF8FAFC),
                                    filled: true,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: TextButton(
                                    onPressed: () {},
                                    style: TextButton.styleFrom(
                                      backgroundColor: primaryColor.withOpacity(0.1),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    child: Text(
                                      'Kirim Ulasan',
                                      style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Review List
                        _buildReviewItem('Budi Santoso', 5, 'Pelayanan sangat cepat dan ramah. Lokasi mudah ditemukan.', isDarkMode, primaryColor, borderColor, surfaceColor),
                        _buildReviewItem('Siti Aminah', 4, 'Tempat bersih, parkiran luas untuk motor. Sangat membantu.', isDarkMode, primaryColor, borderColor, surfaceColor),
                        
                        const SizedBox(height: 120), // Padding for sticky CTA
                      ],
                    ),
                  ),
                ),
              ],
            ),
          // 3. Top Layer: Fixed Back Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: (isDarkMode ? bgDark : Colors.white).withOpacity(0.9),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.arrow_back,
                  color: isDarkMode ? Colors.white : Colors.blueGrey[900],
                  size: 20,
                ),
              ),
            ),
          ),

          // 4. Bottom Layer: Sticky Bottom CTA
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              decoration: BoxDecoration(
                color: (isDarkMode ? bgDark : Colors.white).withOpacity(0.8),
                border: Border(top: BorderSide(color: borderColor)),
              ),
              child: ElevatedButton.icon(
                onPressed: () {
                  // This could lead to the order flow with this shop selected
                },
                icon: const Icon(Icons.inventory_2_outlined, size: 20),
                label: const Text(
                  'Kirim Paket dari Sini',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDarkMode ? primaryColor : Colors.blueGrey[900],
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Row(
        children: [
          Icon(icon, color: Colors.blueGrey[400], size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.blueGrey[900],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHourRow(String day, String time, bool isDarkMode, bool isClosed) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDarkMode ? Colors.white.withOpacity(0.05) : const Color(0xFFF8FAFC),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            day,
            style: TextStyle(
              color: isDarkMode ? Colors.blueGrey[400] : Colors.blueGrey[600],
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            time,
            style: TextStyle(
              color: isClosed ? const Color(0xFFEC5B13) : (isDarkMode ? Colors.white : Colors.blueGrey[900]),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewItem(String name, int rating, String comment, bool isDarkMode, Color primaryColor, Color borderColor, Color surfaceColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isDarkMode ? Colors.white : Colors.blueGrey[900],
                  ),
                ),
                Row(
                  children: List.generate(5, (index) {
                    return Icon(
                      Icons.star,
                      size: 14,
                      color: index < rating ? primaryColor : (isDarkMode ? Colors.blueGrey[700] : Colors.blueGrey[200]),
                    );
                  }),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '"$comment"',
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: isDarkMode ? Colors.blueGrey[400] : Colors.blueGrey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
