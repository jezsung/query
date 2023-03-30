bool isOutdated(
  DateTime dateTime,
  Duration duration,
) {
  return dateTime.isBefore(DateTime.now().subtract(duration));
}
