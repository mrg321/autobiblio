#!/usr/bin/env python3
"""Convert a PDF to Markdown using Docling."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

PDF_FILE_EXTENSION = ".pdf"
MARKDOWN_FILE_EXTENSION = ".md"
TEXT_ENCODING = "utf-8"
SUCCESS_EXIT_CODE = 0
INVALID_INPUT_EXIT_CODE = 2


def convert_pdf(input_path: Path, output_path: Path) -> int:
    try:
        from docling.document_converter import DocumentConverter
    except ImportError as exc:
        print(
            "Docling is not installed. Install project dependencies with:\n"
            "  python -m pip install -r requirements.txt",
            file=sys.stderr,
        )
        return INVALID_INPUT_EXIT_CODE

    converter = DocumentConverter(show_progress=True)
    result = converter.convert(str(input_path))
    try:
        markdown = result.document.export_to_markdown()
    finally:
        result.input.release()

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(markdown, encoding=TEXT_ENCODING)
    print(
        f"OK: {input_path.name} -> {output_path} "
        f"({len(markdown):,} characters)"
    )
    return SUCCESS_EXIT_CODE


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Convert a PDF to Markdown using Docling."
    )
    parser.add_argument("--input", type=Path, required=True, help="Input PDF")
    parser.add_argument(
        "--output",
        type=Path,
        required=True,
        help="Output Markdown file (the Robot suite uses .txt for compatibility)",
    )
    args = parser.parse_args()

    if not args.input.is_file():
        parser.error(f"Input PDF does not exist: {args.input}")
    if args.input.suffix.lower() != PDF_FILE_EXTENSION:
        parser.error(f"Input file does not have a .pdf extension: {args.input}")
    if args.output.suffix.lower() not in {MARKDOWN_FILE_EXTENSION, ".txt"}:
        parser.error("Output file must have a .md or .txt extension")

    return convert_pdf(args.input, args.output)


if __name__ == "__main__":
    raise SystemExit(main())