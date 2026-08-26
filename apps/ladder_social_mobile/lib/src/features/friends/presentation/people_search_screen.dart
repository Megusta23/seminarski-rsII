import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ladder_social_core/ladder_social_core.dart';
import 'package:ladder_social_mobile/src/core/providers/core_providers.dart';
import 'package:ladder_social_mobile/src/core/widgets/mobile_widgets.dart';
import 'package:ladder_social_mobile/src/features/friends/presentation/friend_profile_screen.dart';
import 'package:ladder_social_mobile/src/features/friends/presentation/friends_screen_controller.dart';
import 'package:ladder_social_mobile/src/features/friends/presentation/friends_widgets.dart';

final class PeopleSearchScreen extends ConsumerStatefulWidget {
  const PeopleSearchScreen({required this.controller, super.key});

  final FriendsScreenController controller;

  @override
  ConsumerState<PeopleSearchScreen> createState() => _PeopleSearchScreenState();
}

final class _PeopleSearchScreenState extends ConsumerState<PeopleSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _processingUserIds = <String>{};
  final List<UserSearchItem> _items = <UserSearchItem>[];
  Timer? _debounce;
  Object? _error;
  bool _isLoading = false;
  int _requestVersion = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final String query = value.trim();
    if (query.length < 2) {
      _requestVersion++;
      setState(() {
        _items.clear();
        _error = null;
        _isLoading = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _search();
    });
  }

  Future<void> _search() async {
    if (!mounted) {
      return;
    }
    final String query = _searchController.text.trim();
    if (query.length < 2) {
      return;
    }
    final int version = ++_requestVersion;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final PagedResult<UserSearchItem> page =
          await ref.read(friendRepositoryProvider).searchUsers(
                search: query,
                excludeExistingRelationships: false,
                pageSize: 50,
              );
      if (!mounted || version != _requestVersion) {
        return;
      }
      setState(() {
        _items
          ..clear()
          ..addAll(page.items);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted || version != _requestVersion) {
        return;
      }
      setState(() {
        _error = error;
        _isLoading = false;
      });
    }
  }

  void _replaceItem(UserSearchItem item) {
    final int index = _items.indexWhere(
      (UserSearchItem candidate) => candidate.userId == item.userId,
    );
    if (index == -1) {
      return;
    }
    setState(() {
      _items[index] = item;
    });
  }

  Future<void> _runAction(
    UserSearchItem item,
    Future<UserSearchItem> Function() action,
    String success,
    FriendsSection section,
  ) async {
    if (_processingUserIds.contains(item.userId)) {
      return;
    }
    setState(() {
      _processingUserIds.add(item.userId);
    });
    try {
      final UserSearchItem updated = await action();
      if (!mounted) {
        return;
      }
      _replaceItem(updated);
      widget.controller.refresh(section: section);
      ref.invalidate(notificationSummaryProvider);
      showMessage(context, success);
    } catch (error) {
      if (mounted) {
        showMessage(context, ApiException.from(error).message, error: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _processingUserIds.remove(item.userId);
        });
      }
    }
  }

  Future<UserSearchItem> _sendRequest(UserSearchItem item) async {
    final FriendRequestItem request =
        await ref.read(friendRepositoryProvider).sendRequest(item.userId);
    return item.copyWith(
      hasOutgoingPendingRequest: true,
      hasIncomingPendingRequest: false,
      outgoingRequestId: request.id,
      clearIncomingRequestId: true,
    );
  }

  Future<UserSearchItem> _acceptRequest(UserSearchItem item) async {
    final String? requestId = item.incomingRequestId;
    if (requestId == null) {
      throw const ApiException(
        message: 'The incoming friend request could not be found.',
      );
    }
    await ref.read(friendRepositoryProvider).acceptRequest(requestId);
    return item.copyWith(
      isFriend: true,
      hasIncomingPendingRequest: false,
      hasOutgoingPendingRequest: false,
      clearIncomingRequestId: true,
      clearOutgoingRequestId: true,
    );
  }

  Future<UserSearchItem> _rejectRequest(UserSearchItem item) async {
    final String? requestId = item.incomingRequestId;
    if (requestId == null) {
      throw const ApiException(
        message: 'The incoming friend request could not be found.',
      );
    }
    await ref.read(friendRepositoryProvider).rejectRequest(requestId);
    return item.copyWith(
      hasIncomingPendingRequest: false,
      clearIncomingRequestId: true,
    );
  }

  Future<UserSearchItem> _cancelRequest(UserSearchItem item) async {
    final String? requestId = item.outgoingRequestId;
    if (requestId == null) {
      throw const ApiException(
        message: 'The outgoing friend request could not be found.',
      );
    }
    await ref.read(friendRepositoryProvider).cancelRequest(requestId);
    return item.copyWith(
      hasOutgoingPendingRequest: false,
      clearOutgoingRequestId: true,
    );
  }

  Future<void> _openProfile(UserSearchItem item) async {
    final bool? removed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => FriendProfileScreen(userId: item.userId),
      ),
    );
    if (removed == true && mounted) {
      _replaceItem(
        item.copyWith(
          isFriend: false,
          hasIncomingPendingRequest: false,
          hasOutgoingPendingRequest: false,
          clearIncomingRequestId: true,
          clearOutgoingRequestId: true,
        ),
      );
      widget.controller.refresh(section: FriendsSection.friends);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search people')),
      body: FriendsSurface(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: SearchBar(
                key: const Key('people-search-field'),
                controller: _searchController,
                autoFocus: true,
                hintText: 'Search by name or email',
                leading: const Icon(Icons.search),
                trailing: <Widget>[
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        _searchController.clear();
                        _onChanged('');
                      },
                      icon: const Icon(Icons.close),
                    ),
                ],
                onChanged: (String value) {
                  setState(() {});
                  _onChanged(value);
                },
                onSubmitted: (_) => _search(),
              ),
            ),
            Expanded(child: _buildResults()),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_searchController.text.trim().length < 2) {
      return const FriendsEmptyCard(
        icon: Icons.person_search_outlined,
        title: 'Find people you know',
        message: 'Enter at least two characters to search Ladder Social.',
      );
    }
    if (_isLoading && _items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: FriendsLoadingList(count: 4),
      );
    }
    if (_error != null && _items.isEmpty) {
      return AppErrorView(error: _error!, onRetry: _search);
    }
    if (_items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: FriendsEmptyCard(
          icon: Icons.search_off_outlined,
          title: 'No people found',
          message: 'Try another name or email address.',
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _search,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        itemCount: _items.length,
        itemBuilder: (BuildContext context, int index) {
          final UserSearchItem item = _items[index];
          final bool processing = _processingUserIds.contains(item.userId);
          return PeopleSearchResultCard(
            item: item,
            isProcessing: processing,
            onPrimaryAction: () {
              if (item.isFriend) {
                _openProfile(item);
              } else if (item.hasIncomingPendingRequest) {
                _runAction(
                  item,
                  () => _acceptRequest(item),
                  'You and ${item.displayName} are now friends.',
                  FriendsSection.friends,
                );
              } else if (!item.hasOutgoingPendingRequest) {
                _runAction(
                  item,
                  () => _sendRequest(item),
                  'Friend request sent.',
                  FriendsSection.requests,
                );
              }
            },
            onSecondaryAction: item.hasIncomingPendingRequest
                ? () => _runAction(
                      item,
                      () => _rejectRequest(item),
                      'Friend request declined.',
                      FriendsSection.requests,
                    )
                : item.hasOutgoingPendingRequest
                    ? () => _runAction(
                          item,
                          () => _cancelRequest(item),
                          'Friend request cancelled.',
                          FriendsSection.requests,
                        )
                    : null,
          );
        },
      ),
    );
  }
}
