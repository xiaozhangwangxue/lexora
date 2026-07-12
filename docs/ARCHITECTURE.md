# Lexora architecture

The Flutter client owns word entry, ordering, local history, PDF generation, and native share/export. `WordService` isolates external lookups, `PdfService` owns deterministic bilingual typesetting, and `HistoryService` stores only local PDF metadata.

The public website is a vinext/React application built for Cloudflare Workers. Download requests reach the worker first: it streams a matching R2 object when present and otherwise redirects to the latest GitHub Release. The release workflow builds each desktop or mobile target on its native runner, publishes immutable GitHub assets, and optionally mirrors the same bytes to R2.

No API keys are shipped in the client. Future paid dictionary or translation providers should be introduced behind a project-owned backend before adding credentials.
