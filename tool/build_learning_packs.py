#!/usr/bin/env python3
"""Build license-aware Lexora learning packs from open/reference sources.

The builder never invents dictionary fields: a source headword is emitted only
when ECDICT supplies both an English definition and a Chinese translation.
"""

from __future__ import annotations

import argparse
import csv
import gzip
import hashlib
import json
import re
from pathlib import Path


def normalize(value: str) -> str:
    return re.sub(r"\s+", " ", value.strip().lower().replace("’", "'"))


def read_ecdict(path: Path) -> dict[str, dict[str, str]]:
    result: dict[str, dict[str, str]] = {}
    with path.open(encoding="utf-8", newline="") as source:
        for row in csv.DictReader(source):
            key = normalize(row["word"])
            if key and row["definition"].strip() and row["translation"].strip():
                result[key] = row
    return result


def read_resemble(path: Path) -> dict[str, tuple[list[str], dict[str, str]]]:
    groups: dict[str, tuple[list[str], dict[str, str]]] = {}
    current: list[str] = []
    translations: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if line.startswith("% "):
            if current:
                for word in current:
                    groups[normalize(word)] = (current, translations.copy())
            current = [item.strip() for item in line[2:].split(",") if item.strip()]
            translations = {}
        elif line.startswith("- ") and ":" in line:
            word, meaning = line[2:].split(":", 1)
            translations[normalize(word)] = meaning.strip()
    if current:
        for word in current:
            groups[normalize(word)] = (current, translations.copy())
    return groups


def pdf_words(path: Path) -> set[str]:
    from pypdf import PdfReader

    words: set[str] = set()
    pattern = re.compile(r"^([A-Za-z][A-Za-z0-9'’ .&/-]*?)\s*\(([^)]{1,42})\)\s*$")
    for page in PdfReader(str(path)).pages:
        for raw in (page.extract_text() or "").splitlines():
            match = pattern.match(raw.strip().lstrip("*"))
            if not match:
                continue
            head = normalize(match.group(1))
            if (
                head
                and len(head) <= 64
                and "/" not in head
                and not head.startswith(("page ", "vocabulary "))
            ):
                words.add(head)
    return words


def text_words(path: Path) -> set[str]:
    return {
        normalize(line)
        for line in path.read_text(encoding="utf-8").splitlines()
        if normalize(line) and not line.lstrip().startswith("#")
    }


def pos_from(row: dict[str, str]) -> str:
    if row.get("pos", "").strip():
        return row["pos"].strip()
    match = re.match(r"^([a-z]+\.)", row["translation"].strip(), re.I)
    return match.group(1).rstrip(".") if match else ""


def frequency(row: dict[str, str]) -> float:
    values = [int(row[key]) for key in ("bnc", "frq") if row.get(key, "").isdigit() and int(row[key]) > 0]
    if not values:
        return 0.0
    rank = min(values)
    return round(max(0.1, 1000.0 / (1.0 + rank / 100.0)), 1)


def difficulty(tags: set[str]) -> str:
    if "cet4" in tags:
        return "A2–B1"
    if "cet6" in tags or "ky" in tags:
        return "B1–B2"
    if "ielts" in tags:
        return "B2–C1"
    return "B1–C1"


def make_entry(
    row: dict[str, str],
    resemble: dict[str, tuple[list[str], dict[str, str]]],
) -> dict:
    word = row["word"].strip()
    tags = {tag.lower() for tag in row["tag"].split()}
    related, related_zh = resemble.get(normalize(word), ([], {}))
    synonyms = [value for value in related if normalize(value) != normalize(word)][:8]
    translations = {value: related_zh.get(normalize(value), "") for value in synonyms}
    definition = row["definition"].strip()
    translation = row["translation"].strip()
    part = pos_from(row)
    senses = [
        {
            "partOfSpeech": part,
            "definitions": [
                {"definition": definition, "definitionZh": translation}
            ],
        }
    ]
    return {
        "word": word,
        "difficulty": difficulty(tags),
        "frequency": frequency(row),
        "usPhonetic": row["phonetic"].strip(),
        "ukPhonetic": row["phonetic"].strip(),
        "definition": definition,
        "definitionZh": translation,
        "synonyms": synonyms,
        "synonymsZh": "；".join(filter(None, translations.values())),
        "synonymTranslations": translations,
        "antonyms": [],
        "antonymsZh": "",
        "antonymTranslations": {},
        "examples": [],
        "examplesZh": [],
        "phrases": [],
        "senses": senses,
        "relatedWords": [
            {"word": value, "meaning": "", "meaningZh": translations.get(value, "")}
            for value in synonyms
        ],
    }


def write_pack(
    output: Path,
    pack_id: str,
    title_zh: str,
    title_en: str,
    description_zh: str,
    license_name: str,
    attribution: str,
    words: set[str],
    dictionary: dict[str, dict[str, str]],
    resemble: dict[str, tuple[list[str], dict[str, str]]],
) -> dict:
    entries = [make_entry(dictionary[word], resemble) for word in sorted(words) if word in dictionary]
    raw = json.dumps(
        {"schemaVersion": 1, "id": pack_id, "version": "2026.08.05", "entries": entries},
        ensure_ascii=False,
        separators=(",", ":"),
    ).encode()
    path = output / f"lexora-learning-{pack_id}-2026.08.05.json.gz"
    with path.open("wb") as file_object:
        with gzip.GzipFile(
            filename="",
            mode="wb",
            compresslevel=9,
            fileobj=file_object,
            mtime=0,
        ) as target:
            target.write(raw)
    payload = path.read_bytes()
    return {
        "id": pack_id,
        "titleZh": title_zh,
        "titleEn": title_en,
        "descriptionZh": description_zh,
        "version": "2026.08.05",
        "entryCount": len(entries),
        "bytes": len(payload),
        "sha256": hashlib.sha256(payload).hexdigest(),
        "urls": [f"https://lexora.12323456.xyz/downloads/{path.name}"],
        "license": license_name,
        "attribution": attribution,
        "filename": path.name,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--ecdict", type=Path, required=True)
    parser.add_argument("--resemble", type=Path, required=True)
    parser.add_argument("--ket-pdf", type=Path, required=True)
    parser.add_argument("--pet-pdf", type=Path, required=True)
    parser.add_argument("--tem8", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    dictionary = read_ecdict(args.ecdict)
    resemble = read_resemble(args.resemble)
    tagged: dict[str, set[str]] = {key: set(row["tag"].lower().split()) for key, row in dictionary.items()}
    tem8 = text_words(args.tem8)
    specs = [
        ("cet4", "大学英语四级", "CET-4", "四级常用词，完整双语释义与音标。", "MIT", "ECDICT", {w for w,t in tagged.items() if "cet4" in t}),
        ("cet6", "大学英语六级", "CET-6", "六级常用词，完整双语释义与音标。", "MIT", "ECDICT", {w for w,t in tagged.items() if "cet6" in t}),
        ("postgraduate", "考研英语", "Postgraduate English", "ECDICT 考研标签词汇。", "MIT", "ECDICT", {w for w,t in tagged.items() if "ky" in t}),
        ("ket", "剑桥 KET / A2 Key", "Cambridge A2 Key", "依据 Cambridge 2025 官方清单匹配开源双语词典；未可靠匹配项不打包。", "Reference list © UCLES 2025; dictionary MIT", "Cambridge English + ECDICT", pdf_words(args.ket_pdf)),
        ("pet", "剑桥 PET / B1 Preliminary", "Cambridge B1 Preliminary", "依据 Cambridge 2025 官方清单匹配开源双语词典；未可靠匹配项不打包。", "Reference list © UCLES 2025; dictionary MIT", "Cambridge English + ECDICT", pdf_words(args.pet_pdf)),
        ("ielts", "雅思基础词库", "IELTS Foundation", "ECDICT 的 IELTS 标签基础词库，不声称为官方考试清单。", "MIT", "ECDICT", {w for w,t in tagged.items() if "ielts" in t}),
        ("tem4", "专四核心（开源参考）", "TEM-4 Core Reference", "从开源 TEM-8 词头中按 ECDICT 高频排名筛选的核心参考，不冒充官方清单。", "Apache-2.0 + MIT", "OpenEtymology + ECDICT", set(sorted(tem8 & dictionary.keys(), key=lambda w: int(dictionary[w].get("frq") or 999999))[:2400])),
        ("tem8", "英语专业八级", "TEM-8", "OpenEtymology 公开 TEM-8 词头与 ECDICT 双语内容匹配。", "Apache-2.0 + MIT", "OpenEtymology + ECDICT", tem8),
    ]
    packs = [write_pack(args.output, *spec, dictionary, resemble) for spec in specs]
    manifest = {"schemaVersion": 1, "generatedAt": "2026-08-05T00:00:00Z", "packs": packs}
    (args.output / "lexora-learning-packs-manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps({pack["id"]: pack["entryCount"] for pack in packs}, ensure_ascii=False))


if __name__ == "__main__":
    main()
