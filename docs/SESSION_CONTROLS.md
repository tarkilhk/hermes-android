# Session goals and background work

D24's initial goal view and controls are implemented in 2.8.0. Open **Goal** from a chat's three-dot menu. Existing server goals also appear in the conversation. D25 adds **Background work** in 2.9.0 for heartbeat, loop and process controls. These controls use server-owned session state; they do not create a second goal scheduler on the phone.

Pause, Resume, Resume now and confirmed Clear wait for the server's reply. Resume continuations reuse prompt submission while preserving unsent composer text, attachments and queued messages. A newer, different server update prevents an outdated continuation from being submitted. Uncertain actions are not retried automatically. The initial R13 view shows criteria and verification details; criteria editing remains planned.

## Verified contracts

Installed backend revision `8d79c2ff57bba4b07e5b37ed90387b16541aef53`, in `tui_gateway/methods_session_control.py`, supplies:

- `session.control.read {session_id}` returns `{control}`. The control contains `goal`, `loop`, `heartbeat`, an opaque content-hash `revision` and persisted `updated_at`.
- `session.control {session_id,action,args:{}}` returns `{control,dispatch}` and emits `session.control.update`. The dispatch can be an executed command's output or a continuation prompt that the client must submit through its existing prompt flow.
- Goal actions are `goal.pause`, `goal.resume`, `goal.clear` and `goal.unwait`. The initial mobile view will expose these supported actions and existing criteria, without adding goal creation or gate editing. The backend explicitly rejects gate actions here.
- Loop actions are `loop.pause`, `loop.resume` and `loop.stop`. Heartbeat actions are `heartbeat.pause`, `heartbeat.resume` and `heartbeat.clear`.

The goal snapshot includes title/status, turn usage/limit, contract outcome/verification/constraints/boundaries/stop condition, subgoals and gate results. Optional values include pause and verification reasons, timestamps, and wait barriers until a timestamp or for another session/process. Clearing a goal returns `goal: null`. An absent or malformed goal field must not be interpreted as successful clearing.

Loop snapshots include prompt/status, interval or self-paced mode, delay, count/limit, next due time, waiting-for-response and deferred-by-goal status. Heartbeat snapshots include prompt/status, interval, last fire time and fire count. Read timestamps come from persisted server data rather than the client's clock.

Desktop's typed implementation is in `apps/desktop/src/store/session-control.ts` and `apps/desktop/src/app/chat/composer/status-stack/session-control-goal.tsx` at revision `d15ed4445207dda418b984e8bda0f68f48b8c6f3`. Its older text-only `/goal status` fallback does not replace the structured snapshot or continuation contract.

## Background work

Open **Background work** from the chat menu to read the selected session's loops, heartbeat and processes. Known work also appears in the conversation. Refresh retrieves both the recurring-work snapshot and current process rows. Recurring-work updates arrive through the existing server event stream; process output is a snapshot refreshed on request.

Loops expose Pause, Resume and Stop; heartbeats expose Pause, Resume and confirmed Clear. Running process rows expose targeted Stop. Finished rows retain their output and can be dismissed for this app session. Dismiss does not delete server history. Reads and stop acknowledgements are guarded against profile/runtime changes, duplicate taps and late responses.

The installed gateway reads `process.list {session_id:<parent runtime>}` through a live session. It filters the process registry by that session's server-owned `session_key`. Rows use `session_id` as the process ID and include command, working directory, PID, owner task, server-reported uptime, `running` or `exited` status, and a 4,000-character output tail. Exit code, detached state and completion notification are optional. There is no separate process-output RPC.

A targeted stop uses `process.kill {session_id:<parent runtime>,process_id:<row session_id>}`. The handler rejects a process outside the resolved session before attempting the kill. A `killed` or `already_exited` result is an acknowledgement; a resolved `{status:"error"}` payload is not. The gateway has no `process.dismiss` method. Desktop dismissal is transient client state that hides a finished row while the registry still reports it. Broad `/stop` calls the separate global `process.stop` operation and is not a per-row substitute.

## Mobile boundaries

All reads and actions belong to the original profile gateway and parent runtime. Newer server events must survive older reads. A control acknowledgement must be handled without erasing unsent text, attachments or queued messages. No failed or uncertain action is retried automatically. Goal/loop continuation uses the existing prompt submission path.

This work does not reopen the deferred Cron, bots, messaging or webhook administration scope. Live-server and phone verification will be recorded after implementation.

## Verification

The 2.8.0 goal snapshot passed 1,042 tests with four opt-in skips and a clean analyzer. Checks cover reopened/ready-event hydration, late reads, event/action races, exact action routing, preserved composer state, continuation failures, malformed responses, the chat-menu entry and large-text layout. Signed Personal 2.8.0 / 21572 passed package/certificate checks, installed in place wirelessly and launched on the owner's phone. Phone evidence is package/process metadata; no live goal was changed during fixture checks.

The 2.9.0 D25 snapshot passed 1,057 tests with four opt-in skips and a clean analyzer. Checks cover exact session/process routing, kill acknowledgement variants, duplicate actions, late reads, transient dismissal, partial refresh failure, chat-menu navigation and large-text controls. Signed Personal 2.9.0 / 21582 passed package/certificate checks. Installation is pending because the authorized wireless endpoint refused the connection; the last verified phone installation remains 2.8.0. No live loop, heartbeat or process has been stopped during development checks.
