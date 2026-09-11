# Supervision and queues — 2026-09-12

This delivery covers D05, D07, D08 and D09 from the selected product plan. D06 approval controls shipped with the conversation foundations. Desktop contract evidence and backend gaps are recorded in [mobile delivery checks](research/MOBILE_DELIVERY_CONTRACTS_2026-09-11.md).

## Delivered behavior

- Activity discovers ongoing sessions independently in each profile on the current connection. Rows retain their original owner. Failed profiles are reported separately; a failed refresh does not present stale rows as current. Missing titles use a short session ID, with at most one metadata page fetched per profile.
- Sudo, secret and vault requests use dedicated forms and exact response methods. Expiry clears only the matching request; duplicate submissions are guarded. Credentials are not saved in drafts, logs or conversation messages.
- Completion and attention notifications have independent switches. Chat titles are optional and off by default. A permission-and-test action sends a synthetic notification; notification taps retain their existing host/profile/chat routing.
- Message actions, also reachable by holding Send/Stop, offer Queue and Steer without changing the normal button action. Queues hold text-only unsent messages, scoped to the original chat and saved in the existing draft store. Users can review/remove entries and explicitly resume a paused queue.
- Queues submit one item at a time after a completed turn. Sending a queued item preserves separately typed text and attachments. A persisted paused marker precedes submission, so an acknowledgement lost during a restart cannot cause an automatic repeat. Stop, failure or uncertainty pauses the remaining work. Steer checks the server's queued/rejected result and preserves rejected text.

## Verification

- `flutter analyze --no-pub`: no issues.
- `flutter test --no-pub --reporter expanded`: 921 passed, four opt-in integration tests skipped.
- Focused checks include partial Activity discovery and original ownership, request identity/expiry, six sensitive-form widget tests, notification settings, queue order/restart/uncertainty/stop/resume, and composer action sheets at large text sizes.
- Release source: Personal `2.1.4+2147`, ARM64 code `21472`. Build/deployment result is recorded in the delivery sequence.

No dependencies changed. This delivery reuses the existing gateway, draft store, notification service and submit path. Release notes are recorded here rather than rewriting the inherited changelog. No public APK release is implied.

## Remaining limits

The pinned Desktop source and mock-backed tests establish client behavior; they do not verify the owner's deployed gateway. That live gateway was unavailable from the local Desktop test setup. End-to-end sensitive responses and notification permission/tap behavior still need phone/backend verification.

Hermes continues accepted work independently, but the phone must be connected to drain its unsent queue. Opening a chat refreshes server state before draining a restored queue. Reliable terminated-app notifications remain D26/D27; no Firebase integration was added. The inspected resume response does not expose pending sudo/secret/vault metadata after process death.

Attachment queueing and local answer-version schema changes are outside this slice. Conversation history and execution remain server-owned.
