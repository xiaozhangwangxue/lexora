# Lexora 1.1.1 design QA

Status: passed.

References reviewed:

- `/Users/xiaozhangwangxue/Downloads/Screenshot_20260714-023149.png`
- `/Users/xiaozhangwangxue/Downloads/Screenshot_20260714-035203.png`

- PDF layout: replaced row-height alignment with independent spanning columns; compact typography selects three columns.
- Completion dialog: one horizontal action row, with an unfilled Ignore action and filled Share/Open actions.
- Settings: fixed title/GitHub header with independently scrolling settings content.
- Android chrome: translucent blurred top edge and bottom navigation treatment.
- Runtime PDF comparison: passed against the supplied Android preview. CI-generated medium and compact PDFs were rendered with macOS Quick Look at 1800 px and inspected at full resolution.
- Font coverage: passed. Bundled Noto Sans SC renders Chinese translations and IPA symbols without missing-glyph boxes.
- Flow layout: passed. Medium cards span independent two-column flows without row-height gaps; compact mode uses three columns and fits all eight QA entries on one page.
- Visual integrity: passed. No clipped cards, overlapping text, broken borders, or truncated page furniture were observed in either preview.
- Update dialog: the progress indicator is independently positioned while the status copy remains geometrically centered.
- Brand system: a Manrope-based Lexora wordmark now appears on Home, Settings, and the website; the existing app icon remains in the website's upper-left navigation.
- Website desktop QA: passed at 1440 × 1000. Final capture: `output/playwright/website-after-desktop-v1.1.1.png`.
- Website mobile QA: passed at 390 × 844. The two Chinese headline lines remain intentional and unbroken. Final capture: `output/playwright/website-after-mobile-v1.1.1.png`.
- Recommended download: passed on macOS Chrome at desktop and 390 px mobile width. Detection runs locally, the matching build is promoted above all versions, official platform brand icons replace text symbols, and the existing installation-warning dialog remains in the download path. Final captures: `output/playwright/website-device-recommendation-desktop-v1.1.1.png`, `output/playwright/website-device-recommendation-mobile-v1.1.1.png`.
- Lookup feedback: failed terms use a red close marker; validated fuzzy matches use an amber close marker and show the accepted word in parentheses.

The v1.1.0 PDF artifacts from GitHub Actions run `29278438792` remain the baseline because v1.1.1 does not alter PDF layout.
