import 'package:flutter_test/flutter_test.dart';
import 'package:ladder_social_core/ladder_social_core.dart';

void main() {
  test('paged merge replaces duplicate values and preserves unique records', () {
    final List<_Item> merged = mergeUniqueItems<_Item>(
      current: const <_Item>[
        _Item('one', 1),
        _Item('two', 2),
      ],
      updates: const <_Item>[
        _Item('two', 20),
        _Item('three', 3),
      ],
      keyOf: (_Item item) => item.id,
      compare: (_Item left, _Item right) => left.value.compareTo(right.value),
    );

    expect(merged.map((_Item item) => item.id), <String>['one', 'three', 'two']);
    expect(merged.last.value, 20);
  });
}

final class _Item {
  const _Item(this.id, this.value);

  final String id;
  final int value;
}
