# Chat filters and project management

D19/D20 continue the existing chat browser and Activity screen. No local read-state database, project store or new backend service is introduced.

## Filters

Activity offers All, Running and Needs input across the connected server's profiles. These filter the existing `session.active_list` results; they do not infer execution from recent timestamps or whether the phone has opened a chat. Profile failures remain visible and opening a result retains its original owner.

Chats offers Unread only under Workspace options. Unread flags come from server session rows. The current API has no unread query parameter, so this view filters loaded pages and explicitly says when older pages remain. Load more stays available even when no loaded row matches. Title search is limited to those loaded unread rows; it does not merge unrelated full-text results that lack unread metadata. Opening a project, switching profiles or returning to the normal view clears the temporary filter.

## Projects

Project actions are reachable from each project row and the selected project's Workspace options. Rename and appearance changes use `projects.update`; deletion uses `projects.delete`. Requests retain the captured host/profile/project owner, and the browser refreshes the server's project list after acknowledgement.

Deleting a project removes its organization, not its saved conversations. Desktop's inspected store returns surviving sessions to Recents. The phone asks for confirmation before deletion. Existing creation, project membership and return-to-all-chats flows remain in use.

Appearance displays server icon/color metadata with a fallback for values Android cannot render. Editing appearance changes that project on the server and is visible to other clients. The client's selected profile remains independent.

## Verification

The owner's 2026-09-12 screenshot feedback also refines D15 in this batch: the context fuse sits on the message box's existing top edge, with a small dot at the current usage position. It adds no separate row. Server-reported usage, thresholds, unknown/estimated states and accessibility labels remain unchanged.

Release target: Personal `2.3.0+2150`, ARM64 code `21502`. Full suite: 984 passed, four opt-in skips; analyzer clean. The five project dialog tests also passed after simplifying their fixture. Tests cover unread pagination and Activity filtering, project write acknowledgements, failures and owner isolation, fuse endpoint geometry and its placement on the composer edge. Final build and phone installation are recorded in the delivery sequence after completion. Live behavior on the owner's gateway remains unverified.
