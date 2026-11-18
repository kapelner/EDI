#!/usr/bin/env python3
"""Checks for the TODO-status audit's mechanical tidy (.github/scripts/audits/_todo_tidy.py):
duplicate TODO numbers are renumbered and each section's entries are put in numeric order.
Stdlib only. The fixtures are short, anonymised fragments in the format of the real release files.
"""
import os
import subprocess
import sys
import tempfile
import unittest
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import audit_run  # noqa: E402
from audits import _todo_tidy as tt  # noqa: E402
from audits import todo_status as ts  # noqa: E402

REL = "R/package_metadata/future_release_plans/release_v1_0_6.md"

SECTIONS = """# Release Scope: v1.0.6

> **Status: APPROVED (owner).** Not yet released.

## Implementation TODOs

Intro prose that stays first.

- [ ] TODO-3 (added 2026-11-01, owner): **Third thing to fix in the kernel.**
  - Problem: a long one.

    ```
    - [ ] TODO-99: inside a fence, part of TODO-3
    ```
  - [x] TODO-3a: nested, moves with its parent.
- [x] TODO-1 (added 2026-10-01): **First thing.**


- [ ] TODO-2: **Second thing.**
  continuation line

A paragraph between runs: entries above and below it never cross it.

- [ ] TODO-5: **Fifth.**
- [ ] a plain checkbox with no number stays put
- [ ] TODO-4: **Fourth.**
- [ ] TODO-0: **Zeroth, after the unnumbered one.**

### Bugs found by the data-shape matrix (TODO-7..9)

- [ ] TODO-9: **Nine.**
- [ ] TODO-7b: **Seven b.**
- [ ] TODO-7: **Seven.**
- [ ] TODO-17: **Seventeen.**
- [ ] TODO-8: **Eight.**

## Implementation TODOs (dependency order)

- [ ] TODO-12: **Must come before eleven.**
- [ ] TODO-11: **Eleven.**
"""


def todos(text):
    return [it["todo"] for it in ts.parse_checkboxes(text, REL)]


class Reorder(unittest.TestCase):
    def setUp(self):
        self.new, self.runs = tt.reorder_text(REL, SECTIONS)

    def test_permutation_of_lines(self):
        self.assertEqual(Counter(self.new.split("\n")), Counter(SECTIONS.split("\n")))
        self.assertNotEqual(self.new, SECTIONS)

    def test_sorted_within_runs_only(self):
        self.assertEqual(todos(self.new), [
            "TODO-1", "TODO-2", "TODO-3",            # run 1, sorted
            "TODO-5", None, "TODO-0", "TODO-4",      # a plain checkbox breaks the run; prose before it
            "TODO-7", "TODO-7b", "TODO-8", "TODO-9", "TODO-17",
            "TODO-12", "TODO-11"])                   # declared order: kept

    def test_prose_and_headings_stay(self):
        old, new = SECTIONS.split("\n"), self.new.split("\n")
        for i, l in enumerate(old):
            if l.startswith("#") or l.startswith("Intro") or l.startswith("A paragraph") or "plain checkbox" in l:
                self.assertEqual(new[i], l)

    def test_block_moves_as_unit(self):
        block = SECTIONS[SECTIONS.index("- [ ] TODO-3"):SECTIONS.index("- [x] TODO-1")]
        self.assertIn(block.rstrip("\n"), self.new)
        self.assertNotIn("TODO-99", [t for t in todos(self.new) if t])

    def test_gaps_stay_in_place(self):
        # Blocks permute among slots; the gaps between slots stay. The double blank line was the 2nd
        # gap, so it now precedes the 3rd entry (TODO-3), and TODO-2 follows TODO-1 directly.
        lines = self.new.split("\n")
        i = lines.index("- [ ] TODO-3 (added 2026-11-01, owner): **Third thing to fix in the kernel.**")
        self.assertEqual(lines[i - 3:i], ["  continuation line", "", ""])
        j = lines.index("- [ ] TODO-2: **Second thing.**")
        self.assertEqual(lines[j - 1], "- [x] TODO-1 (added 2026-10-01): **First thing.**")

    def test_ordered_heading_reported_not_moved(self):
        kept = [r for r in self.runs if r["kept_order"]]
        self.assertEqual(len(kept), 1)
        self.assertEqual(kept[0]["before"], ["TODO-12", "TODO-11"])

    def test_idempotent(self):
        again, runs = tt.reorder_text(REL, self.new)
        self.assertEqual(again, self.new)
        self.assertTrue(all(r["kept_order"] for r in runs))

    def test_num_key(self):
        nums = ["17", "4b", "5", "4", "17a", "17.1", "3"]
        self.assertEqual(sorted(nums, key=tt.num_key), ["3", "4", "4b", "5", "17", "17.1", "17a"])
        self.assertLess(tt.num_key("4"), tt.num_key("4b"))
        self.assertLess(tt.num_key("4b"), tt.num_key("5"))
        self.assertLess(tt.num_key("9"), tt.num_key("17"))


DUPS = """# Release Scope: v1.0.6

## Implementation TODOs

### Found by an agent (TODO-20..30)

- [ ] TODO-7 (added 2026-11-18, agent): **Later-added entry that sits first in the file.**
  - Found: v1.0.6-TODO-7; see also `R/EDI/tests/testthat/test-later-thing.R`.
  - Related: v1.1.0-TODO-7 (another release) and `release_v1_1_0.md →
    TODO-7` (another file), and v1.0.6 TODO-7 (old style).
  - Scope (`plan.md`):
    - TODO-7: a plan's own TODO, not this entry.
  - Self-reference in prose: this is TODO-7.

- [ ] TODO-7 (added 2026-11-02, owner): **Earlier-added entry keeps its number.**
  - Cites TODO-7 about itself.

- [ ] TODO-5 (added 2026-11-01): **Split item.**
- [ ] ~~TODO-5 (steps 5-8)~~ **→ moved 2026-11-02 to `release_v1_1_0.md → TODO-40`**: remainder.

- [ ] TODO-30: **Highest.**

Status: v1.0.6-TODO-7 (**Later-added entry that sits first in the file.**) is in progress.
Elsewhere: TODO-7 is mentioned without context.
"""


class Renumber(unittest.TestCase):
    def setUp(self):
        self.items = ts.parse_checkboxes(DUPS, REL)
        self.plan = tt.plan_renumber(self.items, DUPS)

    def test_split_pointer_is_not_a_duplicate(self):
        self.assertEqual(set(tt.duplicate_groups(self.items)), {"7"})

    def test_earliest_added_keeps_number(self):
        self.assertEqual(len(self.plan), 1)
        r = self.plan[0]
        self.assertEqual(r["item"]["line"], 7)
        self.assertEqual(r["kept"]["line"], 15)
        # next free number: above the entries (30) and the heading range (..30)
        self.assertEqual(r["new"], "31")

    def test_undated_falls_back_to_blame_then_order(self):
        text = "- [ ] TODO-2: **Aaaaaaaaaaaaaa.**\n- [ ] TODO-2: **Bbbbbbbbbbbbbb.**\n"
        items = ts.parse_checkboxes(text, REL)
        self.assertEqual(tt.plan_renumber(items, text)[0]["item"]["line"], 2)
        blame = lambda it: {1: "2026-11-10", 2: "2026-11-01"}[it["line"]]
        p = tt.plan_renumber(items, text, blame)
        self.assertEqual((p[0]["item"]["line"], p[0]["new"], p[0]["date_source"]), (1, "3", "git blame"))

    def test_rewrites_only_provable_references(self):
        new, rw, fl = tt.renumber_text(REL, DUPS, self.plan)
        lines = new.split("\n")
        self.assertTrue(lines[6].startswith("- [ ] TODO-31 (added 2026-11-18"))
        self.assertIn("Found: v1.0.6-TODO-31;", lines[7])
        self.assertIn("v1.1.0-TODO-7 (another release)", lines[8])             # other release: untouched
        self.assertEqual(lines[9].strip()[:6], "TODO-7")                        # other file: untouched
        self.assertIn("v1.0.6 TODO-7 (old style)", lines[9])                    # old style: never rewritten
        self.assertEqual(lines[11], "    - TODO-7: a plan's own TODO, not this entry.")   # nested lead
        self.assertIn("this is TODO-31.", lines[12])
        self.assertTrue(lines[14].startswith("- [ ] TODO-7 (added 2026-11-02"))  # kept
        self.assertIn("Cites TODO-7 about itself.", lines[15])
        self.assertIn("Status: v1.0.6-TODO-31 (", new)                          # names the title
        self.assertIn("Elsewhere: TODO-7 is mentioned", new)                    # ambiguous: left
        whys = {(f["line"], f["why"].split(",")[0].split(":")[0]) for f in fl}
        self.assertIn((10, "inside renumbered TODO-7 -> TODO-31"), whys)        # old style, listed
        self.assertIn((12, "inside renumbered TODO-7 -> TODO-31"), whys)        # nested lead, listed
        elsewhere = DUPS.split("\n").index("Elsewhere: TODO-7 is mentioned without context.") + 1
        self.assertIn((elsewhere, "ambiguous"), whys)
        self.assertEqual(len(new.split("\n")), len(DUPS.split("\n")))
        self.assertEqual(sum(a != b for a, b in zip(new.split("\n"), DUPS.split("\n"))), 4)

    def test_dedup_then_reorder(self):
        new, _, _ = tt.renumber_text(REL, DUPS, self.plan)
        out, runs = tt.reorder_text(REL, new)
        self.assertEqual([t for t in todos(out)], ["TODO-5", "TODO-5", "TODO-7", "TODO-30", "TODO-31"])
        self.assertEqual(Counter(out.split("\n")), Counter(new.split("\n")))
        self.assertEqual(tt.duplicate_groups(ts.parse_checkboxes(out, REL)), {})


def git(repo, *args, date=None):
    env = dict(os.environ, GIT_AUTHOR_NAME="t", GIT_AUTHOR_EMAIL="t@x", GIT_COMMITTER_NAME="t",
               GIT_COMMITTER_EMAIL="t@x")
    if date:
        env.update(GIT_AUTHOR_DATE=date, GIT_COMMITTER_DATE=date)
    return subprocess.run(["git", *args], cwd=repo, check=True, capture_output=True, text=True, env=env).stdout


class RepoReferences(unittest.TestCase):
    """References in other files: rewritten only in a file the renumbered entry introduced."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.repo = Path(self.tmp.name)
        git(self.repo, "init", "-q", "-b", "main")
        (self.repo / "R/EDI/tests/testthat").mkdir(parents=True)
        (self.repo / "R/package_metadata/future_release_plans").mkdir(parents=True)
        (self.repo / "R/EDI/DESCRIPTION").write_text("Package: EDI\nVersion: 1.0.5\n")
        (self.repo / "R/EDI/NEWS.md").write_text("* Fixed v1.0.6-TODO-7.\n* Old: v1.0.6 TODO-7.\n"
                                                  "* Other: v1.1.0-TODO-7.\n")
        (self.repo / REL).write_text(DUPS)
        git(self.repo, "add", "-A")
        git(self.repo, "commit", "-qm", "base: v1.0.6-TODO-7 started", date="2026-11-01T00:00:00Z")
        (self.repo / "R/EDI/tests/testthat/test-later-thing.R").write_text(
            "# v1.0.6-TODO-7: the later thing\ntest_that('x', { expect_true(TRUE) })  # TODO-7\n")
        git(self.repo, "add", "-A")
        git(self.repo, "commit", "-qm", "add test", date="2026-11-18T00:00:00Z")

    def tearDown(self):
        self.tmp.cleanup()

    def test_tidy_files(self):
        res = tt.tidy_files(str(self.repo), [REL])
        test = "R/EDI/tests/testthat/test-later-thing.R"
        self.assertIn(test, res["files"])
        self.assertIn("# v1.0.6-TODO-31: the later thing", res["files"][test])
        self.assertIn("# TODO-7", res["files"][test])            # bare: not grepped outside the release file
        self.assertNotIn("R/EDI/NEWS.md", res["files"])
        rep = res["report"][0]
        flagged = {(f["file"], f["why"].split(":")[0]) for f in rep["flagged"]}
        self.assertIn(("R/EDI/NEWS.md", "ambiguous"), flagged)
        self.assertIn(("R/EDI/NEWS.md", "old-style reference, never rewritten"), flagged)
        self.assertFalse(any("v1.1.0" in f["text"] for f in rep["flagged"]))
        self.assertEqual(rep["commits"][0]["count"], 1)
        applied, human, info = tt.summarise(res)
        self.assertTrue(any("renumbered to TODO-31" in a for a in applied))
        self.assertTrue(all(isinstance(h, dict) and h["unit"] for h in human))
        self.assertTrue(any("1 commit(s)" in i for i in info))
        # nothing was written
        self.assertEqual((self.repo / REL).read_text(), DUPS)

    def test_audit_hook_commits_tidy_separately(self):
        import audit_common as ac
        ctx = ac.Context(ac.spec_of(ts), str(self.repo), ac.Notes(self.tmp.name + "/notes", "todo-status"),
                         self.tmp.name + "/work")
        old = os.environ.get("AUDIT_TIDY")
        try:
            os.environ["AUDIT_TIDY"] = "0"
            self.assertEqual(audit_run.run_tidy(ts, ctx, commit=True), {})
            os.environ["AUDIT_TIDY"] = "1"
            t = audit_run.run_tidy(ts, ctx, commit=True)
        finally:
            if old is None:
                os.environ.pop("AUDIT_TIDY", None)
            else:
                os.environ["AUDIT_TIDY"] = old
        self.assertTrue(t["committed"])
        self.assertEqual(git(self.repo, "status", "--porcelain").strip(), "")
        self.assertIn("mechanical tidy", git(self.repo, "log", "-1", "--format=%s"))
        self.assertIn("TODO-31 (added 2026-11-18", (self.repo / REL).read_text())
        # The agents' checkout is not tidied: units carry where the entry is there.
        where = ts._TIDY[str(self.repo)]
        self.assertEqual(where[f"{REL}::TODO-31"], {"checkout_line": 7, "checkout_todo": "TODO-7"})


if __name__ == "__main__":
    unittest.main()
