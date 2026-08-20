Map<String, dynamic> jsonMap(Object? value, {String context = 'response'}) {
  if (value is! Map<dynamic, dynamic>) {
    throw FormatException('The server returned an invalid $context object.');
  }
  return Map<String, dynamic>.from(value);
}

List<dynamic> jsonList(Object? value, {String context = 'response'}) {
  if (value is! List<dynamic>) {
    throw FormatException('The server returned an invalid $context list.');
  }
  return value;
}

int requiredInt(Map<String, dynamic> json, String key) {
  final Object? value = json[key];
  if (value is int) return value;
  final int? parsed = int.tryParse(value?.toString() ?? '');
  if (parsed == null) {
    throw FormatException('Server response is missing a valid "$key".');
  }
  return parsed;
}

bool requiredBool(Map<String, dynamic> json, String key) {
  final Object? value = json[key];
  if (value is bool) return value;
  final String normalized = value?.toString().toLowerCase() ?? '';
  if (normalized == 'true') return true;
  if (normalized == 'false') return false;
  throw FormatException('Server response is missing a valid "$key".');
}

DateTime? nullableDateTime(Object? value) {
  final String? text = value?.toString();
  if (text == null || text.isEmpty) return null;
  return DateTime.parse(text).toUtc();
}

String dateOnlyString(DateTime value) {
  final DateTime local = value.toLocal();
  final String month = local.month.toString().padLeft(2, '0');
  final String day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}
