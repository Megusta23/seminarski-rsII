/// Returns the application-wide UTC business date as a date-only [DateTime].
///
/// The returned value intentionally carries only calendar components. It is used
/// for APIs whose contract is a `DateOnly`, so the value must not shift when the
/// device's local time zone differs from UTC.
DateTime utcBusinessDate([DateTime? instant]) {
  final DateTime utc = (instant ?? DateTime.now()).toUtc();
  return DateTime(utc.year, utc.month, utc.day);
}

/// Returns the UTC calendar date represented by [instant] without a time value.
DateTime utcCalendarDate(DateTime instant) {
  final DateTime utc = instant.toUtc();
  return DateTime(utc.year, utc.month, utc.day);
}

/// Returns the calendar components of [value] without applying a time-zone
/// conversion. This is useful when [value] already represents an API DateOnly.
DateTime calendarDate(DateTime value) =>
    DateTime(value.year, value.month, value.day);
