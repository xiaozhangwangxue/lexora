# Lexora architecture

The Flutter client owns word entry, ordering, local history, PDF generation, and native share/export. `WordService` isolates external lookups, `PdfService` owns deterministic bilingual typesetting, and `HistoryService` stores local PDF metadata plus aggregate generated-word counts, timestamps, difficulty, and star state.

The public website is a vinext/React application deployed directly as the `lexora-official` Cloudflare Worker. A zone-level Worker Route owns every `lexora.12323456.xyz/*` request, so the production request path does not depend on ChatGPT.site. Download requests reach the worker first: it streams a matching `autoword-downloads` R2 object when present and otherwise redirects to the latest GitHub Release. The release workflow builds each desktop or mobile target on its native runner, publishes immutable GitHub assets, and optionally mirrors the same bytes to R2.

No API keys are shipped in the client. Future paid dictionary or translation providers should be introduced behind a project-owned backend before adding credentials.
