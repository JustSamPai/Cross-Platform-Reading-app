String todaysDateFormatted([DateTime? now]) {
  return convertDateTimeToString(now ?? DateTime.now());
}

DateTime createDateTimeObject(String yyyymmdd) {
  if (yyyymmdd.length != 8) {
    throw FormatException('Expected date key in yyyymmdd format.', yyyymmdd);
  }

  final year = int.parse(yyyymmdd.substring(0, 4));
  final month = int.parse(yyyymmdd.substring(4, 6));
  final day = int.parse(yyyymmdd.substring(6, 8));

  return DateTime(year, month, day);
}

String convertDateTimeToString(DateTime dateTime) {
  final year = dateTime.year.toString().padLeft(4, '0');
  final month = dateTime.month.toString().padLeft(2, '0');
  final day = dateTime.day.toString().padLeft(2, '0');

  return '$year$month$day';
}

DateTime dateOnly(DateTime dateTime) {
  return DateTime(dateTime.year, dateTime.month, dateTime.day);
}

Iterable<DateTime> daysBetween(DateTime start, DateTime end) sync* {
  var day = dateOnly(start);
  final lastDay = dateOnly(end);

  while (!day.isAfter(lastDay)) {
    yield day;
    day = day.add(const Duration(days: 1));
  }
}
