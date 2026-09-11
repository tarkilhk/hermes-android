# Hermes Desktop and Android feature analysis

Research date: 2026-09-11.

> The owner has now selected and narrowed the backlog in [PRODUCT_PLAN.md](PRODUCT_PLAN.md). That plan supersedes this report's recommendations, including navigation placement, mobile notification scope, voice priority and local-state assumptions. This report remains the dated research record. The README was corrected after the audit, so references below to its overstatement describe the pre-correction README. Follow-up [contract notes](research/FEATURE_PLAN_CONTRACT_NOTES_2026-09-11.md) correct the model-picker description and qualify `/yolo` support.

## Product recommendation

Hermes Android should let you give Hermes work, leave the app, return when your input is needed, and use the result. The most valuable desktop capabilities are conversation continuity, finding the right work, understanding progress, answering requests, and taking useful output into another app.

Do not use a desktop parity percentage as the target. A phone client can be excellent without an integrated terminal, a host filesystem tree, a pane layout editor, or local runtime installation. It cannot be excellent if a completed report is inaccessible, a permission request leaves work stuck, a reconnect loses the task, or sharing a screenshot requires several manual steps.

There is a significant baseline correction. The current Android entry point opens `ProfileWorkspaceScreen`. Much of the broader v2.1 feature set still exists in the repository in the older `WorkspaceScreen` and `ChatScreen`, but those screens are not the route used when opening a saved connection. The README therefore describes more capabilities than the current primary interface exposes. This report distinguishes active features, partial implementations, and retained older code. [A-entry] [A-workspace] [A-inventory]

## Scope and evidence

- Desktop baseline is official `NousResearch/hermes-agent` main at `d15ed4445207dda418b984e8bda0f68f48b8c6f3`, committed 2026-09-11. I fetched a fresh source checkout and inspected route registration, controls, stores, and transport adapters. This is the current source snapshot, not a claim about the version installed on your computer or the latest packaged installer. [D-root]
- Android baseline is this fork at `b8f1d981a272059076cefce179e2de9596dc9e06`, committed 2026-09-11. Its working tree was clean before the research documents were added.
- "Present" means implemented and wired in the inspected source. I did not launch either app or exercise a live gateway in this audit. Existing tests and earlier verification notes are supporting evidence, not tests run for this report.
- Scope is the built-in Desktop app and its first-party settings and extension interfaces. Arbitrary third-party plugin functionality and every tool Hermes can invoke are not finite client features. A plugin route can add more UI after installation. [D-routes]
- Desktop local and remote modes differ. Host files and Git operations can use remote APIs; OS window controls and local runtime installation cannot. The same named feature may still require gateway support, authentication, host tools, or a cloud account. [D-fs] [D-git] [D-management]
- The older roadmap documents in this fork are useful history. Their proposed features are not evidence of implementation and are not treated here as requirements you have approved.

Supporting inventories contain the deeper implementation evidence:

- [Current Android inventory](research/HERMES_ANDROID_FEATURE_INVENTORY_2026-09-11.md).
- [Desktop chat and agent interaction inventory](research/HERMES_DESKTOP_CHAT_INVENTORY_2026-09-11.md).
- [Desktop management and settings inventory](research/HERMES_DESKTOP_MANAGEMENT_INVENTORY_2026-09-11.md).

## How to read the feature matrix

Android status:

| Label | Meaning |
| --- | --- |
| Active | Available through the current profile workspace or connection home. This does not claim live verification on every backend. |
| Partial | A narrower form is active, or an important part is missing. |
| Command | Available through the slash-command path when the gateway supports it; a dedicated mobile control is absent. |
| Retained | An implementation remains in older screens or services but is not exposed through the primary profile workspace. It needs integration and verification before counting as available. |
| Gap | No equivalent active client experience was found. |

Mobile fit:

| Label | Decision |
| --- | --- |
| Essential | Central to productive mobile use. Preserve or build a first-class experience. |
| Useful | Worth adding in a compact, task-focused form. |
| Specialist | Useful to a smaller group, such as people supervising coding or operating several gateways. Put it behind a secondary entry point. |
| Omit | Do not spend mobile product effort copying this desktop mechanism. Where appropriate, preserve the underlying task through another interaction. |

Priorities are recommendations, not a promise of implementation. P0 makes work dependable and unblocks it. P1 completes everyday input, retrieval, and output. P2 covers occasional administration and advanced work. P3 is optional polish or specialist expansion. "Keep" means maintain the active behavior, rather than rebuild it merely for parity.

## Feature matrix

The matrix contains 197 feature decisions across 12 themes. Related controls are grouped where they solve the same user task; the supporting inventories provide the finer breakdown. A further 13 Android-specific additions follow the comparison.

| Theme | Android's current position | What mobile needs most |
| --- | --- | --- |
| Conversation discovery and organization | Strong active foundation | Better search navigation, complete unread lifecycle, share/export |
| Projects and execution context | Active browse/create/move; limited administration | Clear working destination, occasional project controls |
| Composing and conversation control | Strong models, commands and answer branching | Durable drafts, edit/resend, visible steering and queueing |
| Reading answers and agent work | Basic text/code and tool history work | Rich outputs, find-in-chat, useful progress and errors |
| Running work and attention | Scoped concurrent work and partial Activity/notifications | Reliable return-to-work inbox, complete requests for input, lifecycle delivery |
| Voice and quick entry | Share/shortcut intake active; voice retained | Dictation, camera/photo capture, read-aloud |
| Files and artifacts | Uploads active; output access is weak | Per-chat Outputs, preview, download and share |
| Coding and terminals | Project context and some tool output | Read-only changes/PR supervision before Git or terminal controls |
| Connections, profiles and administration | Strong profile ownership; narrower authentication/setup | Repairable connections, status, selected administration |
| Providers, capabilities and memory | Commands active; management UI largely absent | Capability readiness, skill invocation, memory correction |
| Automation and integrations | Earlier Cron implementation retained | Run history/results, pause/resume, pairing decisions |
| Settings and conveniences | Several controls retained or absent | Reachable accessibility/notification settings; omit most desktop decoration |

### 1. Conversation discovery and organization

Desktop evidence: session menus, filters, export, import, and profile-aware navigation. Android evidence: current browser, row actions, gateway, and controller. [D-session-menu] [D-filters] [D-export] [D-import] [A-browser] [A-rows] [A-controller]

| ID | Desktop feature | Android today | Mobile fit and justification | Recommendation |
| --- | --- | --- | --- | --- |
| C01 | Create a conversation and resume stored history | Active, scoped to connection and profile | Essential. Starting quickly and continuing the same task are the core workflow. | Keep |
| C02 | Paginated session browsing and older transcript loading | Active; sessions and history load in pages | Essential. Long-running use must not hide older work or load everything into phone memory. | Keep; verify large histories |
| C03 | Search conversations | Active server full-text search; bounded result set | Essential. On a phone, search is faster than navigating a large tree. Excerpts and opening the matching place matter more than elaborate filters. | P1, improve result navigation and limits |
| C04 | Rename a chat; copy its ID | Active | Useful. A useful title aids retrieval; copying an ID helps support and cross-device reference. | Keep |
| C05 | Pin and unpin chats | Active | Essential for returning to a few ongoing jobs. Pinning is cheaper than repeatedly searching. | Keep |
| C06 | Archive, view archives, restore, delete | Active; busy work has action restrictions | Essential. Phones need a short useful list and a clear recovery path for archived work. | Keep |
| C07 | Unread state and explicit mark read/unread | Active explicit mutations; full automatic completion/open lifecycle not established | Essential. A completed response needs to remain discoverable until you have dealt with it. | Keep; complete and verify lifecycle across devices |
| C08 | Filter by work status, profile, project, PR; group and sort by date, status, usage, cost or manual order | Partial. Profile/project browsing, archives and automated-chat visibility exist; full desktop filter suite does not | Useful for Needs input, Running and Unread. Cost ordering and PR filters are specialist. Avoid importing every option into one menu. | P1 for task-state views; P3 for advanced filters |
| C09 | Optional All profiles and grouped gateway browsing | Partial. Android switches profiles and retains their running work; no full merged desktop browser | Useful for an attention list; specialist for a merged archive. Keep host and profile labels on every actionable item. | P1 attention across owners; P2 merged search |
| C10 | Manual list reordering, row density and session colors | Gap for these controls; pinning and workspace accent are narrower alternatives | Useful only where it improves recognition. Dense per-row metadata and many appearance controls consume scarce screen space. | P3 |
| C11 | Export a conversation as JSON | Command `/save` and retained older export code; no equivalent active native export flow | Useful. Share a readable answer first; offer transcript export for records. A file saved on the server is not yet a file usable on the phone. | P1 native share; P2 full export |
| C12 | Import and continue Claude Code or Codex sessions from the connected host | Gap | Specialist. Valuable for cross-tool coding continuity, but not a prerequisite for everyday Hermes use. Preview the imported context before continuing. | P3 |

### 2. Projects and execution context

Desktop projects own folders and present repository and worktree lanes. They are more than chat folders. Desktop creation requires a folder; moving a session changes its working directory. Android has already adopted meaningful project context, but has fewer administration and branch controls. [D-projects] [D-project-dialog] [D-project-menu] [D-worktree] [D-lanes] [A-controller] [A-rows]

| ID | Desktop feature | Android today | Mobile fit and justification | Recommendation |
| --- | --- | --- | --- | --- |
| P01 | Browse projects and their conversations | Active | Essential when Hermes works on several ongoing subjects or repositories. Show useful names before raw paths. | Keep |
| P02 | Start a chat in a project or start a detached chat | Active | Essential. The user must know which workspace receives the work. | Keep |
| P03 | Create a project with a name and working folder | Active, basic form | Useful. Prefer existing host locations or a server-provided default; typing long paths is awkward. | P2 improve folder selection |
| P04 | Rename and delete a project | Retained in older project detail; absent from active browser | Useful. These are occasional organizational actions that belong in a project menu. Reuse the behavior with current profile ownership. | P2 |
| P05 | Multiple folders per project; add another folder | Gap in active project UI | Specialist. Useful for related repositories, but a single primary folder covers most phone submissions. | P2/P3 |
| P06 | Set an active project/default context | Partial; Android selects a project and uses it for creation | Essential to make the destination clear. Distinguish current navigation from a server-wide default. | Keep explicit creation context |
| P07 | Move a conversation to another project's working directory | Active, with a consequence explanation | Useful. This can change where future tools run, so it must not look like a cosmetic filing action. | Keep |
| P08 | Project icon/color and adoption of auto-discovered repositories | Partial. Automatic project colors and discovered projects exist; no custom appearance or explicit adoption controls | Useful recognition aid, especially for many similar names; not a productivity blocker. | P3 |
| P09 | Browse repository/branch/worktree lanes | Partial. Project session-tree data is consumed; full lane controls are absent | Specialist but valuable for supervising coding. Show the selected branch/worktree on a task detail view. | P2 read-only context first |
| P10 | Create a worktree, choose a base branch, open or track an existing branch | Gap | Specialist. A short "Start isolated coding task" form can be useful without a full Git interface. | P2/P3, only after reliable context selection |
| P11 | Switch the main checkout's branch; remove a worktree | Gap | Specialist. These affect other work on the host. They are infrequent and need a clear server-side result and conflict explanation. | P3 |
| P12 | Generate a starter project idea from a name or template | Gap | Omit as a dedicated mobile control. Ordinary chat already handles brainstorming; it does not help users resume or finish work. | No parity work |
| P13 | Reveal project folders in Finder/Explorer; copy paths | Gap; no active project reveal/copy-path control | Omit OS reveal. Copying a path can be added to details for diagnosis and precise references. | P3 copy only |

### 3. Composing and controlling a conversation

Desktop evidence includes draft persistence, structured references, command completion, model controls, queue actions and history rewinding. Android's active controller already handles model changes, command discovery, branches and conservative submission. [D-chat] [A-workspace] [A-controller] [A-gateway]

| ID | Desktop feature | Android today | Mobile fit and justification | Recommendation |
| --- | --- | --- | --- | --- |
| Q01 | Multiline prompt, streaming submission and Stop | Active | Essential. Keep these obvious and usable with the keyboard open. | Keep |
| Q02 | Saved per-conversation text and attachment drafts | Partial. Drafts remain across navigation while the controller lives; process-death persistence is missing | Essential. Phone interruptions must not erase work before it is sent. | P0 |
| Q03 | Attach images/files, paste images, attach a URL | Partial. Repeated single-file picker and share intake work; richer acquisition/preview UI is absent | Essential. Preview selected files and preserve them through failed uploads. | P1 |
| Q04 | Structured references and `@` completion for files, folders, URLs, tools, Git and diffs | Gap beyond ordinary attachments and typed links | Useful for files/links; specialist for Git context. Mobile can use an Add context sheet instead of requiring punctuation on the keyboard. | P2 |
| Q05 | Slash catalog, aliases, skill commands and argument completion | Active via modern gateway catalog and dispatch | Essential capability discovery. Keep the catalog server-owned and add a visible entry button for touch use. | Keep; P1 discoverability |
| Q06 | Prompt snippets and user quick commands | Partial. Server commands are callable; no native snippet editor/picker | Useful for repeated productive tasks. User favorites matter more than copying Desktop's development templates. | P2 |
| Q07 | Correct a previous user message and resend after rewind | Retained older edit/resend UI; no active equivalent | Essential. Typos and dictation errors are common. Explain what happens to subsequent conversation context. | P1 |
| Q08 | Branch at a selected assistant answer | Active | Useful for exploring alternatives without losing the original. Distinguish a conversation branch from a Git branch. | Keep |
| Q09 | Regenerate, alternate response navigation and earlier-history restoration | Partial. Active regenerate/version navigation uses separate server sessions and locally stored grouping | Useful. Android already has a considered alternative-history model; do not replace it merely to mimic Desktop. It does not sync Desktop's version picker. | Keep; P2 interoperability |
| Q10 | Steer a currently running task | Command `/steer`; Stop is a native control | Essential for mobile supervision. A visible "Send correction now" action should expose the existing capability. | P1 |
| Q11 | Queue next prompts with attachments; edit/delete, send next/now, resume queue | Gap. Drafting while busy works, but ordinary send is blocked | Useful. Capture the next instruction immediately and show whether it runs after the current task or changes it now. | P1 after durable drafts |
| Q12 | Side questions and background prompts without replacing the main run | Command `/btw`, `/bg` and `/background` | Useful. Ask a quick clarification about ongoing work without derailing it. Add distinct status/results rather than another spinner. | Keep command support; P2 UI |
| Q13 | Compact context manually, optionally focused on a topic | Command path can dispatch supported server commands; no dedicated active control | Useful for long sessions. Show when compaction occurs and what conversation continuity means. Do not promise every gateway accepts every option. | P2 |
| Q14 | Select a model/provider for the current conversation | Active searchable picker | Essential. Preserve current per-chat ownership and acknowledged changes. | Keep |
| Q15 | Reasoning effort, fast mode and per-model presets | Partial. Reasoning effort is active; no full Desktop fast/preset suite | Useful. Effort is already available; expose speed-specific options only where supported. | Keep effort; P2 fast/presets |
| Q16 | Model shortlist, provider collapse, refresh and override indicators | Partial. Searchable flat picker with provider subtitles; no collapsible provider sections | Useful. Favor a short set of suitable choices and clearly distinguish the chat override from the profile default. | P2 |
| Q17 | Select a configured mixture-of-agents preset | Backend-dependent catalog possibility; no specialized UI established | Specialist. Selecting a server preset may be enough; orchestrator editing does not belong in the basic composer. | P3 |
| Q18 | Session status/help and messaging-platform handoff commands | Status/help active; catalogued messaging-only commands are explicitly rejected on Android | Useful status/help; specialist handoff. Opening the same conversation on another device takes priority. | Keep discovery; P2/P3 handoff |

### 4. Reading answers and inspecting agent work

Desktop's transcript handles more event types and richer output than the current Android profile transcript. Retained Android widgets can help, but their presence alone does not establish active rendering. [D-chat] [A-workspace] [A-inventory]

| ID | Desktop feature | Android today | Mobile fit and justification | Recommendation |
| --- | --- | --- | --- | --- |
| T01 | Streaming prose, interim text and finished answers | Active | Essential. Clearly separate useful output from running status. | Keep |
| T02 | Selectable Markdown, code blocks and copying | Active | Essential. Reusing text and reading code are basic productive actions. | Keep |
| T03 | Highlighted code, mathematical notation, tables and expanded large blocks | Partial. Markdown/code exist; equivalent math/rich rendering was not established | Useful. Make wide content readable in an expanded view instead of squeezing it into a bubble. | P1 common content; P2 math |
| T04 | Mermaid, SVG and structured visual/listing blocks with source fallback | Gap for dedicated renderers | Useful for plans, diagrams and structured results. Plain readable fallback comes before exhaustive renderer parity. | P2 |
| T05 | Inline images, generated-image results, audio/video playback | Partial. Current Markdown image handling offers an external Open image link | Essential for images and common deliverables; useful for audio/video. The phone must be able to consume the output. | P1 images; P2 other media |
| T06 | Rich link embeds for maps, video, social and music providers | Gap beyond ordinary external links | Useful selectively. A useful title/thumbnail and open-in-app action cover most needs. | P2/P3 |
| T07 | Live tool status and structured expandable tool results, logs, search hits and diffs | Partial. Active tool label and collapsed persisted results; older richer handling retained | Essential summary and failure details. A user needs to distinguish healthy progress from a stuck tool. | P1 |
| T08 | Collapsible reasoning and elapsed time | Retained richer reasoning; no equivalent active presentation | Useful when the backend emits it, but optional. Prefer progress and outcome over filling the phone with intermediate text. | P2 |
| T09 | Todo/checklist progress and task summary | Gap in active native status | Useful. A short progress summary saves rereading tool logs. | P1/P2 |
| T10 | Context usage, token limits, estimated values and category breakdown | Command `/status` is a narrower view | Useful. Show a compact warning and details sheet when nearing a limit; avoid a permanent debugging dashboard. | P2 |
| T11 | Find within the displayed conversation with next/previous matches | Gap in active transcript-specific search | Useful. Global history search does not replace finding a passage inside a long answer or chat. | P1 |
| T12 | Older-history loading, preserve reading position, jump to latest | Active; some reading state is in memory | Essential. Streaming and keyboard changes must not move the reader away from earlier content. | Keep; P0 persistent return state |
| T13 | Message reactions and emoji acknowledgements | Gap; Desktop reactions are opt-in and default off | Optional. Useful for lightweight feedback, but lower value than actionable questions and unread results. | P3 |
| T14 | Distinct system notices, inter-agent deliveries and linked task references | Partial event/rendering coverage | Useful. Users need to know whether text is their agent's answer, a tool event, or another task's delivery. | P2 |
| T15 | Copy, branch, regenerate and read-aloud answer actions | Partial. Copy, branch and regenerate are active; read-aloud is retained | Essential copy; useful other actions. Add native Share and restore read-aloud through a touch-friendly menu. | P1 |

### 5. Running work, attention, and continuity

This is the highest-value supervision theme. Desktop has distinct protocols for permissions, clarification, secrets, vault actions and verification codes. It also has subagent and goal/heartbeat/loop controls when supported by the backend. Android currently covers a useful subset. [D-chat] [A-controller] [A-entry] [A-inventory]

| ID | Desktop feature | Android today | Mobile fit and justification | Recommendation |
| --- | --- | --- | --- | --- |
| R01 | Continue running work when switching conversations or profiles | Active application-owned profile resources | Essential. Leaving a conversation must not cancel it or retarget its events. | Keep |
| R02 | Reconnect/resume and reconcile server history | Active pending-identity journal and conservative no-resend; not a durable offline outbox | Essential. Build on the current ownership checks and show uncertain outcomes honestly. | P0 strengthen lifecycle acceptance |
| R03 | Work status, unread completion and attention across sessions | Partial. Activity lists application-owned work across visited profiles | Essential. Expand toward authoritative pending/running/completed server state, including work initiated elsewhere. | P0 |
| R04 | Approve once or reject a requested action | Active, including resume hydration | Essential. This is a prime reason to open Hermes on a phone. Keep target, action and consequences visible. | Keep; P0 expiry/retry acceptance |
| R05 | Per-session/permanent allow choices and profile approval policy | Partial. Active reply permits once/deny only | Useful for policy inspection; specialist for broad changes. Keep request permission and profile policy clearly separate. | P2 |
| R06 | Session-specific automatic approval override such as `/yolo` | No dedicated active UI; server command support may vary | Specialist. Do not make it a large primary button. If supported, show its scope and effective state. | P3 |
| R07 | Structured choices/free text and multiple clarification questions | Active sequential question flow | Essential. Preserve entered answers on transient failure and make stale requests explicit. | Keep; P0 acceptance |
| R08 | Masked sudo/password and environment-secret requests | Retained older dedicated handling, absent from active event path | Essential when these block supported work. They require dedicated routes, not an ordinary chat message. | P0 supported request families |
| R09 | Vault unlock, save-login and one-time verification-code requests | Gap in active native experience | Useful and potentially blocking. Phones often hold the password manager/authenticator. Scope delivery to the requesting task. | P0 if advertised; otherwise P2 |
| R10 | Subagent roster, progress, queue state and elapsed time | Retained generic subagent insight handling; no active roster | Useful. A compact summary helps explain parallel work without exposing every subagent by default. | P2 |
| R11 | Inspect a subagent transcript and steer/interrupt that subagent | Gap | Specialist. Valuable when a parallel task is wrong or blocked; use a task detail screen. | P2/P3 |
| R12 | Goal objective/criteria/progress with pause, resume, wait-resume and clear | Gap in dedicated active UI | Useful for long-running work. Prioritize objective, current state, blocked reason and stop/pause controls. | P2 |
| R13 | Edit goal criteria and inspect verification/quality-gate details | Gap | Specialist. Useful for changing requirements away from a desk, but less urgent than seeing and stopping work. | P2/P3 |
| R14 | Heartbeat and loop status, cadence, counts, pause/resume/stop | Gap as dedicated controls; command availability is server-dependent | Useful. Recurring work needs visible ownership and an easy way to pause it. | P2 |
| R15 | Background process status, stop and dismiss | Partial. Background command results exist, no full process control panel | Useful. A bounded status/actions sheet is enough; a terminal is unnecessary. | P2 |
| R16 | Native notifications by category, deduplication and opening the originating task | Partial. Local attention/completion notifications and owner-aware taps exist; no proven process-dead push | Essential. Mobile policy should cover followed offscreen tasks rather than copy Desktop's narrower completion gating. | P0 delivery; P1 preferences |
| R17 | Notification buttons and in-app notices | Partial. Tap routing and transient error feedback; no inline notification actions | Useful. Direct reply can save time. For consequential requests, open the task so the decision has context. | P1/P2 |
| R18 | Error-specific recovery: retry, new chat, reauthenticate, change provider, copy diagnostics | Partial. Retry/errors and model selection exist; no complete classified recovery flow | Essential. A failure should explain whether the user should wait, reconnect, fix credentials or choose another model. | P0 common errors; P1 details |

### 6. Voice, capture, and quick entry

Desktop voice includes both editable dictation and a separate ongoing voice conversation with interruption. Android currently retains earlier voice services but does not expose them in the profile composer. The OS keyboard may offer dictation independently; that is not an app-integrated voice feature. [D-chat] [A-inventory]

| ID | Desktop feature | Android today | Mobile fit and justification | Recommendation |
| --- | --- | --- | --- | --- |
| V01 | Dictate into an editable draft | Retained older app voice implementation | Essential. Review and correction before Send make long mobile prompts practical. | P1 |
| V02 | Speak an answer aloud or automatically speak replies | Retained older TTS implementation | Useful for accessibility and hands-busy use. Keep stop/playback controls available. | P1 |
| V03 | Continuous voice conversation with listening/transcribing/thinking/speaking states | Gap in the active client | Useful after text supervision and dictation are reliable. It is a distinct feature, not simply microphone dictation plus TTS. | P2 |
| V04 | Interrupt speech/generation by speaking; stop/end/mute controls | Gap in active voice experience | Essential once continuous voice exists. Users must be able to stop a long reply and know when the microphone is live. | With V03 |
| V05 | Wake word with local or remote-client microphone capture | Gap | Omit initially. Explicit launch/share/microphone actions offer most of the value with fewer background and battery demands. | P3 only if justified |
| V06 | Global quick-entry window targeting current/new/recent conversations | Partial mobile equivalent: launcher shortcut and share intake create a chat | Essential purpose, desktop-specific form. Improve destination selection and draft retention; do not copy a floating desktop window. | P1 |
| V07 | Clipboard images, file pickers and quick attachment actions | Partial file/share support; no active app camera action | Essential mobile adaptation. Camera/photo/screenshot capture should be easier than locating a file on the host. | P1 |

### 7. Files, artifacts, and previews

Desktop has both a filesystem browser and a separate artifact library. The library extracts images, files and links from recent conversations. In this snapshot it starts from 30 recent sessions, so it should not be mistaken for a complete server-wide document index. Remote artifacts can be downloaded through the gateway. The file preview supports images, PDFs, readable text, rendered Markdown, source and diffs; readable whole text can be edited. [D-artifacts] [D-preview-file] [D-fs] [D-file-actions] [D-browser-bar] [A-inventory]

| ID | Desktop feature | Android today | Mobile fit and justification | Recommendation |
| --- | --- | --- | --- | --- |
| F01 | Browse the connected workspace's directory tree | Retained older Files screen; no active equivalent | Specialist. Your intuition is right for a general tree. On a phone it is usually a slow way to find the result of a conversation. | P3, secondary tool at most |
| F02 | Select a host file or folder as context | Partial. Phone file attachment is active; no comparable remote picker | Useful when the needed file already lives beside the project. A bounded project file search is more useful than an unrestricted filesystem browser. | P2 |
| F03 | Click an output file and read it | Gap in active artifact handling | Essential. A report, PDF or generated image is often the actual deliverable. A printed host path does not finish the job. | P1 |
| F04 | Download a remote artifact to the client | Gap in active native flow | Essential. Users need to save results locally and open them in the appropriate Android app. | P1 |
| F05 | Browse generated images, files and links, then return to their conversation | Gap; older Assets ideas are not an implemented library | Useful. A per-chat Outputs list is essential first; a recent-results library follows. Preserve the source host, profile and chat. | P1 per chat; P2 library |
| F06 | Image zoom and previews; PDF viewing; formatted Markdown and code files | Partial answer rendering; no equivalent general file viewer | Essential for common outputs. Use native viewers where they are better; preserve the return path to Hermes. | P1 |
| F07 | Open interactive HTML or a web page alongside chat | Gap as a client preview experience | Useful. On phones use a full-screen preview and a clear return to chat. Do not require simultaneous narrow panes. | P2 |
| F08 | Navigate a browser preview, reload, copy its URL, open it externally | Ordinary text links are a narrower path | Useful. A server's localhost address may not be reachable from the phone, so a working gateway preview URL matters more than browser chrome. | P2 |
| F09 | Annotate a page or region and send comments plus visual context to Hermes | Gap | Useful for iterating on designs. Start with screenshot markup and a message; DOM-aware annotations are a later improvement. | P2 |
| F10 | Browser console, DevTools and preview-server diagnosis | Gap | Omit the full interface. A short failure summary and "Ask Hermes to fix" action fit mobile better. | P3 diagnostic summary only |
| F11 | Edit a source or text file in an embedded editor | Gap | Specialist. Occasional small corrections may help, but long code editing is poor phone work. Prioritize asking Hermes to make a selected change. | P3 |
| F12 | Copy absolute/relative paths; rename/delete files locally | Gap in primary interface | Specialist for copy; omit direct desktop filesystem management as a parity goal. Desktop itself hides local rename/delete controls in remote mode. | No broad parity work |
| F13 | Agent opens/navigates previews through the Desktop UI bridge | Gap for native Android preview targets | Useful only after mobile output viewing exists. Advertise the client's actual supported preview actions to Hermes. | P2 after F03 through F08 |

### 8. Coding review, Git, and terminals

Desktop's Git adapter routes to Electron locally and `/api/git/*` on remote gateways. The review pane here shows uncommitted changes, with file diffs, stage/unstage/revert, commit and push, generated commit messages, and PR creation/opening. Do not assume branch-versus-base or last-turn review merely because the lower-level adapter accepts a scope. Remote PR-comment fetching is explicitly unavailable in this adapter. [D-git] [D-review] [D-ship] [D-terminal]

| ID | Desktop feature | Android today | Mobile fit and justification | Recommendation |
| --- | --- | --- | --- | --- |
| G01 | See the repository, branch and changed-file summary | Partial project context; no full coding summary | Useful for coding users. Before approving a next step, users need to know which repository and branch it affects. | P2 |
| G02 | Inspect changed files and syntax-colored diffs | Gap in active native experience; older generic review event code is not equivalent | Useful. A file list and readable patch let someone assess small changes away from a desk. | P2 |
| G03 | Stage/unstage files or discard changes | Gap | Specialist. These are less common than reading a diff or asking for a correction. Small touch targets must not make destructive edits casual. | P3 |
| G04 | Write or generate a commit message, commit, commit-and-push | Gap as dedicated controls; Hermes can still be asked to do work | Specialist. A reviewed result followed by an explicit action is reasonable; a full Git client is unnecessary. | P2/P3 |
| G05 | Create/open a pull request and display its status | Gap | Useful for coding users. Open a PR link and report checks/status first; host `gh` and credentials are a backend dependency. | P2 |
| G06 | Ask Hermes to handle the commit/PR workflow | Command/chat can express the request; dedicated scoped action absent | Useful. Bind a shortcut to the correct task and repository, and show what happened. | P2 |
| G07 | Read live terminal output and agent command activity | Partial through tool activity | Useful. Showing a failing command or recent log lines helps the user decide what to ask next. | P1 readable activity; P2 log detail |
| G08 | Interactive terminal tabs, selection, paste, resizing and persistent sessions | Gap | Specialist. A small escape hatch may suit operators, but typing shell commands is not a core mobile productivity flow. | P3, optional |
| G09 | Open a conversation in an external terminal/window | Gap | Omit the desktop mechanism. A mobile deep link to the same conversation is the relevant counterpart. | No direct parity work |

### 9. Connections, profiles, and gateway administration

Desktop supports local, URL, SSH and Cloud connection paths, provider-independent gateway authentication, a saved registry, and profile/bot administration. Android's current setup targets modern profile-aware dashboard/gateway servers. API-only legacy onboarding is no longer the active path. A connection, a profile, a model-provider account, and a bot's canonical conversation are separate identities. [D-management] [A-entry] [A-gateway] [A-inventory]

| ID | Desktop feature | Android today | Mobile fit and justification | Recommendation |
| --- | --- | --- | --- | --- |
| B01 | Save, edit, remove, switch and reopen backend connections | Active | Essential. Preserve labels, last-used selection and separate credentials for each host. | Keep |
| B02 | Remote HTTP/HTTPS gateway with authentication discovery and connection test | Active modern dashboard/password/ticket path, narrower than all Desktop authentication modes | Essential. Test the connection the app will actually use and explain failures before saving. | Keep; P0 diagnostics |
| B03 | Gateway OAuth/browser authentication | Gap for full Desktop-equivalent OAuth onboarding | Essential for gateways that require it. Use a supported authorization flow; do not ask users to copy browser cookies. | P1 if required by target deployments |
| B04 | Extra gateway headers and advanced reverse-proxy access | Partial. Ports, prefixes and proxy mode exist; arbitrary header editor not found | Useful for self-hosted deployments. Keep uncommon fields under Advanced. | P2 |
| B05 | Native SSH tunnel connection, key selection and remote runtime path | Gap | Specialist. Existing LAN/private-network HTTPS access should work first. Add SSH only if the target audience needs it. | P3 |
| B06 | Discover SSH hosts from desktop OS configuration | Gap | Omit. Importing a connection or explicit mobile setup serves the purpose without copying desktop filesystem assumptions. | No parity work |
| B07 | Hermes Cloud sign-in, organization/agent discovery and selection | Gap as a guided Cloud flow | Essential for Cloud users, otherwise optional. Prioritize only if Cloud is in this app's intended audience. | P1 for Cloud scope; otherwise P3 |
| B08 | Secure client credential storage | Active platform secure storage | Essential. Preserve Android's existing mechanism; desktop keychain settings are not a UI requirement. | Keep |
| B09 | Install and launch a managed local Hermes runtime | Gap by design of the remote client | Omit. Running the desktop Python/backend installer on Android is a different product. | No parity work |
| B10 | Boot-failure recovery, reconnect and apply a repaired connection | Partial. Connection editing, retry and reconnect exist | Essential. A broken connection must be repairable without reaching the normal workspace. | P0 |
| B11 | Backend version/status, restart/update, per-connection managed updates | Gap in active native management | Useful status/recovery; specialist update-all. Show possible effects on running jobs before an operator action. | P1 version/health; P2 restart; P3 bulk update |
| B12 | Discover/select profiles with remembered client selection | Active | Essential. Keep current profile identity and background continuity. Do not change the server's default profile merely to browse another. | Keep |
| B13 | Create, clone, rename and delete profiles | Gap in dedicated active UI | Useful occasional administration. Selection is more important than full lifecycle parity. | P2 |
| B14 | Inspect profile details and edit SOUL/persona | Gap in active native editor | Useful. Correct persistent instructions directly rather than through a remote file tree. | P2 |
| B15 | Explicit profile selector for settings writes | Gap because broad management UI is absent; active chat controls are scoped | Essential for any restored settings. A clear target must precede every write. | Required with all administration |
| B16 | Bot roster with a canonical continuing chat per profile | Partial identity foundation through profiles; no Bot Mode/canonical-chat UI | Useful if this workflow is adopted. A contact-like specialist list fits a phone, but must preserve canonical chat identity rather than pick an arbitrary recent chat. | P2 product choice |
| B17 | Create/edit bot name, avatar, model, persona, capabilities and schedules; group roster sections/sources | Gap beyond profile/model selection | Useful for reusable specialists; detailed configuration is occasional. Existing profile controls should be extended before inventing a second identity system. | P2/P3 |
| B18 | Bot group chats, membership, room name, threads, attachments and disband | Gap | Specialist. Potentially productive, but requires real room semantics and backend support rather than rendering several chat cards together. | P3 |
| B19 | Group run state, held/running status and stop | Gap | Essential if group conversations are added. Every autonomous room run must be observable and stoppable. | With B18 |
| B20 | Global Agents view with delegation trees and tool/file/token/cost totals | Partial application-owned Activity; richer generic subagent code retained | Useful summary. Extend Activity with a compact worker detail view before copying Desktop's full tree. | P2 |

Bot Mode is a bundled Desktop plugin enabled by default in this snapshot. Android's profile picker is not automatically Bot Mode parity. A canonical long-lived bot chat and independent task chats need a deliberate product decision. [D-management]

### 10. Model providers, tools, skills, plugins, and memory

Desktop's Capabilities page unifies Skills, Toolsets, MCP and Plugins. It also exposes provider configuration, memory providers, learning controls and vault administration elsewhere. The current Android command picker already makes installed capabilities callable, but does not supply the corresponding management pages. [D-management] [A-inventory]

| ID | Desktop feature | Android today | Mobile fit and justification | Recommendation |
| --- | --- | --- | --- | --- |
| K01 | Connect/disconnect model-provider accounts with keys, browser/device authorization and provider guidance | Gap in active native provider setup | Useful. Reauthentication can unblock work; provider setup should remain distinct from gateway login. | P2, P1 for frequent auth failures |
| K02 | Inspect/search/change provider and service credentials | Gap in active management | Specialist but sometimes necessary. Use a focused secret entry flow scoped to the backend, not raw chat. | P2 |
| K03 | Custom compatible endpoints and provider definitions | Gap in active UI | Specialist. Relevant for self-hosted inference, not a default onboarding requirement. | P3 |
| K04 | Profile default model, reasoning and speed/service options | Retained older default-model setting; active per-chat choices are narrower | Useful. The user should know whether a change affects this chat or future work. | P2 |
| K05 | Auxiliary model assignments, fallback list and stale-provider warnings | Gap | Specialist. Expose failures and a simple reset-to-default before a large configuration form. | P2 warnings; P3 editor |
| K06 | Mixture-of-agents reference/aggregator configuration and presets | Gap in active editor | Specialist. Selecting a configured preset is sufficient for most phone use. | P3 |
| K07 | Max steps, retries, tool enforcement, subagent concurrency/timeouts and other run limits | No dedicated active editor; some commands may exist | Useful budget/limit summary; specialist full tuning. Start with pause/stop and clear limit failures. | P2 summary; P3 editing |
| K08 | Execution backend, persistent shell, environment, image, file/output and checkpoint limits | Gap in active native configuration | Specialist. A named execution preset and current status are more useful than every subprocess/container field. | P3 |
| K09 | Local inference runtime lifecycle, hardware fit, downloads, activation/ejection/deletion and model sideload | Gap; Desktop feature is `--local` gated | Omit desktop-local provisioning. Selecting a model hosted remotely remains relevant and is covered by Q14. | No direct parity work |
| K10 | Search installed skills and read full instructions/metadata | Command discovery and `/skills` active; older native list retained | Essential invocation/discovery; useful detailed inspection. Add a simple capability detail sheet. | P1 discovery; P2 full details |
| K11 | Enable/disable skills, bulk changes and disable-unused | Gap in dedicated active UI | Useful individual toggle; specialist bulk controls. Show whether changes affect the current or next conversation. | P2 |
| K12 | Skill usage counts and sorting | Gap in native UI | Useful for suggested favorites. A short "Frequently used" section is more valuable than analytics. | P2 |
| K13 | Official catalog/Skills Hub preview and install | Gap in dedicated active UI | Useful. Installing a needed capability may unblock a task from the phone. Keep source and required access visible. | P2 |
| K14 | Edit learned/local skill instructions and archive them | Gap in active editor | Specialist. Fixing a persistent instruction is useful; writing long skill documents is better done elsewhere. | P2/P3 |
| K15 | Inspect toolsets, tools, availability/prerequisites and usage | Gap in dedicated UI; slash catalog is narrower | Essential availability summary. Explain why Hermes cannot use a needed capability. | P1/P2 |
| K16 | Toolset enable/disable and credential/configuration setup | Gap | Useful focused setup. Route an unavailable capability to the fields needed to make it work. | P2 |
| K17 | Backend browser/computer-use/terminal setup and readiness | Gap in native settings | Useful readiness; specialist provisioning. This controls the remote environment, not permission to operate every Android app. | P2 status; P3 setup |
| K18 | MCP inventory, catalog install, import, JSON/config editing and deep-link install | Gap in dedicated UI | Useful catalog/import; specialist raw JSON. Start from a known server and a readable installation request. | P2 |
| K19 | MCP authenticate, probe, reload, enable/disable/remove; inspect tools/prompts/resources | Gap | Useful. Expired authorization and broken connectors can block otherwise routine mobile work. | P2 |
| K20 | Per-MCP-tool enable/disable | Gap | Specialist. Use it for a concrete access need, not as a large initial configuration screen. | P3 |
| K21 | Backend plugin catalog/Git installation, enable/disable/update and errors | Command dispatch supports plugin commands, not a native lifecycle manager | Useful for backend capability access. Implement status and focused repair before generic package administration. | P2/P3 |
| K22 | Desktop UI plugin loading, hot reload, routes, panes and composer extensions | Gap | Omit direct parity. Electron/React plugin UI cannot be assumed to run inside Flutter. Add Android extensions only for identified use cases. | No generic parity project |
| K23 | Read and correct individual memory/user-profile items | Retained read-only viewer; correction absent in active UI | Useful and high value. Correcting a durable mistake should not require locating a server file or learning graph node. | P2, ahead of memory-provider tuning |
| K24 | Memory enablement, budgets and provider selection/connect/configuration | Gap in active controls | Useful simple on/off/status; specialist provider configuration. Preserve understandable defaults. | P2/P3 |
| K25 | Context engine and automatic compaction threshold/target/protected history | Gap in active settings | Specialist. Visible compaction status and a manual action matter more than tuning every threshold. | P3 |
| K26 | Learning curator status, pause/resume/run-now; memory usage and reset | Gap | Useful. Users should be able to stop undesired automatic learning and inspect what changed. Individual corrections come before reset. | P2 |
| K27 | Starmap spatial learning graph, time axis, animation, sharing/import | Gap | Omit the full graph initially. Use a searchable memory/learned-skills list; graph export is a specialist extra. | P3 if demand exists |
| K28 | Approval policy, timeout/allowlists, redaction, private URL and checkpoint settings | Gap in dedicated native controls | Useful effective-policy summary; specialist editor. These govern remote agent actions and are different from Android permissions. | P2 summary; P3 advanced changes |
| K29 | Real desktop-browser profile consent and browser routing | Gap in active native settings | Specialist. A phone may authorize backend access, but copying Android browser cookies is not an implied parity requirement. | P3 |
| K30 | Vault sources/inventory, lock/unlock, login/payment/address records and OTP metadata | Gap in active management | Useful for users delegating authenticated web tasks. First handle a legitimate blocking request; full record administration can follow. | P2/P3 |

For memory, a plain list with View, Edit and Forget is the recommended mobile form. For skills and connectors, the useful questions are "What can Hermes do?", "Is it ready?", and "How do I use or repair it?" A long raw configuration page is not necessary to answer them.

### 11. Scheduled work, messaging, and external events

Desktop has three separate families here: scheduled Cron work, messaging-channel integration, and externally triggered webhooks. Session goals/heartbeats/loops are covered in R12 through R14. The optional Kanban plugin adds another task model; it is disabled by default. [D-management] [A-inventory]

| ID | Desktop feature | Android today | Mobile fit and justification | Recommendation |
| --- | --- | --- | --- | --- |
| U01 | List/search Cron jobs with state and profile | Retained basic job/status list; no search or profile-scoped browser | Useful and high priority for people using scheduled Hermes work. Make it reachable with correct ownership. | P2, early in automation work |
| U02 | Create/edit job name, prompt, schedule and custom cron | Retained basic form | Useful. Start with plain time/repeat controls and show the next occurrence; raw cron belongs under Advanced. | P2 |
| U03 | Per-job model and multiple result delivery destinations | Gap beyond narrower retained form | Useful. A recurring task needs a predictable cost/quality choice and a destination the user can access. | P2 |
| U04 | Parameterized automation blueprints | Gap | Useful for common recurring work. Templates reduce typing and prevent incomplete setup. | P2/P3 |
| U05 | Run now, pause/resume and delete a job | Retained older implementation | Useful. Pausing unwanted work and rerunning a failed job are good phone actions. | P2, before advanced authoring |
| U06 | Inspect recent runs and open their conversations/results | Gap in complete active workflow | Essential if automation is part of the mobile client. A schedule with no usable result/history view is incomplete. | P2 with U01 |
| U07 | Preserve and manage script-only scheduled jobs | Retained form has script-only concept | Specialist. Editing an existing script job must not force it into a model-prompt schema. | With Cron integration |
| U08 | Messaging platform inventory with connected/failed/disabled state | Gap in active settings | Useful. Explains why a scheduled message or handoff did not arrive. | P2 |
| U09 | Enable/disable channels, edit tokens/settings, restart-required state and restart | Gap | Specialist. Useful for an owner recovering a broken or noisy channel. Keep advanced setup secondary. | P2/P3 |
| U10 | Approve pending platform pairing requests and revoke approved users | Gap | Useful and time-sensitive for shared gateways. Show both platform and requesting identity before the action. | P2; P1 for shared-gateway audience |
| U11 | Telegram QR onboarding | Gap | Specialist. Same-phone setup needs an open-link alternative to scanning the phone's own display. | P3 |
| U12 | Webhook service status, enable and restart handling | Gap | Specialist. A short health view is enough for occasional repair. | P3 |
| U13 | List/search webhook subscriptions; enable/disable/delete | Gap | Specialist. An emergency disable or failure summary is more useful than a full setup wizard. | P3 |
| U14 | Create webhook event filters, prompts, skill lists, delivery-only mode and targets | Gap | Specialist. External-system configuration often dominates the workflow. An external dashboard is an acceptable first step. | P3 |
| U15 | Copy generated webhook URL and one-time secret | Gap | Useful if webhook setup is exposed. Keep one-time secret handling distinct from ordinary chat output. | With U14 |
| U16 | Kanban boards, lanes, search/filter, task creation and movement | Gap; Desktop bundled plugin is off by default | Specialist product extension. A mobile task list may fit better than a horizontal board. Adopt only if this is how you plan to organize work. | P3 |
| U17 | Kanban task priority/assignee/workspace/skills/model/parent and goal settings | Gap | Specialist. Capture task, destination and assignee first; most fields belong in details. | With U16 |
| U18 | Kanban results, dependencies, comments, attachments, activity, runs and logs | Gap | Useful if Kanban is adopted. Reviewing a result and leaving feedback is better phone work than configuring orchestration. | With U16 |
| U19 | Kanban feedback/requeue, diagnostic actions, archive/delete and orchestration defaults | Gap | Specialist. Expose correction/requeue before default orchestrator and auto-decomposition settings. | Later Kanban phase |

### 12. Usage, diagnostics, appearance, and desktop conveniences

Desktop also has substantial account, maintenance and personalization UI. Some controls are optional or local to the desktop process. Android retains several device-preference and backup implementations without a route to their controls. Billing should be distinguished from provider-wide spend, and app updates from backend updates. [D-management] [D-routes] [D-layout] [D-windows] [A-entry] [A-inventory]

| ID | Desktop feature | Android today | Mobile fit and justification | Recommendation |
| --- | --- | --- | --- | --- |
| S01 | Command Center health and searchable agent/gateway/desktop error logs | Gap in active native diagnostics | Useful. Lead with the cause and next action; keep raw logs behind details. | P1 connection summary; P2 log details |
| S02 | Usage analytics over 7/30/90-day windows | Gap in dedicated UI | Useful for cost awareness; a simple recent usage summary is enough initially. | P2 |
| S03 | Doctor, security audit, backend backup and debug-share actions | Gap | Specialist owner tools. A focused diagnostic bundle can be valuable; sharing it must be an explicit action. | P2/P3 |
| S04 | Live account plan/balance/cap/credits and connector/model summary | Gap | Useful, essential for users whose Hermes service stops on exhausted credit. Do not present this as a complete bill for every external provider. | P1 failure reason; P2 account summary |
| S05 | Free-tier notice and account sign-in | Gap as guided account flow | Useful for supported service accounts. Hide irrelevant billing UI for deployments without it. | With Cloud/account support |
| S06 | Credit top-up, step-up auth, charge confirmation/status and automatic reload | Gap | Specialist account management. External secure account pages are acceptable; a mobile task should not silently change a spending policy. | P2 external flow; P3 native controls |
| S07 | Plan catalog/upgrade portal, preview/schedule downgrade, undo pending downgrade/cancellation; payment portal | Gap | Specialist. Occasional account work need not occupy primary navigation. | P2/P3 external portal |
| S08 | App version, release notes, update checking/download/install/restart | Gap for a comparable active in-app updater | Useful mobile equivalent. Use Android's distribution channel; keep gateway compatibility/version visible separately. | P2 |
| S09 | Configuration search, import/export/reset | Partial. Active app configuration restore; old export/settings retained; no full backend config editor | Useful. Name whether the operation changes phone preferences, saved connections or remote profile configuration. | P1 reachable preferences; P2 export/search |
| S10 | Light/dark/system theme, readable scale and density | Partial. Runtime theme/scaling exists; controls are retained in old Settings | Essential accessibility. Restore the controls without weakening system text scaling and touch targets. | P1 |
| S11 | Language selection and localized interface | Gap for Desktop-equivalent selector/localization | Useful according to intended users. Avoid making essential states and errors English-only if broader distribution is planned. | P2 |
| S12 | Notification categories, completion sounds, preview and test | Partial. Permission/tap handling exists; detailed settings absent | Essential interruption control. A test should verify the device's notification path, not imply guaranteed future background delivery. | P1 |
| S13 | Voice provider/model/voice/language, auto-speak and transcription settings | Retained earlier voice preference work, no active route | Useful once voice returns. Most users need voice/language and auto-speak; backend transcription tuning can be advanced. | P1 basics; P2 advanced |
| S14 | Resume-last-session, transcript/tool disclosure, reasoning and embed preferences | Partial remembered connection/view behavior; not the full settings suite | Useful. Resume exact work and offer readable defaults before adding many appearance switches. | P1/P2 |
| S15 | Searchable command palette and editable/resettable keybindings | Slash picker only; no full command palette | Useful touch command picker; specialist physical-keyboard customization. Do not make keyboard shortcuts the only route to a feature. | P2 picker; P3 keybindings |
| S16 | Multiple chat/page/preview tabs, split panes, drag/stack/reorder and layout restoration | Gap | Omit the full desktop layout engine. A two-column tablet view may help; phones should use clear task switching and full-screen details. | P2 tablet only |
| S17 | Separate chat/browser windows, composer popout and floating HUD | Gap | Omit desktop window parity. Use Android task links, shortcuts and appropriate multiwindow support. | No direct parity work |
| S18 | Tray/window controls, quit guard, keep-awake, F12/DevTools controls | Gap | Omit exact controls. The mobile equivalents are honest background state and preventing accidental loss of an unsent draft. | No direct parity work |
| S19 | Theme marketplace, custom backgrounds, translucency, terminal font, tint/frost and bubble effects | Partial accent only | Omit most initially. Readability, contrast and battery use matter more than reproducing desktop decoration. | P3 optional themes |
| S20 | Tips/tours, introductory splash, reactions/hearts | Gap beyond simple initial empty states | Useful short onboarding; omit decorative effects from the productive-client backlog. | P2 contextual tips; P3 decoration |
| S21 | Pet gallery/adopt/rename/export/remove, generated pets and overlay | Gap | Omit for this goal. It adds personality but does not improve task capture, supervision or result use. | No priority |
| S22 | Radio presets/search/playback/volume/pins and now-playing links | Gap; Desktop plugin disabled by default | Omit. Existing Android music apps already serve this purpose. | No priority |
| S23 | Desktop uninstall and selectable local cleanup | Android OS uninstall/storage controls | Omit desktop-specific cleanup UI. Remote backend deletion is a separate operation and should not follow uninstalling a client. | No parity work |

Not counted as a present Desktop feature: a functional invoice browser. Its feature flag is explicitly false. Billing fixtures are developer-only, while normal billing uses live gateway RPC subject to account flags. Likewise, local-model management requires `--local`, reactions are opt-in, and Kanban/Radio are not enabled by default. These qualifiers matter when using the inventory as a backlog. [D-management] [D-chat]

## What makes the mobile feature list different

These are recommended Android features, not claims that Desktop already implements their mobile equivalents. They address conditions that a desktop window does not have to solve in the same way.

| ID | Proposed mobile feature | Current starting point | Why it belongs in the product | Priority |
| --- | --- | --- | --- | --- |
| M01 | Reliable completion and attention delivery while the phone is locked or the app process is gone | Local notifications and owner-aware tap routing exist; no verified push delivery after process death | A user should be able to delegate work and put the phone away. Choose and document an Android-compatible delivery design, including its private-network constraints. | P0 |
| M02 | A durable Needs you / Running / Completed inbox | Activity currently covers application-owned chats; older Home digest is retained | A returning user needs to know what requires a decision without visiting every profile and conversation. Include work started by other clients when the server can report it. | P0 |
| M03 | Persistent unsent drafts and staged attachments | Draft and view state are mainly in memory; attachment caching exists | Interruptions are normal phone behavior. A call, app switch or process restart must not discard a carefully composed request. | P0 |
| M04 | Truthful offline and uncertain-send states | Reconnect and conservative no-resend behavior exist | Distinguish "saved on phone", "sending", "accepted by Hermes", and "outcome unknown". An offline outbox should wait for an explicit supported deduplication contract before promising automatic retries. | P0 |
| M05 | Native share-out for answers and artifacts | Copy is active; older answer export/share exists | The productivity result often belongs in email, notes, a document app or a messaging app. Use the Android share sheet with usable text or files. | P1 |
| M06 | Camera, screenshot and share-sheet intake with target review | File/share intake exists; camera UI does not | Capture something where it happens, choose the host/profile/project, and review before sending. Do not turn an incoming share into an invisible submission. | P1 |
| M07 | Dictate, review, edit and send; optional read-aloud | Older voice services exist | Typing is often the most expensive mobile interaction. Start with a trustworthy dictation workflow before continuous voice. | P1 |
| M08 | Task links and lightweight handoff between devices | Notification routing uses full ownership; copy-ID exists | Open the exact host/profile/chat from a link and keep server history consistent. Do not imply that local answer-version grouping or drafts already sync. | P1/P2 |
| M09 | Notification preferences and private previews | Local notification permission and tap handling exist | Let users choose attention/completion categories, quiet hours and whether lock-screen text reveals the task title. Inline reply can follow; inspect approval context inside the app. | P1 |
| M10 | Read selected recent conversations and downloaded results offline | No active durable offline transcript library | Useful during commutes and poor connectivity. Separate cached information from current server state and offer explicit refresh. | P2 |
| M11 | A compact saved-actions or favorite-skills picker | Dynamic slash suggestions exist | Repeating a useful task should not require memorizing syntax or retyping a long prompt. A saved action should show its inputs and destination. | P2 |
| M12 | Accessible phone and tablet layouts | Responsive helpers, selection and system text scaling exist; some settings are unreachable | Preserve large text, screen-reader labels, comfortable tap targets, keyboard visibility and reading position. Tablets can add a two-column layout after the phone workflow works. | P1 baseline; P2 tablet |
| M13 | A home-screen quick action or widget | Launcher New chat shortcut exists; no widget found | Useful for capture or a small attention count. Do this after the underlying inbox and notification states are dependable. | P3 |

The file decision deserves a firm boundary. Build "Outputs for this conversation", preview, download, share, and "Use this as input" before a general remote file browser. Add a project-scoped file picker only when users need reference material that is already on the host. That preserves the useful file workflows without making the phone an alternative remote desktop.

For gateway settings, split everyday recovery from machine administration. The phone should say which host/profile it is using, whether it is connected, why authentication failed, and what must happen next. Changing providers, pairing an integration, pausing a runaway schedule, or correcting memory can be useful on mobile. Installing runtimes, choosing Python interpreters, configuring every subprocess, and managing local desktop windows are not requirements for an excellent remote client.

## Suggested mobile navigation

Keep the current conversation view as the main working screen. A compact top-level structure can be:

| Destination | Purpose | Important content |
| --- | --- | --- |
| Chats | Find and continue work | Search, recents, pins, archives, project filter, new chat |
| Activity | Act on work that needs attention | Pending questions and approvals, running work, unread completions, failures |
| More | Occasional controls | Automations, capabilities, memory, connections, device settings, dashboard link |

Projects can remain a scope within Chats rather than requiring another permanent tab. Put Outputs and task details inside each conversation. Keep connection/profile selection available in the browser, with compact owner context in chat and on every attention item. An All profiles attention view should not silently change the profile used for new messages.

This is a proposed direction. It does not require reviving the former Home/Projects/Activity/More shell unchanged. Existing widgets can be reused where their behavior fits the current ownership model.

## Recommended sequence and acceptance criteria

The order below favors completed mobile workflows over the number of screens added. Keep existing profile, search, conversation organization, answer version and model-selection behavior throughout.

| Order | Work package | Concrete acceptance criteria | Main dependencies |
| --- | --- | --- | --- |
| 1 | Complete attention handling and lifecycle truthfulness | Start work in profile A, move to B, lock the phone, interrupt connectivity, kill and reopen the process. Every pending item resolves to its original owner. Uncertain prompts are never silently sent twice. Approval, clarification and supported secret requests have correct pending/resolved/expired states. Completed work is findable even if its notification was missed. | Server pending-work discovery, resume/history contract, Android delivery design; R and M feature families below |
| 2 | Preserve mobile input and make voice/capture usable | A long unsent draft and its staged files survive restart. Dictated text can be corrected before send. Camera/gallery/share intake previews the chosen destination. Upload failures preserve the draft and identify the failed item. A changed host or profile never receives stale attachments. | Profile-owned draft persistence, existing attachment and voice services |
| 3 | Finish the output workflow | Hermes generates an image, PDF and text file on a remote host. Each appears in that chat's Outputs, opens on the phone, downloads and shares as a real file, and returns to the same conversation. Expired authentication or unavailable artifacts produce an actionable error. | Authenticated artifact list/read/download contract; Android content URIs and viewers |
| 4 | Make active work easy to find and steer | Search finds an older archived chat and opens the relevant content. Needs input, Running and Unread work have obvious views. The user can send a steering correction while work runs and distinguish it from a queued next request. | Authoritative search/pagination, work-state APIs, scoped steer/queue semantics |
| 5 | Restore selected everyday controls | Theme/text size and notification preferences are reachable. A user can inspect a skill, invoke it, correct a memory item, inspect a scheduled run, pause/resume it and open its result. Each action stays scoped to the selected host/profile. | Reuse retained UI only after adapting its clients and caches to profile ownership |
| 6 | Add specialist supervision where usage justifies it | A coding user can identify branch/worktree, read a change summary/diff and open a PR. An operator can inspect health and a failed integration. Rare administration can open the dashboard. | Remote Git/status APIs, capability/auth contracts, tested dashboard URLs |

Acceptance for notification delivery must state the tested conditions. Ordinary backgrounding, OS process reclamation, explicit force-stop, battery restrictions and an unreachable private gateway are distinct cases. No delivery mechanism should be described as unconditional. The product must make undelivered work visible when the user returns.

Three implementation boundaries will prevent the feature list from becoming a regression list:

1. Scope every read, mutation, draft, attachment, notification and cached result by its actual connection and canonical profile. Moving between screens must not change ownership.
2. Treat retained screens as reusable implementations. Reconnecting a route without checking its transport and state ownership can bring back unscoped or legacy behavior. The current profile architecture should remain the authority.
3. Separate app support from server support. A button should either work through a verified contract or explain the missing capability. A generic slash-command dispatcher is not proof that every administrative function is supported.

I would defer the general filesystem tree, terminal emulator, full Git administration, local model downloads, runtime installer, detailed webhook editor, arbitrary desktop plugin pages, pane-layout controls, pets and decorative visualizations. They can all be legitimate desktop features. None should displace reliable attention, capture, search, voice, and usable outputs in the Android roadmap.

## Source register

Desktop links are pinned to the inspected commit. Android links point to the current local implementation; the snapshot SHA above makes the baseline explicit. The supporting inventories give more precise locations and limitations.

[D-root]: https://github.com/NousResearch/hermes-agent/tree/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop
[D-routes]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/routes.ts
[D-layout]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/chat/preview-tile.tsx
[D-windows]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/store/windows.ts
[D-session-menu]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/chat/sidebar/session-actions-menu.tsx
[D-filters]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/chat/sidebar/filter-menu.tsx
[D-export]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/lib/session-export.ts
[D-import]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/session-import/index.tsx
[D-projects]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/store/projects.ts
[D-project-dialog]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/chat/sidebar/project-dialog.tsx
[D-project-menu]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/chat/sidebar/projects/project-menu.tsx
[D-worktree]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/chat/sidebar/projects/worktree-dialog.tsx
[D-lanes]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/chat/sidebar/projects/workspace-group.tsx
[D-artifacts]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/artifacts/index.tsx
[D-preview-file]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/chat/right-rail/preview-file.tsx
[D-browser-bar]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/chat/right-rail/preview-browser-bar.tsx
[D-fs]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/lib/desktop-fs.ts
[D-file-actions]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/right-sidebar/file-actions.tsx
[D-git]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/lib/desktop-git.ts
[D-review]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/store/review.ts
[D-ship]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/right-sidebar/review/ship-bar.tsx
[D-terminal]: https://github.com/NousResearch/hermes-agent/tree/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/right-sidebar/terminal
[D-management]: research/HERMES_DESKTOP_MANAGEMENT_INVENTORY_2026-09-11.md
[D-chat]: research/HERMES_DESKTOP_CHAT_INVENTORY_2026-09-11.md
[A-entry]: ../lib/main.dart
[A-workspace]: ../lib/core/screens/profile_workspace_screen.dart
[A-browser]: ../lib/core/screens/profile_workspace_browser.dart
[A-rows]: ../lib/core/screens/profile_row_actions.dart
[A-controller]: ../lib/core/services/profile_workspace_controller.dart
[A-gateway]: ../lib/core/services/profile_gateway.dart
[A-inventory]: research/HERMES_ANDROID_FEATURE_INVENTORY_2026-09-11.md
