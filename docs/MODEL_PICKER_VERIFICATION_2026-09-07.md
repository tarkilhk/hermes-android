# Profile chat model picker verification

Live Android verification found that the original picker was wired only into
the legacy ChatScreen. Hermes Personal uses ProfileWorkspaceScreen. The fix
adds the same picker to that screen, with the workspace's theme and a full-width
message field above the attachment, model and send controls.

The implementation was rebased onto main `fa90b59`, including answer branching
and profile boxes. Controller guards prevent sending or branching during a
model change. Preferences are isolated by connection identity, profile and
durable chat ID. Restored selections are applied to the live session before
the next prompt. A failed reasoning write does not falsely display its value.

## Live checks

On 2026-09-07, the normal app entry point ran on the API 36 emulator against
the installed, unmodified Prestige Hermes gateway. This was not a fixture run.

- Created a chat in the disposable `android-qa-a` profile.
- Opened Intelligence from the actual profile conversation composer.
- Searched the real provider catalog and selected `gpt-5.6-sol` from
  `openai-codex`, then selected Extra High and applied both settings.
- The composer displayed `5.6 Sol Extra High` after gateway acknowledgement.
- Sent one bounded prompt requesting `MODEL_PICKER_OK` without tools. The
  assistant returned that exact text.
- Force-stopped and relaunched the app, reopened the saved chat and confirmed
  that the chosen model and reasoning remained visible.
- Reopened the picker and visually checked Extra High's selected indicator.
- Selected Low then Cancel. The composer retained Extra High.
- Inspected screenshots in light and dark themes; restored light mode afterward.
- The test profile's config.yaml SHA-256 was unchanged before and after applying
  settings, confirming that this check did not change profile defaults.

Automated checks cover the actual profile screen interaction, per-profile
ownership, persistence, restoring settings before a prompt, confirmation and
partial failure. Existing answer-branching and conversation checks were also run.
The composer geometry assertion was updated for the requested two-row layout,
while retaining minimum 48-pixel attachment/send targets and keyboard coverage.

The optional `integration_test/profile_intelligence_device.dart` entry point
uses isolated gateway data for repeatable manual UI checks. It is debug-only
test code and is not the entry point used for the signed Personal build.
