import 'package:flutter/material.dart';
import 'package:ladder_social_core/ladder_social_core.dart';
import 'package:ladder_social_mobile/src/core/widgets/mobile_widgets.dart';
import 'package:ladder_social_mobile/src/features/friends/presentation/friends_screen_controller.dart';

const Color _friendsAccent = Color(0xFF7358A5);
const Color _friendsAccentSoft = Color(0xFFEDE7F6);
const Color _friendsBorder = Color(0xFFE7E1EA);
const Color _friendsBackground = Color(0xFFF8F6FB);
const Color _successSoft = Color(0xFFE7F5EE);
const Color _successStrong = Color(0xFF247A52);
const Color _warmSoft = Color(0xFFFFF2DD);
const Color _warmStrong = Color(0xFF9A5A16);

final class FriendsTabSwitcher extends StatelessWidget {
  const FriendsTabSwitcher({
    required this.selected,
    required this.requestCount,
    required this.onSelected,
    super.key,
  });

  final FriendsSection selected;
  final int requestCount;
  final ValueChanged<FriendsSection> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('friends-tab-switcher'),
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0ECF3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: FriendsSection.values.map((FriendsSection section) {
          final bool isSelected = section == selected;
          final String label = switch (section) {
            FriendsSection.friends => 'Friends',
            FriendsSection.requests => 'Requests',
            FriendsSection.discover => 'Discover',
          };
          return Expanded(
            child: Semantics(
              button: true,
              selected: isSelected,
              label: section == FriendsSection.requests && requestCount > 0
                  ? '$label, $requestCount pending'
                  : label,
              child: InkWell(
                key: Key('friends-section-${section.name}'),
                borderRadius: BorderRadius.circular(12),
                onTap: () => onSelected(section),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isSelected
                        ? const <BoxShadow>[
                            BoxShadow(
                              color: Color(0x16000000),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isSelected
                                ? _friendsAccent
                                : const Color(0xFF6B6470),
                            fontWeight:
                                isSelected ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                      ),
                      if (section == FriendsSection.requests &&
                          requestCount > 0) ...<Widget>[
                        const SizedBox(width: 5),
                        Container(
                          key: const Key('friends-requests-count'),
                          constraints: const BoxConstraints(minWidth: 20),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? _friendsAccent
                                : const Color(0xFF8C8193),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            requestCount > 99 ? '99+' : '$requestCount',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }
}

final class FriendsSectionHeading extends StatelessWidget {
  const FriendsSectionHeading({
    required this.title,
    this.subtitle,
    this.count,
    super.key,
  });

  final String title;
  final String? subtitle;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 6, 2, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ],
              ],
            ),
          ),
          if (count != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: _friendsAccentSoft,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: _friendsAccent,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

final class FriendCard extends StatelessWidget {
  const FriendCard({
    required this.friend,
    required this.onOpenProfile,
    required this.onMessage,
    required this.onRemove,
    this.isRemoving = false,
    this.isStartingMessage = false,
    super.key,
  });

  final FriendSummary friend;
  final VoidCallback onOpenProfile;
  final VoidCallback onMessage;
  final VoidCallback onRemove;
  final bool isRemoving;
  final bool isStartingMessage;

  @override
  Widget build(BuildContext context) {
    final String mutualLabel = friend.mutualFriendCount == 0
        ? 'No mutual friends'
        : '${friend.mutualFriendCount} mutual friend${friend.mutualFriendCount == 1 ? '' : 's'}';
    return _SocialCard(
      key: Key('friend-card-${friend.userId}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: onOpenProfile,
                child: UserAvatar(
                  displayName: friend.displayName,
                  avatarUrl: friend.avatarUrl,
                  radius: 27,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: onOpenProfile,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          friend.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          mutualLabel,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Friend actions',
                enabled: !isRemoving,
                onSelected: (String value) {
                  if (value == 'remove') {
                    onRemove();
                  }
                },
                itemBuilder: (BuildContext context) =>
                    const <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
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
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 6,
            children: <Widget>[
              _MetricChip(
                icon: Icons.local_fire_department_outlined,
                label: '${friend.currentStreak} day streak',
                background: _warmSoft,
                foreground: _warmStrong,
              ),
              _MetricChip(
                icon: Icons.task_alt,
                label: '${friend.completedTaskCount} completed',
                background: _successSoft,
                foreground: _successStrong,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ResponsiveActions(
            primary: OutlinedButton.icon(
              key: Key('view-friend-${friend.userId}'),
              onPressed: isRemoving ? null : onOpenProfile,
              icon: const Icon(Icons.person_outline),
              label: const Text('View profile'),
            ),
            secondary: FilledButton.icon(
              key: Key('message-friend-${friend.userId}'),
              onPressed: isRemoving || isStartingMessage ? null : onMessage,
              icon: isStartingMessage
                  ? const SizedBox.square(
                      dimension: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.chat_bubble_outline),
              label: const Text('Message'),
            ),
          ),
        ],
      ),
    );
  }
}

final class IncomingFriendRequestCard extends StatelessWidget {
  const IncomingFriendRequestCard({
    required this.request,
    required this.onAccept,
    required this.onReject,
    this.isProcessing = false,
    super.key,
  });

  final FriendRequestItem request;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final bool isProcessing;

  @override
  Widget build(BuildContext context) {
    return _SocialCard(
      key: Key('incoming-request-${request.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              UserAvatar(
                displayName: request.senderDisplayName,
                avatarUrl: request.senderAvatarUrl,
                radius: 25,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      request.senderDisplayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sent ${formatDateTime(request.createdAtUtc)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                  ],
                ),
              ),
              if (isProcessing)
                const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _ResponsiveActions(
            primary: OutlinedButton(
              key: Key('reject-request-${request.id}'),
              onPressed: isProcessing ? null : onReject,
              child: const Text('Decline'),
            ),
            secondary: FilledButton(
              key: Key('accept-request-${request.id}'),
              onPressed: isProcessing ? null : onAccept,
              child: const Text('Accept'),
            ),
          ),
        ],
      ),
    );
  }
}

final class OutgoingFriendRequestCard extends StatelessWidget {
  const OutgoingFriendRequestCard({
    required this.request,
    required this.onCancel,
    this.isProcessing = false,
    super.key,
  });

  final FriendRequestItem request;
  final VoidCallback onCancel;
  final bool isProcessing;

  @override
  Widget build(BuildContext context) {
    return _SocialCard(
      key: Key('outgoing-request-${request.id}'),
      child: _ResponsiveIdentityAction(
        identity: _PersonIdentity(
          displayName: request.receiverDisplayName,
          avatarUrl: request.receiverAvatarUrl,
          subtitle: 'Request pending',
        ),
        action: TextButton(
          key: Key('cancel-request-${request.id}'),
          onPressed: isProcessing ? null : onCancel,
          child: isProcessing
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Cancel'),
        ),
      ),
    );
  }
}

final class FriendSuggestionCard extends StatelessWidget {
  const FriendSuggestionCard({
    required this.recommendation,
    required this.onAdd,
    this.isProcessing = false,
    super.key,
  });

  final FriendRecommendation recommendation;
  final VoidCallback onAdd;
  final bool isProcessing;

  @override
  Widget build(BuildContext context) {
    return _SocialCard(
      key: Key('friend-suggestion-${recommendation.userId}'),
      child: _ResponsiveIdentityAction(
        identity: _PersonIdentity(
          displayName: recommendation.displayName,
          avatarUrl: recommendation.avatarUrl,
          subtitle: recommendation.explanation,
          subtitleMaxLines: 2,
        ),
        action: FilledButton(
          key: Key('add-recommendation-${recommendation.userId}'),
          onPressed: isProcessing ? null : onAdd,
          child: isProcessing
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Add'),
        ),
      ),
    );
  }
}

final class PeopleSearchResultCard extends StatelessWidget {
  const PeopleSearchResultCard({
    required this.item,
    required this.onPrimaryAction,
    this.onSecondaryAction,
    this.isProcessing = false,
    super.key,
  });

  final UserSearchItem item;
  final VoidCallback onPrimaryAction;
  final VoidCallback? onSecondaryAction;
  final bool isProcessing;

  @override
  Widget build(BuildContext context) {
    final String relationshipLabel;
    final String primaryLabel;
    final IconData primaryIcon;
    if (item.isFriend) {
      relationshipLabel = 'Friends';
      primaryLabel = 'Profile';
      primaryIcon = Icons.person_outline;
    } else if (item.hasIncomingPendingRequest) {
      relationshipLabel = 'Sent you a request';
      primaryLabel = 'Accept';
      primaryIcon = Icons.person_add_alt_1;
    } else if (item.hasOutgoingPendingRequest) {
      relationshipLabel = 'Request pending';
      primaryLabel = 'Requested';
      primaryIcon = Icons.schedule_send_outlined;
    } else {
      relationshipLabel = item.mutualFriendCount == 0
          ? 'No mutual friends'
          : '${item.mutualFriendCount} mutual friend${item.mutualFriendCount == 1 ? '' : 's'}';
      primaryLabel = 'Add';
      primaryIcon = Icons.person_add_alt_1;
    }

    final bool primaryEnabled =
        !isProcessing && !(item.hasOutgoingPendingRequest && !item.isFriend);
    final Widget identity = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        UserAvatar(
          displayName: item.displayName,
          avatarUrl: item.avatarUrl,
          radius: 24,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                item.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                relationshipLabel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
              if (item.mutualFriendCount > 0 &&
                  (item.isFriend ||
                      item.hasIncomingPendingRequest ||
                      item.hasOutgoingPendingRequest)) ...<Widget>[
                const SizedBox(height: 3),
                Text(
                  '${item.mutualFriendCount} mutual friend${item.mutualFriendCount == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _friendsAccent,
                      ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
    final Widget actions = Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 4,
      children: <Widget>[
        FilledButton.tonalIcon(
          key: Key('people-primary-${item.userId}'),
          onPressed: primaryEnabled ? onPrimaryAction : null,
          icon: isProcessing
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(primaryIcon, size: 18),
          label: Text(primaryLabel),
        ),
        if (onSecondaryAction != null)
          TextButton(
            key: Key('people-secondary-${item.userId}'),
            onPressed: isProcessing ? null : onSecondaryAction,
            child: Text(
              item.hasIncomingPendingRequest ? 'Decline' : 'Cancel',
            ),
          ),
      ],
    );

    return _SocialCard(
      key: Key('people-search-result-${item.userId}'),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          if (constraints.maxWidth < 330) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                identity,
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerRight, child: actions),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: identity),
              const SizedBox(width: 8),
              Flexible(child: actions),
            ],
          );
        },
      ),
    );
  }
}

final class FriendsLoadingList extends StatelessWidget {
  const FriendsLoadingList({this.count = 3, super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List<Widget>.generate(
        count,
        (int index) => Container(
          height: 118,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _friendsBorder),
          ),
          child: const Center(
            child: SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      ),
    );
  }
}

final class FriendsEmptyCard extends StatelessWidget {
  const FriendsEmptyCard({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _friendsBorder),
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(
              color: _friendsAccentSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _friendsAccent, size: 30),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 7),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          if (actionLabel != null && onAction != null) ...<Widget>[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.person_search_outlined),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

final class FriendsSurface extends StatelessWidget {
  const FriendsSurface({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: _friendsBackground, child: child);
  }
}

final class _SocialCard extends StatelessWidget {
  const _SocialCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _friendsBorder),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

final class _PersonIdentity extends StatelessWidget {
  const _PersonIdentity({
    required this.displayName,
    required this.subtitle,
    this.avatarUrl,
    this.subtitleMaxLines = 1,
  });

  final String displayName;
  final String subtitle;
  final String? avatarUrl;
  final int subtitleMaxLines;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        UserAvatar(
          displayName: displayName,
          avatarUrl: avatarUrl,
          radius: 25,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: subtitleMaxLines,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

final class _ResponsiveIdentityAction extends StatelessWidget {
  const _ResponsiveIdentityAction({
    required this.identity,
    required this.action,
  });

  final Widget identity;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 330) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              identity,
              const SizedBox(height: 10),
              Align(alignment: Alignment.centerRight, child: action),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(child: identity),
            const SizedBox(width: 8),
            action,
          ],
        );
      },
    );
  }
}

final class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 15, color: foreground),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final class _ResponsiveActions extends StatelessWidget {
  const _ResponsiveActions({required this.primary, required this.secondary});

  final Widget primary;
  final Widget secondary;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 300) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              primary,
              const SizedBox(height: 8),
              secondary,
            ],
          );
        }
        return Row(
          children: <Widget>[
            Expanded(child: primary),
            const SizedBox(width: 10),
            Expanded(child: secondary),
          ],
        );
      },
    );
  }
}
