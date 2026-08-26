# Tasks / To-do V2

The task feature contains the document-aligned personal To-do board, task
details, create/edit form and completion flow.

`tasks_screen.dart` loads all active and completed task pages, groups tasks as
To-do's, Dailies and Habits, and keeps the current collapse state while the user
moves between bottom-navigation tabs.

`todo_widgets.dart` owns the visual board: section headers, counts, pastel rows,
right-side rails, completion controls, loading skeletons and responsive layout.

`todo_visuals.dart` is the single source of truth for category colors, recurrence
section mapping and the four completion/proof states.

The create/edit screen contains the colored work-block selector, styled schedule
and sharing controls, and uses `TodoTaskPreview` for its live row preview.

The four visible task states are:

- unfinished with required proof;
- completed with proof;
- unfinished without proof;
- completed without proof.

The existing backend task, ownership, recurrence, proof-media and feed behavior
remains authoritative. The direct no-proof completion action still calls the
normal task-completion endpoint, while proof-required tasks reuse the existing
camera/gallery flow.

`task_proof_viewer_screen.dart` opens the owner-authorized proof image for a
completed proof task without exposing media outside the existing protected
endpoint.

Run `scripts/test-todo-v2.sh` after the general task smoke test to verify the
recurrence codes and completion flags that drive the three sections and four
visual states.
