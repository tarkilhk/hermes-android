# Android device verification

The quote and question changes were exercised on emulator-5554, Android API 36,
1080x2400, using ADB taps, text entry, UI hierarchy inspection and native screen
captures. This is a running Android APK, not a widget-test image.

## Scope

`integration_test/profile_device_ui_check.dart` is a disposable debug entry point
using the shipped ProfileWorkspaceScreen, controller, transcript, Markdown and
question widgets. Its gateway has authored data and validates response profile,
session and request IDs. SharedPreferences is in memory. It never reads saved
credentials or contacts a real server. No production question was answered.
This verifies device UI and client response routing, not production transport.

The paired phone was initially inspected but was actively switching to ChatGPT.
Testing moved to the emulator. Other tasks also wanted the emulator; exclusive
access was coordinated before continuing. A stale tap landed in the other app's
connection dialog before coordination completed. No text, connection submit or
other action was performed there. That dialog was left untouched afterward.

## Observed results

- Dark and light quotes have a subtle left rule, italic readable text and no
  pale-blue fill. Headings, lists, inline code, tables and fenced code render.
- Two adjacent tool results are one collapsed row. Tapping it exposes both
  results without losing the answer.
- A long question displays three choices, Other, Skip, progress and confirmation.
  Selecting an option produces no fixture response until confirmation.
- The first confirmation intentionally fails. The chosen answer stays selected
  and the retry error is visible. Retrying sends the same answer and advances to
  question 2 of 2 without carrying the old selection.
- Selecting Layout and Accessibility plus entering "Mobile touch targets"
  produces the ordered answer `Layout, Accessibility, Mobile touch targets`.
  The question panel disappears after successful final confirmation.
- At 1.6 text scale, choices and custom text remain usable with no horizontal
  overflow. Long content extends above the viewport rather than shrinking text.
- Android text entry and its floating Gboard input toolbar were exercised. A
  full-width docked keyboard was not observed; this is not a claim of that layout
  passing. The emulator's `show_ime_with_hard_keyboard` setting was temporarily
  changed from 0 to 1 and restored to 0.
- No Flutter exception or RenderFlex overflow was found in captured runtime logs.

Fixture response log:

1. q1, Quick review of the main issues, intentional failure.
2. q1, same answer, accepted.
3. q2, Layout, Accessibility, Mobile touch targets, accepted.

## Correction found on device

The light-mode capture showed white status-bar icons on a pale background.
ProfileWorkspaceTheme now sets an explicit SystemUiOverlayStyle for each theme.
After rebuilding and installing the fixture APK, the settled light-mode screen
shows dark, legible Android time, Wi-Fi and battery icons. A theme regression test
asserts the icon brightness. Nine focused design tests passed.

## Evidence and cleanup

Ignored local captures under `build/`:

- `device-quotes-dark.png`, `device-quotes-light.png`, `device-tools-open.png`
- `device-question-initial.png`, `device-question-selected.png`
- `device-question-retry.png`, `device-question-next.png`
- `device-question-keyboard.png`, `device-question-completed.png`
- `device-question-large.png`, `device-question-large-keyboard.png`
- `device-light-statusbar-fixed.png`
- `device-ui-runtime.log`, `device-statusbar-test.log`, `device-ui-rebuild.log`

Only the emulator Dev package was replaced, always with `adb install -r`. No
uninstall or data clear was performed. The phone Personal app was not replaced.
Emulator access was handed to the queued profile-boxes task with an explicit
request to install its normal main-entry APK over the temporary Dev fixture
before continuing. The model-controls task follows that task in the device queue.

Cleanup was subsequently confirmed by the profile-boxes task: the temporary
fixture was replaced by a normal `lib/main.dart` Dev APK with the source tree of
merged main fa90b59. The connection list opened normally. No Personal package was
replaced by this verification task. After rebasing the status-bar correction onto
fa90b59, static analysis passed and all 29 selected design, Markdown and question
regressions passed. Final logs are `build/device-check-final-analyze.log` and
`build/device-check-final-tests.log`. The status-bar correction was verified in
the emulator fixture; it has not been separately deployed to the owner's phone
by this task while other tasks own that device.

To repeat, build a debug APK with the device-check entry point, install it only
on a disposable emulator, choose a scenario, and interact manually. Never install
this fixture in Hermes Personal. Restore a normal main-entry APK afterward.
