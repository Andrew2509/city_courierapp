import 'package:flutter/material.dart';
import 'package:city_courierapp/screens/home/shipping/select_sender_screen.dart';
import 'package:city_courierapp/screens/home/shipping/item_info_screen.dart';
import 'package:city_courierapp/screens/home/shipping/select_service_screen.dart';
import 'package:city_courierapp/screens/home/shipping/confirmation_screen.dart';
import 'package:city_courierapp/screens/home/shipping/widgets/pickup_time_bottom_sheet.dart';

class PickupScreen extends StatefulWidget {
  const PickupScreen({Key? key}) : super(key: key);

  @override
  State<PickupScreen> createState() => _PickupScreenState();
}

class _PickupScreenState extends State<PickupScreen> {
  String? selectedPickupTime;
  bool isItemInfoSaved = false;
  String itemDeskripsi = '';
  double itemBerat = 0.0;
  double itemBeratVolume = 0.0;
  int itemJumlah = 0;
  
  Map<String, dynamic>? senderData;
  Map<String, dynamic>? receiverData;

  Map<String, dynamic>? selectedCourier = {
    'code': 'regular',
    'name': 'City Regular',
    'service': 'REGULAR',
    'duration': '1-2 Hari',
    'price': 15000,
    'icon': Icons.local_shipping,
  };
  bool asuransiPengiriman = false;
  bool packingKayu = false;

  final TextEditingController senderController = TextEditingController();
  final TextEditingController receiverController = TextEditingController();

  @override
  void dispose() {
    senderController.dispose();
    receiverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFEC5B13);
    const bgLight = Color(0xFFF9FAFB);
    const bgDark = Color(0xFF0F172A);
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? bgDark : bgLight,
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 16,
                    bottom: 32,
                  ),
                  child: Transform.translate(
                    offset: const Offset(0, -24),
                    child: Column(
                      children: [
                        _buildAddressCard(context, isDarkMode, primaryColor),
                        const SizedBox(height: 12),
                        _buildPickupTimeButton(
                          context,
                          isDarkMode,
                          primaryColor,
                        ),
                        if (senderController.text.isNotEmpty &&
                            receiverController.text.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _buildItemInfoButton(
                            context,
                            isDarkMode,
                            primaryColor,
                          ),
                          if (isItemInfoSaved) ...[
                            const SizedBox(height: 12),
                             _buildServiceSelectionButton(
                              context,
                              isDarkMode,
                              primaryColor,
                              origin: (senderData?['subdistrict_id'] ?? senderData?['city_id'])?.toString(),
                              destination: (receiverData?['subdistrict_id'] ?? receiverData?['city_id'])?.toString(),
                              originName: senderData != null ? '${senderData!['name']} - ${senderData!['city_name']}' : 'Lokasi Pengirim',
                              destinationName: receiverData != null ? '${receiverData!['name']} - ${receiverData!['city_name']}' : 'Lokasi Penerima',
                              weight: (itemBerat * 1000).toInt(), // weight in grams
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              _buildBottomBar(context, isDarkMode, primaryColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 32,
        left: 20,
        right: 20,
        bottom: 48,
      ),
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFEC5B13), Color(0xFFEC5B13)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Request Pickup',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Text(
            'Riwayat',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressCard(
    BuildContext context,
    bool isDarkMode,
    Color primaryColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Sender
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: const BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  Container(
                    width: 2,
                    height: 52, // Adjust height based on TextField + padding
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.grey.shade700
                          : Colors.grey.shade300,
                    ),
                    // For a dashed line effect, Flutter's CustomPaint is better,
                    // but a simple solid or dotted container works as a fallback without extra packages.
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PENGIRIM',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode
                            ? Colors.grey.shade500
                            : Colors.grey.shade400,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SelectSenderScreen(),
                          ),
                        );
                        if (result != null && result is Map<String, dynamic>) {
                          String name = result['name'] ?? 'Pengirim';
                          String phone = result['phone'] ?? '';
                          String phoneShort = phone.length > 4
                              ? '${phone.substring(0, 4)}...'
                              : phone;

                           setState(() {
                            senderData = result;
                            senderController.text = '$name ($phoneShort)';
                          });
                        }
                      },
                      child: AbsorbPointer(
                        child: TextField(
                          controller: senderController,
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : Colors.black87,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Budi - Jakarta Selatan',
                            hintStyle: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 14,
                            ),
                            filled: true,
                            fillColor: isDarkMode
                                ? const Color(0xFF0F172A).withOpacity(0.5)
                                : Colors.grey.shade50,
                            suffixIcon: Icon(
                              Icons.contact_page,
                              color: primaryColor.withOpacity(0.7),
                              size: 18,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDarkMode
                                    ? Colors.grey.shade700
                                    : Colors.grey.shade100,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDarkMode
                                    ? Colors.grey.shade700
                                    : Colors.grey.shade100,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: primaryColor),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            isDense: true,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ],
          ),
          // Receiver
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PENERIMA',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode
                            ? Colors.grey.shade500
                            : Colors.grey.shade400,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SelectSenderScreen(),
                          ),
                        );
                        if (result != null && result is Map<String, dynamic>) {
                          String name = result['name'] ?? 'Penerima';
                          String phone = result['phone'] ?? '';
                          String phoneShort = phone.length > 4
                              ? '${phone.substring(0, 4)}...'
                              : phone;

                           setState(() {
                            receiverData = result;
                            receiverController.text = '$name ($phoneShort)';
                          });
                        }
                      },
                      child: AbsorbPointer(
                        child: TextField(
                          controller: receiverController,
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : Colors.black87,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Masukan informasi penerima',
                            hintStyle: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 14,
                            ),
                            filled: true,
                            fillColor: isDarkMode
                                ? const Color(0xFF0F172A).withOpacity(0.5)
                                : Colors.grey.shade50,
                            suffixIcon: Icon(
                              Icons.contact_page,
                              color: primaryColor.withOpacity(0.7),
                              size: 18,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDarkMode
                                    ? Colors.grey.shade700
                                    : Colors.grey.shade100,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDarkMode
                                    ? Colors.grey.shade700
                                    : Colors.grey.shade100,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: primaryColor),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            isDense: true,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPickupTimeButton(
    BuildContext context,
    bool isDarkMode,
    Color primaryColor,
  ) {
    return GestureDetector(
      onTap: () async {
        final result = await showModalBottomSheet<String>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (context) {
            return PickupTimeBottomSheet(
              primaryColor: primaryColor,
            );
          },
        );
        if (result != null) {
          setState(() {
            selectedPickupTime = result;
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withOpacity(0.05),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.orange.shade900.withOpacity(0.2)
                        : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.schedule, color: primaryColor, size: 18),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Waktu Penjemputan',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade400,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      selectedPickupTime ?? 'Pilih Waktu Pickup',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (selectedPickupTime != null)
              Icon(Icons.check_circle, color: primaryColor, size: 20)
            else
              Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildItemInfoButton(
    BuildContext context,
    bool isDarkMode,
    Color primaryColor,
  ) {
    if (isItemInfoSaved) {
      return GestureDetector(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ItemInfoScreen()),
          );
          if (result != null &&
              result is Map &&
              result['status'] == 'tersimpan') {
            setState(() {
              isItemInfoSaved = true;
              itemDeskripsi = result['deskripsi'] ?? 'Peralatan Rumah Tangga';
              itemBerat = result['berat'] ?? 1.5;
              itemBeratVolume = result['beratVolume'] ?? 1.8;
              itemJumlah = result['jumlahBarang'] ?? 1;
            });
          }
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDarkMode
                  ? Colors.grey.shade700.withOpacity(0.5)
                  : Colors.grey.shade100,
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.05),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? Colors.orange.shade900.withOpacity(0.2)
                              : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.inventory_2,
                          color: primaryColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'INFORMASI BARANG',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode
                                  ? Colors.grey.shade500
                                  : Colors.grey.shade400,
                              letterSpacing: 1,
                            ),
                          ),
                          Text(
                            itemDeskripsi.isEmpty
                                ? 'Peralatan Rumah Tangga'
                                : itemDeskripsi,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode
                                  ? Colors.white
                                  : Colors.grey.shade800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Icon(Icons.check_circle, color: primaryColor, size: 20),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: isDarkMode
                          ? Colors.grey.shade700.withOpacity(0.5)
                          : Colors.grey.shade50,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.fitness_center,
                                size: 14,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'BERAT',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${itemBerat.toStringAsFixed(1)} KG',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode
                                  ? Colors.grey.shade200
                                  : Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      height: 24,
                      width: 1,
                      color: isDarkMode
                          ? Colors.grey.shade700.withOpacity(0.5)
                          : Colors.grey.shade100,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.square_foot,
                                size: 14,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'VOLUM',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${itemBeratVolume.toStringAsFixed(2)} KGV',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode
                                  ? Colors.grey.shade200
                                  : Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      height: 24,
                      width: 1,
                      color: isDarkMode
                          ? Colors.grey.shade700.withOpacity(0.5)
                          : Colors.grey.shade100,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.all_inbox,
                                size: 14,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'JUMLAH',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$itemJumlah Barang',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode
                                  ? Colors.grey.shade200
                                  : Colors.grey.shade700,
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
      );
    }

    // Default Unsaved State
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ItemInfoScreen()),
        );
        if (result != null &&
            result is Map &&
            result['status'] == 'tersimpan') {
          setState(() {
            isItemInfoSaved = true;
            itemDeskripsi = result['deskripsi'] ?? 'Peralatan Rumah Tangga';
            itemBerat = result['berat'] ?? 1.5;
            itemBeratVolume = result['beratVolume'] ?? 1.8;
            itemJumlah = result['jumlahBarang'] ?? 1;
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.transparent),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withOpacity(0.05),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.orange.shade900.withOpacity(0.2)
                        : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.inventory_2, color: primaryColor, size: 24),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Informasi Barang',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Isi detail paket Anda',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isDarkMode
                            ? Colors.grey.shade500
                            : Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Icon(
              Icons.chevron_right,
              color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade300,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(int amount) {
    final str = amount.toString();
    return 'Rp${str.replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  Widget _buildServiceSelectionButton(
    BuildContext context,
    bool isDarkMode,
    Color primaryColor, {
    String? origin,
    String? destination,
    String? originName,
    String? destinationName,
    int? weight,
  }) {
    String courierName = selectedCourier?['name'] ?? 'Pilih Layanan';
    int courierPrice = selectedCourier?['price'] ?? 0;

    return Column(
      children: [
        GestureDetector(
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SelectServiceScreen(
                  initialCourier: selectedCourier,
                  asuransiPengiriman: asuransiPengiriman,
                  packingKayu: packingKayu,
                  origin: origin,
                  destination: destination,
                  originName: originName,
                  destinationName: destinationName,
                  weight: weight,
                ),
              ),
            );

            if (result != null &&
                result is Map &&
                result['status'] == 'tersimpan') {
              setState(() {
                selectedCourier = result['courier'];
                asuransiPengiriman = result['asuransi'];
                packingKayu = result['packingKayu'];
              });
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: primaryColor, width: 2),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.orange.shade900.withOpacity(0.2)
                            : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.local_shipping,
                        color: primaryColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PILIH LAYANAN',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode
                                ? Colors.grey.shade500
                                : Colors.grey.shade400,
                            letterSpacing: 1,
                          ),
                        ),
                        Text(
                          courierPrice == 0
                              ? 'City Regular'
                              : '${courierName.split(' ').last} - ${_formatCurrency(courierPrice)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Icon(
                  Icons.chevron_right,
                  color: Colors.grey.shade400,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Ketuk untuk mengganti jenis pengiriman',
          style: TextStyle(
            fontSize: 10,
            fontStyle: FontStyle.italic,
            color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade400,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(
    BuildContext context,
    bool isDarkMode,
    Color primaryColor,
  ) {
    int totalHarga = 0;
    if (selectedCourier != null) {
      totalHarga += (selectedCourier!['price'] as int);
    }
    if (asuransiPengiriman) totalHarga += 2500;
    if (packingKayu) totalHarga += 50000;

    String _formatCurrency(int amount) {
      final str = amount.toString();
      return 'Rp${str.replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
    }

    if (isItemInfoSaved) {
      return Container(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).padding.bottom + 16,
        ),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF0F172A) : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.payments, color: primaryColor, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'TOTAL',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode
                            ? Colors.grey.shade400
                            : Colors.grey.shade500,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  selectedCourier == null ? 'Rp0' : _formatCurrency(totalHarga),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: isDarkMode ? Colors.white : Colors.grey.shade900,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ConfirmationScreen(
                        selectedCourier: selectedCourier,
                        itemDeskripsi: itemDeskripsi.isEmpty ? 'Peralatan Rumah Tangga' : itemDeskripsi,
                        itemBerat: itemBerat,
                        itemBeratVolume: itemBeratVolume,
                        itemJumlah: itemJumlah,
                        asuransiPengiriman: asuransiPengiriman,
                        packingKayu: packingKayu,
                        senderData: senderData,
                        receiverData: receiverData,
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.2),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'Selanjutnya',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF0F172A) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.payments, color: primaryColor, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'ESTIMASI',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode
                            ? Colors.grey.shade400
                            : Colors.grey.shade500,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Rp0',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: isDarkMode ? Colors.white : Colors.grey.shade900,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? const Color(0xFFEC5B13)
                    : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                'Selanjutnya',
                style: TextStyle(
                  color: isDarkMode
                      ? Colors.grey.shade500
                      : const Color(0xFF64748B),
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
}
