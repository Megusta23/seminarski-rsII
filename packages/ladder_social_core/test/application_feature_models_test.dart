import 'package:flutter_test/flutter_test.dart';
import 'package:ladder_social_core/ladder_social_core.dart';

void main() {
  test('task details and completion models parse the API contract', () {
    final TaskDetail task = TaskDetail.fromJson(<String, dynamic>{
      'id': 'task-id',
      'title': 'Finish the seminar',
      'description': 'Implement all required milestones.',
      'taskCategoryId': 'category-id',
      'categoryName': 'Work',
      'categoryCode': 'work',
      'recurrenceTypeId': 'recurrence-id',
      'recurrenceName': 'Daily',
      'recurrenceCode': 'daily',
      'dueAtUtc': '2026-08-25T18:00:00Z',
      'status': 1,
      'requiresProofImage': true,
      'shareWithFriends': true,
      'createdAtUtc': '2026-08-20T12:00:00Z',
      'updatedAtUtc': null,
      'recentCompletions': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'completion-id',
          'taskId': 'task-id',
          'occurrenceDate': '2026-08-20',
          'completedAtUtc': '2026-08-20T12:30:00Z',
          'note': 'Done',
          'scorePoints': 1,
          'proofMediaId': 'proof-id',
          'proofUrl': '/api/media/task-proofs/proof-id',
          'postId': 'post-id',
        },
      ],
    });

    expect(task.title, 'Finish the seminar');
    expect(task.status, TaskStatus.active);
    expect(task.recentCompletions.single.occurrenceDate, DateTime(2026, 8, 20));
    expect(task.recentCompletions.single.proofMediaId, 'proof-id');
  });

  test('feed and recommendation models preserve social explanations', () {
    final FeedPost post = FeedPost.fromJson(<String, dynamic>{
      'id': 'post-id',
      'authorUserId': 'author-id',
      'authorDisplayName': 'Hasan Brkic',
      'authorAvatarUrl': null,
      'taskId': 'task-id',
      'taskTitle': 'Run smoke tests',
      'categoryName': 'Work',
      'caption': 'All green.',
      'completedAtUtc': '2026-08-20T15:00:00Z',
      'proofMediaId': null,
      'proofUrl': null,
      'hasBeenViewed': false,
    });
    final FriendRecommendation recommendation = FriendRecommendation.fromJson(
      <String, dynamic>{
        'userId': 'recommended-id',
        'displayName': 'Recommended User',
        'avatarUrl': null,
        'mutualFriendCount': 3,
        'explanation': 'Recommended because you have 3 mutual friends.',
      },
    );

    expect(post.hasBeenViewed, isFalse);
    expect(recommendation.mutualFriendCount, 3);
    expect(recommendation.explanation, contains('3 mutual friends'));
  });

  test('chat, notification, leaderboard and admin models parse typed values', () {
    final ChatMessage message = ChatMessage.fromJson(<String, dynamic>{
      'id': 'message-id',
      'conversationId': 'conversation-id',
      'senderUserId': 'sender-id',
      'senderDisplayName': 'Sender',
      'type': 1,
      'content': 'Hello',
      'sentAtUtc': '2026-08-20T16:00:00Z',
      'attachmentId': null,
      'attachmentUrl': null,
      'attachmentMimeType': null,
    });
    final AppNotification notification = AppNotification.fromJson(
      <String, dynamic>{
        'id': 'notification-id',
        'kind': 1,
        'title': 'New friend request',
        'body': 'A user sent you a request.',
        'isRead': false,
        'createdAtUtc': '2026-08-20T16:01:00Z',
        'readAtUtc': null,
        'relatedEntityType': 'FriendRequest',
        'relatedEntityId': 'request-id',
      },
    );
    final LeaderboardResult leaderboard = LeaderboardResult.fromJson(
      <String, dynamic>{
        'fromDate': '2026-08-20',
        'toDate': '2026-08-20',
        'entries': <Map<String, dynamic>>[
          <String, dynamic>{
            'position': 1,
            'userId': 'winner-id',
            'displayName': 'Winner',
            'avatarUrl': null,
            'score': 5,
            'isCurrentUser': true,
          },
        ],
        'currentUser': <String, dynamic>{
          'position': 1,
          'userId': 'winner-id',
          'displayName': 'Winner',
          'avatarUrl': null,
          'score': 5,
          'isCurrentUser': true,
        },
      },
    );
    final AdminDashboard dashboard = AdminDashboard.fromJson(<String, dynamic>{
      'generatedAtUtc': '2026-08-20T16:02:00Z',
      'totalUsers': 10,
      'activeUsers': 9,
      'tasksCreated': 30,
      'tasksCompletedToday': 7,
      'sharedPosts': 5,
      'friendRequests': 4,
      'messages': 12,
      'topUsers': <Map<String, dynamic>>[],
    });

    expect(message.content, 'Hello');
    expect(notification.isRead, isFalse);
    expect(leaderboard.currentUser?.score, 5);
    expect(dashboard.activeUsers, 9);
  });
}
