import 'package:flutter_test/flutter_test.dart';
import 'package:ladder_social_core/ladder_social_core.dart';

void main() {
  test('own profile overview parses social statistics and highlights', () {
    final OwnProfileOverview profile = OwnProfileOverview.fromJson(
      <String, dynamic>{
        'userId': 'user-id',
        'displayName': 'Hasan Brkic',
        'bio': 'Building better habits.',
        'avatarUrl': '/api/media/avatars/user-id',
        'cityName': 'Mostar',
        'memberSinceUtc': '2026-06-01T10:00:00Z',
        'visiblePostCount': 4,
        'friendCount': 12,
        'completedTaskCount': 46,
        'habitCount': 3,
        'currentStreak': 7,
        'highlightedPosts': <Map<String, dynamic>>[
          <String, dynamic>{
            'postId': 'post-id',
            'taskId': 'task-id',
            'taskTitle': 'Go for a hike',
            'caption': 'Outside today.',
            'categoryName': 'Self-care',
            'categoryCode': 'self-care',
            'proofMediaId': 'proof-id',
            'proofUrl': '/api/media/task-proofs/proof-id',
            'completedAtUtc': '2026-08-25T09:30:00Z',
            'highlightedAtUtc': '2026-08-25T10:00:00Z',
          },
        ],
      },
    );

    expect(profile.displayName, 'Hasan Brkic');
    expect(profile.friendCount, 12);
    expect(profile.currentStreak, 7);
    expect(profile.highlightedPosts.single.postId, 'post-id');
  });
}
