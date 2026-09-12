# Mobile delivery contract checks — 2026-09-11

These checks extend the original feature audit. Source is the Desktop tree at `NousResearch/hermes-agent` commit `d15ed4445207dda418b984e8bda0f68f48b8c6f3`. The local Desktop gateway used in earlier tests was not running, so these are source findings, not deployed-server verification.

## Activity (D05)

`session.active_list` returns `sessions` with runtime `id`, durable `session_key`, `status` and optional `last_active`. Desktop treats `working` and `waiting` as active and reconciles absence from a successful snapshot. Profiles use separate gateways; one profile's snapshot does not enumerate another's work. Android can reuse its scoped gateways and query each discovered profile without changing the active view. `starting` is also presented as running.

Activity enumeration must not resume every session. Resume can attach or create a runtime; call it when opening a selected session. A bounded first page of existing session metadata supplies titles where available; it is not the authority for liveness. If that page lacks a title, retain the live item with a short durable ID. Report unavailable profiles separately.

Evidence: [`use-background-sync.ts`](https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/contrib/hooks/use-background-sync.ts), especially active-list synchronization; [`api/sessions.ts`](https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/api/sessions.ts) for metadata.

## Sensitive requests (D07)

| Event | Response method | Response fields, plus Android's immutable profile scope |
| --- | --- | --- |
| `sudo.request` | `sudo.respond` | `request_id`, `password` |
| `secret.request` | `secret.respond` | `request_id`, `value` |
| `vault.unlock.request` | `vault.unlock.respond` | `request_id`, `password` |
| `vault.code.request` | `vault.code.respond` | `request_id`, `code`, removing spaces/hyphens |
| `vault.save_login.request` | `vault.save_login.respond` | `request_id`, `login`, a JSON string with trimmed `identifier` and `password` |

Empty values are explicit cancel/skip/decline responses. Matching vault `*.expire` events clear only the matching kind and request ID. Desktop treats specific missing-pending-request RPC errors as expiry. Other failures permit retry. Values belong only in the input fields and response call; do not save them with composer drafts, journals, chat messages or diagnostic errors.

Resume exposes approval and clarification metadata but the inspected contract has no pending sudo/secret/vault fields. Keep a known request across a brief disconnect only while the runtime identity remains the same. A process restart cannot reconstruct unseen sensitive requests. This remains a backend limitation, not a reason to persist passwords or invent pending fields.

Evidence: [`prompt-overlays.tsx`](https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/components/prompt-overlays.tsx), [`input-requests.ts`](https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/session/hooks/use-message-stream/gateway-event/input-requests.ts), and [`types/hermes.ts`](https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/types/hermes.ts).

## Queue and steer (D09)

Desktop's ordinary composer queue is client-owned, not a discovered server queue RPC. The owner explicitly approved following this design after the audit. Android therefore stores queued text as unsent work, scoped like a draft, and uses the existing submit path when the previous turn finishes. No server queue endpoint is required.

The existing `session.steer {session_id,text}` contract returns `queued` or `rejected`. Check that response rather than treating RPC completion as acceptance. Desktop also uses `session.redirect` in its active correction path with `redirected`/`queued`; Android retains its established `session.steer` path, without adding an unverified fallback.

Evidence: Desktop `app/session/hooks/use-prompt-actions/index.ts` and `utils.ts`, plus `composer-queue` / `use-composer-queue` implementation. Queue and Steer remain separate: queue waits for a later turn; steer is submitted to the active run.

## Edit, versions and fork (D10; investigation only)

Desktop edit/regenerate rewinds the same live session through `prompt.submit`: corrected/original text, `truncate_before_row_id` where possible, `confirm_truncate:true`, and `confirm_empty_truncate:true` when the surviving prefix may be empty. Everything after that boundary is replaced. Android already uses the row-addressed form for regeneration; reuse it for an explicit saved-user-message Edit action.

Desktop's answer-version arrows use renderer branch groups. The inspected session-message contract has no persisted answer-version field, and the renderer's session state is in memory. The inference from its read/write path is that prior alternatives cannot be reconstructed after a reload once the server tail has been truncated. This does not establish a backend version-history feature.

Android currently creates real server child chats for alternatives but saves their version grouping locally. Those relationships are more durable than Desktop's renderer grouping, yet conflict with the original server-owned version requirement. Do not infer missing version links by comparing transcript text or expand that schema without a product decision. The owner has approved client-owned queues; that concrete exception must not be silently generalized to all server data.

Separate-chat fork is `session.branch {session_id,count?}`. Count refers to display text rows through a saved boundary; Android already validates and uses this operation. A one-shot Fork submission can reuse that path when idle, then send into the returned child. Do not fork an unsaved streaming tail. Desktop's stored-session reconstruction fallback is unnecessary for an already open live Android chat.

Evidence: [`use-prompt-actions/rewind.ts`](https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/session/hooks/use-prompt-actions/rewind.ts), [`use-session-actions/index.ts`](https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/session/hooks/use-session-actions/index.ts), and the session/message types above.

## Side questions (D11; investigation on 2026-09-12)

Desktop starts a side question with `prompt.btw {session_id,text}` and uses the acknowledged `task_id` in its start notice. `btw.complete` supplies `task_id`, `question` and `text`; Desktop renders a control row identifying that question and task. Android already routes these events to the originating profile/chat, but discards their task identity and shows plain command output. A small follow-up can retain transient task identity and show distinct pending/completed deliveries without persisting another copy of server history.

The inspected source does not establish a recovery/list API for side questions. Android's existing direct `prompt.background` path also needs deployed-gateway verification: Desktop uses slash dispatch for `/bg`, and its event rendering does not demonstrate `background.complete` support. Keep these limits explicit rather than inventing background task recovery.

Evidence: Desktop `app/session/hooks/use-prompt-actions/slash.ts`, `app/session/hooks/use-message-stream/gateway-event/status.ts`, `btw-complete-event.test.tsx`, and `desktop-slash-commands.ts` at the pinned commit above.

## Execution output (D14; investigation on 2026-09-12)

Android already groups stored tool rows into expandable sections. Its active controller only keeps a live tool name, despite reusable `GatewayToolActivity` and `GatewayReasoningUpdate` parsers elsewhere in the repository. Wire those into the active view rather than introducing another protocol/model layer.

Desktop upserts `tool.start`, `tool.progress` and `tool.complete` by tool ID; `tool.generating` is a name-only status and does not create an unfinished row. Useful payload fields include args/arguments, context, preview, result, summary, error and server `duration_s`. Keep raw args/results collapsed. Read-only todo snapshots arrive as `todo.updated`, or `todo_state {revision,todos}` on create/resume. Todo items have `id`, `content`, `status` and optional `parent`; known statuses are pending, in_progress, completed and cancelled. Ignore older revisions. No local task editing is implied.

`reasoning.delta` appends and `reasoning.available` replaces. Historical assistant rows can expose `reasoning`, `reasoning_content` or string `reasoning_details`. Whole-turn duration is renderer state in Desktop, not a durable backend message field; server tool duration can be displayed without inventing persisted timings.

Evidence: pinned Desktop `app/session/hooks/use-message-stream/gateway-event/tools.ts`, `tool-parts.ts`, `message-stream.ts`; `lib/chat-messages/types.ts`, `hydration.ts`; `lib/todos.ts`, `store/todos.ts`; and `components/assistant-ui/tool/fallback.tsx`.

## History and read state (D18/D19; Android audit on 2026-09-12)

The active Android client already paginates server history, preserves its reading anchor, exposes Latest/New activity, searches unloaded conversations through `sessions/search`, and writes read/unread through the profile-scoped session patch. Existing tests cover stale queries, profile changes, failures and retry. The main gaps are find inside the current chat and remaining selected Chats filters. Do not replace these working server paths or represent a search of loaded rows as a search of all history.

## Chat outputs (D16/D17; investigation on 2026-09-12)

Desktop has no authoritative outputs enumeration API in the inspected client. `app/artifacts/index.tsx` derives candidates from server messages using `artifact-utils.ts`. Its global screen scans recent sessions, but Android's selected scope uses exactly one chat. Assistant collection covers MEDIA references, Markdown destinations, qualifying URLs and file paths. Tool collection is narrower: producer names and explicit result keys such as output_path, generated_file, files_created, saved_to and screenshot_path. This is an ephemeral heuristic, not new server-owned metadata.

Desktop reads saved messages oldest-first in pages of 500 with `include_compacted=true` and a JSON-size cap. The client-owned fenced-code artifact store is separate from backend files; a code fence does not establish that a file exists.

Remote open carries the original connection, profile and durable session ID into `GET /api/fs/download?path=...&session_id=...&profile=...`. The server's Content-Disposition supplies the filename. Desktop also has a 404-only data-URL fallback; Android intentionally uses the modern download route. Text preview is `/api/fs/read-text` with path/profile; Android additionally carries the session identity for relative-path resolution. Images can use authenticated downloaded bytes. Interactive HTML is a separate renderer/staging path in Desktop, not something an ordinary Android external link can reproduce.

The existing Android RemoteFilesClient provides the transport seam but originally omitted owner parameters and buffered arbitrary download sizes. D16 adds mandatory owner fields and a byte cap. Deployed file authorization, relative/tilde path resolution and MIME/range behavior still need live verification. Source evidence includes Desktop `app/artifacts/artifact-utils.ts`, `app/artifacts/index.test.ts`, `remote-open.test.tsx`, `gateway-file-download.test.ts` and `api/sessions` at the pinned commit.

## Project actions (D20; investigation on 2026-09-12)

The active Android project flow already creates a named project with a host folder using `projects.create {name,folders:[path],primary_path:path}`. Returning to all chats is client navigation and sends no backend active-profile mutation. Rename/delete and icon/color editing are missing from this active flow, though separate retained project services contain related methods.

Desktop uses `projects.update {id,name?,color?,icon?,profile}` and `projects.delete {id,profile}`. An empty string clears an icon/color; omitted or null values leave them unchanged. The existing Android `projects.tree` parser retains these server fields, but the current project row substitutes a folder icon and an ID-derived accent. Reuse that row for a small actions menu, render server appearance and refresh server metadata after writes. No repository discovery/adoption feature or broader administration scope is implied by these contracts.

Evidence: pinned Desktop `store/projects.ts` (`createProject`, `renameProject`, `setProjectAppearance`, `deleteProject`) and the earlier [project contract notes](FEATURE_PLAN_CONTRACT_NOTES_2026-09-11.md).

Desktop waits for each write RPC before reconciling server state. Its update path sends only defined fields and maps explicit null appearance values to `''`; the backend treats null or omission as unchanged and the empty string as clear. Its delete path consumes the acknowledged `ProjectsPayload {projects,active_id}` before refreshing `projects.tree`. The retained Android `ProjectsGatewayClient` likewise requires a returned `project` record for `projects.update` and a valid project snapshot for `projects.delete`; the active profile-scoped gateway now uses those acknowledgment shapes before publishing a fresh tree.

Desktop also documents the destructive boundary directly in `deleteProject`: deleting removes the project record, clears it as active, and exits an open project view, while each session survives and falls back to Recents. Android therefore clears only the deleted project association on cached chats and keeps their transcript and draft. These are pinned-source contracts; no deployed-server write was performed for this investigation.

## Per-chat subagents (D23; investigation on 2026-09-12)

Desktop uses the parent runtime ID for every subagent operation. `subagent.list {session_id}` returns `subagents` and `delegations`; the composer consumes the roster and leaves `delegations` unused. Roster fields include `subagent_id`, `parent_id`, `goal`, `child_session_id`, `delegation_id`, `model`, `status`, `task_count`, `task_index`, `started_at`, `last_tool`, duration/cost/token/tool counts, and files read or written.

`subagent.tail {session_id,subagent_id}` returns `{subagent_id,available,text,truncated}`. Desktop polls it only while details are open, keeps at most the final 16,384 characters, and never stores the transcript locally. `subagent.steer {session_id,subagent_id,text}` is accepted only when `status == "queued"`. `subagent.interrupt {session_id,subagent_id}` is accepted only when `found == true`; the client waits for server events or a snapshot before changing displayed status.

The live event family is `subagent.spawn_requested`, `subagent.start`, `subagent.thinking`, `subagent.tool`, `subagent.progress` and `subagent.complete`. These events require an explicit session ID. Status values normalize to queued, running, completed, failed or interrupted; timeout/error become failed and canceled becomes interrupted. Progress may also carry `text`, `summary`, `tool_name`, `tool_preview` and `output_tail` entries with `tool`, `preview` and `is_error`.

Desktop prevents a late roster read from resurrecting a child completed by a newer event. It applies a snapshot only when the known owner and the session's pre-request list identity are unchanged, and it never downgrades an already terminal row. The roster polls every five seconds while mounted; the expanded tail polls every two seconds. Failures retain event-fed state rather than inferring children from generic tool calls.

Android already has an event parser and merge model in `lib/core/models/gateway_insight.dart`, an unused display grouping seam in `lib/core/utils/chat_display_items.dart`, and the six event names in `lib/core/services/desktop_gateway_client.dart`. The model is not currently connected to `ProfileChat`, the active controller event switch or the production chat screen. It also does not retain exact status, child/parent/delegation IDs, timing metrics, file lists or current tool. Extending that model and adding transient per-chat state is the smallest reuse path; no durable subagent registry is established by this contract.

Any Android list, tail, steer or interrupt method should accept the owned `ProfileChat`, capture its profile-bound resource and runtime ID before awaiting, and fail closed if the chat, runtime or selected child changes. The RPC must travel through that captured resource's gateway. It must never use the visible profile, another socket, the child's transcript session ID or the durable parent ID as a fallback. A per-chat event revision provides the equivalent snapshot race guard: discard the list response when a newer event changed the revision.

Evidence: [`use-subagent-snapshot.ts`](https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/chat/composer/status-stack/use-subagent-snapshot.ts), [`subagent-transcript.tsx`](https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/chat/composer/status-stack/subagent-transcript.tsx), [`subagent-controls.tsx`](https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/chat/composer/status-stack/subagent-controls.tsx), [`subagent-section.tsx`](https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/chat/composer/status-stack/subagent-section.tsx), and [`store/subagents.ts`](https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/store/subagents.ts). The pinned client establishes these request and response expectations; no backend handler source or deployed-gateway verification was available in this audit.

### Installed backend follow-up, 2026-09-12

The installed backend at revision `8d79c2ff57bba4b07e5b37ed90387b16541aef53` supplies the handlers in `tui_gateway/methods_subagents.py`. Its list is narrower than Desktop's display types: active children only, with `subagent_id`, `parent_id`, `depth`, `goal`, `delegation_id`, `model`, `started_at`, `status`, `tool_count`, `last_tool` and `accepting_steer`. `delegations` is empty. Completion unregisters the child, so a later list cannot recover a completed roster and a finished tail can be unavailable.

Tail returns the last 16 KiB of live text. Steer replies `queued` or `rejected`; queued means accepted for delivery, and a later `missed_steer` outcome is possible. Interrupt requires `found: true` and the same returned child ID. These methods validate the parent session's live transport and generation; missing or foreign ownership fails rather than falling back to another runtime.

Live completion events can carry more fields than the list. The child completion builder supplies cost, but the inspected progress whitelist drops `cost_usd`; the initial Android view must not promise it. Keep event-fed completion summaries in the current chat only, with no durable child history. Source evidence also includes `tui_gateway/tool_progress.py`, `tools/delegate_tool_child_run.py` and `tests/tui_gateway/test_subagent_snapshot.py`. This is source verification, not a live control action on the owner's server.

## Background notifications (D26/D27; follow-up on 2026-09-12)

The installed backend above emits `notification.show`/`notification.clear` through the transient TUI event stream (`tui_gateway/agent_callbacks.py:101-105`). The inspected source has no Firebase token registration, installation registry or FCM sender. Android already has local notification settings, original-session routing and authenticated reopening in `turn_notification_service.dart` and `main.dart`; these should be reused.

Firebase project/app configuration for `com.tarkilhk.hermes.android` and trusted server-side sender credentials remain external setup dependencies. No SDK, project, credential or backend registration API was added during this investigation. Completion/input events need authenticated profile-scoped registration and minimal routing payloads, then client token lifecycle, duplicate handling and locked/terminated-phone checks. All conversation state stays on Hermes. FCM remains selected roadmap work while independent app milestones continue.

## Session usage and cost (S02; follow-up on 2026-09-12)

The primary contract is `GET /api/analytics/usage?days=30&profile=...`, implemented in installed `hermes_cli/web_routers/analytics.py:75-150`. It reads the selected profile's session database with a bounded day interval and returns `totals`, `daily`, `by_model`, `by_task`, `period_days`, skills and tools. This performs no inference or provider billing-portal request. Desktop's Command Center uses the same analytics route.

Totals contain server-recorded sessions, API calls, input/output/cache/reasoning tokens, estimated cost and provider-reported actual cost. The SQL coalesces an absent actual-cost sum to zero, so that number is not proof of a zero bill: unreported provider costs are excluded. The client should label it reported cost where available and retain Unknown for malformed/missing fields. Estimates remain explicitly estimates supplied by Hermes.

The model breakdown adds auxiliary model calls while the overview totals come from session rows. Do not recompute or force those totals to match on the client. Label auxiliary inclusion in the breakdown. `usage.bars` is a separate Nous subscription/top-up balance surface and was rejected as the primary S02 source; it is not general session cost analytics.
