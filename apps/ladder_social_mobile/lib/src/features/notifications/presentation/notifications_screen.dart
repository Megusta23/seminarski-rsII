import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ladder_social_core/ladder_social_core.dart';
import 'package:ladder_social_mobile/src/core/providers/core_providers.dart';
import 'package:ladder_social_mobile/src/core/widgets/mobile_widgets.dart';

final class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

final class _NotificationsScreenState
    extends ConsumerState<NotificationsScreen> {
  Future<PagedResult<AppNotification>>? _future;
  bool? _isRead;

  bool _didInitialize = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInitialize) {
      return;
    }

    _didInitialize = true;
    _future = _requestNotifications();
    ref.invalidate(notificationSummaryProvider);
  }

  Future<PagedResult<AppNotification>> _requestNotifications() {
    return ref
        .read(notificationRepositoryProvider)
        .getNotifications(isRead: _isRead);
  }

  void _load() {
    if (!mounted) {
      return;
    }

    setState(() {
      _future = _requestNotifications();
    });
    ref.invalidate(notificationSummaryProvider);
  }

  Future<void> _markAll() async {
    try {
      await ref.read(notificationRepositoryProvider).markAllRead();
      if (mounted) {
        showMessage(context, 'All notifications marked as read.');
        _load();
      }
    } catch (error) {
      if (mounted) {
        showMessage(context, ApiException.from(error).message, error: true);
      }
    }
  }

  Future<void> _mark(AppNotification notification) async {
    if (notification.isRead) {
      return;
    }
    try {
      await ref.read(notificationRepositoryProvider).markRead(notification.id);
      if (mounted) {
        _load();
      }
    } catch (error) {
      if (mounted) {
        showMessage(context, ApiException.from(error).message, error: true);
      }
    }
  }

  IconData _icon(int kind) => switch (kind) {
        NotificationKind.friendRequestReceived => Icons.person_add_alt_1,
        NotificationKind.friendRequestAccepted => Icons.people,
        NotificationKind.taskCompleted => Icons.task_alt,
        NotificationKind.newMessage => Icons.chat_bubble_outline,
        _ => Icons.notifications_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Mark all as read',
            onPressed: _markAll,
            icon: const Icon(Icons.done_all),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _load(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            SegmentedButton<bool?>(
              segments: const <ButtonSegment<bool?>>[
                ButtonSegment<bool?>(value: null, label: Text('All')),
                ButtonSegment<bool?>(value: false, label: Text('Unread')),
                ButtonSegment<bool?>(value: true, label: Text('Read')),
              ],
              selected: <bool?>{_isRead},
              onSelectionChanged: (Set<bool?> values) {
                setState(() => _isRead = values.first);
                _load();
              },
            ),
            const SizedBox(height: 12),
            FutureBuilder<PagedResult<AppNotification>>(
              future: _future,
              builder: (BuildContext context,
                  AsyncSnapshot<PagedResult<AppNotification>> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator()));
                }
                if (snapshot.hasError) {
                  return AppErrorView(error: snapshot.error!, onRetry: _load);
                }
                final List<AppNotification> items = snapshot.data!.items;
                if (items.isEmpty) {
                  return const EmptyState(
                    icon: Icons.notifications_none,
                    title: 'No notifications',
                  );
                }
                return Column(
                  children: items
                      .map((AppNotification item) => Card(
                            color: item.isRead
                                ? null
                                : Theme.of(context)
                                    .colorScheme
                                    .primaryContainer,
                            child: ListTile(
                              onTap: () => _mark(item),
                              leading: Icon(_icon(item.kind)),
                              title: Text(item.title),
                              subtitle: Text(
                                  '${item.body}\n${formatDateTime(item.createdAtUtc)}'),
                              isThreeLine: true,
                              trailing: item.isRead
                                  ? const Icon(Icons.done, size: 18)
                                  : const Icon(Icons.circle, size: 12),
                            ),
                          ))
                      .toList(growable: false),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
