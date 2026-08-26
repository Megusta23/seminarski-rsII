# Friends feature

This module contains Friends V2, people search, friend requests, accepted friends, graph-based recommendations and Friend Profile V2.

Friends V2 provides:

- polished Friends, Requests and Discover sections;
- immediate UI removal of accepted, declined and cancelled requests;
- immediate insertion of newly accepted friends;
- per-card processing state that prevents double actions;
- relationship-aware people search;
- friend productivity summaries, profile and message actions;
- graph-based suggestions with backend explanations;
- pull-to-refresh and clear loading, empty and error states.

Friend Profile V2 remains friend-only and presents avatar, biography, social counts, mutual friends, streak, task completion statistics, habits and secure highlighted proof posts.

All relationship mutations remain server-authorized. Flutter updates local state for responsiveness, then reloads the authoritative API data.
