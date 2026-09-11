# Profile-aware Workspace implementation specification

> Current fork scope is recorded in the [owner-selected product plan](PRODUCT_PLAN.md), dated 2026-09-11. This document is a dated design, audit or implementation record. Its earlier roadmap and approval statements do not add requirements to the current plan; retain useful evidence and ownership contracts without restoring the old UI by default.

Status: **Approved design target**  
Baseline: Hermes Android `v2.1.1` / `e1b94e2b4cef661174e3c6382407c05749087753`  
Companion design note: [PROFILE_SWITCHING_DESIGN.md](PROFILE_SWITCHING_DESIGN.md)

## Fork direction confirmed 2026-09-06

The fork owner confirmed a clean target for modern profile-aware Hermes servers.
This supersedes the legacy-client, old-server fallback, and compatibility-migration
requirements below; they are historical design text, not approved implementation
scope. Do not silently issue unscoped requests when a required capability is absent.

Official Hermes Desktop is the reference for profile, project, session, and
background-work behavior. The owner explicitly confirmed **Codex Remote in
ChatGPT on Android** as the mobile UI and interaction reference. Its documented
behavior is recorded in the reference note; mobile UI source availability remains
unverified. Root/project navigation screenshots were
supplied by the owner later on the same date; the UI reference note records the
approved tree layout and its priority ahead of pagination. The broader
daily-driver and indispensable-product roadmaps inherited from upstream are not
this fork owner's roadmap.

See [Desktop behavior research](HERMES_DESKTOP_BEHAVIOR_REFERENCE.md) and
[Codex Android UI research](CODEX_ANDROID_UI_REFERENCE.md) for the checked evidence
and remaining gaps. The original specification below has not yet been fully
reconciled against those references.

## 1. Purpose

Add first-class Hermes profile selection to the active Android Workspace. Selecting a profile must reload that profile's projects and sessions in the same way users experience profile selection in official Hermes Desktop, without confusing a Hermes profile with an Android saved connection.

The implementation must preserve active work: changing the visible profile does not interrupt turns running under another profile.

## 2. User-visible contract

Given one saved Android connection to a profile-aware Hermes dashboard:

1. The Workspace shows the current Hermes profile and offers a profile picker.
2. The picker lists profiles returned by that host.
3. Selecting `client-work` replaces the visible Home, Chats, Projects, Activity, search, and new-chat scope with `client-work` data.
4. Selecting `default` again restores the `default` tree with no `client-work` entries left visible.
5. New chats, resumed chats, project mutations, search, and other profile-owned actions are routed to the selected profile.
6. A turn started under `client-work` keeps running if the user switches to `default`. Its events cannot mutate `default` UI state. The user can return to `client-work` and reopen the updated session.
7. If the requested profile cannot load, the app fails closed. It must not silently send an unscoped request to the server's default profile.

## 3. Goals

- Separate host connection identity from Hermes profile identity.
- Discover profiles through the authenticated dashboard API.
- Scope every profile-owned REST and JSON-RPC operation explicitly.
- Rebuild the foreground Workspace tree when profile selection changes.
- Preserve running turns and recovery state across foreground profile changes.
- Partition persistent and in-memory state by connection and canonical profile.
- Remain compatible with older gateways through an explicit capability path.
- Add deterministic unit, widget, integration, and end-to-end coverage.

## 4. Non-goals

- Changing Hermes's sticky CLI default through `POST /api/profiles/active`.
- Reimplementing Electron's local process/gateway pool on Android.
- Reading remote `HERMES_HOME` files directly.
- Treating saved Android connections as profiles.
- Merging project or session trees from multiple profiles into one Workspace view.
- Interrupting active turns as a navigation side effect.
- Silently routing to another profile when the selected profile is unavailable.

## 5. Terminology and identity

### 5.1 Connection

A `SavedConnection` describes a host, dashboard/gateway endpoints, and authentication material. It does not identify a Hermes profile.

### 5.2 Profile

A profile is a named, isolated Hermes home on the connected host. Routing must use its canonical server-provided name, never a presentation-only label.

```dart
@immutable
class HermesProfile {
  final String name;
  final String displayName;
}
```

### 5.3 Workspace scope

```dart
@immutable
class WorkspaceScope {
  final String connectionId;
  final String profileName;

  String get storageNamespace => '$connectionId::$profileName';
}
```

`WorkspaceScope` is the minimum identity for visible Workspace state. A running turn additionally uses its session identity:

```text
TurnScope = connectionId + profileName + sessionId
```

Canonical profile names and session IDs must be encoded safely when used in storage keys; do not concatenate unescaped user-controlled values into paths.

## 6. Required server contracts

The modern path requires an authenticated Hermes dashboard that supports:

- `GET /api/profiles`
- Profile-scoped session listing/detail/history/search routes
- Profile-aware session JSON-RPC calls, including create and resume/open
- Profile-aware `projects.*` JSON-RPC calls
- Existing dashboard authentication and one-shot WebSocket ticket flow

Every profile-owned REST call carries `profile=<canonical-name>`. Every profile-owned gateway call carries `params.profile=<canonical-name>`.

`POST /api/profiles/active` is not part of the switch flow. It changes the default for later process launches and does not safely retarget a running client.

## 7. Capability model

Introduce an explicit profile capability result per connection:

```dart
enum ProfileCapability {
  supported,
  unauthenticated,
  unavailable,
  legacy,
}

class ProfileCapabilities {
  final ProfileCapability discovery;
  final bool sessionRestScope;
  final bool sessionRpcScope;
  final bool projectsRpcScope;
}
```

Capability discovery must:

1. Use the existing authenticated dashboard client.
2. Treat `401`/`403` as authentication failures, not legacy servers.
3. Treat route/method absence as an unsupported capability.
4. Preserve partial support: sessions may work when Projects RPC is unavailable.
5. Cache only a last-known result and re-probe after authentication, endpoint, or server-version changes.

Legacy mode keeps current single-profile behavior and labels the selector unavailable. It must never display a successful profile switch that the server cannot enforce.

## 8. Component architecture

### 8.1 `ProfilesRepository`

Responsibilities:

- Fetch and validate `GET /api/profiles`.
- Return canonical names and display labels.
- Preserve server ordering unless product requirements define another order.
- Reject missing, blank, duplicate, or malformed canonical names.
- Expose loading, authenticated-error, unsupported, and retry states.

### 8.2 `ProfileSelectionStore`

Responsibilities:

- Store the selected canonical profile per saved connection.
- Validate a restored profile against the latest discovery result.
- Choose a deterministic initial profile: restored valid selection, otherwise server `current`, otherwise server `active`, otherwise the first returned profile.
- Never write the server's sticky active profile.

Suggested preference namespace:

```text
workspace_profile_selection_v1_<encoded connectionId>
```

### 8.3 `WorkspaceScopeController`

Owns foreground selection and generation:

```dart
class WorkspaceScopeState {
  final WorkspaceScope committed;
  final WorkspaceScope? pending;
  final int generation;
}
```

Responsibilities:

- Begin a pending profile change.
- Validate/probe the target profile.
- Commit the target atomically only when its required session data can load.
- Increment `generation` on each switch attempt.
- Reject late foreground results whose captured generation/scope no longer matches.
- Retain the previous committed scope if the target fails.

### 8.4 Profile-scoped clients

Add a `profileName` constructor argument or required method parameter to:

- Dashboard session repository/client
- Desktop Gateway session client
- `ProjectsGatewayClient`
- Session search providers
- Message history/detail client
- Session mutation client
- Project mutation client

Prefer immutable clients bound to one `WorkspaceScope`; this makes accidental unscoped calls harder than optional method parameters.

A modern profile-scoped client must not accept an empty profile name. The legacy compatibility client is a separate explicit type/path.

### 8.5 `ProfileResourcePool`

Own long-lived resources independently of the foreground Workspace:

```text
Map<ProfileResourceKey, ProfileResources>
ProfileResourceKey = connection fingerprint + canonical profile name
```

`ProfileResources` may contain:

- Authenticated gateway connection/ticket renewal authority
- Turn recovery coordinator registry
- Running-turn index
- Profile-scoped event subscriptions
- Last activity timestamp

Changing the foreground profile releases only the screen subscription. It does not call `interrupt`, `closeAll`, or dispose resources with running turns.

Idle resources may be evicted only by a documented policy. A resource is not idle while it has a submitting, awaiting-input, reconnecting, or otherwise unsettled turn.

### 8.6 Background turn registry

Track active work by `TurnScope`:

```dart
class BackgroundTurnRecord {
  final WorkspaceScope workspace;
  final String sessionId;
  final String? clientTurnId;
  final BackgroundTurnStatus status;
  final DateTime updatedAt;
}
```

Requirements:

- Register before submitting the turn.
- Journal state transitions using the existing recovery mechanism.
- Retain ownership when screens detach or profiles switch.
- Route events only to matching scope/session observers.
- Notify on completion/failure when the owning chat is not visible.
- Remove or archive only after settlement is durably reflected in history/recovery state.
- Allow explicit stop from Activity/background-work UI, even when its profile is not foreground.

## 9. Foreground profile-switch algorithm

For a switch from scope A to scope B:

1. Allocate a new switch generation and set B as pending.
2. Freeze or snapshot any view-local navigation state for A.
3. Detach A's foreground listeners; do not stop A's running turns.
4. Build B-scoped repositories/clients.
5. Load B's required session summary and start the Projects load.
6. If required authentication/session loading fails, discard B resources if idle, clear pending state, and keep A committed.
7. If validation succeeds, atomically commit B and persist its canonical name for this connection.
8. Render only results matching B and the committed generation.
9. Continue optional B loads independently; show profile-specific partial errors when Projects or another capability is unavailable.
10. Let A's application-level turn resources live until their turns settle and normal idle eviction permits cleanup.

List fetch cancellation is optional. Correctness comes from generation/scope checks, since some transports cannot be reliably cancelled.

## 10. Profile scoping matrix

| Surface or operation | Required scope |
|---|---|
| Home digest | connection + profile |
| Chats filters/list | connection + profile |
| Session detail/history | connection + profile + session |
| Session search | connection + profile |
| New quick chat | connection + profile |
| Resume/open chat | connection + profile + session |
| Prompt/attachment turn | connection + profile + session |
| Rename/archive/pin/delete | connection + profile + session |
| Projects tree | connection + profile |
| Project detail/sessions | connection + profile + project |
| Create/rename/delete project | connection + profile + project |
| Move session to project | connection + profile + session + project |
| Activity feed | connection + profile for foreground; TurnScope for background records |
| Model/config-derived choices | connection + profile |
| Recovery journal | connection + profile + session/turn |
| Notification routing | connection + profile + session/turn |

Cross-profile moves are not supported by this feature. The app must reject attempts to combine a session from A with a project from B.

## 11. Cache and persistence migration

Existing keys such as project cache keys that use only `connectionId` are unsafe after profile support.

New keys use a versioned encoded scope:

```text
projects_cache_v2_<scopeDigest>
session_search_v2_<scopeDigest>_<setting>
workspace_ui_v1_<scopeDigest>
turn_recovery_v2_<scopeDigest>_<sessionId>
```

Migration rules:

1. Do not copy an ambiguous connection-only cache into every profile.
2. The first selected profile may import safe presentation preferences only when semantics are profile-neutral.
3. Session, project, search-result, quick-chat, and recovery data must start profile-partitioned.
4. Old caches can be deleted after successful scoped refresh or left to bounded cleanup; they must not be read in modern mode.
5. Backup/restore schemas must include selected profiles and scoped preferences without exporting plaintext secrets.

## 12. UI specification

### 12.1 Picker placement

Place the selected profile in the Workspace app bar/header where it remains visible across Home, Chats, Projects, Activity, and More. The control shows:

- Profile display name
- Loading indicator while switching
- Error affordance when discovery or target loading fails
- Optional badge indicating running background work in another profile

### 12.2 Picker behavior

- Opening the picker displays canonical/disambiguated profile labels from the current connection only.
- The committed profile remains visually selected until B commits.
- Selecting the current profile is a no-op or explicit refresh; it must not restart clients unnecessarily.
- During a pending switch, profile-owned mutation controls are disabled or remain bound clearly to the committed profile. They must never route through a half-switched scope.
- Back navigation does not revert the selected profile.

### 12.3 Background work

Activity should expose running/completed turns grouped or labelled by profile. Selecting a background item first activates its profile, then opens the matching session after the switch commits.

A completion notification deep link includes enough opaque app identity to restore the correct connection, profile, and session. If the profile is unavailable, show a scoped error instead of opening the default profile.

## 13. Error behavior

| Failure | Required behavior |
|---|---|
| Profile discovery `401/403` | Keep current Workspace; request/retry authentication |
| Discovery endpoint absent | Enter explicit legacy mode; hide or disable profile picker |
| Target profile missing | Keep previous committed profile; explain that the server no longer exposes it |
| Target session load fails | Do not commit target; keep previous Workspace |
| Target Projects RPC unsupported | Commit sessions/profile; show existing Projects-unavailable state |
| Rapid A→B→A race | Only final A generation may render or mutate foreground state |
| Old-profile turn event arrives | Journal/update old TurnScope; never paint new profile chat |
| Socket disconnect during background turn | Apply existing reconnect/recovery contract within the original profile scope |
| App process killed | On restart, restore foreground profile and recover each durable scoped pending turn supported by the gateway |
| Authorization revoked for old profile | Mark its turn disconnected/failed as supported; do not re-home it |

## 14. Security requirements

- Reuse secure credential storage and the existing dashboard authentication ladder.
- Use one-shot WebSocket tickets as currently required.
- Never log passwords, API keys, cookies, tickets, or raw credential-derived connection fingerprints.
- Treat profile names as untrusted server data for display, storage, URL encoding, and logs.
- Do not expose a dashboard to an untrusted public network merely to enable this feature.
- Fail closed on missing profile parameters in modern mode.
- Do not infer or scan profile-specific ports.

## 15. Observability

Structured diagnostics may include redacted/hashed connection identity, canonical profile name when safe, generation, method, and session ID when consistent with existing logging policy. Useful events:

- profile discovery started/succeeded/failed
- profile switch requested/committed/rejected
- stale generation result dropped
- background turn retained/settled/recovered
- profile resource created/evicted

No diagnostic should include authentication material.

## 16. Implementation sequence

### Milestone 1 — domain and discovery

- Add profile and scope models.
- Add `ProfilesRepository` and capability probe.
- Add per-connection selection persistence.
- Add picker states and tests without changing data routing.

### Milestone 2 — read-path isolation

- Add profile-scoped dashboard session reads/search/history.
- Add profile to `projects.*` calls.
- Partition caches and repositories by `WorkspaceScope`.
- Add atomic/generation-safe foreground switching.

### Milestone 3 — write-path isolation

- Scope session create/open/resume and mutations.
- Scope project mutations and session/project associations.
- Add cross-profile invariant checks.

### Milestone 4 — background continuity

- Make application turn ownership profile-aware.
- Retain active profile resources across foreground switches.
- Add Activity/profile badges, settlement notifications, and deep links.
- Add bounded idle resource cleanup.

### Milestone 5 — migration and compatibility

- Migrate safe preferences.
- Add explicit legacy/partial-capability behavior.
- Update backup/restore and connection diagnostics.
- Complete end-to-end test matrix and documentation.

Each milestone should be independently reviewable and must not claim Desktop-style parity before Milestone 5 acceptance criteria pass.

## 17. Test specification

### 17.1 Unit tests

- Profile response parsing and canonical-name validation.
- Initial-profile selection precedence.
- Scope equality, encoding, and cache namespaces.
- Required-profile rejection in modern clients.
- Generation rejection after A→B and A→B→A races.
- Partial capability mapping.
- Resource-pool idle and active-turn retention.
- Cross-profile session/project operation rejection.

### 17.2 Repository/client tests

Use one fake host with profiles A and B:

- Assert every REST route receives the selected `profile` query.
- Assert every relevant RPC receives `params.profile`.
- Return distinct session/project fixtures for A and B.
- Verify no optional/empty profile is emitted in modern mode.
- Verify auth and ticket renewal use existing flows.

### 17.3 Widget tests

- Picker loads, selects, retries, and preserves committed selection on failure.
- Switching shows no stale A rows while B is committed/loading.
- Home, Chats, Projects, Activity, search, and new-chat controls all reflect B.
- Background-work badge appears for A while B is foreground.
- Selecting A background work switches scope before opening the session.

### 17.4 Background-turn integration tests

1. Start a long-running turn under A.
2. Switch to B while the turn is unsettled.
3. Assert no `interrupt`, `closeAll`, or active-resource disposal occurs for A.
4. Deliver A events while B is visible.
5. Assert B's visible transcript/tree remains unchanged.
6. Settle A and assert its recovery journal/notification updates.
7. Switch back to A and assert the completed transcript is recoverable.
8. Repeat with a socket disconnect/reconnect where recovery is supported.

### 17.5 End-to-end acceptance

Against a real profile-aware Hermes server:

- Create uniquely named project/chat data under A and B.
- Switch repeatedly and verify strict tree isolation.
- Start an actual long turn under A, switch to B, and verify it completes.
- Restart Android and verify selected-profile restoration and data isolation.
- Exercise an older/partial server and verify honest compatibility states.
- Verify authentication failures never cause unscoped/default writes.

## 18. Definition of done

The feature is complete only when:

- The active Workspace has a first-class Hermes profile picker.
- All profile-owned reads and writes are explicitly scoped.
- Caches, persistence, UI state, and recovery are profile-isolated.
- Foreground switching reloads the selected profile's project/session tree.
- Running turns continue under their original profiles across switches.
- Late events and reads cannot contaminate another profile's UI.
- Unsupported and failure paths fail closed and are tested.
- The full focused test matrix and a real-server end-to-end run pass.
- Documentation clearly distinguishes profiles from saved connections.
