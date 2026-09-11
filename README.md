# Hermes Android

A personal Android client for a remote [Hermes Agent](https://github.com/NousResearch/hermes-agent), focused on finding work, continuing conversations, supervising agents and using their results from a phone.

This is the `tarkilhk/hermes-android` fork. Its current interface and roadmap are independent of the inherited application's UI. Existing code can be reused or replaced according to the selected plan.

## Product plan and research

The [owner-selected product plan](docs/PRODUCT_PLAN.md) is the source of truth for what we intend to build. It records the feature selections, exclusions, incremental work packages and progress. Planned features are not claims about the current app.

The direction is a left hamburger menu for Chats, cross-profile Activity and occasional settings/administration. Hermes owns work state; the phone preserves unsent drafts and uses server refresh to recover current history and status. Broad backend administration is a later, small start that can grow. Voice, bots, Cron/messaging/webhook administration, offline history and a general filesystem browser are outside the initial scope.

The [Desktop/Android comparison](docs/HERMES_DESKTOP_ANDROID_FEATURE_ANALYSIS.md) and [source inventories](docs/README.md#research-preserved-for-future-work) preserve the research behind the decisions. The [documentation index](docs/README.md) distinguishes current contracts from historical plans.

## Current implementation

The current connection flow opens `ProfileWorkspaceScreen`. Implemented features include:

- Saved connections, modern dashboard/gateway validation, profile discovery and switching.
- Separate profile-owned conversations and running work, with reconnect and server-history refresh.
- Projects, recent and pinned chats, paginated session/history loading, full-text conversation search, and an option to include automated chats.
- Rename, pin/unpin, explicit read/unread, archive/unarchive, delete and move-to-project actions with server-side constraints.
- Streaming conversations, selectable Markdown/code, basic tool activity and Stop.
- Per-chat model and reasoning selection; a searchable flat model list currently shows provider identifiers.
- Dynamic slash-command discovery, aliases, argument completion, skill dispatch, and dedicated current-session actions including steering and side questions.
- Branching at saved answers, regeneration and answer-version navigation. Version grouping is currently stored locally and is a known mismatch with the planned server-owned behavior.
- Phone file attachments, Android share/launcher intake, allow-once/deny and structured clarification.
- Local completion/input notifications with original host/profile/chat routing, plus configuration restore from the connections screen.

Some features in the previous README exist only in older, currently unconnected screens. Native voice, broad settings, Cron, Memory, Files, full export/share and rich event handling must not be assumed available in the active workspace. See the [Android source inventory](docs/research/HERMES_ANDROID_FEATURE_INVENTORY_2026-09-11.md) for precise limits.

A command appearing in the gateway catalog does not prove correct support for every client or session. Terminal-only, messaging-only and host-microphone commands have platform restrictions. The follow-up audit also records a current `/yolo` routing/availability gap; see [contract notes](docs/research/FEATURE_PLAN_CONTRACT_NOTES_2026-09-11.md).

Remote work and phone notification delivery are separate. The app can reload server results when reopened. Its local notification implementation does not establish alerts after Android terminates the process. Reliable background notifications are a committed later roadmap milestone; the initial release may ship without push. Durable drafts, more complete server-backed Activity and server refresh on return are also selected work, not completed claims. Session state remains on Hermes.

## Connect to Hermes

The active app requires a modern Hermes dashboard with profile and session APIs and an authenticated Desktop Gateway WebSocket endpoint. It does not fall back to the old unscoped API-only chat flow.

1. Run Hermes on the backend machine and make its dashboard and gateway reachable from the phone, for example on the same LAN or an existing private network.
2. Add a connection with a label and host. The current form defaults to dashboard port `9119`; use the actual port for your deployment.
3. Supply dashboard credentials if required. Advanced fields support a dashboard path prefix, proxy-authenticated access and an explicit Desktop Gateway URL.
4. Save. The app tests profile discovery, gateway connection and session listing before accepting the connection.
5. Select the intended profile and open a chat or project.

Reverse proxies must route both HTTP requests and the WebSocket connection correctly. Gateway authentication is distinct from the model-provider credentials stored on Hermes. If setup fails, check the host/port/path, credentials and server capabilities rather than following the inherited API-key/SSE instructions.

The app's current slash/profile contracts and any separately maintained backend fixes are documented in [slash command support](docs/SLASH_COMMAND_SUPPORT.md) and the [profile design](docs/PROFILE_SWITCHING_DESIGN.md). Do not assume that a newer Android APK supplies a missing server API.

## Version and application identity

Source version on 2026-09-11 is `2.1.1+2144` in [pubspec.yaml](pubspec.yaml). This is the checked-out version, not a claim that a matching public release has been published.

- Personal release package: `com.tarkilhk.hermes.android`, labelled Hermes Personal.
- Development package: `com.hermesagent.hermes_android.dev`.
- The inherited upstream package is separate and is not this fork's release identity.
- ABI-split codes derive from the base build number; the current ARM64 split uses `21442`.

The [release plan](docs/ANDROID_RELEASE_PLAN.md) and [build configuration](android/app/build.gradle.kts) document identity, signing and version-code rules. The selected S08 work will expose this client's version/build and update information in the app, separately from the backend version.

## Development

Use an installed Flutter SDK compatible with [pubspec.yaml](pubspec.yaml), Java 17 and the configured Android SDK. The [local build notes](docs/LOCAL_BUILD_SETUP.md) contain environment-specific setup and dated verification results; use the actual checkout path on your machine.

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

Device/live gateway checks are separate from the ordinary test suite. Follow the relevant feature's contract document for its opt-in integration tests.

Personal release builds use [scripts/build-personal-release.ps1](scripts/build-personal-release.ps1) and the separate signing identity. Keep signing material outside Git. Complete [CODE_QUALITY_CHECKLIST.md](CODE_QUALITY_CHECKLIST.md) before a release; do not change signing identity or publish an APK as part of unrelated feature work.

## Main implementation paths

| Path | Responsibility |
| --- | --- |
| [lib/main.dart](lib/main.dart) | Saved connections, app wiring, credentials and notification navigation |
| [Profile workspace](lib/core/screens/profile_workspace_screen.dart) | Current conversation UI and composer |
| [Workspace browser](lib/core/screens/profile_workspace_browser.dart) | Profiles, projects, chats, search and Activity entry |
| [Workspace controller](lib/core/services/profile_workspace_controller.dart) | Profile/chat ownership, commands, active work and reconciliation |
| [Profile gateway](lib/core/services/profile_gateway.dart) | Scoped HTTP/RPC operations |
| [Attachment service](lib/core/services/attachment_draft_service.dart) | Staging, validation and upload |
| [Product plan](docs/PRODUCT_PLAN.md) | Selected scope and delivery record |

The older `WorkspaceScreen`, `ChatScreen` and related screens are retained implementation history. Their existence does not establish current user-facing support or oblige this fork to keep their design.

## Provenance and credits

Forked from [rusty4444/hermes-android](https://github.com/rusty4444/hermes-android). The [changelog](CHANGELOG.md), [notice](NOTICE.md) and Git history preserve inherited work and attribution.

Contributors to the inherited application include CarlosReyesPena for the daily-driver workspace edition, CristianGCiocoi for Remote Gateway integration, AI-Guru and grunjol for review/testing and proxy work, louquillio for session-source filters, and sternbergm for password-protected dashboards. This fork's new roadmap does not diminish those contributions.

License: MIT. See the repository's license/provenance material and upstream history.
