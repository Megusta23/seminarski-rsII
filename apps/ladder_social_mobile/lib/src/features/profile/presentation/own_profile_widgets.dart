import 'package:flutter/material.dart';
import 'package:ladder_social_core/ladder_social_core.dart';
import 'package:ladder_social_mobile/src/core/widgets/mobile_widgets.dart';

typedef OwnProfileThumbnailBuilder = Widget Function(
  BuildContext context,
  HighlightedPost post,
);

final class OwnProfileBody extends StatelessWidget {
  const OwnProfileBody({
    required this.profile,
    required this.onOpenAvatar,
    required this.onOpenPosts,
    required this.onOpenFriends,
    required this.onOpenHighlightedPost,
    this.controller,
    this.highlightThumbnailBuilder,
    this.highlightSectionKey,
    super.key,
  });

  final OwnProfileOverview profile;
  final VoidCallback onOpenAvatar;
  final VoidCallback onOpenPosts;
  final VoidCallback onOpenFriends;
  final ValueChanged<HighlightedPost> onOpenHighlightedPost;
  final ScrollController? controller;
  final OwnProfileThumbnailBuilder? highlightThumbnailBuilder;
  final Key? highlightSectionKey;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('own-profile-body'),
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 118),
      children: <Widget>[
        _ProfileHeader(
          profile: profile,
          onOpenAvatar: onOpenAvatar,
          onOpenPosts: onOpenPosts,
          onOpenFriends: onOpenFriends,
        ),
        const SizedBox(height: 18),
        _BiographySection(profile: profile),
        const SizedBox(height: 22),
        _ProfileStatistics(profile: profile),
        const SizedBox(height: 28),
        _HighlightedPostsSection(
          key: highlightSectionKey,
          posts: profile.highlightedPosts,
          onOpenHighlightedPost: onOpenHighlightedPost,
          thumbnailBuilder: highlightThumbnailBuilder,
        ),
      ],
    );
  }
}

final class OwnProfileLoadingView extends StatelessWidget {
  const OwnProfileLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    final Color fill = Theme.of(context).colorScheme.surfaceContainerHighest;
    return ListView(
      key: const Key('own-profile-loading'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 118),
      children: <Widget>[
        Row(
          children: <Widget>[
            CircleAvatar(radius: 44, backgroundColor: fill),
            const SizedBox(width: 24),
            for (int index = 0; index < 2; index++) ...<Widget>[
              Expanded(
                child: Column(
                  children: <Widget>[
                    Container(height: 22, width: 44, color: fill),
                    const SizedBox(height: 7),
                    Container(height: 13, width: 56, color: fill),
                  ],
                ),
              ),
              if (index == 0) const SizedBox(width: 20),
            ],
          ],
        ),
        const SizedBox(height: 24),
        Container(height: 18, width: 180, color: fill),
        const SizedBox(height: 10),
        Container(height: 14, width: double.infinity, color: fill),
        const SizedBox(height: 8),
        Container(height: 14, width: 230, color: fill),
        const SizedBox(height: 26),
        Row(
          children: <Widget>[
            for (int index = 0; index < 3; index++) ...<Widget>[
              Expanded(
                child: Container(
                  height: 102,
                  decoration: BoxDecoration(
                    color: fill,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              if (index < 2) const SizedBox(width: 10),
            ],
          ],
        ),
        const SizedBox(height: 30),
        Container(height: 20, width: 150, color: fill),
        const SizedBox(height: 14),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          children: List<Widget>.generate(
            6,
            (_) => DecoratedBox(
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

final class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.profile,
    required this.onOpenAvatar,
    required this.onOpenPosts,
    required this.onOpenFriends,
  });

  final OwnProfileOverview profile;
  final VoidCallback onOpenAvatar;
  final VoidCallback onOpenPosts;
  final VoidCallback onOpenFriends;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Semantics(
          button: true,
          label: 'Profile picture for ${profile.displayName}',
          child: InkResponse(
            key: const Key('own-profile-avatar'),
            onTap: onOpenAvatar,
            radius: 50,
            child: UserAvatar(
              displayName: profile.displayName,
              avatarUrl: profile.avatarUrl,
              radius: 44,
            ),
          ),
        ),
        const SizedBox(width: 26),
        Expanded(
          child: Row(
            children: <Widget>[
              Expanded(
                child: _CountButton(
                  key: const Key('own-profile-post-count'),
                  value: profile.visiblePostCount,
                  label: 'Posts',
                  onTap: onOpenPosts,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CountButton(
                  key: const Key('own-profile-friend-count'),
                  value: profile.friendCount,
                  label: 'Friends',
                  onTap: onOpenFriends,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

final class _CountButton extends StatelessWidget {
  const _CountButton({
    required this.value,
    required this.label,
    required this.onTap,
    super.key,
  });

  final int value;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$value ${label.toLowerCase()}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$value',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _BiographySection extends StatelessWidget {
  const _BiographySection({required this.profile});

  final OwnProfileOverview profile;

  @override
  Widget build(BuildContext context) {
    final bool hasBio = profile.bio?.trim().isNotEmpty == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          profile.displayName,
          key: const Key('own-profile-display-name'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 5),
        Text(
          hasBio ? profile.bio! : 'Add a biography from Profile settings.',
          key: const Key('own-profile-bio'),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                height: 1.35,
                color: hasBio ? null : Theme.of(context).colorScheme.outline,
              ),
        ),
        if (profile.cityName?.trim().isNotEmpty == true) ...<Widget>[
          const SizedBox(height: 9),
          Row(
            children: <Widget>[
              Icon(
                Icons.location_on_outlined,
                size: 17,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  profile.cityName!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 7),
        Text(
          'Member since ${formatDate(profile.memberSinceUtc)}',
          key: const Key('own-profile-member-since'),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
        ),
      ],
    );
  }
}

final class _ProfileStatistics extends StatelessWidget {
  const _ProfileStatistics({required this.profile});

  final OwnProfileOverview profile;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('own-profile-statistics'),
      height: 118,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: _StatisticCard(
              value: profile.currentStreak,
              label: 'Streak',
              semanticsLabel: '${profile.currentStreak}-day streak',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: _StatisticCard(
              value: profile.completedTaskCount,
              label: 'Tasks completed',
              semanticsLabel: '${profile.completedTaskCount} completed tasks',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatisticCard(
              value: profile.habitCount,
              label: 'Habits',
              semanticsLabel: '${profile.habitCount} active habits',
            ),
          ),
        ],
      ),
    );
  }
}

final class _StatisticCard extends StatelessWidget {
  const _StatisticCard({
    required this.value,
    required this.label,
    required this.semanticsLabel,
  });

  final int value;
  final String label;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
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
            const SizedBox(height: 5),
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
      ),
    );
  }
}

final class _HighlightedPostsSection extends StatelessWidget {
  const _HighlightedPostsSection({
    required this.posts,
    required this.onOpenHighlightedPost,
    this.thumbnailBuilder,
    super.key,
  });

  final List<HighlightedPost> posts;
  final ValueChanged<HighlightedPost> onOpenHighlightedPost;
  final OwnProfileThumbnailBuilder? thumbnailBuilder;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Highlighted posts',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 10),
        if (posts.isEmpty)
          const _EmptyHighlights()
        else
          GridView.builder(
            key: const Key('own-profile-highlight-grid'),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: posts.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 1,
            ),
            itemBuilder: (BuildContext context, int index) {
              final HighlightedPost post = posts[index];
              final Widget thumbnail = thumbnailBuilder?.call(context, post) ??
                  ProtectedImage(path: post.proofUrl, fit: BoxFit.cover);
              return Semantics(
                button: true,
                label: 'Open highlighted task ${post.taskTitle}',
                child: InkWell(
                  key: Key('own-highlight-${post.postId}'),
                  onTap: () => onOpenHighlightedPost(post),
                  borderRadius: BorderRadius.circular(6),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: thumbnail,
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

final class _EmptyHighlights extends StatelessWidget {
  const _EmptyHighlights();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('own-profile-empty-highlights'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        children: <Widget>[
          Icon(
            Icons.photo_library_outlined,
            size: 40,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 10),
          const Text(
            'No highlighted tasks yet.',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          Text(
            'Use Profile settings to feature completed tasks with proof.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
        ],
      ),
    );
  }
}
