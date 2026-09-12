# Server chat relationships

Regenerate and Branch create durable Hermes sessions using the existing saved-row
boundary checks. Edit and the one-shot Fork action keep their existing server
operations and draft protection. A rejected regeneration returns to its source;
an uncertain submission is not automatically retried.

The old answer arrows relied on a phone-only index of related sessions. That
index and carousel are removed. Startup makes a best-effort removal of only
`answer_versions_v1_*` preferences; no draft or queue keys are removed, and the
obsolete links are never read again. Server conversations remain available in Chats.

**Chat actions → Parent chat** appears when Hermes supplies a nonblank
`parent_session_id`. An acknowledged branch may also supply its source as
`parent`; the client accepts that only when it matches the source session.
Navigation keeps the original connection and profile. This is disposable server
metadata, not a new local relationship store. An explicit null removes the parent;
an omitted field can retain already received server metadata.

Parent does not mean previous answer: Hermes also uses parent sessions for other
relationships. The app does not infer siblings from matching transcript prefixes,
scan session pages as a complete version list, or assign version numbers locally.

Q09's synchronized answer carousel remains selected. It needs a server contract
identifying the origin answer row, relationship kind and stable sibling order or
a relationship endpoint. The inspected backend stores parent identity but does
not expose that complete contract.

Contract evidence: installed Hermes revision
`8d79c2ff57bba4b07e5b37ed90387b16541aef53`,
`tui_gateway/methods_session.py` (`session.branch` and persisted parent
metadata), and the dashboard session-list response retaining `parent_session_id`.
The original Desktop audit remains pinned at
`d15ed4445207dda418b984e8bda0f68f48b8c6f3`.

Verification for 2.18.0: 31 focused checks passed, followed by the full suite
with 1,143 passed and four opt-in skips; analysis is clean. Checks cover saved-row boundaries,
original-profile navigation, drafts, obsolete-key cleanup, rejected/uncertain
regeneration, restart lineage, omitted versus explicit-null metadata, and the
Parent chat menu. Live server/phone relationship behavior remains a manual check.
