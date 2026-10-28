import 'package:flutter/material.dart';
import 'package:city_courierapp/models/shipping/schedule_time_config.dart';

class PickupTimeBottomSheet extends StatefulWidget {
  final Color primaryColor;
  final DateTime? initialDateTime;
  final String? title;
  final DateTime? referenceNow; // Untuk kemudahan testing & sinkronisasi waktu lokal

  const PickupTimeBottomSheet({
    super.key,
    required this.primaryColor,
    this.initialDateTime,
    this.title,
    this.referenceNow,
  });

  @override
  State<PickupTimeBottomSheet> createState() => _PickupTimeBottomSheetState();
}

class _PickupTimeBottomSheetState extends State<PickupTimeBottomSheet> {
  late List<Map<String, dynamic>> days;
  int selectedDayIndex = 0;

  // Wheel Items
  final List<String> hours = List.generate(12, (i) => (i + 1).toString().padLeft(2, '0'));
  // Interval menit 00, 05, 10, ... 55 atau 00-59
  final List<String> minutes = List.generate(60, (i) => i.toString().padLeft(2, '0'));
  final List<String> periods = ['AM', 'PM'];

  late int selectedHourIndex;
  late int selectedMinuteIndex;
  late int selectedPeriodIndex;

  String? selectedSlotId;

  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;
  late FixedExtentScrollController _periodController;

  DateTime get _effectiveNow => widget.referenceNow ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    final now = _effectiveNow;
    days = ScheduleTimeConfig.generateAvailableDays(referenceNow: now);

    // Tentukan waktu awal (initialDateTime)
    DateTime initDt;
    if (widget.initialDateTime != null) {
      initDt = widget.initialDateTime!;
    } else {
      initDt = ScheduleTimeConfig.getInitialPickupDateTime(referenceNow: now);
    }

    // Temukan index hari yang cocok
    for (int i = 0; i < days.length; i++) {
      final d = days[i]['fullDate'] as DateTime;
      if (d.year == initDt.year && d.month == initDt.month && d.day == initDt.day) {
        selectedDayIndex = i;
        break;
      }
    }

    final (h12, m, p) = ScheduleTimeConfig.fromDateTime(initDt);
    selectedHourIndex = (h12 - 1).clamp(0, 11);
    selectedMinuteIndex = m.clamp(0, 59);
    selectedPeriodIndex = p == 'PM' ? 1 : 0;

    _hourController = FixedExtentScrollController(initialItem: selectedHourIndex);
    _minuteController = FixedExtentScrollController(initialItem: selectedMinuteIndex);
    _periodController = FixedExtentScrollController(initialItem: selectedPeriodIndex);

    // Cek apakah waktu awal cocok dengan salah satu slot
    _detectMatchingSlot(initDt.hour, initDt.minute);
  }

  void _detectMatchingSlot(int h24, int minute) {
    selectedSlotId = null;
    for (final slot in ScheduleTimeConfig.defaultSlots) {
      if (slot.startHour24 == h24 && slot.startMinute == minute) {
        selectedSlotId = slot.id;
        break;
      }
    }
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    _periodController.dispose();
    super.dispose();
  }

  int get currentHour12 => selectedHourIndex + 1;
  int get currentMinute => selectedMinuteIndex;
  String get currentPeriod => periods[selectedPeriodIndex];

  DateTime get currentTargetDate => days[selectedDayIndex]['fullDate'] as DateTime;

  /// Evaluasi validasi waktu pickup yang sedang dipilih
  ({
    DateTime dateTime,
    bool isValid,
    String? message,
  }) _evaluateSelection() {
    final now = _effectiveNow;
    final h24 = ScheduleTimeConfig.to24Hour(currentHour12, currentPeriod);
    final dt = DateTime(
      currentTargetDate.year,
      currentTargetDate.month,
      currentTargetDate.day,
      h24,
      currentMinute,
    );

    // 0. Validasi batas tanggal (hanya Hari Ini dan Besok yang diperbolehkan)
    if (!ScheduleTimeConfig.isDateAllowed(currentTargetDate, referenceNow: now)) {
      return (
        dateTime: dt,
        isValid: false,
        message: 'Hanya dapat memilih jadwal pickup untuk Hari Ini atau Besok',
      );
    }

    // 1. Validasi masa lalu jika hari ini
    final isPast = ScheduleTimeConfig.isPickupInPast(
      currentTargetDate,
      currentHour12,
      currentMinute,
      currentPeriod,
      referenceNow: now,
    );

    if (isPast) {
      return (
        dateTime: dt,
        isValid: false,
        message: 'Waktu pickup tidak boleh sebelum waktu saat ini',
      );
    }

    // 2. Validasi jam operasional (08:00 AM – 07:00 PM)
    final withinHours = ScheduleTimeConfig.isWithinOperatingHours(currentHour12, currentPeriod);
    if (!withinHours) {
      return (
        dateTime: dt,
        isValid: false,
        message: 'Layanan pickup beroperasi antara 08:00 AM – 07:00 PM',
      );
    }

    return (
      dateTime: dt,
      isValid: true,
      message: null,
    );
  }

  void _applySlot(PickupSlot slot) {
    setState(() {
      selectedSlotId = slot.id;
      final (h12, m, p) = ScheduleTimeConfig.fromDateTime(
        DateTime(2026, 1, 1, slot.startHour24, slot.startMinute),
      );
      selectedHourIndex = (h12 - 1).clamp(0, 11);
      selectedMinuteIndex = m.clamp(0, 59);
      selectedPeriodIndex = p == 'PM' ? 1 : 0;
    });

    if (_hourController.hasClients) {
      _hourController.jumpToItem(selectedHourIndex);
    }
    if (_minuteController.hasClients) {
      _minuteController.jumpToItem(selectedMinuteIndex);
    }
    if (_periodController.hasClients) {
      _periodController.jumpToItem(selectedPeriodIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final eval = _evaluateSelection();
    final headerTitle = widget.title ?? 'Pilih Jadwal Pickup';
    final availableSlots = ScheduleTimeConfig.getAvailableSlotsForDate(
      currentTargetDate,
      referenceNow: _effectiveNow,
    );

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          // Handle bar
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          // Header Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: widget.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.access_time_rounded,
                        size: 20,
                        color: widget.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      headerTitle,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  key: const Key('button_close_time_sheet'),
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close,
                      color: Colors.grey.shade500,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(
            color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
            height: 1,
            thickness: 1,
          ),
          // Scrollable Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // BAGIAN 1: PILIH TANGGAL PICKUP
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'TANGGAL PICKUP',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade500,
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        ScheduleTimeConfig.formatDisplayDay(currentTargetDate, referenceNow: _effectiveNow),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: widget.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: days.asMap().entries.map((entry) {
                      final index = entry.key;
                      final day = entry.value;
                      final isSelected = selectedDayIndex == index;
                      final title = day['displayTitle'] ?? day['title'];
                      final dateFormatted = day['dateFormatted'] ?? '${day['date']} ${day['month']}';

                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: index < days.length - 1 ? 8 : 0,
                          ),
                          child: GestureDetector(
                            key: Key('day_item_$index'),
                            onTap: () {
                              setState(() {
                                selectedDayIndex = index;
                                // Auto-sesuaikan slot yang cocok pada tanggal baru
                                final slots = ScheduleTimeConfig.getAvailableSlotsForDate(
                                  day['fullDate'] as DateTime,
                                  referenceNow: _effectiveNow,
                                );
                                if (slots.isNotEmpty) {
                                  final stillAvailable = slots.any((s) => s.id == selectedSlotId);
                                  if (!stillAvailable) {
                                    _applySlot(slots.first);
                                  }
                                }
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? widget.primaryColor.withOpacity(0.12)
                                    : (isDarkMode ? const Color(0xFF1E293B) : Colors.grey.shade50),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? widget.primaryColor
                                      : (isDarkMode ? Colors.grey.shade700 : Colors.grey.shade200),
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                                    size: 18,
                                    color: isSelected ? widget.primaryColor : Colors.grey.shade400,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          title,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: isSelected
                                                ? widget.primaryColor
                                                : (isDarkMode ? Colors.white : Colors.grey.shade800),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          dateFormatted,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                            color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // BAGIAN 2: SLOT WAKTU PICKUP OPERASIONAL
                  Text(
                    'PILIH SLOT WAKTU PICKUP',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade500,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (availableSlots.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.orange, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Layanan pickup untuk hari ini sudah berakhir. Silakan pilih tanggal berikutnya.',
                              style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: availableSlots.map((slot) {
                        final isSlotSelected = selectedSlotId == slot.id;
                        return GestureDetector(
                          key: Key('slot_chip_${slot.id}'),
                          onTap: () => _applySlot(slot),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSlotSelected
                                  ? widget.primaryColor.withOpacity(0.12)
                                  : (isDarkMode ? const Color(0xFF1E293B) : Colors.grey.shade50),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSlotSelected
                                    ? widget.primaryColor
                                    : (isDarkMode ? Colors.grey.shade700 : Colors.grey.shade200),
                                width: isSlotSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isSlotSelected ? Icons.check_circle : Icons.schedule,
                                  size: 14,
                                  color: isSlotSelected ? widget.primaryColor : Colors.grey.shade400,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  slot.title,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSlotSelected ? FontWeight.bold : FontWeight.w600,
                                    color: isSlotSelected
                                        ? widget.primaryColor
                                        : (isDarkMode ? Colors.white : Colors.grey.shade700),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 20),

                  // BAGIAN 3: ROLLING TIME PICKER (WAKTU SPESIFIK 12 JAM)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'WAKTU SPESIFIK (FORMAT 12 JAM)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade500,
                          letterSpacing: 1,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: widget.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '08:00 AM – 07:00 PM',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: widget.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Container Rolling Wheel
                  Container(
                    height: 150,
                    decoration: BoxDecoration(
                      color: isDarkMode ? const Color(0xFF1E293B) : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade200,
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Center Highlight Selection Bar
                        Container(
                          height: 40,
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: widget.primaryColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: widget.primaryColor.withOpacity(0.35),
                              width: 1.5,
                            ),
                          ),
                        ),
                        // Wheels Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // 1. Wheel Jam (01 - 12)
                            _buildWheelColumn(
                              keyName: 'wheel_hour',
                              title: 'JAM',
                              controller: _hourController,
                              items: hours,
                              selectedIndex: selectedHourIndex,
                              onSelectedItemChanged: (index) {
                                setState(() {
                                  selectedHourIndex = index;
                                  final h24 = ScheduleTimeConfig.to24Hour(currentHour12, currentPeriod);
                                  _detectMatchingSlot(h24, currentMinute);
                                });
                              },
                              isDarkMode: isDarkMode,
                              width: 65,
                            ),
                            // Separator ":"
                            Text(
                              ':',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: widget.primaryColor,
                              ),
                            ),
                            // 2. Wheel Menit (00 - 59)
                            _buildWheelColumn(
                              keyName: 'wheel_minute',
                              title: 'MENIT',
                              controller: _minuteController,
                              items: minutes,
                              selectedIndex: selectedMinuteIndex,
                              onSelectedItemChanged: (index) {
                                setState(() {
                                  selectedMinuteIndex = index;
                                  final h24 = ScheduleTimeConfig.to24Hour(currentHour12, currentPeriod);
                                  _detectMatchingSlot(h24, currentMinute);
                                });
                              },
                              isDarkMode: isDarkMode,
                              width: 65,
                            ),
                            // Separator vertical line
                            Container(
                              height: 32,
                              width: 1,
                              color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                            ),
                            // 3. Wheel AM / PM
                            _buildWheelColumn(
                              keyName: 'wheel_period',
                              title: 'PERIODE',
                              controller: _periodController,
                              items: periods,
                              selectedIndex: selectedPeriodIndex,
                              onSelectedItemChanged: (index) {
                                setState(() {
                                  selectedPeriodIndex = index;
                                  final h24 = ScheduleTimeConfig.to24Hour(currentHour12, currentPeriod);
                                  _detectMatchingSlot(h24, currentMinute);
                                });
                              },
                              isDarkMode: isDarkMode,
                              width: 65,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // LIVE TIME PREVIEW & FEEDBACK
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: eval.isValid
                          ? widget.primaryColor.withOpacity(0.06)
                          : Colors.red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: eval.isValid
                            ? widget.primaryColor.withOpacity(0.2)
                            : Colors.red.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              eval.isValid ? Icons.check_circle_outline : Icons.error_outline,
                              color: eval.isValid ? widget.primaryColor : Colors.red,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              eval.isValid ? 'Pickup Dijadwalkan' : 'Waktu Tidak Valid',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: eval.isValid ? widget.primaryColor : Colors.red,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ScheduleTimeConfig.formatFull(eval.dateTime),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.grey.shade800,
                          ),
                        ),
                        if (eval.message != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            eval.message!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Divider(
            color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
            height: 1,
            thickness: 1,
          ),
          // Action Buttons
          Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 12,
              bottom: MediaQuery.of(context).padding.bottom + 16,
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                key: const Key('button_confirm_time'),
                onPressed: eval.isValid
                    ? () {
                        final timeStr = ScheduleTimeConfig.format12Hour(
                          eval.dateTime.hour,
                          eval.dateTime.minute,
                        );
                        final displayDate = ScheduleTimeConfig.formatDisplayDay(
                          eval.dateTime,
                          referenceNow: _effectiveNow,
                        );
                        final result = ScheduleTimeResult(
                          dateTime: eval.dateTime,
                          hour12: currentHour12,
                          minute: currentMinute,
                          period: currentPeriod,
                          time12Hour: timeStr,
                          displayDate: displayDate,
                          displayFull: ScheduleTimeConfig.formatFull(eval.dateTime),
                          slotTitle: selectedSlotId != null
                              ? ScheduleTimeConfig.defaultSlots
                                  .firstWhere((s) => s.id == selectedSlotId)
                                  .title
                              : null,
                        );
                        Navigator.pop(context, result);
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.primaryColor,
                  disabledBackgroundColor: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: eval.isValid ? 2 : 0,
                ),
                child: const Text(
                  'Konfirmasi Jadwal Pickup',
                  style: TextStyle(
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

  Widget _buildWheelColumn({
    required String keyName,
    required String title,
    required FixedExtentScrollController controller,
    required List<String> items,
    required int selectedIndex,
    required ValueChanged<int> onSelectedItemChanged,
    required bool isDarkMode,
    required double width,
  }) {
    return SizedBox(
      key: Key(keyName),
      width: width,
      height: 140,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 2),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade400,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Expanded(
            child: ListWheelScrollView.useDelegate(
              controller: controller,
              itemExtent: 36,
              perspective: 0.005,
              diameterRatio: 1.2,
              physics: const FixedExtentScrollPhysics(),
              onSelectedItemChanged: onSelectedItemChanged,
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: items.length,
                builder: (context, index) {
                  final isSelected = index == selectedIndex;
                  return Center(
                    child: Text(
                      items[index],
                      style: TextStyle(
                        fontSize: isSelected ? 18 : 14,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected
                            ? widget.primaryColor
                            : (isDarkMode ? Colors.grey.shade400 : Colors.grey.shade500),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
