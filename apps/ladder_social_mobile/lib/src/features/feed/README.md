# Mobile Feed V2

This feature presents friends' explicitly shared task activity in the compact layout from the Ladder Social seminar mock-up.

`feed_screen.dart` owns page state, selected date, search, refresh, pagination, grouping and the protected proof viewer. `feed_widgets.dart` contains reusable visual components for:

- one compact card per friend;
- a header with avatar, display name, latest shared-activity time, completed count and streak;
- category-coloured task rows;
- the connected checkbox rail from the original design;
- unfinished shared tasks;
- completed tasks without proof;
- completed tasks with unseen proof;
- completed tasks with viewed proof;
- the Snapchat-style proof viewer with task title and caption.

The header's relative time describes the friend's latest shared feed activity. It is not an online-presence indicator because the current domain does not collect presence data.

The screen receives all privacy-sensitive and calculated data from the API. Flutter does not calculate friend scores, infer friendship access, or download proof media before the user explicitly opens a task that contains proof.

See [`docs/feed-v2.md`](../../../../../../docs/feed-v2.md) for the API contract, scheduling rules, privacy behaviour and test procedure.
