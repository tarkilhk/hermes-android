# Changelog

All notable changes to this project are documented here. This project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html). Release notes for
versions prior to 1.0.7 are in the **What's new** sections of the [README](README.md).

Feature releases increment the minor version, fixes increment the patch version,
and breaking changes increment the major version. The Android build number after
`+` always increases. Update this changelog for every release milestone.

## [2.30.0+2183] - 2026-09-12

### Added

- Server-backed Previous/Next answer versions. Regenerate records an explicit
  relationship; ordinary branches remain separate. Selection reveals the saved
  answer, including older history, and retains version controls there.
- Side and background task recovery from the server's live session. Activity
  includes chats whose background work is running while their composer is idle.
  Failure and truncation labels use server metadata; no task state is saved locally.
- What's new and Releases links in the installed app version card.
- Disposable native preview checks for PDF, media, HTML, diagrams and browser
  navigation, plus a scoped notification-tap fixture.

### Fixed

- HTML and SVG previews identify their actual format to accessibility services.

### Deployment

- Answer versions and side-task recovery require backend patches 0005 and 0006.
  Firebase project setup and a supervised remote TUI restart remain separate
  dependencies; this release does not claim to supply either deployment.

### Verification

- Full suite: 1,256 passed, four opt-in skips; 49 focused milestone checks passed.
  Static analysis is clean. Dependency review completed; package upgrades are
  deferred because this slice needs no dependency changes.
- All six exact backend patch artifacts applied in order to fresh pinned Hermes
  source; the combined suite passed 106 tests.
- All four emulator integration scenarios passed with a clean driver exit,
  including resumed requests, background task discovery and answer navigation.
- Real-browser diagram/HTML/SVG checks passed. Native PDF pages, audio/video
  playback, HTML interaction/source, Mermaid rendering and browser return
  navigation passed on the disposable emulator. See
  [the verification record](docs/EMULATOR_ROADMAP_VERIFICATION.md).
- Real Android warm/cold notification taps returned to the original profile
  and chat with the draft intact. These test plugin/navigation behavior, not FCM delivery.
- Signed Personal 21832 passed native compilation, certificate and package checks,
  installed in place on the owner's phone and launched successfully.

## [2.29.0+2182] - 2026-09-12

### Added

- Pending password, secret and verification requests can return when a chat
  reconnects, using the server's current request. Expired or answered requests
  close their forms. Replaced requests clear entered values; partial status
  updates preserve an active form. Sensitive answers remain unsaved.
- Backend patch 0004 exposes pending request metadata through resume and
  session-info responses, with ownership, expiry and display-field checks.

### Fixed

- Restored the required release version code to both CI verification step environments.
- Rebased the older TCP/SSE and profile-command backend patches onto the pinned
  Hermes source. Corrected push registration/status to use the host's Firebase
  configuration while keeping installation records scoped to their profile.

### Verification

- Full suite: 1,245 passed, four opt-in skips; static analyzer clean.
- Signed Personal 21822 passed native compilation, package and certificate checks.
- All three roadmap emulator scenarios passed with a clean standard-driver
  exit after connecting it directly to the emulator's VM service. The combined
  Flutter launch connection failure remains documented in the verification record.
- All 28 focused request recovery checks passed. Live server acceptance needs
  the coordinated backend patch. See [request recovery](docs/SENSITIVE_REQUEST_RECOVERY.md).
- On the disposable emulator, Android reclaimed Hermes while the camera stayed
  open. Completing the capture recreated Hermes and restored photo review.
  Phone installation remains deferred while the owner is away.

## [2.28.0+2181] - 2026-09-12

### Added

- Firebase background notification integration with explicit permission setup,
  per-profile registration, token refresh, current device preferences and
  original-connection validation. App settings reports setup status and offers
  Retry. Local notifications remain available without Firebase configuration.
- A coordinated backend patch supplies authenticated registration and a bounded
  sender for completion/input events, including work whose client disconnected.
  WebSocket and Firebase messages share event IDs to avoid ordinary duplicates.
- Optional Firebase build configuration in the signed Personal build script.
  No Firebase project or sender credential is included in the app or repository.
- Emulator scenarios for chat workflows and a native test entry point for
  sharing, camera, file selection and draft interruption checks.

### Verification

- Full suite: 1,237 passed, four opt-in skips; static analyzer clean.
- Three emulator scenarios completed, with a separate Flutter runner/DDS
  failure still tracked. Direct native permission, draft/share interruption,
  camera capture/cancellation and file-picker checks passed. See
  [the detailed verification record](docs/EMULATOR_ROADMAP_VERIFICATION.md).
- Real background delivery still requires Firebase project configuration,
  backend patch deployment and locked/background/terminated-app tests.
  Phone installation remains deferred while the owner is away.

## [2.27.2+2180] - 2026-09-12

### Fixed

- Notification taps reuse the chat screen for their original connection instead
  of stacking copies. Concurrent callbacks for the same target share one open;
  later taps still refresh the session from Hermes.
- A newer notification target takes precedence over an older pending open,
  including rapid switches between chats. Failed opens remain retryable.

### Verification

- All 33 focused notification checks and 1,224 full-suite tests pass, with four
  opt-in skips. Analyzer clean; signed Personal 21802 passed native compilation
  and certificate/package checks.
- Phone installation remains deferred while the owner is away from home.

## [2.27.1+2179] - 2026-09-12

### Fixed

- Retry native notification initialization after a temporary startup failure,
  including before a later alert or the explicit permission/test action.
- Use deterministic Android notification IDs for the original chat so app
  restarts do not change the ID used to replace that chat's alert.

### Documentation

- Record Firebase configuration steps and the verified backend event and
  registration requirements for the selected background-delivery milestone.
  This patch does not add Firebase delivery or a backend sender.

### Verification

- The startup retry, concurrent initialization and repeated launch regressions
  failed before the fix. All 24 focused checks and 1,216 full-suite tests pass;
  four opt-in tests remain skipped. Analyzer clean; signed Personal 21792 passed
  native compilation and certificate/package checks.
- Phone installation is deferred while the owner is away from home.

## [2.27.0+2178] - 2026-09-12

### Added

- Queue messages with attachments, including attachment-only drafts, through
  the existing Message actions menu. Queued files use the same upload and send
  path as ordinary drafts; separately typed work stays in the composer.
- Restore queued text and files after interruption, including previously saved
  text-only queues. Remove the private file cache only after the queued entry is
  durably removed. Failed or uncertain sends keep the entry paused for review.

### Fixed

- Preserve newer composer edits during delayed queue saves and removals, and
  distinguish duplicate queue entries when removing one.
- Clean up queued attachment caches when a chat is deleted, including chats
  whose saved draft has not been opened in this app run.

### Verification

- All 108 focused checks passed. Full suite: 1,209 passed, four opt-in skips;
  analyzer clean. Independent review found no remaining issue. Signed Personal
  2.27.0 / 21782 passed native compilation and certificate/package checks.
  Phone installation remains deferred while the owner is away.

## [2.26.0+2177] - 2026-09-12

### Added

- Find results offer **View in chat**, including matches in older saved history.
  Read the matching message with nearby context and return with **Back to latest**.
  Matched tool results open their disclosures automatically.
- Keep this search view temporary and scoped to its original chat. It leaves
  normal history and pagination untouched and discards stale selections after
  a history refresh or chat change.

### Verification

- All 22 focused checks passed. Full suite: 1,191 passed, four opt-in skips;
  analyzer clean. Signed Personal 2.26.0 / 21772 passed native compilation and
  certificate/package checks. Phone installation is deferred while the owner
  is away from home.

## [2.25.1+2176] - 2026-09-12

### Fixed

- Complete the server-backed unread lifecycle when an unread chat is explicitly
  opened and its history loads successfully. Reuse the existing acknowledged
  read-state update, with original-profile and stale-response guards.
- Keep the chat usable if marking it read fails, preserve its unread state and
  explain how to retry manually. Reconnecting alone does not mark a chat read.

### Verification

- All 38 focused read-state checks passed. Full suite: 1,188 passed, four
  opt-in skips; analyzer clean. Signed Personal 2.25.1 / 21762 passed native
  compilation and certificate/package checks. Phone installation and live
  server checks are deferred while the owner is away from home.

## [2.25.0+2175] - 2026-09-12

### Added

- `/bg` and `/background` use the existing side-question card to show each
  task's prompt, running state and result. Server task IDs keep out-of-order
  completions attached to the right task and originating profile/chat.
- Preserve a result that arrives before the start acknowledgement, and show
  a neutral explanation when a completed task returns no text. These are live
  task views; no local task database or invented child-chat link is added.

### Verification

- All 30 focused command/card checks passed. Full suite: 1,182 passed, four
  opt-in skips. Analyzer clean. Dependencies were reviewed and the lockfile was
  retained; this feature needs no dependency upgrade.
- Signed Personal 2.25.0 / 21752 passed native compilation and certificate/package checks. Phone installation waits for a new
  wireless-debugging endpoint; the last verified installation is 2.24.0.

## [2.24.1+2174] - 2026-09-12

### Fixed

- Find in chat loads recent saved-history batches, removing the complete-chat
  size gate. Search older messages preserves the query and prior results;
  partial counts, retry and Close explain the current state. All loaded matches
  remain accessible, including those beyond the old 100-result display cap.
- Deduplicate overlapping history pages and use the server-identified history
  segment after compression for both Find and Outputs.
- Reconcile stale roadmap descriptions of delivered version/admin functions
  and removed local answer-version links. Preserve the remaining selected work.

### Verification

- Reproduced the exact 10,000-message Find failure through the actual chat menu
  before the fix. All ten focused tests pass, including retry, page overlap,
  compressed-chat ownership and narrow layout with large text and keyboard.
- Full suite: 1,176 passed, four opt-in skips. Analyzer clean. An additional
  loaded-results/error layout test passed with large text and the keyboard open.
- Signed Personal 2.24.1 / 21742 passed native compilation and certificate/package
  checks. Installation awaits a new wireless-debugging endpoint; the phone
  refused the last address. The last verified installation remains 2.24.0.

## [2.24.0+2173] - 2026-09-12

### Fixed

- Large chats now open Outputs from the first recent-history batch, with **Load
  older outputs** to find earlier files. Outputs no longer downloads the whole
  transcript and fails at 10,000 messages. A failed batch keeps existing results
  and offers **Try again**; an initial failure also offers **Back to chat**.
- Keep the fix in the existing D16 Outputs milestone and preserve all other
  product selections, exclusions and outstanding work.

### Added

- Open downloaded, self-contained interactive HTML from file options, with
  source access and Save or share. Reuse the existing preview and authenticated
  download, with a 1 MiB HTML limit and a script sandbox that blocks external
  web resources. No new renderer dependency or server resource proxy.

### Verification

- Reproduced the owner's exact large-chat error before the fix. Regression
  checks now reach the oldest output in a 10,000-message chat and cover retry,
  retained results and original profile/session ownership.
- Real browser fixtures verify HTML interaction, isolated document/storage,
  blocked external scripts/images/fetch, source limits and viewer replacement.
  Existing Mermaid and SVG fixtures still pass.
- Full suite: 1,173 passed, four opt-in skips. Analyzer clean. A separate
  review found no defects in pagination ownership or retry/refresh handling.
- Signed Personal 2.24.0 / 21732 passed native compilation and certificate/package
  checks, installed in place wirelessly and launched. Phone checks cover version
  and process metadata; the owner's live chat and native HTML interaction still
  need device verification.

## [2.23.0+2172] - 2026-09-12

### Added

- Preview completed SVG blocks and authenticated SVG output files in the
  existing diagram viewer, with source/copy access, pinch zoom and return to
  the originating chat. Incomplete and oversized blocks retain source access.
- Render SVG as an image in the offline viewer, with no executable SVG scripts
  or external resources. Bound source size and image dimensions, and release
  temporary image URLs on completion or replacement. No new renderer dependency.

### Verification

- Real headless-browser fixtures passed for SVG rendering, disabled scripts,
  blocked external content, source/dimension limits and URL cleanup. Existing
  Mermaid rendering checks still pass.
- Full suite: 1,169 passed, four opt-in skips. All 32 focused reading/diagram
  checks passed and the analyzer is clean.
- Signed Personal 2.23.0 / 21722 passed native compilation and certificate/package
  checks, installed in place wirelessly and launched. Phone checks cover version
  and process metadata; live WebView gestures remain a manual check.

## [2.22.0+2171] - 2026-09-12

### Added

- Play downloaded audio/video inside Hermes from chat Outputs using Android's
  built-in play/pause and seek controls. Playback starts only when requested,
  releases on backgrounding, and returns to the original file options with Back.
  Existing external-open and save/share actions remain available for formats
  the phone cannot decode.
- Reuse authenticated file downloads and the 32 MiB cap. Temporary media files
  are private and removed when the player closes; no background playback,
  persistent media library or new player dependency.

### Verification

- Full suite: 1,166 passed, four opt-in skips. After consolidating the shared
  file-action helper, all 19 focused media/file/Outputs checks passed again and
  the analyzer remained clean.
- Signed Personal 2.22.0 / 21712 passed native compilation and certificate/package
  checks, installed in place through wireless debugging, and launched. Phone
  verification covers version/process metadata; live playback/gesture QA remains.

## [2.21.0+2170] - 2026-09-12

### Added

- Formatted Markdown file previews in chat Outputs, reusing reply formatting,
  tables, code and diagrams. Toggle to the exact source for copying; keep the
  server's truncation notice and full-file save/share actions.
- Browser previews for web links in replies and Outputs, with an external
  browser fallback. Returning from the browser preserves the originating chat.

### Verification

- Full suite: 1,161 passed, four opt-in skips. Analyzer clean; 41 focused
  reading/link checks passed.
- Signed Personal 2.21.0 / 21702 passed native compilation and certificate/package
  checks, installed in place through wireless debugging, and launched. Phone
  verification covers version/process metadata; live reading/browser QA remains.
- Downloaded interactive HTML, integrated audio/video and remaining visual
  formats stay planned. See [preview behavior](docs/MARKDOWN_AND_WEB_PREVIEWS.md).

## [2.20.0+2169] - 2026-09-12

### Added

- Read PDFs inside Hermes from chat Outputs, with page navigation, pinch zoom
  and retry. Reuse one authenticated download and Android's built-in PDF
  renderer. Release the temporary document when the reader closes, while
  keeping external app and save/share options available.

## [2.19.0+2168] - 2026-09-12

### Added

- Open Mermaid diagrams from completed chat code blocks in a zoomable view,
  with source/copy access and normal Back navigation. Rendering uses bundled
  assets without a network service. Invalid or unsupported diagrams keep their
  source available.

## [2.18.0+2167] - 2026-09-12

### Added

- Open Parent chat from Chat actions when Hermes supplies the relationship,
  keeping the original connection and profile.

### Changed

- Remove the phone-only answer-version carousel and obsolete link preferences.
  Regenerate, Branch, Edit and Fork retain their server operations and draft
  protection. A synchronized version carousel remains a backend dependency.

## [2.17.0+2166] - 2026-09-12

### Added

- Open PDF, audio and video files from chat Outputs in a compatible installed
  Android app. Reuse authenticated downloads and private read-only file grants,
  with Save or share available when no viewer is installed.

### Changed

- Group session usage counts, per-model token counts and costs with thousands
  separators so large values are easier to read.

## [2.16.0+2165] - 2026-09-12

### Added

- Check and update explicitly selected Hermes backends from Connections.
  Review the host list before starting, choose one saved connection per dashboard
  endpoint, and retain separate eligibility, progress and outcomes for each host.
  Reuse the existing update controls and manual status refresh.

## [2.15.0+2164] - 2026-09-12

### Added

- Configure custom access-proxy headers in advanced connection settings.
  Store values with existing secure credentials, preserve saved values when
  editing, and use the headers for dashboard requests and WebSocket connections.
  Header-bearing requests reject redirects; managed authentication stays intact.

## [2.14.0+2163] - 2026-09-12

### Added

- Add, remove or clear server goal criteria from the existing Goal view. Keep
  failed additions available for review and confirm removals against the latest
  received criteria. Goal contracts and verification gates remain read-only.

## [2.13.0+2162] - 2026-09-12

### Added

- Read the selected profile's last 30 days of server-recorded sessions, API
  calls, tokens and costs in Hermes administration. Keep estimated and reported
  costs separate, with an optional server model breakdown and manual refresh.

## [2.12.0+2161] - 2026-09-12

### Added

- Start an eligible update on one Hermes host from administration after
  confirmation. Check eligibility again before submitting, follow the
  acknowledged update's status and distinguish incomplete or unconfirmed
  outcomes. Backend restart and multi-host operations remain separate work.

## [2.11.0+2160] - 2026-09-12

### Added

- Edit the selected profile's description and SOUL from Hermes administration.
  Save changes centrally on Hermes, preserve unapplied edits after a partial
  response, and confirm before discarding unsaved text. Profile selection
  remains local to each client.

## [2.10.0+2159] - 2026-09-12

### Added

- Manual connection diagnostics in Hermes administration, with separate
  dashboard/authentication, provider setup and credential-resolution results.
- Installed Android app version/build in App settings and a manual backend
  version/update check in Hermes administration. Update status can remain
  unknown; this release does not apply backend updates.

## [2.9.0+2158] - 2026-09-12

### Added

- Background work in the chat menu shows server loop and heartbeat status,
  cadence and supported Pause, Resume, Stop and Clear controls.
- Session-scoped background process rows show recent output and exit status,
  with targeted Stop and transient Dismiss for finished processes. Refresh
  retrieves the server state; uncertain stops are not retried automatically.

## [2.8.0+2157] - 2026-09-12

### Added

- Goal status and details from Hermes, including criteria, verification,
  turn limits and waiting reasons. Open Goal from the chat menu; an active
  goal also appears in the conversation.
- Supported Pause, Resume, Resume now and confirmed Clear controls use
  acknowledged server state. Goal continuations preserve unsent composer
  text, attachments and queued messages.

## [2.7.0+2156] - 2026-09-12

### Added

- Subagents in the chat menu shows the server's active children. Live events
  also display an expandable roster in the conversation.
- Child details show selectable live output, supported Steer and Interrupt
  controls, with exact chat ownership and server acknowledgements. Rejected
  steering retains the typed guidance; failed refreshes offer Retry.

## [2.6.0+2155] - 2026-09-12

### Added

- Camera in the attachment menu opens Android's camera and returns a photo to
  draft review with the originating chat selected. If that chat cannot be
  reopened, the photo stays available while a destination is chosen.
- Captured photos use the existing private pending-intake queue and draft
  preparation. Cancellation leaves the conversation draft intact; nothing
  sends automatically.

## [2.5.2+2154] - 2026-09-12

### Fixed

- Deleting an already-open chat now accepts Hermes's `session_key` identity.
  The 2.5.1 fix expected `stored_session_id`, which is returned when creating a
  runtime, and failed when Hermes reused an existing runtime. Conflicting IDs
  and profile mismatches still block deletion.

## [2.5.1+2153] - 2026-09-12

### Fixed

- Delete from Chats now closes an idle Hermes runtime before removing its
  history. Previously, any open runtime blocked deletion, even after a response
  completed. Profile ownership is verified before closing; chats still working
  or waiting for input remain protected.

## [2.5.0+2152] - 2026-09-12

### Added

- Incoming Android shares are retained in private app storage until added to a
  draft or explicitly discarded, including before a destination is selected.

### Fixed

- Import failures report an error instead of silently omitting unreadable or
  oversized files. Existing pending shares remain available.
- Draft review and Discard wait for the native acknowledgement; failure keeps
  the pending share available and explains the outcome.
- Reopened chats request context fullness again when the backend finishes
  loading the session. The fuse no longer depends on sending a new message
  after an initial zero-limit response from a still-loading agent.

### Known limitations

- An interruption between saving a conversation draft and clearing its incoming
  share can offer that share again. Review remains mandatory; nothing auto-sends.
- Camera remains planned. The context reopen fix has a reproduced regression;
  the owner's live-server phone check remains outstanding.

## [2.4.0+2151] - 2026-09-12

### Added

- Added review of incoming Android shares with explicit connection, profile and
  new/existing conversation selection. Add to draft preserves existing unsent
  text and files and never sends automatically.
- Added Photos and Files choices to the attachment button using the existing
  picker and image preparation pipeline.

### Fixed

- Shared files are prepared and checked together before changing the destination
  draft. Failed preparation no longer leaves a partially added set of files.
- Incoming shares remain pending until applied or explicitly discarded. A later
  share waits instead of replacing the content currently being reviewed.

### Known limitations

- Incoming content is durable after Add to draft. Before destination selection,
  pending share metadata is in memory and native intake files remain temporary.
- Camera capture is still planned. The reported context-fuse loading problem on
  existing chats remains an active D15 bug pending deployed-server evidence.

## [2.3.0+2150] - 2026-09-12

### Added

- Added Running and Needs input filters to cross-profile Activity.
- Added Unread only to Chats, with explicit loaded-page coverage and access to
  older pages even when the current page has no unread chats.
- Added project rename, appearance and confirmed deletion through server-owned
  project actions. Project icons and colors now display server metadata.

### Changed

- Moved the context fuse onto the message box's top border and added a small dot
  at the current usage position, removing the separate composer row.

### Known limitations

- The session API has no unread query filter. Unread title search covers loaded
  pages, and older pages must be loaded to complete the list.
- Live gateway verification remains outstanding for project changes.

## [2.2.0+2149] - 2026-09-12

### Added

- Added expandable live execution details for tools, server todos and available
  reasoning, with bounded raw payload display and server-reported duration.
- Added Find in chat over bounded, server-owned saved history. Results report the
  full match count while displaying at most 100 expandable matches.
- Added per-chat Outputs for delivered files, images and links, with authenticated
  reads and downloads scoped to the original host, profile and conversation.
- Added zoomable authenticated and embedded image previews, selectable text/code
  previews, and Android save/share delivery using the retrieved file bytes.

### Changed

- Saved-history loading now uses bounded oldest-first pages, includes compacted
  rows and reports incomplete or malformed history instead of caching it locally.
- Downloads enforce a 32 MiB limit and reduce server-provided filenames to safe
  decoded basenames.

### Known limitations

- Output discovery is derived from transcript references, so it can miss silent
  outputs or show a path whose file was removed.
- Interactive backend HTML and specialized audio, video and PDF viewers remain
  incomplete. Live behavior on the owner's gateway has not yet been verified.

## [2.1.5+2148] - 2026-09-12

### Added

- Added saved-message Edit and resend with explicit history-replacement
  confirmation, row-addressed server truncation and correction retention until
  acknowledgement.
- Added a one-shot, text-only Fork action from the latest loaded saved answer.
- Added distinct `/btw` result cards correlated by server task ID.
- Added narrow-screen Markdown table and fenced-code improvements, zoomable web
  image preview and a server-reported context fuse beside the composer.

### Changed

- Edit and Fork preserve unrelated draft text and attachments. Edit pauses queued
  follow-ups, and Fork clears its source draft only after the child send is
  acknowledged.

### Known limitations

- Answer-version grouping remains local to the phone. Diagram rendering,
  authenticated backend media and specialized media previews were not completed.
- Source checks and fixtures do not establish live gateway compatibility.

## [2.1.4+2147] - 2026-09-12

### Added

- Added per-profile Activity discovery for ongoing work, retaining each chat's
  original owner and reporting profiles that could not be queried.
- Added dedicated sudo, secret and vault request forms with request expiry and
  duplicate-response guards. Sensitive values are not saved in drafts or chat.
- Added independent completion and attention notification switches, optional chat
  titles and a permission-and-test notification action.
- Added text-only per-chat queues and one-shot Steer through Message actions and
  holding Send/Stop. Queues can be reviewed, removed, paused and resumed.

### Changed

- Queued messages send in order after completed turns and pause after stop,
  failure or uncertain delivery. Separately typed drafts and attachments remain.

### Known limitations

- The phone must stay connected to drain queued work. Attachment queueing,
  process-death restoration of sensitive prompts and background push remain
  unavailable. Live gateway behavior was not verified for this milestone.

## [2.1.3+2146] - 2026-09-11

### Added

- Added durable unsent drafts and staged attachment references scoped to the
  verified connection identity, profile and saved conversation.
- Added provider-grouped model selection that preserves the exact server route,
  plus session-scoped `/yolo` state and changes.
- Added server-advertised approval scopes and independent device settings for
  completion and attention alerts.

### Fixed

- Reopening a loaded chat now refreshes server execution and pending-input state.
- Accepted sends clear only the submitted draft. Text typed during acknowledgement
  remains, missing staged files retain draft text, and lost acknowledgements never
  trigger automatic resubmission.

### Known limitations

- This release adds no offline transcript, accepted-work outbox, global model
  override or background push. Live gateway and phone workflow checks remained
  outstanding after the automated release checks.

## [2.1.2+2145] - 2026-09-11

### Changed

- Added the shared left drawer for Chats, Activity, Connections, App settings and Hermes administration.
- Applied the workspace style to connection setup and device settings; moved existing password fields into the main connection form.
- Added a read-only administration entry using already-discovered connection/profile information.
- Removed unreachable legacy screens, navigation widgets and unused UI dependencies. Saved data and current conversation behavior are preserved.
- Recorded the Desktop comparison and owner-selected mobile roadmap. New backend features and Firebase notifications remain planned.

## [2.1.1+2142] - 2026-09-08

### Fixed

- Forking a conversation now counts hidden stored notices before the selected
  answer. The earlier repair was absent from the personal release checkout,
  causing valid fork actions to report an incorrect copied-answer boundary.

## [2.1.1] - 2026-09-06

### Fixed

- Parse the batch `questions[]` clarify payload emitted by stock Hermes
  gateways, not just the custom desktop gateway shape (PR #95).

### Changed

- Release builds now fail when an APK lacks a valid signing block, so unsigned
  artefacts can no longer be tagged and published (PR #96).

## [2.1.0] - 2026-09-03

Community daily-driver workspace edition from
[@CarlosReyesPena](https://github.com/CarlosReyesPena) (PR #88).

### Added

- Workspace shell: Home attention digest, global New chat button, Activity
  operational timeline, More pane routing Cron/Skills/Memory/Settings/dashboard.
- Projects pane over the gateway `projects.*` RPC family: tree overview,
  per-project chats, Spaces→Projects migration preview and write path, chat
  moves between projects, per-project search, safe deletion, and legacy-gateway
  compatibility mode.
- Chats browser with All/Recent/Unassigned/Archived filters, date grouping,
  status and project labels.
- Session search with three per-connection modes: on-device, dashboard FTS5
  full-text with matching excerpts, and AI-assisted query rewriting.
- Encrypted configuration export/import (PBKDF2 + AES-256-GCM), with restore
  available from the empty-connection state.
- Quick chat lifecycle: app shortcut, share-target intents, share review
  sheets, 72-hour archive policy.
- Gateway capability discovery (CapabilityRegistry) so older gateways degrade
  gracefully instead of erroring.
- Runtime Android 13+ notification permission request.
- Chat UI: sticky context header, You/Hermes role labels, long-press action
  sheet, fenced code blocks with copy and wrap/scroll toggle, full tool output
  on expanded activity cards.

### Fixed

- Fresh TCP per request with a 20 s timeout fixes stale keep-alive hangs.
- FAB no longer swallows taps on the More destination.

### Validation

- `flutter analyze` clean; 941 Flutter tests pass (including release-identity
  gates), CI green on PR #88.
- Secret scan of the merged diff: no real credentials (test fixtures only).

## [1.0.14-hermesapk.14] - 2026-07-30

### Added

- Remote Gateway attachments now identify the mobile source channel and active
  ATLAS profile so the server can register them in the canonical document inbox.
- The attachment response carries the document-intake status without exposing
  credentials or raw user/session identifiers.

### Changed

- Chat upload remains available if document catalog registration is temporarily
  unavailable and shows a non-blocking pending notice to the operator.

### Validation

- Static analysis passes with `--fatal-infos`.
- 113 Flutter tests pass.
- The synthetic Desktop Gateway contract suite passes with the extended
  `atlas_intake` response.
- An ARM64 debug APK builds successfully. It remains a private test artifact
  signed with the Android debug certificate.

## [1.0.13-hermesapk.13] - 2026-07-30

Community Remote Gateway edition based on Hermes Android 1.0.13.

### Added

- A unified Desktop Gateway JSON-RPC chat transport with session resume/create,
  reconnect handling, streaming, interruption, and persistent chat mapping.
- Per-chat model and thinking-effort selection. Supported effort values follow
  the Hermes Desktop contract: `none`, `minimal`, `low`, `medium`, `high`,
  `xhigh`, `max`, and `ultra`.
- Up to 10 mixed attachments per message, 16 MiB each, uploaded through
  `file.attach`, with per-file progress, remove, failure, and retry states.
- Selectable Markdown, Copy, Read aloud, Edit and resend, Regenerate, Stop,
  conversation export, session search, Rename, Branch, and Delete.
- Native handling for approval, sudo, secret, clarification, notification,
  reasoning, interim message, tool activity, background result, review summary,
  and subagent events from Hermes Desktop Gateway.
- A local synthetic Desktop Gateway fixture and contract test suite under
  `tools/fake_gateway`.
- A separate debug application ID (`com.hermesagent.hermes_android.dev`) so the
  community test build can coexist with the upstream application.

### Changed

- Text, images, and files in Desktop Gateway profiles now share one session and
  one JSON-RPC transport instead of splitting new messages across REST and
  WebSocket paths.
- Model and thinking overrides are scoped to one conversation; the profile
  default remains controlled from Settings.
- Release signing no longer falls back to the Android debug key. A real release
  requires an explicitly configured private keystore.

### Fixed

- Branch actions no longer open a dialog while the popup route is being torn
  down, preventing the Flutter `_dependents.isEmpty` assertion.
- If Hermes creates a branch but returns a late JSON-RPC error, the app refreshes
  history and reconciles the successful result instead of showing a false
  failure.
- Dashboard dialogs no longer refresh their parent while an IME-dependent route
  is closing.
- Microphone permission is requested only after an explicit microphone action.
- Session identity, official terminal events, retry state, delayed events, and
  duplicate tool progress are handled defensively.

### Validation

- 110 Flutter tests pass.
- The synthetic gateway contract suite covers Dashboard authentication,
  session lifecycle, model/reasoning configuration, attachments, streaming,
  interruption, interactive requests, activity, notifications, and subagents.
- The ARM64 debug build was validated on a physical Android phone connected to a
  private Remote Gateway network.

## [1.0.13]

### Changed
- Updated the Flutter package version to `1.0.13+113` so generated Android
  builds report the same version as the GitHub `v1.0.13` release.

## [1.0.12]

### Added
- **Session source filters** in Settings. Mobile users can now choose which
  Hermes session origins appear in the session list, including scheduled tasks,
  developer tool calls, CLI chats, desktop sessions, and messaging platforms.
- Filter preferences are scoped per saved connection so settings for one Hermes
  gateway do not affect another.

### Changed
- Session filtering is performed client-side against each session's recorded
  source, so it works without any Hermes Gateway API changes.

## [1.0.8]

### Added
- **Reverse-proxy path prefixes** for Gateway API and dashboard routes. Gateway
  prefixes are applied before `/api` and `/v1` routes; dashboard prefixes are
  applied before dashboard `/api` routes.
- **Proxied dashboard mode** for deployments where nginx/Caddy/another proxy
  injects dashboard authentication. In this mode the app sends clean dashboard
  requests without scraping the SPA token or using password login.
- **Dashboard / Proxy Settings** can edit gateway prefix, dashboard prefix,
  proxied-dashboard mode, dashboard port, and dashboard credentials after a
  connection is created.

### Fixed
- Existing chat history, streaming chat completions, session browsing, API-key
  validation, and dashboard validation now consistently use configured path
  prefixes.

## [1.0.7]

### Added
- Support for **password-protected dashboards**: the Memory, Cron Jobs, Skills,
  and Settings screens now authenticate against a basic-auth dashboard via the
  `/auth/password-login` flow and reuse the returned session cookie. Open
  (`--insecure`) dashboards continue to work via the existing token scrape.
- **Configurable dashboard port** per connection (`dashboardPortOverride`),
  defaulting to the previous behaviour (`9119` for HTTP, the external port for
  HTTPS) when unset.
- **Dashboard details in the Add Connection dialog** under a collapsible
  "Custom dashboard details" section, plus a **Dashboard Login** entry on each
  connection's overflow menu. Both validate the dashboard before saving.

### Changed
- `DashboardClient` accepts an optional `http.Client` for testability and
  de-duplicates concurrent login / token requests.

### Fixed
- Updating a connection's API key no longer clears its saved dashboard settings.
