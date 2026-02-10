import 'package:equatable/equatable.dart';

class WeeklyChartItem extends Equatable {
  const WeeklyChartItem({
    required this.date,
    required this.label,
    required this.value,
  });

  final DateTime date;
  final String label;
  final double value;

  @override
  List<Object?> get props => [date, label, value];
}
