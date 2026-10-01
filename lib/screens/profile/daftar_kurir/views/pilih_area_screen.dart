import 'package:flutter/material.dart';
import '../widgets/daftar_kurir_components.dart';
import '../widgets/daftar_kurir_constants.dart';
import 'data_diri_screen.dart';

class PilihAreaScreen extends StatefulWidget {
  const PilihAreaScreen({super.key});

  @override
  State<PilihAreaScreen> createState() => _PilihAreaScreenState();
}

class _PilihAreaScreenState extends State<PilihAreaScreen> {
  final List<String> _areaList = [
    'Kecamatan Tegalsari',
    'Kecamatan Genteng',
    'Kecamatan Wonokromo',
    'Kecamatan Sukolilo',
    'Kecamatan Gubeng',
    'Kecamatan Rungkut',
    'Kecamatan Mulyorejo',
    'Kecamatan Wiyung',
  ];
  
  String _searchQuery = '';
  String? _selectedArea;

  @override
  Widget build(BuildContext context) {
    final filteredArea = _areaList
        .where((area) => area.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return ScreenLayout(
      title: 'Pilih Area Operasional',
      currentStep: 2, // Step 2 of 4 (Data Diri)
      totalSteps: 4,
      bottomAction: PrimaryButton(
        text: 'Lanjutkan',
        onPressed: _selectedArea != null
            ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DataDiriScreen(),
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
                hintText: 'Cari Area/Kecamatan',
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
          
          // Area List
          if (filteredArea.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'Area tidak ditemukan',
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
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredArea.length,
                itemBuilder: (context, index) {
                  final area = filteredArea[index];
                  final isSelected = _selectedArea == area;
                  
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedArea = area;
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
                            area,
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
