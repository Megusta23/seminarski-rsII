import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ladder_social_core/ladder_social_core.dart';
import 'package:ladder_social_mobile/src/core/providers/core_providers.dart';
import 'package:ladder_social_mobile/src/core/widgets/mobile_widgets.dart';

final class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({
    this.pollInterval = const Duration(seconds: 10),
    super.key,
  });

  final Duration pollInterval;

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

final class _NotificationsScreenState
    extends ConsumerState<NotificationsScreen> with WidgetsBindingObserver {
  Timer? _pollTimer;
  List<AppNotification> _items = const <AppNotification>[];
  bool? _isRead;
  bool _didInitialize = false;
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _reloadQueued = false;
  bool _queuedShowLoading = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInitialize) {
      return;
    }

    _didInitialize = true;
    _startPolling();
    unawaited(_load());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling();
      unawaited(_load());
      return;
    }

    _pollTimer?.cancel();
    _pollTimer = null;
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      widget.pollInterval,
      (_) => unawaited(_load()),
    );
  }

  Future<void> _load({bool showLoading = false}) async {
    if (!mounted) {
      return;
    }

    if (_isRefreshing) {
      _reloadQueued = true;
      _queuedShowLoading = _queuedShowLoading || showLoading;
      return;
    }

    _isRefreshing = true;
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final PagedResult<AppNotification> result = await ref
          .read(notificationRepositoryProvider)
          .getNotifications(isRead: _isRead);
      if (!mounted) {
        return;
      }

      setState(() {
        _items = List<AppNotification>.unmodifiable(result.items);
        _isLoading = false;
        _error = null;
      });
      ref.invalidate(notificationSummaryProvider);
    } catch (error) {
      if (!mounted) {
        return;
      }

      if (showLoading || _items.isEmpty) {
        setState(() {
          _isLoading = false;
          _error = error;
        });
      }
    } finally {
      _isRefreshing = false;
      if (_reloadQueued && mounted) {
        final bool queuedShowLoading = _queuedShowLoading;
        _reloadQueued = false;
        _queuedShowLoading = false;
        unawaited(_load(showLoading: queuedShowLoading));
      }
    }
  }

  Future<void> _markAll() async {
    try {
      await ref.read(notificationRepositoryProvider).markAllRead();
      if (mounted) {
        showMessage(context, 'All notifications marked as read.');
        await _load();
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
        await _load();
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
        onRefresh: _load,
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
                unawaited(_load(showLoading: true));
              },
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null)
              AppErrorView(
                error: _error!,
                onRetry: () => unawaited(_load(showLoading: true)),
              )
            else if (_items.isEmpty)
              const EmptyState(
                icon: Icons.notifications_none,
                title: 'No notifications',
              )
            else
              Column(
                children: _items
                    .map(
                      (AppNotification item) => Card(
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
                            '${item.body}\n${formatDateTime(item.createdAtUtc)}',
                          ),
                          isThreeLine: true,
                          trailing: item.isRead
                              ? const Icon(Icons.done, size: 18)
                              : const Icon(Icons.circle, size: 12),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
          ],
        ),
      ),
    );
  }
}
