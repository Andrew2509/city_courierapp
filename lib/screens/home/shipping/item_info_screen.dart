import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:city_courierapp/models/shipping/vehicle_capacity_config.dart';

class ItemInfoScreen extends StatefulWidget {
  final String initialVehicle;
  final double? initialBerat;
  final double? initialPanjang;
  final double? initialLebar;
  final double? initialTinggi;
  final int? initialJumlah;
  final String? initialDeskripsi;
  final String? initialKategori;
  final List<String>? initialPhotoPaths;

  const ItemInfoScreen({
    super.key,
    this.initialVehicle = 'motor',
    this.initialBerat,
    this.initialPanjang,
    this.initialLebar,
    this.initialTinggi,
    this.initialJumlah,
    this.initialDeskripsi,
    this.initialKategori,
    this.initialPhotoPaths,
  });

  @override
  State<ItemInfoScreen> createState() => _ItemInfoScreenState();
}

class _ItemInfoScreenState extends State<ItemInfoScreen> {
  bool get isDarkMode => Theme.of(context).brightness == Brightness.dark;
  String jenisKiriman = 'Barang'; // 'Dokumen' or 'Barang'
  String? kategoriBarang = 'lainnya';
  late String selectedKendaraan;

  late final TextEditingController deskripsiController;
  late final TextEditingController panjangController;
  late final TextEditingController lebarController;
  late final TextEditingController tinggiController;
  late final TextEditingController beratController;

  int jumlahBarang = 1;

  // Daftar file foto barang nyata
  final List<File> _itemPhotos = [];
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    deskripsiController = TextEditingController(
      text: widget.initialDeskripsi ?? 'Peralatan Rumah Tangga',
    );
    panjangController = TextEditingController(
      text: widget.initialPanjang != null
          ? (widget.initialPanjang! % 1 == 0
              ? widget.initialPanjang!.toInt().toString()
              : widget.initialPanjang!.toString())
          : '30',
    );
    lebarController = TextEditingController(
      text: widget.initialLebar != null
          ? (widget.initialLebar! % 1 == 0
              ? widget.initialLebar!.toInt().toString()
              : widget.initialLebar!.toString())
          : '20',
    );
    tinggiController = TextEditingController(
      text: widget.initialTinggi != null
          ? (widget.initialTinggi! % 1 == 0
              ? widget.initialTinggi!.toInt().toString()
              : widget.initialTinggi!.toString())
          : '15',
    );
    beratController = TextEditingController(
      text: widget.initialBerat != null
          ? (widget.initialBerat! % 1 == 0
              ? widget.initialBerat!.toInt().toString()
              : widget.initialBerat!.toString())
          : '1.5',
    );

    if (widget.initialJumlah != null) {
      jumlahBarang = widget.initialJumlah!;
    }
    if (widget.initialKategori != null) {
      kategoriBarang = widget.initialKategori;
    }

    // Inisialisasi foto yang sudah ada jika ada
    if (widget.initialPhotoPaths != null) {
      for (final path in widget.initialPhotoPaths!) {
        final file = File(path);
        if (file.existsSync()) {
          _itemPhotos.add(file);
        }
      }
    }

    // Evaluasi awal kendaraan berdasarkan berat dan dimensi
    final initialDetection = VehicleCapacityConfig.detect(
      weight: berat,
      length: panjang,
      width: lebar,
      height: tinggi,
    );

    if (initialDetection.isValid && initialDetection.recommendedVehicle != null) {
      selectedKendaraan = initialDetection.recommendedVehicle!;
    } else {
      selectedKendaraan = widget.initialVehicle;
    }

    panjangController.addListener(_onDimensionOrWeightChanged);
    lebarController.addListener(_onDimensionOrWeightChanged);
    tinggiController.addListener(_onDimensionOrWeightChanged);
    beratController.addListener(_onDimensionOrWeightChanged);
  }

  void _onDimensionOrWeightChanged() {
    final result = detectionResult;
    if (result.isValid && result.recommendedVehicle != null) {
      if (result.isMobil) {
        selectedKendaraan = 'mobil';
      } else if (result.isMotor) {
        selectedKendaraan = 'motor';
      }
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    panjangController.removeListener(_onDimensionOrWeightChanged);
    lebarController.removeListener(_onDimensionOrWeightChanged);
    tinggiController.removeListener(_onDimensionOrWeightChanged);
    beratController.removeListener(_onDimensionOrWeightChanged);
    deskripsiController.dispose();
    panjangController.dispose();
    lebarController.dispose();
    tinggiController.dispose();
    beratController.dispose();
    super.dispose();
  }

  double get panjang => double.tryParse(panjangController.text) ?? 0.0;
  double get lebar => double.tryParse(lebarController.text) ?? 0.0;
  double get tinggi => double.tryParse(tinggiController.text) ?? 0.0;
  double get berat => double.tryParse(beratController.text) ?? 0.0;

  /// Berat aktual barang (kg)
  double get beratAktual => berat;

  /// Berat volumetrik: (Panjang × Lebar × Tinggi) ÷ 6000
  double get beratVolumetrik => VehicleCapacityConfig.calculateVolumetricWeight(
        length: panjang,
        width: lebar,
        height: tinggi,
      );

  /// Berat pengiriman yang digunakan: MAX(Berat Aktual, Berat Volumetrik)
  double get beratPengiriman => VehicleCapacityConfig.calculateShippingWeight(
        actualWeight: beratAktual,
        volumetricWeight: beratVolumetrik,
      );

  /// Alias untuk kompatibilitas ke belakang
  double get beratVolume => beratVolumetrik;

  /// Rumus volume: Panjang × Lebar × Tinggi (dalam satuan cm³)
  double get volumeCm3 => VehicleCapacityConfig.calculateVolumeCm3(
        length: panjang,
        width: lebar,
        height: tinggi,
      );

  /// Konversi volume ke satuan Liter (1 Liter = 1.000 cm³)
  double get volumeLiter => VehicleCapacityConfig.convertCm3ToLiter(volumeCm3);

  /// Deteksi otomatis jenis kendaraan secara real-time
  VehicleDetectionResult get detectionResult => VehicleCapacityConfig.detect(
        weight: beratAktual,
        length: panjang,
        width: lebar,
        height: tinggi,
      );

  String _formatWeight(double val) {
    if (val <= 0) return '0 kg';
    return val % 1 == 0 ? '${val.toInt()} kg' : '${val.toStringAsFixed(1)} kg';
  }

  String _formatVolumeNumber(double val) {
    if (val <= 0) return '0';
    final int rounded = val.round();
    final str = rounded.toString();
    return str.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  // --- FUNGSI AMBIL FOTO (KAMERA / GALERI) ---
  Future<void> _pickImage(ImageSource source) async {
    if (_itemPhotos.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maksimal 3 foto barang.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        final fileSize = await file.length();
        // Cek ukuran file max 5 MB (5 * 1024 * 1024 bytes)
        if (fileSize > 5 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Ukuran foto melebihi batas 5MB.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        if (mounted) {
          setState(() {
            _itemPhotos.add(file);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengambil foto: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showImageSourcePicker(BuildContext context, bool isDarkMode, Color primaryColor) {
    if (_itemPhotos.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maksimal 3 foto barang telah tercapai.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'Tambah Foto Barang',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pilih sumber foto (${_itemPhotos.length}/3 foto)',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.camera_alt, color: primaryColor, size: 22),
                  ),
                  title: Text(
                    'Ambil Foto dari Kamera',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: isDarkMode ? Colors.white : Colors.grey.shade800,
                    ),
                  ),
                  subtitle: Text(
                    'Gunakan kamera untuk memotret barang langsung',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade500,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.camera);
                  },
                ),
                const Divider(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.photo_library, color: primaryColor, size: 22),
                  ),
                  title: Text(
                    'Pilih dari Galeri',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: isDarkMode ? Colors.white : Colors.grey.shade800,
                    ),
                  ),
                  subtitle: Text(
                    'Pilih foto yang sudah tersimpan di perangkat',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade500,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPhotoPreview(File photoFile) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                photoFile,
                fit: BoxFit.contain,
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFEC5B13);
    const bgLight = Color(0xFFF8FAFC);
    const bgDark = Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: isDarkMode ? bgDark : bgLight,
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(context, primaryColor),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // KARTU 1: Informasi Dasar Paket (Jenis, Kategori, Deskripsi, Berat & Jumlah)
                      _buildCardDetailPaket(isDarkMode, primaryColor),

                      // KARTU 2: Dimensi & Kalkulasi Berat Pengiriman (Hanya untuk Paket Barang)
                      if (jenisKiriman == 'Barang') ...[
                        const SizedBox(height: 14),
                        _buildCardDimensiDanKalkulasi(isDarkMode, primaryColor),
                      ],

                      // KARTU 3: Pilihan Kendaraan & Deteksi Kapasitas
                      const SizedBox(height: 14),
                      _buildCardPilihanKendaraan(isDarkMode, primaryColor),

                      // KARTU 4: Foto Barang (Fungsional, Maks. 3 Foto)
                      const SizedBox(height: 14),
                      _buildCardFotoBarang(isDarkMode, primaryColor),

                      const SizedBox(height: 90),
                    ],
                  ),
                ),
              ),
            ],
          ),
          _buildBottomBar(context, primaryColor),
        ],
      ),
    );
  }

  // --- HEADER SCREEN ---
  Widget _buildHeader(BuildContext context, Color primaryColor) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        bottom: 16,
        left: 16,
        right: 16,
      ),
      decoration: BoxDecoration(
        color: primaryColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Informasi Barang',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 1),
                Text(
                  'Detail spesifikasi & kalkulasi pengiriman',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- REUSABLE SECTION CARD CONTAINER ---
  Widget _buildSectionCard({
    required bool isDarkMode,
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.15 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildCardHeader({
    required IconData icon,
    required String title,
    required bool isDarkMode,
    required Color primaryColor,
    Widget? trailing,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: primaryColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing,
        ],
      ],
    );
  }

  // --- KARTU 1: DETAIL PAKET (JENIS, KATEGORI, DESKRIPSI, BERAT & JUMLAH) ---
  Widget _buildCardDetailPaket(bool isDarkMode, Color primaryColor) {
    return _buildSectionCard(
      isDarkMode: isDarkMode,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(
            icon: Icons.inventory_2_outlined,
            title: 'JENIS & DETAIL PAKET',
            isDarkMode: isDarkMode,
            primaryColor: primaryColor,
          ),
          const SizedBox(height: 12),

          // Pilihan Jenis Kiriman (Dokumen / Barang)
          _buildJenisKiriman(isDarkMode, primaryColor),

          if (jenisKiriman == 'Barang') ...[
            const SizedBox(height: 14),

            // Kategori Barang Dropdown
            _buildKategoriBarang(isDarkMode, primaryColor),

            // Deskripsi Tambahan jika Kategori 'Lainnya'
            if (kategoriBarang == 'lainnya') ...[
              const SizedBox(height: 12),
              _buildDeskripsiBarang(isDarkMode, primaryColor),
            ],

            const SizedBox(height: 14),

            // Berat Aktual & Jumlah Barang (Side by side)
            _buildBeratDanJumlah(isDarkMode, primaryColor),
          ],
        ],
      ),
    );
  }

  Widget _buildJenisKiriman(bool isDarkMode, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Text(
            'JENIS KIRIMAN',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade500,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF0F172A) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      jenisKiriman = 'Dokumen';
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: jenisKiriman == 'Dokumen'
                          ? primaryColor
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: jenisKiriman == 'Dokumen'
                          ? [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Dokumen',
                      style: TextStyle(
                        color: jenisKiriman == 'Dokumen'
                            ? Colors.white
                            : Colors.grey.shade500,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      jenisKiriman = 'Barang';
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: jenisKiriman == 'Barang'
                          ? primaryColor
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: jenisKiriman == 'Barang'
                          ? [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Barang',
                      style: TextStyle(
                        color: jenisKiriman == 'Barang'
                            ? Colors.white
                            : Colors.grey.shade500,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKategoriBarang(bool isDarkMode, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Text(
            'KATEGORI BARANG',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade500,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: kategoriBarang,
              isExpanded: true,
              dropdownColor: isDarkMode
                  ? const Color(0xFF1E293B)
                  : Colors.white,
              icon: Icon(Icons.expand_more, color: Colors.grey.shade400, size: 20),
              style: TextStyle(
                color: isDarkMode
                    ? Colors.grey.shade200
                    : const Color(0xFF334155),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              items: const [
                DropdownMenuItem(value: '', child: Text('Pilih Kategori')),
                DropdownMenuItem(
                  value: 'pakaian',
                  child: Text('Pakaian & Fashion'),
                ),
                DropdownMenuItem(
                  value: 'elektronik',
                  child: Text('Elektronik'),
                ),
                DropdownMenuItem(
                  value: 'makanan',
                  child: Text('Makanan & Minuman'),
                ),
                DropdownMenuItem(
                  value: 'kosmetik',
                  child: Text('Kosmetik / Farmasi'),
                ),
                DropdownMenuItem(value: 'lainnya', child: Text('Lainnya')),
              ],
              onChanged: (value) {
                setState(() {
                  kategoriBarang = value;
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeskripsiBarang(bool isDarkMode, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Text(
            'DESKRIPSI BARANG',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade500,
              letterSpacing: 0.8,
            ),
          ),
        ),
        _buildTextField(
          deskripsiController,
          'Sebutkan jenis barang lainnya...',
          isDarkMode,
          primaryColor,
        ),
      ],
    );
  }

  Widget _buildBeratDanJumlah(bool isDarkMode, Color primaryColor) {
    return Row(
      children: [
        // Berat Aktual
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 2, bottom: 6),
                child: Text(
                  'BERAT (KG)',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode
                        ? Colors.grey.shade400
                        : Colors.grey.shade500,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF0F172A) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDarkMode
                        ? Colors.grey.shade700
                        : Colors.grey.shade300,
                  ),
                ),
                child: TextField(
                  key: const Key('field_berat'),
                  controller: beratController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black87,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: '0',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 13,
                    ),
                    suffixIcon: UnconstrainedBox(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Text(
                          'KG',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ),
                    ),
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),

        // Jumlah Barang Counter
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 2, bottom: 6),
                child: Text(
                  'JUMLAH BARANG',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode
                        ? Colors.grey.shade400
                        : Colors.grey.shade500,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF0F172A) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDarkMode
                        ? Colors.grey.shade700
                        : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      iconSize: 18,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
                      icon: const Icon(Icons.remove_circle_outline),
                      color: Colors.grey.shade400,
                      onPressed: () {
                        if (jumlahBarang > 1) {
                          setState(() {
                            jumlahBarang--;
                          });
                        }
                      },
                    ),
                    Expanded(
                      child: Text(
                        jumlahBarang.toString(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    IconButton(
                      iconSize: 18,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
                      icon: const Icon(Icons.add_circle),
                      color: primaryColor,
                      onPressed: () {
                        setState(() {
                          jumlahBarang++;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- KARTU 2: DIMENSI & KALKULASI BERAT PENGIRIMAN ---
  Widget _buildCardDimensiDanKalkulasi(bool isDarkMode, Color primaryColor) {
    final bool isVolumetricHigher = beratVolumetrik > beratAktual;

    return _buildSectionCard(
      isDarkMode: isDarkMode,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(
            icon: Icons.straighten_rounded,
            title: 'DIMENSI & KALKULASI BERAT',
            isDarkMode: isDarkMode,
            primaryColor: primaryColor,
          ),
          const SizedBox(height: 12),

          // Baris Input Dimensi (P, L, T dalam cm)
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 2, bottom: 4),
                      child: Text(
                        'Panjang',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                    ),
                    _buildTextField(
                      panjangController,
                      'P',
                      isDarkMode,
                      primaryColor,
                      key: const Key('field_panjang'),
                      suffixText: 'cm',
                      isNumber: true,
                      isCenter: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 2, bottom: 4),
                      child: Text(
                        'Lebar',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                    ),
                    _buildTextField(
                      lebarController,
                      'L',
                      isDarkMode,
                      primaryColor,
                      key: const Key('field_lebar'),
                      suffixText: 'cm',
                      isNumber: true,
                      isCenter: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 2, bottom: 4),
                      child: Text(
                        'Tinggi',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                    ),
                    _buildTextField(
                      tinggiController,
                      'T',
                      isDarkMode,
                      primaryColor,
                      key: const Key('field_tinggi'),
                      suffixText: 'cm',
                      isNumber: true,
                      isCenter: true,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // PANEL RINGKAS PERHITUNGAN BERAT PENGIRIMAN
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade200,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Perhitungan + Status Comparison Badge
                LayoutBuilder(
                  builder: (context, constraints) {
                    final bool isNarrow = constraints.maxWidth < 320;
                    final badgeWidget = Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (isVolumetricHigher ? Colors.orange : Colors.blue)
                            .withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isVolumetricHigher
                            ? 'Volumetrik Lebih Besar'
                            : 'Aktual Lebih Besar',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: isVolumetricHigher
                              ? Colors.orange.shade800
                              : Colors.blue.shade700,
                        ),
                      ),
                    );

                    return isNarrow
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.scale_rounded, size: 14, color: primaryColor),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'PERHITUNGAN BERAT PENGIRIMAN',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isDarkMode
                                            ? Colors.grey.shade300
                                            : Colors.grey.shade700,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              badgeWidget,
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.scale_rounded, size: 14, color: primaryColor),
                                  const SizedBox(width: 6),
                                  Text(
                                    'PERHITUNGAN BERAT PENGIRIMAN',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isDarkMode
                                          ? Colors.grey.shade300
                                          : Colors.grey.shade700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                              badgeWidget,
                            ],
                          );
                  },
                ),

                const SizedBox(height: 10),

                // 3 METRIK KOMPAK: AKTUAL, VOLUMETRIK, PENGIRIMAN
                LayoutBuilder(
                  builder: (context, constraints) {
                    final bool isVeryNarrow = constraints.maxWidth < 280;

                    final aktualCol = Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Berat Aktual',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade500,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _formatWeight(beratAktual),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.white : Colors.grey.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );

                    final volumetrikCol = Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Berat Volumetrik',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade500,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _formatWeight(beratVolumetrik),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.white : Colors.grey.shade800,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              '${_formatVolumeNumber(volumeCm3)} cm³',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 8.5,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );

                    final pengirimanCol = Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: primaryColor.withOpacity(0.3),
                            width: 1.2,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Berat Pengiriman',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _formatWeight(beratPengiriman),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: primaryColor,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              'MAX',
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                                color: primaryColor.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );

                    if (isVeryNarrow) {
                      return Column(
                        children: [
                          Row(
                            children: [
                              aktualCol,
                              const SizedBox(width: 8),
                              volumetrikCol,
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [pengirimanCol],
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        aktualCol,
                        const SizedBox(width: 6),
                        volumetrikCol,
                        const SizedBox(width: 6),
                        pengirimanCol,
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- KARTU 3: PILIHAN KENDARAAN & REKOMENDASI KAPASITAS ---
  Widget _buildCardPilihanKendaraan(bool isDarkMode, Color primaryColor) {
    final result = detectionResult;
    final bool canUseMotor = result.isMotor;
    final bool canUseMobil = !result.isOverCapacity;

    Color bannerBg;
    Color bannerBorder;
    Color bannerTextColor;
    IconData bannerIcon;
    String bannerTitle;

    if (result.isOverCapacity) {
      bannerBg = isDarkMode ? Colors.red.shade900.withOpacity(0.2) : Colors.red.shade50;
      bannerBorder = isDarkMode ? Colors.red.shade800 : Colors.red.shade300;
      bannerTextColor = isDarkMode ? Colors.red.shade200 : Colors.red.shade800;
      bannerIcon = Icons.warning_amber_rounded;
      bannerTitle = 'Kapasitas Melebihi Batas';
    } else if (result.isMobil) {
      bannerBg = isDarkMode ? Colors.amber.shade900.withOpacity(0.2) : Colors.amber.shade50;
      bannerBorder = isDarkMode ? Colors.amber.shade800 : Colors.amber.shade300;
      bannerTextColor = isDarkMode ? Colors.amber.shade200 : Colors.amber.shade900;
      bannerIcon = Icons.swap_horiz;
      bannerTitle = 'Dialihkan ke Mobil Otomatis';
    } else {
      bannerBg = isDarkMode ? Colors.green.shade900.withOpacity(0.2) : Colors.green.shade50;
      bannerBorder = isDarkMode ? Colors.green.shade800 : Colors.green.shade300;
      bannerTextColor = isDarkMode ? Colors.green.shade200 : Colors.green.shade900;
      bannerIcon = Icons.check_circle_outline;
      bannerTitle = 'Motor Direkomendasikan';
    }

    return _buildSectionCard(
      isDarkMode: isDarkMode,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(
            icon: Icons.electric_moped_outlined,
            title: 'PILIHAN KENDARAAN',
            isDarkMode: isDarkMode,
            primaryColor: primaryColor,
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Deteksi Otomatis',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Banner Status Rekomendasi
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: bannerBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: bannerBorder),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(bannerIcon, size: 16, color: bannerTextColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bannerTitle,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: bannerTextColor,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        result.message,
                        style: TextStyle(
                          fontSize: 10,
                          color: bannerTextColor.withOpacity(0.9),
                          height: 1.25,
                        ),
                      ),
                      if (result.exceededReasons.isNotEmpty && result.isOverCapacity) ...[
                        const SizedBox(height: 4),
                        ...result.exceededReasons.map(
                          (reason) => Padding(
                            padding: const EdgeInsets.only(bottom: 1),
                            child: Text(
                              '• $reason',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color: bannerTextColor,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Pilihan Kartu Motor & Mobil
          Row(
            children: [
              Expanded(
                child: _buildVehicleCard(
                  id: 'motor',
                  title: 'Motor',
                  subtitle: 'Maks. 20 kg (40×40×50 cm)',
                  icon: Icons.two_wheeler,
                  isSelected: selectedKendaraan == 'motor' && !result.isOverCapacity,
                  isDisabled: !canUseMotor,
                  disabledBadge: result.isOverCapacity
                      ? 'Tidak Tersedia'
                      : (canUseMotor ? null : 'Melebihi Batas Motor'),
                  isDarkMode: isDarkMode,
                  primaryColor: primaryColor,
                  onTap: () {
                    if (result.isOverCapacity) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(VehicleCapacityConfig.messageOverCapacity),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    if (!canUseMotor) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Barang melebihi batas Motor (maks. 20 kg & 40×40×50 cm). Silakan gunakan Mobil.',
                          ),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }
                    setState(() {
                      selectedKendaraan = 'motor';
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildVehicleCard(
                  id: 'mobil',
                  title: 'Mobil',
                  subtitle: 'Maks. 100 kg (100×100×80 cm)',
                  icon: Icons.directions_car,
                  isSelected: selectedKendaraan == 'mobil' && !result.isOverCapacity,
                  isDisabled: !canUseMobil,
                  disabledBadge: canUseMobil ? null : 'Melebihi Batas Mobil',
                  isDarkMode: isDarkMode,
                  primaryColor: primaryColor,
                  onTap: () {
                    if (result.isOverCapacity) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(VehicleCapacityConfig.messageOverCapacity),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    setState(() {
                      selectedKendaraan = 'mobil';
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleCard({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    bool isDisabled = false,
    String? disabledBadge,
    required bool isDarkMode,
    required Color primaryColor,
    required VoidCallback onTap,
  }) {
    final activeBg = isDarkMode
        ? primaryColor.withOpacity(0.18)
        : primaryColor.withOpacity(0.08);
    final inactiveBg = isDarkMode ? const Color(0xFF0F172A) : Colors.white;

    final activeBorder = primaryColor;
    final inactiveBorder =
        isDarkMode ? Colors.grey.shade700 : Colors.grey.shade200;

    return InkWell(
      key: Key('item_info_vehicle_$id'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isDisabled ? 0.6 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isSelected ? activeBg : inactiveBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? activeBorder : inactiveBorder,
              width: isSelected ? 1.8 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? primaryColor.withOpacity(0.1)
                    : Colors.black.withOpacity(0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? primaryColor
                          : (isDarkMode
                              ? Colors.grey.shade800
                              : Colors.grey.shade100),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon,
                      size: 16,
                      color: isSelected
                          ? Colors.white
                          : (isDarkMode
                              ? Colors.grey.shade300
                              : Colors.grey.shade600),
                    ),
                  ),
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? primaryColor : Colors.transparent,
                      border: Border.all(
                        color: isSelected ? primaryColor : Colors.grey.shade400,
                        width: isSelected ? 1.8 : 1.2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 11, color: Colors.white)
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? primaryColor
                      : (isDarkMode ? Colors.white : Colors.grey.shade800),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9.5,
                  color: isSelected
                      ? (isDarkMode
                          ? Colors.orange.shade200
                          : primaryColor.withOpacity(0.85))
                      : (isDarkMode
                          ? Colors.grey.shade400
                          : Colors.grey.shade500),
                ),
              ),
              if (disabledBadge != null) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.red.shade900.withOpacity(0.3)
                        : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isDarkMode ? Colors.red.shade800 : Colors.red.shade200,
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    disabledBadge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.red.shade300 : Colors.red.shade700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // --- KARTU 4: FOTO BARANG (FUNGSIONAL - KAMERA & GALERI, MAKS. 3 FOTO) ---
  Widget _buildCardFotoBarang(bool isDarkMode, Color primaryColor) {
    return _buildSectionCard(
      isDarkMode: isDarkMode,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(
            icon: Icons.camera_alt_outlined,
            title: 'FOTO BARANG',
            isDarkMode: isDarkMode,
            primaryColor: primaryColor,
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF0F172A) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                  width: 0.8,
                ),
              ),
              child: Text(
                '${_itemPhotos.length}/3 Foto',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: _itemPhotos.isNotEmpty ? primaryColor : Colors.grey.shade500,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Deretan Thumbnail Foto & Tombol Tambah
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Tombol Tambah Foto (Hanya jika belum 3 foto)
                if (_itemPhotos.length < 3)
                  GestureDetector(
                    onTap: () => _showImageSourcePicker(context, isDarkMode, primaryColor),
                    child: Container(
                      width: 80,
                      height: 80,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: primaryColor.withOpacity(0.4),
                          width: 1.2,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_a_photo,
                            color: primaryColor,
                            size: 24,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'TAMBAH',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Daftar Foto yang Dipilih
                ...List.generate(_itemPhotos.length, (index) {
                  final photoFile = _itemPhotos[index];
                  return Container(
                    width: 80,
                    height: 80,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                      ),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Gambar
                        GestureDetector(
                          onTap: () => _showPhotoPreview(photoFile),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: Image.file(
                              photoFile,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        // Tombol Hapus (Badge Merah di Sudut Kanan Atas)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _itemPhotos.removeAt(index);
                              });
                            },
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 4,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 8),
          Text(
            '* Maks. 3 foto barang, ukuran maks. 5MB per foto (Kamera atau Galeri)',
            style: TextStyle(
              fontSize: 9.5,
              fontStyle: FontStyle.italic,
              color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hintText,
    bool isDarkMode,
    Color primaryColor, {
    Key? key,
    String? suffixText,
    bool isNumber = false,
    bool isCenter = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
        ),
      ),
      child: TextField(
        key: key,
        controller: controller,
        keyboardType: isNumber
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        textAlign: isCenter ? TextAlign.center : TextAlign.start,
        style: TextStyle(
          color: isDarkMode ? Colors.white : Colors.black87,
          fontSize: 13,
          fontWeight: isCenter ? FontWeight.bold : FontWeight.normal,
        ),
        decoration: InputDecoration(
          isDense: true,
          hintText: hintText,
          hintStyle: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 13,
          ),
          suffixIcon: suffixText != null
              ? UnconstrainedBox(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Text(
                      suffixText,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  // --- BOTTOM BAR SIMPAN ---
  Widget _buildBottomBar(BuildContext context, Color primaryColor) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 14,
          bottom: MediaQuery.of(context).padding.bottom + 14,
        ),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF0F172A) : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Builder(
          builder: (context) {
            final isOverCapacity = detectionResult.isOverCapacity;

            return GestureDetector(
              onTap: () {
                if (isOverCapacity) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(VehicleCapacityConfig.messageOverCapacity),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                  return;
                }

                if (berat <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Berat barang harus lebih besar dari 0 kg'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                String finalDeskripsi = deskripsiController.text;
                if (kategoriBarang != 'lainnya') {
                  switch (kategoriBarang) {
                    case 'pakaian':
                      finalDeskripsi = 'Pakaian & Fashion';
                      break;
                    case 'elektronik':
                      finalDeskripsi = 'Elektronik';
                      break;
                    case 'makanan':
                      finalDeskripsi = 'Makanan & Minuman';
                      break;
                    case 'kosmetik':
                      finalDeskripsi = 'Kosmetik / Farmasi';
                      break;
                    default:
                      finalDeskripsi = 'Peralatan Rumah Tangga';
                  }
                }
                Navigator.pop(context, {
                  'status': 'tersimpan',
                  'deskripsi': finalDeskripsi,
                  'kategori': kategoriBarang,
                  'berat': beratAktual,
                  'beratAktual': beratAktual,
                  'panjang': panjang,
                  'lebar': lebar,
                  'tinggi': tinggi,
                  'volumeCm3': volumeCm3,
                  'volumeLiter': volumeLiter,
                  'beratVolume': beratVolumetrik,
                  'beratVolumetrik': beratVolumetrik,
                  'beratPengiriman': beratPengiriman,
                  'shippingWeight': beratPengiriman,
                  'jumlahBarang': jumlahBarang,
                  'vehicleType': selectedKendaraan,
                  'photoPaths': _itemPhotos.map((f) => f.path).toList(),
                  'detectionStatus': detectionResult.status.name,
                  'detectionMessage': detectionResult.message,
                });
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: isOverCapacity ? Colors.grey.shade400 : primaryColor,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: isOverCapacity
                      ? null
                      : [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.28),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                        ],
                ),
                alignment: Alignment.center,
                child: Text(
                  isOverCapacity ? 'Kapasitas Melebihi Batas' : 'Simpan Detail Barang',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

extension ColorsExtension on Colors {
  static MaterialColor get slate =>
      const MaterialColor(0xFF0F172A, <int, Color>{
        50: Color(0xFFF8FAFC),
        100: Color(0xFFF1F5F9),
        200: Color(0xFFE2E8F0),
        300: Color(0xFFCBD5E1),
        400: Color(0xFF94A3B8),
        500: Color(0xFF64748B),
        600: Color(0xFF475569),
        700: Color(0xFF334155),
        800: Color(0xFF1E293B),
        900: Color(0xFF0F172A),
      });
}
