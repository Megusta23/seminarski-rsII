import 'package:flutter/material.dart';
import 'package:ladder_social_mobile/src/features/friends/presentation/friends_screen_controller.dart';
import 'package:ladder_social_mobile/src/features/friends/presentation/people_search_screen.dart';

final class FriendsSearchAction extends StatelessWidget {
  const FriendsSearchAction({required this.controller, super.key});

  final FriendsScreenController controller;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const Key('friends-search-action'),
      tooltip: 'Search people',
      onPressed: () => Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => PeopleSearchScreen(controller: controller),
        ),
      ),
      icon: const Icon(Icons.person_search_outlined),
    );
  }
}
