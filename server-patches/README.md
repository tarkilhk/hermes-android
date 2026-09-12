# Coordinated Hermes backend patches

These changes run on Hermes, separately from the Android APK. They target
`NousResearch/hermes-agent` commit
`8d79c2ff57bba4b07e5b37ed90387b16541aef53`.

| Patch | Purpose |
| --- | --- |
| 0001 | Set TCP_NODELAY on the pinned messaging API's SSE transport |
| 0002 | Scope command catalog, completion and dispatch to the requested profile |
| 0003 | Authenticated mobile registration, shared event IDs and Firebase sending |
| 0004 | Recover pending sensitive request metadata through resume/session info |
| 0005 | Persist explicit answer-version relationships and resolve current rows |
| 0006 | Recover live-session side tasks and expose running counts to Activity |

Apply these files in numerical order to a matching, reviewed backend checkout.
Check each patch immediately before applying it, since later patches use the
earlier contracts. An APK upgrade does not apply any of them. If upstream already
includes a change or the checkout differs, review that difference before applying.
Keep the existing process ownership and deployment method when restarting Hermes.

The exact six repository artifacts applied sequentially to a fresh copy of the
pinned source and passed 106 combined tests on 2026-09-12. That verifies the patch
series, not deployment to the owner's server. The installed backend was unchanged
during this validation.

Patch 0003 additionally needs the owner's Firebase project and trusted server
credentials. It stores installations per profile while reading Firebase setup
from the process's host configuration. See
[background notification setup](../docs/BACKGROUND_NOTIFICATIONS.md).

Patch 0004 restores only unanswered, unexpired requests still owned by a live
server session. Patch 0006's task list also lasts only for that live session.
Neither recreates work after the server itself restarts. Patch 0005 stores its
explicit relationships in the server database and validates the canonical
question before reusing them. See [request recovery](../docs/SENSITIVE_REQUEST_RECOVERY.md),
[answer versions](../docs/ANSWER_VERSIONS.md) and
[side-task recovery](../docs/SIDE_TASK_RECOVERY.md).

These patches do not add a remote TUI process restart API. That operation needs
an explicit external supervisor; the messaging-gateway restart route is different.
