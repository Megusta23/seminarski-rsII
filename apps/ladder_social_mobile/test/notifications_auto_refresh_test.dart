import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ladder_social_core/ladder_social_core.dart';
import 'package:ladder_social_mobile/src/core/providers/core_providers.dart';
import 'package:ladder_social_mobile/src/features/notifications/presentation/notifications_screen.dart';

final class _FakeNotificationDataSource implements NotificationDataSource {
  int requestCount = 0;

  @override
  Future<PagedResult<AppNotification>> getNotifications({
    bool? isRead,
    String? search,
    int page = 1,
    int pageSize = 20,
  }) async {
    requestCount += 1;
    final String title = requestCount == 1
        ? 'Initial notification'
        : 'Automatically refreshed notification';
    return PagedResult<AppNotification>(
      items: <AppNotification>[
        AppNotification(
          id: 'notification-$requestCount',
          kind: NotificationKind.system,
          title: title,
          body: 'Notification body',
          isRead: false,
          createdAtUtc: DateTime.utc(2026, 9, 1, 12),
        ),
      ],
      page: 1,
      pageSize: pageSize,
      totalCount: 1,
      totalPages: 1,
    );
  }

  @override
  Future<NotificationSummary> getSummary() async => NotificationSummary(
        unreadCount: 1,
        generatedAtUtc: DateTime.utc(2026, 9, 1, 12),
      );

  @override
  Future<void> markAllRead() async {}

  @override
  Future<void> markRead(String id) async {}
}

void main() {
  testWidgets('open notification list refreshes automatically', (
    WidgetTester tester,
  ) async {
    final _FakeNotificationDataSource dataSource =
        _FakeNotificationDataSource();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationRepositoryProvider.overrideWithValue(dataSource),
        ],
        child: const MaterialApp(
          home: NotificationsScreen(
            pollInterval: Duration(seconds: 1),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Initial notification'), findsOneWidget);
    expect(dataSource.requestCount, 1);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(
      find.text('Automatically refreshed notification'),
      findsOneWidget,
    );
    expect(dataSource.requestCount, greaterThanOrEqualTo(2));
  });
}
