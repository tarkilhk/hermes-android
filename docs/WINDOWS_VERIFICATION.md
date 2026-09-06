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
- Full unit/widget suite: 976 passed, one opt-in live test skipped.
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

- Exercise a real approval/input request. Controller routing tests alone do not
  prove the complete server-to-device approval interaction.
- Test Android process termination during a running turn. Pending owner retention
  and reconnect tests do not prove complete process-death recovery.
- Add connection endpoint/credential-change invalidation for retained resources.
  Do not treat editing an existing connection during active work as verified.
- Add session/history pagination and richer transcript/attachment rendering.
- Compare real Codex Remote Android screenshots before claiming visual fidelity.
- Stock Hermes can resolve a profile deleted between discovery and an RPC to the
  launch context. Android revalidates profiles before writes, but cannot close
  that server-side race. No compatibility fallback or local server patch is used,
  and strict deletion-race isolation is not claimed.

Profile switching does not change the server's sticky active profile. New app
routes use the stock modern profile-aware gateway; older unscoped UI modules are
not a runtime fallback for these routes.
