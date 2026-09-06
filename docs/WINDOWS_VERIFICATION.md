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
