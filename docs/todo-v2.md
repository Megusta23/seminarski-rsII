# To-do V2

To-do V2 redesigns the current user's task screen around the three sections shown
in the approved application document:

- **To-do's**: tasks whose recurrence code is `none`;
- **Dailies**: tasks whose recurrence code is `daily`;
- **Habits**: weekly, monthly and any other recurring tasks.

The screen intentionally keeps the task title and completion action prominent. A
pastel row color represents the task category:

| Category | Visual treatment |
| --- | --- |
| Creative | Soft peach |
| Social | Mint |
| Self-care | Lavender |
| Work | Powder blue |

## Task states

The right-hand rail reproduces the four document states:

1. unfinished task requiring proof: outlined camera;
2. completed task requiring proof: camera with completion mark;
3. unfinished task without proof: empty square;
4. completed task without proof: check mark.

A task title opens the existing detail screen. The state control performs the
most direct valid action:

- unfinished proof task opens the existing proof-completion flow;
- unfinished no-proof task asks for confirmation and completes today's
  occurrence;
- completed proof task opens the owner's protected proof image when available;
- other completed tasks open task details.

Weekly and monthly tasks that are not scheduled for the current day open their
details instead of bypassing server recurrence validation.

## Create and edit form

The existing API contract is unchanged. The form still captures title,
description, category, recurrence, deadline, proof requirement, sharing and
editable task status. To-do V2 adds:

- document-aligned pastel category choices;
- compact recurrence choices;
- colored schedule and sharing sections;
- a live task-row preview;
- category-colored save action;
- the same color mapping used by Feed V2.

## Backend and database impact

This milestone is a Flutter-only redesign. It does not add a database migration
or change the task API. The task list reads all active and completed task pages
(up to the API's existing 100-item page limit per request) and groups them on the
client using server-provided recurrence codes.

Existing ownership, proof-image validation, recurrence validation, soft-delete,
feed-sharing and protected-media behavior remains authoritative on the server.

## Verification

Run:

```bash
cd apps/ladder_social_mobile
flutter analyze
flutter test test/todo_widgets_test.dart
flutter test test/todo_visuals_test.dart
flutter test

cd ../..
./scripts/test-tasks.sh
./scripts/test-todo-v2.sh
./scripts/test-feed-v2.sh
./scripts/verify-source.sh
```
