# Conversation polish

The owner approved long-conversation work and then asked for denser, more
enjoyable UI throughout. This pass concentrates on the conversation, retaining
the compact workspace/project/profile changes already installed.

## Changes

- Keep durable rows and expanded tool groups mounted when additions change their
  lazy-list indices. Older-page insertion must not move the visible message.
- Preserve reading position through streaming growth, including a response taller
  than the viewport. Follow output only at the latest edge or after tapping Latest.
  A newer touch gesture cancels a pending automatic scroll correction.
- Show New activity when output arrives away from the latest edge. Input needed
  takes priority while approval or clarification is pending. Tapping this control
  scrolls only; it never submits a reply or grants approval. Respect reduced motion.
- Put Copy beside the assistant header or user bubble instead of reserving an
  extra footer row. Tighten message gaps and Markdown paragraph spacing.
- Use a single-row composer that grows with multiline text, with attachments
  above it only when present. Keep 48 dp attach/send/copy controls. Hide the
  redundant idle status strip; retain running/error status.
- Use a small labelled history loader and an explicit start-of-loaded-history
  marker, without claiming access to compression ancestors the server has not sent.

## Verification

Targeted tests cover 2,500 variable-height rows with lazy mounting, older-page
insertion, a multi-screen stream tail, materialized-message updates, tool-group
expansion, input discovery, failed-page retry, large text with a keyboard and
compact composer dimensions. Existing profile and history tests remain required.

Production acceptance uses the emulator's saved connection for authentication.
Its test controller has in-memory preferences, no pending-turn restore, and an
allowlist for session/history/search reads plus projects.tree. No runtime resume,
chat mutation, prompt, model call or backend change is part of this verification.
Logs contain counts rather than message bodies. Authored content is used for
visual screenshots. Restore the normal app after running integration/preview APKs.
Always pass `--no-uninstall` when using `flutter test` on Android; its default
cleanup uninstalls the app. The standalone read-only probe avoids that runner.
See WINDOWS_VERIFICATION.md for the emulator-data incident and incomplete live retest.

## Limits

Scroll offset restoration remains in-memory per chat, not durable across process
death. It is not a message bookmark across arbitrary offscreen history changes.
Stock offset paging may overlap during concurrent writes; existing ID deduplication
remains in place. If a refresh has no overlap with the loaded history, the existing
latest-page replacement behavior still applies. Cross-segment compression history
and a new server cursor contract are outside this UI pass.

The signed release must be verified and installed without uninstalling Personal,
Dev or the older third-party app. Actual results are recorded in WINDOWS_VERIFICATION.md.
