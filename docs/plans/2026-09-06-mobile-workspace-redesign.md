# Mobile workspace redesign

Research: [Mobile AI interface research](../MOBILE_AI_DESIGN_RESEARCH.md).

## Scope and constraints

Redesign the profile workspace and management menus. Preserve the owner's
profiles → five recent projects → pinned → recents structure, production API
behavior, pagination and profile ownership. Do not patch Hermes, mutate
production chats for testing, or add compatibility layers.

## Progress

- [x] Research first-party mobile conventions, HCI evidence and Flutter options.
- [x] Reconcile evidence and limitations; choose compact object-attached menus.
- [x] Implement and verify the first editorial workspace design.
- [x] Inspect authored previews in light/dark themes.
- [x] Install the normal build on the phone and inspect its workspace/menu.
- [x] Restore the emulator's normal APK with saved data preserved.
- [ ] Gather the owner's visual feedback during everyday use.

Research and implementation verification are complete. The appearance remains
a proposal for the owner to evaluate. Full suite: 1,050 passed, two opt-in live
tests skipped. Analysis is clean.

## First pass

The owner expanded the scope to the conversation and a device-local accent
picker. Consecutive tool results now belong in a compact disclosure group;
never collapse user/assistant prose, questions or approvals into that group.
Retain all underlying history rows, copying, Markdown, Stop and paging anchors.
Offer Mint, Iris, Glacier, Coral and Gold. Status meanings and colors stay fixed.

Use Flutter's popup route rather than a full-width ListTile sheet. Preserve the
async profile-safe command handlers. Include a visible overflow alternative,
context header, grouped commands, separated deletion, focus, Back/outside-tap
dismissal, and reduced-motion handling.

Introduce an isolated ink/mint workspace theme, stronger left-aligned title,
stable project accent colors, quieter chat rows, and a single bottom search and
compose dock. Keep fonts responsive and targets at least 48 dp. Do not infer
connection health from decorative dots or fill empty space with fake AI content.

The first project spans the width; the next four use a two-column tile layout.
Their existing recency order is unchanged. Narrow screens and large system text
use a vertical list. This is a visual proposal, not a research-proven improvement
over the owner's original five-row reference.

## Acceptance

- Existing profile, project, search, paging, mutation and conversation tests pass.
- Menus open through both gestures and visible buttons; cancel is read-only.
- Long titles, 2x text and narrow screens remain usable without render overflow.
- New palette has readable foreground/background contrast in both themes.
- Phone and emulator receive normal app builds with saved data preserved.
- No claims of measured usability superiority, untested TalkBack support or
  universal cross-device activity detection.

## Subsequent candidates

Evaluate the project tiles against the owner's five-project list reference in
daily use. Explore a contextual input-needed strip
using only owned runtimes. Test real task flows with the owner before adding
swipe shortcuts, animation-heavy previews or another menu dependency.
