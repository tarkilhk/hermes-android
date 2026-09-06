# Windows profile workspace verification

Checkpoint on 2026-09-06, Prestige. This is working profile-aware development,
not full acceptance of every scenario in `WINDOWS_HANDOFF.md`.

## Environment

- Checkout: `C:\Users\rober\Development\hermes-android`, outside OneDrive.
- Flutter 3.44.0, Dart 3.12.0, JDK 17, Android SDK 36.
- Native `Hermes_API_36` emulator, Android 16, `emulator-5554`.
- Installed Hermes Desktop reports v0.21.0 +65, commit `b499ab1`.
- Local gateway tested at `http://127.0.0.1:65243`. This Desktop-managed port
  may change after restart. Authentication is fetched by the client, not stored
  in this document or command arguments.
- Disposable profiles: `android-qa-a` and `android-qa-b`.

The installed Hermes source remains unmodified. No changes to the separate
remote production gateway were made.

## Verified

- `flutter analyze --no-pub`: no issues.
- Full unit/widget suite at the initial checkpoint: 976 passed, one opt-in live
  test skipped. See the connection/recovery follow-up below for the newer run.
- Normal debug APK builds and installs successfully.
- Opt-in host contract test passes against both actual QA profiles. It verifies
  authenticated discovery, scoped sessions/projects, session creation and file
  attachment without a model call.
- Emulator no-model test passes, including project creation/reuse, authoritative
  project session membership, attachment preparation, profile switching and
  reconnect.
- One bounded live-model emulator test passed. It submits an attached text file
  under A, navigates to B, waits for A's completion, returns to A, checks the exact
  `ANDROID_PROFILE_QA` result and reconnects without submitting again. The test
  now also records the visible profile at completion; rerun the model variant
  to verify that strengthened assertion.
- Computer Use verified the normal installed app's connection setup, profile
  selector, A's session list and recovered conversation with the expected answer.
- Native notification delivery and tapping passed on the emulator after the owner
  granted notification permission. The no-model `profile_notification_test.dart`
  posts a clearly labelled QA notification through the production sink while B
  is visible. Tapping it reopened the original A session, confirmed by the
  device assertion and Computer Use. The fixture tests native transport/navigation,
  not generation of a completion event by a model.
- A second short real prompt returned `NOTIFICATION_QA`. It completed before
  backgrounding, so it was not counted as native notification verification.

The controller's deterministic tests cover identical IDs across profiles, late
switch results, failed/deleted-profile selection, project ownership, background
approval routing, completion errors, final-text retention after failed history
refresh, stock inflight recovery and preservation of unavailable pending owners.

## Repeat the live checks

Use the PowerShell toolchain setup in `LOCAL_BUILD_SETUP.md`, then:

```powershell
$adb = 'C:\Users\rober\Development\android-dev\android-sdk\platform-tools\adb.exe'
& $adb reverse tcp:65243 tcp:65243
& $flutter test test/profile_live_contract_test.dart --dart-define=HERMES_TEST_PORT=65243
& $flutter test integration_test/profile_workspace_test.dart -d emulator-5554 --dart-define=HERMES_TEST_PORT=65243 --dart-define=HERMES_TEST_PROJECT=C:/Users/rober/Development/hermes-android
```

Adding `--dart-define=RUN_MODEL=true` submits one real prompt on each run. Do not
use it for an unbounded retry loop. Model used in the verified run was the QA
profile's configured `openai-codex` / `gpt-5.6-luna`.

Local logs are in ignored `build/`: `milestone-tests.log`, `milestone-apk.log`,
`profile-emulator-test.log` and `profile-emulator-model-test.log`.

For the no-model native notification test, build the target
`integration_test/profile_notification_test.dart` with the same port define,
install using `adb install -r`, and launch the app. This preserves the existing
notification permission. Tap the labelled QA notification within 120 seconds.
The device log emits `[notification-qa] PASS` after checking the original owner.
Restore the normal APK built with `-t lib/main.dart` afterward.

## Remaining acceptance and implementation limits

- Exercise a real tool approval (Allow once/Deny). Real clarification input and
  Android process termination while awaiting input now pass as described below.
- Test termination during token streaming and attachment upload as separate cases.
- An edited connection retains its original running clients in memory, but the
  replacement cannot restore those owners after process death. Restoring the exact
  original endpoint/auth settings makes their separate journals eligible again.
- Add history pagination and richer transcript/attachment rendering. Session
  list paging is covered in the follow-up below.
- Root/project navigation now uses the owner's Android screenshots. Conversation,
  approval, and output-viewer visual references remain to be supplied.
- Stock Hermes can resolve a profile deleted between discovery and an RPC to the
  launch context. Android revalidates profiles before writes, but cannot close
  that server-side race. No compatibility fallback or local server patch is used,
  and strict deletion-race isolation is not claimed.

Profile switching does not change the server's sticky active profile. New app
routes use the stock modern profile-aware gateway; older unscoped UI modules are
not a runtime fallback for these routes.

## Connection ownership and process recovery follow-up, 2026-09-06

Connection ownership now includes the saved ID plus endpoint/authentication
settings, represented by an HMAC-SHA256 identity keyed by a random 32-byte secret
in Android secure storage. Labels do not partition ownership. The application
registry, profile selection, pending journals, and notification targets use this
identity. Opening a workspace reloads saved credentials; an older Home snapshot cannot
silently select an old authenticated client. Old notifications are rejected before
gateway I/O when their endpoint or credentials no longer match.

Existing v1 pending journals and notifications lack endpoint/auth ownership and
are deliberately not rebound to current settings. They are not deleted, and
server conversations remain accessible through their correct connection/profile.
There is no server-compatibility fallback or modification to installed Hermes.

Verified on the same stock local gateway and emulator:

- Final `flutter analyze --no-pub`: no issues. Full unit/widget suite: 992 passed,
  one opt-in live test skipped. Normal `lib/main.dart` debug APK built and installed.
- Unit tests cover endpoint/credential changes, label-only changes, secure-key
  failure, config import, duplicate IDs, pending-owner isolation, stale notification
  rejection before gateway traffic, and process recreation without prompt replay.
- The no-model emulator acceptance test passed with real Android secure storage:
  edited endpoint got a separate controller; the old session was rejected; the
  original client remained bound to port 65243. The QA connection was restored.
- A real `clarify` request exposed stock batch questions (`questions`, `qid`, and
  replayed `answers`). Android now displays the next unanswered question and sends
  its `question_id`, retains remaining questions, and handles expired requests.
- Closing Reply exposed premature `TextEditingController` disposal during the
  dialog exit animation. A failing widget test reproduced it; the field now owns
  its controller lifetime and the regression passes.
- Two bounded QA prompts were used. The first recovered after process termination
  and returned the exact marker, but its test failed on the dialog exception; it
  is not counted as a clean end-to-end pass. No prompt was resent during debugging.
- The clean second run (`20260906-verified`) passed: PID 4363 waited for real input
  in A with B visible, was force-stopped, and PID 4438 restored the original owner.
  The actual Reply dialog submitted `PROCESS_RECOVERY_QA`; the final assistant
  response matched exactly and history contained one original user prompt.
  Device result: `00:09 +2: All tests passed!`, with no UI exceptions.
- Computer Use inspected and answered the first recovered batch question after
  the batch fix. The clean rerun drove the same dialog through Flutter's device
  test harness. Notification permission remained granted throughout.

Local evidence: `build/connection-safety-full-tests.log`,
`build/connection-safety-final-focused.log`, `build/clarification-regression.log`,
`build/clarification-dialog-red.log`, `build/recovery-qa-final-result.log`,
`build/connection-recovery-full-tests.log`, and `build/connection-recovery-normal-apk.log`.

To repeat process recovery, build `integration_test/profile_process_recovery_test.dart`
with `HERMES_TEST_PORT`, a new `RECOVERY_RUN_ID`, and explicit `RUN_MODEL=true`.
`AUTO_ANSWER=true` drives the real Reply dialog after restart; otherwise answer
through the emulator UI. Install with `adb install -r`, launch, wait for
`READY_FOR_PROCESS_STOP`, force-stop only this Android package, and launch the
same APK again. The checkpoint is written before submission so relaunch cannot
create another prompt. A completed run ID cannot start a new turn. Each new run
ID with `RUN_MODEL=true` authorizes one real model turn; do not loop indefinitely.
Always restore the normal APK built with `-t lib/main.dart` afterward.

## Screenshot-driven navigation pass, 2026-09-06

The owner moved UI work ahead of pagination and supplied the actual Codex Remote
Android root/project screenshots. The navigation pass replaces the separate
Chats/Projects tabs with one tree: profile chips, five recently active projects,
pinned chats, and recent chats. See all opens the complete loaded project list.
Project entry shows only the server's project-session membership. The bottom bar
contains search over loaded rows and new chat; the menu retains Activity, new
project, refresh, and notification enablement. No voice button is imitated.

Project recency comes directly from the modern `projects.tree` overview's
`lastActive`, not from local folder guesses. The synthetic Home bucket is not
shown as a project. No `projects.list` fallback is used. Chats use `last_active`
and pinned rows are not repeated in Recents. Profile navigation refreshes the
tree and resets old project/chat navigation while keeping active work owned by
the application controller.

Verification:

- Full unit/widget suite: 998 passed, one opt-in live test skipped.
- Final Flutter analysis found no issues. The normal debug APK was rebuilt,
  installed with notification permission preserved, and launched on the emulator.
- Five new widget tests cover project ordering/top-five display, section order,
  project-only membership, Back, search, profile switching during a pending load,
  and truthful project-read errors.
- The opt-in no-model host contract test passed using the new tree RPC against
  the unchanged local Hermes server.
- The no-model emulator acceptance test passed through the redesigned screen:
  project membership, attachment preparation, profile switching, reconnect and
  edited-connection isolation. Device result: `00:08 +2: All tests passed!`.
- Populated home/project views were inspected on the Android emulator using an
  explicitly labelled authored-data preview. The preview is a separate debug
  target, never imported by the production app and never connected to Hermes.
  Spacing was tightened after the initial captures.
- No model prompts or backend patches were used for this UI pass. Pagination
  remains deferred; search covers loaded chats, not the entire server archive.

Evidence is in ignored `build/ui-full-tests.log`, `build/ui-live-contract.log`,
`build/ui-emulator-result.log`, and `build/ui-final-focused.log`. Initial preview
captures are `build/hermes-ui-home.png` and `build/hermes-ui-project.png`.
The normal app with real local gateway data is captured in `build/hermes-ui-live.png`.
The preview can be rebuilt with `-t integration_test/profile_workspace_preview.dart`;
always reinstall the normal `lib/main.dart` APK after inspecting it.

## Session pagination follow-up, 2026-09-06

All chats uses the stock profile-scoped REST listing with `limit=50`, `offset`,
and `order=recent`. The next offset advances by the server page size, not the
number of returned rows: Hermes back-fills all pinned sessions on every page.
Android deduplicates by session ID within the immutable connection/profile owner.
Errors preserve rows and the failed offset for retry. Navigation, refresh, and
profile switching invalidate in-flight page publication without closing sockets
or interrupting running turns. Pull-to-refresh restarts at page zero. Offset
pagination is not a snapshot: concurrent new activity can move rows between
pages; refresh retrieves a new first page.

Project membership still comes only from `projects.project_sessions`. The stock
handler has no offset/cursor and scans the latest 5,000 eligible sessions across
the profile by default. Android explicitly requests that limit, progressively
reveals returned members, and states the limit at the end of the list. It does
not invent a project paging route, increase the server scan without bounds, or
guess membership from directory prefixes. Pin flags omitted by this RPC are
overlaid only on returned project members using the REST listing's pins.

Protocol evidence was read from the installed, unchanged Hermes source:
`hermes_cli/web_routers/sessions.py`, `hermes_state_sessions.py`,
`tui_gateway/methods_config.py`, and `tui_gateway/methods_projects.py`.

Fourteen new tests cover paging beyond 100 rows, pinned back-fill, duplicate
scroll requests, retry, refresh races, A/B/A races, project navigation, a changing
offset window, empty/exact page boundaries, malformed metadata, and lazy project
display, and a failed profile switch while the original project is loading.
The production read-only emulator check is
`integration_test/profile_pagination_readonly_test.dart`, selected by
`PAGING_CONNECTION_LABEL` and `PAGING_EXPECTED_HOST`. It reads credentials from
the app's secure store and logs counts, not conversation titles or credentials.
It makes no model calls or server mutation requests, and bounds each profile to
40 pages. Project results retain the stock 5,000-session scan limit.

The owner requested real production data instead of a seeded local volume test.
Their confirmed production connection was saved as `Prod Claw` through the normal
Android connection form. Dashboard authentication and the profile/gateway probe
passed with the inference API key left blank. The password is in Android secure
storage, not plaintext connection preferences, source, or test defines.

The read-only emulator check passed on all four actual production profiles:

| Profile index | Unique chats | REST pages | Pins | Largest returned project |
| --- | ---: | ---: | ---: | ---: |
| 1 | 1,311 | 27 | 3 | 259 |
| 2 | 54 | 2 | 1 | 5 |
| 3 | 23 | 1 | 0 | 6 |
| 4 | 1,187 | 24 | 0 | 6 |

All four lists reached the server's final page. The 259-chat project scrolled
beyond its first 100 members; the list revealed 250 chat rows plus its load-more
control during the assertion. Real pending-page profile navigation also passed.
The final device result was `00:34 +2: All tests passed!`. Logs use profile indexes
and counts rather than private conversation titles. No dummy data, model calls,
or server mutation requests were used in production.

Local evidence: `build/pagination-tests.log`, `build/pagination-full-tests.log`,
`build/pagination-analyze.log`, `build/pagination-prod-result.log`, and
`build/pagination-normal-apk.log`. Screenshots and logs remain ignored by Git.

Final full suite: 1,012 passed, one opt-in test skipped. Flutter analysis is
clean. The normal debug APK was rebuilt and reinstalled with `Prod Claw` saved;
the read-only test APK is not left installed. Notification permission and all
previous saved connections were preserved.

## History pagination and profile search, 2026-09-06

History now opens at the newest 50 durable rows and loads older pages on upward
scroll, with explicit load/retry controls. It uses the unchanged Desktop contract:
`session.resume` with `omit_messages=true`, followed by profile-scoped REST
`messages` reads with `order=latest` and `include_compacted=true`. These reads
resolve the current compression segment; traversal of ancestor segments is not
implemented. Offset pages can overlap when new rows arrive. Durable row IDs
deduplicate overlaps, and latest-tail refresh preserves an overlapping older
prefix. A reversed lazy transcript keeps a visible row anchored through older
page insertion and streaming growth and remembers each chat's scroll offset.

Root search is debounced and calls the stock profile-scoped `/sessions/search`
endpoint for chat IDs and message content, including archived chats. Loaded
title matches supplement server results, but global title search is not claimed.
Archived results are labelled. The server caps results at 100 and has no search
cursor; the UI reports that limit. Search and history generations discard stale
responses after navigation, profile changes, or newer requests. Failures retain
useful rows and expose retry controls instead of presenting a false empty state.

The new read-only emulator acceptance test is
`integration_test/profile_history_search_readonly_test.dart`. It reads the saved
`Prod Claw` credentials from Android secure storage and does not call
`session.resume`, send prompts, or mutate server data. It tests message reads
through a test-only transcript without attaching a runtime. No Hermes source or
production configuration was changed.

Actual production results:

| Profile index | History rows loaded | History pages | Older rows remain | Content matches |
| --- | ---: | ---: | --- | ---: |
| 1 | 600 | 12 | Yes | 100 (server cap) |
| 2 | 551 | 12 | No | 61 |
| 3 | 144 | 3 | No | 27 |
| 4 | 600 | 12 | Yes | 84 |

All three profiles with more than one chat-list page returned an ID search match
outside their first loaded page. All histories had unique durable IDs, preserved
the initial newest page, rendered and scrolled without widget errors, and kept
their older prefix on refresh. The device result was
`00:24 +2: All tests passed!` across all four production profiles.

Eleven new unit/widget tests cover history beyond 500, overlapping windows,
refresh/retry races, A/B/A profile ownership, unloaded archived search matches,
query races, debounce, errors, and visible-row/scroll restoration. Full suite:
1,023 passed, one opt-in test skipped. Flutter analysis found no issues.
Evidence remains in ignored `build/history-search-tests.log`,
`build/history-search-full-tests.log`, `build/history-search-analyze.log`, and
`build/history-search-prod-result.log`. Logs contain counts, not conversation
titles, message bodies, or credentials.

The normal `lib/main.dart` debug APK was rebuilt, installed with `adb install -r`,
and launched after acceptance. Saved connections were preserved; the integration
test APK is not left installed. Build evidence:
`build/history-search-normal-apk.log`.

## Conversation UI verification, 2026-09-06

The profile conversation now renders assistant Markdown, tables, and existing
copy/wrap code blocks, with message copying and tap-only web links. User text
stays literal. Named tool output is collapsed; approvals/input remain visible.
The composer supports multiline drafts, disabled empty sends, attachment chips,
and Stop while running. It does not promise queued submission. A Latest control
returns to the tail while keeping older pages loaded. No gateway protocol or
Hermes backend changes were made.

Ten new tests cover narrow-phone Markdown/tables, whitespace-preserving code
copy/wrap, message copy, partial streaming fences, literal user content, safe URL
schemes, no automatic image fetching, collapsed tool output, 1.8x text with a
keyboard inset, profile-isolated multiline drafts, scoped Stop without prompt
submission, and jump-to-latest. Existing scroll anchoring and clarification tests
also pass. Final full suite: 1,033 passed, one opt-in test skipped. Analysis clean.

The production read-only history/search acceptance now renders actual messages
through `ProfileMessage`. It passed on all four Prod Claw profiles again, loading
600, 551, 144, and 600 unique durable rows. Three histories exceeded 500 rows;
all retained their initial latest page and older prefix after refresh. The device
result was `00:24 +2: All tests passed!`. No prompts, runtime resume requests, or
server mutations were used.

The isolated authored-content preview was inspected on the emulator. Markdown,
code controls, collapsed tool activity, the header, and composer were checked;
typing a draft enabled Send without submitting it. The keyboard-inset regression
is a widget test; physical-device keyboard/background behavior remains unverified.
ADB currently exposes only `emulator-5554`, not the owner's phone.

Evidence remains ignored: `build/conversation-ui-tests.log`,
`build/conversation-full-tests.log`, `build/conversation-analyze.log`,
`build/conversation-prod-result.log`, `build/hermes-conversation-preview.png`,
and `build/hermes-conversation-keyboard.png`. Production logs contain only counts.

The normal `lib/main.dart` APK was rebuilt and restored with `adb install -r`.
Saved connections and the granted notification permission were preserved. Neither
the test APK nor the authored preview is left installed. Build evidence is in
`build/conversation-normal-apk.log`.

## Workspace color and row actions, 2026-09-06

Implemented gold profile/folder accents, chat status icons, project New chat,
and chat Rename, Pin/Unpin, Mark read/unread, Copy ID, Archive/Unarchive and
confirmed Delete. Archived chats have an overflow-menu destination. Mutations
use the stock profile-aware PATCH body and DELETE query parameter. No Hermes
backend code or configuration was patched, and no compatibility fallback added.

Eleven new unit/widget tests cover owner-scoped actions, failed writes, archive
discovery, duplicate taps, delayed writes across profile changes, stale refreshes,
project creation ownership, action sheets, delete cancellation, and status
semantics. Final suite: 1,044 passed, two opt-in live tests skipped. Analysis found
no issues. The separate opt-in local mutation test passed on the unchanged
Desktop gateway using two newly imported disposable chats with the same ID in
`android-qa-a` and `android-qa-b`. Pin, title, unread, archive/unarchive and delete
affected only the intended profile. Both disposable chats were deleted during
cleanup; their authored test history is not recoverable. No production chats
were modified or prompts submitted.

Deletion refuses a durable ID present in the stock global live-session list,
which has no profile owner field. This is deliberately conservative when IDs
collide. Precise running/input/completed indicators use owned app runtimes only;
unopened rows do not acquire a guessed live status from that global list.

The authored preview was inspected on the emulator in light mode and its chat
action sheet in dark mode. Evidence stays ignored under `build/`:
`hermes-actions-preview.png`, `hermes-actions-menu.png`, `actions-live.log`,
`actions-tests-final.log`, `actions-full-tests-final.log`, and
`actions-analyze-final.log`. The normal APK build is recorded in
`actions-normal-apk.log`.

The owner's Samsung SM-S918B is now paired over wireless ADB. This supersedes
the earlier emulator-only note. Use `adb devices -l` or mDNS discovery for its
current connection endpoint; do not store temporary pairing codes in the repo.
The normal `lib/main.dart` APK was installed with `adb install -r` and launched
on both the emulator and this phone. Saved app data was preserved. Neither
device was left running a preview or integration-test APK.

## Research-led design pass, 2026-09-06

The profile workspace now uses compact contextual menus, a workspace-scoped
light/dark palette, a featured project plus four ordered tiles, quieter chat
rows and a unified search/compose dock. Narrow or large-text layouts retain a
vertical project list. Five selectable accents persist locally. Consecutive tool
results share one collapsed group; prose, approvals, questions and Stop remain
available. No backend/protocol changes or compatibility behavior were added.

Six new design tests cover all accent foreground/background contrast pairs in
both themes, menu bounds/48 dp targets and safe dismissal, accent persistence,
2x text, tool grouping chronology/anchor identity and disclosure content. Existing
spinner tests now use bounded pumps while work is running. Full suite: 1,050
passed, two opt-in live tests skipped. Flutter analysis found no issues. This
does not claim a new live gateway mutation test or TalkBack certification.

The authored emulator preview was inspected in light and dark mode, including
the compact chat menu, collapsed/expanded tool results, Markdown/code controls,
composer and accent picker. The normal build was installed on the owner's
Samsung SM-S918B with data preserved. Its dark workspace and chat menu were
visually checked; Back dismissed the menu without selecting any command. No
production chats were opened, modified or prompted during this design check.

Ignored evidence includes `build/design-full-tests-final.log`,
`build/design-analyze-final.log`, `build/design-normal-apk.log`,
`build/hermes-design-root.png`, `build/hermes-design-menu.png`,
`build/hermes-design-chat.png`, `build/hermes-design-dark.png`,
`build/hermes-design-accent.png`, `build/hermes-design-phone.png` and
`build/hermes-design-phone-menu.png`. Phone captures contain private titles and
must not be committed. The research report and implementation plan are in docs.

After the preview checks, the normal `lib/main.dart` APK was restored on the
emulator with `adb install -r` and launched successfully. Emulator night mode
was returned to its earlier light setting. Both devices retain their saved app
data; neither is left running an authored preview or integration-test APK.

## Move to project verification, 2026-09-06

Implemented profile-bound Move to project using Desktop's stock
`session.workspace.move` RPC. The picker shows destination paths and explains
the working-folder change. No `projects.assign_session` compatibility path or
backend patch was introduced. Known busy chats and durable IDs present in the
global active-session list are refused. The live lookup's profile ambiguity and
preflight race are documented in the UI reference.

Six new tests cover the profile-stamped request, target project membership,
removal from the old project, global/search cache updates, rejected/active moves,
late responses across profile switches, duplicate taps, foreign project
rejection, refresh failure after a successful write, and picker selection/cancel.
Final full suite: 1,056 passed, two opt-in live tests skipped. Analysis is clean.

The separate opt-in local mutation test passed with an explicit existing test
folder. It imported two disposable chats with the same ID in `android-qa-a` and
`android-qa-b`, moved only A, checked persisted cwd/repository metadata and B's
unchanged cwd, then deleted both disposable chats. Their authored test history
is not recoverable. No production chats were moved, opened or prompted.

Ignored logs: `build/move-tests.log`, `build/move-full-tests.log`,
`build/move-analyze.log`, `build/move-live.log`, and `build/move-apk.log`.

The normal debug APK built successfully and was installed with `adb install -r`
on both the Samsung phone and emulator, preserving saved data. No preview APK
was installed in this pass. The phone returned to another foreground app during
the attempted UI check, so the new picker has widget-test coverage but no claimed
physical-device visual verification. No Flutter/Android runtime errors appeared
in the inspected recent error log.

## Compact project list and release readiness, 2026-09-06

Removed the project tile grid and card backgrounds in favor of 48 dp full-width
rows with small colored folder icons. Reduced the default toolbar to 64 dp,
title to 24 sp, section spacing, and chat-row minimum to 52 dp. Font scaling,
top-five recency order, See all, profile navigation and row actions are retained.

A new widget test checks five contiguous rows occupying 240 dp, full-width
titles, transparent row backgrounds, 48 dp action controls and project drill-in.
The existing 2x-text and menu tests pass. Full suite: 1,057 passed, two opt-in
live tests skipped. Analysis is clean. No gateway behavior or data was changed.
Logs are ignored under `build/compact-tests.log`, `compact-full-tests.log`,
`compact-analyze.log` and `compact-apk.log`.

Release readiness was inspected without publishing or generating secrets. The
phone has both Dev and an older release package, version 2.1.0/code 21402. The
checkout has no signing properties and GitHub lists no repository secrets.
Updating the existing release requires its original certificate/key; a distinct
fork identity can instead coexist. [Release plan](ANDROID_RELEASE_PLAN.md)
records signing, versioning, installation and encrypted configuration transfer.
