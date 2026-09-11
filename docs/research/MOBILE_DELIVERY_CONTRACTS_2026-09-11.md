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
