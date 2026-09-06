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

## Visual evidence still needed

The fetched official Remote page documents behavior and desktop connection controls; it did not provide a verified Android screen sequence suitable for measuring navigation, spacing, typography, composer placement or gestures. No pixel-level Android resemblance is claimed here. Before a faithful UI pass, inspect the owner's actual Android reference or a first-party Android demonstration and record the version and screens. iOS-only releases or desktop screenshots must not silently stand in for Android evidence.

A useful visual comparison should cover the session list, active conversation, composer, approval request, output viewer and return from a notification. Until then, the table above is a behavioral brief rather than a finished visual specification.
