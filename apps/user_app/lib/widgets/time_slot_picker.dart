import 'package:flutter/material.dart';

class TimeSlot {
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final bool isAvailable;

  const TimeSlot({
    required this.startTime,
    required this.endTime,
    required this.isAvailable,
  });

  String get formattedTime {
    final start = _formatTimeOfDay(startTime);
    final end = _formatTimeOfDay(endTime);
    return '$start - $end';
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour == 0 ? 12 : (time.hour > 12 ? time.hour - 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }
}

class TimeSlotPicker extends StatefulWidget {
  final List<TimeSlot> availableSlots;
  final TimeSlot? selectedSlot;
  final Function(TimeSlot) onSlotSelected;

  const TimeSlotPicker({
    super.key,
    required this.availableSlots,
    this.selectedSlot,
    required this.onSlotSelected,
  });

  @override
  State<TimeSlotPicker> createState() => _TimeSlotPickerState();
}

class _TimeSlotPickerState extends State<TimeSlotPicker> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Available Time Slots',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (widget.availableSlots.isEmpty)
          Text(
            'No available time slots for this date.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.availableSlots.map((slot) {
              final isSelected = widget.selectedSlot == slot;
              final isAvailable = slot.isAvailable;
              return GestureDetector(
                onTap: isAvailable ? () => widget.onSlotSelected(slot) : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : (isAvailable 
                            ? theme.colorScheme.primaryContainer.withOpacity(0.3)
                            : theme.colorScheme.surfaceContainerHighest),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : (isAvailable 
                              ? theme.colorScheme.primary.withOpacity(0.5)
                              : theme.colorScheme.outline.withOpacity(0.3)),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    slot.formattedTime,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isSelected
                          ? theme.colorScheme.onPrimary
                          : (isAvailable 
                              ? theme.colorScheme.onSurface
                              : theme.colorScheme.onSurface.withOpacity(0.5)),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}
