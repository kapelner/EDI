#!/usr/bin/env python3
"""Tests for scripts/check_todo_duplicates.py on a throwaway git repo. Stdlib only."""
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import check_todo_duplicates as ctd  # noqa: E402

REL = "R/package_metadata/future_release_plans/release_v1_0_6.md"


def run(cwd, *args):
    return subprocess.run(args, cwd=cwd, capture_output=True, text=True, check=True).stdout.strip()


class Repo:
    def __init__(self):
        self.dir = tempfile.mkdtemp()
        run(self.dir, "git", "init", "-q")
        run(self.dir, "git", "config", "user.email", "t@example.invalid")
        run(self.dir, "git", "config", "user.name", "t")

    def commit(self, text, path=REL):
        f = Path(self.dir) / path
        f.parent.mkdir(parents=True, exist_ok=True)
        f.write_text(text)
        run(self.dir, "git", "add", "-A")
        run(self.dir, "git", "commit", "-q", "-m", "x", "--allow-empty")
        return run(self.dir, "git", "rev-parse", "HEAD")

    def check(self, base, local):
        old = os.getcwd()
        os.chdir(self.dir)
        try:
            return ctd.main(["x", base, local])
        finally:
            os.chdir(old)


class Tests(unittest.TestCase):
    def test_counts_only_checkbox_lines(self):
        text = "- [ ] TODO-1 a\n- [x] TODO-2 b\n  see v1.0.6-TODO-1\n- TODO-3 not a checkbox\n"
        self.assertEqual(dict(ctd.todo_counts(text)), {1: 1, 2: 1})

    def test_new_duplicate_fails(self):
        r = Repo()
        base = r.commit("- [ ] TODO-146 a\n")
        local = r.commit("- [ ] TODO-146 a\n- [ ] TODO-147 b\n- [ ] TODO-147 c\n")
        self.assertEqual(r.check(base, local), 1)

    def test_unique_append_passes(self):
        r = Repo()
        base = r.commit("- [ ] TODO-146 a\n")
        local = r.commit("- [ ] TODO-146 a\n- [ ] TODO-147 b\n")
        self.assertEqual(r.check(base, local), 0)

    def test_existing_duplicate_does_not_block(self):
        r = Repo()
        base = r.commit("- [ ] TODO-3 a\n- [ ] TODO-3 b\n")
        local = r.commit("- [ ] TODO-3 a\n- [ ] TODO-3 b\n- [ ] TODO-4 c\n")
        self.assertEqual(r.check(base, local), 0)

    def test_existing_duplicate_gaining_another_entry_fails(self):
        r = Repo()
        base = r.commit("- [ ] TODO-3 a\n- [ ] TODO-3 b\n")
        local = r.commit("- [ ] TODO-3 a\n- [ ] TODO-3 b\n- [ ] TODO-3 c\n")
        self.assertEqual(r.check(base, local), 1)

    def test_new_file_against_empty_tree(self):
        r = Repo()
        local = r.commit("- [ ] TODO-1 a\n- [ ] TODO-1 b\n")
        self.assertEqual(r.check(ctd.EMPTY_TREE, local), 1)

    def test_non_release_files_ignored(self):
        r = Repo()
        base = r.commit("x\n", path="notes.md")
        local = r.commit("- [ ] TODO-1 a\n- [ ] TODO-1 b\n", path="notes.md")
        self.assertEqual(r.check(base, local), 0)


if __name__ == "__main__":
    unittest.main(verbosity=1)
