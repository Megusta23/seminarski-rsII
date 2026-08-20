import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ladder_social_core/ladder_social_core.dart';
import 'package:ladder_social_mobile/src/core/providers/core_providers.dart';
import 'package:ladder_social_mobile/src/core/widgets/mobile_widgets.dart';
import 'package:ladder_social_mobile/src/features/friends/presentation/friend_profile_screen.dart';

final class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

final class _FriendsScreenState extends ConsumerState<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _friendSearch = TextEditingController();
  final TextEditingController _userSearch = TextEditingController();
  Future<PagedResult<FriendSummary>>? _friends;
  Future<PagedResult<FriendRequestItem>>? _incoming;
  Future<PagedResult<FriendRequestItem>>? _outgoing;
  Future<PagedResult<UserSearchItem>>? _users;
  Future<List<FriendRecommendation>>? _recommendations;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _friendSearch.dispose();
    _userSearch.dispose();
    super.dispose();
  }

  void _loadAll() {
    setState(() {
      final FriendRepository repository = ref.read(friendRepositoryProvider);
      _friends = repository.getFriends(search: _friendSearch.text);
      _incoming = repository.getIncomingRequests();
      _outgoing = repository.getOutgoingRequests();
      _users = repository.searchUsers(search: _userSearch.text);
      _recommendations = repository.getRecommendations();
    });
  }

  Future<void> _perform(Future<void> Function() action, String success) async {
    try {
      await action();
      if (!mounted) return;
      showMessage(context, success);
      _loadAll();
    } catch (error) {
      if (mounted) showMessage(context, ApiException.from(error).message, error: true);
    }
  }

  Future<void> _openFriend(FriendSummary friend) async {
    final bool? removed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => FriendProfileScreen(userId: friend.userId),
      ),
    );
    if (removed == true && mounted) _loadAll();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        TabBar(
          controller: _tabController,
          tabs: const <Tab>[
            Tab(text: 'Friends'),
            Tab(text: 'Requests'),
            Tab(text: 'Discover'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: <Widget>[
              _friendsTab(),
              _requestsTab(),
              _discoverTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _friendsTab() {
    return RefreshIndicator(
      onRefresh: () async => _loadAll(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: <Widget>[
          SearchBar(
            controller: _friendSearch,
            hintText: 'Search friends',
            leading: const Icon(Icons.search),
            onSubmitted: (_) => _loadAll(),
          ),
          const SizedBox(height: 12),
          FutureBuilder<PagedResult<FriendSummary>>(
            future: _friends,
            builder: (BuildContext context, AsyncSnapshot<PagedResult<FriendSummary>> snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: Padding(
                  padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
              }
              if (snapshot.hasError) {
                return AppErrorView(error: snapshot.error!, onRetry: _loadAll);
              }
              final List<FriendSummary> items = snapshot.data!.items;
              if (items.isEmpty) {
                return const EmptyState(
                  icon: Icons.people_outline,
                  title: 'No friends yet',
                  message: 'Use Discover to find people and send a request.',
                );
              }
              return Column(
                children: items
                    .map((FriendSummary friend) => Card(
                          child: ListTile(
                            onTap: () => _openFriend(friend),
                            leading: UserAvatar(
                              displayName: friend.displayName,
                              avatarUrl: friend.avatarUrl,
                            ),
                            title: Text(friend.displayName),
                            subtitle: Text(
                              '${friend.completedTaskCount} completed • ${friend.currentStreak} day streak',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                          ),
                        ))
                    .toList(growable: false),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _requestsTab() {
    return RefreshIndicator(
      onRefresh: () async => _loadAll(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: <Widget>[
          Text('Incoming', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          FutureBuilder<PagedResult<FriendRequestItem>>(
            future: _incoming,
            builder: (BuildContext context, AsyncSnapshot<PagedResult<FriendRequestItem>> snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LinearProgressIndicator();
              }
              if (snapshot.hasError) return AppErrorView(error: snapshot.error!);
              final List<FriendRequestItem> items = snapshot.data!.items;
              if (items.isEmpty) return const Text('No incoming requests.');
              return Column(
                children: items
                    .map((FriendRequestItem item) => Card(
                          child: ListTile(
                            leading: UserAvatar(
                              displayName: item.senderDisplayName,
                              avatarUrl: item.senderAvatarUrl,
                            ),
                            title: Text(item.senderDisplayName),
                            subtitle: Text(formatDateTime(item.createdAtUtc)),
                            trailing: Wrap(
                              children: <Widget>[
                                IconButton(
                                  tooltip: 'Reject',
                                  onPressed: () => _perform(
                                    () => ref.read(friendRepositoryProvider).rejectRequest(item.id),
                                    'Request rejected.',
                                  ),
                                  icon: const Icon(Icons.close),
                                ),
                                IconButton(
                                  tooltip: 'Accept',
                                  onPressed: () => _perform(
                                    () => ref.read(friendRepositoryProvider).acceptRequest(item.id),
                                    'Friend request accepted.',
                                  ),
                                  icon: const Icon(Icons.check),
                                ),
                              ],
                            ),
                          ),
                        ))
                    .toList(growable: false),
              );
            },
          ),
          const SizedBox(height: 24),
          Text('Outgoing', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          FutureBuilder<PagedResult<FriendRequestItem>>(
            future: _outgoing,
            builder: (BuildContext context, AsyncSnapshot<PagedResult<FriendRequestItem>> snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LinearProgressIndicator();
              }
              if (snapshot.hasError) return AppErrorView(error: snapshot.error!);
              final List<FriendRequestItem> items = snapshot.data!.items;
              if (items.isEmpty) return const Text('No outgoing requests.');
              return Column(
                children: items
                    .map((FriendRequestItem item) => Card(
                          child: ListTile(
                            leading: const Icon(Icons.schedule_send_outlined),
                            title: Text(item.receiverDisplayName),
                            subtitle: Text(formatDateTime(item.createdAtUtc)),
                            trailing: TextButton(
                              onPressed: () => _perform(
                                () => ref.read(friendRepositoryProvider).cancelRequest(item.id),
                                'Request cancelled.',
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                        ))
                    .toList(growable: false),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _discoverTab() {
    return RefreshIndicator(
      onRefresh: () async => _loadAll(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: <Widget>[
          Text('Recommended for you', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          FutureBuilder<List<FriendRecommendation>>(
            future: _recommendations,
            builder: (BuildContext context, AsyncSnapshot<List<FriendRecommendation>> snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LinearProgressIndicator();
              }
              if (snapshot.hasError) return AppErrorView(error: snapshot.error!);
              final List<FriendRecommendation> items = snapshot.data!;
              if (items.isEmpty) return const Text('No recommendations yet. Add more friends to expand your graph.');
              return Column(
                children: items
                    .map((FriendRecommendation item) => Card(
                          child: ListTile(
                            leading: UserAvatar(
                              displayName: item.displayName,
                              avatarUrl: item.avatarUrl,
                            ),
                            title: Text(item.displayName),
                            subtitle: Text(item.explanation),
                            trailing: IconButton(
                              tooltip: 'Send request',
                              onPressed: () => _perform(
                                () async {
                                  await ref.read(friendRepositoryProvider).sendRequest(item.userId);
                                },
                                'Friend request sent.',
                              ),
                              icon: const Icon(Icons.person_add_alt_1),
                            ),
                          ),
                        ))
                    .toList(growable: false),
              );
            },
          ),
          const SizedBox(height: 22),
          SearchBar(
            controller: _userSearch,
            hintText: 'Search users by name or email',
            leading: const Icon(Icons.person_search_outlined),
            onSubmitted: (_) => _loadAll(),
          ),
          const SizedBox(height: 10),
          FutureBuilder<PagedResult<UserSearchItem>>(
            future: _users,
            builder: (BuildContext context, AsyncSnapshot<PagedResult<UserSearchItem>> snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LinearProgressIndicator();
              }
              if (snapshot.hasError) return AppErrorView(error: snapshot.error!);
              final List<UserSearchItem> items = snapshot.data!.items;
              if (items.isEmpty) return const Text('No users match your search.');
              return Column(
                children: items
                    .map((UserSearchItem item) => Card(
                          child: ListTile(
                            leading: UserAvatar(
                              displayName: item.displayName,
                              avatarUrl: item.avatarUrl,
                            ),
                            title: Text(item.displayName),
                            subtitle: Text(item.email),
                            trailing: item.isFriend
                                ? const Icon(Icons.people, color: Colors.green)
                                : item.hasOutgoingPendingRequest
                                    ? const Icon(Icons.schedule_send_outlined)
                                    : item.hasIncomingPendingRequest
                                        ? const Icon(Icons.mark_email_unread_outlined)
                                        : IconButton(
                                            tooltip: 'Send request',
                                            onPressed: () => _perform(
                                              () async {
                                                await ref.read(friendRepositoryProvider).sendRequest(item.userId);
                                              },
                                              'Friend request sent.',
                                            ),
                                            icon: const Icon(Icons.person_add_alt_1),
                                          ),
                          ),
                        ))
                    .toList(growable: false),
              );
            },
          ),
        ],
      ),
    );
  }
}
