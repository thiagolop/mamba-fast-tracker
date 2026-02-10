String dateKeyFromDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

DateTime dateFromKey(String key) {
  final parts = key.split('-');
  if (parts.length != 3) {
    return DateTime.now();
  }
  final year = int.tryParse(parts[0]) ?? DateTime.now().year;
  final month = int.tryParse(parts[1]) ?? DateTime.now().month;
  final day = int.tryParse(parts[2]) ?? DateTime.now().day;
  return DateTime(year, month, day);
}

DateTime startOfDay(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

DateTime endOfDay(DateTime date) {
  return DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
}
