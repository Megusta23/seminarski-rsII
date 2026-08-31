# Review Phase 2A: chat friendship rules and live notifications

This phase addresses review items 8, 9, and 10.

## Direct-message authorization

Direct-conversation history remains available to existing participants after a
friendship is removed. Every new send operation rechecks the current friendship
inside the database transaction. When the users are no longer friends, the API
returns HTTP 403 and does not create a message, attachment, or notification.

Conversation responses expose `canSendMessages`. The mobile chat screen polls
that value together with the message list, keeps history visible, and disables
the composer when the direct conversation becomes read-only.

## Privacy-safe chat notifications

A valid message may contain up to 4000 characters, while notification bodies
have a lower database limit. New-message notifications therefore never copy the
full chat content. They use one of these short messages:

- `<display name> sent you a message.`
- `<display name> sent you an image.`

This avoids length failures and prepares the notification path for future E2E
encryption, where the server must not have plaintext message content.

## Automatic notification-list refresh

The open mobile notification list polls its own first page every 10 seconds.
Polling pauses when the application leaves the foreground and resumes
immediately when the application becomes active. Pull-to-refresh remains as a
manual fallback.

The focused widget test uses a shorter injected interval to verify that the
visible list changes without a user refresh gesture.

## Verification

```bash
./scripts/test-review-chat-notifications.sh

cd packages/ladder_social_core
flutter test test/chat_models_test.dart

cd ../../apps/ladder_social_mobile
flutter test test/notifications_auto_refresh_test.dart
```

The HTTP smoke test verifies:

- a 4000-character message succeeds;
- the notification contains a short generic body;
- conversation history remains readable after unfriend;
- conversation metadata becomes read-only after unfriend;
- sending after unfriend returns HTTP 403;
- refriending reuses and re-enables the existing conversation.
