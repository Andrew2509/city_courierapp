import 'package:flutter/material.dart';

class ItemInfoScreen extends StatefulWidget {
  const ItemInfoScreen({Key? key}) : super(key: key);

  @override
  State<ItemInfoScreen> createState() => _ItemInfoScreenState();
}

class _ItemInfoScreenState extends State<ItemInfoScreen> {
  bool get isDarkMode => Theme.of(context).brightness == Brightness.dark;
  String jenisKiriman = 'Barang'; // 'Dokumen' or 'Barang'
  String? kategoriBarang = 'lainnya';

  final TextEditingController deskripsiController = TextEditingController(
    text: 'Peralatan Rumah Tangga',
  );
  final TextEditingController panjangController = TextEditingController(
    text: '30',
  );
  final TextEditingController lebarController = TextEditingController(
    text: '20',
  );
  final TextEditingController tinggiController = TextEditingController(
    text: '15',
  );
  final TextEditingController beratController = TextEditingController(
    text: '1.5',
  );

  int jumlahBarang = 1;
  bool gunakanAsuransi = true;

  @override
  void initState() {
    super.initState();
    panjangController.addListener(() => setState(() {}));
    lebarController.addListener(() => setState(() {}));
    tinggiController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    deskripsiController.dispose();
    panjangController.dispose();
    lebarController.dispose();
    tinggiController.dispose();
    beratController.dispose();
    super.dispose();
  }

  double get beratVolume {
    double p = double.tryParse(panjangController.text) ?? 0;
    double l = double.tryParse(lebarController.text) ?? 0;
    double t = double.tryParse(tinggiController.text) ?? 0;
    return (p * l * t) / 5000;
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFEC5B13);
    final bgLight = const Color(0xFFF9FAFB);
    final bgDark = const Color(0xFF0F172A);

    return Scaffold(
        backgroundColor: isDarkMode ? bgDark : bgLight,
        body: Stack(
          children: [
            Column(
              children: [
                _buildHeader(context, primaryColor),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(
                      left: 20,
                      right: 20,
                      top: 24,
                      bottom: 40,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildJenisKiriman(isDarkMode, primaryColor),
                        if (jenisKiriman == 'Barang') ...[
                          const SizedBox(height: 24),
                          _buildKategoriBarang(isDarkMode, primaryColor),
                          if (kategoriBarang == 'lainnya') ...[
                            const SizedBox(height: 24),
                            _buildDeskripsiBarang(isDarkMode, primaryColor),
                          ],
                          const SizedBox(height: 24),
                          _buildDimensiPaket(isDarkMode, primaryColor),
                        ],
                        const SizedBox(height: 24),
                        _buildBeratDanJumlah(isDarkMode, primaryColor),
                        const SizedBox(height: 16),
                        _buildBeratVolume(isDarkMode, primaryColor),
                        const SizedBox(height: 16),
                        _buildAsuransi(isDarkMode, primaryColor),
                        const SizedBox(height: 24),
                        _buildFotoBarang(isDarkMode, primaryColor),
                        const SizedBox(height: 80),
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

  Widget _buildHeader(BuildContext context, Color primaryColor) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        bottom: 24,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        color: primaryColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Text(
            'Informasi Barang',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJenisKiriman(bool isDarkMode, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'JENIS KIRIMAN',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade500,
              letterSpacing: 1,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E293B) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
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
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: jenisKiriman == 'Dokumen'
                          ? primaryColor
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: jenisKiriman == 'Dokumen'
                          ? [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
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
                        fontSize: 14,
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
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: jenisKiriman == 'Barang'
                          ? primaryColor
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: jenisKiriman == 'Barang'
                          ? [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
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
                        fontSize: 14,
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
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'KATEGORI BARANG',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade500,
              letterSpacing: 1,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade200,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: kategoriBarang,
              isExpanded: true,
              dropdownColor: isDarkMode
                  ? const Color(0xFF1E293B)
                  : Colors.white,
              icon: Icon(Icons.expand_more, color: Colors.grey.shade400),
              style: TextStyle(
                color: isDarkMode
                    ? Colors.grey.shade200
                    : const Color(0xFF334155),
                fontSize: 14,
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
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'DESKRIPSI BARANG',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade500,
              letterSpacing: 1,
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

  Widget _buildDimensiPaket(bool isDarkMode, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'DIMENSI PAKET (CM)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade500,
              letterSpacing: 1,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: Text(
                      'Panjang',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ),
                  _buildTextField(
                    panjangController,
                    'P',
                    isDarkMode,
                    primaryColor,
                    isNumber: true,
                    isCenter: true,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: Text(
                      'Lebar',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ),
                  _buildTextField(
                    lebarController,
                    'L',
                    isDarkMode,
                    primaryColor,
                    isNumber: true,
                    isCenter: true,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: Text(
                      'Tinggi',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ),
                  _buildTextField(
                    tinggiController,
                    'T',
                    isDarkMode,
                    primaryColor,
                    isNumber: true,
                    isCenter: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBeratDanJumlah(bool isDarkMode, Color primaryColor) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  'BERAT (KG)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode
                        ? Colors.grey.shade400
                        : Colors.grey.shade500,
                    letterSpacing: 1,
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDarkMode
                        ? Colors.grey.shade700
                        : Colors.grey.shade200,
                  ),
                ),
                child: TextField(
                  controller: beratController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black87,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: '0',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 14,
                    ),
                    suffixIcon: UnconstrainedBox(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Text(
                          'KG',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  'JUMLAH BARANG',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode
                        ? Colors.grey.shade400
                        : Colors.grey.shade500,
                    letterSpacing: 1,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDarkMode
                        ? Colors.grey.shade700
                        : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
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
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    IconButton(
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

  Widget _buildBeratVolume(bool isDarkMode, Color primaryColor) {
    if (jenisKiriman != 'Barang') return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.orange.shade900.withOpacity(0.1)
            : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode
              ? Colors.orange.shade900.withOpacity(0.3)
              : Colors.orange.shade100,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.straighten, color: primaryColor, size: 24),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TOTAL BERAT VOLUME',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode
                          ? Colors.orange.shade400
                          : Colors.orange.shade600,
                    ),
                  ),
                  Text(
                    'Dihitung: (P×L×T) / 5000',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                beratVolume.toStringAsFixed(2),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: primaryColor,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'KGv',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAsuransi(bool isDarkMode, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode
              ? Colors.grey.shade700.withOpacity(0.5)
              : Colors.grey.shade100,
        ),
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
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.shield_outlined,
                  color: primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gunakan Asuransi',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.grey.shade800,
                    ),
                  ),
                  Text(
                    'Proteksi ekstra untuk kiriman Anda',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDarkMode
                          ? Colors.grey.shade400
                          : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Switch(
            value: gunakanAsuransi,
            activeColor: Colors.white,
            activeTrackColor: primaryColor,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.grey.shade300,
            onChanged: (value) {
              setState(() {
                gunakanAsuransi = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFotoBarang(bool isDarkMode, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'FOTO BARANG',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade500,
              letterSpacing: 1,
            ),
          ),
        ),
        Row(
          children: [
            Container(
              width: 100,
              height: 100,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDarkMode
                      ? Colors.grey.shade700
                      : Colors.grey.shade200,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_a_photo,
                    color: Colors.grey.shade400,
                    size: 32,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'TAMBAH',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                image: const DecorationImage(
                  image: NetworkImage(
                    'https://lh3.googleusercontent.com/aida-public/AB6AXuCQbeyckEpnv-pkGBnoQgWSlg3lpA0SDBaifttTx_waEa7I7u0Ys985xB2XF-wRh3FDhKWjitYdREQnbTEAt20tpjFZxPppk9tCiagEpaKS-qp5Lqxt_eYhn3PLR0IE2qfl6AJZy0mLx7N7TivM4AwdW9Doz6uVdceIDp6h97E8iFcoWcs0JMGFe_NYQJx06KyPVHqsETJml0uCJ8cE8I5YqFdRqm7yul2gTQEeYKzPQ5TEGNb0BL9-oQBO0_H9QIWL8G4iIpaLR_s5',
                  ),
                  fit: BoxFit.cover,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            '* Max. 3 foto, ukuran max 5MB/foto',
            style: TextStyle(
              fontSize: 10,
              fontStyle: FontStyle.italic,
              color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade400,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hintText,
    bool isDarkMode,
    Color primaryColor, {
    bool isNumber = false,
    bool isCenter = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade200,
        ),
      ),
      child: TextField(
        controller: controller,
        keyboardType: isNumber
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        textAlign: isCenter ? TextAlign.center : TextAlign.start,
        style: TextStyle(
          color: isDarkMode ? Colors.white : Colors.black87,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 14,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, Color primaryColor) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).padding.bottom + 20,
        ),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF0F172A) : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
            ),
          ),
        ),
        child: GestureDetector(
          onTap: () {
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
              'berat': double.tryParse(beratController.text) ?? 1.5,
              'beratVolume': beratVolume,
              'jumlahBarang': jumlahBarang,
            });
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Text(
              'Simpan Detail Barang',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
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
