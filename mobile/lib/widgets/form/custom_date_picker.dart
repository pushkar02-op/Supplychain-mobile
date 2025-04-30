import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CustomDatePicker extends StatelessWidget {
  final DateTime selectedDate;
  final Function() onTap;
  final bool enabled;
  final Widget label;

  const CustomDatePicker({
    super.key,
    required this.selectedDate,
    required this.onTap,
    required this.enabled,
    this.label = const Text('Date'),
  });

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('yyyy-MM-dd').format(selectedDate);

    if (enabled) {
      return ListTile(
        title: Row(
          children: [label, const SizedBox(width: 8), Text(formattedDate)],
        ),
        trailing: const Icon(Icons.calendar_today),
        onTap: onTap,
      );
    } else {
      return TextFormField(
        initialValue: formattedDate,
        decoration: InputDecoration(label: label),
        enabled: false,
      );
    }
  }
}
