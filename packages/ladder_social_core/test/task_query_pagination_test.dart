import 'package:flutter_test/flutter_test.dart';
import 'package:ladder_social_core/ladder_social_core.dart';

void main() {
  test('task query sends bounded board section parameters', () {
    final Map<String, dynamic> query = TaskQuery(
      section: TaskBoardSection.daily,
      businessDate: DateTime.utc(2026, 9, 1),
      page: 2,
      pageSize: 15,
    ).toQueryParameters();

    expect(query['section'], TaskBoardSection.daily);
    expect(query['businessDate'], '2026-09-01');
    expect(query['page'], 2);
    expect(query['pageSize'], 15);
  });
}
