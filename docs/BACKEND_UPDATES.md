# Backend updates

The **Backend updates** button in the Connections toolbar opens the saved-host
update view. Nothing is selected or contacted automatically. Select the hosts
to check, use **Check selected**, then **Update selected** when every selected
host confirms eligibility. The confirmation lists their labels and dashboard
addresses and explains that updates affect all profiles on each host.

Each host reuses the existing update controller and card. Eligibility is checked
again immediately before submission. An inaccessible or refusing host does not
erase another host's result. Use **Refresh selected status**, or the individual
card's status action, to read progress and completed receipts. Partial, refused,
failed and unconfirmed outcomes remain distinct. The phone does not automatically
retry an update request or run a background update service.

Selecting a different saved connection with the same dashboard endpoint replaces
the earlier selection. This lets the user choose credentials deliberately while
avoiding duplicate batch submissions to the same configured endpoint. Matching
uses the actual dashboard scheme, lowercase host, effective port and path-prefix
joining rules. Separate prefixes and aliases stay separate; the client cannot
infer physical-server identity through DNS or matching credentials.

The view captures the connection list and credentials when opened. Controllers
and transports are released when it closes. Updates already accepted by Hermes
continue on the server. Reopening can read the server's last recorded outcome;
it does not reconstruct a local operation ledger or claim that an old receipt
confirms a lost acknowledgement.

## Scope and evidence

The installed `hermes_cli/web_routers/actions.py` update/check/status/receipt
routes operate on the host installation and do not accept a profile parameter.
The view reuses the captured `ProfileGateway` REST path without profile discovery
or a WebSocket connection. `desktopGatewayUrl` is a WebSocket override and is
not used as the dashboard update target.

Remote TUI restart is still a backend contract dependency. The messaging gateway
restart endpoint is not a substitute and remains outside this feature. See
[connection diagnostics and versions](CONNECTION_DIAGNOSTICS_AND_VERSIONS.md)
for the verified one-host contracts and receipt rules.

Verification for 2.16.0: 1,132 tests passed, four opt-in skips, clean analyzer. Thirty focused screen/card/navigation checks cover selected-only writes, exact endpoint deduplication, fresh eligibility refusal, partial outcomes, late closing, external controller ownership and 320-pixel layout at 200% text. No live backend was updated.
