# Opening output files

Open a PDF, audio or video file from a chat's **Outputs** view, then choose
**Open in app**. Hermes downloads the file through the original authenticated
connection and asks Android to open it with a compatible installed viewer.
**Save or share** remains available when no viewer is installed. This is a
document/media handoff. Since 2.20.0, PDFs also offer **Read PDF** for in-app
pages and zoom; see [PDF reading](PDF_READING.md). Integrated audio/video
playback remains separate work.

The existing 32 MiB download limit applies. Unsupported files retain their
existing preview/save/share behavior. Opening is explicit, duplicate taps are
disabled during delivery, and a preview closed during download cannot launch a
viewer when that download later completes. The native bridge also checks that
the activity is still active immediately before launching the viewer.

Android receives the downloaded bytes, filename and supported MIME type. A
background write creates a UUID-named file in the app's private output cache.
FileProvider grants temporary read access to that file only. No backend password,
cookie, header or authenticated URL is passed to the viewer. Old cache files
are pruned by age and count; the cache is not a local file library.

The existing FileProvider exposes only the new `delivered_outputs/` cache
subdirectory for this feature. The bridge permits PDF and common audio/video
types, rejects invalid/oversized payloads, and returns safe errors. It adds no
storage permission, viewer dependency, platform query or background service.

Verification for 2.17.0: the full suite passed 1,139 tests with four opt-in skips.
The six usage-panel checks passed after the owner's thousands-separator polish,
and analysis is clean. File delivery checks cover exact bytes and MIME, invalid
payloads, unavailable viewers, safe errors and closing during download. Actual
viewer behavior on the phone remains a manual check.

Signed Personal 2.17.0 / 21662 passed certificate and package checks, installed
in place through wireless debugging, and launched successfully. Deployment
evidence is package/process metadata; no private output was opened for QA.
