import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ladder_social_core/ladder_social_core.dart';
import 'package:ladder_social_mobile/src/core/providers/core_providers.dart';
import 'package:ladder_social_mobile/src/core/widgets/mobile_widgets.dart';
import 'package:ladder_social_mobile/src/features/chat/presentation/chat_screen.dart';

final class FriendProfileScreen extends ConsumerStatefulWidget {
  const FriendProfileScreen({required this.userId, super.key});
  final String userId;

  @override
  ConsumerState<FriendProfileScreen> createState() => _FriendProfileScreenState();
}

final class _FriendProfileScreenState extends ConsumerState<FriendProfileScreen> {
  Future<FriendProfile>? _future;
  bool _startingChat = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _future = ref.read(friendRepositoryProvider).getProfile(widget.userId);
    });
  }

  Future<void> _message() async {
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
      if (mounted) showMessage(context, ApiException.from(error).message, error: true);
    } finally {
      if (mounted) setState(() => _startingChat = false);
    }
  }

  Future<void> _remove(FriendProfile profile) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Remove friend?'),
        content: Text('Remove ${profile.displayName} from your friends?'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(friendRepositoryProvider).removeFriend(widget.userId);
      if (!mounted) return;
      Navigator.of(context).pop<bool>(true);
    } catch (error) {
      if (mounted) showMessage(context, ApiException.from(error).message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Friend profile')),
      body: FutureBuilder<FriendProfile>(
        future: _future,
        builder: (BuildContext context, AsyncSnapshot<FriendProfile> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return AppErrorView(error: snapshot.error!, onRetry: _load);
          }
          final FriendProfile profile = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: <Widget>[
              Center(
                child: UserAvatar(
                  displayName: profile.displayName,
                  avatarUrl: profile.avatarUrl,
                  radius: 52,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                profile.displayName,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (profile.cityName != null)
                Text(
                  profile.cityName!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.outline),
                ),
              if (profile.bio != null) ...<Widget>[
                const SizedBox(height: 14),
                Text(profile.bio!, textAlign: TextAlign.center),
              ],
              const SizedBox(height: 20),
              Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _startingChat ? null : _message,
                      icon: _startingChat
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.chat_bubble_outline),
                      label: const Text('Message'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: () => _remove(profile),
                    icon: const Icon(Icons.person_remove_outlined),
                    label: const Text('Remove'),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.55,
                children: <Widget>[
                  _MetricCard(label: 'Friends', value: profile.friendCount, icon: Icons.people_outline),
                  _MetricCard(label: 'Completed', value: profile.completedTaskCount, icon: Icons.task_alt),
                  _MetricCard(label: 'Habits', value: profile.habitCount, icon: Icons.repeat),
                  _MetricCard(label: 'Streak', value: profile.currentStreak, icon: Icons.local_fire_department_outlined),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

final class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value, required this.icon});
  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon),
            const SizedBox(height: 6),
            Text('$value', style: Theme.of(context).textTheme.titleLarge),
            Text(label),
          ],
        ),
      ),
    );
  }
}
