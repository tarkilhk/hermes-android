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
then finds that ID in paginated stored history, including compaction-archived
rows. `session.branch` receives the runtime ID and the stored user/assistant
row count through that answer. Hidden system notices consume a count even
though `session.history` omits them. Counting only visible messages cut forks
short and left failed copies in Chats.
It verifies the returned profile, durable ID, and copied boundary. Tool rows do
not consume a branch count. Displayed page positions never determine the cut.
Version controls bind to saved answer IDs and remain available after history
pagination, reconnect, and regeneration rewrite those IDs.

Raw rows remain in the paginated history cache. The transcript hides system
notices and rows marked `display_kind: hidden`, including after continuation.
Missing saved boundaries fail before creating a child.

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

The unit tests also cover hidden notices, boundaries beyond 500 stored rows,
multimodal content, and another fork after continuation. The opt-in
`test/answer_branch_live_test.dart` reproduces the hidden-notice failure against
the installed local gateway without model calls.

`integration_test/answer_branch_live_test.dart` uses the real Android buttons to
fork at the first, middle, and last answers. It reloads each saved child through
a fresh socket, asks Luna to recall context from the middle fork, and forks the
continued child again. It verifies that the source transcript stays unchanged.
Both live tests use the existing disposable `android-qa-a` profile and require
`--dart-define=HERMES_TEST_PORT=<local gateway port>`. Forward that port with ADB
reverse before running the emulator test.

The initial implementation passed 990 tests and built a debug APK on 2026-09-07.
Before merge, the feature was ported onto the newer profile workspace on main,
preserving its Markdown rendering, connection identity, and paginated transcript.
The 13 answer-version tests pass on that version, and full static analysis is
clean. The pull request records the final regression and build results.

The fork-boundary repair was checked on the current main branch with 1,132
passing tests and four opt-in tests skipped. Full static analysis passed. The
dedicated live gateway reproduction passed separately with hidden notices in
the source history.
