#!/usr/bin/env python3
"""Fail a push that introduces a duplicate TODO number in a release file.

Release files (R/package_metadata/future_release_plans/release_v*.md) number their
checkbox TODOs (`- [ ] TODO-147 ...`). Agents append to them concurrently, and two of
them can pick the same next number (it happened on 2026-11-18 with v1.0.6-TODO-99).
This compares each changed release file at the pushed commit with the remote base and
fails only on duplicates the push adds: a number that is newly duplicated, or that
gained more entries. Duplicates already on the remote do not block the push; the
TODO-status audit renumbers those.

Usage: check_todo_duplicates.py BASE_SHA LOCAL_SHA
Stdlib only; runs in milliseconds. Exit 0 = fine, 1 = new duplicates (listed).
"""
import collections
import re
import subprocess
import sys

RELEASE_GLOB = re.compile(r"^R/package_metadata/future_release_plans/release_v[0-9_]+\.md$")
TODO_LINE = re.compile(r"^- \[[ xX]\] TODO-(\d+)\b")
EMPTY_TREE = "4b825dc642cb6eb9a060e54bf8d69288fbee4904"


def git(*args):
    return subprocess.run(["git", *args], capture_output=True, text=True)


def file_at(sha, path):
    if sha == EMPTY_TREE:
        return ""
    out = git("show", f"{sha}:{path}")
    return out.stdout if out.returncode == 0 else ""


def todo_counts(text):
    return collections.Counter(int(m.group(1)) for line in text.splitlines() if (m := TODO_LINE.match(line)))


def todo_lines(text, number):
    return [f"  line {i}: {line[:110]}" for i, line in enumerate(text.splitlines(), 1)
            if (m := TODO_LINE.match(line)) and int(m.group(1)) == number]


def new_duplicates(base_text, local_text):
    base, local = todo_counts(base_text), todo_counts(local_text)
    return sorted(n for n, c in local.items() if c > 1 and c > base.get(n, 0))


def main(argv):
    if len(argv) != 3:
        print(__doc__.strip().splitlines()[-2], file=sys.stderr)
        return 2
    base, local = argv[1], argv[2]
    diff = git("diff", "--name-only", base, local)
    if diff.returncode != 0:
        print(f"check_todo_duplicates: git diff failed: {diff.stderr.strip()}", file=sys.stderr)
        return 0  # fail open, like the other pre-push helpers
    bad = []
    for path in (p for p in diff.stdout.splitlines() if RELEASE_GLOB.match(p)):
        local_text = file_at(local, path)
        for n in new_duplicates(file_at(base, path), local_text):
            bad.append(f"{path}: TODO-{n} is used by more than one entry:\n" + "\n".join(todo_lines(local_text, n)))
    if bad:
        print("pre-push: this push adds duplicate TODO numbers. Renumber the newer entry to the next free"
              " number (and any reference to it) before pushing:", file=sys.stderr)
        print("\n".join(bad), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
