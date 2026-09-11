# Sharing into a draft

D21 adds review and destination choice to the existing Android share bridge. The Photos part of D22 uses the existing file picker; Camera remains a separate step.

Incoming text, links, images and files open a review. With multiple connections, choose the destination server first. The review displays its connection, lets the user choose a discovered profile and either a new or existing conversation, and exposes pagination for older chats. Add to draft is the only write action; Send remains a separate action in the composer.

The controller prepares every incoming attachment against the existing draft's limits before changing the draft. It preserves existing text, attachments, queued messages and uncertain-delivery status. Shared text is appended with a blank separator. Preparation failures clean only newly staged files, and a changed destination draft is left intact. Successful staging uses the existing durable draft store.

The exact pending share is acknowledged only after staging succeeds. Cancelling leaves the content available from the Home Review control; Discard explicitly removes it. A failed New chat staging attempt reuses the already-created conversation on retry. It does not delete a server chat or create another one on every retry.

From 2.5.0, native intake keeps unsent text and attachment copies in private app storage before destination selection. A small persisted queue owns pending shares; Flutter displays the oldest and acknowledges its ID only after draft staging or explicit Discard. Copies are removed after that acknowledgement is saved. The queue survives app restart and holds at most ten shares and 128 MiB of files; each share allows ten files, 64 MiB of files and 256 Ki characters of text. Imports are serialized, and unreadable or oversized input fails as a whole with a visible error. It does not silently import only some selected files.

If clearing an incoming share fails after its conversation draft was saved, the app opens the saved draft and explains that the pending share can be discarded from Home. A failed Discard leaves the review controls available. These are unsent drafts only; no conversation history or execution state is stored in the intake queue.

Photos and Files feed the same attachment path. Images receive the existing sanitization and file limits. No camera bridge or new picker dependency is added here.

## Remaining limits

An interruption after saving the conversation draft but before acknowledging the incoming share can offer the share again. Review is mandatory and nothing sends automatically. No separate deduplication ledger is added to conversation drafts. A file copy interrupted before native intake commits may need to be shared again; only successfully imported content is retained. Native process-death behavior still needs an end-to-end device check.

The D15 existing-session context-loading report was reproduced using the
installed backend's deferred-agent sequence. The small ready-event refresh is
included in 2.5.0; see [the context reopen fix](CONTEXT_REOPEN_FIX.md). Its live
phone verification remains outstanding.

## Verification

The 2.4.0 review/Photos release passed 995 tests with four opt-in skips and a clean analyzer. Tests cover reviewed routing, exact acknowledgement, merge/preservation, preparation failure, concurrent draft changes, pagination retry and 320-pixel/200% text layout.

The 2.5.0 intake recovery release adds bridge replay/acknowledgement and UI failure checks. The full suite passed 1,000 tests with four opt-in skips; analyzer clean. The signed Personal APK passed package/certificate checks and was installed in place and launched on the owner's phone as 2.5.0 / 21522. Bridge fixtures verify service replay, not Android process-death behavior itself.
