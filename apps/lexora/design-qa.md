# Lexora 1.1.0 design QA

Status: passed.

Reference reviewed: `/Users/xiaozhangwangxue/Downloads/Screenshot_20260714-023149.png`.

- PDF layout: replaced row-height alignment with independent spanning columns; compact typography selects three columns.
- Completion dialog: one horizontal action row, with an unfilled Ignore action and filled Share/Open actions.
- Settings: fixed title/GitHub header with independently scrolling settings content.
- Android chrome: translucent blurred top edge and bottom navigation treatment.
- Runtime PDF comparison: passed against the supplied Android preview. CI-generated medium and compact PDFs were rendered with macOS Quick Look at 1800 px and inspected at full resolution.
- Font coverage: passed. Bundled Noto Sans SC renders Chinese translations and IPA symbols without missing-glyph boxes.
- Flow layout: passed. Medium cards span independent two-column flows without row-height gaps; compact mode uses three columns and fits all eight QA entries on one page.
- Visual integrity: passed. No clipped cards, overlapping text, broken borders, or truncated page furniture were observed in either preview.

Verified artifacts from GitHub Actions run `29278438792`: `qa-pdf-preview.pdf` and `qa-pdf-preview-small.pdf`.
