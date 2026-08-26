import 'package:flutter_test/flutter_test.dart';
import 'package:ladder_social_core/ladder_social_core.dart';

void main() {
  test('friend summary parses mutual-friend and productivity values', () {
    final FriendSummary friend = FriendSummary.fromJson(<String, dynamic>{
      'userId': 'friend-id',
      'displayName': 'Faruk Chaluk',
      'avatarUrl': '/api/media/avatars/friend-id',
      'mutualFriendCount': 4,
      'completedTaskCount': 46,
      'currentStreak': 12,
    });

    expect(friend.mutualFriendCount, 4);
    expect(friend.completedTaskCount, 46);
    expect(friend.currentStreak, 12);
  });

  test('people search parses relationship-aware request identifiers', () {
    final UserSearchItem result = UserSearchItem.fromJson(<String, dynamic>{
      'userId': 'candidate-id',
      'displayName': 'Ajdin Hajdarevic',
      'email': 'ajdin@example.com',
      'avatarUrl': null,
      'isFriend': false,
      'hasOutgoingPendingRequest': false,
      'hasIncomingPendingRequest': true,
      'mutualFriendCount': 3,
      'outgoingRequestId': null,
      'incomingRequestId': 'request-id',
    });

    expect(result.hasIncomingPendingRequest, isTrue);
    expect(result.incomingRequestId, 'request-id');
    expect(result.mutualFriendCount, 3);
  });

  test('outgoing request parses the receiver avatar', () {
    final FriendRequestItem request = FriendRequestItem.fromJson(
      <String, dynamic>{
        'id': 'request-id',
        'senderUserId': 'sender-id',
        'senderDisplayName': 'Hasan Brkic',
        'senderAvatarUrl': null,
        'receiverUserId': 'receiver-id',
        'receiverDisplayName': 'Edhem Kevric',
        'receiverAvatarUrl': '/api/media/avatars/receiver-id',
        'status': FriendRequestStatus.pending,
        'createdAtUtc': '2026-08-26T12:00:00Z',
        'respondedAtUtc': null,
      },
    );

    expect(request.receiverDisplayName, 'Edhem Kevric');
    expect(request.receiverAvatarUrl, '/api/media/avatars/receiver-id');
  });
}
