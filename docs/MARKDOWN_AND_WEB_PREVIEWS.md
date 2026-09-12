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

This delivers the hosted web page portion of F07. Downloaded interactive HTML,
integrated audio/video and other selected visual formats remain in the plan.
There is no new browser engine, Markdown renderer or production dependency.

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
