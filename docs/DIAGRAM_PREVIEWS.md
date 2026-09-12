# Diagram previews

Open a completed Mermaid code block with **Open diagram**. The phone creates
one viewer for that diagram, with pinch zoom, light/dark appearance and
**Show source** for selecting or copying the original code. Back returns to
the same chat. Streaming and unfinished blocks retain their source view.

The renderer is the Mermaid 11.16.1 browser bundle, matching the renderer version
in the pinned Desktop audit. Android serves three bundled assets to a dedicated
WebView at a synthetic HTTPS origin. No server connection, authenticated URL,
credential or remote rendering service is involved. The view is disposed on
close; it does not persist conversation state.

This implements the Mermaid portion of T04/D12. Other diagram formats retain
the existing selectable source fallback. Previews are limited to 50,000 source
characters and 500 edges. Embedded media, links and custom configuration
directives are disabled. Parse failures show a readable error with source still
available. This is a diagram viewer, not the separately planned F07 interactive
HTML preview.

The native view has no JavaScript interface to app functions. It denies file,
content and network loading, external navigation, windows, downloads and device
permission requests. Only the exact bundled HTML and two JavaScript asset URLs
receive local responses. The shell enforces a content security policy and uses
Mermaid strict mode without binding diagram click handlers.

References checked during implementation:

- [Mermaid strict mode](https://mermaid.js.org/config/schema-docs/config-properties-securitylevel.html).
- [Android local web content](https://developer.android.com/develop/ui/views/layout/webapps/load-local-content).
- [Chromium interception order](https://chromium.googlesource.com/chromium/src/+/refs/heads/main/android_webview/browser/network_service/aw_proxying_url_loader_factory.cc#394)
  and [network blocking](https://chromium.googlesource.com/chromium/src/+/refs/heads/main/android_webview/browser/network_service/net_helpers.cc).
  HTTPS requests can receive an intercepted local response while network fallback
  remains blocked. This source check does not replace live device verification.

## Vendored renderer

`android/app/src/main/assets/diagrams/mermaid.min.js` is copied without changes
from `dist/mermaid.min.js` in the npm `mermaid@11.16.1` tarball. It is 3,566,058
bytes before APK compression and has SHA-256
`18327bef70d96fb505fe7287d9f6a7362ebf07ff6576ddfaffb1a06f3e1a2954`.
Its embedded third-party notices are retained. The accompanying Mermaid MIT
license and the license of its bundled DOMPurify 3.4.0 are included in the same
directory. No Flutter dependency was added.

To update the bundle, obtain an explicitly reviewed version with `npm pack`,
copy its standalone browser bundle and licenses, update the hash/version here,
and rerun the browser, Flutter and native build checks. Do not replace the
bundle with a CDN URL.

## Verification

The seven focused Flutter checks pass, covering existing Markdown reading,
deferred platform-view creation, exact source delivery, source switching,
size/streaming fallback and return navigation at 320px and 200% text size.
`node scripts/test-diagram-preview.mjs` exercises the actual bundled renderer
in an isolated headless Chrome profile using synthetic diagrams. Set
`CHROME_PATH` when Chrome is installed elsewhere. The harness uses Playwright
Core as a development-only tool. Install it with
`npm install --prefix build/diagram-vendor --no-save --ignore-scripts playwright-core@1.58.2`,
or set `PLAYWRIGHT_CORE_PATH` to an existing installation.

The full suite passed 1,147 tests with four opt-in skips, and analysis is clean.
Flutter's telemetry connection failed after the first clean analysis report;
rerunning with `--suppress-analytics` exited successfully. This did not require
an application change.

The real browser checks passed for flowchart, sequence and pie rendering,
visible labels, dark appearance, rejected links/configuration and parse errors.
The synthetic flowchart screenshot was visually inspected. Signed Personal
2.19.0 / 21682 passed native compilation and package/certificate checks,
installed in place wirelessly and launched. Phone evidence covers version and
process metadata; live WebView gestures remain a manual check.
