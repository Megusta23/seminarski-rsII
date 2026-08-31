import 'dart:collection';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ladder_social_core/ladder_social_core.dart';
import 'package:ladder_social_mobile/src/core/providers/core_providers.dart';
import 'package:ladder_social_mobile/src/core/widgets/mobile_widgets.dart';
import 'package:ladder_social_mobile/src/features/feed/presentation/feed_widgets.dart';
import 'package:ladder_social_mobile/src/features/feed/presentation/feed_search_action.dart';
import 'package:ladder_social_mobile/src/features/friends/presentation/friend_profile_screen.dart';

final class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({
    required this.searchController,
    super.key,
  });

  final FeedSearchController searchController;

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

final class _FeedScreenState extends ConsumerState<FeedScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<FeedPost> _items = <FeedPost>[];

  DateTime _selectedDate = utcBusinessDate();
  List<FriendProgress> _friendProgress = <FriendProgress>[];
  Object? _initialError;
  Object? _loadMoreError;
  bool _hasFriends = false;
  bool _isInitialLoading = true;
  bool _isLoadingMore = false;
  int _page = 0;
  int _totalPages = 0;
  int _requestVersion = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    widget.searchController.addListener(_onSearchChanged);
    _load(reset: true);
  }

  @override
  void didUpdateWidget(covariant FeedScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchController == widget.searchController) return;
    oldWidget.searchController.removeListener(_onSearchChanged);
    widget.searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    widget.searchController.removeListener(_onSearchChanged);
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _load(reset: true);
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 420) {
      _loadMore();
    }
  }

  Future<void> _load({required bool reset}) async {
    final int requestVersion = reset ? ++_requestVersion : _requestVersion;
    final DateTime requestedDate = _selectedDate;
    final String requestedSearch = widget.searchController.value;

    if (reset) {
      if (mounted) {
        setState(() {
          _isInitialLoading = true;
          _isLoadingMore = false;
          _initialError = null;
          _loadMoreError = null;
        });
      }
    } else {
      if (_isInitialLoading || _isLoadingMore || _page >= _totalPages) return;
      setState(() {
        _isLoadingMore = true;
        _loadMoreError = null;
      });
    }

    final int targetPage = reset ? 1 : _page + 1;
    try {
      final FeedPage page = await ref.read(feedRepositoryProvider).getFeed(
            date: requestedDate,
            search: requestedSearch,
            page: targetPage,
            pageSize: 100,
          );
      if (!mounted || requestVersion != _requestVersion) return;

      setState(() {
        if (reset) {
          _items
            ..clear()
            ..addAll(page.items);
        } else {
          final Set<String> existingKeys = _items
              .map((FeedPost item) => '${item.activityType.value}:${item.id}')
              .toSet();
          _items.addAll(
            page.items.where(
              (FeedPost item) =>
                  existingKeys.add('${item.activityType.value}:${item.id}'),
            ),
          );
        }
        _friendProgress = page.friendProgress;
        _hasFriends = page.hasFriends;
        _page = page.page;
        _totalPages = page.totalPages;
        _isInitialLoading = false;
        _isLoadingMore = false;
        _initialError = null;
        _loadMoreError = null;
      });
    } catch (error) {
      if (!mounted || requestVersion != _requestVersion) return;
      setState(() {
        if (reset) {
          _initialError = error;
          _isInitialLoading = false;
        } else {
          _loadMoreError = error;
          _isLoadingMore = false;
        }
      });
    }
  }

  Future<void> _loadMore() => _load(reset: false);

  Future<void> _pickDate() async {
    final DateTime today = utcBusinessDate();
    final DateTime? selected = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(today.year - 2),
      lastDate: today,
      helpText: 'Choose feed date',
    );
    if (!mounted || selected == null || DateUtils.isSameDay(selected, _selectedDate)) return;
    setState(() => _selectedDate = DateUtils.dateOnly(selected));
    await _load(reset: true);
  }

  Future<void> _moveDate(int days) async {
    final DateTime candidate = DateUtils.dateOnly(_selectedDate.add(Duration(days: days)));
    final DateTime today = utcBusinessDate();
    if (candidate.isAfter(today)) return;
    setState(() => _selectedDate = candidate);
    await _load(reset: true);
  }

  void _openFriend(String userId) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => FriendProfileScreen(userId: userId),
      ),
    );
  }

  Future<void> _openDetails(FeedPost post) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext context) => _FeedItemDetailsSheet(
        post: post,
        onOpenFriend: () {
          Navigator.of(context).pop();
          _openFriend(post.authorUserId);
        },
        onOpenProof: post.hasProof
            ? () {
                Navigator.of(context).pop();
                _openProof(post);
              }
            : null,
      ),
    );
  }

  Future<void> _openProof(FeedPost post) async {
    if (!post.hasProof) return;
    final bool? markedViewed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => _ProofImageViewer(post: post),
      ),
    );
    if (markedViewed == true && mounted && !post.hasBeenViewed) {
      setState(() {
        final int index = _items.indexWhere(
          (FeedPost item) => item.id == post.id && item.activityType == post.activityType,
        );
        if (index >= 0) {
          _items[index] = _items[index].copyWithViewed();
        }
      });
    }
  }

  String get _dateLabel {
    final DateTime today = utcBusinessDate();
    if (DateUtils.isSameDay(_selectedDate, today)) return 'Today';
    if (DateUtils.isSameDay(_selectedDate, today.subtract(const Duration(days: 1)))) {
      return 'Yesterday';
    }
    return formatDate(_selectedDate);
  }

  List<_FriendFeedGroup> _buildGroups() {
    final Map<String, FriendProgress> progressByUser = <String, FriendProgress>{
      for (final FriendProgress item in _friendProgress) item.userId: item,
    };
    final LinkedHashMap<String, List<FeedPost>> grouped =
        LinkedHashMap<String, List<FeedPost>>();

    for (final FeedPost item in _items) {
      grouped.putIfAbsent(item.authorUserId, () => <FeedPost>[]).add(item);
    }

    final List<_FriendFeedGroup> result = grouped.entries.map(
      (MapEntry<String, List<FeedPost>> entry) {
        final List<FeedPost> tasks = entry.value;
        final FeedPost first = tasks.first;
        final FriendProgress progress = progressByUser[entry.key] ??
            FriendProgress(
              userId: first.authorUserId,
              displayName: first.authorDisplayName,
              avatarUrl: first.authorAvatarUrl,
              completedToday:
                  tasks.where((FeedPost item) => item.isCompleted).length,
              scheduledToday: tasks.length,
              percentage: tasks.isEmpty
                  ? null
                  : ((tasks.where((FeedPost item) => item.isCompleted).length *
                              100) /
                          tasks.length)
                      .round(),
              currentStreak: 0,
            );
        return _FriendFeedGroup(progress: progress, tasks: tasks);
      },
    ).toList();

    result.sort(
      (_FriendFeedGroup left, _FriendFeedGroup right) =>
          right.latestActivityAt.compareTo(left.latestActivityAt),
    );
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final DateTime today = utcBusinessDate();
    final List<_FriendFeedGroup> groups = _buildGroups();
    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            sliver: SliverToBoxAdapter(
              child: _FeedDateSelector(
                label: _dateLabel,
                canGoForward: _selectedDate.isBefore(today),
                onPrevious: () => _moveDate(-1),
                onNext: () => _moveDate(1),
                onPick: _pickDate,
              ),
            ),
          ),
          if (widget.searchController.value.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              sliver: SliverToBoxAdapter(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: InputChip(
                    avatar: const Icon(Icons.search, size: 18),
                    label: Text('Search: ${widget.searchController.value}'),
                    tooltip: 'Clear feed search',
                    onDeleted: widget.searchController.clear,
                  ),
                ),
              ),
            ),
          if (_isInitialLoading)
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 96),
              sliver: SliverToBoxAdapter(child: _FeedLoadingSkeleton()),
            )
          else if (_initialError != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: AppErrorView(
                error: _initialError!,
                onRetry: () => _load(reset: true),
              ),
            )
          else ...<Widget>[
            if (!_hasFriends)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.group_add_outlined,
                  title: 'Add friends to build your feed',
                  message: 'Once you connect, their shared tasks and progress will appear here.',
                ),
              )
            else if (_items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: widget.searchController.hasQuery
                      ? Icons.search_off_outlined
                      : Icons.dynamic_feed_outlined,
                  title: widget.searchController.hasQuery
                      ? 'No matching feed activity'
                      : 'No shared activity for $_dateLabel',
                  message: widget.searchController.hasQuery
                      ? 'No friends or shared tasks match "${widget.searchController.value}" for $_dateLabel.'
                      : 'Your friends have not shared any scheduled or completed tasks for this date.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 16),
                sliver: SliverList.separated(
                  itemCount: groups.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (BuildContext context, int index) {
                    final _FriendFeedGroup group = groups[index];
                    return FriendFeedCard(
                      key: ValueKey<String>(group.progress.userId),
                      progress: group.progress,
                      tasks: group.tasks,
                      onOpenFriend: () => _openFriend(group.progress.userId),
                      onOpenTask: _openDetails,
                      onOpenProof: _openProof,
                    );
                  },
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
              sliver: SliverToBoxAdapter(
                child: _FeedPageFooter(
                  isLoading: _isLoadingMore,
                  error: _loadMoreError,
                  hasMore: _page < _totalPages,
                  onRetry: _loadMore,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

final class _FriendFeedGroup {
  const _FriendFeedGroup({required this.progress, required this.tasks});

  final FriendProgress progress;
  final List<FeedPost> tasks;

  DateTime get latestActivityAt => tasks
      .map((FeedPost item) => item.activityAtUtc)
      .reduce((DateTime current, DateTime next) =>
          next.isAfter(current) ? next : current);
}

final class _FeedDateSelector extends StatelessWidget {
  const _FeedDateSelector({
    required this.label,
    required this.canGoForward,
    required this.onPrevious,
    required this.onNext,
    required this.onPick,
  });

  final String label;
  final bool canGoForward;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          children: <Widget>[
            IconButton(
              tooltip: 'Previous day',
              onPressed: onPrevious,
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onPick,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    children: <Widget>[
                      Text(
                        label,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Friends’ shared progress',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Next day',
              onPressed: canGoForward ? onNext : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    );
  }
}

final class _FeedPageFooter extends StatelessWidget {
  const _FeedPageFooter({
    required this.isLoading,
    required this.error,
    required this.hasMore,
    required this.onRetry,
  });

  final bool isLoading;
  final Object? error;
  final bool hasMore;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry loading more'),
        ),
      );
    }
    if (!hasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            'You’re all caught up',
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
        ),
      );
    }
    return const SizedBox(height: 28);
  }
}

final class _FeedLoadingSkeleton extends StatelessWidget {
  const _FeedLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    final Color color = Theme.of(context).colorScheme.surfaceContainerHighest;
    const Color borderColor = Color(0xFFCAD3D9);
    return Column(
      children: List<Widget>.generate(
        2,
        (int _) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: <Widget>[
                Container(
                  height: 55,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  color: Theme.of(context).colorScheme.surface,
                  child: Row(
                    children: <Widget>[
                      CircleAvatar(backgroundColor: color, radius: 18),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Container(
                              height: 12,
                              width: 130,
                              decoration: _skeletonDecoration(color),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              height: 9,
                              width: 62,
                              decoration: _skeletonDecoration(color),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        height: 14,
                        width: 64,
                        decoration: _skeletonDecoration(color),
                      ),
                    ],
                  ),
                ),
                for (int row = 0; row < 5; row++)
                  Container(
                    height: 44,
                    color: switch (row % 4) {
                      0 => const Color(0xFFF4EAF8),
                      1 => const Color(0xFFE6F8F2),
                      2 => const Color(0xFFFFF3DE),
                      _ => const Color(0xFFEAF4FB),
                    },
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Container(
                            height: 11,
                            width: 180,
                            decoration: _skeletonDecoration(color),
                          ),
                        ),
                        const SizedBox(width: 18),
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static BoxDecoration _skeletonDecoration(Color color) => BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      );
}

final class _FeedItemDetailsSheet extends StatelessWidget {
  const _FeedItemDetailsSheet({
    required this.post,
    required this.onOpenFriend,
    this.onOpenProof,
  });

  final FeedPost post;
  final VoidCallback onOpenFriend;
  final VoidCallback? onOpenProof;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            InkWell(
              onTap: onOpenFriend,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: <Widget>[
                    UserAvatar(
                      displayName: post.authorDisplayName,
                      avatarUrl: post.authorAvatarUrl,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            post.authorDisplayName,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          Text(
                            post.isCompleted
                                ? 'Completed ${formatDateTime(post.activityAtUtc)}'
                                : 'Scheduled ${formatDate(post.occurrenceDate)}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: FeedStatusIndicator(post: post),
            ),
            const SizedBox(height: 18),
            Text(
              post.taskTitle,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            _DetailRow(icon: Icons.category_outlined, label: 'Category', value: post.categoryName),
            _DetailRow(icon: Icons.repeat, label: 'Repeats', value: post.recurrenceName),
            if (post.dueAtUtc != null)
              _DetailRow(
                icon: Icons.event_outlined,
                label: 'Due',
                value: formatDateTime(post.dueAtUtc!),
              ),
            if (post.caption != null) ...<Widget>[
              const SizedBox(height: 16),
              Text('Caption', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 6),
              Text(post.caption!),
            ],
            if (post.hasProof) ...<Widget>[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onOpenProof,
                icon: const Icon(Icons.image_outlined),
                label: Text(post.hasBeenViewed ? 'Open proof image' : 'Open new proof image'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

final class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          SizedBox(width: 72, child: Text(label)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

final class _ProofImageViewer extends ConsumerStatefulWidget {
  const _ProofImageViewer({required this.post});

  final FeedPost post;

  @override
  ConsumerState<_ProofImageViewer> createState() => _ProofImageViewerState();
}

final class _ProofImageViewerState extends ConsumerState<_ProofImageViewer> {
  late final Future<_ProofViewerResult> _future = _load();
  bool _markedViewed = false;

  Future<_ProofViewerResult> _load() async {
    final MediaRepository mediaRepository = ref.read(mediaRepositoryProvider);
    final FeedRepository feedRepository = ref.read(feedRepositoryProvider);
    final Uint8List bytes = await mediaRepository.loadBytes(widget.post.proofUrl!);
    Object? markError;
    if (!widget.post.hasBeenViewed) {
      try {
        await feedRepository.markProofViewed(widget.post.id);
        _markedViewed = true;
      } catch (error) {
        markError = error;
      }
    } else {
      _markedViewed = true;
    }
    return _ProofViewerResult(bytes, markError);
  }

  void _close() => Navigator.of(context).pop<bool>(_markedViewed);

  @override
  Widget build(BuildContext context) {
    return PopScope<bool>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, bool? result) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: FutureBuilder<_ProofViewerResult>(
          future: _future,
          builder: (
            BuildContext context,
            AsyncSnapshot<_ProofViewerResult> snapshot,
          ) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _ProofLoadingView();
            }
            if (snapshot.hasError) {
              return _ProofErrorView(onClose: _close);
            }

            final _ProofViewerResult result = snapshot.data!;
            return Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Center(
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 5,
                    child: Image.memory(
                      result.bytes,
                      fit: BoxFit.contain,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                ),
                const IgnorePointer(child: _ProofViewerGradients()),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Container(
                          height: 3,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: <Widget>[
                            UserAvatar(
                              displayName: widget.post.authorDisplayName,
                              avatarUrl: widget.post.authorAvatarUrl,
                              radius: 18,
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Text(
                                    widget.post.authorDisplayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      shadows: <Shadow>[
                                        Shadow(
                                          color: Colors.black54,
                                          blurRadius: 5,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    formatFeedRelativeTime(
                                      widget.post.activityAtUtc,
                                    ),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      shadows: <Shadow>[
                                        Shadow(
                                          color: Colors.black54,
                                          blurRadius: 5,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Close proof',
                              onPressed: _close,
                              style: IconButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: Colors.black26,
                              ),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                        if (result.markError != null) ...<Widget>[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .errorContainer
                                  .withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'The image opened, but its viewed state could not be saved.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onErrorContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        Text(
                          widget.post.taskTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                            shadows: <Shadow>[
                              Shadow(color: Colors.black87, blurRadius: 8),
                            ],
                          ),
                        ),
                        if (widget.post.caption case final String caption) ...<Widget>[
                          const SizedBox(height: 8),
                          Text(
                            caption,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              height: 1.3,
                              shadows: <Shadow>[
                                Shadow(color: Colors.black87, blurRadius: 8),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: <Widget>[
                            const Icon(
                              Icons.category_outlined,
                              color: Colors.white70,
                              size: 17,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              widget.post.categoryName,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

final class _ProofLoadingView extends StatelessWidget {
  const _ProofLoadingView();

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Column(
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: LinearProgressIndicator(
              minHeight: 3,
              color: Colors.white,
              backgroundColor: Colors.white24,
            ),
          ),
          Expanded(child: Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }
}

final class _ProofErrorView extends StatelessWidget {
  const _ProofErrorView({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.broken_image_outlined,
              color: Colors.white,
              size: 54,
            ),
            const SizedBox(height: 14),
            const Text(
              'The proof image could not be loaded.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onClose,
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}

final class _ProofViewerGradients extends StatelessWidget {
  const _ProofViewerGradients();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          height: 180,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Colors.black87, Colors.transparent],
            ),
          ),
        ),
        const Spacer(),
        Container(
          height: 260,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: <Color>[Colors.black87, Colors.transparent],
            ),
          ),
        ),
      ],
    );
  }
}

final class _ProofViewerResult {
  const _ProofViewerResult(this.bytes, this.markError);

  final Uint8List bytes;
  final Object? markError;
}
