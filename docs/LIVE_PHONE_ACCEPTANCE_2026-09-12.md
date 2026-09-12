# Live phone acceptance, 2026-09-12

These checks used the installed Personal client and an existing Hermes connection
on a Samsung phone. No Hermes backend code or configuration changed. One short,
tool-free prompt was sent in a temporary test chat, which was then deleted.
Private transcripts, file paths, host addresses and credentials are omitted.

## Verified on 2.31.1

Personal 2.31.1 / 21862 installed over the prior version, launched and retained
the saved connection. The full suite passed 1,288 tests with four opt-in skips;
analysis was clean. All four emulator scenarios passed with driver exit code 0.
The first emulator runner lost its debug-service connection, then the restarted
runner completed; no application failure was observed.

| Check | Result and limit |
| --- | --- |
| Existing large chat and context fuse | History opened with an empty composer. The context fuse immediately showed 57% without submitting a prompt. This closes the reported D15 live check for this chat. |
| Large-chat Outputs | The formerly failing Outputs list opened with recent references and an older batch available. Loading older results kept the list usable. |
| Authenticated Markdown preview | A repository README opened as formatted Markdown. Back returned to the originating view. This verifies the file service and authenticated preview for one current file. |
| Older generated file references | One PDF reference and one Markdown reference returned the client's HTTP 404 category through the same file/read-text route. Another file worked through that service. The two older paths are stale, unavailable or otherwise unresolved; the client now reports the actionable category, but the files were not restored. |
| Find over older history | Loading older history increased the match count from 121 to 132 while preserving the first result. An expanded long result kept **View in chat** immediately visible. It opened **Search result** with nearby messages, and **Back to latest** returned to the empty composer. |
| Project folder discovery | An explicit scan returned repository folders and selecting one filled the absolute-path field. Cancelling made no project. This verifies discovery and selection, not `projects.create`. |
| Activity | Activity opened empty without an error because the server reported no ongoing sessions. This does not verify active rows, cross-profile ownership or filters with live work. |
| Draft survival | A marker typed into an empty composer survived navigation, force-stop and restart. Removing it restored the verified empty composer. Nothing was sent. |
| Model selection and prompt round trip | The picker grouped models by technical provider. Low reasoning applied to the temporary chat. Sending cleared its composer, displayed Working and Stop, and produced the requested short reply. The context indicator then showed measured usage. Intermediate streaming chunks were not separately verified. |
| Test cleanup | The temporary chat was deleted and remained absent after a server refresh. The original chat was reopened with an empty composer. |

The 2.31.1 correction classifies safe HTTP file failures, offers Retry only for
transient failures, preserves saved proxied-auth forwarding, keeps recent Find
results stable while adding older matches, and places the result action before
expanded full text. Raw server responses and private paths are not displayed.

## Follow-up on 2026-09-13

The installed Personal 2.31.1 build passed these additional Samsung checks.
No messages, files or photos were sent during this pass.

| Check | Result and limit |
| --- | --- |
| Local test notification | Android notification permission was granted. The built-in test posted an actual Hermes notification, and tapping it returned to the app. This verifies local delivery and app opening, not background push or chat-specific routing. |
| Photos cancellation | Photos opened Android's app chooser. Cancelling returned to an empty composer with Send disabled. No media was selected. |
| Camera cancellation | Samsung Camera opened and cancelled back to the empty composer without a review. A second launch also opened and cancelled successfully. No photo was taken. |
| Files cancellation | Android's document picker opened and cancelled back to the original empty composer. The context fuse remained populated and the original model setting remained High. |
| Incoming text recovery | An explicit Android text-share intent opened review. After leaving review, force-stopping Hermes and relaunching restored the exact unsent text. Home's Review action reopened it. This verifies native text intake across actual process restart, not a third-party sender's share-sheet selection. |
| Incoming text discard | Discard removed the test intake. Another force-stop and relaunch did not restore it or reopen review. Nothing was added to a conversation draft. |

## Remaining live acceptance

- Create or edit a real project after selecting a discovered folder.
- Observe Activity with actual ongoing and input-required sessions across profiles.
- Verify cross-client read state, queue uploads and sensitive-response delivery.
- Exercise Samsung media playback, camera and photo flows.
- Recheck older file references only if Hermes later exposes valid current paths;
  repeated 404 responses do not establish a client retrieval defect.

Unsupported background push, synchronized answer versions, cold sensitive or
side-task recovery, and remote TUI restart remain deferred under the
no-backend-modifications rule.
