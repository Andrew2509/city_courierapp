import 'package:flutter/material.dart';
import '../shipping/select_region_screen.dart';
import 'estimation_result_screen.dart';

class CekOngkirScreen extends StatefulWidget {
  const CekOngkirScreen({super.key});

  @override
  State<CekOngkirScreen> createState() => _CekOngkirScreenState();
}

class _CekOngkirScreenState extends State<CekOngkirScreen> {
  bool get isDarkMode => Theme.of(context).brightness == Brightness.dark;
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _lengthController = TextEditingController();
  final TextEditingController _widthController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  
  String? _senderLoc;
  String? _receiverLoc;
  String? _senderId;
  String? _receiverId;
  
  double _volumeWeight = 0.0;

  @override
  void initState() {
    super.initState();
    _lengthController.addListener(_calculateVolumeWeight);
    _widthController.addListener(_calculateVolumeWeight);
    _heightController.addListener(_calculateVolumeWeight);
  }

  void _calculateVolumeWeight() {
    final double l = double.tryParse(_lengthController.text) ?? 0;
    final double w = double.tryParse(_widthController.text) ?? 0;
    final double h = double.tryParse(_heightController.text) ?? 0;
    
    setState(() {
      _volumeWeight = (l * w * h) / 6000;
    });
  }

  @override
  void dispose() {
    _weightController.dispose();
    _lengthController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFEC5B13);
    final secondaryColor = const Color(0xFFEC5B13);
    final bgLight = const Color(0xFFF9FAFB);

    return Scaffold(
        backgroundColor: isDarkMode ? const Color(0xFF0F172A) : bgLight,
        body: Stack(
          children: [
            Column(
              children: [
                _buildHeader(context, secondaryColor, primaryColor),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(left: 16, right: 16, top: 0, bottom: 40),
                    child: Transform.translate(
                      offset: const Offset(0, -16),
                      child: _buildMainCard(primaryColor),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
  }

  Widget _buildHeader(BuildContext context, Color secondaryColor, Color primaryColor) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 20,
        bottom: 32,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [secondaryColor, primaryColor],
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.chevron_left, color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Cek Ongkir',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainCard(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          if (!isDarkMode)
            BoxShadow(
              color: Colors.grey.shade200.withValues(alpha: 0.5),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
        ],
        border: Border.all(
          color: isDarkMode ? const Color(0xFF334155) : const Color(0xFFF8FAFC),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLocationInput(
            label: 'Lokasi Pengirim',
            placeholder: _senderLoc ?? 'Pilih lokasi asal',
            icon: Icons.location_on_outlined,
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SelectRegionScreen()),
              );
              if (!mounted) return;
              if (result != null && result is Map<String, dynamic>) {
                final String newLoc = result['kecamatan_name'] ?? result['city_name'] ?? 'Lokasi';
                final String newId = (result['kecamatan_id'] ?? result['subdistrict_id'] ?? result['city_id'])?.toString() ?? '';
                setState(() {
                  _senderLoc = newLoc;
                  _senderId = newId;
                });
              }
            },
          ),
          const SizedBox(height: 16),
          _buildLocationInput(
            label: 'Lokasi Penerima',
            placeholder: _receiverLoc ?? 'Pilih lokasi tujuan',
            icon: Icons.my_location_outlined,
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SelectRegionScreen()),
              );
              if (!mounted) return;
              if (result != null && result is Map<String, dynamic>) {
                final String newLoc = result['kecamatan_name'] ?? result['city_name'] ?? 'Lokasi';
                final String newId = (result['kecamatan_id'] ?? result['subdistrict_id'] ?? result['city_id'])?.toString() ?? '';
                setState(() {
                  _receiverLoc = newLoc;
                  _receiverId = newId;
                });
              }
            },
          ),
          const SizedBox(height: 16),
          _buildLabel('Berat Barang (Kg)'),
          const SizedBox(height: 6),
          _buildNumberInput(
            controller: _weightController,
            placeholder: '0.00',
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildLabel('Dimensi Barang (Cm)'),
              const Text(
                'P × L × T',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 2.2,
            ),
            children: [
              _buildNumberInput(controller: _lengthController, placeholder: 'P', textAlign: TextAlign.center),
              _buildNumberInput(controller: _widthController, placeholder: 'L', textAlign: TextAlign.center),
              _buildNumberInput(controller: _heightController, placeholder: 'T', textAlign: TextAlign.center),
            ],
          ),
          const SizedBox(height: 16),
          _buildVolumeWeightDisplay(),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                if (_senderLoc == null || _receiverLoc == null) return;
                
                final double weight = double.tryParse(_weightController.text) ?? 0.0;
                final double finalWeight = weight > _volumeWeight ? weight : _volumeWeight;
                
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EstimationResultScreen(
                      origin: _senderLoc!,
                      originId: _senderId!,
                      destination: _receiverLoc!,
                      destinationId: _receiverId!,
                      weight: finalWeight,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
              child: const Text(
                'Cek Ongkir',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade500,
        ),
      ),
    );
  }

  Widget _buildLocationInput({
    required String label,
    required String placeholder,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF1E293B).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDarkMode ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: Colors.grey.shade400),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    placeholder,
                    style: TextStyle(
                      fontSize: 14,
                      color: (placeholder == 'Pilih lokasi asal' || placeholder == 'Pilih lokasi tujuan') 
                          ? Colors.grey.shade400 
                          : (isDarkMode ? Colors.white : Colors.black87),
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNumberInput({
    required TextEditingController controller,
    required String placeholder,
    TextAlign textAlign = TextAlign.start,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: textAlign,
      style: TextStyle(
        fontSize: 14,
        color: isDarkMode ? Colors.white : Colors.black87,
      ),
      decoration: InputDecoration(
        hintText: placeholder,
        hintStyle: TextStyle(color: Colors.grey.shade300, fontSize: 13),
        filled: true,
        fillColor: isDarkMode ? const Color(0xFF1E293B).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDarkMode ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDarkMode ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEC5B13)),
        ),
      ),
    );
  }

  Widget _buildVolumeWeightDisplay() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E293B).withValues(alpha: 0.3) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDarkMode ? const Color(0xFF334155) : Colors.grey.shade200,
          style: BorderStyle.solid,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.calculate_outlined, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          const Text(
            'Total Berat Volume:',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          const Spacer(),
          Text(
            '${_volumeWeight.toStringAsFixed(2)} Kg',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.grey.shade200 : const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }
}
