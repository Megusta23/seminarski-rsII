import 'package:flutter_test/flutter_test.dart';
import 'package:ladder_social_core/ladder_social_core.dart';

void main() {
  test('friend profile parses statistics, mutual friends and highlights', () {
    final FriendProfile profile = FriendProfile.fromJson(<String, dynamic>{
      'userId': 'friend-id',
      'displayName': 'Faruk Chaluk',
      'bio': 'Building better habits one day at a time.',
      'avatarUrl': '/api/media/avatars/friend-id',
      'cityName': 'Mostar',
      'memberSinceUtc': '2026-06-15T09:00:00Z',
      'visiblePostCount': 4,
      'friendCount': 122,
      'completedTaskCount': 46,
      'habitCount': 3,
      'currentStreak': 12,
      'canMessage': true,
      'mutualFriends': <String, dynamic>{
        'count': 3,
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'userId': 'mutual-id',
            'displayName': 'Ajdin',
            'avatarUrl': null,
          },
        ],
      },
      'highlightedPosts': <Map<String, dynamic>>[
        <String, dynamic>{
          'postId': 'post-id',
          'taskId': 'task-id',
          'taskTitle': 'Go for a hike',
          'caption': 'A productive afternoon outside.',
          'categoryName': 'Self-care',
          'categoryCode': 'self-care',
          'proofMediaId': 'proof-id',
          'proofUrl': '/api/media/task-proofs/proof-id',
          'completedAtUtc': '2026-08-24T16:30:00Z',
          'highlightedAtUtc': '2026-08-25T08:00:00Z',
        },
      ],
    });

    expect(profile.displayName, 'Faruk Chaluk');
    expect(profile.currentStreak, 12);
    expect(profile.completedTaskCount, 46);
    expect(profile.habitCount, 3);
    expect(profile.mutualFriends.count, 3);
    expect(profile.mutualFriends.items.single.displayName, 'Ajdin');
    expect(profile.highlightedPosts.single.taskTitle, 'Go for a hike');
    expect(profile.highlightedPosts.single.caption, contains('afternoon'));
  });

  test('highlight candidate copies selected state without changing identity', () {
    final ProfileHighlightCandidate candidate =
        ProfileHighlightCandidate.fromJson(<String, dynamic>{
      'postId': 'post-id',
      'taskId': 'task-id',
      'taskTitle': 'Finish the seminar',
      'caption': null,
      'categoryName': 'Work',
      'categoryCode': 'work',
      'proofMediaId': 'proof-id',
      'proofUrl': '/api/media/task-proofs/proof-id',
      'completedAtUtc': '2026-08-25T12:00:00Z',
      'isHighlighted': false,
      'highlightedAtUtc': null,
    });

    final ProfileHighlightCandidate selected =
        candidate.copyWithHighlighted(true);

    expect(selected.postId, candidate.postId);
    expect(selected.taskId, candidate.taskId);
    expect(selected.isHighlighted, isTrue);
    expect(selected.highlightedAtUtc, isNotNull);
  });
}
