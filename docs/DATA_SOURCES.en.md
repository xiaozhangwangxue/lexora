# Data sources and privacy

Lexora makes network requests only after the user selects **Start generating**. Requests contain the English words entered by the user and the dictionary definitions or examples that need translation.

- `dictionaryapi.dev`: English definitions, phonetics, examples, and some related words.
- `api.datamuse.com`: related words and public corpus frequency signals.
- `api.mymemory.translated.net`: Chinese translations of definitions and examples.
- `fonts.google.com`: Noto Sans SC is fetched and cached when a PDF is generated for the first time.

History and generated PDFs are stored locally by default. Lexora requires no account and does not upload history to a project-owned server. Each external provider applies its own privacy policy and terms.

Difficulty is a learning-level estimate derived from public frequency signals and word shape, not an official examination level. The Datamuse frequency value is useful for relative sorting and comparison; it is not a precise percentage for a specific corpus.
