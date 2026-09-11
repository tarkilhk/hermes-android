# Conversation actions and reading — 2026-09-12

This delivery continues D10-D13 and implements D15 from the selected delivery sequence. It reuses the existing conversation, branch, Markdown and gateway code, with no added dependencies or durable server-data store.

## Conversation actions

Saved user messages offer Edit with explicit confirmation that their turn and later history will be replaced. The client rechecks the saved row against current server history and submits the corrected text using the row-addressed truncate contract. It pauses queued follow-ups and preserves separately composed text and attachments. The dialog keeps the correction until acknowledgement; rejected/uncertain edits retain the text and show an error, with retry disabled while the chat reconnects.

Message actions adds a one-shot Fork when the conversation is idle and has a saved assistant boundary. It uses the existing server branch operation at the latest loaded saved answer and sends the text into that child. The original composer clears only after the send is acknowledged. This initial action accepts text only; ordinary Send/Stop behavior remains unchanged.

Existing regeneration and answer-version navigation are retained. Their locally stored grouping remains a known dependency for Q09; this delivery neither expands that schema nor claims cross-device version relationships.

## Side questions

`/btw` records the server's task ID and displays a distinct side-question card in the owning chat. Completion updates the matching card even when several questions finish out of order. Results remain selectable, empty events are ignored, and a completion observed without its start still displays its question/result.

These are transient display records. No verified side-question recovery API was found. Existing `/bg` handling remains unchanged and still needs deployed-gateway contract verification; it is not claimed as newly completed background-task management.

## Reading and context

- Wide Markdown tables use the renderer's horizontal scrolling rather than compressing columns to the phone width.
- Code supports backtick and tilde fences, longer outer fences and incomplete streamed blocks. Copy preserves the code text; a single wrap/scroll toggle and 48-pixel controls remain usable at large text sizes.
- Web images open on tap in a zoomable preview, with an external-browser fallback and normal Back navigation. Media/web links retain explicit external-app opening. Backend file downloads are separate D16 work.
- A four-pixel context fuse sits between the composer text and model controls. Green, amber and red correspond to less than 65%, 65–84% and 85% or above. Tooltip/accessibility text gives usage and marks server estimates as approximate. Missing or unusable data displays an unknown neutral line.

The fuse reads `session.context_breakdown {session_id}` after history refresh and model changes. `session.usage` supplies live updates through its `usage` payload; `session.info.usage` is handled too. Each chat owns its disposable snapshot, and a late request cannot replace a newer usage event. No token count or model limit is guessed on the phone. The server's percentage drives the line; used/max values describe it, without recomputing from category totals.

Rich diagram rendering remains incomplete: diagram fences currently provide readable/selectable source with copy/wrap controls. No external diagram-rendering service or browser engine was added. Audio/video-specific previews and authenticated backend media remain further D13/D16 work.

## Verification

Release source is Personal `2.1.5+2148`, ARM64 code `21482`. Static analysis reports no issues. The full suite passed 944 tests, with four opt-in integration skips. Signed-build and phone deployment results are recorded in the delivery sequence. Focused tests cover saved-row addressing, rejected edits, fork destination/draft preservation, side-question correlation, narrow-screen tables/code, image navigation/fallback, and scoped context updates including stale-response rejection.

The [contract audit](research/MOBILE_DELIVERY_CONTRACTS_2026-09-11.md) records the pinned Desktop evidence. Live owner-gateway behavior remains unverified; mocks and source inspection do not establish deployed-server capability.
