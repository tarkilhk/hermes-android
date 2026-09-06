# Hermes Android: continue development on Prestige (Windows)

## Receiving task

The owner explicitly requested handoff to **Prestige**, their Windows laptop
already configured as a remote target in ChatGPT/Codex. Continue on that host.
Inspect the actual checkout and installed tools before making changes. Preserve
the uncommitted documents included with this handoff. Work autonomously within
the approved scope below and report verified results and concrete blockers.

If using the ZIP transfer, extract it into a development directory and open the
included `hermes-android` repository in Codex on Prestige. If the app's native
handoff already transferred the checkout and these documents, use that checkout.
Do not replace an existing checkout with local changes.

## Immediate objective

Establish a verified Windows development loop for this Flutter Android fork:
build → run in a local Android emulator → inspect screenshots and logs → interact
with the app → verify against the existing Hermes Desktop-managed local gateway.
Then implement the first profile-aware end-to-end slice described below.

The owner chose Windows because hardware acceleration on the Linux dev VM has
been problematic. Do not resume Linux KVM/emulator troubleshooting. The Linux
emulator packages were installed but never booted; no KVM permission was changed.

## Agreed product direction

- Modern profile-aware Hermes servers only. Clean breaking changes are preferred.
  Backward compatibility, legacy defaults/interfaces/data formats, aliases,
  migration shims, and fallbacks require the owner's explicit approval before
  adding or preserving them. They are not part of the approved target.
- Official Electron Hermes Desktop is the behavior reference for profiles,
  projects, sessions, and background work.
- **Codex Remote inside ChatGPT on Android** is the confirmed mobile UI and
  interaction reference. Its exact visual details still need actual Android
  screens or a first-party demonstration; behavior docs alone are not a visual
  specification.
- The broader daily-driver/indispensable-product roadmaps were inherited from
  Carlos Reyes Peña's upstream PR #88. They are not this owner's roadmap.
- Keep Flutter and the useful transport, credential, attachment, Android and
  recovery modules; restructure application ownership and replace the main UI.

## Source and transfer state

- Origin: `https://github.com/tarkilhk/hermes-android.git`
- Branch: `main`; baseline: `116b1f965f956be2bd634334b94fea07027898ca`.
- Application source is unchanged from that commit. Research/handoff documents
  are intentionally uncommitted. Preserve them when preparing a work branch.
- This transfer contains Git history and source, not installed dependencies,
  credentials, signing keys, APKs, or Linux-generated `android/local.properties`.

Read these files before implementation:

1. `docs/PROFILE_SWITCHING_IMPLEMENTATION_SPEC.md` — the confirmed-direction
   addendum supersedes its historical compatibility requirements.
2. `docs/HERMES_DESKTOP_BEHAVIOR_REFERENCE.md` — pinned official source,
   integration risks and acceptance matrix.
3. `docs/CODEX_ANDROID_UI_REFERENCE.md` — verified mobile behavior and visual gaps.

`docs/LOCAL_BUILD_SETUP.md` records the old Linux baseline, not Windows commands.

## Establish the Windows feedback loop

1. Inspect existing Git, Flutter, Java, Android SDK, emulator, and Hermes Desktop
   installations first. The owner authorized development dependency installation;
   reuse suitable installations and install missing tools. Run the emulator
   natively on Windows. Use Flutter **3.44.0** (Dart **3.12.0**), JDK **17**,
   Android compile/target SDK **36**, and the repository's Gradle wrapper.
   Dependencies may install SDK 34/35, NDK 28.2.13676358 and CMake 3.22.1.
   Verify Windows hypervisor support with `emulator -accel-check` and an actual
   boot; an installed emulator alone is not completion.
2. Run `flutter pub get`, `flutter analyze --no-pub --fatal-infos`,
   `flutter test --no-pub`, and `flutter build apk --debug --no-pub`.
   Install the APK on the emulator and open it. Confirm package
   `com.hermesagent.hermes_android.dev`, capture a screenshot, and inspect logcat
   for startup failures. Keep host-specific SDK paths out of Git.
3. Use ADB and Flutter integration tests for repeatable app actions and logs.
   Add Android UI automation for native permissions/notifications when needed.
   If Computer Use is available, enable it for Hermes Desktop and the emulator
   and verify it can actually inspect/interact with each. On Windows it requires
   the active desktop; no background-control capability is assumed. A missing
   Computer Use tool does not prevent ADB screenshots and scripted interactions.
4. Use the owner's existing **Windows Hermes Desktop-managed local gateway** as
   the preferred backend. The owner offered it for development; no extra Linux
   Hermes server is needed. Inspect its installed version, endpoint, auth, and
   profile REST/RPC routes. Create clearly disposable test profiles for mutations
   and keep existing personal sessions intact. Keep credentials in local secure
   configuration. Determine the configured model and agree on a limit before
   sustained billable live-model tests. Do not connect to the separate production
   server merely because it was offered as an alternative.
5. Verify emulator-to-host connectivity and authenticated HTTP/WebSocket access
   using the actual gateway address. Desktop's renderer may use local-only
   capabilities unavailable to Android; do not assume its visible success proves
   that the mobile-accessible routes work. Record screenshots, app/server logs,
   and observed responses as the environment acceptance evidence.

## First implementation milestone

Demonstrate: connect → discover profiles A/B → select A → list/create a session
and project → submit/stream → switch to B while A runs → handle completion →
return to A with correct history. Cover attachments and an approval, rapid
switching, identical IDs in different profiles, missing/deleted profiles,
reconnect, and notification navigation. Distinguish continued server execution
from durable Android process-death recovery; neither implies the other.

Before exposing the picker, make connection/profile/session ownership explicit
through clients, repositories, caches, journals, navigation, and notifications.
Extract chat orchestration from the widget; screens should render state and issue
commands while running work has application lifetime. Retain useful tested
modules wherever the verified server contract supports their behavior.

## Findings to carry forward

- The 3,448-line `lib/core/screens/chat_screen.dart` constructs clients, selects
  three send paths, handles approvals, updates transcripts, and owns UI state.
  A visual replacement alone is insufficient.
- Retained recovery exists in `GatewayTurnApplicationController`, but it is
  connection-scoped. Project requests and persistent identities omit profiles.
- Chat settlement callbacks are captured by retained coordinators and refer to
  screen instances. `_onTurnSettled` returns when its original widget is disposed,
  so navigation can suppress notifications even while the turn survives.
- Official Hermes source inspected at
  `245e48008fa814b3251f50755eb656bd9fb86cb1` can resolve an unknown/deleted profile
  to the launch context in RPC handlers. Including `params.profile` is therefore
  insufficient to guarantee isolation. Reproduce against the installed version
  and require explicit rejection; a client discovery check cannot close the
  deletion-between-discovery-and-write race.
- The Android recovery engine expects an explicitly negotiated experimental
  contract (`session.open`, versioned prompt/reconcile behavior). A modern stock
  gateway is not automatically compatible. Verify methods, response ownership,
  durable/runtime IDs and replay behavior before choosing the target path.
- README says MIT, while NOTICE says the upstream snapshot supplied no license
  grant. Clarify this inconsistency before treating distribution rights as settled.

## Verified baseline and limits

On Linux with the pinned toolchain: analysis clean, **947 tests passed**, debug
APK built and signature verified; package `.dev`, version `2.1.1-dev`, code 2141.
The suite includes real loopback WebSockets, journal fault injection, credential
rollback, attachment sanitization, widget and lifecycle tests. It is useful
regression coverage, not proof of the live server contract.

No emulator boot, physical-device run, authenticated real-server flow, or model
call has been verified in this task. Existing Kotlin Gradle Plugin migration
warnings did not block the pinned build. No source changes, commits, pushes,
production changes, or release signing were performed.
