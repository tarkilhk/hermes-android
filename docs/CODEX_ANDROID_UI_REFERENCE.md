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

The profile workspace now implements that tree, a full-projects view reached by
See all, and local search over loaded rows. All chats now requests another
50-row REST page near the scroll end, with explicit load-more and retry controls.
Project lists reveal the authoritative returned members in groups of 50; the
stock project RPC has no offset or cursor. Server-wide search is not implied by
this UI. Activity, project creation, refresh, and notification
enablement remain available in the workspace menu.

## Visual evidence still needed for other screens

The supplied screenshots establish the root and project navigation reference,
but not the conversation, approval, or output-viewer design. No pixel-level
equivalence is claimed. iOS-only releases or desktop screenshots must not silently
stand in for the missing Android screens.

A further visual comparison should cover the active conversation, composer,
approval request, output viewer and return from a notification.
