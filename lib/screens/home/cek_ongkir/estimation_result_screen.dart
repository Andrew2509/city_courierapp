import 'package:flutter/material.dart';
import '../../../services/shipping/rajaongkir_service.dart';
import '../../../services/shipping/rajaongkir_parser.dart';

class EstimationResultScreen extends StatefulWidget {
  final String origin;
  final String originId;
  final String destination;
  final String destinationId;
  final double weight;

  const EstimationResultScreen({
    super.key,
    required this.origin,
    required this.originId,
    required this.destination,
    required this.destinationId,
    required this.weight,
  });

  @override
  State<EstimationResultScreen> createState() => _EstimationResultScreenState();
}

class _EstimationResultScreenState extends State<EstimationResultScreen> {
  bool get isDarkMode => Theme.of(context).brightness == Brightness.dark;
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _availableServices = [];
  Map<String, dynamic>? _selectedService;

  @override
  void initState() {
    super.initState();
    _fetchShippingCosts();
  }

  Future<void> _fetchShippingCosts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await RajaOngkirService.calculateCost(
        origin: widget.originId,
        destination: widget.destinationId,
        weight: (widget.weight * 1000).toInt(),
        courier: 'jne:pos:tiki:sicepat:jnt', // Fetch multiple couriers
      );

      if (response['success'] == true && response['data'] != null) {
        final List<Map<String, dynamic>> parsedServices =
            RajaOngkirParser.parseCouriers(response['data']);

        List<Map<String, dynamic>> services = [];
        for (var s in parsedServices) {
          services.add({
            'courier_name': s['name'],
            'courier_code': s['code'],
            'service': s['service'],
            'description': s['description'],
            'price': s['price'],
            'etd': s['etd'],
            'duration': s['duration'],
            'display_title': '${s['name']} - ${s['service']}',
          });
        }

        // Sort by price (lowest first)
        services.sort((a, b) => (a['price'] as int).compareTo(b['price'] as int));

        setState(() {
          _availableServices = services;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = response['message'] ?? 'Gagal mengambil data ongkir';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Terjadi kesalahan koneksi. Pastikan ID wilayah benar.';
        _isLoading = false;
      });
    }
  }

  IconData _getCourierIcon(String code) {
    code = code.toLowerCase();
    if (code.contains('jne')) return Icons.local_shipping;
    if (code.contains('pos')) return Icons.local_post_office;
    if (code.contains('tiki')) return Icons.airport_shuttle;
    if (code.contains('j&t') || code.contains('jnt')) return Icons.bolt;
    if (code.contains('sicepat')) return Icons.flash_on;
    return Icons.local_shipping_outlined;
  }

  Color _getCourierColor(String code) {
    code = code.toLowerCase();
    if (code.contains('jne')) return const Color(0xFF003399);
    if (code.contains('pos')) return const Color(0xFFFF6600);
    if (code.contains('tiki')) return const Color(0xFF003399);
    if (code.contains('jnt')) return const Color(0xFFE31E24);
    if (code.contains('sicepat')) return const Color(0xFFED1C24);
    return const Color(0xFFEC5B13);
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFEC5B13);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.chevron_left, color: Colors.white, size: 20),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Hasil Estimasi',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: false,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _buildRouteSummary(isDarkMode),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _errorMessage != null
                        ? _buildErrorState()
                        : _availableServices.isEmpty
                            ? _buildEmptyState()
                            : _buildServiceList(),
              ),
            ],
          ),
          if (_selectedService != null) _buildBottomBar(primaryColor),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _fetchShippingCosts,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.sentiment_dissatisfied, size: 48, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Tidak ada layanan pengiriman tersedia\nuntuk rute ini.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _availableServices.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final service = _availableServices[index];
        return _buildServiceOption(service);
      },
    );
  }

  Widget _buildRouteSummary(bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        ),
        boxShadow: [
          if (!isDarkMode)
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'RUTE PENGIRIMAN',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Text(
                        widget.origin,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.east, size: 14, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        widget.destination,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 30,
            width: 1,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            color: isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'BERAT',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.weight.toStringAsFixed(1)} Kg',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFEC5B13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServiceOption(Map<String, dynamic> service) {
    final bool isSelected = _selectedService == service;
    final String courierCode = service['courier_code'];
    final Color iconColor = _getCourierColor(courierCode);
    const primaryColor = Color(0xFFEC5B13);

    return GestureDetector(
      onTap: () => setState(() => _selectedService = service),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDarkMode
                  ? primaryColor.withOpacity(0.05)
                  : const Color(0xFFFFF7ED))
              : (isDarkMode ? const Color(0xFF0F172A) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? primaryColor
                : (isDarkMode
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFF1F5F9)),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_getCourierIcon(courierCode), color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service['display_title'],
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    service['duration'] ?? 'Estimasi tidak tersedia',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Rp ${service['price'].toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFEC5B13),
                  ),
                ),
              ],
            ),
            if (isSelected)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: const Icon(Icons.check_circle, color: Color(0xFFEC5B13), size: 18),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(Color primaryColor) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).padding.bottom + 16,
        ),
        decoration: BoxDecoration(
          color: isDarkMode
              ? const Color(0xFF0F172A).withOpacity(0.9)
              : Colors.white.withOpacity(0.9),
          border: Border(
            top: BorderSide(
              color: isDarkMode
                  ? const Color(0xFF1E293B)
                  : const Color(0xFFF1F5F9)),
          ),
        ),
        child: ElevatedButton(
          onPressed: () {
            // Future: Implement ordering flow
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 4,
            shadowColor: primaryColor.withOpacity(0.3),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Pesan Sekarang',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
