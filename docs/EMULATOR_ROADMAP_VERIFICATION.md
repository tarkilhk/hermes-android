# Roadmap emulator verification

The owner requested direct emulator testing after the selected implementation
work. This record separates native Android checks, synthetic server scenarios
and checks that still need a configured Hermes server or Firebase project.

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
Resolving this runner issue remains part of verification; this is not recorded
as a fully passing integration-test command.

`integration_test/roadmap_native_preview.dart` uses the same synthetic transport
with real Android plugins, secure storage and preferences for direct UI checks.
It requires a debug build and is only used on the disposable emulator.

Interruption while the camera owns the foreground,
media/PDF/browser previews and cold/warm session-target notification taps still
need their Android checks. The force-stop checks above test draft/intake
recovery only; they do not claim FCM delivery to a force-stopped application.
Fixture results must not be recorded as live server results. Production-context
fullness, deployed profile contracts and real push delivery retain their separate
acceptance checks in [the delivery sequence](DELIVERY_SEQUENCE.md).
