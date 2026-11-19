#!/usr/bin/env python3
"""Copy R/EDI/DESCRIPTION's Version into every other file that states the package version.

Owner, 2026-11-19: DESCRIPTION is the single source of truth for the version number. Edit only
DESCRIPTION, then run this script; the pre-push hook runs it with --check and refuses a push while
any copy disagrees.

  python3 scripts/sync_version.py          # rewrite the copies
  python3 scripts/sync_version.py --check  # exit 1 and list the copies that disagree

Copies kept in sync:
  CITATION.cff, python/CITATION.cff     top-level `version:` (not preferred-citation's)
  codemeta.json                         "version"
  python/pyproject.toml                 [project] version; a `.postN` suffix is kept when the
                                        X.Y.Z part already matches (Python packaging-only releases)
  R/EDI/inst/CITATION                   "R package version X.Y.Z"
  README.md, R/EDI/README.md,
  python/README.md, python/README_PYPI.md   BibTeX `version = {X.Y.Z}`
NEWS.md and python/CHANGELOG.md are not rewritten: their top section may already name the next
version (the news-version audit checks that they are not behind).
"""
import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DESCRIPTION = ROOT / "R" / "EDI" / "DESCRIPTION"


def description_version(root=ROOT):
    m = re.search(r"^Version:\s*(\S+)\s*$", (root / "R/EDI/DESCRIPTION").read_text(), re.M)
    if not m:
        sys.exit("R/EDI/DESCRIPTION has no Version field")
    return m.group(1)


def _pyproject(text, v):
    def repl(m):
        old = m.group(2)
        post = re.match(r"^(\d+(?:\.\d+)*)(\.post\d+)$", old)
        new = old if post and post.group(1) == v else v
        return m.group(1) + new + m.group(3)
    return re.sub(r'(^\[project\][^\[]*?^version\s*=\s*")([^"]+)(")', repl, text, count=1, flags=re.M | re.S)


# (path, function(text, version) -> new text)
RULES = [
    ("CITATION.cff", lambda t, v: re.sub(r'^(version:\s*"?)[^"\s]+("?\s*)$', rf"\g<1>{v}\g<2>", t, count=1, flags=re.M)),
    ("python/CITATION.cff", lambda t, v: re.sub(r'^(version:\s*"?)[^"\s]+("?\s*)$', rf"\g<1>{v}\g<2>", t, count=1, flags=re.M)),
    ("codemeta.json", lambda t, v: re.sub(r'^(\s*"version":\s*")[^"]*(")', rf"\g<1>{v}\g<2>", t, count=1, flags=re.M)),
    ("python/pyproject.toml", _pyproject),
    ("R/EDI/inst/CITATION", lambda t, v: re.sub(r"(R package version )\d+(?:\.\d+)+", rf"\g<1>{v}", t)),
] + [(p, lambda t, v: re.sub(r"^(\s*version\s*=\s*\{)[^}]+(\})", rf"\g<1>{v}\g<2>", t, flags=re.M))
     for p in ("README.md", "R/EDI/README.md", "python/README.md", "python/README_PYPI.md")]


def sync(root=ROOT, check=False):
    """Returns the list of files whose version differs from DESCRIPTION (rewritten unless check)."""
    v = description_version(root)
    stale = []
    for rel, fn in RULES:
        p = root / rel
        if not p.exists():
            continue
        old = p.read_text()
        new = fn(old, v)
        if new != old:
            stale.append(rel)
            if not check:
                p.write_text(new)
    return v, stale


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--check", action="store_true", help="report, do not rewrite")
    a = ap.parse_args()
    v, stale = sync(check=a.check)
    if a.check:
        if stale:
            print(f"Version copies disagree with R/EDI/DESCRIPTION ({v}): {', '.join(stale)}.\n"
                  "Run: python3 scripts/sync_version.py", file=sys.stderr)
            sys.exit(1)
        return
    print(f"R/EDI/DESCRIPTION {v}: " + (f"updated {', '.join(stale)}" if stale else "all copies already match"))


if __name__ == "__main__":
    main()
