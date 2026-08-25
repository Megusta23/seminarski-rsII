import 'package:flutter/material.dart';
import 'package:ladder_social_core/ladder_social_core.dart';
import 'package:ladder_social_mobile/src/core/widgets/mobile_widgets.dart';

typedef HighlightThumbnailBuilder = Widget Function(
  BuildContext context,
  HighlightedPost post,
);

final class FriendProfileBody extends StatelessWidget {
  const FriendProfileBody({
    required this.profile,
    required this.onMessage,
    required this.onFriendship,
    required this.onOpenMutualFriends,
    required this.onOpenMutualFriend,
    required this.onOpenHighlightedPost,
    this.highlightThumbnailBuilder,
    super.key,
  });

  final FriendProfile profile;
  final VoidCallback? onMessage;
  final VoidCallback onFriendship;
  final VoidCallback? onOpenMutualFriends;
  final ValueChanged<MutualFriend> onOpenMutualFriend;
  final ValueChanged<HighlightedPost> onOpenHighlightedPost;
  final HighlightThumbnailBuilder? highlightThumbnailBuilder;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
      children: <Widget>[
        _ProfileOverview(profile: profile),
        const SizedBox(height: 18),
        Text(
          profile.bio?.trim().isNotEmpty == true
              ? profile.bio!
              : 'No biography added yet.',
          key: const Key('friend-profile-bio'),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                height: 1.35,
                color: profile.bio?.trim().isNotEmpty == true
                    ? null
                    : Theme.of(context).colorScheme.outline,
              ),
        ),
        const SizedBox(height: 16),
        _MutualFriendsPreview(
          mutualFriends: profile.mutualFriends,
          onOpenAll: onOpenMutualFriends,
          onOpenFriend: onOpenMutualFriend,
        ),
        const SizedBox(height: 18),
        _ProfileActions(
          onFriendship: onFriendship,
          onMessage: onMessage,
        ),
        const SizedBox(height: 22),
        _ProfileStatistics(profile: profile),
        const SizedBox(height: 28),
        Text(
          'Highlighted posts',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 12),
        _HighlightedPostsPanel(
          posts: profile.highlightedPosts,
          thumbnailBuilder: highlightThumbnailBuilder,
          onOpenHighlightedPost: onOpenHighlightedPost,
        ),
      ],
    );
  }
}

final class _ProfileOverview extends StatelessWidget {
  const _ProfileOverview({required this.profile});

  final FriendProfile profile;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        UserAvatar(
          displayName: profile.displayName,
          avatarUrl: profile.avatarUrl,
          radius: 36,
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                profile.displayName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 7),
              Row(
                children: <Widget>[
                  _CompactCount(
                    value: profile.visiblePostCount,
                    label: 'posts',
                  ),
                  const SizedBox(width: 28),
                  _CompactCount(
                    value: profile.friendCount,
                    label: 'friends',
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

final class _CompactCount extends StatelessWidget {
  const _CompactCount({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '$value',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.1),
        ),
      ],
    );
  }
}

final class _MutualFriendsPreview extends StatelessWidget {
  const _MutualFriendsPreview({
    required this.mutualFriends,
    required this.onOpenAll,
    required this.onOpenFriend,
  });

  final MutualFriends mutualFriends;
  final VoidCallback? onOpenAll;
  final ValueChanged<MutualFriend> onOpenFriend;

  @override
  Widget build(BuildContext context) {
    if (mutualFriends.count == 0) {
      return Text(
        'No mutual friends yet.',
        key: const Key('no-mutual-friends'),
        style: TextStyle(color: Theme.of(context).colorScheme.outline),
      );
    }

    final List<MutualFriend> preview =
        mutualFriends.items.take(4).toList(growable: false);
    final int overlapCount = (preview.length - 1).clamp(0, 3).toInt();
    return InkWell(
      key: const Key('mutual-friends-preview'),
      borderRadius: BorderRadius.circular(12),
      onTap: onOpenAll,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: <Widget>[
            Text(
              'Mutual friends:',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 24.0 + (overlapCount * 19.0),
              height: 34,
              child: Stack(
                children: <Widget>[
                  for (int index = 0; index < preview.length; index++)
                    Positioned(
                      left: index * 19,
                      child: GestureDetector(
                        onTap: () => onOpenFriend(preview[index]),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).colorScheme.surface,
                              width: 2,
                            ),
                          ),
                          child: UserAvatar(
                            displayName: preview[index].displayName,
                            avatarUrl: preview[index].avatarUrl,
                            radius: 15,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                mutualFriends.count > preview.length
                    ? '+${mutualFriends.count - preview.length}'
                    : '',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.outline,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _ProfileActions extends StatelessWidget {
  const _ProfileActions({
    required this.onFriendship,
    required this.onMessage,
  });

  final VoidCallback onFriendship;
  final VoidCallback? onMessage;

  @override
  Widget build(BuildContext context) {
    final ButtonStyle style = FilledButton.styleFrom(
      foregroundColor: Theme.of(context).colorScheme.onSurface,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      disabledBackgroundColor:
          Theme.of(context).colorScheme.surfaceContainerHighest,
      disabledForegroundColor:
          Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    );
    return Row(
      children: <Widget>[
        Expanded(
          child: FilledButton(
            key: const Key('friendship-button'),
            onPressed: onFriendship,
            style: style,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text('Friends'),
                SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down, size: 19),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton(
            key: const Key('message-button'),
            onPressed: onMessage,
            style: style,
            child: const Text('Message'),
          ),
        ),
      ],
    );
  }
}

final class _ProfileStatistics extends StatelessWidget {
  const _ProfileStatistics({required this.profile});

  final FriendProfile profile;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('friend-profile-statistics'),
      height: 108,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            flex: 10,
            child: _StatisticCard(
              value: profile.currentStreak,
              label: 'Streak',
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 20,
            child: _StatisticCard(
              value: profile.completedTaskCount,
              label: 'Tasks completed',
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 10,
            child: _StatisticCard(
              value: profile.habitCount,
              label: 'Habits',
            ),
          ),
        ],
      ),
    );
  }
}

final class _StatisticCard extends StatelessWidget {
  const _StatisticCard({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 106),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 1.4,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$value',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          const SizedBox(height: 6),
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

final class _HighlightedPostsPanel extends StatelessWidget {
  const _HighlightedPostsPanel({
    required this.posts,
    required this.onOpenHighlightedPost,
    this.thumbnailBuilder,
  });

  final List<HighlightedPost> posts;
  final ValueChanged<HighlightedPost> onOpenHighlightedPost;
  final HighlightThumbnailBuilder? thumbnailBuilder;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('highlighted-posts-panel'),
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 250),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 1.4,
        ),
      ),
      child: posts.isEmpty
          ? const _EmptyHighlights()
          : GridView.builder(
              key: const Key('highlighted-posts-grid'),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: posts.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.72,
              ),
              itemBuilder: (BuildContext context, int index) {
                final HighlightedPost post = posts[index];
                return _HighlightedPostTile(
                  post: post,
                  thumbnailBuilder: thumbnailBuilder,
                  onTap: () => onOpenHighlightedPost(post),
                );
              },
            ),
    );
  }
}

final class _HighlightedPostTile extends StatelessWidget {
  const _HighlightedPostTile({
    required this.post,
    required this.onTap,
    this.thumbnailBuilder,
  });

  final HighlightedPost post;
  final VoidCallback onTap;
  final HighlightThumbnailBuilder? thumbnailBuilder;

  @override
  Widget build(BuildContext context) {
    final Widget thumbnail = thumbnailBuilder?.call(context, post) ??
        ProtectedImage(
          path: post.proofUrl,
          fit: BoxFit.cover,
        );
    return Semantics(
      button: true,
      label: 'Open highlighted task ${post.taskTitle}',
      child: InkWell(
        key: Key('highlight-post-${post.postId}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: thumbnail,
        ),
      ),
    );
  }
}

final class _EmptyHighlights extends StatelessWidget {
  const _EmptyHighlights();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        key: const Key('empty-highlighted-posts'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.photo_library_outlined,
              size: 38,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 10),
            const Text(
              'No highlighted tasks yet.',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Completed tasks with proof can be featured here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}
