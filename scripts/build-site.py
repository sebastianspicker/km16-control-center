#!/usr/bin/env python3
"""Assemble the browser demo from an explicit list of public files."""

import argparse
import json
from pathlib import Path
import shutil


ROOT = Path(__file__).resolve().parents[1]
SITE_FILES = ("index.html", "styles.css", "app.js", "favicon.svg", "archivo.woff2", "fragment-mono.woff2", "fonts-OFL.txt")
OUTPUT_FILES = {*SITE_FILES, "presets.json", ".nojekyll"}


def build_site(root: Path, output: Path) -> None:
    sources = {name: root / "site" / name for name in SITE_FILES}
    sources["presets.json"] = root / "presets" / "all.json"
    for source in sources.values():
        if source.is_symlink() or not source.is_file():
            raise ValueError(f"Expected a regular source file: {source}")
    json.loads(sources["presets.json"].read_text(encoding="utf-8"))

    if output.is_symlink():
        raise ValueError(f"Output must not be a symbolic link: {output}")
    if output.exists():
        for child in output.iterdir():
            if child.name not in OUTPUT_FILES or child.is_symlink() or not child.is_file():
                raise ValueError(f"Unexpected output entry; choose a fresh directory: {child}")
    output.mkdir(parents=True, exist_ok=True)
    for name, source in sources.items():
        shutil.copyfile(source, output / name)
    (output / ".nojekyll").write_text("", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "dist" / "site")
    args = parser.parse_args()
    try:
        build_site(ROOT, args.output)
    except (OSError, ValueError) as error:
        parser.error(str(error))
    print(f"Built browser demo: {args.output}")


if __name__ == "__main__":
    main()
