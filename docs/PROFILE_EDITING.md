# Selected-profile editing

D29 adds the small B14/B15 administration slice in 2.11.0: open Hermes administration, then the edit icon next to the selected profile. The editor shows the connection/profile it owns and edits only the description and SOUL text.

Saving changes those fields on the central Hermes server. Switching the client's selected profile still changes only client navigation. There is no global profile activation, local server-setting override, or provider/tool/skill configuration editor in this slice.

## Server contract

Installed backend revision `8d79c2ff57bba4b07e5b37ed90387b16541aef53`, `tui_gateway/methods_profiles.py:400-428,563-580`:

- `profiles.describe {name}` returns profile identity, description and SOUL content. SOUL is text from `SOUL.md`, not a file path to submit.
- `profiles.configure {name,description?,soul?}` changes only supplied sections. Its `applied` map reports each field independently, with top-level `ok` reflecting all requested sections. Description is trimmed by the server; SOUL is written exactly.
- These two fields have no server conflict revision or special confirmation requirement. The existing profile-discovery check runs before a write. The backend's model-cost confirmation belongs to model/provider changes, outside this editor.

Desktop's SOUL editor uses the same describe/configure requests in `apps/desktop/src/plugins/hermes-bots/profile-config.tsx` at pinned revision `d15ed4445207dda418b984e8bda0f68f48b8c6f3`. Android uses the field RPC for description as well, rather than adding Desktop's CLI wrapper.

## Editing and recovery

Requests retain the original gateway and profile. Only edited fields are submitted. The editor waits for acknowledged outcomes and refreshes authoritative values, preserving any requested field the server did not apply. An unrelated server change must not turn an untouched field into a new client edit on retry.

A lost acknowledgement is reported as an unconfirmed save, without automatic resubmission. Unsaved edits remain visible; closing asks before discarding them. Back, drag and barrier dismissal cannot hide a pending save. The editor does not persist a separate local profile configuration. Concurrent writers are last-write-wins for these backend fields; no client-only revision scheme is introduced.

## Verification

The 2.11.0 snapshot passed 1,080 tests with four opt-in skips and a clean analyzer. Seven focused editor checks cover acknowledged/partial/uncertain saves, empty-field edits, preserved unrelated central changes, pending-save dismissal, captured ownership and narrow keyboard layout. The admin navigation test opens the editor for the selected profile. No live profile or SOUL has been changed during development verification. Phone deployment remains pending wireless debugging availability.
