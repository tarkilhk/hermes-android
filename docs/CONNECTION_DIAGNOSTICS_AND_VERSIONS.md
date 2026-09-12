# Connection diagnostics and versions

This is the initial D28 diagnostics and D30 version-visibility slice. It extends the existing App settings and Hermes administration screens. Selected-profile editing is documented separately. One-host backend updates are implemented below; provider billing/credit usage and remote TUI restart remain separate work.

## Diagnostics

Hermes administration offers a manual check of the selected connection/profile. Three independent results distinguish an authenticated dashboard response, configured provider credentials and whether the selected profile's provider credentials can be resolved. A successful credential check does not prove that an inference request or provider network call will succeed.

The panel reuses the modern profile gateway: a one-row `sessions` REST request, `setup.status` and `setup.runtime_check`. Each request carries the captured profile. The legacy API client's health check is not used. Errors provide address/password/network or server-credential guidance without printing raw exceptions. Manage connections opens the existing access editor. No diagnostic check submits a model prompt or changes server options.

## Version visibility

App settings reads the actual installed Android app label, package ID, version and build through the existing `package_info_plus` dependency. It does not infer the installed version from the repository or backend. **What's new** opens this fork's checked-in changelog and **Releases** opens its GitHub Releases page. These are plain distribution links; the app does not poll for a newer version or claim that a release is available.

Backend update information is a separate manual, authenticated dashboard read. An unavailable check remains unknown. One-host update controls are available after an eligibility check. Remote TUI restart and multi-host outcomes remain D30 follow-up work.

## Contract evidence

Installed Hermes revision `8d79c2ff57bba4b07e5b37ed90387b16541aef53`:

- `tui_gateway/methods_config.py:267-330`: `setup.status` reports `provider_configured`; `setup.runtime_check` reports `ok`, provider/model/source and an optional error. Both accept the selected profile. Runtime resolution checks credential availability rather than performing inference.
- `hermes_cli/web_routers/actions.py:239-291`: `GET /api/hermes/update/check` reports `current_version`, `install_method`, `behind`, `update_available`, `can_apply` and guidance. `behind: null` means the check could not run, and `-1` means the commit count is unknown. This is a dashboard route, not a WebSocket update RPC.

The Android transport's authentication, timeout and profile scope are reused. Results belong to the connection/profile that was checked and are discarded after that owner changes.

## Operations follow-up

The initial restart audit needed a correction: `POST /api/gateway/restart?profile=...` launches `hermes gateway restart` for the profile/messaging gateway. `hermes_cli/gateway.py:571-572` explicitly excludes `python -m tui_gateway` from that process matching. It must not be labeled as a restart of the connected TUI backend. No separate remote TUI restart endpoint was found in the inspected Desktop flow. Connected-backend restart remains a contract dependency; this does not reopen deferred messaging administration.

A second source audit on 2026-09-12 used official Desktop commit `d15ed4445207dda418b984e8bda0f68f48b8c6f3`. Electron starts a local backend as `hermes serve --host 127.0.0.1 --port 0` and records the child PID, process-start marker, nonce, profile and Electron-parent identity before it can stop that process. Desktop SSH mode has a separate privileged lifecycle: it starts `serve --isolated`, records an ownership ID, spawn nonce, PID, process creation time, Hermes path/home and token fingerprint on the remote host, and stops only that proven owner before reconnecting. None of that ownership is available from an Android HTTP connection, and no authenticated API for restarting the connected `serve` process exists in the inspected backend. A valid remote restart therefore needs an explicit external supervisor and control channel: the supervisor acknowledges an operation ID and old process instance, replaces the exact process it owns, then exposes a changed process instance or durable receipt so Android can prove the restart before reconnecting and resuming sessions. Builds without that supervisor must report restart unavailable. Android must not infer ownership from a reachable URL, scan or kill a process, or ask the connected server to kill or execute itself.

One-host updates have a different supported path: `POST /api/hermes/update` starts an admitted update and reports an action ID/PID or refusal. `GET /api/actions/hermes-update/status` reports process state and durable update evidence. Its receipt summary has no action ID: an old successful receipt alone cannot confirm a new request. The client must correlate status with the accepted action before claiming completion, retain partial/refused/failed outcomes, and treat a connection gap as uncertainty rather than proof of failure. No automatic POST retry is planned. This flow is implemented in 2.12.0; multi-host operations remain selected later work.

### One-host update flow (2.12.0)

The Backend version card reuses its manual eligibility check. An eligible host offers **Update backend** with a confirmation naming that host and explaining that every profile can be affected. Eligibility is checked again immediately before submission. A valid already-running acknowledgement follows the existing update instead of claiming a second update was started.

**Refresh update status** reads server progress and recent output. A matching action ID or process completion associates status with the acknowledged request. The full `hermes/update/receipt` response is an envelope containing `receipt` and `summary`; only a completed full receipt with the accepted PID supplies this request's final outcome. A summary or process exit alone must not turn an unknown outcome into verified success. Partial, refused and failed receipts remain distinct.

A fresh view can display the server's last recorded update. A view with its own lost acknowledgement cannot use an unrelated older receipt to claim that request succeeded. This distinction needs only transient request identity; it adds no local update ledger. A connection gap offers manual status refresh and never automatically repeats the update POST. No live backend update is used for development verification.

## Verification

The 2.10.0 snapshot passed 1,072 tests with four opt-in skips. Focused checks cover independent diagnostic failures, exact profile requests, replaced/disposed owners, actual manual update checks, unknown update state, installed package metadata and narrow large-text navigation. Analyzer is clean. No live provider configuration or backend update has been performed. Phone deployment is pending wireless debugging availability; the last verified installed version remains 2.8.0.

The 2.12.0 update snapshot passed 1,097 tests with four opt-in skips and a clean analyzer. Update coverage includes exact scoped requests, fresh eligibility refusals, confirmations, already-running responses, nested receipts, lost acknowledgements, late status reads, replaced owners and narrow large-text layout. No live backend update was triggered.

Deployment on 2026-09-12: the signed Personal 2.12.0 APK passed certificate/package checks, installed in place via wireless debugging, and launched. Android reported versionCode 21612 and versionName 2.12.0. Earlier deployment-pending notes above are historical. No backend update was triggered.

The multi-host follow-up is implemented in 2.16.0; see [Backend updates](BACKEND_UPDATES.md) for selection, endpoint matching, per-host outcomes and verification. Earlier follow-up notes above describe the initial 2.12.0 boundary. Remote TUI restart remains a separate backend dependency.
