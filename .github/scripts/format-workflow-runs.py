#!/usr/bin/env python3

"""
Format `run:` blocks in GitHub Actions workflow/action YAML files using the
shfmt hook configured in .pre-commit-config.yaml.

Handles both literal block-scalar runs (`run: |`) and single-line runs
(`run: some command`). For each occurrence:
  1. Extract the shell content (dedented for blocks).
  2. Write it to a temp .sh file.
  3. Invoke `pre-commit run shfmt --files <temp>` (falling back to `prek`)
     so the same shfmt arguments declared in .pre-commit-config.yaml apply.
  4. Read the formatted result and write it back. If shfmt expands a
     single-line value into multiple lines, the entry is upgraded to a
     `run: |` block scalar.

When invoked without arguments, every .yml/.yaml file under .github/ is
scanned. When invoked with file arguments (the pre-commit case), only those
files are processed.
"""

from __future__ import annotations

import re
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Union

REPO = Path(__file__).resolve().parents[2]

_HOOK_RUNNER = next((cmd for cmd in ("pre-commit", "prek") if shutil.which(cmd)), None)
if _HOOK_RUNNER is None:
    sys.exit("error: neither `pre-commit` nor `prek` found on PATH")

RUN_BLOCK_RE = re.compile(r"^(?P<prefix>[ \t]*(?:- )?)run:[ \t]*\|[+-]?[ \t]*$")
RUN_INLINE_RE = re.compile(
    r"^(?P<prefix>[ \t]*(?:- )?)run:[ \t]+" r"(?P<value>(?!\|[+-]?[ \t]*$)\S.*?)[ \t]*$"
)


@dataclass(frozen=True)
class BlockRun:
    """A `run: |` block scalar; `body_start:body_end` slices into `lines`."""

    body_start: int
    body_end: int
    body_indent: int


@dataclass(frozen=True)
class InlineRun:
    """A single-line `run: value` at `line_idx`."""

    line_idx: int
    prefix: str
    value: str


RunItem = Union[BlockRun, InlineRun]


def _scan_block_body(
    lines: list[str], body_start: int, run_col: int
) -> tuple[int | None, int]:
    """Locate the body of a `run: |` block scalar starting at `body_start`.

    Returns `(body_indent, scan_end)`. `scan_end` is the line index where the
    outer scanner should resume. `body_indent` is `None` when no body is
    present (the scalar is empty, or the next non-blank line has indent
    `<= run_col`).
    """
    body_indent: int | None = None
    scan_end = len(lines)
    for idx in range(body_start, len(lines)):
        line = lines[idx]
        if line.strip() == "":
            continue
        indent = len(line) - len(line.lstrip(" "))
        if body_indent is None:
            if indent > run_col:
                body_indent = indent
            else:
                scan_end = idx
                break
        elif indent < body_indent:
            scan_end = idx
            break
    if body_indent is not None:
        while scan_end > body_start and lines[scan_end - 1].strip() == "":
            scan_end -= 1
        if scan_end <= body_start:
            body_indent = None
    return body_indent, scan_end


def find_run_blocks(lines: list[str]) -> list[RunItem]:
    """Return run items in document order."""
    items: list[RunItem] = []
    line_idx = 0
    while line_idx < len(lines):
        line = lines[line_idx]
        if block_match := RUN_BLOCK_RE.match(line):
            run_col = len(block_match.group("prefix"))
            body_start = line_idx + 1
            body_indent, scan_end = _scan_block_body(lines, body_start, run_col)
            if body_indent is not None:
                items.append(
                    BlockRun(
                        body_start=body_start,
                        body_end=scan_end,
                        body_indent=body_indent,
                    )
                )
            line_idx = scan_end
            continue
        if inline_match := RUN_INLINE_RE.match(line):
            items.append(
                InlineRun(
                    line_idx=line_idx,
                    prefix=inline_match.group("prefix"),
                    value=inline_match.group("value"),
                )
            )
        line_idx += 1
    return items


def dedent(lines: list[str], n: int) -> list[str]:
    pad = " " * n
    return [
        (
            ""
            if line.strip() == ""
            else (line[n:] if line.startswith(pad) else line.lstrip(" "))
        )
        for line in lines
    ]


def reindent(lines: list[str], n: int) -> list[str]:
    pad = " " * n
    return [pad + line if line else "" for line in lines]


def shfmt_via_hook(tmp_path: Path) -> tuple[bool, str]:
    res = subprocess.run(
        [_HOOK_RUNNER, "run", "shfmt", "--files", str(tmp_path)],
        cwd=REPO,
        capture_output=True,
        text=True,
    )
    blob = (res.stdout + res.stderr).lower()
    parse_err = any(
        s in blob for s in ("syntax error", "invalid parameter", "parse error")
    )
    return not parse_err, res.stdout + res.stderr


def _skip(path: Path, where: int, kind: str, output: str) -> None:
    print(
        f"  shfmt could not parse {kind} at {path}:{where + 1} — skipped",
        file=sys.stderr,
    )
    print(f"    {output.strip()}", file=sys.stderr)


def process_file(path: Path, tmp_path: Path) -> int:
    text = path.read_text()
    had_nl = text.endswith("\n")
    lines = text.split("\n")
    if had_nl:
        lines = lines[:-1]
    items = find_run_blocks(lines)
    if not items:
        return 0
    changed = 0
    # Process in reverse so earlier indices remain valid as we splice.
    for item in reversed(items):
        if isinstance(item, BlockRun):
            body = lines[item.body_start : item.body_end]
            tmp_path.write_text("\n".join(dedent(body, item.body_indent)) + "\n")
            ok, output = shfmt_via_hook(tmp_path)
            if not ok:
                _skip(path, item.body_start, "block", output)
                continue
            formatted = tmp_path.read_text().rstrip("\n")
            new_body = reindent(formatted.split("\n"), item.body_indent)
            if new_body != body:
                lines[item.body_start : item.body_end] = new_body
                changed += 1
        else:
            tmp_path.write_text(item.value + "\n")
            ok, output = shfmt_via_hook(tmp_path)
            if not ok:
                _skip(path, item.line_idx, "inline run", output)
                continue
            formatted = tmp_path.read_text().rstrip("\n")
            if formatted == item.value:
                continue
            formatted_lines = formatted.split("\n")
            if len(formatted_lines) == 1:
                lines[item.line_idx] = f"{item.prefix}run: {formatted}"
            else:
                body_indent = len(item.prefix) + 2
                lines[item.line_idx : item.line_idx + 1] = [
                    f"{item.prefix}run: |",
                    *reindent(formatted_lines, body_indent),
                ]
            changed += 1
    new_text = "\n".join(lines) + ("\n" if had_nl else "")
    if new_text != text:
        path.write_text(new_text)
    return changed


def gather_files(argv: list[str]) -> list[Path]:
    if argv:
        return [
            (REPO / a).resolve() if not Path(a).is_absolute() else Path(a) for a in argv
        ]
    gh = REPO / ".github"
    return sorted(list(gh.rglob("*.yml")) + list(gh.rglob("*.yaml")))


def main(argv: list[str]) -> int:
    files = [
        f
        for f in gather_files(argv)
        if f.suffix in (".yml", ".yaml") and ".github" in f.parts and f.exists()
    ]
    if not files:
        return 0
    with tempfile.TemporaryDirectory(prefix="format-workflow-runs-") as tmpdir:
        tmp_path = Path(tmpdir) / "shfmt.sh"
        total = 0
        for f in files:
            n = process_file(f, tmp_path)
            if n:
                print(f"{f.relative_to(REPO)}: reformatted {n} run-block(s)")
                total += n
        return 1 if total else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
