# Reading PDFs

Open a PDF under **Chat actions → Outputs**, then choose **Read PDF**. Use
Previous/Next page and pinch zoom to read it. Back returns to the file options,
where **Open in app** and **Save or share** remain available.

The reader reuses the original chat's authenticated download callback and path.
It downloads once per reader opening, then asks Android's built-in `PdfRenderer`
for the current page. A failed page can be retried without downloading the file
or opening the native document again. No server edit or session setting changes.

The existing 32 MiB download limit applies. Rendering uses one page at a time,
with a bitmap no larger than 2,000 pixels on its longest edge. The initial
reader is for viewing pages; it does not add PDF editing, form filling, text
search or selection. Password-protected and unsupported PDFs can be opened in
another installed app through the existing file options.

Downloaded bytes cross the native channel without credentials, authenticated
URLs or server filenames. The renderer uses a UUID-named private cache file and
an opaque in-memory document handle. Closing the reader releases that handle,
renderer and file. An open that finishes after the reader closes is released
too. Activity destruction closes remaining documents. Old orphaned cache files
are pruned on later opens; they are not a persistent document library.

The worker serializes native PDF operations, limits open documents to three,
validates page indices/dimensions and closes each rendered page and bitmap.
It adds no package dependency, storage permission or PDF network service.

The implementation uses the API 21 `PdfRenderer.Page.render` overload. Android
fits the page to the bounded bitmap when no transform is supplied, as documented
in the [platform API reference](https://developer.android.com/reference/android/graphics/pdf/PdfRenderer.Page).

## Verification

Focused checks cover exact bytes and native handles, valid page boundaries,
malformed native responses, error messages, one-download page navigation,
retry without reopening, late-download/open cleanup and return to the original
Outputs options. The reader layout is checked at 320px with 200% text size.
These fixture checks do not establish native rendering behavior on the phone;
native compilation and live PDF reading are recorded separately.

For 2.20.0, the full Flutter suite passed 1,155 tests with four opt-in skips and
the analyzer reported no issues. Fourteen focused checks cover the new reader,
native-channel behavior and the existing Outputs actions. Native review found
no resource-lifetime or file-ownership defects.

Signed Personal 2.20.0 / 21692 passed native compilation and certificate/package
checks, installed in place through wireless debugging and launched successfully.
Phone verification covers installed version and process metadata; live PDF
rendering and gestures remain a manual check.
