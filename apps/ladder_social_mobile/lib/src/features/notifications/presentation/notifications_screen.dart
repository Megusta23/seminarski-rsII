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
  static const int _pageSize = 20;

  final ScrollController _scrollController = ScrollController();
  Timer? _pollTimer;
  List<AppNotification> _items = const <AppNotification>[];
  bool? _isRead;
  bool _didInitialize = false;
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _loadingMore = false;
  bool _reloadQueued = false;
  bool _queuedShowLoading = false;
  bool _queuedResetPagination = false;
  int _page = 0;
  int _totalPages = 1;
  int _queryGeneration = 0;
  Object? _error;
  Object? _loadMoreError;

  bool get _hasMore => _page < _totalPages;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_handleScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInitialize) {
      return;
    }

    _didInitialize = true;
    _startPolling();
    unawaited(_load(resetPagination: true));
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
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _handleScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.extentAfter < 320) {
      unawaited(_loadMore());
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      widget.pollInterval,
      (_) => unawaited(_load()),
    );
  }

  Future<void> _load({
    bool showLoading = false,
    bool resetPagination = false,
  }) async {
    if (!mounted) {
      return;
    }

    final int generation =
        resetPagination ? ++_queryGeneration : _queryGeneration;
    if (_isRefreshing) {
      _reloadQueued = true;
      _queuedShowLoading = _queuedShowLoading || showLoading;
      _queuedResetPagination =
          _queuedResetPagination || resetPagination;
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
          .getNotifications(
            isRead: _isRead,
            page: 1,
            pageSize: _pageSize,
          );
      if (!mounted || generation != _queryGeneration) {
        return;
      }

      final List<AppNotification> updated = resetPagination
          ? List<AppNotification>.unmodifiable(result.items)
          : mergeUniqueItems<AppNotification>(
              current: _items,
              updates: result.items,
              keyOf: (AppNotification item) => item.id,
              compare: _compareNotifications,
            );
      setState(() {
        _items = updated;
        _page = resetPagination ? result.page : (_page < 1 ? 1 : _page);
        _totalPages = result.totalPages;
        _isLoading = false;
        _error = null;
      });
      ref.invalidate(notificationSummaryProvider);
    } catch (error) {
      if (!mounted || generation != _queryGeneration) {
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
        final bool queuedResetPagination = _queuedResetPagination;
        _reloadQueued = false;
        _queuedShowLoading = false;
        _queuedResetPagination = false;
        unawaited(
          _load(
            showLoading: queuedShowLoading,
            resetPagination: queuedResetPagination,
          ),
        );
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || _loadingMore || !_hasMore) {
      return;
    }

    final int generation = _queryGeneration;
    setState(() {
      _loadingMore = true;
      _loadMoreError = null;
    });
    try {
      final PagedResult<AppNotification> result = await ref
          .read(notificationRepositoryProvider)
          .getNotifications(
            isRead: _isRead,
            page: _page + 1,
            pageSize: _pageSize,
          );
      if (!mounted || generation != _queryGeneration) {
        return;
      }
      setState(() {
        _items = mergeUniqueItems<AppNotification>(
          current: _items,
          updates: result.items,
          keyOf: (AppNotification item) => item.id,
          compare: _compareNotifications,
        );
        _page = result.page;
        _totalPages = result.totalPages;
      });
    } catch (error) {
      if (mounted && generation == _queryGeneration) {
        setState(() => _loadMoreError = error);
      }
    } finally {
      if (mounted && generation == _queryGeneration) {
        setState(() => _loadingMore = false);
      }
    }
  }

  int _compareNotifications(AppNotification left, AppNotification right) {
    final int time = right.createdAtUtc.compareTo(left.createdAtUtc);
    return time != 0 ? time : right.id.compareTo(left.id);
  }

  Future<void> _markAll() async {
    try {
      await ref.read(notificationRepositoryProvider).markAllRead();
      if (mounted) {
        showMessage(context, 'All notifications marked as read.');
        await _load(resetPagination: true);
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
        await _load(resetPagination: true);
      }
    } catch (error) {
      if (mounted) {
        showMessage(context, ApiException.from(error).message, error: true);
      }
    }
  }

  void _changeFilter(bool? value) {
    setState(() {
      _isRead = value;
      _items = const <AppNotification>[];
      _page = 0;
      _totalPages = 1;
      _loadingMore = false;
      _loadMoreError = null;
    });
    unawaited(_load(showLoading: true, resetPagination: true));
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
        onRefresh: () => _load(resetPagination: true),
        child: ListView(
          controller: _scrollController,
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
              onSelectionChanged: (Set<bool?> values) =>
                  _changeFilter(values.first),
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null && _items.isEmpty)
              AppErrorView(
                error: _error!,
                onRetry: () => unawaited(
                  _load(showLoading: true, resetPagination: true),
                ),
              )
            else if (_items.isEmpty)
              const EmptyState(
                icon: Icons.notifications_none,
                title: 'No notifications',
              )
            else ...<Widget>[
              for (final AppNotification item in _items)
                Card(
                  color: item.isRead
                      ? null
                      : Theme.of(context).colorScheme.primaryContainer,
                  child: ListTile(
                    onTap: () => unawaited(_mark(item)),
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
              AppPaginationFooter(
                hasMore: _hasMore,
                isLoading: _loadingMore,
                error: _loadMoreError,
                onLoadMore: () => unawaited(_loadMore()),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
