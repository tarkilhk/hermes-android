# Answer actions

The profile workspace displays **Branch in new session** and **Regenerate
response** below saved assistant answers. A turn with alternate answers also
displays previous/next buttons and a position such as `1 / 2`.

Branching copies the conversation through the chosen answer and opens the new
session. Regeneration copies that boundary into a new server session, then
regenerates the original prompt in the copy. The original session and its later
conversation remain available. Switching versions switches the active server
session, so subsequent messages use the selected answer's context.

Version links persist in Android preferences, scoped by connection and canonical
profile. They contain session IDs and turn positions, not message text. The
answers themselves remain in Hermes history. Alternate sessions are also visible
in Chats. Version grouping is local to this Android installation; it does not
sync the desktop client's version picker.

## Gateway contract

The client resolves the selected saved message ID against `session.history`,
then calls `session.branch` with the runtime ID and visible-message `count`.
It verifies the returned profile, durable ID, and copied boundary. Tool rows do
not consume a branch count. Displayed page positions never determine the cut.
Version controls bind to saved answer IDs and remain available after history
pagination, reconnect, and regeneration rewrite those IDs.

Regeneration resolves the copied prompt's durable `row_id` from the child's
history. Only the child receives `prompt.submit` with `truncate_before_row_id`,
`confirm_truncate`, and `confirm_empty_truncate`. Missing addresses and rejected
requests fail visibly. A rejected attempt is removed from the version picker;
its saved copy remains reachable in Chats. An uncertain submission retains its
links and reconnects without automatically submitting again.

Contracts were checked against the public Hermes implementations of
[session branching](https://github.com/NousResearch/hermes-agent/blob/main/tui_gateway/methods_session.py)
and [desktop rewind submissions](https://github.com/NousResearch/hermes-agent/blob/main/apps/desktop/src/app/session/hooks/use-prompt-actions/rewind.ts)
on 2026-09-07. Older gateways missing these contracts are not silently emulated.

## Verification

`test/answer_versions_test.dart` covers answer boundaries, tool rows, repeated
regeneration, later turns, continuation context, persistence, profile isolation,
navigation races, duplicate taps, paged and stale history, missing row IDs, rejected and
uncertain submissions, and the rendered controls on narrow screens.

These tests use a deterministic gateway double. They do not establish live-model
compatibility with a particular installed Hermes server.

The initial implementation passed 990 tests and built a debug APK on 2026-09-07.
Before merge, the feature was ported onto the newer profile workspace on main,
preserving its Markdown rendering, connection identity, and paginated transcript.
The 13 answer-version tests pass on that version, and full static analysis is
clean. The pull request records the final regression and build results.
