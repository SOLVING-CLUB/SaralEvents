import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../features/services/availability_service.dart';

enum DaySlot { morning, afternoon, evening, night }
enum DayStatus { booked, available, partial }

class AvailabilityCalendarController {
  final Map<DateTime, ServiceAvailabilityOverride> _overrides = <DateTime, ServiceAvailabilityOverride>{};

  List<ServiceAvailabilityOverride> getOverrides() => _overrides.values.toList();

  void setOverride(ServiceAvailabilityOverride override) {
    final key = DateTime(override.date.year, override.date.month, override.date.day);
    _overrides[key] = override;
  }

  ServiceAvailabilityOverride? getFor(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return _overrides[key];
  }
}

class AvailabilityCalendar extends StatefulWidget {
  final String? serviceId; // optional during create flow
  final AvailabilityService availabilityService;
  final AvailabilityCalendarController? controller; // captures in-memory overrides
  final bool persistImmediately; // if true, upserts on each change when serviceId != null
  final bool isViewMode; // disables editing; shows selection details on tap

  const AvailabilityCalendar({
    super.key,
    required this.availabilityService,
    this.serviceId,
    this.controller,
    this.persistImmediately = true,
    this.isViewMode = false,
  });

  @override
  State<AvailabilityCalendar> createState() => _AvailabilityCalendarState();
}

class _AvailabilityCalendarState extends State<AvailabilityCalendar> {
  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  bool _loading = false;
  final Map<DateTime, ServiceAvailabilityOverride> _overrides = <DateTime, ServiceAvailabilityOverride>{};
  DayStatus? _activePaintStatus; // When selected, tapping days applies this status directly
  DateTime? _selectedForDetails; // for view mode details

  @override
  void initState() {
    super.initState();
    _loadMonth();
  }

  Future<void> _loadMonth() async {
    if (widget.serviceId == null) {
      // Create flow: use controller state only
      setState(() {
        _loading = false;
        _overrides
          ..clear()
          ..addEntries(widget.controller?._overrides.entries ?? const <MapEntry<DateTime, ServiceAvailabilityOverride>>[]);
      });
      return;
    }

    setState(() => _loading = true);
    try {
      final rows = await widget.availabilityService.getOverrides(
        serviceId: widget.serviceId!,
        month: _visibleMonth,
      );
      _overrides
        ..clear()
        ..addEntries(rows.map((o) => MapEntry(DateTime(o.date.year, o.date.month, o.date.day), o)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changeMonth(int delta) {
    final now = DateTime.now();
    final minMonth = DateTime(now.year, now.month, 1);
    final next = DateTime(_visibleMonth.year, _visibleMonth.month + delta, 1);

    // Do not allow navigating to months before the current month
    if (next.isBefore(minMonth)) {
      return;
    }

    setState(() {
      _visibleMonth = next;
    });
    _loadMonth();
  }

  ServiceAvailabilityOverride _currentFor(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return _overrides[key] ?? ServiceAvailabilityOverride(
      date: key,
      morningAvailable: true,
      afternoonAvailable: true,
      eveningAvailable: true,
      nightAvailable: true,
    );
  }

  bool _hasOverride(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return _overrides.containsKey(key);
  }

  DayStatus? _statusFor(DateTime day) {
    if (!_hasOverride(day)) return null; // no status shown by default
    final o = _currentFor(day);
    if (!o.morningAvailable && !o.afternoonAvailable && !o.eveningAvailable && !o.nightAvailable) return DayStatus.booked;
    if (o.morningAvailable && o.afternoonAvailable && o.eveningAvailable && o.nightAvailable) return DayStatus.available;
    return DayStatus.partial;
  }

  Future<void> _toggle(DateTime day, DaySlot slot, bool value) async {
    final cur = _currentFor(day);
    final updated = ServiceAvailabilityOverride(
      date: cur.date,
      morningAvailable: slot == DaySlot.morning ? value : cur.morningAvailable,
      afternoonAvailable: slot == DaySlot.afternoon ? value : cur.afternoonAvailable,
      eveningAvailable: slot == DaySlot.evening ? value : cur.eveningAvailable,
      nightAvailable: slot == DaySlot.night ? value : cur.nightAvailable,
      customStart: cur.customStart,
      customEnd: cur.customEnd,
    );
    setState(() {
      _overrides[DateTime(day.year, day.month, day.day)] = updated;
    });
    // Capture in controller for create flow
    widget.controller?.setOverride(updated);
    // Persist immediately if editing an existing service
    if (widget.serviceId != null && widget.persistImmediately) {
      await widget.availabilityService.upsertOverride(widget.serviceId!, updated);
    }
  }

  Future<void> _toggleFullDayBooked(DateTime day, bool booked) async {
    final newVal = ServiceAvailabilityOverride(
      date: DateTime(day.year, day.month, day.day),
      morningAvailable: !booked,
      afternoonAvailable: !booked,
      eveningAvailable: !booked,
      nightAvailable: !booked,
    );
    setState(() {
      _overrides[DateTime(day.year, day.month, day.day)] = newVal;
    });
    widget.controller?.setOverride(newVal);
    if (widget.serviceId != null && widget.persistImmediately) {
      await widget.availabilityService.upsertOverride(widget.serviceId!, newVal);
    }
  }

  Future<void> _applyStatus(DateTime day, DayStatus status) async {
    switch (status) {
      case DayStatus.booked:
        await _toggleFullDayBooked(day, true);
        break;
      case DayStatus.available:
        final newVal = ServiceAvailabilityOverride(
          date: DateTime(day.year, day.month, day.day),
          morningAvailable: true,
          afternoonAvailable: true,
          eveningAvailable: true,
          nightAvailable: true,
        );
        setState(() {
          _overrides[DateTime(day.year, day.month, day.day)] = newVal;
        });
        widget.controller?.setOverride(newVal);
        if (widget.serviceId != null) {
          await widget.availabilityService.upsertOverride(widget.serviceId!, newVal);
        }
        break;
      case DayStatus.partial:
        // Default partial template: morning + afternoon available, evening + night unavailable
        final newVal = ServiceAvailabilityOverride(
          date: DateTime(day.year, day.month, day.day),
          morningAvailable: true,
          afternoonAvailable: true,
          eveningAvailable: false,
          nightAvailable: false,
        );
        setState(() {
          _overrides[DateTime(day.year, day.month, day.day)] = newVal;
        });
        widget.controller?.setOverride(newVal);
        if (widget.serviceId != null) {
          await widget.availabilityService.upsertOverride(widget.serviceId!, newVal);
        }
        break;
    }
  }

  TimeOfDay _parseTimeOfDay(String? value, {int fallbackHour = 9}) {
    if (value == null || value.isEmpty) return TimeOfDay(hour: fallbackHour, minute: 0);
    final parts = value.split(':');
    if (parts.length != 2) return TimeOfDay(hour: fallbackHour, minute: 0);
    final h = int.tryParse(parts[0]) ?? fallbackHour;
    final m = int.tryParse(parts[1]) ?? 0;
    return TimeOfDay(hour: h.clamp(0, 23), minute: m.clamp(0, 59));
  }

  String _formatTimeOfDay24(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatTimeUi12(String? hhmm) {
    if (hhmm == null || hhmm.isEmpty) return '';
    final parts = hhmm.split(':');
    if (parts.length != 2) return hhmm;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final dt = DateTime(2000, 1, 1, h, m);
    return DateFormat('h:mm a').format(dt);
  }

  bool _overlaps(TimeOfDay startA, TimeOfDay endA, TimeOfDay startB, TimeOfDay endB) {
    int toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;
    final a1 = toMinutes(startA);
    final a2 = toMinutes(endA);
    final b1 = toMinutes(startB);
    final b2 = toMinutes(endB);
    return a1 < b2 && b1 < a2;
  }

  Future<void> _applyCustomBookedWindow(DateTime day, String startHHmm, String endHHmm) async {
    // Interpret [start, end) as BOOKED window; remaining time is available.
    final start = _parseTimeOfDay(startHHmm);
    final end = _parseTimeOfDay(endHHmm);

    int minutes(TimeOfDay t) => t.hour * 60 + t.minute;

    bool fullDayBooked;
    if (minutes(start) == minutes(end)) {
      fullDayBooked = true; // 24h window
    } else if (minutes(start) < minutes(end)) {
      fullDayBooked = (minutes(end) - minutes(start)) >= (24 * 60 - 1);
    } else {
      // wrap booking covers from start..24h and 0..end
      fullDayBooked = true;
    }

    if (fullDayBooked) {
      await _toggleFullDayBooked(day, true);
      // also store window for reference
      final bookedAll = ServiceAvailabilityOverride(
        date: DateTime(day.year, day.month, day.day),
        morningAvailable: false,
        afternoonAvailable: false,
        eveningAvailable: false,
        nightAvailable: false,
        customStart: startHHmm,
        customEnd: endHHmm,
      );
      setState(() {
        _overrides[DateTime(day.year, day.month, day.day)] = bookedAll;
      });
      widget.controller?.setOverride(bookedAll);
      if (widget.serviceId != null && widget.persistImmediately) {
        await widget.availabilityService.upsertOverride(widget.serviceId!, bookedAll);
      }
      return;
    }

    // Define slot windows (local): Morning 06:00-12:00, Afternoon 12:00-17:00, Evening 17:00-21:00, Night 21:00-06:00 (wrap)
    final sMorning = TimeOfDay(hour: 6, minute: 0), eMorning = TimeOfDay(hour: 12, minute: 0);
    final sAfternoon = TimeOfDay(hour: 12, minute: 0), eAfternoon = TimeOfDay(hour: 17, minute: 0);
    final sEvening = TimeOfDay(hour: 17, minute: 0), eEvening = TimeOfDay(hour: 21, minute: 0);
    final sNight1 = TimeOfDay(hour: 21, minute: 0), eNight1 = TimeOfDay(hour: 24 % 24, minute: 0);
    final sNight2 = TimeOfDay(hour: 0, minute: 0), eNight2 = TimeOfDay(hour: 6, minute: 0);

    bool bookedOverlap(TimeOfDay slotStart, TimeOfDay slotEnd) {
      if (minutes(start) <= minutes(end)) {
        // simple case
        return _overlaps(start, end, slotStart, slotEnd);
      }
      // wrap booking: overlaps if intersects either [start..24:00) or [00:00..end)
      final wrapStartA = start, wrapEndA = TimeOfDay(hour: 24 % 24, minute: 0);
      final wrapStartB = TimeOfDay(hour: 0, minute: 0), wrapEndB = end;
      return _overlaps(wrapStartA, wrapEndA, slotStart, slotEnd) || _overlaps(wrapStartB, wrapEndB, slotStart, slotEnd);
    }

    final morningAvail = !bookedOverlap(sMorning, eMorning);
    final afternoonAvail = !bookedOverlap(sAfternoon, eAfternoon);
    final eveningAvail = !bookedOverlap(sEvening, eEvening);
    final nightAvail = !(bookedOverlap(sNight1, eNight1) || bookedOverlap(sNight2, eNight2));

    final up = ServiceAvailabilityOverride(
      date: DateTime(day.year, day.month, day.day),
      morningAvailable: morningAvail,
      afternoonAvailable: afternoonAvail,
      eveningAvailable: eveningAvail,
      nightAvailable: nightAvail,
      customStart: startHHmm,
      customEnd: endHHmm,
    );
    setState(() {
      _overrides[DateTime(day.year, day.month, day.day)] = up;
    });
    widget.controller?.setOverride(up);
    if (widget.serviceId != null && widget.persistImmediately) {
      await widget.availabilityService.upsertOverride(widget.serviceId!, up);
    }
  }

  Future<void> _applyCustomAvailableWindow(DateTime day, String startHHmm, String endHHmm) async {
    // Interpret [start, end) as AVAILABLE window; remaining time is booked (unavailable)
    final start = _parseTimeOfDay(startHHmm);
    final end = _parseTimeOfDay(endHHmm);

    int minutes(TimeOfDay t) => t.hour * 60 + t.minute;

    // Define slot windows
    final sMorning = TimeOfDay(hour: 6, minute: 0), eMorning = TimeOfDay(hour: 12, minute: 0);
    final sAfternoon = TimeOfDay(hour: 12, minute: 0), eAfternoon = TimeOfDay(hour: 17, minute: 0);
    final sEvening = TimeOfDay(hour: 17, minute: 0), eEvening = TimeOfDay(hour: 21, minute: 0);
    final sNight1 = TimeOfDay(hour: 21, minute: 0), eNight1 = TimeOfDay(hour: 24 % 24, minute: 0);
    final sNight2 = TimeOfDay(hour: 0, minute: 0), eNight2 = TimeOfDay(hour: 6, minute: 0);

    bool availableOverlap(TimeOfDay slotStart, TimeOfDay slotEnd) {
      if (minutes(start) <= minutes(end)) {
        return _overlaps(start, end, slotStart, slotEnd);
      }
      // wrap available window spans midnight
      final wrapStartA = start, wrapEndA = TimeOfDay(hour: 24 % 24, minute: 0);
      final wrapStartB = const TimeOfDay(hour: 0, minute: 0), wrapEndB = end;
      return _overlaps(wrapStartA, wrapEndA, slotStart, slotEnd) || _overlaps(wrapStartB, wrapEndB, slotStart, slotEnd);
    }

    final morningAvail = availableOverlap(sMorning, eMorning);
    final afternoonAvail = availableOverlap(sAfternoon, eAfternoon);
    final eveningAvail = availableOverlap(sEvening, eEvening);
    final nightAvail = availableOverlap(sNight1, eNight1) || availableOverlap(sNight2, eNight2);

    final up = ServiceAvailabilityOverride(
      date: DateTime(day.year, day.month, day.day),
      morningAvailable: morningAvail,
      afternoonAvailable: afternoonAvail,
      eveningAvailable: eveningAvail,
      nightAvailable: nightAvail,
      customStart: startHHmm,
      customEnd: endHHmm,
    );
    setState(() {
      _overrides[DateTime(day.year, day.month, day.day)] = up;
    });
    widget.controller?.setOverride(up);
    if (widget.serviceId != null && widget.persistImmediately) {
      await widget.availabilityService.upsertOverride(widget.serviceId!, up);
    }
  }

  bool _isPastDate(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(day.year, day.month, day.day);
    return target.isBefore(today);
  }

  Future<void> _promptStatusAndTimes(BuildContext context, DateTime day) async {
    final status = await showDialog<DayStatus>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Set ${DateFormat('EEE, MMM d').format(day)}', maxLines: 2, overflow: TextOverflow.ellipsis),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, DayStatus.available),
            child: const Text('Available'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, DayStatus.partial),
            child: const Text('Partially Available'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, DayStatus.booked),
            child: const Text('Booked'),
          ),
        ],
      ),
    );
    if (status == null) return;

    if (status == DayStatus.booked) {
      await _toggleFullDayBooked(day, true);
      return;
    }
    
    // If "Available" is selected, automatically mark all time slots as available
    if (status == DayStatus.available) {
      await _applyStatus(day, DayStatus.available);
      return;
    }
    
    // Only show time slot selection for "Partially Available"
    // Multi-select slot chips flow
    // Persist selection state across setState within the sheet
    final Set<DaySlot> availableSel = <DaySlot>{};
    final Set<DaySlot> bookedSel = <DaySlot>{};

    await showModalBottomSheet(
      context: context,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return DefaultTabController(
          length: 1,
          child: StatefulBuilder(
            builder: (ctx, setS) {
              String slotLabel(DaySlot s) {
                switch (s) {
                  case DaySlot.morning: return 'Morning';
                  case DaySlot.afternoon: return 'Afternoon';
                  case DaySlot.evening: return 'Evening';
                  case DaySlot.night: return 'Night';
                }
              }

              String slotTimeLabel(DaySlot s) {
                switch (s) {
                  case DaySlot.morning: return '06:00 - 12:00';
                  case DaySlot.afternoon: return '12:00 - 17:00';
                  case DaySlot.evening: return '17:00 - 21:00';
                  case DaySlot.night: return '21:00 - 06:00';
                }
              }

              Widget slotsChecklist(Set<DaySlot> target, {Color? color}) {
                Widget tile(DaySlot s) => CheckboxListTile(
                  value: target.contains(s),
                  onChanged: (v) => setS(() { if (v == true) {
                    target.add(s);
                  } else {
                    target.remove(s);
                  } }),
                  title: Text(slotLabel(s), maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(slotTimeLabel(s), maxLines: 1, overflow: TextOverflow.ellipsis),
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: color ?? Theme.of(context).colorScheme.primary,
                );
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    tile(DaySlot.morning),
                    tile(DaySlot.afternoon),
                    tile(DaySlot.evening),
                    tile(DaySlot.night),
                  ],
                );
              }

              Future<void> apply() async {
                // For partial booking: only selected slots are available
                // If no slots selected, all slots will be unavailable (booked)
                bool m = availableSel.contains(DaySlot.morning) && !bookedSel.contains(DaySlot.morning);
                bool a = availableSel.contains(DaySlot.afternoon) && !bookedSel.contains(DaySlot.afternoon);
                bool e = availableSel.contains(DaySlot.evening) && !bookedSel.contains(DaySlot.evening);
                bool n = availableSel.contains(DaySlot.night) && !bookedSel.contains(DaySlot.night);
                final up = ServiceAvailabilityOverride(
                  date: DateTime(day.year, day.month, day.day),
                  morningAvailable: m,
                  afternoonAvailable: a,
                  eveningAvailable: e,
                  nightAvailable: n,
                );
                setState(() {
                  _overrides[DateTime(day.year, day.month, day.day)] = up;
                });
                widget.controller?.setOverride(up);
                if (widget.serviceId != null && widget.persistImmediately) {
                  await widget.availabilityService.upsertOverride(widget.serviceId!, up);
                }
                if (context.mounted) Navigator.pop(ctx);
              }

              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    const Text('Select available slots'),
                    const SizedBox(height: 4),
                    slotsChecklist(availableSel, color: Colors.green),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(onPressed: apply, child: const Text('Apply')),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _openDayEditor(BuildContext context, DateTime day) {
    final cur = _currentFor(day);
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        bool fullBooked = !cur.morningAvailable && !cur.afternoonAvailable;
        bool morning = cur.morningAvailable;
        bool afternoon = cur.afternoonAvailable;
        bool evening = cur.eveningAvailable;
        bool night = cur.nightAvailable;
        String? startStr = cur.customStart;
        String? endStr = cur.customEnd;
        return StatefulBuilder(
          builder: (ctx, setS) => Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Edit ${DateFormat('EEE, MMM d').format(day)}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Full day booked'),
                    Switch(
                      value: fullBooked,
                      onChanged: (v) async {
                        setS(() {
                          fullBooked = v;
                          morning = !v;
                          afternoon = !v;
                          evening = !v;
                          night = !v;
                        });
                        await _toggleFullDayBooked(day, v);
                      },
                    )
                  ],
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Morning available'),
                    Switch(
                      value: morning,
                      onChanged: fullBooked
                          ? null
                          : (v) async {
                              setS(() => morning = v);
                              await _toggle(day, DaySlot.morning, v);
                            },
                    )
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Afternoon available'),
                    Switch(
                      value: afternoon,
                      onChanged: fullBooked
                          ? null
                          : (v) async {
                              setS(() => afternoon = v);
                              await _toggle(day, DaySlot.afternoon, v);
                            },
                    )
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Evening available'),
                    Switch(
                      value: evening,
                      onChanged: fullBooked
                          ? null
                          : (v) async {
                              setS(() => evening = v);
                              await _toggle(day, DaySlot.evening, v);
                            },
                    )
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Night available'),
                    Switch(
                      value: night,
                      onChanged: fullBooked
                          ? null
                          : (v) async {
                              setS(() => night = v);
                              await _toggle(day, DaySlot.night, v);
                            },
                    )
                  ],
                ),
                const SizedBox(height: 8),
                Text('Custom time window (optional)', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.access_time),
                        label: Text(startStr == null || startStr!.isEmpty ? 'Start time' : 'Start: ${_formatTimeUi12(startStr)}'),
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: _parseTimeOfDay(startStr, fallbackHour: 9),
                            helpText: 'Select start time',
                            builder: (context, child) {
                              final mq = MediaQuery.of(context);
                              return MediaQuery(
                                data: mq.copyWith(alwaysUse24HourFormat: false),
                                child: child ?? const SizedBox.shrink(),
                              );
                            },
                          );
                          if (picked != null) {
                            startStr = _formatTimeOfDay24(picked);
                            setS(() {});
                            // Only apply when both bounds selected
                            if ((startStr ?? '').isNotEmpty && (endStr ?? '').isNotEmpty) {
                              await _applyCustomBookedWindow(day, startStr!, endStr!);
                            }
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.access_time),
                        label: Text(endStr == null || endStr!.isEmpty ? 'End time' : 'End: ${_formatTimeUi12(endStr)}'),
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: _parseTimeOfDay(endStr, fallbackHour: 17),
                            helpText: 'Select end time',
                            builder: (context, child) {
                              final mq = MediaQuery.of(context);
                              return MediaQuery(
                                data: mq.copyWith(alwaysUse24HourFormat: false),
                                child: child ?? const SizedBox.shrink(),
                              );
                            },
                          );
                          if (picked != null) {
                            endStr = _formatTimeOfDay24(picked);
                            setS(() {});
                            if ((startStr ?? '').isNotEmpty && (endStr ?? '').isNotEmpty) {
                              await _applyCustomBookedWindow(day, startStr!, endStr!);
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('MMMM yyyy').format(_visibleMonth);
    final firstWeekday = DateTime(_visibleMonth.year, _visibleMonth.month, 1).weekday; // 1=Mon..7=Sun
    final daysInMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    final leadingEmpty = (firstWeekday % 7); // convert Monday=1..Sunday=7 to 0..6 starting on Sunday visually

    final items = <Widget>[];
    for (int i = 0; i < leadingEmpty; i++) {
      items.add(const SizedBox());
    }
    for (int d = 1; d <= daysInMonth; d++) {
      final day = DateTime(_visibleMonth.year, _visibleMonth.month, d);
      final status = _statusFor(day);
      final isPast = _isPastDate(day);
      items.add(_StatusDayTile(
        day: day,
        status: status,
        onTap: () async {
          // Prevent editing past dates
          if (isPast) {
            return;
          }
          if (widget.isViewMode) {
            if (status != null) setState(() => _selectedForDetails = day);
            return;
          }
          if (_activePaintStatus != null) {
            await _applyStatus(day, _activePaintStatus!);
          } else {
            await _promptStatusAndTimes(context, day);
          }
        },
        onLongPress: isPast ? null : () => _openDayEditor(context, day),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: Text(monthLabel, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis)),
              Row(
                children: [
                  IconButton(icon: const Icon(Icons.chevron_left), onPressed: _loading ? null : () => _changeMonth(-1)),
                  IconButton(icon: const Icon(Icons.chevron_right), onPressed: _loading ? null : () => _changeMonth(1)),
                ],
              )
            ],
          ),
        ),
        // Weekday headers (Sun..Sat) to match the UI
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              WeekdayLabel('SUN'),
              WeekdayLabel('MON'),
              WeekdayLabel('TUE'),
              WeekdayLabel('WED'),
              WeekdayLabel('THU'),
              WeekdayLabel('FRI'),
              WeekdayLabel('SAT'),
            ],
          ),
        ),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          children: items,
        ),
        if (widget.isViewMode && _selectedForDetails != null && _statusFor(_selectedForDetails!) == DayStatus.partial) ...[
          const SizedBox(height: 12),
          _PartialDetailsCard(overrideFor: _currentFor(_selectedForDetails!)),
        ],
        const SizedBox(height: 12),
        const SizedBox(height: 12),
        _Legend(),
      ],
    );
  }
}

class _StatusDayTile extends StatelessWidget {
  final DateTime day;
  final DayStatus? status;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _StatusDayTile({required this.day, required this.status, required this.onTap, this.onLongPress});

  Color? _statusColor(BuildContext context) {
    if (status == null) return null;
    switch (status!) {
      case DayStatus.booked:
        return Colors.redAccent;
      case DayStatus.available:
        return Colors.green;
      case DayStatus.partial:
        return Colors.orangeAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(context);
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: (color ?? Colors.black12).withOpacity(color == null ? 0.1 : 0.25)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 1))],
        ),
        alignment: Alignment.center,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(color: (color ?? Colors.transparent).withOpacity(color == null ? 0 : 0.18), shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text('${day.day}', style: TextStyle(fontWeight: FontWeight.w700, color: color ?? Colors.black87)),
        ),
      ),
    );
  }
}

// Unused helper removed

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Widget item(Color c, String label) => Row(
          children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(label),
          ],
        );
    return Column(
      children: [
        const Divider(),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            item(Colors.redAccent, 'Booked'),
            item(Colors.green, 'Available'),
            item(Colors.orangeAccent, 'Partially Available'),
          ],
        ),
      ],
    );
  }
}


class WeekdayLabel extends StatelessWidget {
  final String text;
  const WeekdayLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          text,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black54),
        ),
      ),
    );
  }
}

class _PartialDetailsCard extends StatelessWidget {
  final ServiceAvailabilityOverride overrideFor;
  const _PartialDetailsCard({required this.overrideFor});

  String _humanize(ServiceAvailabilityOverride o) {
    final ranges = <String>[];
    if (o.customStart != null || o.customEnd != null) {
      final a = o.customStart ?? '--:--';
      final b = o.customEnd ?? '--:--';
      ranges.add('$a - $b');
    }
    if (o.morningAvailable || o.afternoonAvailable || o.eveningAvailable || o.nightAvailable) {
      final parts = <String>[];
      if (o.morningAvailable) parts.add('Morning');
      if (o.afternoonAvailable) parts.add('Afternoon');
      if (o.eveningAvailable) parts.add('Evening');
      if (o.nightAvailable) parts.add('Night');
      if (parts.isNotEmpty) ranges.add(parts.join(', '));
    }
    return ranges.isEmpty ? 'No available slots' : ranges.join('  •  ');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
        border: Border.all(color: Colors.orangeAccent.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info, color: Colors.orangeAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Partially Available', style: TextStyle(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(_humanize(overrideFor), maxLines: 3, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


