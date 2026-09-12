# Markdown and web previews

Markdown files in **Chat actions → Outputs** open formatted, using the same
headings, tables, code blocks and Mermaid viewer as chat replies. The toolbar's
**Show source** button exposes the original preview text and its copy control;
**Show preview** returns to formatted reading. A server truncation notice stays
visible in both modes. Save or share retrieves the full file through the
original chat's authenticated download callback.

Non-binary previews qualify by Markdown MIME type, language or `.md`/`.markdown`
filename. Ordinary text/code and binary file options keep their existing
behavior. Images remain explicit tap-to-load previews. Relative links are not
silently resolved against the phone or the Hermes server.

HTTP/HTTPS links in replies and Outputs open the installed browser's full-screen
preview, with its title and close/back control. Android uses Custom Tabs where
available; an unavailable or failed preview falls back to an external browser.
A Custom Tab provider disappearing between the capability check and launch
can also trigger the existing launcher's WebView fallback.
A failure to open either displays an error. The helper rejects non-web schemes,
missing hosts and URL user information, and passes no Hermes authentication
headers. The browser may use its own existing website login state.

This delivers the hosted web page portion of F07. Downloaded interactive HTML
is added in 2.24.0 below; audio/video playback was added in 2.22.0. There is no
new browser engine, Markdown renderer or production dependency.

## Downloaded interactive HTML — 2.24.0

For an HTML file in Outputs, **Open HTML** downloads the original file through
the selected chat's authenticated connection and opens the shared web preview.
The truncated text preview is never used as the interactive document. Source,
Back and Save or share remain available. Files larger than 1 MiB or unreadable
as UTF-8 receive an explanation with the Save or share alternative.

Self-contained HTML can run inline JavaScript and CSS and display embedded
images. A fresh iframe permits scripts but has an opaque origin, no parent
document access, storage, native bridge or Hermes credentials. Parent and child
content policies, plus native WebView interception, block external web
resources, navigation, forms, workers and nested frames. Temporary frames are
removed when replaced or closed. CDN-dependent pages should be opened through
Save or share in an appropriate app; no authenticated resource proxy is added.

This is a document sandbox, not a guarantee of complete network isolation:
WebRTC ICE/data-channel networking is not covered reliably by the WebView
request interception and content-policy controls. No server secrets or bridge
are exposed to the document.

Browser fixtures exercise a working counter, denied parent/storage access,
external script/image/fetch blocking even with a permissive source meta policy,
standards mode, size limits and replacement cleanup. Flutter checks verify full
authenticated bytes, source access, duplicate/late download handling and size
rejection. Native WebView interaction remains a live phone QA item.

The 2.24.0 full suite passed 1,173 tests with four opt-in skips, and analysis was
clean. Signed Personal 2.24.0 / 21732 compiled, passed certificate/package checks,
installed in place wirelessly and launched. The phone check verified installed
identity and process metadata; HTML interaction was exercised in the authored
browser fixture, not in a private phone document.

## Verification

Focused tests cover formatted file display, exact source copy, truncation,
detection, binary exclusion, web URL validation, browser preview selection,
external fallback and failure handling. Existing chat rendering and PDF/file
actions are checked alongside the extraction of the shared Markdown widget.
Installed-browser behavior and live result reading remain manual phone checks.

For 2.21.0, all 41 focused checks passed, the full suite passed 1,161 tests with
four opt-in skips, and the analyzer reported no issues.

Signed Personal 2.21.0 / 21702 passed native compilation and certificate/package
checks, installed in place through wireless debugging and launched successfully.
The phone check verified version and process metadata, not private web content.
