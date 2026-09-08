/// Merges paged or real-time items without duplicating records that share a key.
///
/// Values from [updates] replace values from [current]. Supply [compare] when
/// server ordering must be restored after the merge.
List<T> mergeUniqueItems<T>({
  required Iterable<T> current,
  required Iterable<T> updates,
  required Object Function(T item) keyOf,
  Comparator<T>? compare,
}) {
  final Map<Object, T> byKey = <Object, T>{};
  for (final T item in current) {
    byKey[keyOf(item)] = item;
  }
  for (final T item in updates) {
    byKey[keyOf(item)] = item;
  }

  final List<T> result = byKey.values.toList(growable: false);
  if (compare != null) {
    result.sort(compare);
  }
  return List<T>.unmodifiable(result);
}
