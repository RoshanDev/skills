#!/usr/bin/env python3
"""Validate this Agent Skill and optionally run its Go example.

No third-party Python packages are required.
"""

from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import sys
from pathlib import Path
from urllib.parse import unquote

NAME_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
LINK_RE = re.compile(r"\[[^\]]*\]\(([^)]+)\)")


def parse_frontmatter(text: str) -> tuple[dict[str, str], str]:
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        raise ValueError("SKILL.md must start with YAML frontmatter delimiter '---'")

    try:
        end = next(i for i in range(1, len(lines)) if lines[i].strip() == "---")
    except StopIteration as exc:
        raise ValueError("SKILL.md frontmatter has no closing '---'") from exc

    values: dict[str, str] = {}
    for line in lines[1:end]:
        if not line or line[0].isspace() or ":" not in line:
            continue
        key, value = line.split(":", 1)
        values[key.strip()] = value.strip().strip('"\'')

    body = "\n".join(lines[end + 1 :]).strip()
    return values, body


def validate_local_links(root: Path, text: str) -> list[str]:
    errors: list[str] = []
    for target in LINK_RE.findall(text):
        target = target.strip()
        if not target or target.startswith(("http://", "https://", "mailto:", "#")):
            continue
        path_part = unquote(target.split("#", 1)[0])
        if not path_part:
            continue
        resolved = (root / path_part).resolve()
        try:
            resolved.relative_to(root.resolve())
        except ValueError:
            errors.append(f"local link escapes skill directory: {target}")
            continue
        if not resolved.exists():
            errors.append(f"broken local link: {target}")
    return errors


def run(cmd: list[str], cwd: Path) -> tuple[bool, str]:
    proc = subprocess.run(
        cmd,
        cwd=cwd,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    return proc.returncode == 0, proc.stdout


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "skill_dir",
        nargs="?",
        type=Path,
        default=Path(__file__).resolve().parents[1],
        help="skill directory; defaults to the parent of scripts/",
    )
    parser.add_argument(
        "--skip-go-test",
        action="store_true",
        help="do not run go test for examples/order",
    )
    args = parser.parse_args()

    root = args.skill_dir.resolve()
    skill_file = root / "SKILL.md"
    errors: list[str] = []

    if not skill_file.is_file():
        print(f"ERROR: missing {skill_file}", file=sys.stderr)
        return 1

    try:
        text = skill_file.read_text(encoding="utf-8")
        frontmatter, body = parse_frontmatter(text)
    except (OSError, UnicodeError, ValueError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    name = frontmatter.get("name", "")
    description = frontmatter.get("description", "")

    if not name:
        errors.append("frontmatter field 'name' is required")
    elif len(name) > 64:
        errors.append("name exceeds 64 characters")
    elif not NAME_RE.fullmatch(name):
        errors.append("name must contain lowercase letters, digits and single hyphens only")

    if name and root.name != name:
        errors.append(f"name '{name}' must match parent directory '{root.name}'")

    if not description:
        errors.append("frontmatter field 'description' is required")
    elif len(description) > 1024:
        errors.append("description exceeds 1024 characters")

    if not body:
        errors.append("SKILL.md body is empty")

    errors.extend(validate_local_links(root, text))

    for path in root.rglob("*"):
        if path.is_file():
            try:
                path.read_text(encoding="utf-8")
            except UnicodeDecodeError:
                # Binary assets are allowed; this package currently has none.
                pass
            except OSError as exc:
                errors.append(f"cannot read {path.relative_to(root)}: {exc}")

    if not args.skip_go_test:
        example = root / "examples" / "order"
        if example.is_dir():
            if shutil.which("go") is None:
                errors.append("Go is not installed; use --skip-go-test to skip example tests")
            else:
                ok, output = run(["go", "test", "./..."], example)
                if not ok:
                    errors.append("Go example tests failed:\n" + output.rstrip())

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    print(f"OK: {root}")
    print(f"  name: {name}")
    print(f"  description characters: {len(description)}")
    if not args.skip_go_test and (root / "examples" / "order").is_dir():
        print("  Go example: passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
