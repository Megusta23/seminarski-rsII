import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ladder_social_core/ladder_social_core.dart';
import 'package:ladder_social_mobile/src/core/providers/core_providers.dart';
import 'package:ladder_social_mobile/src/core/widgets/mobile_widgets.dart';
import 'package:ladder_social_mobile/src/features/friends/presentation/profile_proof_viewer_screen.dart';
import 'package:ladder_social_mobile/src/features/profile/presentation/own_profile_widgets.dart';
import 'package:ladder_social_mobile/src/features/profile/presentation/profile_avatar_viewer_screen.dart';

final class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({required this.onOpenFriends, super.key});

  final VoidCallback onOpenFriends;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

final class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _highlightSectionKey = GlobalKey();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(currentProfileProvider);
    ref.invalidate(ownProfileOverviewProvider);
    await ref.read(ownProfileOverviewProvider.future);
  }

  void _openPosts() {
    final BuildContext? sectionContext = _highlightSectionKey.currentContext;
    if (sectionContext == null) {
      return;
    }
    Scrollable.ensureVisible(
      sectionContext,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      alignment: 0.05,
    );
  }

  void _openAvatar(OwnProfileOverview profile) {
    final String? avatarUrl = profile.avatarUrl;
    if (avatarUrl == null || avatarUrl.isEmpty) {
      showMessage(
        context,
        'Use Profile settings to add a profile picture.',
      );
      return;
    }

    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ProfileAvatarViewerScreen(
          displayName: profile.displayName,
          avatarUrl: avatarUrl,
        ),
      ),
    );
  }

  void _openHighlightedPost(
    OwnProfileOverview profile,
    HighlightedPost post,
  ) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ProfileProofViewerScreen(
          post: post,
          ownerDisplayName: profile.displayName,
          ownerAvatarUrl: profile.avatarUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<OwnProfileOverview> overview =
        ref.watch(ownProfileOverviewProvider);

    return overview.when(
      loading: () => const OwnProfileLoadingView(),
      error: (Object error, StackTrace stackTrace) => AppErrorView(
        error: error,
        onRetry: () => ref.invalidate(ownProfileOverviewProvider),
      ),
      data: (OwnProfileOverview profile) => RefreshIndicator(
        onRefresh: _refresh,
        child: OwnProfileBody(
          profile: profile,
          controller: _scrollController,
          highlightSectionKey: _highlightSectionKey,
          onOpenAvatar: () => _openAvatar(profile),
          onOpenPosts: _openPosts,
          onOpenFriends: widget.onOpenFriends,
          onOpenHighlightedPost: (HighlightedPost post) =>
              _openHighlightedPost(profile, post),
        ),
      ),
    );
  }
}
