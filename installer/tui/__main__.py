#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.11"
# dependencies = ["archinstall"]
# ///
"""Entry point. Run directly (`python3 installer/tui/__main__.py`) from
anywhere; the sys.path insert below is what makes that work without
needing the repo installed as a package or PYTHONPATH set up by hand,
since this is fetched and run straight out of a git checkout, not
pip-installed.

The inline metadata above (PEP 723) is for `uv run installer/tui/
__main__.py`: `archinstall` alone is listed since it already depends on
`python-textual`, so `uv` resolves both from one declared dependency.
On the live ISO both are already installed system-wide (archinstall's
own pacman dependency), so plain `python3` works there with no `uv`
involved at all; the inline metadata only matters for running this
outside that environment."""

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from app import SobarchApp  # noqa: E402


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
    return parser.parse_args(argv)


def main() -> None:
    args = parse_args()
    app = SobarchApp(dry_run=args.dry_run, output_dir=args.output_dir)
    app.run()


if __name__ == "__main__":
    main()
