# Chat filters and project management

D19/D20 continue the existing chat browser and Activity screen. No local read-state database, project store or new backend service is introduced.

## Filters

Activity offers All, Running and Needs input across the connected server's profiles. These filter the existing `session.active_list` results; they do not infer execution from recent timestamps or whether the phone has opened a chat. Profile failures remain visible and opening a result retains its original owner.

Chats offers Unread only under Workspace options. Unread flags come from server session rows. The current API has no unread query parameter, so this view filters loaded pages and explicitly says when older pages remain. Load more stays available even when no loaded row matches. Title search is limited to those loaded unread rows; it does not merge unrelated full-text results that lack unread metadata. Opening a project, switching profiles or returning to the normal view clears the temporary filter.

## Projects

Project actions are reachable from each project row and the selected project's Workspace options. Rename and appearance changes use `projects.update`; deletion uses `projects.delete`. Requests retain the captured host/profile/project owner, and the browser refreshes the server's project list after acknowledgement.

Deleting a project removes its organization, not its saved conversations. Desktop's inspected store returns surviving sessions to Recents. The phone asks for confirmation before deletion. Existing creation, project membership and return-to-all-chats flows remain in use.

Appearance displays server icon/color metadata with a fallback for values Android cannot render. Editing appearance changes that project on the server and is visible to other clients. The client's selected profile remains independent.

## Chat deletion, 2026-09-12

Confirmed Delete now closes an idle Hermes runtime before deleting the chat's
stored history. Previously Android rejected every matching entry in
`session.active_list`, including idle chats, with "Close it before deleting."
Returning to Chats does not close a runtime, so this blocked ordinary deletion.

The live list does not identify profile ownership. When a durable ID is open,
Android uses profile-scoped `session.resume`, verifies the returned profile and
stored ID, and checks the returned runtime in a fresh live list. Only an explicit
`idle` status permits `session.close`; working, starting, waiting and unknown
states remain blocked. After an acknowledged close, the existing profile-scoped
REST delete removes the history. Failed requests preserve the visible chat for
retry, and cancelling the confirmation sends no close or delete request.

The installed Hermes source confirms that idle runtimes appear in the live list,
that `session.close` returns `closed`, and that REST deletion removes the database
row without closing a runtime. Desktop also closes a known runtime before REST
deletion. The status check and close are separate server requests, so another
client can still start work between them. No server changes were made.

Controller and widget regression tests cover idle deletion, close-before-delete
ordering, busy and unknown states, profile/ID collisions, failures and retry.
These checks use authored fixtures; deletion on the owner's phone and gateway
has not been exercised.

Release checks for Personal `2.5.1+2153`: full suite 1,011 passed with four opt-in
live tests skipped; Flutter analysis reports no issues. `dart pub outdated`
was reviewed and the existing lockfile retained for this fix. The initial direct
Dart analyzer hit a Windows performance-pipe shutdown error; rerunning through
Flutter completed successfully. Phone installation and live smoke results are
reported separately from these automated checks.

Follow-up for `2.5.2+2154`: the owner's "Explorer le sens de gauche" attempt
exposed a second response shape. Hermes's `_resume_reuse_live_locked` calls
`_live_session_payload`, returning `session_key` and `resumed`, without
`stored_session_id`. The original fixture modeled only a fresh runtime. A test
using the reused-runtime shape reproduced `FormatException: Session response
has a different chat`, which the browser displayed as its generic retry message.
Deletion now accepts either durable-ID field and rejects conflicting fields.
All 32 chat-action tests pass, including the confirmed-delete widget test using
the reused-runtime response. This reproduces the contract error locally; it
does not claim a captured response from the owner's remote gateway.

## Verification

The owner's 2026-09-12 screenshot feedback also refines D15 in this batch: the context fuse sits on the message box's existing top edge, with a small dot at the current usage position. It adds no separate row. Server-reported usage, thresholds, unknown/estimated states and accessibility labels remain unchanged.

Release target: Personal `2.3.0+2150`, ARM64 code `21502`. Full suite: 984 passed, four opt-in skips; analyzer clean. The five project dialog tests also passed after simplifying their fixture. Tests cover unread pagination and Activity filtering, project write acknowledgements, failures and owner isolation, fuse endpoint geometry and its placement on the composer edge. Final build and phone installation are recorded in the delivery sequence after completion. Live behavior on the owner's gateway remains unverified.
