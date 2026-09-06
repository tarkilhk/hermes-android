# Codex on Android as a UI and behavior reference

Research date: 2026-09-06. The fork owner explicitly confirmed **Codex Remote in ChatGPT on Android** as the mobile UI and interaction reference, alongside Hermes Desktop. This does not adopt the original Hermes Android roadmap or introduce a Codex backend dependency.

## Verified product and source availability

OpenAI documents Codex access on Android through **Remote in the ChatGPT mobile app**. Remote connects to a Mac or Windows desktop host; availability can vary by rollout. This is the product the owner confirmed, rather than a separate Android application named Codex. [Official Remote documentation](https://learn.chatgpt.com/docs/remote-connections)

The official open-source inventory identifies the Codex CLI, SDK and App Server as public components. It does not identify an Android/mobile UI repository. Therefore an open-source mobile UI implementation has **not been established** by this research; the public Codex engine should not be presented as the source for the Android interface. This is a documentation finding, not proof that no mobile source exists anywhere. [Official open-source inventory](https://learn.chatgpt.com/docs/open-source)

## Documented mobile behavior

Remote supports starting or continuing host project chats, steering active work, responding to questions and approvals, inspecting results/diffs/tests/terminal output/screenshots, receiving completion or attention notifications, and changing hosts or chats. The execution environment remains on the connected host. Host unavailability is distinct from an empty project or chat. [Official Remote documentation](https://learn.chatgpt.com/docs/remote-connections)

## Proposed application to this fork

These are design recommendations derived from the owner's references, not claims that each control has been observed in the Android app:

| Surface | Target for Hermes Android |
| --- | --- |
| Workspace entry | Show the current host and Hermes profile clearly. Keep connection setup separate from choosing a profile. |
| Session navigation | Let users find and resume existing profile-owned work quickly, with visible running, attention-needed and completed states. |
| Conversation | Prioritize the transcript and composer; expose agent/tool detail progressively so long work stays readable on a phone. |
| Active work | Support follow-up and approval interactions where Hermes provides the corresponding server contracts. Changing visible sessions or profiles must preserve ongoing work. |
| Review | Present returned files, images, code and execution results in phone-appropriate viewers. Rich diff review requires a verified Hermes contract before being promised. |
| Notifications | Return users to the exact owning host, profile and session. Distinguish an unreachable host from finished work. |

Hermes Desktop defines Hermes profile, session and execution semantics. Codex on Android supplies the requested mobile interaction reference. Keep Hermes identity and existing modern profile-aware server contracts; copying the OpenAI account/pairing system or connecting to Codex is outside this direction.

## Owner-supplied Android screenshots, 2026-09-06

The owner supplied `Screenshot_20260906_164646_ChatGPT.jpg` and
`Screenshot_20260906_164703_ChatGPT.jpg` and explicitly prioritized this UI pass
before pagination. The screenshots remain local references and are not copied
into the repository because they contain the owner's conversation titles.

The first shows a compact selector above one vertically scrolling list, with
Projects, Pinned chats, and Recents sections. Rows are flat, with generous touch
targets, folder outlines for projects, single-line chat titles, and trailing
relative timestamps. Search and new-chat controls stay at the bottom. The second
shows a project title, host context, a back control, and only that project's chats.

The owner's requested adaptation uses Hermes profiles in the top selector, the
five most recently active projects, pinned chats without duplicate recent rows,
and recent chats sorted by activity. Entering a project uses authoritative Hermes
project membership. Switching profiles reloads the entire tree and returns to
the new profile's root. The implementation retains Hermes branding and its gold
accent; it does not copy OpenAI account, voice, or pairing controls.

The profile workspace now implements that tree and a full-projects view reached by
See all. Root search queries profile-wide message content and chat IDs, including
archived chats, and supplements those results with loaded title matches. The
stock server does not search all titles or provide a search cursor; the UI
labels its 100-server-match limit. Project search filters the returned project
members, while the full-projects view filters project names.
All chats requests another
50-row REST page near the scroll end, with explicit load-more and retry controls.
Project lists reveal the authoritative returned members in groups of 50; the
stock project RPC has no offset or cursor. Activity, project creation, refresh, and notification
enablement remain available in the workspace menu.

## Visual evidence still needed for other screens

The supplied screenshots establish the root and project navigation reference,
but not the conversation, approval, or output-viewer design. No pixel-level
equivalence is claimed. iOS-only releases or desktop screenshots must not silently
stand in for the missing Android screens.

A further visual comparison should cover the active conversation, composer,
approval request, output viewer and return from a notification.

## Conversation readability pass, 2026-09-06

The owner approved Markdown/code/link rendering, collapsed tool output, a better
composer, clearer streaming status, and a jump-to-latest control. The conversation
now puts the chat title above the host/profile selector, uses a right-aligned
literal-text user bubble and full-width assistant Markdown, and reuses the
existing code block copy/wrap component. Tool output starts collapsed and remains
plain text when expanded. Approval and input requests stay directly actionable.

The rounded multiline composer keeps attachments in a horizontal strip, disables
empty sends, and allows drafting while a turn runs. During that turn, its action
is Stop, not an implied queued send. Human-readable status text distinguishes
sending, working, writing, attention, reconnecting, and history refresh. Latest
returns to the newest row without dropping loaded history. Scrolling the
transcript dismisses the keyboard.

Links open externally only after a tap and only for http/https URLs without
embedded credentials. Images render as explicit link controls rather than
automatically fetching remote content or opening host paths on the phone.
Remote file previews remain separate future work.

`integration_test/profile_conversation_preview.dart` supplies labelled authored
content for emulator visual inspection without connecting to Hermes. It is not
imported by the normal app. This pass follows the approved mobile direction but
does not claim pixel equivalence with a Codex conversation screenshot, which the
owner has not supplied.

## Color, row actions and activity, 2026-09-06

The owner requested color accents and Desktop-inspired long-press actions.
The workspace now uses warm gold profile selection and section labels, softly
tinted folder icons, and the existing theme's rounded search and action controls.
Light and dark themes retain the same layout and hierarchy.

Long-pressing a project offers New chat in project. Chat sheets offer Rename,
Pin/Unpin, Mark as read/unread, Copy ID, Archive/Unarchive, and confirmed Delete.
Archived chats are reachable from the workspace overflow menu. The captured
profile owns each action even if navigation changes before a request completes.
Branch, Export, Move to project, Appearance, and Desktop's New window are not
implemented by this pass.

Known runtimes show a blue working spinner, amber input request, green completed
check, red failure, or reconnect/stopped icon. Tooltips and accessibility labels
identify states without relying on color; reduced motion disables spinning.
Unread rows have a dot. REST `is_active` means recent activity, not proof of an
active turn. The stock `session.active_list` response has no profile ownership,
so Android does not use it to assign precise states to unopened chats. Its
potentially duplicate durable IDs cannot safely identify those owners.

## Research-led workspace and conversation redesign, 2026-09-06

The owner rejected the preceding menu treatment and requested a more distinctive
design, conversation improvements, and a selectable accent. The implementation
now supersedes the warm-gold/full-width-sheet description above. Research and
its limitations are recorded in [Mobile AI design research](MOBILE_AI_DESIGN_RESEARCH.md).

Management actions use compact, row-attached Flutter popup menus with a visible
overflow alternative to long-press. Commands and production behavior are unchanged.
The workspace has an ink-blue dark theme, a cool light theme, stronger typography,
decorative project tiles and a unified search/compose dock. The five projects
retain their order, with a vertical-list fallback for narrow or large-text layouts.

Mint, Iris, Glacier, Coral and Gold accents are device-local preferences, available
through workspace options or the conversation palette button. They do not alter
semantic activity colors. Consecutive tool results share a collapsed disclosure;
assistant prose, approvals and clarification requests remain outside that group.
Expanded results stay selectable plain text. User bubbles use the selected accent.

Light/dark authored conversations and menus were inspected on the emulator. The
normal workspace and a safely dismissed chat menu were inspected on the owner's
Samsung phone. This is a proposed visual direction, not a measured usability
improvement or pixel copy of a current Codex conversation.
