#!/usr/bin/env python3
"""Build a range-addressable ECDICT pack for the Lexora Cloudflare Worker."""

from __future__ import annotations

import argparse
import csv
import gzip
import hashlib
import json
import re
import shutil
from collections import OrderedDict
from pathlib import Path


VALID_TERM = re.compile(r"^[a-z][a-z' -]{0,79}$")


def prefix_for(term: str) -> str:
    second = term[1] if len(term) > 1 and term[1].isalpha() else "_"
    return term[0] + second


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()

    staging = args.output.parent / f".{args.output.name}-lines"
    if staging.exists():
        shutil.rmtree(staging)
    staging.mkdir(parents=True)
    args.output.mkdir(parents=True, exist_ok=True)

    handles: OrderedDict[str, object] = OrderedDict()
    rows = 0

    def handle_for(prefix: str):
        handle = handles.pop(prefix, None)
        if handle is None:
            handle = (staging / f"{prefix}.jsonl").open("a", encoding="utf-8")
        handles[prefix] = handle
        if len(handles) > 48:
            _, oldest = handles.popitem(last=False)
            oldest.close()
        return handle

    with args.source.open("r", encoding="utf-8-sig", newline="") as source:
        for row in csv.DictReader(source):
            term = " ".join((row.get("word") or "").strip().lower().split())
            translation = (row.get("translation") or "").strip()
            if not VALID_TERM.fullmatch(term) or not translation:
                continue
            value = [
                (row.get("phonetic") or "").strip(),
                (row.get("definition") or "").strip(),
                translation,
                (row.get("pos") or "").strip(),
                (row.get("bnc") or "").strip(),
                (row.get("frq") or "").strip(),
            ]
            handle_for(prefix_for(term)).write(
                json.dumps([term, value], ensure_ascii=False, separators=(",", ":"))
                + "\n"
            )
            rows += 1
    for handle in handles.values():
        handle.close()

    pack_path = args.output / "lexora-ecdict-v1.pack"
    manifest = {
        "version": 1,
        "source": "ECDICT (MIT)",
        "rows": rows,
        "pack": pack_path.name,
        "shards": {},
    }
    offset = 0
    with pack_path.open("wb") as pack:
        for source_path in sorted(staging.glob("*.jsonl")):
            values: dict[str, list[str]] = {}
            with source_path.open("r", encoding="utf-8") as lines:
                for line in lines:
                    term, value = json.loads(line)
                    values[term] = value
            payload = json.dumps(
                values, ensure_ascii=False, separators=(",", ":")
            ).encode("utf-8")
            compressed = gzip.compress(payload, compresslevel=9, mtime=0)
            pack.write(compressed)
            prefix = source_path.stem
            manifest["shards"][prefix] = {
                "offset": offset,
                "length": len(compressed),
                "rows": len(values),
            }
            offset += len(compressed)
    manifest["bytes"] = offset
    manifest["sha256"] = hashlib.sha256(pack_path.read_bytes()).hexdigest()
    (args.output / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )
    shutil.rmtree(staging)
    print(json.dumps({"rows": rows, "bytes": offset, "shards": len(manifest["shards"])}))


if __name__ == "__main__":
    main()
