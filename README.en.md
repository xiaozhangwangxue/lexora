<div align="center">
  <img src="public/lexora-icon-192.png" alt="Lexora icon" width="128" height="128">

  # Lexora · The Dictionary That Builds Your Vocabulary Book

  **Every lookup builds your own vocabulary book.**

  [![Release](https://img.shields.io/github/v/release/xiaozhangwangxue/lexora?style=flat-square&color=2444c8)](https://github.com/xiaozhangwangxue/lexora/releases/latest)
  [![Build](https://img.shields.io/github/actions/workflow/status/xiaozhangwangxue/lexora/build-release.yml?branch=main&style=flat-square&label=4-platform%20build)](https://github.com/xiaozhangwangxue/lexora/actions/workflows/build-release.yml)
  [![License](https://img.shields.io/github/license/xiaozhangwangxue/lexora?style=flat-square)](LICENSE)
  [![Platforms](https://img.shields.io/badge/platform-Android%20%7C%20macOS%20%7C%20Windows%20%7C%20Linux-10131d?style=flat-square)](#download-and-install)

  [Official website](https://lexora.12323456.xyz) · [Download](https://lexora.12323456.xyz/#download) · [Donate](https://lexora.12323456.xyz/donate) · [简体中文](README.md)
</div>

<p align="center">
  <img src="public/og.png" alt="Lexora — Make your words worth keeping" width="900">
</p>

---

Lexora is a bilingual dictionary for Android, macOS, Windows, and Linux that turns useful lookups into a personal vocabulary book. It offers live suggestions, bilingual senses grouped by part of speech, related words, synonyms, antonyms, examples, and collocations. Save what matters in one tap, then export a compact PDF, EPUB, editable DOCX, page images, or one long image.

> [!IMPORTANT]
> Lexora needs no account. Word lists, history, and generated PDFs stay on the device by default. Only after **Start generating** is selected are words, definitions, and examples sent to public dictionary and translation services.

## Lexora 4.0.0 release notes

<!-- release-notes:en:start -->

### Dictionary and personal vocabulary books

- Added a dedicated dictionary search with live suggestions, bilingual senses by part of speech, examples, collocations, and linked related words.
- Add or remove a result from Vocabulary Book in one tap with immediate motion and a self-dismissing confirmation.
- History now switches between generated-word and search history, with one-tap repeat searches.
- Added precise search-result text sizing, optimized by default for phone reading.
- Reorganized navigation into Words, Vocabulary Book, Generated, History, and Settings.
- Result text is selectable, and related words open in a draggable preview on double-click.
- Parts of speech include Chinese labels in both interface languages.

### Search speed and accuracy

- Search now enters the result immediately, targets the core definition within two seconds, and completes the rest in the background.
- Cloudflare edge aggregation brings in the complete English dictionary, pronunciation, parts of speech, and related content as a fast second stage.
- Chinese translation now uses edge batching while related words, examples, and phrases fill independently without serially blocking search.
- Typing prefetches English dictionary data for only the top three suggestions and warms just the first definition translation.
- Translation work is capped at two concurrent requests with progressive retries; failed responses are no longer cached.
- Completed translation cache survives a confirmed search for faster, more reliable repeat viewing.
- Fixed raw pronunciation codes by converting fallback phonetics into readable IPA.
- 4.0.0 moves suggestions into an independent overlay so typing and result completion no longer relayout the page.

### History, previews, and interaction

- Search history supports sorting, multi-select deletion, and batch book creation.
- Search history and linked words share a draggable sheet that expands, dismisses, and returns through linked results naturally.
- Double-click Words in the desktop sidebar to return home; GitHub hides as suggestions appear.
- The history header and search-history list now share a consistent layout.
- Search, dragging, state feedback, navigation, and desktop sidebar motion have been retuned throughout the app.
- Reduced-motion support keeps meaningful feedback while removing unnecessary spatial movement.

### Cross-platform stability and updates

- Fixed a macOS crash when exporting images caused by missing Photos permission descriptions.
- Reduced desktop resize jank by suspending costly sidebar motion during live resizing and restoring it naturally afterward.
- The GitHub button hides when a search result is shown so it cannot cover content.
- Fixed compressed search-result layouts and enforced a safe minimum desktop window size.
- Recentered macOS traffic-light controls in the wider collapsed sidebar.
- macOS updates open the official download, quit Lexora, and reveal Privacy & Security.
- Fixed desktop sidebar reader exit and unwanted Android keyboard popups.
- Update checks fail over across the official site, direct Cloudflare Worker, and GitHub.
- The macOS sidebar uses flush native material while interactive Liquid Glass is limited to selected controls for cheaper resizing.
- Android, macOS, Windows, and Linux builds, installation, upgrades, and download integrity are revalidated.

### Website, documentation, and diagnostics

- The website demo adapts to mobile or desktop and includes multiple interactive pages.
- The website, README, and onboarding are updated while historical downloads remain available.
- Developer mode captures detailed input, navigation, search, backend response, timing, generation, and reader diagnostics.
- 4.0.0 coalesces high-frequency scroll diagnostics off the UI thread and adds P50, P95, worst-frame, and slow-frame summaries.
- GitHub, the website, and README share the complete release notes while the app uses a concise phone-friendly version.

### 4.0.0 performance, security, and motion

- Website dragging now updates a GPU-composited transform per frame instead of rerendering the page on every pointer move.
- FLIP reordering is interruptible, while the wordmark and demo use shorter, more natural nonlinear transitions.
- Removed animated filters, background positions, top changes, and transition: all patterns that caused unnecessary work.
- Version, build, filenames, checksums, and release notes are generated from one manifest and checked before publishing.
- Updated website runtime and build dependencies to address known high-severity vulnerabilities.
- Added coverage for small-screen notes, rapid typing, live desktop resizing, reduced motion, and manifest compatibility.

<!-- release-notes:en:end -->

## Why Lexora

| 🔎 Search-engine-speed lookup | ＋ One-tap saving | ↕️ Playlist-like ordering | 📖 A finished result |
| --- | --- | --- | --- |
| History-first live suggestions and full bilingual results | Add or remove a result without a confirmation dialog | Long-press, swipe, or use four sort modes | Five polished output formats |

## Features

- **Full bilingual dictionary:** a dedicated search workspace with history-first live suggestions, multiple bilingual definitions grouped by part of speech, related words, synonyms, antonyms, examples, and collocations.
- **Search and save:** linked English terms launch a new search, while the + button adds a result to Vocabulary Book with immediate, self-dismissing feedback.
- **Fast capture:** Enter to add in Vocabulary Book, with duplicate and input validation.
- **Bulk document import:** add newline-delimited words or phrases from DOC, DOCX, PDF, TXT, RTF, ODT, and other document files.
- **Flexible ordering:** long-press to reorder, swipe left to delete, and sort by custom order, A–Z, length, or estimated difficulty.
- **Full lookup:** English definition, corpus frequency signal, US and UK phonetics, synonyms, antonyms, and examples.
- **Safe fuzzy lookup:** when no exact result exists, Lexora accepts only a highly similar spelling that also returns complete dictionary data; the results dialog marks skipped terms in red and validated matches in yellow with the word actually used.
- **Faster batches:** up to four concurrent lookups plus a 14-day on-device cache speed up long lists and repeated generation.
- **Complete Chinese layer:** definitions, examples, and related words receive Chinese translations; PDF labels are bilingual too.
- **Automatic language:** follows the device language, using Simplified Chinese on Chinese devices and English elsewhere.
- **Dual history:** switch History between generated words and past searches, then reopen any searched term in one tap.
- **Search text sizing:** precisely tune result typography in Settings; the default is optimized for phone reading.
- **First-run guidance:** introduces lookup, saving, organization, generation, and both history modes.
- **Dedicated settings:** document format, type, and example count live in Settings alongside quick website access and donation QR codes.
- **Five export formats:** print-ready PDF, standards-based EPUB, editable DOCX, page images, and one continuous long image.
- **Custom layout:** small, medium, and large type plus 0, 1, or 2–3 examples; medium uses two compact columns, sufficiently small typography switches to three, and independent column flow removes gaps between uneven cards.
- **Stable fonts:** Noto Sans SC for Chinese and IPA-complete Noto Sans for phonetics; DOCX embeds both fonts to avoid missing glyphs across devices.
- **Generated records:** pinch to zoom, read, export, share, or delete PDF, EPUB, and DOCX books, with a first-words preview in each overflow menu.
- **Word history:** sort every generated word both ways by count, first letter, time, or difficulty; starred words stay pinned.
- **Background completion alerts:** the system notifies you when generation finishes while Lexora is out of focus.
- **Native sharing:** Export to… on desktop and the system share sheet on Android.
- **Adaptive interface:** SwiftUI Liquid Glass behind macOS navigation; Android supports blank-area page swipes without stealing swipe-to-delete gestures.

## Download and install

Use the [official download section](https://lexora.12323456.xyz/#download) for binaries built by GitHub Actions on each platform’s native runner. The website detects the device platform locally and recommends the matching build without uploading device information. Files are mirrored to Cloudflare R2 so downloads do not depend on GitHub access.

| Platform | Package | Requirement | Download |
| --- | --- | --- | --- |
| Android | APK | Android 8.0+ | [Official mirror](https://lexora.12323456.xyz/downloads/lexora-android-v4.0.0.apk) |
| macOS | Drag-to-install DMG | macOS 12+ | [Official mirror](https://lexora.12323456.xyz/downloads/lexora-macos-v4.0.0.dmg) |
| Windows | Setup EXE (launch option checked by default) | Windows 10 / 11 | [Official mirror](https://lexora.12323456.xyz/downloads/lexora-windows-v4.0.0-setup.exe) |
| Linux | tar.gz | 64-bit Linux | [Official mirror](https://lexora.12323456.xyz/downloads/lexora-linux-v4.0.0.tar.gz) |

> [!IMPORTANT]
> Android v0.2.0 used an ephemeral build signature whose private key cannot be recovered. Moving to the stable v0.3.0 signing key therefore requires one uninstall and reinstall. From v0.3.0 onward, future APKs use the same release key and install directly over the existing app. Export any PDFs you need before removing v0.2.0.

Every release filename contains its version, such as `lexora-android-v4.0.0.apk`, so old and new installers remain easy to distinguish. The website keeps 3.2.5 and 3.1.0 under Previous versions, and both remain in R2. In-app updates prefer Cloudflare R2 and verify download completeness plus SHA-256 before opening an installer.

## Three steps to a vocabulary book

1. Search in **Words** and save useful results, or type/import a large batch in **Vocabulary Book**.
2. Long-press to reorder or select a sort mode, choose type and examples in **Settings**, then select **Start generating**.
3. Choose PDF, EPUB, DOCX, page images, or one long image; read, export, or share the result in **Generated**, and browse every generated word in **History**.

```text
word list → dictionary + corpus + translation → bilingual layout → PDF / EPUB / DOCX → history / export / share
```

## Data and accuracy

| Content | Source | Use |
| --- | --- | --- |
| Definitions, phonetics, examples | [Dictionary API](https://dictionaryapi.dev/) | Public English dictionary data |
| Related words, frequency signals, spelling suggestions | [Datamuse](https://www.datamuse.com/api/) | Synonym enrichment, relative frequency, difficulty estimate, and strict fuzzy matching |
| Chinese translation | [MyMemory](https://mymemory.translated.net/) | Definitions, examples, and related words |
| PDF Chinese and IPA fonts | Noto Sans SC + Noto Sans | Fetched and cached on first generation |

Difficulty is a learning-level estimate based on frequency and word shape, not an official examination level. External services may be rate-limited or unavailable; Lexora reports errors instead of inventing results. See [Data sources and privacy](docs/DATA_SOURCES.en.md).

## Run from source

Install Flutter stable and the toolchain for your target platform:

```bash
git clone https://github.com/xiaozhangwangxue/lexora.git
cd lexora/apps/lexora
flutter create --project-name lexora --platforms=android,linux,macos,windows .
flutter pub get
dart run flutter_launcher_icons
flutter run
```

The website requires Node.js 22 or newer:

```bash
cd lexora
npm install
npm run dev
```

## Support Lexora

If Lexora saves you time, you can voluntarily support cross-platform testing, data services, signing, and long-term maintenance on the [dedicated donation page](https://lexora.12323456.xyz/donate).

| WeChat Pay | Alipay |
| :---: | :---: |
| <img src="https://raw.githubusercontent.com/xiaozhangwangxue/autoword/main/assets/donate/wechat.png" alt="WeChat Pay QR code" width="260"> | <img src="https://raw.githubusercontent.com/xiaozhangwangxue/autoword/main/assets/donate/alipay.jpg" alt="Alipay QR code" width="260"> |

## Contributing and license

Issues and pull requests are welcome. Lexora is released under the [MIT License](LICENSE).

<div align="center">
  <sub>Make your words worth keeping.</sub>
</div>
