<div align="center">
  <img src="public/lexora-icon-192.png" alt="Lexora icon" width="128" height="128">

  # Lexora · Bilingual Vocabulary Books

  **Words in. A beautiful bilingual book out.**

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

Lexora is an English vocabulary organizer for Android, macOS, Windows, and Linux. Enter a loose word list and it enriches every item with difficulty, frequency, US and UK phonetics, synonyms, antonyms, examples, and complete Chinese translations, then typesets the result as a compact bilingual PDF.

> [!IMPORTANT]
> Lexora needs no account. Word lists, history, and generated PDFs stay on the device by default. Only after **Start generating** is selected are words, definitions, and examples sent to public dictionary and translation services.

## Why Lexora

| ✍️ Search-like capture | ↕️ Playlist-like ordering | ✦ Complete context | 📖 A finished result |
| --- | --- | --- | --- |
| Type a word and press Enter | Long-press, swipe, or use four sort modes | Phonetics, frequency, difficulty, related words, and bilingual examples | A polished PDF ready for screens or paper |

## Features

- **Fast capture:** focused search-style home, Enter to add, duplicate and input validation.
- **Flexible ordering:** long-press to reorder, swipe left to delete, and sort by custom order, A–Z, length, or estimated difficulty.
- **Full lookup:** English definition, corpus frequency signal, US and UK phonetics, synonyms, antonyms, and examples.
- **Complete Chinese layer:** definitions, examples, and related words receive Chinese translations; PDF labels are bilingual too.
- **Automatic language:** follows the device language, using Simplified Chinese on Chinese devices and English elsewhere.
- **First-run guidance:** a concise three-step tutorial introduces capture, ordering, generation, and sharing.
- **Custom PDF:** small, medium, or large type plus no example, one example, or two to three examples per word.
- **Polished PDF:** Noto Sans SC for Chinese and IPA-complete Noto Sans for phonetics, with automatic pagination and compact hierarchy.
- **Built-in history reader:** read, print, share, or delete generated PDFs without leaving the app.
- **Native sharing:** Export to… on desktop and the system share sheet on Android.
- **Adaptive interface:** bottom navigation on mobile, side navigation on desktop, and platform-aware feedback.

## Download and install

Use the [official download section](https://lexora.12323456.xyz/#download) for binaries built by GitHub Actions on each platform’s native runner. Files are mirrored to Cloudflare R2 so downloads do not depend on GitHub access.

| Platform | Package | Requirement | Download |
| --- | --- | --- | --- |
| Android | APK | Android 8.0+ | [Official mirror](https://lexora.12323456.xyz/downloads/lexora-android.apk) |
| macOS | ZIP app bundle | macOS 12+ | [Official mirror](https://lexora.12323456.xyz/downloads/lexora-macos.zip) |
| Windows | ZIP | Windows 10 / 11 | [Official mirror](https://lexora.12323456.xyz/downloads/lexora-windows.zip) |
| Linux | tar.gz | 64-bit Linux | [Official mirror](https://lexora.12323456.xyz/downloads/lexora-linux.tar.gz) |

## Three steps to a vocabulary book

1. Type an English word and press Enter; continue until the list is complete.
2. Long-press to reorder or select a sort mode, choose the font size and example count, then select **Start generating**.
3. Read the PDF in **History**, or open the menu to export and share it.

```text
word list → dictionary + corpus + translation → bilingual layout → local PDF → history / export / share
```

## Data and accuracy

| Content | Source | Use |
| --- | --- | --- |
| Definitions, phonetics, examples | [Dictionary API](https://dictionaryapi.dev/) | Public English dictionary data |
| Related words, frequency signals | [Datamuse](https://www.datamuse.com/api/) | Synonym enrichment, relative frequency, and difficulty estimate |
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
