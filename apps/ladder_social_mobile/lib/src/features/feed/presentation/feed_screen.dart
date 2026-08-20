import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ladder_social_core/ladder_social_core.dart';
import 'package:ladder_social_mobile/src/core/providers/core_providers.dart';
import 'package:ladder_social_mobile/src/core/widgets/mobile_widgets.dart';
import 'package:ladder_social_mobile/src/features/friends/presentation/friend_profile_screen.dart';

final class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

final class _FeedScreenState extends ConsumerState<FeedScreen> {
  final TextEditingController _searchController = TextEditingController();
  Future<PagedResult<FeedPost>>? _future;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _load({int? page}) {
    final int target = page ?? _page;
    setState(() {
      _page = target;
      _future = ref.read(feedRepositoryProvider).getFeed(
            search: _searchController.text,
            page: target,
          );
    });
  }

  Future<void> _view(FeedPost post) async {
    if (!post.hasBeenViewed) {
      try {
        await ref.read(feedRepositoryProvider).markViewed(post.id);
      } catch (_) {
        // Viewing a post must not be blocked by a read-receipt failure.
      }
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext context) => _FeedPostDetails(post: post),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => _load(page: 1),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            sliver: SliverToBoxAdapter(
              child: SearchBar(
                controller: _searchController,
                hintText: 'Search shared tasks',
                leading: const Icon(Icons.search),
                trailing: <Widget>[
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      onPressed: () {
                        _searchController.clear();
                        _load(page: 1);
                      },
                      icon: const Icon(Icons.clear),
                    ),
                ],
                onSubmitted: (_) => _load(page: 1),
              ),
            ),
          ),
          FutureBuilder<PagedResult<FeedPost>>(
            future: _future,
            builder: (
              BuildContext context,
              AsyncSnapshot<PagedResult<FeedPost>> snapshot,
            ) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return SliverFillRemaining(
                  child: AppErrorView(error: snapshot.error!, onRetry: _load),
                );
              }
              final PagedResult<FeedPost> result = snapshot.data!;
              if (result.items.isEmpty) {
                return const SliverFillRemaining(
                  child: EmptyState(
                    icon: Icons.dynamic_feed_outlined,
                    title: 'Your feed is quiet',
                    message: 'Complete a shared task or add friends to see progress here.',
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                sliver: SliverList.separated(
                  itemCount: result.items.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (BuildContext context, int index) {
                    if (index == result.items.length) {
                      return _PageControls(
                        page: result.page,
                        totalPages: result.totalPages,
                        onPrevious: result.page > 1
                            ? () => _load(page: result.page - 1)
                            : null,
                        onNext: result.page < result.totalPages
                            ? () => _load(page: result.page + 1)
                            : null,
                      );
                    }
                    final FeedPost post = result.items[index];
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => _view(post),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            ListTile(
                              leading: UserAvatar(
                                displayName: post.authorDisplayName,
                                avatarUrl: post.authorAvatarUrl,
                              ),
                              title: Text(post.authorDisplayName),
                              subtitle: Text(formatDateTime(post.completedAtUtc)),
                              trailing: post.hasBeenViewed
                                  ? const Icon(Icons.visibility_outlined, size: 18)
                                  : Icon(
                                      Icons.fiber_new,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                              onTap: () => Navigator.of(context).push<void>(
                                MaterialPageRoute<void>(
                                  builder: (_) => FriendProfileScreen(
                                    userId: post.authorUserId,
                                  ),
                                ),
                              ),
                            ),
                            if (post.proofUrl != null)
                              AspectRatio(
                                aspectRatio: 4 / 3,
                                child: ProtectedImage(path: post.proofUrl!),
                              ),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    post.taskTitle,
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 6),
                                  Chip(
                                    avatar: const Icon(Icons.category_outlined, size: 16),
                                    label: Text(post.categoryName),
                                  ),
                                  if (post.caption != null) ...<Widget>[
                                    const SizedBox(height: 8),
                                    Text(post.caption!),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

final class _FeedPostDetails extends StatelessWidget {
  const _FeedPostDetails({required this.post});
  final FeedPost post;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
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
                      Text(post.authorDisplayName,
                          style: Theme.of(context).textTheme.titleMedium),
                      Text(formatDateTime(post.completedAtUtc)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(post.taskTitle, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(post.categoryName),
            if (post.caption != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(post.caption!),
            ],
            if (post.proofUrl != null) ...<Widget>[
              const SizedBox(height: 18),
              ProtectedImage(
                path: post.proofUrl!,
                borderRadius: BorderRadius.circular(16),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

final class _PageControls extends StatelessWidget {
  const _PageControls({
    required this.page,
    required this.totalPages,
    this.onPrevious,
    this.onNext,
  });
  final int page;
  final int totalPages;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        IconButton(onPressed: onPrevious, icon: const Icon(Icons.chevron_left)),
        Text('Page $page of ${totalPages == 0 ? 1 : totalPages}'),
        IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
      ],
    );
  }
}
