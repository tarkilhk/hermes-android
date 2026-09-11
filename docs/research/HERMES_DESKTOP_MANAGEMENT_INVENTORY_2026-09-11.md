# Hermes Desktop management inventory

Audit date: 2026-09-11. Official source: `NousResearch/hermes-agent`, commit `d15ed4445207dda418b984e8bda0f68f48b8c6f3`. This is a source audit of the wired Desktop UI, not a claim that every cloud account, backend version, or external service supports every control. It covers management and auxiliary features. Chat, projects, files, artifacts, layout, and Android implementation are covered by companion audits.

Mobile relevance uses three judgments. **Core** means it directly supports common phone work or recovering interrupted work. **Useful** means it belongs in a later or advanced mobile workflow. **Low** means the desktop form should usually stay on desktop, although its outcome may remain useful remotely. These judgments are product recommendations, not upstream claims.

## Availability boundaries

- The registered core routes include Settings, Command Center, Capabilities at `/skills`, Messaging, Webhooks, Cron, Profiles, Agents, and Starmap. They are actual routed components. [Route registry][routes]
- Capabilities contains Skills, Toolsets, MCP, and Plugins. Old Settings links for MCP and Plugins redirect there; there is no separate current Skills Hub top-level tab. [Capabilities][skills], [settings redirects][moved]
- Bot Mode is a bundled plugin enabled by default. Kanban and Radio are bundled plugins disabled by default. Runtime plugins may add more routes, commands, panes, and settings, but an arbitrary user's plugin inventory cannot be inferred from this checkout. [Plugin discovery][plugins], [Kanban registration][kanban-plugin], [Radio registration][radio]
- Local model management is hidden unless the app starts with `--local`; the provider page also checks the flag. It is present but not a default feature. [Settings navigation][settings], [local models][local-models]
- Billing normally uses real gateway RPC. Its fixtures and simulated transactions are developer-only. Invoice UI is explicitly disabled. Payment and plan changes depend on backend account capabilities. [Billing][billing], [billing API][billing-api], [billing state mapping][billing-state]
- Generic configuration rows depend on the backend configuration schema. A field name in the curated definitions does not guarantee an old remote backend exposes it. Profiles and connections scope management actions; changing one must not silently apply settings to another. [Configuration renderer][config], [field definitions][constants]

## Connect to and operate Hermes backends

| Feature present in Desktop | Mobile fit | Why and suggested mobile form | Evidence |
|---|---|---|---|
| Local managed backend connection | Low | Android's primary job should be connecting to a running backend. Reproducing a desktop Python process manager adds installation, storage, and battery work. | [Gateway settings][gateway] |
| Remote HTTP/S URL connection with session token | Core | The essential connection path for an Android client. Include a saved label and clear connection state. | [Gateway settings][gateway] |
| Discover authentication scheme and open OAuth or password sign-in | Core | Private gateways must be usable without copying browser cookies or editing config files. | [Gateway settings][gateway] |
| SSH connection with host, user, port, key, remote Hermes path and profile | Useful | Important for self-hosters. An optional advanced tunnel can remove the need for public exposure; native SSH key setup is less convenient on a phone. | [Gateway settings][gateway] |
| Populate SSH hosts from local SSH configuration | Low | Desktop host discovery is OS-specific. Mobile can use explicit hosts or an imported connection instead. | [Gateway settings][gateway] |
| Hermes Cloud sign-in, organization selection, discover agents and connect to an agent | Core for Cloud users | A guided picker removes difficult endpoint and credential setup. It depends on actual Cloud account access. | [Gateway settings][gateway] |
| Saved connection registry with add, edit, rename-label, remove, search and switch | Core | A productive client needs to distinguish personal, work, local-network and cloud backends. | [Connection registry][connections] |
| Additional request headers per remote connection | Useful | Needed behind some reverse proxies or access gateways. Hide inside advanced connection settings. | [Connection registry][connections] |
| Connection test, reachable/auth status and duplicate-backend hints | Core | A phone regularly changes networks. Explain whether failure is routing, authentication or backend availability. | [Gateway settings][gateway], [connection registry][connections] |
| Save for next restart versus save and reconnect | Useful | Mobile should apply a tested connection immediately while keeping the previous working connection available. | [Gateway settings][gateway] |
| Launch against the last-used connection | Core | Reduce daily friction when reopening the client. | [Connection registry][connections] |
| Keychain-backed encryption setting and explicit unencrypted-secret fallback | Core outcome | Use Android secure credential storage. Do not copy the desktop's platform-specific toggle UI as a requirement. | [Gateway settings][gateway] |
| Gateway recovery controls reused in boot-failure UI | Core | Connection failures must be repairable from the failure screen, before normal app navigation loads. | [Gateway settings][gateway] |
| Update eligible backend connections individually or all together | Useful | An owner may need to recover an outdated gateway while away. Keep backend updates deliberate and show progress. Cloud connections can be skipped. | [Connection registry][connections], [managed updates][managed-updates] |

## Provider accounts, models and execution policy

| Feature present in Desktop | Mobile fit | Why and suggested mobile form | Evidence |
|---|---|---|---|
| Guided provider onboarding with API keys, browser authorization codes, device codes, external CLI sign-in, and model confirmation | Core for account setup | Direct key and browser sign-in are practical on mobile. External CLI instructions should remain a recovery link for the backend owner. | [Onboarding][onboarding], [providers][providers] |
| Connected provider accounts, account setup and disconnect | Useful | Restore access or change a provider while away. Display the target backend/profile before writing credentials. | [Providers][providers] |
| Search and manage provider API keys; tool/service credentials and settings credentials in separate views | Useful | Key rotation can unblock work. A mobile secret editor should be small, secure, and explicit about backend scope. | [Providers][providers], [keys][keys] |
| Custom OpenAI-compatible endpoints and provider definitions | Useful | Essential for some self-hosters, but an advanced setup path rather than the default onboarding. | [Custom endpoints][custom-endpoints] |
| Default provider and model selection, including activating an unconfigured provider inline | Core | Cost, latency and capability affect every mobile task. | [Model settings][model-settings] |
| Default reasoning effort and speed/service options when the model reports support | Core | Quick mobile requests and complex delegated jobs need different tradeoffs. Only show supported controls. | [Model settings][model-settings] |
| Auxiliary model assignments, per-task overrides, reset to main/default, and stale-provider warnings | Useful | Avoid accidental charges to an old provider or broken vision/other auxiliary tasks. Most users need a simple default. | [Model settings][model-settings] |
| Mixture-of-agents configuration, reference models, aggregator and presets | Low initially | This is real model orchestration configuration, but a large phone editor adds little to daily capture, review and steering. | [Model settings][model-settings] |
| Context-window override and fallback model list | Useful | Recover provider failures and fit a specific workload. Prefer advanced settings. | [Field definitions][constants], [model settings][model-settings] |
| Agent max steps, API retries, tool-use enforcement and service tier | Useful | A phone is well suited to changing a run budget or recovering a stuck request; detailed tuning is occasional. | [Field definitions][constants] |
| Subagent provider/model, reasoning, max iterations, concurrency and timeout | Useful | Resource limits and quality affect remote jobs. Keep basic delegation limits understandable. | [Field definitions][constants] |
| Execution backend selection, timeout, persistent shell, environment passthrough and image settings | Low as a full editor | These configure execution on the server, not Android. A status summary and named presets are more useful than exposing every container option. | [Field definitions][constants], [terminal backend panel][terminal-backend] |
| Default working directory, execution scope, file-read/output limits, checkpoint limits | Useful for advanced users | Useful to diagnose wrong workspace or truncated results. Most mobile use should select an existing project. | [Field definitions][constants] |
| Local inference runtime install/update/start/stop, hardware fit, model download/activate/eject/delete, catalog search and model sideload | Low | Hidden behind `--local`. Do not turn Android parity into a requirement to download desktop-sized models. Remote runtime status and model choice can be added later. | [Local models][local-models], [settings navigation][settings] |

## Skills, tools, MCP and plugins

| Feature present in Desktop | Mobile fit | Why and suggested mobile form | Evidence |
|---|---|---|---|
| Browse/search installed skills and read their complete instructions and metadata | Core | Users need to know what Hermes can do and which capability to invoke. | [Capabilities][skills] |
| Skill enable/disable, bulk enable/disable and disable-unused actions | Useful | Reduce irrelevant capabilities or recover an accidentally disabled skill. Bulk operations need clear scope. | [Capabilities][skills] |
| Skill usage counts and sorting | Useful | Frequently used skills make useful mobile shortcuts; usage is a selection aid rather than a dashboard priority. | [Capabilities][skills] |
| Official skill catalog and embedded Skills Hub with preview and install | Useful | Installing a relevant capability from the phone can unblock a task. Preserve provenance and readable previews. | [Capabilities][skills], [embedded Hub][hub] |
| Edit learned/local `SKILL.md`; archive learned/local skills | Useful | Fix persistent bad instructions or remove a learned capability. Bundled skills are not offered the same rewrite/archive controls. | [Capabilities][skills] |
| Browse toolsets, inspect tools and readiness, enable/disable, bulk toggles, usage counts | Core summary, Useful administration | Capability availability is needed to explain why a task can or cannot run. Detailed toggles belong under advanced settings. | [Capabilities][skills] |
| Per-toolset setup with credentials, settings, model choices, prerequisites and post-setup actions | Useful | A tool's setup should be reachable from its unavailable state. Long installation logs can remain behind a details view. | [Toolset setup][toolset-config] |
| Browser, computer-use and terminal setup panels integrated with capabilities | Useful status, Low full setup | These operate the backend or desktop environment. Mobile should show reachability and let the owner choose a working setup. | [Capabilities][skills], [computer-use panel][computer-use] |
| MCP server inventory, catalog install, configuration import and JSON/config editing | Useful | Catalog installs and imports are reasonable on mobile. Raw configuration editing should be secondary. | [MCP][mcp] |
| MCP server enable/disable, remove, probe connection and reload | Useful | Fast repair of a broken connector can unblock a mobile task. | [MCP][mcp] |
| MCP OAuth authenticate, status, discovered tool/prompt/resource counts and per-tool enable/disable | Core status, Useful administration | Access to a user's connected systems matters on mobile just as on desktop. Handle auth in a suitable browser flow. | [MCP][mcp] |
| Install MCP through a deep-link confirmation dialog | Useful | Shareable setup links can reduce phone typing, provided the requested server and permissions are clear. | [MCP deep-link dialog][mcp-link] |
| Plugin catalog and installation from Git, with agent and desktop halves shown separately | Useful agent half, Low desktop half | Backend plugins may add productive capabilities. Electron UI plugins cannot simply run as Android UI. | [Plugins tab][plugins-tab], [plugin install][plugin-install] |
| Plugin enable/disable, errors, update and rescan; install an agent half into the selected profile | Useful | Show which backend capability failed and allow a focused repair. Desktop rescanning/hot reload is not a mobile product requirement. | [Plugins tab][plugins-tab] |
| Runtime desktop plugin loading and hot reload; plugins add routes, commands and panes | Low as parity | This is an extension architecture, not a finite set of stock features. Design Android extension boundaries only when a real use case needs them. | [Plugin discovery][plugins], [routes][routes] |

## Profiles, bot identities and multi-agent work

| Feature present in Desktop | Mobile fit | Why and suggested mobile form | Evidence |
|---|---|---|---|
| Profiles list/search, create, clone, rename and delete | Core switching, Useful administration | Distinct work/personal identities need reliable selection. Creating or cloning a profile is a reasonable occasional phone task. | [Profiles][profiles], [create profile][create-profile] |
| Profile path/details and editable SOUL persona | Useful | View and correct persistent instructions without navigating the server filesystem. | [Profiles][profiles] |
| Settings apply-to profile selection | Core | A remote admin control is unsafe and confusing if the user cannot tell which profile it changes. | [Profile scope][profile-scope] |
| Bot roster with persistent canonical chat per bot/profile and previews/activity | Core if bot workflow is adopted | A contact-like interface fits mobile particularly well. The canonical forever-chat is distinct from side chats. | [Bot plugin][bots], [canonical contract][src-agents] |
| Create/edit bots, name/persona/avatar, model, SOUL, capabilities and scheduled work | Useful | Reusable specialists reduce repeated prompting. Editing long prompts and many capabilities can be advanced. | [Bot create][bot-create], [bot edit][bot-edit], [bot configuration][bot-config] |
| Roster grouping/sections and bots from multiple registered sources | Useful | A phone needs compact navigation across a small set of specialists and backends. | [Roster][roster], [bot configuration][bot-config] |
| Bot group chats, membership/name changes, disband, room messages, threaded replies and attachments | Useful | Coordinating specialists can be productive away from the desk. This is more complex than ordinary group display and should follow reliable single-agent chat. | [Bot group chat][bot-group] |
| Group activity, running/held status and stop room run | Core once group runs exist | Long-running group work needs visible progress and an immediate stop action. | [Bot group chat][bot-group] |
| Global Agents overlay shows delegation trees grouped by session, worker status, duration, tool/file/token/cost totals and recent stream rows | Core summary | A phone is a strong monitoring device. Use a compact active-jobs list with expandable workers rather than a large tree by default. | [Agents][agents] |

## Scheduled work, webhooks and task boards

| Feature present in Desktop | Mobile fit | Why and suggested mobile form | Evidence |
|---|---|---|---|
| Cron job inventory, search, state and profile scope | Core | Scheduled work continues while the phone is closed; users need a dependable place to find it. | [Cron][cron] |
| Create/edit job name, prompt, schedule presets/custom cron, delivery targets and model override | Core | Scheduling follow-ups and recurring tasks is a central mobile productivity workflow. Provide a natural schedule picker before raw cron. | [Cron][cron] |
| Automation blueprints with parameterized fields and validation | Useful | Templates reduce phone typing for common recurring jobs. | [Cron][cron], [blueprints][blueprints] |
| Multiple delivery destinations, including local and available messaging channels | Core | Results should reach the place the user can act on them. Do not assume delivery targets exist until returned by the backend. | [Cron][cron] |
| Pause/resume, run now, delete jobs and inspect recent run conversations | Core | This is useful control and review work on mobile. A run transcript should open directly into the resulting conversation. | [Cron][cron] |
| Preserve script-only jobs when editing; skip meaningless model/prompt requirements | Useful | Existing backend automations must remain manageable without being rewritten into agent prompts. | [Cron][cron] |
| Webhook service enabled state, enable action and restart-needed/restart handling | Useful | An owner can recover a disabled integration. It is less common than consuming its output. | [Webhooks][webhooks] |
| List/search webhook subscriptions, enable/disable, delete, view configuration | Useful | Quick supervision and emergency disable are good phone actions. | [Webhooks][webhooks] |
| Create webhook with description, event filters, prompt, skill list, delivery and delivery-only mode | Useful advanced | Valuable for self-hosters, but initial integration setup often needs another system's dashboard. | [Webhooks][webhooks] |
| Show generated URL and one-time secret with copy controls | Useful | Copying a setup secret into another app is a valid phone workflow. Preserve one-time handling. | [Webhooks][webhooks] |
| Kanban board, board switcher, search/filter, lanes, task creation and task movement | Useful, plugin-gated | Task triage and review fit mobile well. Kanban is bundled but disabled by default and depends on its backend plugin API. | [Kanban registration][kanban-plugin], [board][kanban-board] |
| Kanban task priority, assignee, workspace, skills, model, parent and goal-mode estimate | Useful | Capture and assign work from the phone; hide most fields until needed. | [Kanban board][kanban-board] |
| Kanban results, summaries, dependencies, comments, attachments, activity, runs and worker logs | Core if Kanban adopted | Reviewing output and adding feedback are especially suitable for mobile. | [Task detail][kanban-drawer] |
| Kanban running-worker feedback/requeue, diagnostic actions, archive and delete | Useful | Lets the user correct direction and recover failed work without returning to a computer. | [Task detail][kanban-drawer] |
| Kanban orchestration settings including orchestrator, default assignee and auto-decomposition | Low initially | Configuration of autonomous task dispatch is less frequent than reviewing and assigning tasks. | [Orchestration][kanban-orchestration] |

## Messaging channels and pairing

| Feature present in Desktop | Mobile fit | Why and suggested mobile form | Evidence |
|---|---|---|---|
| Messaging platform inventory with connected/fatal/startup-failed/disabled states | Core summary | Channel health explains missing deliveries. The platform list is backend-driven, not a static promise that every provider is configured. | [Messaging][messaging] |
| Platform enable/disable, credential and channel settings, advanced options, docs and clear-field controls | Useful | An owner may need to rotate a token or disable a noisy bot while away. | [Messaging][messaging] |
| Restart-needed notice and restart after changing channel configuration | Useful | A saved setting is not necessarily live. Keep that distinction visible. | [Messaging][messaging] |
| Pending pairing requests, approve pairing and revoke approved users | Core for shared gateways | Time-sensitive access decisions are a strong mobile use case. Show platform and user together. | [Messaging][messaging] |
| Telegram QR onboarding flow | Useful | Phone-based messaging onboarding is valuable, although a QR shown on the same phone needs an open-link or handoff alternative. | [Telegram setup][telegram] |

## Memory, learning and safety

| Feature present in Desktop | Mobile fit | Why and suggested mobile form | Evidence |
|---|---|---|---|
| Persistent memory and user-profile toggles and character budgets | Useful | Users need control over retained information; budgets can remain advanced. | [Field definitions][constants] |
| Memory provider selection, provider-specific config and connect flow | Useful | Connecting an existing memory service may be necessary for a productive client; backend installation details can remain advanced. | [Memory provider panel][memory-provider], [memory connect][memory-connect] |
| Context engine selection and automatic compression enable/threshold/target/protected-recent-message settings | Useful | Long chats are common, but sensible defaults matter more than a dense phone settings page. | [Field definitions][constants] |
| Starmap learning graph with skills/memory, time axis, timeline controls, inspection and graph sharing/import code | Low visualization, Useful inspection | The full animated spatial map competes with limited screen area. A searchable learned-items list gives more practical value. | [Starmap][starmap], [graph][star-map], [share controls][starmap-share] |
| Edit a learned skill or memory node; archive a skill; permanently delete a memory | Core | Correcting a remembered mistake is useful and should not require finding a small dot on a graph. | [Node actions][node-actions] |
| Memory usage/status and destructive reset through maintenance | Useful | Provide an explicit retained-memory management path. Prefer individual corrections before reset. | [Maintenance][maintenance] |
| Curator status, pause/resume and run-now | Useful | Users may want to stop or request automatic learning. Explain what it will change. | [Maintenance][maintenance] |
| Approval mode/timeout, command allowlist and MCP-reload confirmation | Core outcome, Useful policy editor | Mobile must reliably receive approval requests. Policy editing is occasional and should clearly identify server scope. | [Field definitions][constants] |
| Secret redaction, private-URL permissions and file checkpoint toggle | Useful | These settings influence remote agent access and recovery. They are not Android filesystem permissions. | [Field definitions][constants] |
| Browser real-profile opt-in and private/local browser routing controls | Useful remotely, Low native parity | Desktop controls a managed copy of desktop browser logins. Mobile can grant or revoke backend use without promising Android browser-profile copying. | [Field definitions][constants], [browser profile panel][browser-profile] |
| Credential vault inventory and sources, local/1Password/Bitwarden enablement and lock/unlock | Useful | A remote task may need an authorized login. Source installation and unlock availability are backend-dependent. | [Vault][vault] |
| Add/remove vault login, payment or address records; login identifier and OTP metadata | Useful later | This can unblock web tasks without posting secrets into chat, but requires a dedicated secure UX. It is not merely another API-key field. | [Vault][vault] |

## Operational visibility, usage, billing and updates

| Feature present in Desktop | Mobile fit | Why and suggested mobile form | Evidence |
|---|---|---|---|
| Command Center system status and agent/errors/gateway/desktop logs, severity selection, log text search | Useful | A short diagnostic view can explain a failure remotely. Default to actionable errors over a constantly streaming console. | [Command Center][command-center] |
| Gateway restart, Hermes update and action progress/log tail | Useful | Backend recovery from a phone is useful, but state and possible run interruption must be clear. | [Command Center][command-center] |
| Usage analytics over 7/30/90-day periods | Useful | Shows spend and workload trends without making accounting the primary mobile flow. | [Command Center][command-center] |
| Doctor, security audit, backup and debug-share with action status | Useful owner tools | Diagnostics and backups can resolve incidents while away. Sharing diagnostics is an explicit user action. | [Maintenance][maintenance] |
| Live account balance, plan, monthly cap, subscription/top-up credits and connector/model summary | Core | Prevent surprise stopped work and make remaining capacity visible. These are account/backend values, not a guaranteed measurement of every external provider bill. | [Billing state][billing-state] |
| Free-tier notice and sign-in path | Core where offered | Explain the active service level without showing unavailable payment controls. | [Billing state][billing-state] |
| Credit top-up presets/custom amount, charge confirmation/polling and step-up authentication | Useful | Can unblock work when credits run out. Actual ability depends on backend billing flags and account eligibility. | [Billing][billing], [billing API][billing-api] |
| Automatic reload enablement and threshold/target amount | Useful | Prevent interruptions for people who choose it. Do not silently activate spending policies. | [Billing API][billing-api], [billing][billing] |
| Plan catalog, upgrade portal links, preview/schedule downgrade and undo pending cancellation/downgrade | Useful | Occasional account administration can use an external portal for complex payment work. | [Billing state][billing-state], [plans][plans] |
| Payment-method portal links and actionable billing refusal/recovery states | Useful | An error must explain the real recovery path instead of looking like a broken chat connection. | [Billing state][billing-state] |
| Invoice section | Not present | `FEATURE_BILLING_INVOICES = false`; do not count a dormant heading as a shipped invoice browser. | [Billing][billing] |
| Desktop app version, update checks/download/install/restart, automatic updates and release notes | Core mobile equivalent | Android should follow its own app distribution/update flow. Backend version and app version should remain distinct. | [About][about] |
| Managed backend update progress per connection | Useful | Especially helpful when client/backend skew blocks a capability. | [Managed updates][managed-updates] |
| Desktop uninstall with selectable cleanup | Low | Use Android system uninstall/storage controls; backend data deletion is a separate operation. | [Uninstall][uninstall] |

## Personalization, voice and attention

| Feature present in Desktop | Mobile fit | Why and suggested mobile form | Evidence |
|---|---|---|---|
| Language selection, light/dark/system theme, presets and installed/marketplace themes | Core basics, Low marketplace | Accessibility and readable color modes matter. Arbitrary desktop theme import is a lower priority. | [Appearance][appearance] |
| UI scale, density, terminal font, tab strip, translucency, tint/frost/fade, bubble appearance and background | Core readable text, Low desktop effects | Honor Android font scaling and touch targets. Desktop glass and tab-strip settings do not need one-to-one copies. | [Appearance][appearance], [terminal font][terminal-font] |
| Resume last session, composer popout, intro splash, reaction style, tips/tours, hearts, tool view, collapsed reasoning and embeds | Useful selective | Resume-last-session and readable transcript controls help daily use; decorative controls can wait. | [Appearance][appearance] |
| Keybinding search/edit/reset and global Quick Entry shortcut | Low exact form, Core quick capture outcome | Replace keyboard-specific entry with Android shortcuts, share targets or widgets; physical keyboard support can be secondary. | [Keybindings][keybinds], [quick entry][quick-entry] |
| Keep-awake and F12 behavior settings | Low | Android should preserve remote jobs server-side rather than keeping the screen on to finish them. | [Configuration renderer][config] |
| Voice STT/TTS providers, provider-specific model/voice/language, automatic spoken responses, transcription options and recording limit | Core voice basics, Useful provider tuning | Dictation and listening are especially valuable while mobile. Put detailed codec and local-device choices under advanced setup. | [Field definitions][constants], [voice fields][voice] |
| Notification toggles for approval, user input, turn completion/error, background completion, credits and plugins | Core | The phone's greatest advantage is timely attention and quick action. Use Android channels and conversation deep links. | [Notification settings][notifications], [notification kinds][notification-kinds] |
| Completion sound selection/preview and test notification | Useful | Users need to verify notifications and control interruptions. | [Notification settings][notifications] |
| Pet gallery/adopt/rename/export/remove, enable and scale; generated pet flow | Low | Present in Desktop but not required for productive mobile use. A lightweight mascot can be added after core work is reliable. | [Pet settings][pets] |
| Bundled Radio plugin: presets, station search, play/pause/next, volume/mute, pinned stations, now-playing links | Low | Disabled by default. Android already has capable music apps; this does not improve Hermes task capture, supervision or review. | [Radio][radio] |
| Settings search with deep links; configuration import/export/reset | Core search, Useful backup | A growing mobile settings area needs search. Config import/reset should name the target backend/profile and be separate from app preferences. | [Settings][settings], [configuration renderer][config] |

## What is easy to overlook

The most useful mobile candidates are not the biggest desktop pages. Pending pairing approvals, correcting individual memories, pausing a scheduled job, checking a failed worker, switching a specialist bot, reconnecting an expired account, and opening a completed run all have high value on a phone. Dense backend settings, the Starmap canvas, the radio player, and the local-model downloader are substantially less important.

The audit must also keep separate concepts separate. A saved backend connection is not a Hermes profile. A bot's canonical forever-chat is not an arbitrary recent session. A provider login is not a gateway login. A desktop UI plugin is not a backend capability. A scheduled cron job is not an active delegated worker. Android should make those distinctions clear without copying Desktop's entire navigation.

## Immutable source links

[routes]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/routes.ts
[settings]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/settings/index.tsx
[moved]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/settings/moved-tabs.ts
[gateway]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/settings/gateway-settings.tsx
[connections]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/settings/connections-registry.tsx
[managed-updates]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/settings/managed-updates-section.tsx
[onboarding]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/components/onboarding/flow.tsx
[providers]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/settings/providers-settings.tsx
[keys]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/settings/keys-settings.tsx
[custom-endpoints]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/settings/custom-endpoints-settings.tsx
[model-settings]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/settings/model-settings.tsx
[constants]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/settings/constants.ts
[config]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/settings/config-settings.tsx
[terminal-backend]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/settings/terminal-backend-panel.tsx
[local-models]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/settings/local-models-settings.tsx
[skills]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/skills/index.tsx
[hub]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/skills/embedded-hub-picker.tsx
[toolset-config]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/settings/toolset-config-panel.tsx
[computer-use]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/settings/computer-use-panel.tsx
[mcp]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/skills/mcp-tab.tsx
[mcp-link]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/contrib/mcp-install-deeplink-dialog.tsx
[plugins-tab]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/skills/plugins-tab.tsx
[plugin-install]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/settings/plugin-install-modal.tsx
[plugins]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/contrib/plugins.ts
[profiles]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/profiles/index.tsx
[create-profile]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/profiles/create-profile-dialog.tsx
[profile-scope]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/settings/profile-scope.tsx
[bots]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/plugins/hermes-bots/plugin.tsx
[src-agents]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/AGENTS.md
[bot-create]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/plugins/hermes-bots/create-dialog.tsx
[bot-edit]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/plugins/hermes-bots/edit-profile-dialog.tsx
[bot-config]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/plugins/hermes-bots/profile-config.tsx
[roster]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/plugins/hermes-bots/roster-pane.tsx
[bot-group]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/plugins/hermes-bots/group-chat-view.tsx
[agents]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/agents/index.tsx
[cron]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/cron/index.tsx
[blueprints]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/cron/blueprints.tsx
[webhooks]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/webhooks/index.tsx
[kanban-plugin]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/plugins/kanban/plugin.tsx
[kanban-board]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/plugins/kanban/board.tsx
[kanban-drawer]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/plugins/kanban/drawer.tsx
[kanban-orchestration]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/plugins/kanban/orchestration.tsx
[messaging]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/messaging/index.tsx
[telegram]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/messaging/telegram-qr-setup.tsx
[memory-provider]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/settings/memory/provider-config-panel.tsx
[memory-connect]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/settings/memory/connect.tsx
[starmap]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/starmap/index.tsx
[star-map]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/starmap/star-map.tsx
[starmap-share]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/starmap/share-controls.tsx
[node-actions]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/starmap/node-context-menu.tsx
[maintenance]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/command-center/maintenance.tsx
[browser-profile]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/settings/browser-real-profile-panel.tsx
[vault]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/settings/vault-settings.tsx
[command-center]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/command-center/index.tsx
[billing]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/settings/billing/index.tsx
[billing-api]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/settings/billing/api.ts
[billing-state]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/settings/billing/use-billing-state.ts
[plans]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/settings/billing/plans-view.tsx
[about]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/settings/about-settings.tsx
[uninstall]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/settings/uninstall-section.tsx
[appearance]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/settings/appearance-settings.tsx
[terminal-font]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/settings/terminal-font-setting.tsx
[keybinds]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/settings/keybind-settings.tsx
[quick-entry]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/settings/quick-entry-settings.tsx
[voice]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/settings/voice-provider-fields.tsx
[notifications]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/settings/notifications-settings.tsx
[notification-kinds]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/store/native-notifications.ts
[pets]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/app/settings/pet-settings.tsx
[radio]: https://github.com/NousResearch/hermes-agent/blob/d15ed4445207dda418b984e8bda0f68f48b8c6f3/apps/desktop/src/plugins/radio/plugin.js
