# Roadmap emulator verification

The owner requested direct emulator testing after the selected implementation
work. This record separates native Android checks, synthetic server scenarios
and checks that still need a configured Hermes server or Firebase project.

## Current installed baseline, 2.31.1

The 2.31.1 full suite passed 1,288 tests with four opt-in skips. Analysis was
clean, and all four emulator scenarios passed with driver exit code 0. Evidence
is in `build/2.31.1-full-tests-final.log`, `build/2.31.1-analyze-clean.log` and
`build/2.31.1-emulator-direct-driver-final.log`. A first runner lost its service
connection before testing; restarting the test app and driver completed the run.

The signed Personal build is installed as 2.31.1 / 21862. Its separate Samsung
checks are recorded in [live phone acceptance](LIVE_PHONE_ACCEPTANCE_2026-09-12.md).

Use the disposable emulator and isolated fixtures for routine acceptance work.
Reserve the phone for final deployment, reported live-connection problems and
Samsung-specific behavior. Neither fixture results nor phone package checks
establish an untested live-server contract. Real server writes remain separate
from the isolated emulator scenarios.

## Previous milestone, 2.31.0

The final unit and widget suite passes 1,281 tests with four opt-in skips.
Static analysis is clean. Evidence is in `build/2.31.0-full-tests-final.log`
and `build/2.31.0-analyze-final.log`.

The suite covers discovered project selection, profile ownership, large text
with the keyboard open, direct file preview retry and return navigation,
once-decoded file paths, review-event ownership and the sensitive-input jump.
An earlier file-path failure caught URI normalization removing a relative path
prefix and a second decode of literal percent characters. Both regressions
pass on this snapshot.

The emulator suite adds a fourth scenario using existing Hermes contracts:
discover and create a project, receive a review summary, then jump from older
history to an unanswered vault request. All four scenarios passed and the direct
driver exited 0. Evidence: `build/2.31.0-emulator-direct-driver-final.log`.
The first run's new scenario checked the jump label before its post-frame update.
The final scenario waits for rendering and preserves the same assertions.
No backend changes or rejected recovery/version contracts are used.

The signed Personal build passed certificate, package, non-debuggable and ARM64
checks, then installed in place on the connected phone as 2.31.0 / 21852.
Evidence: `build/2.31.0-release-build.log` and installed package metadata.
This does not establish live acceptance of private chats or Samsung-specific
interaction behavior. The emulator used the separate debug test package.

Scope correction for 2.30.1: the owner prohibits Hermes backend modifications.
The fourth 2.30.0 scenario relied on invented patch contracts and has been removed
from the active suite. Its historical pass below is not evidence of support in
unmodified Hermes. The remaining three scenarios exercise existing client flows.
Unit regressions separately verify reconnect with absent optional server fields.
All three remaining scenarios passed on 2.30.1 and the driver exited 0. Evidence:
`build/2.30.1-emulator-direct-driver.log`. This rerun uses the existing-contract
fixtures and no answer-version, sensitive-snapshot or side-task-snapshot RPCs.

## Test environment

- Date: 2026-09-12.
- Disposable AVD: `Hermes_Roadmap_QA`, Android 36, x86_64, emulator-5556.
- Baseline: 2.27.2-dev / 2180, production `lib/main.dart` entry point.
- Debug package: `com.hermesagent.hermes_android.dev`.
- Existing phone and emulator configurations were not replaced. This AVD started
  with fresh data and uses no production connection or model credentials.
- Direct Android interaction uses ADB input and UI Automator accessibility
  bounds. Screenshots and logs are under ignored `build/` paths.

## Native checks completed on the baseline

| Check | Observed result | Evidence |
| --- | --- | --- |
| Install and launch | `adb install -r` succeeded; the app opened its empty Connections screen | `build/emulator-home.png`, `build/emulator-home.xml` |
| Drawer | Chats, Activity, Connections, App settings and Hermes administration are present | `build/emulator-menu.xml` |
| Settings | Android app identity is visible; selecting Dark changes appearance; controls remain reachable by scrolling | `build/emulator-settings.xml`, `build/emulator-alerts.xml` |
| Notification permission denied | Android displayed its permission dialog; denying it produced "Notifications are disabled in Android settings." | `build/emulator-permission.xml`, `build/emulator-denied.png` |
| Notification permission granted | A second explicit request displayed Android's dialog; granting it posted "Hermes notification test" with the expected body in the real notification shade | `build/emulator-permission2.xml`, `build/emulator-notification.png` |
| Draft process interruption | Typed composer text remained after force-stop, relaunch and reopening the same synthetic chat | `build/qa-native-draft.xml`, `build/qa-native-draft-restored.xml` |
| Incoming Android share | A real `ACTION_SEND` opened review with the exact shared text and an explicit profile/chat destination | `build/qa-native-share.xml` |
| Share review interruption | Force-stop during review retained the pending shared content; relaunch reopened review | `build/qa-native-share-restored.xml` |
| Share merge | Add to draft appended the shared text while preserving the original unsent text; no send occurred | `build/qa-native-share-merged.xml` |
| Camera cancellation | Native camera opened; cancelling returned to the unchanged text draft | `build/qa-native-camera-ready.xml`, `build/qa-native-camera-cancelled.xml` |
| Camera capture | Native Shutter and Done returned a 72 KiB Camera photo.jpg to destination review; Add to draft staged it with the original text | `build/qa-native-camera-confirm.xml`, `build/qa-native-camera-result.xml`, `build/qa-native-camera-staged.xml` |
| Camera draft interruption | Restart after staging did not reoffer the completed intake; reopening the chat retained the image and text | `build/qa-native-camera-restart-ready.xml`, `build/qa-native-camera-restored.xml` |
| Process reclaimed during capture | Android killed the background Hermes process while the camera remained open. Shutter and Done recreated Hermes with a 75 KiB photo in destination review | `build/qa-native-camera-after-kill.xml`, `build/qa-native-camera-killed-confirm.xml`, `build/qa-native-camera-recovered-ready.xml` |
| Native file picker | Android Downloads selected the synthetic text document; the composer retained it alongside the earlier image and text | `build/qa-native-downloads.xml`, `build/qa-native-file-selected.xml` |
| Native photo picker | Selected a synthetic emulator screenshot; horizontal scrolling revealed it as the third attachment without replacing the earlier items | `build/qa-native-photo-items.xml`, `build/qa-native-photo-chip.xml` |

These checks establish native permission and local display behavior. They do not
establish Firebase delivery, session-target notification navigation, or behavior
on the owner's Samsung phone.

## Broader scenarios executed

`integration_test/roadmap_emulator_test.dart` drives the production app and
screens with isolated credential and gateway fixtures. It covers navigation,
profiles/projects, text size, drafts, model/command controls, history, Find,
Outputs, context, queues, approval and Activity.

All three named scenarios completed on emulator-5556 against the 2.27.2
baseline. The fixture was corrected after initial failures caused by ambiguous
Find labels, an incorrect expectation that an idle chat would retain its queue,
and an output path placed in a user message instead of an assistant message.
These were test defects; no product failure was observed in those scenarios.

The runner itself did not exit cleanly. With `--no-dds`, Flutter reported a
separate pre-test load error for
`integration_test.VmServiceProxyGoldenFileComparator`, then completed all three
scenarios and exited with `+3 -1`. With standard DDS enabled, it failed to start
the Dart Development Service before loading the suite. The exact error and
scenario results are retained in `build/roadmap-emulator-run-20260912.log`.
That command did not pass and remains recorded as a runner failure.

The 2.29.0 rerun used `test_driver/roadmap_emulator_driver.dart`. The combined
`flutter drive --no-dds` launch lost its service connection before running tests.
The app remained alive and paused at start. A direct VM-service probe succeeded,
so the same standard integration driver was connected through an explicit ADB
port forward. All three scenarios then passed and the driver exited 0. No test
assertions or Flutter SDK files were changed. The clean result is in
`build/2.29.0-emulator-direct-driver.log`; the failed launch is retained in
`build/2.29.0-emulator-drive.log`.

For this run, `adb forward tcp:61888 tcp:42549` forwarded the emulator's observed
VM port. Setting `VM_SERVICE_URL` to that forwarded service URI and running
`dart --packages=.dart_tool/package_config.json test_driver/roadmap_emulator_driver.dart`
completed the suite. VM ports and service tokens change on each app launch.

The final 2.30.0 run used the same direct standard driver with the expanded
suite. All four scenarios passed in 62 seconds and the driver exited 0:

- Drawer, settings, profiles, chats and projects at large text size.
- Drafts, provider/model and slash controls, paged Find/Outputs and context.
- Activity, approval responses and queued work with their original chat owner.
- Resumed sensitive requests and expiry, idle foreground chats with background
  tasks, and Previous/Next navigation through server-owned answer versions.

The result is in `build/2.30.0-emulator-direct-driver.log`. The last scenario
checks actual screen navigation and profile-scoped requests against synthetic
server responses. Live deployment acceptance remains separate.

`integration_test/roadmap_native_preview.dart` uses the same synthetic transport
with real Android plugins, secure storage and preferences for direct UI checks.
It requires a debug build and is only used on the disposable emulator.

## Native reading checks on 2.29.0

`integration_test/reading_native_preview.dart` opens production PDF, media and
web viewers with locally generated fixtures. It requires a debug build. Its PDF
has two pages; audio is a 12-second generated tone; the optional MP4 is a small
12-second blue frame generated with FFmpeg and supplied through the
`HERMES_QA_VIDEO_BASE64` build define. Nothing is downloaded from Hermes.

| Check | Observed result | Evidence |
| --- | --- | --- |
| PDF | Android rendered page 1; Next rendered page 2 and updated the page count | `build/qa-reading-pdf1.png`, `build/qa-reading-pdf2.xml` |
| Audio | Native player prepared the WAV, showed its 12-second duration, and Play/Pause advanced then stopped the timeline | `build/qa-reading-audio.xml`, `build/qa-reading-audio-paused.png` |
| Video | Native player rendered the blue MP4 frame; Play/Pause advanced then stopped its 12-second timeline | `build/qa-reading-video-frame.png`, `build/qa-reading-video-paused.xml` |
| HTML | Local HTML rendered; tapping its button changed the text to Interaction passed; Show source exposed the original HTML | `build/qa-reading-html.png`, `build/qa-reading-html-clicked.xml`, `build/qa-reading-html-source.xml` |
| Mermaid | The bundled renderer displayed the draft/server/result diagram in the Android WebView | `build/qa-reading-diagram.png`, `build/qa-reading-diagram.xml` |
| Browser | Chrome's in-app tab displayed a local HTTP fixture; Close returned to the original Hermes screen | `build/qa-reading-browser-content.xml`, `build/qa-reading-browser-return.xml` |

These checks cover real native rendering and controls. The headless emulator's
playback timeline does not establish physical speaker output. HTML's WebView
accessibility label incorrectly said Diagram preview; the shared renderer now
sets its title and label to the actual format.

## Native notification taps on 2.30.0

The optional `ROADMAP_NATIVE_NOTIFICATION_NONCE` define in
`roadmap_native_preview.dart` posts two real Android alerts through the production
notification plugin. Each carries the original connection/profile/chat key.
A persisted test nonce prevents setup or reposting during the cold launch.

- Warm tap opened `personal/chat-0` and retained its draft and attachments.
  Evidence: `build/qa-notify-230-expanded.xml`, `build/qa-notify-230-warm.xml`.
- Before the cold tap, the work profile was selected. Android then removed the
  background app process, confirmed by an empty `pidof` result. The retained
  notification launched a new process and reopened `personal/chat-0`, preserving
  its existing draft and attachments. Evidence: `build/qa-notify-230-work.xml`,
  `build/qa-notify-230-cold-shade.xml`, `build/qa-notify-230-cold-ready.xml`.

These checks verify the real plugin callback, cold startup and application
navigation. They do not establish Firebase transport or recovery of a live
approval request from a deployed server.

The force-stop checks above test draft/intake
recovery only; they do not claim FCM delivery to a force-stopped application.
Fixture results must not be recorded as live server results. Production-context
fullness, deployed profile contracts and real push delivery retain their separate
acceptance checks in [the delivery sequence](DELIVERY_SEQUENCE.md).
