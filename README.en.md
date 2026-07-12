# Lexora

English · [简体中文](README.md)

> Words in. A beautiful bilingual book out.

Lexora is an open-source English vocabulary organizer for Android, macOS, Windows, and Linux. It enriches a loose word list with difficulty, frequency, US and UK phonetics, synonyms, antonyms, examples, and Chinese translations, then turns it into a compact, polished PDF.

![Lexora icon](public/lexora-icon-192.png)

## Features

- Add words from a focused, search-like home screen by pressing Enter.
- Long-press and drag to reorder; swipe left to delete.
- Sort by custom order, alphabet, word length, or estimated difficulty.
- Fetch definitions, corpus frequency signals, phonetics, related words, and examples online.
- Add Chinese definitions and example translations automatically.
- Typeset a bilingual PDF designed for reading on screen or paper.
- Open PDFs from History; export or share on desktop and use the native Android share sheet.
- Adapt navigation, density, window layout, and interaction feedback to each platform.

## Repository layout

```text
apps/lexora/       Flutter client for all four platforms
app/               Lexora website (React / vinext)
worker/            Cloudflare Worker and R2 download proxy
.github/workflows/ Multi-platform builds, GitHub Releases, and R2 mirroring
docs/              Architecture, sources, and privacy notes
```

## Run the client

Install Flutter stable and the toolchain for your target platform.

```bash
cd apps/lexora
flutter create --project-name lexora --platforms=android,linux,macos,windows .
flutter pub get
dart run flutter_launcher_icons
flutter run
```

## Run the website

Node.js 22 or newer is required.

```bash
npm install
npm run dev
```

## Data and limitations

The current version uses Dictionary API for dictionary entries, Datamuse for related words and public corpus frequency signals, and MyMemory for Chinese translation. The `printing` package caches the PDF font on demand. Third-party services can be rate-limited or temporarily unavailable; Lexora reports failures instead of inventing dictionary data. See [docs/DATA_SOURCES.en.md](docs/DATA_SOURCES.en.md).

## Releases

Pushing a `v*` tag builds Android, Linux, Windows, and macOS packages on their native GitHub runners. With `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`, and `CLOUDFLARE_R2_BUCKET` configured, release files are mirrored to R2 and served through the website’s `/downloads/*` endpoint.

## License

[MIT](LICENSE)
