# Documentation index

## Start here

The [owner-selected product plan](PRODUCT_PLAN.md) is the current scope for this fork, recorded on 2026-09-11. It contains the accepted feature IDs, exclusions, work packages, progress, server-state policy and navigation decisions. Update it as work is delivered.

The [repository README](../README.md) describes the current implementation and setup. A planned feature must not be listed there as available before its active user flow works.

The approved [delivery sequence](DELIVERY_SEQUENCE.md) tracks implementation in small phone-testable increments, starting with draft protection and conversation reliability.

## Research preserved for future work

| Document | Purpose |
| --- | --- |
| [Desktop/Android feature analysis](HERMES_DESKTOP_ANDROID_FEATURE_ANALYSIS.md) | Source-pinned inventory and original recommendations. Its priorities are superseded by the owner's product plan. |
| [Android feature inventory](research/HERMES_ANDROID_FEATURE_INVENTORY_2026-09-11.md) | Active versus retained code at the audit baseline. |
| [Desktop chat inventory](research/HERMES_DESKTOP_CHAT_INVENTORY_2026-09-11.md) | Detailed conversation, agent control, voice and notification evidence. |
| [Desktop management inventory](research/HERMES_DESKTOP_MANAGEMENT_INVENTORY_2026-09-11.md) | Backend administration, capabilities, automation and optional-feature evidence. |
| [Feature-plan contract notes](research/FEATURE_PLAN_CONTRACT_NOTES_2026-09-11.md) | Follow-up facts about backend appearance, commands, model routes and context usage. |
| [Mobile delivery contract checks](research/MOBILE_DELIVERY_CONTRACTS_2026-09-11.md) | Activity discovery, sensitive responses, client-owned queues, steering and saved-history editing contracts. |
| [Earlier Desktop behavior reference](HERMES_DESKTOP_BEHAVIOR_REFERENCE.md) | Dated architectural evidence, especially profile ownership. |
| [Mobile AI design research](MOBILE_AI_DESIGN_RESEARCH.md) | Earlier design research, not a feature commitment. |
| [Codex Android UI reference](CODEX_ANDROID_UI_REFERENCE.md) | Prior interaction reference, not this app's requirements. |

The inventories describe their inspection dates and source commits. Do not silently rewrite them to pretend newer work existed at the audit baseline. Add a dated note or a new investigation when facts change.

## Current implementation contracts

- [App shell](APP_SHELL.md), navigation, cleanup boundary and verification.
- [Conversation foundations](CONVERSATION_FOUNDATIONS.md), durable drafts, server refresh, provider selection, session YOLO and approval controls.
- [Supervision and queues](SUPERVISION_AND_QUEUES.md), cross-profile Activity, sensitive responses, notification controls and client-owned follow-up queues.
- [Conversation actions and reading](CONVERSATION_ACTIONS_AND_READING.md), saved-message actions, side-question deliveries, phone reading improvements and the context fuse.
- [Execution, Find and Outputs](EXECUTION_FIND_AND_OUTPUTS.md), live tool/todo/reasoning views, current-chat search and scoped output retrieval.
- [Filters and projects](FILTERS_AND_PROJECTS.md), paginated unread filtering, Activity status filters and server project management.
- [Sharing and capture](SHARING_AND_CAPTURE.md), reviewed destinations, preserved drafts and Photos/Files choices, with intake recovery and Camera limits.
- [Context fullness on reopen](CONTEXT_REOPEN_FIX.md), the deferred-agent ready-event fix and regression evidence.
- [Subagent supervision](SUBAGENT_SUPERVISION.md), scoped live rosters, output and supported child controls.

- [Slash commands](SLASH_COMMAND_SUPPORT.md).
- [Answer actions and versions](ANSWER_VERSIONS.md). Its description of local version links is current implementation evidence; the product plan calls for server ownership as this feature evolves.
- [Session visibility](SESSION_VISIBILITY.md).
- [Profile switching design](PROFILE_SWITCHING_DESIGN.md) and [implementation specification](PROFILE_SWITCHING_IMPLEMENTATION_SPEC.md), read with their original baselines.
- [Request-scoped profiles ADR](adr/0001-request-scoped-hermes-profiles.md) and [background continuity ADR](adr/0002-background-session-continuity.md). These preserve ownership rules and do not authorize a separate local task database. The current product plan separately commits to a later background-notification milestone under M01/W07.

## Build, distribution and verification

- [Local build setup](LOCAL_BUILD_SETUP.md). Host paths and tool versions are dated evidence; use the actual current checkout rather than assuming an old location.
- [Android release identity and signing](ANDROID_RELEASE_PLAN.md).
- [Code quality and release checks](../CODE_QUALITY_CHECKLIST.md).
- [Windows handoff](../WINDOWS_HANDOFF.md), [Windows verification](WINDOWS_VERIFICATION.md), [device verification](DEVICE_VERIFICATION_2026-09-07.md) and [model-picker verification](MODEL_PICKER_VERIFICATION_2026-09-07.md).
- [Development log](HERMESAPK_DEVELOPMENT_LOG.md) and [changelog](../CHANGELOG.md) retain historical results. A previous passing test is not proof that a newer slice passed.

## Historical plans and audits

The following remain for provenance and useful details. Their statements of approval refer to their original author/date, not approval for the current owner's roadmap:

- [Daily-driver roadmap](ANDROID_DAILY_DRIVER_ROADMAP.md).
- [Indispensable product specification](HERMES_ANDROID_INDISPENSABLE_PRODUCT_SPEC.md).
- [Final UI draft](ANDROID_FINAL_UI_SPEC_DRAFT.md).
- [Phase-one coherence goal](ANDROID_PHASE1_COHERENCE_GOAL.md).
- [Spaces specification](ANDROID_SPACES_SPEC.md).
- [Functional UI audit](ANDROID_FUNCTIONAL_UI_AUDIT.md).
- Earlier dated plans under [plans](plans/), including the August Workspace/Chats/Projects proposals and September 6 redesign/polish notes.

Do not restore old navigation, add AI organization, adopt local Spaces, or implement unselected features merely because one of these files recommends it. The current plan deliberately allows discarding the old app's UI and unneeded implementation.
