import 'package:flutter/material.dart';

class DaySummaryTile extends StatelessWidget {
  const DaySummaryTile({
    super.key,
    required this.dateLabel,
    required this.caloriesLabel,
    required this.fastingLabel,
    required this.statusLabel,
    required this.isOnTrack,
    this.onTap,
  });

  final String dateLabel;
  final String caloriesLabel;
  final String fastingLabel;
  final String statusLabel;
  final bool isOnTrack;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusColor = isOnTrack
        ? colorScheme.primary
        : colorScheme.error;

    return Card(
      child: ListTile(
        onTap: onTap,
        title: Text(
          dateLabel,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text('$caloriesLabel • $fastingLabel'),
        trailing: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: statusColor.withAlpha(100),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            statusLabel,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
