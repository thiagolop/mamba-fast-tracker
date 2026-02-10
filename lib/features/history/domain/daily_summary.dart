import 'package:equatable/equatable.dart';

class DailySummary extends Equatable {
  const DailySummary({
    required this.dateKey,
    required this.date,
    required this.caloriesTotal,
    required this.fastingTotal,
    required this.isOnTrack,
  });

  final String dateKey;
  final DateTime date;
  final int caloriesTotal;
  final Duration fastingTotal;
  final bool isOnTrack;

  @override
  List<Object?> get props => [
        dateKey,
        date,
        caloriesTotal,
        fastingTotal,
        isOnTrack,
      ];
}
