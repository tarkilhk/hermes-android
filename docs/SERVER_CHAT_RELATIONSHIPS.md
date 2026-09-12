# Server chat relationships

Owner correction, 2026-09-12: no Hermes backend modifications. Patch 0005 was an
unapproved experiment and was never deployed. Its invented version API and UI
were removed from Android in 2.30.1. Existing parent metadata and normal
Branch/Regenerate remain; explicit synchronized versions are deferred. Any
patch-specific contracts below describe the rejected experiment only.

Regenerate and Branch create durable Hermes sessions using the existing saved-row
boundary checks. Edit and the one-shot Fork action keep their existing server
operations and draft protection. A rejected regeneration returns to its source;
an uncertain submission is not automatically retried.

The old answer arrows relied on a phone-only index of related sessions. That
index was removed in 2.18.0. Startup makes a best-effort removal of only
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

Q09's synchronized answer carousel is implemented in 2.30.0 with backend patch
0005. Its explicit relationship, source answer and version order are stored on
Hermes. It never derives a version group from the generic parent link. See
[answer actions and versions](ANSWER_VERSIONS.md) for the current contract,
historical-answer navigation and deployment boundary.

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

Signed Personal 2.18.0 / 21672 passed certificate/package checks, installed in
place through wireless debugging, and launched successfully. Phone verification
covers installed version and process metadata, not private conversation behavior.
