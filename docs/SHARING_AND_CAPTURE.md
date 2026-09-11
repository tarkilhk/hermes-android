# Sharing into a draft

D21 adds review and destination choice to the existing Android share bridge. The Photos part of D22 uses the existing file picker; Camera remains a separate step.

Incoming text, links, images and files open a review. With multiple connections, choose the destination server first. The review displays its connection, lets the user choose a discovered profile and either a new or existing conversation, and exposes pagination for older chats. Add to draft is the only write action; Send remains a separate action in the composer.

The controller prepares every incoming attachment against the existing draft's limits before changing the draft. It preserves existing text, attachments, queued messages and uncertain-delivery status. Shared text is appended with a blank separator. Preparation failures clean only newly staged files, and a changed destination draft is left intact. Successful staging uses the existing durable draft store.

The exact pending share is acknowledged only after staging succeeds. Further incoming shares wait in memory while the current one is reviewed. Cancelling leaves the content available from the Home Review control; Discard explicitly removes it. A failed New chat staging attempt reuses the already-created conversation on retry. It does not delete a server chat or create another one on every retry.

Photos and Files feed the same attachment path. Images receive the existing sanitization and file limits. No camera bridge or new picker dependency is added here.

## Remaining limits

The native bridge copies incoming files into temporary intake storage. Pending share metadata before Add to draft is in memory, so interruption before destination selection is not covered by the durable conversation-draft guarantee. Native intake also retains its existing item/size limits and behavior for unreadable inputs. This slice does not claim process-death recovery for unassigned incoming shares; that remains D21 follow-up work.

The D15 existing-session context-loading report remains active. Available source fixtures hydrate after the server response and do not reproduce the reported settled-empty bar. No speculative timing patch or local token estimate is included.

## Verification

Release target: Personal `2.4.0+2151`, ARM64 code `21512`. Full suite: 995 passed, four opt-in skips; analyzer clean. Tests cover reviewed routing, exact acknowledgement, merge/preservation, preparation failure, concurrent draft changes, pagination retry and 320-pixel/200% text layout. Final build and phone results are recorded in the delivery sequence after completion.
