import 'package:flutter/material.dart';

class PickupTimeBottomSheet extends StatefulWidget {
  final Color primaryColor;

  const PickupTimeBottomSheet({
    Key? key,
    required this.primaryColor,
  }) : super(key: key);

  @override
  State<PickupTimeBottomSheet> createState() => _PickupTimeBottomSheetState();
}

class _PickupTimeBottomSheetState extends State<PickupTimeBottomSheet> {
  int selectedDayIndex = 0;
  int selectedTimeIndex = 0;

  final List<Map<String, String>> days = [
    {'title': 'HARI INI', 'date': '23', 'month': 'OKT'},
    {'title': 'BESOK', 'date': '24', 'month': 'OKT'},
    {'title': 'RAB', 'date': '25', 'month': 'OKT'},
    {'title': 'KAM', 'date': '26', 'month': 'OKT'},
    {'title': 'JUM', 'date': '27', 'month': 'OKT'},
  ];

  final List<String> times = [
    '09:00 - 10:00',
    '10:00 - 11:00',
    '11:00 - 12:00',
    '13:00 - 14:00',
    '14:00 - 15:00',
    '15:00 - 16:00',
  ];

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.grey.shade700
                  : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pilih Waktu Pickup',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode
                        ? Colors.white
                        : const Color(0xFF0F172A), // Slate 900
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Icon(
                      Icons.close,
                      color: Colors.grey.shade400,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(
            color: isDarkMode
                ? Colors.grey.shade800
                : Colors.grey.shade50,
            height: 1,
            thickness: 1,
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PILIH HARI',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade400,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(days.length, (index) {
                        final isSelected = selectedDayIndex == index;
                        final day = days[index];
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedDayIndex = index;
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 8, bottom: 4),
                            width: 64,
                            height: 80,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? widget.primaryColor
                                  : (isDarkMode
                                        ? const Color(0xFF1E293B)
                                        : Colors.white),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.transparent
                                    : (isDarkMode
                                          ? Colors.grey.shade700
                                          : Colors.grey.shade100),
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: widget.primaryColor.withOpacity(
                                          0.2,
                                        ),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  day['title']!,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? Colors.white.withOpacity(0.8)
                                        : (isDarkMode
                                              ? Colors.grey.shade500
                                              : Colors.grey.shade400),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  day['date']!,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    height: 1,
                                    color: isSelected
                                        ? Colors.white
                                        : (isDarkMode
                                              ? Colors.white
                                              : Colors.grey.shade800),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  day['month']!,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.grey.shade400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'WAKTU TERSEDIA',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade400,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 3.5, // roughly 160 / 40
                        ),
                    itemCount: times.length,
                    itemBuilder: (context, index) {
                      final isSelected = selectedTimeIndex == index;
                      final time = times[index];
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedTimeIndex = index;
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? widget.primaryColor
                                : (isDarkMode
                                      ? const Color(0xFF1E293B)
                                      : Colors.white),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.transparent
                                  : (isDarkMode
                                        ? Colors.grey.shade700
                                        : Colors.grey.shade100),
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: widget.primaryColor.withOpacity(
                                        0.1,
                                      ),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (isSelected) ...[
                                const Icon(
                                  Icons.schedule,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                time,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w600,
                                  color: isSelected
                                      ? Colors.white
                                      : (isDarkMode
                                            ? Colors.grey.shade200
                                            : Colors.grey.shade700),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          Divider(
            color: isDarkMode
                ? Colors.grey.shade800
                : Colors.grey.shade50,
            height: 1,
            thickness: 1,
          ),
          Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 12,
              bottom: MediaQuery.of(context).padding.bottom + 16,
            ),
            child: GestureDetector(
              onTap: () {
                final pickupTimeData =
                    '${days[selectedDayIndex]['date']} ${days[selectedDayIndex]['month']} - ${times[selectedTimeIndex]}';
                Navigator.pop(context, pickupTimeData);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: widget.primaryColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: widget.primaryColor.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Konfirmasi Waktu',
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
