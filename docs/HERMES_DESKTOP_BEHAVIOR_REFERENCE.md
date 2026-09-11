# Official Hermes Desktop behavior reference

> Current fork scope is recorded in the [owner-selected product plan](PRODUCT_PLAN.md), dated 2026-09-11. This document is a dated design, audit or implementation record. Its earlier roadmap and approval statements do not add requirements to the current plan; retain useful evidence and ownership contracts without restoring the old UI by default.

Research date: 2026-09-06. Official source inspected: `NousResearch/hermes-agent` commit `245e48008fa814b3251f50755eb656bd9fb86cb1` (2026-09-06 UTC). Android baseline: `e1b94e2b4cef661174e3c6382407c05749087753`, with fork documentation commit `116b1f9`. This is a source-based comparison, not a claim that Desktop or a live two-profile server was exercised.

Related mobile interaction research: [Codex Android UI reference](CODEX_ANDROID_UI_REFERENCE.md). Hermes Desktop remains the behavior reference for this document.

## Fork direction and inherited roadmap provenance

The user confirmed that this fork should target modern profile-aware servers directly, without backward-compatibility paths, and ultimately behave like official Electron Hermes Desktop. The upstream Android roadmap is not the user's product plan.

Git history confirms that both broader planning documents predate the fork's profile work:

- `ANDROID_DAILY_DRIVER_ROADMAP.md` was introduced by Carlos Antonio Reyes Pena in `9e2f5017d0ce5c3717fa58b69dfe339964bbaa53` on 2026-08-24. [Introducing commit](https://github.com/rusty4444/hermes-android/commit/9e2f5017d0ce5c3717fa58b69dfe339964bbaa53).
- `HERMES_ANDROID_INDISPENSABLE_PRODUCT_SPEC.md` was introduced in the same contributor's `31a56c33f9bea1624c96a5f7cd8e68dad0e4a6a8` on 2026-08-30. Both commits are ancestors of Android baseline `e1b94e2`; upstream merge `6079f83ebf2d7eaa76b2af915e7def086a830c37` is titled `Merge branch 'pr-88'`. [Specification commit](https://github.com/rusty4444/hermes-android/commit/31a56c33f9bea1624c96a5f7cd8e68dad0e4a6a8), [upstream merge](https://github.com/rusty4444/hermes-android/commit/6079f83ebf2d7eaa76b2af915e7def086a830c37).
- The baseline README credits Carlos's PR #88 for the daily-driver Workspace edition. The fork commit `116b1f9` changes only README, the two profile design/spec documents, and two profile/background-continuity ADRs. It does not introduce the broader roadmap. [Baseline credits](https://github.com/rusty4444/hermes-android/blob/e1b94e2b4cef661174e3c6382407c05749087753/README.md#L607), [fork commit](https://github.com/tarkilhk/hermes-android/commit/116b1f9).

Consequently, AI organization and Mission Control ideas in those inherited documents are historical context, not approved requirements for this fork.

## Desktop behavior to preserve

### Workspace and navigation

Desktop is chat-centered: streaming conversation and tool activity are primary, with files, previews, review, and terminal attached to the task. Its design calls for background results to update badges/data without replacing the visible transcript or stealing focus. Settings and management tasks return to the preceding context when closed. Android should adapt this behavior to a phone rather than mechanically copy a desktop pane layout. [Official design](https://github.com/NousResearch/hermes-agent/blob/245e48008fa814b3251f50755eb656bd9fb86cb1/apps/desktop/DESIGN.md#L46-L68).

Projects are server-owned, per-profile workspaces containing folders, repositories, worktrees/lanes, and sessions. `projects.tree` supplies the overview; project sessions load on drill-in. Entering a project changes the work scope without automatically opening a session. A new chat uses the entered project's root or configured default directory; an otherwise bare chat remains detached. [Project store](https://github.com/NousResearch/hermes-agent/blob/245e48008fa814b3251f50755eb656bd9fb86cb1/apps/desktop/src/store/projects.ts#L37-L150).

### Profile selection and identity

The normal sidebar shows the selected profile's sessions. Desktop also has an explicit, opt-in **All profiles** grouped browsing mode. Selecting a profile exits that mode, sets the new-chat owner, and activates that profile on the current connection/source. Canonical names are routing identities; display names are presentation only. Connection identity also matters: the same profile name on two hosts is not the same workspace. [Profile state and selection](https://github.com/NousResearch/hermes-agent/blob/245e48008fa814b3251f50755eb656bd9fb86cb1/apps/desktop/src/store/profile.ts#L752-L870), [canonical labels](https://github.com/NousResearch/hermes-agent/blob/245e48008fa814b3251f50755eb656bd9fb86cb1/apps/desktop/src/store/profile.ts#L35-L58).

Switching is a soft workspace change. The shell stays mounted; gateway-bound data resets/refetches so the previous profile's rows/transcript cannot bleed into the new view. Activation is serialized, failed gateway activation propagates an error, and no message should silently route to the previous/default socket. Some descriptor lookups remain best-effort in Desktop; its source is a behavior reference, not a guarantee that every path implements stronger atomicity than Android's proposed spec. [Switch implementation](https://github.com/NousResearch/hermes-agent/blob/245e48008fa814b3251f50755eb656bd9fb86cb1/apps/desktop/src/store/profile.ts#L487-L558), [soft-switch contract](https://github.com/NousResearch/hermes-agent/blob/245e48008fa814b3251f50755eb656bd9fb86cb1/apps/desktop/README.md#L181-L188).

The selected client profile is separate from the sticky CLI default. Desktop remembers local startup selection in its own `active-profile.json`; the live rail uses persistence-only IPC. Dashboard `GET /api/profiles/active` distinguishes `active` from `current`, and its POST changes later-launch defaults rather than retargeting the running server. Android should persist its own selection per saved connection. [Desktop persistence](https://github.com/NousResearch/hermes-agent/blob/245e48008fa814b3251f50755eb656bd9fb86cb1/apps/desktop/electron/main.ts#L856-L863), [remember IPC](https://github.com/NousResearch/hermes-agent/blob/245e48008fa814b3251f50755eb656bd9fb86cb1/apps/desktop/electron/main.ts#L16036-L16043), [server semantics](https://github.com/NousResearch/hermes-agent/blob/245e48008fa814b3251f50755eb656bd9fb86cb1/hermes_cli/web_routers/profiles.py#L704-L731).

### Running work and notifications

Profile switching does not cancel a turn or stop its backend. Dedicated background sockets continue receiving events, and the gateway registry retains routes across multi-RPC submissions and unsettled turns. Session routing and remembered navigation must retain their actual owner rather than infer it from the currently selected profile. [Gateway retention](https://github.com/NousResearch/hermes-agent/blob/245e48008fa814b3251f50755eb656bd9fb86cb1/apps/desktop/src/store/gateway.ts#L1084-L1295), [session ownership/navigation](https://github.com/NousResearch/hermes-agent/blob/245e48008fa814b3251f50755eb656bd9fb86cb1/apps/desktop/src/store/session.ts#L76-L251).

Desktop distinguishes in-app feedback from native notifications. Native categories include approval, input, completion, errors, and background completion. Approvals/input can notify for an offscreen session even while the app is focused. Ordinary completion notifications are narrower: the app must be away and the session must match the active session; explicitly global notifications have different gating. Therefore the Android spec's proposed notification on every offscreen settlement is **not exact Desktop parity**. Decide mobile notification policy deliberately. [Native notification policy](https://github.com/NousResearch/hermes-agent/blob/245e48008fa814b3251f50755eb656bd9fb86cb1/apps/desktop/src/store/native-notifications.ts#L13-L160).

### Connection and execution boundary

Desktop supports local, remote, and cloud connections. Remote onboarding discovers token/OAuth authentication and requires HTTP plus WebSocket testing; secrets use encrypted Desktop storage. In remote mode, tools, terminals, and file operations execute on the gateway host. Android should preserve that host boundary and retain its platform-appropriate secure credentials. Desktop's local installer, process spawning, and native filesystem IPC are not Android requirements. [Official connections documentation](https://github.com/NousResearch/hermes-agent/blob/245e48008fa814b3251f50755eb656bd9fb86cb1/apps/desktop/README.md#L140-L175).

Desktop does **not always open one socket per profile**. Dedicated local/per-profile routes use pooled sockets, but a shared remote host can serve multiple profiles on the primary socket with an explicit profile on each request. This is a direct precedent for Android's one-authenticated-host architecture. [Shared remote routing](https://github.com/NousResearch/hermes-agent/blob/245e48008fa814b3251f50755eb656bd9fb86cb1/apps/desktop/src/store/gateway.ts#L746-L800), [activation](https://github.com/NousResearch/hermes-agent/blob/245e48008fa814b3251f50755eb656bd9fb86cb1/apps/desktop/src/store/gateway.ts#L1451-L1476).

## Server contracts requiring verification

1. **Unknown/deleted profiles are a real isolation concern.** At this inspected commit, `_profile_home()` returns `None` for both the launch profile and an invalid/missing profile. `_profile_scoped()` then invokes the handler without a home override. `projects.*` uses this wrapper, and `session.create` also consumes `_profile_home()`. Thus merely including `params.profile` does not prove fail-closed routing: a stale profile can reach launch-profile state. Discovery validation helps but cannot eliminate deletion between discovery and a write. Require server-side rejection of unknown profiles (and an integration test) before claiming strict isolation; no fallback is approved. [Resolver/wrapper](https://github.com/NousResearch/hermes-agent/blob/245e48008fa814b3251f50755eb656bd9fb86cb1/tui_gateway/server.py#L454-L505), [project wrapper](https://github.com/NousResearch/hermes-agent/blob/245e48008fa814b3251f50755eb656bd9fb86cb1/tui_gateway/methods_projects.py#L27-L37), [session creation](https://github.com/NousResearch/hermes-agent/blob/245e48008fa814b3251f50755eb656bd9fb86cb1/tui_gateway/methods_session.py#L296-L328).
2. **Verify exact methods and owner fields.** Current source uses `session.create` and `session.resume`; the Android planning documents' “resume/open” wording is not a wire-contract definition. Check durable versus runtime IDs, event profile tags, reconnect/replay, and duplicate IDs across profiles against the deployed server. [Session resume](https://github.com/NousResearch/hermes-agent/blob/245e48008fa814b3251f50755eb656bd9fb86cb1/tui_gateway/methods_session.py#L787-L805), [Desktop duplicate-ID handling](https://github.com/NousResearch/hermes-agent/blob/245e48008fa814b3251f50755eb656bd9fb86cb1/apps/desktop/src/store/session.ts#L546-L607).
3. **Audit HTTP methods individually.** Session reads accept a profile query and stamp owners in returned rows, while some mutations take profile in the request body. “Every REST call gets a query parameter” is insufficient as an implementation rule. Verify auth/ticket expiry and every required operation on the configured dashboard. [Session routes](https://github.com/NousResearch/hermes-agent/blob/245e48008fa814b3251f50755eb656bd9fb86cb1/hermes_cli/web_routers/sessions.py#L163-L215), [mutations/detail](https://github.com/NousResearch/hermes-agent/blob/245e48008fa814b3251f50755eb656bd9fb86cb1/hermes_cli/web_routers/sessions.py#L393-L489).

For item 1, the inspected RPC dispatch validates the request envelope and invokes the registered handler; it does not reject unknown profile names first. The registry applies the same profile wrapper described above. This is a source-level finding awaiting a live reproduction, not an assertion about an uninspected deployed server. [Dispatch](https://github.com/NousResearch/hermes-agent/blob/245e48008fa814b3251f50755eb656bd9fb86cb1/tui_gateway/server.py#L713-L782), [handler registration](https://github.com/NousResearch/hermes-agent/blob/245e48008fa814b3251f50755eb656bd9fb86cb1/tui_gateway/method_ctx.py#L46-L69).

## Android gaps and recommended order

The current Workspace receives one `SavedConnection`, session loading uses that connection's API client, and project initialization/cache identity uses the connection ID. `ProjectsGatewayClient` has no profile constructor field and sends unscoped maps. These are foundational routing/state gaps before UI parity. [Workspace baseline](https://github.com/rusty4444/hermes-android/blob/e1b94e2b4cef661174e3c6382407c05749087753/lib/core/screens/workspace_screen.dart#L264-L280), [project integration](https://github.com/rusty4444/hermes-android/blob/e1b94e2b4cef661174e3c6382407c05749087753/lib/core/screens/workspace_screen.dart#L605-L687), [project client](https://github.com/rusty4444/hermes-android/blob/e1b94e2b4cef661174e3c6382407c05749087753/lib/core/services/projects_gateway_client.dart#L38-L107).

Recommended sequence (implementation guidance, not an imported roadmap):

1. Establish the deployed modern server contract, especially missing-profile rejection. Introduce required `(connection, canonical profile)` ownership and profile-bound REST/RPC clients.
2. Partition foreground data, drafts/model choices, navigation, caches, recovery, and notification targets. Keep running-session resources outside the screen's lifetime.
3. Add soft profile switching and profile-owned project/session navigation; verify two-profile isolation and background continuity on a real server/device.
4. Compare wider Desktop flows on mobile: project/worktree navigation, streaming tool presentation, approval/input handling, search/history, remote files/previews, voice and settings. Audit existing Android coverage before adding features.

Desktop's optional All profiles view is wider than the current Android profile milestone, which explicitly excludes merged trees. Record it as a later parity decision. Likewise, exact notification gating needs a mobile product decision. Neither discrepancy blocks the initial single-profile-at-a-time Workspace work.

## Suggested parity acceptance matrix

| Scenario | Expected outcome |
| --- | --- |
| Select B on one host | B sessions, projects and new-chat ownership; CLI sticky default unchanged. |
| Rapid A → B → A | Latest committed scope wins; late B reads never paint A. |
| B auth/transport failure | Visible error; no successful B indication or unscoped retry. |
| Delete B after discovery, then mutate | Server rejects; no project/chat appears in launch profile. |
| Same session/project ID in A and B | Separate cache/history/actions and correct owner on every request. |
| Long turn in A, browse/work in B | A continues; A events never replace B transcript or steal focus. |
| Reconnect or restart during A's turn | Recover using A's durable identity; no duplicate prompt submission. |
| Enter project then create chat | Correct profile and project/worktree directory; plain detached chat stays detached. |
| Attention/completion notification | Apply chosen mobile policy; opening notification resolves original connection/profile/session. |
| Switch between two hosts with profile `default` | Distinct state, credentials, routing, and notification targets. |
| Remote tools/files/terminal | Operations stay on the connected host. |
| Unsupported server contract | Explicit upgrade-required error; no legacy or default-profile mode. |

Source checkout used for inspection: `/tmp/hermes-desktop-reference`. No Desktop application execution or live gateway/device acceptance testing was performed during this research.
