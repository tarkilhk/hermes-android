# Execution, Find and Outputs — 2026-09-12

This delivery implements the active D14 reading paths, D18 Find, and the first D16/D17 output flows. It uses the existing gateway and HTTP client, tool/reasoning parsers, file transport, Markdown and Android share dependencies.

## Execution details

Live tool calls now update by server tool ID, with expandable arguments/results, progress, errors and server-reported duration. Generating is a name-only status. Raw payload display is capped at 12,000 characters. A successful server history refresh removes completed live rows to avoid showing the same call twice beside stored tool results.

Server todo snapshots populate a read-only task panel. The client recognizes pending, in-progress, completed and cancelled statuses, preserves simple parent indentation and rejects older revisions. Create/resume can restore `todo_state`; no local todo database or task editor was added.

Reasoning events feed a collapsed disclosure. Historical reasoning is displayed when the server returns one of the verified string fields. The app does not invent timings or reconstruct reasoning absent from history. General tool output remains plain selectable text; there is no terminal, Git client or custom UI for each tool.

## Find in chat

The chat actions menu contains Find, Outputs and Refresh. Find fetches the selected chat's saved history once, then filters locally as the query changes. Results expand to selectable text. At most 100 results are displayed, with the full matching count reported. Closing the sheet preserves the transcript's reading position. Failure and retry remain visible.

Find and Outputs share an oldest-first server loader, in pages of 500, including compacted rows. The loader stops with an explicit error on malformed/repeated pages, a different returned chat, or its limits of 10,000 rows / 32 MiB of JSON characters. It does not label an incomplete history as complete or save another transcript on the phone. The ordinary paginated conversation remains available for larger histories.

## Per-chat Outputs

Outputs follows Desktop's transcript-derived approach. It finds assistant-delivered MEDIA tags, links/images and qualified paths, plus explicit producer-tool output fields. It recognizes common documents, archives and media; explicit references may use relative filenames. Passive tool cache/source paths are excluded where possible. Candidates are deduplicated within the one selected chat and remain disposable.

This is a useful index of references, not an authoritative server output catalog: it can miss silent outputs or retain a path whose file was removed. The UI describes that limit. It does not scan other chats or expose a filesystem browser.

File reads and downloads include the original `profile` and durable `session_id` on the authenticated host connection. Downloads enforce a 32 MiB limit against declared and streamed size. The client uses the modern download route, strips server filenames to decoded basenames, writes user-requested files to temporary staging, and hands actual file bytes to Android's share/save flow. Credentials stay on the existing authentication path.

Images use the zoomable preview, including authenticated bytes and embedded data images. Text/code use the existing selectable code renderer with a shortened-preview indication when Hermes reports truncation. Binary formats can be saved/shared for another Android app to open. Web links open explicitly in the browser. Backend-local HTML remains source text; interactive HTML and specialized audio/video/PDF viewers are not completed here.

## Verification and remaining work

Release source: Personal `2.2.0+2149`, ARM64 code `21492`. Analyzer clean; full suite 970 passed, four opt-in skips. Final build/phone results are recorded in the delivery sequence. Focused tests cover event ownership, tool upserts, todo revisions, reasoning, saved-history pagination and failure, Find expansion/count/retry, output extraction, authenticated scope, filenames, byte limits, preview navigation and actual delivered bytes. Output layouts are checked at 320 pixels and 200% text size.

Live behavior on the owner's gateway still needs verification. The pinned Desktop source establishes request shapes, not whether the deployed server exposes them or how it resolves every relative/tilde path. No Firebase integration, broad administration, global output registry or extra backend compatibility path was added.
