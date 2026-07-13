# Lexora 1.1.0 design QA

Status: blocked pending the remote Flutter build.

Reference reviewed: `/Users/xiaozhangwangxue/Downloads/Screenshot_20260714-023149.png`.

- PDF layout: replaced row-height alignment with independent spanning columns; compact typography selects three columns.
- Completion dialog: one horizontal action row, with an unfilled Ignore action and filled Share/Open actions.
- Settings: fixed title/GitHub header with independently scrolling settings content.
- Android chrome: translucent blurred top edge and bottom navigation treatment.
- Runtime screenshot comparison: blocked because this Mac workspace has no Flutter or Dart SDK, and the GitHub build could not be started after the local Git operation was denied by the current Codex usage limit.

The production PDF previews are wired into the Linux CI job as `qa-pdf-preview.pdf` and `qa-pdf-preview-small.pdf`; visual sign-off should be completed from those artifacts before tagging the release.
