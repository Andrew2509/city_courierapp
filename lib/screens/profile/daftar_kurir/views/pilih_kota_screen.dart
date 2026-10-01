import 'package:flutter/material.dart';
import '../widgets/daftar_kurir_components.dart';
import '../widgets/daftar_kurir_constants.dart';
import 'pilih_kendaraan_screen.dart';

class PilihKotaScreen extends StatefulWidget {
  const PilihKotaScreen({super.key});

  @override
  State<PilihKotaScreen> createState() => _PilihKotaScreenState();
}

class _PilihKotaScreenState extends State<PilihKotaScreen> {
  final List<String> _kotaList = [
    'Surabaya',
    'Sidoarjo',
    'Gresik',
    'Malang',
    'Jakarta',
    'Bandung',
    'Semarang',
    'Yogyakarta',
  ];
  
  String _searchQuery = '';
  String? _selectedKota;

  @override
  Widget build(BuildContext context) {
    final filteredKota = _kotaList
        .where((kota) => kota.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return ScreenLayout(
      title: 'Pilih Kota',
      currentStep: 2, // Step 2 of 4 (Data Diri)
      totalSteps: 4,
      bottomAction: PrimaryButton(
        text: 'Lanjutkan',
        onPressed: _selectedKota != null
            ? () {
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
          // Search Field
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
          
          // City List
          if (filteredKota.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'Kota tidak ditemukan',
                  style: TextStyle(color: DaftarKurirColors.textSub),
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
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredKota.length,
                separatorBuilder: (context, index) => const Divider(height: 1, color: DaftarKurirColors.border),
                itemBuilder: (context, index) {
                  final kota = filteredKota[index];
                  final isSelected = _selectedKota == kota;
                  
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedKota = kota;
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
                          Text(
                            kota,
                            style: const TextStyle(
                              fontSize: 16,
                              color: DaftarKurirColors.textDark,
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
      ),
    );
  }
}
