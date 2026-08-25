import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ladder_social_core/ladder_social_core.dart';
import 'package:ladder_social_mobile/src/core/providers/core_providers.dart';
import 'package:ladder_social_mobile/src/features/chat/presentation/conversations_screen.dart';
import 'package:ladder_social_mobile/src/features/feed/presentation/feed_screen.dart';
import 'package:ladder_social_mobile/src/features/feed/presentation/feed_search_action.dart';
import 'package:ladder_social_mobile/src/features/friends/presentation/friends_screen.dart';
import 'package:ladder_social_mobile/src/features/leaderboard/presentation/leaderboard_screen.dart';
import 'package:ladder_social_mobile/src/features/notifications/presentation/notifications_screen.dart';
import 'package:ladder_social_mobile/src/features/profile/presentation/profile_screen.dart';
import 'package:ladder_social_mobile/src/features/tasks/presentation/tasks_screen.dart';

final class AuthenticatedHomeScreen extends ConsumerStatefulWidget {
  const AuthenticatedHomeScreen({super.key});

  @override
  ConsumerState<AuthenticatedHomeScreen> createState() =>
      _AuthenticatedHomeScreenState();
}

final class _AuthenticatedHomeScreenState
    extends ConsumerState<AuthenticatedHomeScreen> {
  int _selectedIndex = 0;
  Timer? _notificationTimer;
  final FeedSearchController _feedSearchController = FeedSearchController();

  static const List<String> _titles = <String>[
    'Feed',
    'Friends',
    'Tasks',
    'Leaderboard',
    'Profile',
  ];

  @override
  void initState() {
    super.initState();
    _notificationTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => ref.invalidate(notificationSummaryProvider),
    );
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    _feedSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<NotificationSummary> summary =
        ref.watch(notificationSummaryProvider);
    final int unread = summary.asData?.value.unreadCount ?? 0;
    final List<Widget> pages = <Widget>[
      FeedScreen(searchController: _feedSearchController),
      const FriendsScreen(),
      const TasksScreen(),
      const LeaderboardScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        actions: <Widget>[
          IconButton(
            tooltip: 'Messages',
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(builder: (_) => const ConversationsScreen()),
            ),
            icon: const Icon(Icons.chat_bubble_outline),
          ),
          if (_selectedIndex == 0)
            FeedSearchAction(controller: _feedSearchController),
          Badge(
            isLabelVisible: unread > 0,
            label: Text(unread > 99 ? '99+' : '$unread'),
            child: IconButton(
              tooltip: 'Notifications',
              onPressed: () async {
                await Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()),
                );
                ref.invalidate(notificationSummaryProvider);
              },
              icon: const Icon(Icons.notifications_outlined),
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int value) => setState(() => _selectedIndex = value),
        destinations: const <NavigationDestination>[
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Feed'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Friends'),
          NavigationDestination(icon: Icon(Icons.task_alt_outlined), selectedIcon: Icon(Icons.task_alt), label: 'Tasks'),
          NavigationDestination(icon: Icon(Icons.emoji_events_outlined), selectedIcon: Icon(Icons.emoji_events), label: 'Ranking'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
