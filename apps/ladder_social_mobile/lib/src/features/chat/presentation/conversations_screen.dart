import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ladder_social_core/ladder_social_core.dart';
import 'package:ladder_social_mobile/src/core/providers/core_providers.dart';
import 'package:ladder_social_mobile/src/core/widgets/mobile_widgets.dart';
import 'package:ladder_social_mobile/src/features/chat/presentation/chat_screen.dart';

final class ConversationsScreen extends ConsumerStatefulWidget {
  const ConversationsScreen({super.key});

  @override
  ConsumerState<ConversationsScreen> createState() => _ConversationsScreenState();
}

final class _ConversationsScreenState extends ConsumerState<ConversationsScreen> {
  final TextEditingController _searchController = TextEditingController();
  Future<PagedResult<ConversationItem>>? _future;

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

  void _load() {
    setState(() {
      _future = ref.read(chatRepositoryProvider).getConversations(
            search: _searchController.text,
          );
    });
  }

  Future<void> _open(ConversationItem conversation) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(conversation: conversation),
      ),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: RefreshIndicator(
        onRefresh: () async => _load(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            SearchBar(
              controller: _searchController,
              hintText: 'Search conversations',
              leading: const Icon(Icons.search),
              onSubmitted: (_) => _load(),
            ),
            const SizedBox(height: 12),
            FutureBuilder<PagedResult<ConversationItem>>(
              future: _future,
              builder: (BuildContext context, AsyncSnapshot<PagedResult<ConversationItem>> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(
                    padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
                }
                if (snapshot.hasError) {
                  return AppErrorView(error: snapshot.error!, onRetry: _load);
                }
                final List<ConversationItem> items = snapshot.data!.items;
                if (items.isEmpty) {
                  return const EmptyState(
                    icon: Icons.chat_bubble_outline,
                    title: 'No conversations',
                    message: 'Open a friend profile and tap Message to start chatting.',
                  );
                }
                return Column(
                  children: items
                      .map((ConversationItem item) {
                        ConversationParticipant? other;
                        for (final ConversationParticipant participant
                            in item.participants) {
                          if (!participant.isCurrentUser) {
                            other = participant;
                            break;
                          }
                        }
                        return Card(
                          child: ListTile(
                            onTap: () => _open(item),
                            leading: UserAvatar(
                              displayName: item.displayTitle,
                              avatarUrl: other?.avatarUrl,
                            ),
                            title: Text(item.displayTitle),
                            subtitle: Text(
                              item.lastMessagePreview ?? 'No messages yet',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: item.unreadCount > 0
                                ? Badge(label: Text('${item.unreadCount}'))
                                : item.lastMessageAtUtc == null
                                    ? null
                                    : Text(
                                        formatDate(item.lastMessageAtUtc!),
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                          ),
                        );
                      })
                      .toList(growable: false),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
