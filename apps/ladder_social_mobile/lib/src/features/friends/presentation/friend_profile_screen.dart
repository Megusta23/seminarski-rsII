import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ladder_social_core/ladder_social_core.dart';
import 'package:ladder_social_mobile/src/core/providers/core_providers.dart';
import 'package:ladder_social_mobile/src/core/widgets/mobile_widgets.dart';
import 'package:ladder_social_mobile/src/features/chat/presentation/chat_screen.dart';
import 'package:ladder_social_mobile/src/features/friends/presentation/friend_profile_widgets.dart';
import 'package:ladder_social_mobile/src/features/friends/presentation/profile_proof_viewer_screen.dart';

final class FriendProfileScreen extends ConsumerStatefulWidget {
  const FriendProfileScreen({required this.userId, super.key});

  final String userId;

  @override
  ConsumerState<FriendProfileScreen> createState() =>
      _FriendProfileScreenState();
}

final class _FriendProfileScreenState
    extends ConsumerState<FriendProfileScreen> {
  late Future<FriendProfile> _future;
  FriendProfile? _loadedProfile;
  bool _startingChat = false;
  bool _removingFriend = false;

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  Future<FriendProfile> _fetch() async {
    final FriendProfile profile =
        await ref.read(friendRepositoryProvider).getProfile(widget.userId);
    if (mounted) {
      setState(() => _loadedProfile = profile);
    } else {
      _loadedProfile = profile;
    }
    return profile;
  }

  Future<void> _refresh() async {
    final Future<FriendProfile> future = _fetch();
    setState(() => _future = future);
    await future;
  }

  void _retry() {
    setState(() => _future = _fetch());
  }

  Future<void> _message() async {
    if (_startingChat || _loadedProfile?.canMessage != true) return;
    setState(() => _startingChat = true);
    try {
      final ConversationItem conversation = await ref
          .read(chatRepositoryProvider)
          .startDirectConversation(widget.userId);
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ChatScreen(conversation: conversation),
        ),
      );
    } catch (error) {
      if (mounted) {
        showMessage(context, ApiException.from(error).message, error: true);
      }
    } finally {
      if (mounted) setState(() => _startingChat = false);
    }
  }

  Future<void> _confirmRemove(FriendProfile profile) async {
    if (_removingFriend) return;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Remove friend?'),
        content: Text(
          'Remove ${profile.displayName}? You will immediately lose access to each other’s feed, friend profile, and protected proof images.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove friend'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _removingFriend = true);
    try {
      await ref.read(friendRepositoryProvider).removeFriend(widget.userId);
      if (!mounted) return;
      Navigator.of(context).pop<bool>(true);
    } catch (error) {
      if (mounted) {
        showMessage(context, ApiException.from(error).message, error: true);
      }
    } finally {
      if (mounted) setState(() => _removingFriend = false);
    }
  }

  Future<void> _showFriendshipActions(FriendProfile profile) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.people_outline),
                title: const Text('You are friends'),
                subtitle: Text(profile.displayName),
              ),
              ListTile(
                key: const Key('remove-friend-action'),
                leading: Icon(
                  Icons.person_remove_outlined,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  'Remove friend',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _confirmRemove(profile);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showMutualFriends(FriendProfile profile) async {
    if (profile.mutualFriends.count == 0) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.62,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Mutual friends',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        profile.mutualFriends.items.length <
                                profile.mutualFriends.count
                            ? 'Showing ${profile.mutualFriends.items.length} of ${profile.mutualFriends.count}'
                            : '${profile.mutualFriends.count} mutual friend${profile.mutualFriends.count == 1 ? '' : 's'}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: profile.mutualFriends.items.length,
                  itemBuilder: (BuildContext context, int index) {
                    final MutualFriend friend =
                        profile.mutualFriends.items[index];
                    return ListTile(
                      leading: UserAvatar(
                        displayName: friend.displayName,
                        avatarUrl: friend.avatarUrl,
                      ),
                      title: Text(friend.displayName),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        _openMutualFriend(friend);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openMutualFriend(MutualFriend friend) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => FriendProfileScreen(userId: friend.userId),
      ),
    );
  }

  void _openHighlightedPost(FriendProfile profile, HighlightedPost post) {
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_loadedProfile?.displayName ?? 'Friend profile'),
        actions: <Widget>[
          if (_loadedProfile case final FriendProfile profile)
            PopupMenuButton<String>(
              tooltip: 'Profile actions',
              onSelected: (String value) {
                if (value == 'remove') _confirmRemove(profile);
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'remove',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.person_remove_outlined),
                    title: Text('Remove friend'),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: FutureBuilder<FriendProfile>(
        future: _future,
        builder: (
          BuildContext context,
          AsyncSnapshot<FriendProfile> snapshot,
        ) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final ApiException error = ApiException.from(snapshot.error!);
            if (error.statusCode == 404) {
              return const EmptyState(
                icon: Icons.person_off_outlined,
                title: 'Profile unavailable',
                message:
                    'This profile is inactive or you are no longer friends.',
              );
            }
            return AppErrorView(error: error, onRetry: _retry);
          }

          final FriendProfile profile = snapshot.data!;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: FriendProfileBody(
              profile: profile,
              onMessage: _startingChat || !profile.canMessage ? null : _message,
              onFriendship: () => _showFriendshipActions(profile),
              onOpenMutualFriends: profile.mutualFriends.count == 0
                  ? null
                  : () => _showMutualFriends(profile),
              onOpenMutualFriend: _openMutualFriend,
              onOpenHighlightedPost: (HighlightedPost post) =>
                  _openHighlightedPost(profile, post),
            ),
          );
        },
      ),
    );
  }
}
