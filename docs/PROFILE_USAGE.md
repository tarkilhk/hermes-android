# Profile usage

Hermes administration offers a manual **Load usage** action for the selected
connection/profile. It reads the last 30 days from Hermes and can be refreshed.
The phone keeps no usage ledger and makes no provider billing requests.

The overview shows session count, API calls, input/output tokens, estimated cost
and reported cost where available. Missing or invalid numbers stay Unknown.
Hermes can return zero reported cost when a provider has reported no costs;
unreported costs are excluded, so this is not an account balance or final bill.

The optional model breakdown includes auxiliary model calls, as returned by the
server. Overview totals come from session rows; the client does not recompute
them from the model breakdown. Costs are displayed in USD.

The captured profile gateway supplies `GET analytics/usage` with `days=30` and
the selected profile. Switching owners discards the old result, and late reads
cannot populate a different profile. Errors offer manual retry without exposing
raw server details. There is no polling or local analytics database.

Source evidence is recorded in
[mobile delivery contracts](research/MOBILE_DELIVERY_CONTRACTS_2026-09-11.md).

Verification for 2.13.0: 1,103 tests passed, four opt-in skips, clean analyzer. Six focused widget checks cover profile scoping/manual reads, cost labels and unknown values, malformed responses/manual retry, replaced/disposed owners and 320-pixel layout at 200% text.

Deployment: included in signed Personal 2.14.0 / 21632, installed and launched on the owner's phone on 2026-09-12.
