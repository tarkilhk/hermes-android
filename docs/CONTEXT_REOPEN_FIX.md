# Context fullness when reopening a chat

The owner reported on 2026-09-12 that the border-integrated fuse remained empty
when opening an existing chat. Its placement and endpoint dot are accepted.

## Cause and change

The installed Hermes backend source at revision
`8d79c2ff57bba4b07e5b37ed90387b16541aef53` revealed the missing sequence. A cold
`session.resume` restores the transcript and returns before constructing the
agent. `session.context_breakdown` deliberately does not wait for that build;
with no agent yet, it can return a zero context limit. After construction, Hermes
emits `session.info`. Its usage may still omit context fields because no provider
turn has run in that process. A fresh breakdown request can now compute the
server's estimate from the restored history, prompt and tools.

Android requested the breakdown after loading history but did not request it
again on that ready event. The fuse could consequently stay unknown until a
message was sent. From 2.5.0, a non-lazy `session.info` for an idle chat triggers
another breakdown read. The existing runtime and generation guards reject a
late pre-ready response. There is no polling loop, provider request, local token
estimate, or extra graphical row.

Source evidence: installed backend `tui_gateway/methods_session.py`
(`_session_method`, `_resume_cold`, `session.context_breakdown`),
`tui_gateway/server.py` (`_schedule_agent_build`, post-build `session.info`,
`_session_info`) and `agent/context_breakdown.py` (`context_usage_fields`,
`compute_session_context_breakdown`). This supplements the earlier Desktop-only
audit; it is not a claim that the owner's remote server runs this exact revision.

## Verification

The regression opens a saved chat with history, returns the backend's initial
zero-limit response, emits the ready event with no measured context fields, and
asserts 30% estimated occupancy without any `prompt.submit`. It failed with
`null` before the change and passed after the change. A second test releases the
old zero-limit response after the ready response and checks that it cannot erase
the newer fullness.

Release validation and phone installation are recorded in
[the delivery sequence](DELIVERY_SEQUENCE.md).

## Live verification

On 2026-09-12, Personal 2.31.1 opened the previously affected large chat with an
empty composer and immediately displayed 57% context fullness. No prompt was
submitted. Opening Outputs and returning preserved the populated indicator and
the original chat. This closes the reported live D15 regression for that chat;
it does not establish context behavior for every provider or server version. See
the [live phone acceptance record](LIVE_PHONE_ACCEPTANCE_2026-09-12.md).
