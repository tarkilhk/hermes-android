# Delivery sequence

Approved on 2026-09-11 after the owner tried the new shell. This breaks the [product plan](PRODUCT_PLAN.md) into increments for implementation and phone use. It does not add features, change exclusions or set calendar deadlines. Owner feedback can move a slice forward.

W00, the shell, is deployed. The W packages remain feature themes and coverage records. D01 through D30 below are delivery slices within those themes, not new feature IDs. Implementation is underway; the tracking table records what has actually been verified.

## How we deliver

Start a slice by checking its existing behavior and the relevant deployed backend contract. Preserve working implementations and define the specific remaining change. Keep this check inside the slice; do not make a complete backend audit a prerequisite for all development.

Implement one useful outcome at a time. Prefer one focused commit and a short set of acceptance checks. If a slice becomes too large, split it at a usable intermediate outcome, such as displaying server project appearance before adding its editor. Do not bundle unrelated work to fill a release.

For each phone build, record the included slices, version, checks and remaining limits in the [changelog](../CHANGELOG.md). Use semantic versions: minor for added features, patch for fixes, major for breaking changes. Increase the Android build number for each release and preserve published version history. Update the changelog with each milestone commit and push to `main`. The owner tries the change during normal use; correct problems before adding another layer to that workflow. Closely related small slices can share a build. One slice is not a promise of one day or one conversation of development.

Research is on `main` as `acd8c40`; the accepted shell baseline is committed and pushed as `87ddb44`. Commit and push after each verified milestone. Use smaller, cheaper agents for bounded tasks, integrate their changes, and report progress regularly. Reuse working code and remove obsolete implementations. This is a new product: do not add backward-compatibility layers.

## 1. Make everyday conversation dependable

These are the first proposed deliveries. Draft protection has immediate value because unsent work has no server copy. Provider grouping and the known `/yolo` gap are bounded improvements that should follow without a large redesign.

| Slice | Scope | Observable completion |
| --- | --- | --- |
| D01 Protect unsent work | Q02, M03; draft portion of Q03 | Unsent text and staged attachment references survive navigation and app restart, retain their intended host/profile/chat, and clear only when appropriate. A missing staged file is reported without losing the text. No transcript database or accepted-work outbox. |
| D02 Resume from Hermes | R02, R18, M01 refresh portion, M04; merged S14 | Reopening a chat displays the server's latest history, execution state and pending input. Lost acknowledgements do not cause duplicate submissions. Preserve and verify current behavior; fix only demonstrated gaps. |
| D03 Choose the right provider and model | Q16 | Expandable technical-provider groups preserve the exact server route/model identity. Reopening reflects server session configuration; old local overrides do not overwrite changes made elsewhere. |
| D04 Fix current-session YOLO | R06 | `/yolo` changes the intended session, shows its effective server state and leaves global defaults alone. Check behavior during a running turn against the deployed contract. Typing `/` remains the command entry point. |

D02 and D03 may reveal a missing server field or API. Record the precise dependency and continue independent slices instead of introducing durable client-owned substitutes.

## 2. Find work that needs attention and unblock it

This makes the phone useful for work started on Desktop or another profile. It also establishes the task targets and pending-input behavior that later push notifications need.

| Slice | Scope | Observable completion |
| --- | --- | --- |
| D05 Discover ongoing work | C09, R03, M02; Running/Needs input portion of C08 | Activity discovers ongoing sessions across profiles from the server, including work never opened on this phone. Opening a result retains its original owner. Test discovery limits before claiming full coverage. |
| D06 Answer approvals and questions | R04, R05, R07 | Existing allow/reject and clarification work is retained and completed where needed. Supported approval scopes, multiple questions and acknowledged outcomes are understandable and target the correct request. |
| D07 Answer sensitive requests | R08, R09 | Supported password, sudo, environment-secret and login/verification requests have dedicated responses and accurate completion/error handling. Implement each request family separately if the contracts differ. |
| D08 Make current notifications useful | R16, R17, S12, M09; local portion of M01 | Local completion/input notices, simple controls and notification taps work together. Tapping loads the right server session. The app accurately describes the limits before D27 adds background push. |

The first backend discovery check belongs at the start of D05. If the server cannot enumerate live sessions and pending requests across profiles, capture the missing contract as backend work. The current controller-only Activity list cannot satisfy this slice.

## 3. Direct a conversation while Hermes works

Keep the interaction small. Existing slash commands and ordinary Send behavior remain the starting point.

| Slice | Scope | Observable completion |
| --- | --- | --- |
| D09 Queue or steer this submission | Q11; Queue/Steer portion of Q10 | One-shot Queue/Steer through long press and an accessible menu. The owner approved Desktop-style client-owned queues on 2026-09-11: keep queued follow-ups with their chat, review/remove them and submit in order after active work finishes. Reuse draft storage/send; pause on uncertainty. Steer uses the backend's acknowledged outcome. Normal Send stays unchanged and Stop remains available. |
| D10 Correct and branch saved work | Q07, Q09; Fork portion of Q10 | Edit/resend, regeneration and answer-version navigation reflect server-owned history relationships. Complete the one-shot Fork action after defining its saved-history boundary. |
| D11 Ask alongside ongoing work | Q12, T14 | Side/background questions have identifiable results and links back to their work. Control notices and agent deliveries remain distinct from ordinary assistant answers. |

Do not delay useful Queue/Steer controls while resolving answer-version persistence. D10 begins by checking whether the server represents branch/version relationships; a local-only grouping database is not an acceptable completion.

## 4. Read and use the results

Deliver the path from an answer to a usable result on the phone. Keep the general remote file browser excluded.

| Slice | Scope | Observable completion |
| --- | --- | --- |
| D12 Read common answer content | T03 P1, T04 | Common Markdown, code, tables and supported diagrams are readable on a narrow phone, including large text and long content. Advanced math remains outside this slice. |
| D13 Read media and links | T05, T06 | Images and other supported media display or open sensibly, and links/previews return cleanly to the conversation. |
| D14 Understand execution output | T07, T08, T09, G07 | Tool output, server-provided todos and optional reasoning/time information are readable and expandable. No terminal or Git client is implied. |
| D15 Show the context fuse | T10 | A thin line integrated into the composer border shows server-reported context occupancy, with a mini dot at the current position, an accessible value and clear unknown/estimated states. Owner screenshot feedback on 2026-09-12 removes the separate row. |
| D16 Retrieve chat outputs | F03, F04, F05 P1 | A per-chat Outputs entry opens and downloads actual backend results from the right host. No global artifact library. |
| D17 Preview results | F06, F07 | Common file previews and interactive web output open from D16 and return to the originating chat. Reuse the media/link handling from D13. |

D15 is independent and can move earlier if the owner wants the fuse sooner. D16 can likewise move ahead of transcript polish when downloading results is the more pressing need.

## 5. Find, organize and start work from the phone

| Slice | Scope | Observable completion |
| --- | --- | --- |
| D18 Search and read older work | C02, C03, T11, T12 | Existing pagination/search is verified and completed for older server history, find-in-chat, stable reading during loading and jumping to the latest message. No durable local session-restoration store. |
| D19 Read state and remaining filters | C07; remaining P1 scope of C08 | Read/unread comes from Hermes and remains consistent across clients. Complete the agreed filters, reusing D05's task states. |
| D20 Manage projects | P03, P04, P06, P08 | Project creation, rename/delete, destination selection and server-owned icon/color metadata work together. Start with display and one-host operations; split individual write actions into separate commits if needed. |
| D21 Share into a reviewed draft | Q03, M06 | Android Share for text, links, images and files reaches the existing staging pipeline, with an explicit destination and review before Send. Reuse D01's durable drafts. |
| D22 Capture into that draft | Camera/photo portion of M06 and Q03 | Camera/photo choices feed the same draft and attachment flow, including cancellation and unavailable-file handling. No separate capture application. |

Capture can move forward once D01 is complete. It does not depend on finishing all search/project improvements.

## 6. Supervise longer work

These screens depend on the same server status and interaction contracts used by Activity and approvals. Keep each control close to the work it affects.

| Slice | Scope | Observable completion |
| --- | --- | --- |
| D23 Supervise subagents | R10, R11 | View a roster and progress, open details/transcripts, and target supported steer/interrupt actions at the correct subagent. |
| D24 Follow goals | R12, R13 | Display server goal state, criteria and verification details; provide supported pause/resume/clear operations with acknowledged outcomes. |
| D25 Inspect session background work | R14, R15 | Inspect and control session heartbeat/loop and background processes where supported. This does not reopen the deferred Cron/messaging/webhook administration section. |

## 7. Add reliable background notifications

FCM remains committed later work. The two halves below form one deliverable; backend integration alone is not completion. It can move ahead of stage 6 once Activity, request handling and notification routing are sound.

| Slice | Scope | Observable completion |
| --- | --- | --- |
| D26 Connect backend events to FCM | M01, R16, W07 | Verify existing event hooks, then supply authenticated device registration and a trusted sender for completion/input events. Use the existing backend where practical; no paid Firebase services are planned. |
| D27 Receive and open background alerts | M01, R16, R17, S12, M09, W07 | Complete Android delivery, registration lifecycle, duplicate handling and taps that refresh the authoritative session. Verify phone-locked and normally terminated-app cases. Respect Android permission, offline and force-stop limits. |

Push carries minimal notification/routing information. Conversations, pending requests and execution remain on Hermes. Do not turn this into a Firebase database migration.

## 8. Complete connection maintenance and the small admin screen

Keep broad K-family administration low priority. The shell already supplies navigation, device appearance controls and a read-only admin entry; finish their selected gaps rather than rebuilding those screens.

| Slice | Scope | Observable completion |
| --- | --- | --- |
| D28 Repair and inspect connections | Remaining B01/B02, B04, B10, S01, S02 | Setup, advanced access, connection repair, useful health diagnostics and server usage information are complete. Separate diagnostics/usage from access changes if the slice grows. |
| D29 Edit the selected profile | B14, B15; limited K seed | Add the selected profile/SOUL operations with explicit server scope. Preserve client-local profile navigation and centrally shared server settings. Broad provider/tool/plugin administration remains deferred. |
| D30 Expose versions and perform updates | S08, B11; verify remaining S10 | Expose Android/backend version identity and selected update information. Implement backend health/restart/update for one host first, then the selected multi-connection operations with per-host outcomes. Validate each operation separately. Retain the existing device appearance controls. |

D30 is a milestone with explicit subdeliveries: version visibility, one-host restart/update, and multi-host updates. Showing version information must not wait for multi-host operations. Restart and update require verified backend contracts and recovery outcomes.

## Tracking and completion

For each active slice, append a short record here or link its implementation note:

| Slice | Status | Delivered change | Verification and phone build | Remaining dependency |
| --- | --- | --- | --- | --- |
| W00 | Done | Shared shell and legacy UI cleanup | Personal 2.1.2 / 21452; see [shell notes](APP_SHELL.md) | No new feature coverage implied |
| D01-D04 | Implemented; live QA pending | Durable drafts, server refresh on cached reopen, technical-provider groups, session YOLO; removed local model overrides. See [delivery notes](CONVERSATION_FOUNDATIONS.md) | Analyzer clean; full suite 890 passed / 4 opt-in skipped; signed Personal 2.1.3 / 21462 built and installed wirelessly on owner's phone | Live gateway/phone behavior verification pending; local Desktop gateway is not running |
| D05 | Implemented; live QA pending | Per-profile `session.active_list` discovery, original session ownership and partial-profile errors | Source contract checked against pinned Desktop; controller and navigation tests | Deployed gateway enumeration still needs live verification |
| D06 | Implemented; live QA pending | Existing clarification handling retained; server-advertised approval scopes and request targeting | Included in foundation test run, 890 passed | Live gateway verification pending |
| D07 | Implemented; live QA pending | Dedicated sudo/secret/vault response forms, scoped expiry and duplicate-response guards; credentials remain unsaved | Controller delivery tests and six widget tests | Resume exposes approval/clarify only; restoring sensitive prompts after process death requires backend metadata |
| D08 | Implemented; live QA pending | Independent completion/attention switches, optional chat titles, permission/test alert and existing notification routing | Settings widget tests | End-to-end notification permission/tap checks remain; locked/terminated-app push remains D26/D27 |
| D09 | Implemented; live QA pending | Desktop-style text queues with review/removal and one-shot Steer through Message actions or long press | Queue tests cover ordered drain, separate drafts/attachments, restart, lost acknowledgement, stop/failure and repeated resume; Steer checks queued/rejected outcomes | Phone must be connected to drain; attachments cannot be queued in this slice |
| D10 | Partial; live QA pending | Saved-message Edit/resend, one-shot idle Fork and Regenerate; phone-only answer links removed; Parent chat uses server metadata. See [relationships](SERVER_CHAT_RELATIONSHIPS.md) | 2.18.0: 1,143 tests passed, four opt-in skips; 31 focused checks passed; analyzer clean; signed build pending | A synchronized answer carousel needs server origin-row, relationship-kind and ordering metadata |
| D11 | Partial; live QA pending | Identifiable side-question cards and out-of-order completion by task ID | Scoped command/delivery tests | `/bg` and task recovery still need verified server contracts |
| D12 | Partial | Wide tables, selectable streamed/nested fenced code and larger copy/wrap controls | Narrow-phone checks at 100%/200% text size | Rich diagrams still render as source fallback |
| D13 | Partial | Tap-to-preview zoomable web images and external-link fallback | Navigation/error widget checks | Additional media and backend file previews remain |
| D14 | Implemented; live QA pending | Expandable live tools with args/results/server duration, revisioned server todos, live/historical reasoning | Event and widget tests; existing stored-tool display retained | Only server-exposed reasoning/timing can be shown |
| D15 | Reopen fix implemented; phone QA pending | Border fuse and endpoint dot; ready-event refresh after deferred agent construction, with stale-response protection | Reproduced empty-on-reopen regression now passes; see [fix notes](CONTEXT_REOPEN_FIX.md) | Verify the owner's live-server chat after installing 2.5.0; no new prompt or local estimate required |
| D16 | Initial flow implemented; live QA pending | Per-chat transcript-derived Outputs; scoped authenticated bytes into Android save/share | Extraction/scoping/size-limit and actual-byte delivery tests | Candidate paths are heuristic; live relative-path resolution and endpoint support unverified |
| D17 | Partial | Authenticated image/text preview, binary save/share and explicit PDF/audio/video handoff to installed Android apps; see [opening files](OPENING_OUTPUT_FILES.md) | 2.17.0: 1,139 tests passed, four opt-in skips; six usage checks passed after polish; clean analyzer; signed Personal 21662 installed and launched | Interactive HTML and integrated media/PDF views remain; live viewer QA pending |
| D18 | Implemented; live QA pending | Find in selected chat with expandable matches, accurate counts and retry; existing pagination/search/Latest retained | Saved-page, Find and existing transcript/search tests | Complete-history loader has explicit size limits |
| D19 | Implemented; live QA pending | Paginated Unread only in Chats; All/Running/Needs input in Activity reuse authoritative server rows | Pagination/filter/navigation fixture checks | Unread has no server query filter; older pages must be loaded |
| D20 | Implemented; live QA pending | Project rename, appearance and confirmed deletion; existing creation/membership retained | Scoped write/ACK, deletion preservation, failure and UI checks | Deployed project write support still needs live verification |
| D21 | Implemented; native interruption QA pending | Connection/profile/new-or-existing chat choice, atomic draft staging, private durable pending intake and exact asynchronous acknowledgement/discard | Merge/failure/routing and bridge replay checks; signed 2.5.0 installed | Native OS interruption/recreation QA remains; an interruption between draft save and intake acknowledgement can reoffer a share |
| D22 | Implemented; native phone QA pending | Camera/Photos/Files feed existing draft preparation; camera returns to review with a verified originating chat or explicit destination choice. See [capture notes](SHARING_AND_CAPTURE.md) | Routing, launch, ownership and draft-review checks pass; analyzer clean. Signed Personal 2.6.0 / 21552 installed and launched | Live camera cancellation/process-recreation QA remains |
| D23 | Implemented; live QA pending | Scoped subagent roster, live details and acknowledged Steer/Interrupt. See [subagent notes](SUBAGENT_SUPERVISION.md) | 1,029 tests passed, four opt-in skips; clean analyzer; signed Personal 2.7.0 / 21562 installed and launched | Active-only roster and transient tails; live-server/phone controls QA remains |
| D24 | Goal controls and criteria editing implemented; live QA pending | Server goal/verification details, Pause/Resume/Unwait/Clear and criteria Add/Remove/Clear. See [session controls](SESSION_CONTROLS.md) | 2.14.0: 1,109 tests passed, four opt-in skips; clean analyzer | Goal contracts and gates remain read-only; live-server controls QA remains |
| D25 | Implemented; live QA pending | Session heartbeat/loop state, supported controls and targeted process Stop/Dismiss | 1,057 tests passed, four opt-in skips; clean analyzer; signed Personal 2.9.0 / 21582 built and verified | Included in installed 2.12.0. No full process-output RPC; Dismiss is transient client view state; live controls QA remains |
| D26-D27 | Planned; Firebase setup pending | Existing local notifications and authenticated tap routing can be reused | Installed backend has transient WebSocket notification events but no FCM registration or sender | Firebase project/app configuration and trusted backend sender integration remain necessary; no Firebase SDK added yet |
| D28 | Diagnostics, session usage and custom headers implemented; live QA pending | Dashboard/provider checks, connection repair, server-recorded profile usage and secure proxy headers | 2.15.0: 1,124 tests passed, four opt-in skips; clean analyzer | Live proxy/provider QA remains; no local usage ledger |
| D29 | Initial editor implemented; live QA pending | Selected-profile description/SOUL editor with acknowledged and partial-save handling | 1,080 tests passed, four opt-in skips; clean analyzer | Included in installed 2.12.0. No global profile activation or broad admin |
| D30 | Versions, one-host and selected-host updates implemented | Installed Android identity; update eligibility, confirmation, progress and correlated per-host outcomes | 2.16.0: 1,132 tests passed, four opt-in skips; clean analyzer | TUI restart needs a verified remote endpoint; live update QA remains |

D05/D07/D08/D09 delivery on 2026-09-12: analyzer clean, full suite 921 passed and four opt-in skips. Signed Personal 2.1.4 / 21472 passed package/certificate checks, installed in place on the owner's phone at the requested wireless endpoint, and launched successfully. See [supervision and queue notes](SUPERVISION_AND_QUEUES.md). Phone evidence is installed version/process metadata; live gateway feature checks remain as listed above.

D10-D13/D15 batch on 2026-09-12: analyzer clean, full suite 944 passed and four opt-in skips. Signed Personal 2.1.5 / 21482 passed package/certificate checks, installed in place wirelessly on the owner's phone, and launched successfully. See [conversation actions and reading](CONVERSATION_ACTIONS_AND_READING.md) for delivered portions and remaining diagram/media/version/background gaps. No live gateway feature verification is implied by package/process checks.

D14/D16-D18 batch on 2026-09-12: analyzer clean, full suite 970 passed and four opt-in skips; release-identity checks passed after the semantic version adjustment. Signed Personal 2.2.0 / 21492 passed package/certificate checks, installed in place wirelessly on the owner's phone, and launched successfully. See [execution, Find and Outputs](EXECUTION_FIND_AND_OUTPUTS.md) for the delivered behavior and limits. Phone checks cover package/process metadata, not live gateway feature verification. The [changelog](../CHANGELOG.md) now backfills the prior milestones and records this release; previously published version numbers are preserved.

D19/D20 and the owner-requested D15 fuse adjustment on 2026-09-12: full suite 984 passed, four opt-in skips; analyzer clean. The five project dialog checks also passed after a test-fixture cleanup. Signed Personal 2.3.0 / 21502 passed certificate/package checks, installed in place wirelessly on the owner's phone, and launched successfully. See [filters and projects](FILTERS_AND_PROJECTS.md). The fuse is integrated into the composer's top edge with an endpoint dot, rather than occupying a separate row. Phone checks verify package/process metadata; live gateway feature verification remains outstanding.

D21 review and D22 Photos batch on 2026-09-12: full suite 995 passed, four opt-in skips; analyzer clean. Signed Personal 2.4.0 / 21512 passed certificate/package checks, installed in place wirelessly and launched on the owner's phone. See [sharing and capture](SHARING_AND_CAPTURE.md). Camera and native intake recovery before destination selection remain tracked, as does the owner-reported D15 existing-chat context-loading bug. Phone checks cover package/process metadata; no live message was submitted for verification.

D21 intake recovery and the D15 context reopen fix on 2026-09-12: full suite 1,000 passed, four opt-in skips; analyzer clean. Signed Personal 2.5.0 / 21522 passed package/certificate checks, installed in place wirelessly, and launched successfully on the owner's phone. See [sharing notes](SHARING_AND_CAPTURE.md) and [context fix evidence](CONTEXT_REOPEN_FIX.md). The context regression failed before the five-line ready-event change and passed afterward. Phone evidence covers package/process metadata; the owner's live-server context display and native process-death recovery still need device verification. Camera and all subsequent roadmap slices remain planned.

The feature ledger in PRODUCT_PLAN.md remains the coverage checklist. Mark a feature Done only after all of its selected portions are delivered; Q10, Q03, C08 and notifications deliberately span multiple slices. R18 error clarity, B15 ownership and M08 server authority apply throughout.

Q05 discoverability, B03 OAuth, B16-B20 bots, broad K administration, section 11, M10 offline history and M11 local ranking remain excluded or deferred exactly as recorded in the product plan. M07, M12 and M13 remain future possibilities. M05 adds no separate work. M08 and S14 add no independent client-state feature.
