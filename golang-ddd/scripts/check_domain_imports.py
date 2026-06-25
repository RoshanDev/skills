#!/usr/bin/env python3
"""Find infrastructure imports and adapter tags inside Go domain packages.

This is a conservative architecture guard, not a full Go parser. Customize the
forbidden prefixes for your repository and review every finding in context.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

IMPORT_BLOCK_RE = re.compile(r"(?ms)^\s*import\s*\((.*?)^\s*\)")
IMPORT_SINGLE_RE = re.compile(r'(?m)^\s*import\s+(?:[._A-Za-z][\w]*\s+)?"([^"]+)"')
QUOTED_RE = re.compile(r'"([^"]+)"')
ADAPTER_TAG_RE = re.compile(r"`[^`]*(?:json|xml|db|gorm|bson|protobuf):[^`]*`")

DEFAULT_FORBIDDEN = (
    "database/sql",
    "net/http",
    "google.golang.org/grpc",
    "gorm.io/",
    "github.com/jackc/pgx",
    "github.com/gin-gonic/gin",
    "github.com/labstack/echo",
    "github.com/gofiber/fiber",
    "github.com/segmentio/kafka-go",
    "github.com/IBM/sarama",
    "github.com/Shopify/sarama",
    "github.com/rabbitmq/amqp091-go",
    "github.com/redis/go-redis",
    "go.mongodb.org/mongo-driver",
)


def imports_from(source: str) -> set[str]:
    imports = set(IMPORT_SINGLE_RE.findall(source))
    for block in IMPORT_BLOCK_RE.findall(source):
        imports.update(QUOTED_RE.findall(block))
    return imports


def is_domain_file(path: Path, names: set[str]) -> bool:
    return any(part in names for part in path.parts[:-1])


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("root", nargs="?", type=Path, default=Path.cwd())
    parser.add_argument(
        "--domain-name",
        action="append",
        default=["domain"],
        help="directory name considered a domain package; repeatable",
    )
    parser.add_argument(
        "--forbid",
        action="append",
        default=[],
        help="additional forbidden import prefix; repeatable",
    )
    parser.add_argument(
        "--allow-import",
        action="append",
        default=[],
        help="allowed exact import or prefix; repeatable",
    )
    parser.add_argument(
        "--allow-adapter-tags",
        action="store_true",
        help="do not flag json/db/gorm/etc. struct tags in domain packages",
    )
    args = parser.parse_args()

    root = args.root.resolve()
    domain_names = set(args.domain_name)
    forbidden = DEFAULT_FORBIDDEN + tuple(args.forbid)
    allowed = tuple(args.allow_import)
    findings: list[str] = []
    scanned = 0

    for path in root.rglob("*.go"):
        if any(part in {"vendor", ".git", "testdata"} for part in path.parts):
            continue
        rel = path.relative_to(root)
        if not is_domain_file(rel, domain_names):
            continue
        scanned += 1
        source = path.read_text(encoding="utf-8")

        for imported in sorted(imports_from(source)):
            if any(imported == item or imported.startswith(item) for item in allowed):
                continue
            if any(imported == item or imported.startswith(item) for item in forbidden):
                findings.append(f"{rel}: forbidden domain import {imported!r}")

        if not args.allow_adapter_tags:
            for match in ADAPTER_TAG_RE.finditer(source):
                line = source.count("\n", 0, match.start()) + 1
                findings.append(f"{rel}:{line}: adapter serialization/persistence tag in domain")

    if findings:
        print("Domain boundary violations:", file=sys.stderr)
        for finding in findings:
            print(f"  - {finding}", file=sys.stderr)
        print(
            "Review the finding, move adapter concerns outward, or document a narrow allow-list.",
            file=sys.stderr,
        )
        return 1

    print(f"OK: scanned {scanned} Go files under domain directories in {root}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
