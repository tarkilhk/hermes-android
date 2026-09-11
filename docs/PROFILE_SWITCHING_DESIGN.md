# Hermes Android profile switching that matches Hermes Desktop

> Current fork scope is recorded in the [owner-selected product plan](PRODUCT_PLAN.md), dated 2026-09-11. This document is a dated design, audit or implementation record. Its earlier roadmap and approval statements do not add requirements to the current plan; retain useful evidence and ownership contracts without restoring the old UI by default.

**Evidence baseline (2026-09-06).** Hermes Agent checkout `b499ab11fe8b081470e269f2fb27abae03000da5` (2026-09-05); Hermes Android release tag `v2.1.1`, commit `e1b94e2b4cef661174e3c6382407c05749087753`. All citations below are first-party source or documentation.

## What “Desktop-style” means upstream

There are two related but distinct official implementations.

1. **Machine dashboard (web).** The sidebar selector calls React `setProfile`; selection is client state, mirrored to `?profile=…` and to the dashboard API client. It is a *management/chat scope*, not a request to change the running dashboard process or the sticky default. Routed pages are keyed by profile so they remount and refetch. [Provider](https://github.com/NousResearch/hermes-agent/blob/b499ab11fe8b081470e269f2fb27abae03000da5/web/src/contexts/ProfileProvider.tsx#L12-L34) · [switcher](https://github.com/NousResearch/hermes-agent/blob/b499ab11fe8b081470e269f2fb27abae03000da5/web/src/components/ProfileSwitcher.tsx#L11-L76) · [remount](https://github.com/NousResearch/hermes-agent/blob/b499ab11fe8b081470e269f2fb27abae03000da5/web/src/App.tsx#L832-L845)

   * `GET /api/profiles` lists profiles; `GET /api/profiles/active` returns both `active` (sticky default) and `current` (dashboard process scope). `POST /api/profiles/active` only writes the sticky default for later CLI/gateway launches; it explicitly **does not** retarget the running dashboard. [Routes](https://github.com/NousResearch/hermes-agent/blob/b499ab11fe8b081470e269f2fb27abae03000da5/hermes_cli/web_routers/profiles.py#L634-L642) · [active semantics](https://github.com/NousResearch/hermes-agent/blob/b499ab11fe8b081470e269f2fb27abae03000da5/hermes_cli/web_routers/profiles.py#L704-L731)
   * Dashboard chat is genuinely profile-scoped: `profile` resolves the named home, sets the child TUI's `HERMES_HOME`, and deliberately does not attach it to the dashboard-profile gateway. [Chat launch](https://github.com/NousResearch/hermes-agent/blob/b499ab11fe8b081470e269f2fb27abae03000da5/hermes_cli/web_server_chat.py#L298-L377)
   * Its all-profile session sidebar does **not** ask each profile gateway. It opens every profile's `state.db` read-only, tags every row with its owner, merges/sorts, and returns `/api/profiles/sessions` (or the batched `/sidebar`). Its all-profile project tree likewise scopes the server-side builder to each home and reads each profile database. [Sessions](https://github.com/NousResearch/hermes-agent/blob/b499ab11fe8b081470e269f2fb27abae03000da5/hermes_cli/web_routers/profiles.py#L362-L412) · [projects](https://github.com/NousResearch/hermes-agent/blob/b499ab11fe8b081470e269f2fb27abae03000da5/hermes_cli/web_routers/profiles.py#L559-L588)

2. **Electron Desktop.** Its active-backend state is `$activeGatewayProfile`. On selection/use, `ensureGatewayProfile(profile)` resolves and opens/reuses that profile's pooled gateway socket, updates the connection descriptor and active profile atom together, and intentionally propagates an error rather than silently falling back to the wrong profile. Background profile sockets may remain live. [Profile store](https://github.com/NousResearch/hermes-agent/blob/b499ab11fe8b081470e269f2fb27abae03000da5/apps/desktop/src/store/profile.ts#L487-L560) · [routing test](https://github.com/NousResearch/hermes-agent/blob/b499ab11fe8b081470e269f2fb27abae03000da5/apps/desktop/src/plugin-socket-scope.test.ts#L83-L119)

**Conclusion:** selecting a profile is not a request to change `active_profile`. The dashboard already exposes an app-global remote-mode contract that a remote Android client can use through one authenticated dashboard endpoint: REST session routes accept `profile`, JSON-RPC session methods bind new/resumed sessions to `params.profile`, and the `projects.*` family is wrapped in a profile-scoped `HERMES_HOME`. Electron may use its privileged pooled-gateway implementation, but Android does not need to reproduce that pool to obtain the same profile-scoped project/session tree. [REST sessions](https://github.com/NousResearch/hermes-agent/blob/b499ab11fe8b081470e269f2fb27abae03000da5/hermes_cli/web_routers/sessions.py#L163-L190) · [JSON-RPC profile scope](https://github.com/NousResearch/hermes-agent/blob/b499ab11fe8b081470e269f2fb27abae03000da5/tui_gateway/server.py#L420-L506) · [Projects scope](https://github.com/NousResearch/hermes-agent/blob/b499ab11fe8b081470e269f2fb27abae03000da5/tui_gateway/methods_projects.py#L27-L37)

The official profile model still supplies the isolation boundary: each profile is its own `HERMES_HOME`, including sessions, state database, configuration and gateway state. The dashboard's explicit profile-scoping helpers select that home per request without changing the running process's default. [Docs: profile isolation](https://hermes-agent.nousresearch.com/docs/user-guide/profiles#what-are-profiles) · [implementation details](https://hermes-agent.nousresearch.com/docs/user-guide/profiles#how-it-works).

## Android v2.1.1 integration facts

* Workspace is constructed with one `SavedConnection`; Home currently reads that connection's profile-specific API-server client (`ApiClient`, normally port 8642), which has no selected-Hermes-profile field. [Workspace constructor](https://github.com/rusty4444/hermes-android/blob/e1b94e2b4cef661174e3c6382407c05749087753/lib/core/screens/workspace_screen.dart#L118-L180) · [session load](https://github.com/rusty4444/hermes-android/blob/e1b94e2b4cef661174e3c6382407c05749087753/lib/core/screens/workspace_screen.dart#L264-L280).
* Native Projects use `DesktopGatewayClient` and `ProjectsRepository`, but every `projects.*` RPC currently omits `profile`, and caches are keyed only by `connection.id`. [Workspace initialization](https://github.com/rusty4444/hermes-android/blob/e1b94e2b4cef661174e3c6382407c05749087753/lib/core/screens/workspace_screen.dart#L605-L687) · [RPC client](https://github.com/rusty4444/hermes-android/blob/e1b94e2b4cef661174e3c6382407c05749087753/lib/core/services/projects_gateway_client.dart#L32-L120).
* The reachable legacy selector in `SessionListScreen` loads **saved connections**, stores `last_connection_id`, and replaces the screen with a different `SavedConnection`; it does not discover or select Hermes profiles. [Selector](https://github.com/rusty4444/hermes-android/blob/e1b94e2b4cef661174e3c6382407c05749087753/lib/core/screens/session_list_screen.dart#L408-L475).
* Android already has the required dashboard authentication ladder, a reusable authenticated `DashboardClient.apiGet(..., queryParameters:)`, and one-shot WebSocket ticket minting before Desktop Gateway RPC. [Dashboard client](https://github.com/rusty4444/hermes-android/blob/e1b94e2b4cef661174e3c6382407c05749087753/lib/core/services/connection_manager.dart#L1059-L1249) · [ticket use](https://github.com/rusty4444/hermes-android/blob/e1b94e2b4cef661174e3c6382407c05749087753/lib/core/services/desktop_gateway_client.dart#L130-L180).

## Smallest honest architecture

### Contract

Keep one host connection and add an independent profile scope:

```
HermesProfile { name, displayName }
ProfileSelection { connectionId, profileName }
WorkspaceScope { connectionId, profileName }
```

A selection means: **keep the same authenticated dashboard endpoint, change `WorkspaceScope.profileName`, and rebuild/refetch every profile-owned surface with that profile argument.**

1. Add a Workspace `ProfilePicker`, populated by authenticated `GET /api/profiles`; persist the selected canonical profile name per saved connection. Never use the presentation-only display name for routing.
2. Add a profile-scoped dashboard data client. Home/Chats read `GET /api/sessions?profile=<name>`; search and message-history/detail routes carry the same `profile` query parameter. In modern profile mode these dashboard routes replace the port-8642 API server as the source of session metadata/history; retain the old API client only as a compatibility path when profile discovery/scoping is unavailable.
3. Add the selected profile to every profile-owned JSON-RPC call. At minimum this covers `projects.*`, `session.list`, `session.create`, `session.open`, session mutations, and any control call that resolves config/model/files through `HERMES_HOME`. The existing server stores the selected profile on session creation/resume, so subsequent prompt events remain attached to the correct profile.
4. On selection, cancel or generation-strand only stale **read requests**, detach the visible project/session route, clear transient rows, and refresh sessions plus `projects.tree`. Do **not** interrupt an active agent turn or dispose its recovery coordinator. Keep background turn ownership keyed by `connectionId + canonicalProfileName + sessionId`, continue journaling its events, and notify on settlement. Scope all caches, recovery journals, quick-chat state, model selections, and UI keys by profile; a late profile-A read must never paint profile B, while profile A's running turn remains resumable.
5. Fail closed. If profile B cannot be authenticated or loaded, show a B-specific error and keep A as the committed scope; never silently issue the request without `profile`, because omission targets the dashboard process's own profile.

This is the web dashboard's request-scoped model adapted to Android. It uses public authenticated REST and JSON-RPC contracts already implemented by Hermes, not filesystem access, sticky-default mutation, inferred ports, or Electron IPC.

### Server prerequisites and fallback

The configured dashboard must be new enough to provide `GET /api/profiles`, profile-aware REST session routes, and profile-scoped JSON-RPC methods. The Hermes version installed on this host already contains those contracts. The Android app should capability-probe them and hide/disable the profile picker on older servers rather than pretending a successful switch occurred.

Do **not** use `POST /api/profiles/active`: it changes future-launch default state and leaves the running server's current profile unchanged. Do **not** require one Android endpoint mapping per profile for the modern path; separately exposed profile gateways remain a legacy fallback only.

Dashboard access is privileged machine-management access. Use the app's existing authenticated cookie/token flow and one-shot WebSocket tickets; do not expose an open dashboard to an untrusted network. [Dashboard profile route](https://github.com/NousResearch/hermes-agent/blob/b499ab11fe8b081470e269f2fb27abae03000da5/hermes_cli/web_routers/profiles.py#L634-L642) · [Android auth behavior](https://github.com/rusty4444/hermes-android/blob/e1b94e2b4cef661174e3c6382407c05749087753/lib/core/services/connection_manager.dart#L1119-L1249).

### Failure and compatibility behavior

* If the target endpoint is missing, unauthenticated, unhealthy, or lacks `projects.*`, keep the previous Workspace selection/data visible, show the target/profile-specific error, and offer retry/edit mapping. Do not fall back to the default endpoint: that can write to the wrong profile.
* If REST works but Desktop Gateway/`projects.*` does not, switch and show sessions; retain Android's existing “Projects unavailable”/unsupported behavior. `ProjectsUnsupportedException` is already designed as a compatibility signal. [Client behavior](https://github.com/rusty4444/hermes-android/blob/e1b94e2b4cef661174e3c6382407c05749087753/lib/core/services/projects_gateway_client.dart#L18-L37) · [Workspace fallback](https://github.com/rusty4444/hermes-android/blob/e1b94e2b4cef661174e3c6382407c05749087753/lib/core/screens/workspace_screen.dart#L628-L687).
* Dashboard discovery failure must not disable manually configured endpoints. A user can continue with their configured profile services.

## Focused acceptance tests

1. **Picker/scope reconstruction:** choosing profile B rebuilds every Workspace surface with `(connection, B)`; old session/project rows cannot render while B's load is pending.
2. **Correct reload:** one fake dashboard returns distinct sessions and `projects.tree` data for profile A and B; selecting B renders only B, and selecting A again reloads A.
3. **RPC ownership:** project detail, new chat and resumed chat after a switch carry `profile: B`; session IDs from A are never sent while B is selected.
4. **Race/failure:** make B auth/session/Projects requests fail or resolve after a rapid A→B→A change. The final visible scope and clients must be A; failed B must not commit or cause an unscoped/default fallback.
5. **Capability split:** profile-scoped session REST succeeds while `projects.list` returns JSON-RPC method-not-found; B sessions still render and Projects shows the existing unsupported state.
6. **Persistence/auth:** restart restores the selected canonical profile per connection; profile discovery uses the existing cookie/token path, secrets remain in secure storage, and ticket minting is repeated for a new gateway socket.
7. **End-to-end isolation:** create a uniquely titled chat and project under B, verify both appear in B and never A, restart the app, then repeat the assertions before claiming parity.
8. **Background continuity:** start a long-running turn in A, switch to B, verify A continues and settles without an interrupt call, then switch back to A and recover the completed transcript/status.
