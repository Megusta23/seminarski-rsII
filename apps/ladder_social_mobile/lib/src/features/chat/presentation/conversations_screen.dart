import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ladder_social_core/ladder_social_core.dart';
import 'package:ladder_social_mobile/src/core/providers/core_providers.dart';
import 'package:ladder_social_mobile/src/core/widgets/mobile_widgets.dart';
import 'package:ladder_social_mobile/src/features/chat/presentation/chat_screen.dart';

final class ConversationsScreen extends ConsumerStatefulWidget {
  const ConversationsScreen({super.key});

  @override
  ConsumerState<ConversationsScreen> createState() =>
      _ConversationsScreenState();
}

final class _ConversationsScreenState
    extends ConsumerState<ConversationsScreen> {
  static const int _pageSize = 20;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ConversationItem> _items = <ConversationItem>[];

  bool _didInitialize = false;
  bool _initialLoading = true;
  bool _loadingMore = false;
  int _page = 0;
  int _totalPages = 1;
  int _requestGeneration = 0;
  Object? _error;
  Object? _loadMoreError;

  bool get _hasMore => _page < _totalPages;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInitialize) {
      return;
    }
    _didInitialize = true;
    unawaited(_refresh());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.extentAfter < 320) {
      unawaited(_loadMore());
    }
  }

  Future<void> _refresh() async {
    final int generation = ++_requestGeneration;
    if (mounted) {
      setState(() {
        _initialLoading = _items.isEmpty;
        _loadingMore = false;
        _error = null;
        _loadMoreError = null;
      });
    }

    try {
      final PagedResult<ConversationItem> result = await ref
          .read(chatRepositoryProvider)
          .getConversations(
            search: _searchController.text,
            page: 1,
            pageSize: _pageSize,
          );
      if (!mounted || generation != _requestGeneration) {
        return;
      }
      setState(() {
        _items
          ..clear()
          ..addAll(result.items);
        _page = result.page;
        _totalPages = result.totalPages;
        _initialLoading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted || generation != _requestGeneration) {
        return;
      }
      setState(() {
        _initialLoading = false;
        _error = error;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_initialLoading || _loadingMore || !_hasMore) {
      return;
    }

    final int generation = _requestGeneration;
    final String search = _searchController.text;
    setState(() {
      _loadingMore = true;
      _loadMoreError = null;
    });
    try {
      final PagedResult<ConversationItem> result = await ref
          .read(chatRepositoryProvider)
          .getConversations(
            search: search,
            page: _page + 1,
            pageSize: _pageSize,
          );
      if (!mounted || generation != _requestGeneration) {
        return;
      }
      final List<ConversationItem> merged = mergeUniqueItems<ConversationItem>(
        current: _items,
        updates: result.items,
        keyOf: (ConversationItem item) => item.id,
      );
      setState(() {
        _items
          ..clear()
          ..addAll(merged);
        _page = result.page;
        _totalPages = result.totalPages;
      });
    } catch (error) {
      if (mounted && generation == _requestGeneration) {
        setState(() => _loadMoreError = error);
      }
    } finally {
      if (mounted && generation == _requestGeneration) {
        setState(() => _loadingMore = false);
      }
    }
  }

  Future<void> _open(ConversationItem conversation) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(conversation: conversation),
      ),
    );
    if (mounted) {
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            SearchBar(
              controller: _searchController,
              hintText: 'Search conversations',
              leading: const Icon(Icons.search),
              trailing: <Widget>[
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    tooltip: 'Clear search',
                    onPressed: () {
                      _searchController.clear();
                      unawaited(_refresh());
                    },
                    icon: const Icon(Icons.close),
                  ),
              ],
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => unawaited(_refresh()),
            ),
            const SizedBox(height: 12),
            if (_initialLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null && _items.isEmpty)
              AppErrorView(error: _error!, onRetry: _refresh)
            else if (_items.isEmpty)
              const EmptyState(
                icon: Icons.chat_bubble_outline,
                title: 'No conversations',
                message:
                    'Open a friend profile and tap Message to start chatting.',
              )
            else ...<Widget>[
              for (final ConversationItem item in _items)
                _ConversationCard(
                  conversation: item,
                  onTap: () => _open(item),
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

final class _ConversationCard extends StatelessWidget {
  const _ConversationCard({
    required this.conversation,
    required this.onTap,
  });

  final ConversationItem conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    ConversationParticipant? other;
    for (final ConversationParticipant participant
        in conversation.participants) {
      if (!participant.isCurrentUser) {
        other = participant;
        break;
      }
    }

    return Card(
      child: ListTile(
        onTap: onTap,
        leading: UserAvatar(
          displayName: conversation.displayTitle,
          avatarUrl: other?.avatarUrl,
        ),
        title: Text(conversation.displayTitle),
        subtitle: Text(
          conversation.canSendMessages
              ? conversation.lastMessagePreview ?? 'No messages yet'
              : 'Read-only conversation · '
                  '${conversation.lastMessagePreview ?? 'No messages'}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: conversation.unreadCount > 0
            ? Badge(label: Text('${conversation.unreadCount}'))
            : conversation.lastMessageAtUtc == null
                ? null
                : Text(
                    formatDate(conversation.lastMessageAtUtc!),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
      ),
    );
  }
}
