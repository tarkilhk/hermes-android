# Hermes Desktop chat and supervision inventory

Audit date: 2026-09-11. Source: NousResearch/hermes-agent, commit `d15ed4445207dda418b984e8bda0f68f48b8c6f3`.

This is a source audit of the current Desktop implementation, not a claim that every control is available in every released build or against every gateway version. Entries below trace rendered UI or live dispatch. This scoped inventory covers conversations, composer, model selection, transcript, supervision, voice and notifications. It does not inventory global management pages, projects, file browser, terminal, review, bot administration or general appearance settings. The Android comparison belongs in the parent report.

Mobile verdicts are product judgments: **Essential** supports everyday capture, execution or supervision; **Useful** helps a recurring subset of tasks; **Defer** has limited return for the first productive client; **Desktop form only** means adapt the purpose to Android rather than copy the control.

## Conversation management

| ID | Current Desktop capability and qualification | Mobile verdict and justification | Source |
|---|---|---|---|
| C01 | Create a new chat; resume existing history; choose sessions from a persistent sidebar. | Essential. Starting work and returning to it are the core client loop. | [S1], [S11] |
| C02 | Search titles, IDs and source metadata locally, then merge server full-text matches across all sessions, including sessions outside the loaded page. | Essential. A phone needs retrieval more than a long desktop sidebar. Do not label a loaded-list filter full search. | [S1] |
| C03 | Find within the current view, with match count and previous/next navigation. Scope stays bound to the view where search began. | Essential for long conversations. Search should eventually reach unloaded transcript history; Desktop find-in-view alone is not evidence of that. | [S5] |
| C04 | Rename sessions. Active runtime-only sessions can use session.title before a stored record exists. | Essential. Short recognizable task names make phone lists usable. | [S2] |
| C05 | Pin/unpin sessions. | Essential for frequently resumed work. | [S2] |
| C06 | Persisted mark read/unread plus a transient finished-unread marker; opening/acknowledging retires the corresponding indicators. | Essential. A phone is often used to triage work completed elsewhere. | [S2] |
| C07 | Archive and delete sessions; archived sessions have their own fetched view. Delete has a confirmation dialog. | Essential. Archive should be the convenient routine cleanup action. | [S1], [S2] |
| C08 | Group sessions by recency or run status, nested conversation branches, profiles and messaging sources. | Useful. Preserve status/profile/source cues; avoid recreating every tree depth. | [S1], [S3] |
| C09 | Manually reorder flat sessions within date groups. | Defer. Pinning, recency and search provide most of the value without touch drag complexity. | [S3] |
| C10 | Per-session color overrides with inherited project color. | Defer. Distinguishable project/profile badges matter more than individual color customization. | [S2] |
| C11 | Branch from a session or assistant reply into a new chat. | Useful. Explore an alternative without losing the original thread. | [S2], [S7] |
| C12 | Edit previous user messages even while streaming; submitting the edit interrupts and rewinds before resubmission. | Essential. Corrections are common with mobile typing and dictation. Explain that later conversation context changes. | [S6], [S8] |
| C13 | Restore earlier conversation checkpoints and go forward through alternate user-turn history. | Useful. Valuable recovery, but distinguish transcript restoration from filesystem rollback. The reviewed primitive truncates prompt history. | [S6], [S8] |
| C14 | Regenerate an assistant response; failed turns expose contextual retry and recovery actions. | Essential. Network and provider failures must be recoverable without copying the whole prompt. | [S7], [S8] |
| C15 | Export the complete paginated transcript as a JSON download with metadata. /save also dispatches session.save. | Useful. Android should add readable text/Markdown sharing as a mobile adaptation; do not claim Desktop's export is PDF or Markdown. | [S4], [S11] |
| C16 | Hand off the current conversation to a configured messaging platform using /handoff. | Useful for users who alternate Hermes clients. Lower priority than seamless reopening of the same server conversation. | [S12] |
| C17 | Open chat in another tab, window or local external terminal. Terminal action is hidden for remote connections. | Desktop form only. Android needs deep links, task switching and possibly tablet split view, not Electron window parity. | [S2] |

## Prompt capture and context

| ID | Current Desktop capability and qualification | Mobile verdict and justification | Source |
|---|---|---|---|
| P01 | Multiline rich composer with structured reference chips and per-session saved text/attachment drafts. | Essential. Drafts must survive navigation, app suspension and reconnects. | [S13] |
| P02 | Attach files and images through pickers; paste clipboard images. | Essential. Android equivalents are system document/photo pickers, camera capture and share intents. | [S9] |
| P03 | Attach folders and complete backend file/folder paths. | Useful only in simplified form. A selected remote path is useful context even when a general remote file manager is not. | [S9], [S10] |
| P04 | Add a URL through an attachment dialog or typed URL reference. | Essential. Sharing a web page into Hermes is a primary phone productivity flow. | [S9], [S10] |
| P05 | @ completions for file, folder, URL, image, tool, git, diff and staged context; extensions can contribute completion sources. | Useful. Start with files, links and session context. Hide coding-specific references unless relevant to the current workspace. | [S10] |
| P06 | / command discovery and execution with curated Desktop built-ins, installed skill commands and user quick commands; skills ranked by usage. Never-used bundled skills are pruned only for bare-menu browsing, not explicit search. | Essential as an accessible command/skill picker. Typing slashes should be optional on a touch keyboard. | [S11] |
| P07 | Prompt snippet dialog with code review, implementation plan and explain-this templates. | Useful. Reusable user snippets would have broader mobile value than copying these three development templates. | [S9] |
| P08 | Plugins can add composer attachment actions. | Defer extensibility; implement concrete mobile capture actions first. A plugin entry is not proof that any specific third-party integration is installed. | [S9] |
| P09 | Send a steering message while the agent is busy; empty composer offers Stop. | Essential. Remote supervision requires course correction without losing a running job. | [S15] |
| P10 | Queue follow-up prompts, display their text and attachment count, edit or delete entries. | Essential for mobile productivity. Capture the next instruction immediately without waiting for the current turn. | [S14] |
| P11 | Promote a queued message to send now/send next, or steer the current run; resume a parked queue. | Useful. Controls need unambiguous labels so the user knows whether execution changes now or after completion. | [S14] |
| P12 | /btw asks a side question using a snapshot of the current conversation without interrupting it; prompt.btw returns a task ID and the answer arrives later. | Useful and unusually well suited to phones: ask what a run means without derailing it. | [S12] |
| P13 | /compress, also /compact, manually compacts conversation context with an optional focus topic and handles long-running background compression. | Useful. Put it in conversation actions with an explanation, rather than a permanently visible control. | [S12] |
| P14 | /help, /status and other curated commands surface session capabilities; catalog-backed extensions dispatch through slash.exec/command.dispatch. | Useful. Preserve capability-aware discovery so unsupported commands do not look broken. | [S11], [S12] |

## Model and context control

| ID | Current Desktop capability and qualification | Mobile verdict and justification | Source |
|---|---|---|---|
| M01 | Switch the current session's model/provider using a searchable, provider-grouped catalog from the owning gateway. | Essential. Users need a quick cost/speed/quality choice on the same backend. | [S16], [S17] |
| M02 | Per-model reasoning/thinking effort and fast mode, constrained by model capabilities; settings are remembered as model presets. | Useful. Offer a compact set of understandable choices and accurate cost implications. | [S16], [S17] |
| M03 | Curated visible-model shortlist, collapsed provider groups and refresh catalog action. | Useful. A short favorites list is better than requiring phone users to scan every provider. | [S16], [S17] |
| M04 | Composer model choice is sticky for future chats; a draft displays a manual-override marker distinct from the configured default. | Essential behavioral clarity. Prevent an expensive forgotten override from silently controlling future mobile chats. | [S18] |
| M05 | Select configured mixture-of-agents presets from the catalog when the backend exposes the virtual moa provider. | Useful for specialist workflows. This is selecting an existing preset, not evidence of mobile-relevant orchestration editing. | [S17] |
| M06 | Managed local-model loading/catalog controls are explicitly gated behind the Desktop --local launch flag. | Desktop form only. Selecting a model served by the remote host is relevant; downloading/managing a desktop-local runtime is not phone-client parity. | [S17] |
| M07 | Context usage gauge with used/max tokens, percentage, estimate marker and category breakdown. | Useful. A small warning and details sheet help explain slow or compacted sessions without a dense status bar. | [S19] |

## Approvals and human input

| ID | Current Desktop capability and qualification | Mobile verdict and justification | Source |
|---|---|---|---|
| H01 | Inline command approval offers run once, reject, and, where allowed by the request, session-wide or permanent permission; permanent allowance has a confirmation dialog. A fallback appears if the tool row has not mounted. | Essential. A productive mobile client must unblock work safely and retain request context through reconnects. | [S20] |
| H02 | Approval policy selector offers manual, smart and off, scoped per profile. | Useful in settings. Show the effective policy while approving; do not confuse a profile change with an action-specific decision. | [S21] |
| H03 | /yolo toggles a separate per-session auto-approval override. | Defer as a prominent affordance. If supported, make scope and effective permission state explicit. | [S12] |
| H04 | Structured clarification supports single questions, batched questions, choices, multiple selection and free text; historical results render back into the transcript. | Essential. A running agent that asks a question must be answerable from the phone. | [S22] |
| H05 | Separate masked sudo/password and environment-secret response dialogs. | Useful when the remote agent needs credentials. Keep these out of ordinary model-visible chat messages. | [S23] |
| H06 | Vault unlock, save-login and one-time verification-code prompts use dedicated response routes. | Useful. The phone is frequently where the user's authenticator or password manager lives. Availability depends on backend vault functionality. | [S23] |
| H07 | Actionable error recovery offers retry, new session, provider reauthentication/switching, and diagnostic copy/log/report actions according to error classification. | Essential at a smaller scale. The phone needs a clear reason and next action, with diagnostics behind details. | [S7] |

## Running work and supervision

| ID | Current Desktop capability and qualification | Mobile verdict and justification | Source |
|---|---|---|---|
| R01 | Composer status stack groups todo progress, goals, subagents, background processes and queued prompts. | Essential. A compact run summary should answer what is happening and whether the user needs to act. | [S24] |
| R02 | Todo list shows completed count and in-progress state. | Essential for following substantial work without rereading the entire transcript. | [S24] |
| R03 | Background process status can be inspected, stopped or dismissed; foreground-visible polling catches silent process exits. | Useful. Stop a runaway job from the phone; do not require a terminal UI. | [S24] |
| R04 | Live subagent roster displays task, latest activity, run/queue status and elapsed duration. | Useful for parallel tasks. Collapse details by default on small screens. | [S25] |
| R05 | Open an individual subagent's progress/details and paged transcript. | Useful for diagnosis when the parent summary is insufficient. | [S25], [S44] |
| R06 | Steer an individual subagent or interrupt it, routed to its owning session/backend. | Useful. Targeted correction is better than stopping the entire task. | [S26] |
| R07 | Goal card shows objective, status, criteria and progress; actions pause, resume, resume-now from a wait or clear the goal. | Essential for a client used to supervise long work. The view appears when session.control is supported and a goal exists. | [S27], [S28] |
| R08 | Add, remove, clear or copy goal criteria from the UI. | Useful. Small requirement changes are common while away from the desk. | [S27] |
| R09 | Goal details expose expected outcome, verification, constraints, boundaries, stop conditions, wait barrier, and quality-gate command/attempt/timeout/exit information. | Useful in a details sheet. Most users need the plain objective and blocked reason first. | [S27] |
| R10 | Heartbeat card displays prompt/cadence/fire count and allows pause, resume and clear. | Useful. Monitor recurring follow-ups and stop unwanted activity remotely. | [S28], [S29] |
| R11 | Loop card displays recurring prompt/run state and allows pause, resume and stop; backend supports interval/self-paced and run-limit metadata. | Useful for users who rely on loops. Do not merge loops, heartbeats and goals into a generic running spinner. | [S28], [S30] |
| R12 | Session-control requests detect unsupported backends and suppress repeated capability probes. | Essential implementation requirement for mobile parity. Controls must reflect server support, not just app version. | [S28] |

## Transcript and results

| ID | Current Desktop capability and qualification | Mobile verdict and justification | Source |
|---|---|---|---|
| T01 | Streaming assistant prose, tool activity and collapsible reasoning with elapsed-time indicators. | Essential. Distinguish waiting, reasoning, tool execution and completed output. | [S7], [S34], [S35] |
| T02 | Markdown, highlighted code, mathematical notation, tables and expandable large blocks. | Essential for reading useful results. Tables/code need horizontal pan or expanded viewing. | [S31] |
| T03 | Mermaid diagrams, sanitized SVG and listing fences render through dedicated lazy renderers with code fallback. | Useful. Diagrams often communicate better than text on a phone; retain a readable fallback. | [S32] |
| T04 | Inline images with zoom, generated image results, audio and video playback. | Essential. The mobile client should display the deliverable rather than just expose a remote path. | [S31], [S34] |
| T05 | Linked artifacts/file previews and session-reference links are recognized in Markdown. | Essential for files the agent produced; useful for jumping to referenced tasks. Viewing/downloading a result is distinct from implementing a general file browser. | [S31] |
| T06 | Rich URL embeds include configured handlers for video, music, social content and maps. | Useful selectively. Link previews plus open-in-app/browser deliver most of the benefit; embedding every provider is a later concern. | [S33] |
| T07 | Tool rows expose structured details, copy payload, terminal ANSI output, search hits, file diffs and previewable targets; tool detail disclosure is configurable. | Essential summary, useful deep details. Keep raw logs/diffs available without filling the default transcript. | [S35] |
| T08 | Assistant final response actions include copy, regenerate, branch and read aloud; completion metadata includes duration. | Essential copy/retry; useful branch/read-aloud. Use a touch action menu rather than hover-only controls. | [S7] |
| T09 | Message reactions, searchable emoji/tapback picker and double-click heart behavior, with user and agent reactions persisted. Explicitly opt-in and off by default; existing reactions remain visible when disabled. | Defer for productivity. A useful lightweight acknowledgement feature, but lower value than approvals and notifications. | [S36], [S37] |
| T10 | Older transcript loading, scroll position and jump-to-latest behavior support large conversations without rendering the whole session at once. | Essential. Mobile memory limits and intermittent connectivity make efficient history loading important. | [S45] |
| T11 | System/control messages and inter-agent delivery notices have distinct transcript treatments. | Useful. User instructions, tool events and automatic work should remain distinguishable. | [S34] |

## Voice and fast entry

| ID | Current Desktop capability and qualification | Mobile verdict and justification | Source |
|---|---|---|---|
| V01 | Dictate into the editable draft using client microphone capture and configured transcription. | Essential. This is often faster than composing long instructions on a phone. Retain review-before-send for dictation. | [S38] |
| V02 | Voice conversation loops through listening, transcription, thinking and speech with voice activity detection. | Useful, potentially a major mobile differentiator after reliable text/capture/supervision. | [S39] |
| V03 | Barge in during generation or speech, interrupt and submit the captured utterance; recognized voice stop commands end the interaction. | Useful once conversation mode exists. Otherwise users must wait through long spoken replies. | [S39] |
| V04 | Mute/unmute microphone, stop the listening turn, end conversation, and visible speaking/listening activity. | Essential whenever voice is enabled. The active microphone must be obvious. | [S15] |
| V05 | Auto-speak typed-chat replies independently of voice conversation mode; read individual assistant replies aloud and stop playback. | Useful for hands-busy use and accessibility. | [S15], [S7] |
| V06 | Wake-word toggle and /wake on/off/status, gateway-owned microphone lease, local or client-side remote capture, failure hints, and pause/rearm around voice conversation. | Defer on mobile. Explicit quick entry offers most of the benefit without always-listening battery/privacy burden. It is not simply a Desktop-only local-mic feature. | [S40], [S12] |
| V07 | Native quick-entry window with configurable global shortcut, targets current/new/recent session, draft retention and disconnected-state checks. Uses the main renderer's normal submit route. | Desktop form only, essential purpose. Android equivalents are launcher shortcuts, widget, share target and Quick Settings tile. | [S41] |

## Notifications and attention

| ID | Current Desktop capability and qualification | Mobile verdict and justification | Source |
|---|---|---|---|
| N01 | Native OS notifications for approval, input request, turn done, turn error, background work done, credits and plugin events; per-kind toggles. | Essential. Phone productivity depends on returning only when work finishes or needs input. | [S42] |
| N02 | Attention events can notify for another session while the app is focused; completion events are restricted to the active session while away. Dedupe and reconnect-baseline suppression avoid replays. | Adapt. Mobile should let users follow explicit tasks across suspension; copying Desktop's active-session-only completion rule may miss desired alerts. | [S42] |
| N03 | Notification routing can open the relevant session or plugin target and carry action buttons. | Essential deep links; useful carefully scoped approve/reject or reply actions after identity checks. | [S42] |
| N04 | Separate in-app notification/toast feed with success/error/other notices. | Useful. Persistent task errors and pending requests must also live in task state, not disappear with a toast. | [S43] |

## Planning implications

1. Treat mobile as an execution and supervision client. Queueing, pending approvals, structured answers, completion notifications, draft retention and reconnect recovery deserve priority over reproducing Desktop administration pages.
2. Separate remote file management from output access and context selection. A phone can omit a full tree/editor yet still need to attach a selected server file, inspect an image/PDF, download a generated artifact and share it.
3. Do not collapse all approvals into a single text reply. Desktop distinguishes action permissions, clarification, sudo, secret entry, vault unlock, login capture and verification codes. Each uses different protocol semantics.
4. Per-session model selection, profile approval policy and session YOLO are different scopes. Mobile must show the effective state without silently applying changes to another profile or task.
5. Preserve features that help a user leave and return. Desktop's big advantage is not its window arrangement; it is the detailed state behind each ongoing conversation.
6. Source existence is weaker than end-to-end validation. These controls were traced in source, not executed against live credentials, every provider, or the user's installed Desktop binary. The strict local-model flag and opt-in reactions are explicit exceptions to default availability; goals/loops/heartbeats and voice depend on server support/configuration.

## Immutable source index

[S1]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/chat/sidebar/index.tsx
[S2]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/chat/sidebar/session-actions-menu.tsx
[S3]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/chat/sidebar/sessions-section.tsx
[S4]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/lib/session-export.ts
[S5]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/store/find-in-page.ts
[S6]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/components/assistant-ui/thread/user-message.tsx
[S7]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/components/assistant-ui/thread/assistant-message.tsx
[S8]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/session/hooks/use-prompt-actions/rewind.ts
[S9]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/chat/composer/context-menu.tsx
[S10]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/chat/composer/hooks/use-at-completions.ts
[S11]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/lib/desktop-slash-commands.ts
[S12]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/session/hooks/use-prompt-actions/slash.ts
[S13]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/chat/composer/hooks/use-composer-draft.ts
[S14]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/chat/composer/queue-panel.tsx
[S15]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/chat/composer/controls.tsx
[S16]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/shell/model-menu-panel.tsx
[S17]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/shell/model-catalog-menu.tsx
[S18]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/chat/composer/model-pill.tsx
[S19]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/shell/context-usage-panel.tsx
[S20]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/components/assistant-ui/tool/approval.tsx
[S21]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/shell/approval-mode-menu.tsx
[S22]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/components/assistant-ui/clarify-tool.tsx
[S23]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/components/prompt-overlays.tsx
[S24]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/chat/composer/status-stack/index.tsx
[S25]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/chat/composer/status-stack/subagent-section.tsx
[S26]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/chat/composer/status-stack/subagent-controls.tsx
[S27]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/chat/composer/status-stack/session-control-goal.tsx
[S28]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/store/session-control.ts
[S29]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/chat/composer/status-stack/session-control-heartbeat.tsx
[S30]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/chat/composer/status-stack/session-control-loop.tsx
[S31]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/components/assistant-ui/markdown-text.tsx
[S32]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/components/assistant-ui/embeds/registry.tsx
[S33]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/components/assistant-ui/embeds/providers/index.ts
[S34]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/components/assistant-ui/thread/message-parts.tsx
[S35]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/components/assistant-ui/tool/fallback.tsx
[S36]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/components/assistant-ui/thread/use-message-reactions.ts
[S37]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/store/reactions-enabled.ts
[S38]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/chat/composer/hooks/use-composer-voice.ts
[S39]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/chat/composer/hooks/use-voice-conversation.ts
[S40]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/store/wake-word.ts
[S41]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/store/quick-entry.ts
[S42]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/store/native-notifications.ts
[S43]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/store/notifications.ts
[S44]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/chat/composer/status-stack/subagent-transcript.tsx
[S45]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/components/assistant-ui/thread/list.tsx
