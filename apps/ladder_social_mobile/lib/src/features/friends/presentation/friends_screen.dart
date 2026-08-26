import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ladder_social_core/ladder_social_core.dart';
import 'package:ladder_social_mobile/src/core/providers/core_providers.dart';
import 'package:ladder_social_mobile/src/core/widgets/mobile_widgets.dart';
import 'package:ladder_social_mobile/src/features/chat/presentation/chat_screen.dart';
import 'package:ladder_social_mobile/src/features/friends/presentation/friend_profile_screen.dart';
import 'package:ladder_social_mobile/src/features/friends/presentation/friends_screen_controller.dart';
import 'package:ladder_social_mobile/src/features/friends/presentation/friends_widgets.dart';
import 'package:ladder_social_mobile/src/features/friends/presentation/people_search_screen.dart';

final class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({required this.controller, super.key});

  final FriendsScreenController controller;

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

final class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  final Set<String> _processingRequestIds = <String>{};
  final Set<String> _processingRecommendationIds = <String>{};
  final Set<String> _removingFriendIds = <String>{};
  final Set<String> _messagingFriendIds = <String>{};

  final List<FriendSummary> _friends = <FriendSummary>[];
  final List<FriendRequestItem> _incoming = <FriendRequestItem>[];
  final List<FriendRequestItem> _outgoing = <FriendRequestItem>[];
  final List<FriendRecommendation> _recommendations =
      <FriendRecommendation>[];

  FriendsSection _selectedSection = FriendsSection.friends;
  Object? _loadError;
  bool _isInitialLoading = true;
  int _loadVersion = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleExternalRefresh);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadAll(showLoading: true);
      }
    });
  }

  @override
  void didUpdateWidget(covariant FriendsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) {
      return;
    }
    oldWidget.controller.removeListener(_handleExternalRefresh);
    widget.controller.addListener(_handleExternalRefresh);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleExternalRefresh);
    super.dispose();
  }

  void _handleExternalRefresh() {
    final FriendsSection? requested = widget.controller.takeRequestedSection();
    if (requested != null && requested != _selectedSection && mounted) {
      setState(() {
        _selectedSection = requested;
      });
    }
    _loadAll();
  }

  Future<_FriendsSnapshot> _fetchSnapshot() async {
    final FriendRepository repository = ref.read(friendRepositoryProvider);
    final Future<PagedResult<FriendSummary>> friendsFuture =
        repository.getFriends(pageSize: 100);
    final Future<PagedResult<FriendRequestItem>> incomingFuture =
        repository.getIncomingRequests(pageSize: 100);
    final Future<PagedResult<FriendRequestItem>> outgoingFuture =
        repository.getOutgoingRequests(pageSize: 100);
    final Future<List<FriendRecommendation>> recommendationsFuture =
        repository.getRecommendations();

    final PagedResult<FriendSummary> friends = await friendsFuture;
    final PagedResult<FriendRequestItem> incoming = await incomingFuture;
    final PagedResult<FriendRequestItem> outgoing = await outgoingFuture;
    final List<FriendRecommendation> recommendations =
        await recommendationsFuture;

    return _FriendsSnapshot(
      friends: friends.items,
      incoming: incoming.items,
      outgoing: outgoing.items,
      recommendations: recommendations,
    );
  }

  Future<void> _loadAll({bool showLoading = false}) async {
    final int version = ++_loadVersion;
    if (showLoading && mounted) {
      setState(() {
        _isInitialLoading = true;
        _loadError = null;
      });
    }

    try {
      final _FriendsSnapshot snapshot = await _fetchSnapshot();
      if (!mounted || version != _loadVersion) {
        return;
      }
      setState(() {
        _friends
          ..clear()
          ..addAll(snapshot.friends);
        _incoming
          ..clear()
          ..addAll(snapshot.incoming);
        _outgoing
          ..clear()
          ..addAll(snapshot.outgoing);
        _recommendations
          ..clear()
          ..addAll(snapshot.recommendations);
        _isInitialLoading = false;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted || version != _loadVersion) {
        return;
      }
      setState(() {
        _isInitialLoading = false;
        _loadError = error;
      });
    }
  }

  void _invalidateRelatedState() {
    ref.invalidate(notificationSummaryProvider);
  }

  void _setRequestProcessing(String requestId, bool processing) {
    if (!mounted) {
      return;
    }
    setState(() {
      if (processing) {
        _processingRequestIds.add(requestId);
      } else {
        _processingRequestIds.remove(requestId);
      }
    });
  }

  void _setProcessing(
    Set<String> ids,
    String id,
    bool processing,
  ) {
    if (!mounted) {
      return;
    }
    setState(() {
      if (processing) {
        ids.add(id);
      } else {
        ids.remove(id);
      }
    });
  }

  Future<void> _acceptRequest(FriendRequestItem request) async {
    if (_processingRequestIds.contains(request.id)) {
      return;
    }
    _setRequestProcessing(request.id, true);
    try {
      await ref.read(friendRepositoryProvider).acceptRequest(request.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _incoming.removeWhere(
          (FriendRequestItem item) => item.id == request.id,
        );
        if (_friends.every(
          (FriendSummary item) => item.userId != request.senderUserId,
        )) {
          _friends.insert(
            0,
            FriendSummary(
              userId: request.senderUserId,
              displayName: request.senderDisplayName,
              avatarUrl: request.senderAvatarUrl,
              mutualFriendCount: 0,
              completedTaskCount: 0,
              currentStreak: 0,
            ),
          );
        }
      });
      _invalidateRelatedState();
      showMessage(
        context,
        'You and ${request.senderDisplayName} are now friends.',
      );
      await _loadAll();
    } catch (error) {
      if (mounted) {
        showMessage(context, ApiException.from(error).message, error: true);
      }
    } finally {
      _setRequestProcessing(request.id, false);
    }
  }

  Future<void> _rejectRequest(FriendRequestItem request) async {
    if (_processingRequestIds.contains(request.id)) {
      return;
    }
    _setRequestProcessing(request.id, true);
    try {
      await ref.read(friendRepositoryProvider).rejectRequest(request.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _incoming.removeWhere(
          (FriendRequestItem item) => item.id == request.id,
        );
      });
      _invalidateRelatedState();
      showMessage(context, 'Friend request declined.');
      await _loadAll();
    } catch (error) {
      if (mounted) {
        showMessage(context, ApiException.from(error).message, error: true);
      }
    } finally {
      _setRequestProcessing(request.id, false);
    }
  }

  Future<void> _cancelRequest(FriendRequestItem request) async {
    if (_processingRequestIds.contains(request.id)) {
      return;
    }
    _setRequestProcessing(request.id, true);
    try {
      await ref.read(friendRepositoryProvider).cancelRequest(request.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _outgoing.removeWhere(
          (FriendRequestItem item) => item.id == request.id,
        );
      });
      _invalidateRelatedState();
      showMessage(context, 'Friend request cancelled.');
      await _loadAll();
    } catch (error) {
      if (mounted) {
        showMessage(context, ApiException.from(error).message, error: true);
      }
    } finally {
      _setRequestProcessing(request.id, false);
    }
  }

  Future<void> _sendRecommendation(
    FriendRecommendation recommendation,
  ) async {
    if (_processingRecommendationIds.contains(recommendation.userId)) {
      return;
    }
    _setProcessing(
      _processingRecommendationIds,
      recommendation.userId,
      true,
    );
    try {
      final FriendRequestItem request = await ref
          .read(friendRepositoryProvider)
          .sendRequest(recommendation.userId);
      if (!mounted) {
        return;
      }
      setState(() {
        _recommendations.removeWhere(
          (FriendRecommendation item) =>
              item.userId == recommendation.userId,
        );
        if (_outgoing.every(
          (FriendRequestItem item) => item.id != request.id,
        )) {
          _outgoing.insert(0, request);
        }
      });
      _invalidateRelatedState();
      showMessage(context, 'Friend request sent.');
      await _loadAll();
    } catch (error) {
      if (mounted) {
        showMessage(context, ApiException.from(error).message, error: true);
      }
    } finally {
      _setProcessing(
        _processingRecommendationIds,
        recommendation.userId,
        false,
      );
    }
  }

  Future<void> _openFriend(FriendSummary friend) async {
    final bool? removed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => FriendProfileScreen(userId: friend.userId),
      ),
    );
    if (removed == true && mounted) {
      setState(() {
        _friends.removeWhere(
          (FriendSummary item) => item.userId == friend.userId,
        );
      });
      await _loadAll();
    }
  }

  Future<void> _messageFriend(FriendSummary friend) async {
    if (_messagingFriendIds.contains(friend.userId) ||
        _removingFriendIds.contains(friend.userId)) {
      return;
    }
    _setProcessing(_messagingFriendIds, friend.userId, true);
    try {
      final ConversationItem conversation = await ref
          .read(chatRepositoryProvider)
          .startDirectConversation(friend.userId);
      if (!mounted) {
        return;
      }
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
      _setProcessing(_messagingFriendIds, friend.userId, false);
    }
  }

  Future<void> _confirmRemoveFriend(FriendSummary friend) async {
    if (_removingFriendIds.contains(friend.userId) ||
        _messagingFriendIds.contains(friend.userId)) {
      return;
    }
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Remove friend?'),
        content: Text(
          'Remove ${friend.displayName}? Their shared tasks, profile, proof images, and leaderboard position will no longer be available to you.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove friend'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    _setProcessing(_removingFriendIds, friend.userId, true);
    try {
      await ref.read(friendRepositoryProvider).removeFriend(friend.userId);
      if (!mounted) {
        return;
      }
      setState(() {
        _friends.removeWhere(
          (FriendSummary item) => item.userId == friend.userId,
        );
      });
      _invalidateRelatedState();
      showMessage(context, '${friend.displayName} was removed.');
      await _loadAll();
    } catch (error) {
      if (mounted) {
        showMessage(context, ApiException.from(error).message, error: true);
      }
    } finally {
      _setProcessing(_removingFriendIds, friend.userId, false);
    }
  }

  Future<void> _openPeopleSearch() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PeopleSearchScreen(controller: widget.controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasContent = _friends.isNotEmpty ||
        _incoming.isNotEmpty ||
        _outgoing.isNotEmpty ||
        _recommendations.isNotEmpty;
    if (_isInitialLoading && !hasContent) {
      return const FriendsSurface(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: FriendsLoadingList(count: 4),
        ),
      );
    }
    if (_loadError != null && !hasContent) {
      return FriendsSurface(
        child: AppErrorView(
          error: _loadError!,
          onRetry: () => _loadAll(showLoading: true),
        ),
      );
    }

    return FriendsSurface(
      child: Column(
        children: <Widget>[
          FriendsTabSwitcher(
            selected: _selectedSection,
            requestCount: _incoming.length,
            onSelected: (FriendsSection section) {
              setState(() {
                _selectedSection = section;
              });
            },
          ),
          Expanded(
            child: switch (_selectedSection) {
              FriendsSection.friends => _friendsTab(),
              FriendsSection.requests => _requestsTab(),
              FriendsSection.discover => _discoverTab(),
            },
          ),
        ],
      ),
    );
  }

  Widget _friendsTab() {
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        key: const PageStorageKey<String>('friends-v2-friends-tab'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 104),
        children: <Widget>[
          FriendsSectionHeading(
            title: 'Your friends',
            subtitle: 'Share progress, compare streaks, and stay connected.',
            count: _friends.length,
          ),
          if (_loadError != null && _friends.isNotEmpty)
            _InlineRefreshError(onRetry: _loadAll),
          if (_friends.isEmpty)
            FriendsEmptyCard(
              icon: Icons.people_outline,
              title: 'No friends yet',
              message:
                  'Find people you know and start sharing your progress.',
              actionLabel: 'Search people',
              onAction: _openPeopleSearch,
            )
          else
            for (final FriendSummary friend in _friends)
              FriendCard(
                friend: friend,
                isRemoving: _removingFriendIds.contains(friend.userId),
                isStartingMessage: _messagingFriendIds.contains(friend.userId),
                onOpenProfile: () => _openFriend(friend),
                onMessage: () => _messageFriend(friend),
                onRemove: () => _confirmRemoveFriend(friend),
              ),
        ],
      ),
    );
  }

  Widget _requestsTab() {
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        key: const PageStorageKey<String>('friends-v2-requests-tab'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 104),
        children: <Widget>[
          if (_incoming.isEmpty && _outgoing.isEmpty)
            const FriendsEmptyCard(
              icon: Icons.mark_email_read_outlined,
              title: 'No pending requests',
              message: 'Incoming and sent friend requests will appear here.',
            )
          else ...<Widget>[
            FriendsSectionHeading(
              title: 'Incoming',
              subtitle: 'People who want to connect with you.',
              count: _incoming.length,
            ),
            if (_incoming.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 4, 4, 22),
                child: Text('No new friend requests.'),
              )
            else
              for (final FriendRequestItem request in _incoming)
                IncomingFriendRequestCard(
                  request: request,
                  isProcessing: _processingRequestIds.contains(request.id),
                  onAccept: () => _acceptRequest(request),
                  onReject: () => _rejectRequest(request),
                ),
            const SizedBox(height: 10),
            FriendsSectionHeading(
              title: 'Sent',
              subtitle: 'Requests waiting for a response.',
              count: _outgoing.length,
            ),
            if (_outgoing.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 4, 4, 12),
                child: Text('No pending sent requests.'),
              )
            else
              for (final FriendRequestItem request in _outgoing)
                OutgoingFriendRequestCard(
                  request: request,
                  isProcessing: _processingRequestIds.contains(request.id),
                  onCancel: () => _cancelRequest(request),
                ),
          ],
        ],
      ),
    );
  }

  Widget _discoverTab() {
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        key: const PageStorageKey<String>('friends-v2-discover-tab'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 104),
        children: <Widget>[
          FriendsSectionHeading(
            title: 'People you may know',
            subtitle: 'Suggestions are based on your mutual-friend network.',
            count: _recommendations.length,
          ),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const Key('friends-v2-open-search'),
              onPressed: _openPeopleSearch,
              icon: const Icon(Icons.person_search_outlined),
              label: const Text('Search people'),
            ),
          ),
          const SizedBox(height: 14),
          if (_recommendations.isEmpty)
            FriendsEmptyCard(
              icon: Icons.hub_outlined,
              title: 'No suggestions right now',
              message:
                  'Recommendations will appear as your network grows. You can still search directly.',
              actionLabel: 'Search people',
              onAction: _openPeopleSearch,
            )
          else
            for (final FriendRecommendation recommendation
                in _recommendations)
              FriendSuggestionCard(
                recommendation: recommendation,
                isProcessing:
                    _processingRecommendationIds.contains(
                      recommendation.userId,
                    ),
                onAdd: () => _sendRecommendation(recommendation),
              ),
        ],
      ),
    );
  }
}

final class _FriendsSnapshot {
  const _FriendsSnapshot({
    required this.friends,
    required this.incoming,
    required this.outgoing,
    required this.recommendations,
  });

  final List<FriendSummary> friends;
  final List<FriendRequestItem> incoming;
  final List<FriendRequestItem> outgoing;
  final List<FriendRecommendation> recommendations;
}

final class _InlineRefreshError extends StatelessWidget {
  const _InlineRefreshError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.sync_problem_outlined,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Some friend data could not be refreshed.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
