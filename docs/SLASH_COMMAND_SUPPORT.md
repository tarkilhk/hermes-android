# Mobile slash commands

Current product scope is maintained in [PRODUCT_PLAN.md](PRODUCT_PLAN.md). The
2026-09-11 [follow-up contract check](research/FEATURE_PLAN_CONTRACT_NOTES_2026-09-11.md)
confirms active-turn support for `/steer`, `/btw` and `/bg`, but identifies a
missing dedicated current-session `/yolo` handler. Generic catalog/dispatch
support must not be read as a guarantee of complete command parity.

In the profile workspace, type `/` to browse the connected gateway's command
catalog. Search matches names, aliases and descriptions. The list includes user
commands, plugin commands and installed skills without a client-side size limit.
Selecting a result inserts it into the composer; Send executes it. Arguments
use the gateway's completion API. Refresh workspace to reload the catalog after
installing or changing skills.

## Execution

The client uses the modern Hermes RPC contract:

- `commands.catalog` supplies commands, aliases, descriptions and availability.
- `complete.slash` supplies argument completions and their replacement offset.
- `command.dispatch` resolves skills, bundles, user commands and plugins.
- `slash.exec` executes built-ins only after dispatch explicitly reports that
  it does not own the command. Execution errors and timeouts never cause a retry
  through another handler.
- `skill` and `send` responses submit their expanded message through the normal
  attachment and streaming path. The visible bubble shows the invocation.
- `prefill` responses, including undo, return text to the composer for editing.
- `exec` and `plugin` responses show command output without waiting for a turn.

New chat, profile selection, session selection, title, branch, save, history,
status, interruption, steering and side questions use mobile navigation or the
live session RPCs. Commands never select a slash worker's separate CLI session.
Every request carries the originating profile; session requests also carry its
runtime ID. Late results stay with that chat when the foreground profile changes.

Terminal-only and messaging-only commands show their requirement. Host microphone
commands explain that they do not capture the phone's microphone. Other commands
remain callable by name, including commands absent from a stale catalog.
Commands that start an ordinary turn require the current turn to finish first.
Interrupt, steering, status and side questions can target an active turn.

Command output remains in application memory for the chat. It is not added to the
model's conversation or persisted as new server history. Attachments remain in
the composer after display-only commands. A skill that starts a turn uses the
existing attachment upload path.

## Server requirement and verification

This implementation was checked against official Hermes source at
`245e48008fa814b3251f50755eb656bd9fb86cb1`:

- [Catalog and dispatch](https://github.com/NousResearch/hermes-agent/blob/245e48008fa814b3251f50755eb656bd9fb86cb1/tui_gateway/methods_tools.py)
- [Completion responses](https://github.com/NousResearch/hermes-agent/blob/245e48008fa814b3251f50755eb656bd9fb86cb1/tui_gateway/methods_complete.py)
- [Desktop command handling](https://github.com/NousResearch/hermes-agent/blob/245e48008fa814b3251f50755eb656bd9fb86cb1/apps/desktop/src/app/session/hooks/use-prompt-actions/slash.ts)

Live testing reproduced a server bug on Prestige's installed runtime,
`b499ab11fe8b081470e269f2fb27abae03000da5`: the command catalog omitted a skill
that existed in the requested QA profile and parsed correctly in Hermes's skill
scanner. Command catalog, completion and dispatch handlers lacked profile scope.

The included [gateway patch](../server-patches/0002-profile-slash-commands.patch)
applies Hermes's existing profile-scoping helpers to those four handlers. It was
applied to Prestige's installed runtime for local testing. Other gateways need
this fix or an upstream equivalent. From a matching Hermes checkout, run
`git apply --check /path/to/0002-profile-slash-commands.patch`, then apply it and
restart the gateway. The patch is separate from the Android APK.

With the patch, the live contract test passed for `android-qa-a` and
`android-qa-b`, using the same skill name with distinct descriptions and prompt
bodies. Catalog, completion and expansion each returned the correct profile's
version. This test does not invoke a model. It does not establish stronger
server-wide isolation guarantees for unrelated APIs or missing profiles.

Automated coverage in `test/slash_commands_test.dart` checks dynamic discovery,
arguments, aliases, profile switching during dispatch, duplicate submission,
timeouts, prefill, side-question routing, autocomplete replacement, stale
completion responses, and the mobile composer. These are injected gateway tests;
they do not replace a live server/device acceptance run.

`test/slash_profile_live_contract_test.dart` runs the real A/B command check with
`--dart-define=HERMES_TEST_PORT=<local-port>`. It requires a disposable
`android-mobile-slash-qa` skill in each QA profile, with a short description
containing the profile name and a body containing `ANDROID_SLASH_<profile>`.

`integration_test/slash_commands_live_test.dart` runs on an Android emulator
against the same gateway. Forward its port with `adb -s emulator-5554 reverse`,
then supply `-d emulator-5554` and the port define to `flutter test`. It checks
the actual command picker, `/model`, `/status`, and installed-skill expansion,
and writes screenshots to the app's external files directory. It adds a
`Prestige local QA` connection and uses only the disposable QA profile.

The emulator acceptance run passed against Prestige on 2026-09-07. Captured
screens confirmed the picker, current-model output and session status for
`android-qa-a`. The test requires a new status result after the second Send and
requires at least one installed skill. It refocuses the composer between
commands because dispatch temporarily disables Android's text input.

To export screenshots before Flutter removes the test app, add
`--dart-define=HERMES_SCREENSHOT_HOLD_SECONDS=40` and pull the three
`slash-command-*.png` files from
`/sdcard/Android/data/com.hermesagent.hermes_android.dev/files/` while the test
prints its screenshot-directory message. Omit the hold for normal test runs.
