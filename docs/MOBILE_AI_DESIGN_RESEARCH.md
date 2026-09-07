# Hermes mobile interface research
Date: 2026-09-06
Audience: Hermes Android owner and implementers

## Decision

Build a compact editorial workspace, with object-attached menus and a distinct visual identity. Keep profiles, five recent projects, pinned chats, recents, and project filtering. Do not replace that working structure with a dashboard.

No source reviewed establishes one mobile AI interface as objectively best. Product documentation demonstrates conventions, not comparative usability. The ink-blue, mint and muted project-color direction is our aesthetic proposal. It must earn its place through actual phone use.

## What the evidence supports

### Familiar retrieval, more contextual actions

Gemini's Android instructions document holding a recent chat to pin, unpin, rename or delete it. Pinned chats precede other recents. This supports keeping the owner's requested organization and long-press behavior, not copying Gemini's appearance. [Google Gemini Help, date not stated](https://support.google.com/gemini/answer/13666746?co=GENIE.Platform%3DAndroid&hl=en)

Claude's Android documentation uses visible conversation overflow actions and confirms deletion. Its iOS instructions separately describe holding a chat in the list. We should provide an overflow alternative to long-press without claiming the two platforms have identical behavior. [Anthropic, Delete or rename a conversation, accessed 2026-09-06](https://support.claude.com/en/articles/8230524-delete-or-rename-a-conversation)

ChatGPT Android documents sidebar history/search and visible response actions. Chat-level commands and text selection are separate interactions. Keep search available; do not hijack transcript selection with chat-level management. [OpenAI Android FAQ, accessed 2026-09-06](https://help.openai.com/en/articles/8142208-chatgpt-android-app-faq)

Codex mobile emphasizes short check-ins across threads, projects and approvals. This makes returning to work and finding an input request more important than a decorative home dashboard. That is a product-design precedent, not controlled research. [OpenAI, Work with Codex from anywhere, 2026-05-14](https://openai.com/index/work-with-codex-from-anywhere/)

Claude project documentation describes quick access and retrieval of archived work. Its desktop/sidebar instructions are not verified Android geometry. [Anthropic project guide, date not stated](https://support.claude.com/en/articles/9519177-how-can-i-create-and-manage-projects)

Perplexity's December 2025 changelog describes user bubbles, result-type tabs and library/sidebar changes. It said mobile rollout was forthcoming. Treat it as a historical organization precedent, not evidence of today's Android appearance. [Perplexity changelog, page dated 2025-12-04](https://www.perplexity.ai/changelog/what-we-shipped---december-5th)

### Honest feedback and explicit control

Amershi and colleagues evaluated 18 human-AI interaction guidelines with 49 design practitioners across 20 AI-infused products. Clear capabilities, relevant context, correction, dismissal and understandable consequences apply directly here. This was guideline validation through heuristic evaluation, not a head-to-head test of mobile chat styles. [Microsoft Research and University of Washington, CHI 2019](https://www.microsoft.com/en-us/research/wp-content/uploads/2019/01/Guidelines-for-Human-AI-Interaction-camera-ready.pdf)

A CHI 2026 controlled study with 45 participants found benefits from planned-step and intermediate-outcome feedback compared with final-only feedback in an agentic in-car prototype. Transfer to handheld text chat is uncertain: the study combined audio and visual feedback in simulated driving. It supports investigating concise intermediate status, not constant animation or exposing every technical log. [Kirmayr et al., CHI 2026](https://www.medien.ifi.lmu.de/pubdb/publications/pub/kirmayr2026chi/kirmayr2026chi.pdf)

Ten think-aloud interviews in a fictional agent-assisted sales task found different preferences for autonomy and intervention. The small qualitative sample does not establish a universal notification cadence. For Hermes, input requests should carry context and routine progress should not have equal urgency. [Goyal, Chang and Terry, CHI EA 2024](https://arxiv.org/html/2404.04289v1)

Google PAIR recommends understandable controls and honest acknowledgement of feedback. In Hermes, pin/archive changes should reflect a server acknowledgement or a visible failure, not a cosmetic success animation detached from the result. [PAIR, Feedback + Control, precise chapter update date not visible](https://pair.withgoogle.com/guidebook-v2/chapter/feedback-controls/)

### Expression without sacrificing usability

Google reports 46 studies and more than 18,000 participants behind Material 3 Expressive. Its design rationale uses emphasis, grouping, shape, color and motion to guide attention. These are first-party research claims about its system, not proof that any bright custom theme improves Hermes. Use expression selectively in identity and the primary action; keep transcripts readable. [Google Design, 2025](https://design.google/library/expressive-material-design-google-research?pubDate=20250521)

Android recommends touch targets of at least 48 by 48 dp. Compact visual styling must not mean tiny controls. [Android accessibility guidance, accessed 2026-09-06](https://developer.android.com/guide/topics/ui/accessibility/views/apps-views?hl=en)

Flutter documents respect for system text scaling and tests for contrast and tap targets. Verify small screens with large fonts, not just default-size emulator screenshots. [Flutter UI accessibility, updated 2026-05-05](https://docs.flutter.dev/ui/accessibility/ui-design-and-styling)

## Flutter component decision

| Option | What it provides | Hermes decision |
| --- | --- | --- |
| MenuAnchor + MenuItemButton | Anchor-relative menus and keyboard activation | Good for persistent toolbars and cascading desktop-style menus. |
| showMenu + styled PopupMenuItem | Awaitable popup route, automatic screen fitting, focus, dismissal semantics and scrollable menu content | Use for current asynchronous row actions. Reuses Flutter's tested route behavior and keeps the profile-safe action code. |
| CupertinoContextMenu | Lifted preview inside a full-screen modal overlay | Useful if we choose an explicitly iOS-style experience; not an automatic Android improvement. |
| super_context_menu | Native menus on some platforms, Flutter Android menus, custom previews and drag/drop integration | Defer. Rust/native integration is more complexity than these six actions require. |
| popover | Custom popover body and positioning | Credible lightweight option, but current requirements do not require another dependency. |

Component facts: [MenuAnchor](https://api.flutter.dev/flutter/material/MenuAnchor-class.html), [MenuItemButton](https://api.flutter.dev/flutter/material/MenuItemButton-class.html), [showMenu](https://api.flutter.dev/flutter/material/showMenu.html), [CupertinoContextMenu](https://api.flutter.dev/flutter/cupertino/CupertinoContextMenu-class.html), [super_context_menu publisher documentation](https://pub.dev/packages/super_context_menu), [popover publisher documentation](https://pub.dev/packages/popover). Accessed 2026-09-06. Package claims are publisher documentation, not independent validation. Local Flutter 3.44 source was also checked before using APIs.

Material guidance allows contextual menus and recommends considering sheets for cramped layouts and long labels. A sheet is not inherently wrong. Our previous sheet's oversized presentation was wrong for this brief. The replacement must still scroll and remain usable at large text sizes. [Material menus guidance, retrieved through Android's official redirect](https://developer.android.com/guide/practices/ui_guidelines/menu_design.html)

## Integration specification

1. Replace full-width management sheets with a 260–300 logical-pixel floating menu near the selected row. Keep title/profile context, 48 dp action targets, grouped commands, separated Delete and existing confirmation.
2. Support both long-press and visible row overflow. Outside tap and Android Back dismiss without executing anything.
3. Use a workspace-scoped theme: ink-blue dark canvas, cool light canvas, mint selection/compose action, and stable decorative project accents. Keep semantic status colors separate.
4. Strengthen typography and grouping. Preserve project and chat recency, avoid adding invented summaries, counts or progress.
5. Keep known runtime spinners/checks/input signals. Unknown cross-device execution remains unknown. No backend patches or inferred ownership.
6. Retain Markdown, tool disclosure, Stop, input and approval controls. A richer contextual activity strip can be explored separately after this pass.

## Evidence gaps and validation

The owner subsequently requested explicit conversation redesign and an accent
picker. The first integration groups consecutive tool-result rows behind one
disclosure, keeps assistant answers on a clean reading surface, and uses an
accent-tinted user bubble. A local five-color preference personalizes selection
and compose controls without changing status colors. These are design choices
derived from progressive disclosure and readable hierarchy, not measured claims
that this particular arrangement is superior. Approvals and clarification stay
visible and outside tool groups.

The source review did not provide a controlled comparison of current mobile AI apps. Several product articles are textual instructions, not current Android screenshots. Perplexity mobile geometry remains unverified. Agent-feedback research has different tasks and populations from Hermes users. Palette and visual distinctiveness need owner evaluation.

Verify: long titles; small screens and large text; menu bounds and dismissal; visible overflow parity; touch target/contrast checks; profile changes around open menus; existing pagination, search, pin/archive and conversation regressions. Device screenshots check appearance, not TalkBack behavior or real-world task speed. Do not claim those without testing.

Research stopped after the principal decision families had primary support and remaining uncertainty concerned aesthetic preference, actual device behavior or server capabilities. Discovery covered official product documentation, Flutter APIs/packages, Android guidance, Google Design, PAIR and HCI papers. Follow-up resolved Android/iOS differences, Perplexity rollout uncertainty and study-population limits. The coordinator independently re-opened the two main papers, Gemini, Claude, Codex and all selected Flutter component sources.
