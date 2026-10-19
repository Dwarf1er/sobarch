#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.11"
# dependencies = ["archinstall"]
# ///
"""Installer entry point, run straight from a git checkout.

archinstall pulls in textual, so the PEP 723 block lists only archinstall.
"""

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from app import SobarchApp  # noqa: E402
from unattended import run_unattended  # noqa: E402


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="sobarch installer TUI")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Walk through every prompt and generate the archinstall config, "
        "but never invoke archinstall or touch a disk (mirrors archinstall's own --dry-run).",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=None,
        help="Where 'Save configuration' writes base.json/credentials.json "
        "(default: /root/sobarch-install as root, ./sobarch-install-output otherwise).",
    )
    parser.add_argument(
        "--answer-file",
        type=Path,
        default=None,
        help="Run unattended from this JSON answer file instead of the interactive "
        "wizard (see installer/unattended-answer.example.json for the schema). "
        "Combine with --dry-run to only generate/save the config without installing.",
    )
    return parser.parse_args(argv)


def main() -> None:
    args = parse_args()

    if args.answer_file is not None:
        output_dir = args.output_dir or SobarchApp.default_output_dir()
        sys.exit(run_unattended(args.answer_file, output_dir, args.dry_run))

    app = SobarchApp(dry_run=args.dry_run, output_dir=args.output_dir)
    app.run()


if __name__ == "__main__":
    main()
