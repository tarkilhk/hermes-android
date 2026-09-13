# Answer actions and versions

Current behavior in 2.31.8: Regenerate replaces the selected answer and subsequent
messages in the same conversation, matching official Desktop. Use Branch to
keep a separate conversation. See [Desktop parity](DESKTOP_ATTACHMENT_REGENERATION_PARITY.md).

Owner correction, 2026-09-12: **No Hermes backend modifications.** Any patch
contracts or deployment instructions described below are rejected experiments,
retained only as research. They were never deployed. Use existing Hermes APIs;
features requiring those invented contracts are deferred, not delivered. Do not
configure a new Hermes sender or deploy patches based on this document.

The invented version API and controls were removed in 2.30.1. Ordinary Branch,
Regenerate and parent navigation remain. The rest of this document records the
rejected 2.30.0 experiment.

In that experiment, answer relationships belonged to Hermes. Android kept only
the displayed server response in memory.

Branch copies the conversation through a saved answer into a new server chat.
Regenerate creates that copy and submits its original question there. The source
chat and its later conversation remain available. Ordinary Branch and the
one-shot Fork action do not create answer-version groups.

Regenerate supplies an explicit `answer_version` relationship through
`session.branch`. Backend patch 0005 records the original answer and a stable
server order. `session.answer_versions` returns current saved answer rows for
that group. A prompt fingerprint includes its canonical text and attachments;
editing a question invalidates its old membership, while regenerating the same
question can replace row IDs without losing the relationship. Unrelated parent
chats and matching transcript prefixes never imply answer versions.

Previous/Next controls appear only when the server returns multiple versions.
Selecting one rechecks the current relationship and opens that server chat.
It finds the target answer through paginated history and uses the existing
focused reading view, including when the answer is older than the latest page.
Version controls remain available there. Branch/Regenerate remain disabled in a
historical projection where the normal saved-message actions are unavailable.
Back to latest returns to the selected chat's current messages.

A profile, connection, navigation or history change invalidates an outstanding
version request. Failed discovery does not invent a local list. No version links
or answer text are persisted by this feature.

Patch 0005 targets Hermes `8d79c2ff57bba4b07e5b37ed90387b16541aef53`.
It must be deployed before the synchronized controls are available. Existing
branches made without the explicit relationship remain ordinary chats. Android
continues to expose them through Chats and server-provided Parent chat links.

Tests cover unchanged Branch arguments, Regenerate relationship metadata,
stale navigation, typed responses and Previous/Next through an older answer.
Backend tests cover explicit grouping, current row replacement, deleted/edited
members, unrelated parents and the indexed lookup for ungrouped sessions.
Release results are in the [changelog](../CHANGELOG.md).
