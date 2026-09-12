# Connection diagnostics and versions

This is the initial D28 diagnostics and D30 version-visibility slice. It extends the existing App settings and Hermes administration screens. Profile editing, provider billing/credit usage and backend restart/update operations remain separate deliveries.

## Diagnostics

Hermes administration offers a manual check of the selected connection/profile. Three independent results distinguish an authenticated dashboard response, configured provider credentials and whether the selected profile's provider credentials can be resolved. A successful credential check does not prove that an inference request or provider network call will succeed.

The panel reuses the modern profile gateway: a one-row `sessions` REST request, `setup.status` and `setup.runtime_check`. Each request carries the captured profile. The legacy API client's health check is not used. Errors provide address/password/network or server-credential guidance without printing raw exceptions. Manage connections opens the existing access editor. No diagnostic check submits a model prompt or changes server options.

## Version visibility

App settings reads the actual installed Android app label, package ID, version and build through the existing `package_info_plus` dependency. It does not infer the installed version from the repository or backend.

Backend update information is a separate manual, authenticated dashboard read. An unavailable check remains unknown. Applying an update, restarting a backend and multi-host outcomes remain D30 follow-up work.

## Contract evidence

Installed Hermes revision `8d79c2ff57bba4b07e5b37ed90387b16541aef53`:

- `tui_gateway/methods_config.py:267-330`: `setup.status` reports `provider_configured`; `setup.runtime_check` reports `ok`, provider/model/source and an optional error. Both accept the selected profile. Runtime resolution checks credential availability rather than performing inference.
- `hermes_cli/web_routers/actions.py:239-291`: `GET /api/hermes/update/check` reports `current_version`, `install_method`, `behind`, `update_available`, `can_apply` and guidance. `behind: null` means the check could not run, and `-1` means the commit count is unknown. This is a dashboard route, not a WebSocket update RPC.

The Android transport's authentication, timeout and profile scope are reused. Results belong to the connection/profile that was checked and are discarded after that owner changes.

## Operations follow-up

The initial restart audit needed a correction: `POST /api/gateway/restart?profile=...` launches `hermes gateway restart` for the profile/messaging gateway. `hermes_cli/gateway.py:571-572` explicitly excludes `python -m tui_gateway` from that process matching. It must not be labeled as a restart of the connected TUI backend. No separate remote TUI restart endpoint was found in the inspected Desktop flow. Connected-backend restart remains a contract dependency; this does not reopen deferred messaging administration.

One-host updates have a different supported path: `POST /api/hermes/update` starts an admitted update and reports an action ID/PID or refusal. `GET /api/actions/hermes-update/status` reports process state and durable update evidence. Its receipt summary has no action ID: an old successful receipt alone cannot confirm a new request. The client must correlate status with the accepted action before claiming completion, retain partial/refused/failed outcomes, and treat a connection gap as uncertainty rather than proof of failure. No automatic POST retry is planned. This flow is the next D30 subdelivery; multi-host operations remain selected later work.

## Verification

The 2.10.0 snapshot passed 1,072 tests with four opt-in skips. Focused checks cover independent diagnostic failures, exact profile requests, replaced/disposed owners, actual manual update checks, unknown update state, installed package metadata and narrow large-text navigation. Analyzer is clean. No live provider configuration or backend update has been performed. Phone deployment is pending wireless debugging availability; the last verified installed version remains 2.8.0.
