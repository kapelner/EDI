#!/usr/bin/env python3
"""Checks for the TODO-status audit (.github/scripts/audits/todo_status.py). Stdlib only.

The fixtures are short, anonymised fragments in the format of the real release and plan files.
"""
import datetime as dt
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import audit_common as ac  # noqa: E402
from audits import todo_status as ts  # noqa: E402

NOW = dt.datetime(2026, 11, 18, 6, tzinfo=dt.timezone.utc)
REL = "R/package_metadata/future_release_plans"

V106 = """# Release Scope: v1.0.6

> **Status: APPROVED 2026-11-10 (owner).** A bug-fix release.

## Implementation TODOs

- [ ] TODO-1 (moved 2026-11-10 from `release_v1_1_0.md → TODO-74`, owner approval; originally added
  2026-10-23, user decision):
  **The jackknife depends on call history.** *(reproducibility fix)*
  - Problem: `approx_jack()` (`R/EDI/R/inference_jack.R`) refits on a duplicate.

  - Work:
    1. Make the refits independent of prior state.
    2. Test: extend `test-jack-history.R`.

- [ ] ~~TODO-8~~ **→ moved back 2026-11-11 to `release_v1_1_0.md → TODO-170`** (owner): no bug.

- [ ] TODO-9 (added 2026-11-09, owner): **Boundary MLEs of `InferenceIncidFoo`.**
  - [x] TODO-9a: make Wald NA at the boundary.
  - [ ] TODO-9b: LR is still oversized.

```
- [ ] TODO-99: inside a code fence, not an item
```

- [ ] TODO-10: a short one.
## Gates

| Gate | State |
|---|---|
| G1 | open |
"""

V105 = """# Release Scope: v1.0.5

> **Status: CLOSED to new TODOs (owner, 2026-11-12): soon to be released.** New work goes to v1.0.6.

- [x] TODO-1 (added 2026-08-27; CLOSED 2026-11-10 by owner, see the closing decision below): **Reusable workers.**
  - **DECIDED 2026-11-10 (owner), TODO-1 CLOSED:** completed, default kept.
- [x] TODO-2 (added 2026-08-30, user decision): **Randomization CI.**
  - Done when: `R/EDI/R/inference_jack.R` exists.
- [ ] ~~TODO-4~~ **→ moved 2026-08-27 to `release_v1_2_0.md
  → TODO-1..3`** — **Kernel lane**.
"""

V110 = """# Release Scope: v1.1.0

In scope: `cold_starts.md` and `../new_feature_plans/v1_1_0/multi_arm.md`.

- [ ] ~~TODO-74~~ **→ moved 2026-11-10 to `release_v1_0_6.md → TODO-1`** (owner approval): jackknife.
- [ ] TODO-170: small-sample excess at n = 50.
- [ ] ~~TODO-17m~~ **→ moved 2026-09-06 to `release_v1_2_0.md → TODO-18`**: `missing_plan.md → TODO-1`.
"""

V120 = """# Release Scope: v1.2.0 — Performance

- [ ] TODO-1: kernel A.
- [x] TODO-2: kernel B.
- [ ] TODO-3: kernel C.
"""

V100 = """# Release Scope: v1.0.0 (CRAN)

- [x] TODO-1: shipped long ago.
"""

COLD = """# Cold starts

- [x] TODO-4: cold-start refits.
- [ ] TODO-5: warm-start chaining.
"""

MULTI = """# Multi-arm designs

  - [x] TODO-1a: drop get_w().
  - [ ] TODO-1b: integer storage.
- [ ] TODO-2: arm selection.
"""


def git(repo, *a):
    return subprocess.run(["git", *a], cwd=repo, check=True, capture_output=True, text=True).stdout


def make_repo():
    tmp = Path(tempfile.mkdtemp())
    repo = tmp / "repo"
    files = {
        "R/EDI/DESCRIPTION": "Package: EDI\nVersion: 1.0.4\n",
        "R/EDI/R/inference_jack.R": "x = 1\n" * 30,
        "R/EDI/R/inference_incid_foo.R": 'InferenceIncidFoo = define_inference_class(\n\tclassname = "InferenceIncidFoo",\n)\n',
        "R/EDI/tests/testthat/test-jack-history.R": 'test_that("jackknife ignores call history", {})\n',
        f"{REL}/release_v1_0_0.md": V100,
        f"{REL}/release_v1_0_5.md": V105,
        f"{REL}/release_v1_0_6.md": V106,
        f"{REL}/release_v1_1_0.md": V110,
        f"{REL}/release_v1_2_0.md": V120,
        "R/package_metadata/new_feature_plans/v1_1_0/cold_starts.md": COLD,
        "R/package_metadata/new_feature_plans/v1_1_0/multi_arm.md": MULTI,
        "R/package_metadata/finished_features/v1_0_0/old.md": "- [ ] TODO-1: out of scope\n",
    }
    for p, t in files.items():
        (repo / p).parent.mkdir(parents=True, exist_ok=True)
        (repo / p).write_text(t)
    git(repo.parent, "init", "-q", "-b", "main", str(repo))
    git(repo, "config", "user.email", "t@t")
    git(repo, "config", "user.name", "t")
    git(repo, "add", "-A")
    git(repo, "commit", "-qm", "start")
    (repo / "R/EDI/R/inference_jack.R").write_text("x = 2\n" * 30)
    git(repo, "commit", "-qam", "v1.0.6 TODO-1: make jackknife refits history-free")
    sha = git(repo, "rev-parse", "--short", "HEAD").strip()
    return tmp, repo, sha


def ctx_for(tmp, repo):
    spec = ac.spec_of(ts)
    notes = ac.Notes(tmp / "notes", spec["name"])
    (tmp / "work").mkdir(exist_ok=True)
    ts._CACHE.clear()
    return ac.Context(spec, repo, notes, tmp / "work", now=NOW)


class Parser(unittest.TestCase):
    def items(self, text=V106):
        return {it["id"].split("::")[1]: it for it in ts.parse_checkboxes(text, "f.md")}

    def test_spans_continuation_and_blank_lines(self):
        it = self.items()["TODO-1"]
        self.assertEqual(it["line"], 7)
        self.assertIn("2. Test: extend", it["text"])           # across the blank line inside the item
        self.assertNotIn("TODO-8", it["text"])
        self.assertFalse(it["checked"])

    def test_nested_checkboxes_belong_to_their_item(self):
        its = self.items()
        self.assertIn("TODO-9a", its["TODO-9"]["text"])
        self.assertNotIn("TODO-9a", its)

    def test_fence_and_heading(self):
        its = self.items()
        self.assertNotIn("TODO-99", its)
        self.assertEqual(its["TODO-10"]["text"], "- [ ] TODO-10: a short one.")   # stops at the heading
        self.assertEqual(sorted(its), ["TODO-1", "TODO-10", "TODO-8", "TODO-9"])

    def test_pointer_detection(self):
        its = self.items()
        self.assertTrue(its["TODO-8"]["pointer"])
        self.assertEqual(its["TODO-8"]["targets"], [("release_v1_1_0.md", "170")])
        self.assertFalse(its["TODO-1"]["pointer"])            # "moved ... from" in the text is not a pointer
        p = self.items(V105)["TODO-4"]
        self.assertEqual(p["targets"], [("release_v1_2_0.md", str(n)) for n in (1, 2, 3)])  # range, line break

    def test_owner_closed_detection(self):
        its = self.items(V105)
        self.assertTrue(its["TODO-1"]["owner_closed"])
        self.assertFalse(its["TODO-2"]["owner_closed"])
        for text, want in (("- [x] TODO-3: CLOSED 2026-10-22 by owner decision (G6 #2).", True),
                           ("- [x] TODO-3: owner decision 2026-10-31: done on existing evidence.", True),
                           ("- [x] TODO-3: closed 2026-10-08 after re-audit.", False),
                           ("- [x] TODO-3: the fail-closed guard is kept.", False)):
            self.assertEqual(ts.parse_checkboxes(text, "f.md")[0]["owner_closed"], want, text)

    def test_unnumbered_and_duplicate_ids(self):
        its = ts.parse_checkboxes("- [ ] Rerun the matrix\n- [ ] TODO-2: a\n- [ ] TODO-2: b\n", "f.md")
        self.assertTrue(its[0]["id"].startswith("f.md::cb-"))
        self.assertEqual([i["id"] for i in its[1:]], ["f.md::TODO-2", "f.md::TODO-2#2"])

    def test_audit_note_does_not_change_the_id(self):
        a = ts.parse_checkboxes("- [ ] Rerun the matrix\n", "f.md")[0]["id"]
        b = ts.parse_checkboxes("- [x] Rerun the matrix *(ticked by the TODO audit 2026-11-18: abc1234)*\n",
                                "f.md")[0]["id"]
        self.assertEqual(a, b)


class Releases(unittest.TestCase):
    def test_released_and_split(self):
        tmp, repo, _ = make_repo()
        st = ts.load_todo_state(repo)
        rel = {r["label"]: r for r in st["releases"]}
        self.assertTrue(rel["v1.0.0"]["released"])
        self.assertFalse(rel["v1.0.5"]["released"])            # above DESCRIPTION's 1.0.4
        self.assertTrue(rel["v1.0.5"]["closed_to_new"])
        self.assertEqual(st["current"]["label"], "v1.0.6")
        self.assertEqual(st["next"]["label"], "v1.1.0")
        self.assertEqual(st["opus"], {(1, 0, 5), (1, 0, 6), (1, 1, 0)})
        self.assertTrue(st["in_scope"]["R/package_metadata/new_feature_plans/v1_1_0/cold_starts.md"])
        self.assertFalse(st["in_scope"][f"{REL}/release_v1_0_0.md"])
        self.assertNotIn("R/package_metadata/finished_features/v1_0_0/old.md", st["in_scope"])

    def test_status_line_wins(self):
        r = ts.release_state(".", "release_v1_0_3.md", "> **Status: soon to be released.**\n", (1, 0, 4))
        self.assertFalse(r["released"])
        r = ts.release_state(".", "release_v1_0_9.md", "> **Status: RELEASED 2026-12-01.**\n", (1, 0, 4))
        self.assertTrue(r["released"])


class Citations(unittest.TestCase):
    def test_forms(self):
        c = ts.citations("v1.0.6-TODO-38 / TODO-43: x\n\nalso v1.0.5 TODO-7 and cold_starts.md TODO-3, "
                         "release_v1_1_0.md → TODO-157")
        self.assertEqual(c, {("release_v1_0_6.md", "38"), ("release_v1_0_6.md", "43"),
                             ("release_v1_0_5.md", "7"), ("cold_starts.md", "3"),
                             ("release_v1_1_0.md", "157")})
        self.assertNotIn(("release_v1_0_6.md", "4"), ts.citations("v1.0.6 TODO-43"))


class Units(unittest.TestCase):
    def test_units_context_model_and_cycles(self):
        tmp, repo, sha = make_repo()
        ctx = ctx_for(tmp, repo)
        u = ts.units(ctx)
        k = f"{REL}/release_v1_0_6.md::TODO-1"
        self.assertEqual(u[k]["model"], ac.OPUS)
        self.assertEqual(u[k]["cycle_weeks"], 4)
        self.assertEqual(u[f"{REL}/release_v1_2_0.md::TODO-1"]["model"], ac.SONNET)
        self.assertEqual(u[f"{REL}/release_v1_2_0.md::TODO-1"]["cycle_weeks"], 12)
        self.assertEqual(u[f"{REL}/release_v1_0_5.md::TODO-2"]["cycle_weeks"], 12)   # ticked
        self.assertNotIn(f"{REL}/release_v1_0_6.md::TODO-8", u)                   # pointer
        self.assertFalse(any("release_v1_0_0" in x or "finished_features" in x for x in u))
        c = u[k]["context"]
        self.assertEqual([x["sha"] for x in c["citing_commits"]], [sha])
        self.assertTrue((tmp / "work" / "commits" / f"{sha}.diff").exists())
        paths = {n["path"]: n for n in c["named_files"]}
        self.assertTrue(paths["R/EDI/R/inference_jack.R"]["exists"])
        self.assertTrue(paths["R/EDI/tests/testthat/test-jack-history.R"]["exists"])
        foo = u[f"{REL}/release_v1_0_6.md::TODO-9"]["context"]["named_files"]
        self.assertEqual(foo[0]["path"], "R/EDI/R/inference_incid_foo.R")          # class -> file
        # A named file changing moves the dependency hash.
        before = u[k]["deps"]
        (repo / "R/EDI/R/inference_jack.R").write_text("x = 3\n")
        git(repo, "commit", "-qam", "unrelated")
        ts._CACHE.clear()
        self.assertNotEqual(ts.units(ctx)[k]["deps"], before)

    def test_mechanical_pointers(self):
        tmp, repo, _ = make_repo()
        m = ts.mechanical(ctx_for(tmp, repo))
        kinds = {(f["unit"].split("::")[1], f["kind"]) for f in m}
        self.assertIn(("TODO-4", "pointer-target-ticked"), kinds)        # release_v1_2_0 TODO-2 is ticked
        self.assertIn(("TODO-17m", "pointer-target-missing"), kinds)     # release_v1_2_0 has no TODO-18
        self.assertNotIn(("TODO-8", "pointer-target-missing"), kinds)    # TODO-170 exists
        texts = " ".join(f["text"] for f in m)
        self.assertNotIn("missing_plan.md", texts.replace("`", ""))      # only the pointer's own targets


class Apply(unittest.TestCase):
    def setUp(self):
        self.tmp, self.repo, self.sha = make_repo()
        self.ctx = ctx_for(self.tmp, self.repo)
        self.f106 = self.repo / REL / "release_v1_0_6.md"
        self.f105 = self.repo / REL / "release_v1_0_5.md"

    def run_apply(self, findings, units):
        return ts.apply(self.ctx, [{"units_checked": units, "findings": findings, "_batch": "b001",
                                    "_units": units}], [])

    def done(self, unit, refs):
        return {"unit": unit, "kind": "done", "text": "All parts landed.", "searched": [], "gap": "",
                "parts": [{"part": f"part {i}", "status": "done", "evidence": [{"ref": r, "what": "x"}]}
                          for i, r in enumerate(refs)]}

    def test_tick_with_evidence(self):
        u = f"{REL}/release_v1_0_6.md::TODO-1"
        before = self.f106.read_text()
        parts = self.run_apply([self.done(u, [self.sha, "R/EDI/R/inference_jack.R:3", "test-jack-history.R"])], [u])
        after = self.f106.read_text()
        line = after.splitlines()[6]
        self.assertTrue(line.startswith("- [x] TODO-1 (moved 2026-11-10"))
        self.assertIn(f"*(ticked by the TODO audit 2026-11-18: {self.sha}; R/EDI/R/inference_jack.R:3; "
                      "test-jack-history.R)*", line)
        # Only the box and the note changed: the original text is intact.
        b = before.splitlines()
        note = parts["proposed"][0]["applied_text"]
        b[6] = b[6].replace("- [ ]", "- [x]", 1) + " " + note
        self.assertEqual(after, "\n".join(b) + "\n")
        self.assertEqual(len(parts["applied"]), 1)
        p = parts["proposed"][0]
        self.assertEqual(p["applied_file"], f"{REL}/release_v1_0_6.md")
        self.assertIn(p["applied_text"], after)

    def test_no_tick_without_verified_evidence(self):
        u = f"{REL}/release_v1_0_6.md::TODO-1"
        before = self.f106.read_text()
        for refs in (["deadbeef"], ["R/EDI/R/inference_jack.R:999"], ["R/EDI/R/nope.R"], []):
            parts = self.run_apply([self.done(u, refs) if refs else
                                    {**self.done(u, ["x"]), "parts": [{"part": "p", "status": "done", "evidence": []}]}],
                                   [u])
            self.assertEqual(self.f106.read_text(), before, refs)
            self.assertEqual(parts["applied"], [])
            self.assertIn("not ticked", ac.texts(parts["human"])[0])
        f = self.done(u, [self.sha])
        f["parts"].append({"part": "rest", "status": "not done", "evidence": []})
        self.assertEqual(self.run_apply([f], [u])["applied"], [])

    def test_unit_outside_the_batch_is_ignored(self):
        u = f"{REL}/release_v1_0_6.md::TODO-1"
        before = self.f106.read_text()
        ts.apply(self.ctx, [{"findings": [self.done(u, [self.sha])], "_units": ["other"]}], [])
        self.assertEqual(self.f106.read_text(), before)

    def test_pointer_is_never_ticked(self):
        u = f"{REL}/release_v1_0_6.md::TODO-8"
        before = self.f106.read_text()
        parts = self.run_apply([self.done(u, [self.sha])], [u])
        self.assertEqual(self.f106.read_text(), before)
        self.assertIn("pointer", ac.texts(parts["human"])[0])

    def test_untick_and_owner_closed(self):
        u2 = f"{REL}/release_v1_0_5.md::TODO-2"
        u1 = f"{REL}/release_v1_0_5.md::TODO-1"
        und = lambda u: {"unit": u, "kind": "undone", "text": "gone", "parts": [], "searched": [],
                         "gap": "the CI test was deleted in abc1234"}
        parts = self.run_apply([und(u2), und(u1)], [u1, u2])
        lines = self.f105.read_text().splitlines()
        t2 = next(l for l in lines if "TODO-2 (added" in l)
        t1 = next(l for l in lines if "TODO-1 (added" in l)
        self.assertTrue(t2.startswith("- [ ] TODO-2"))
        self.assertIn("*(unticked by the TODO audit 2026-11-18: the CI test was deleted in abc1234)*", t2)
        self.assertTrue(t1.startswith("- [x] TODO-1"))                   # owner closed it: never unticked
        self.assertEqual(len(parts["applied"]), 1)
        self.assertIn("owner closed", ac.texts(parts["human"])[0])

    def test_partly_done_and_changed_verdicts(self):
        u1 = f"{REL}/release_v1_0_6.md::TODO-1"
        u10 = f"{REL}/release_v1_0_6.md::TODO-10"
        before = self.f106.read_text()
        f1 = {"unit": u1, "kind": "partly done", "text": "Step 1 landed.", "searched": [], "gap": "",
              "parts": [{"part": "refits", "status": "done", "evidence": [{"ref": self.sha, "what": "x"}]},
                        {"part": "test", "status": "not done", "evidence": []}]}
        f10 = {"unit": u10, "kind": "not done", "text": "Nothing found.", "parts": [], "searched": ["grep"],
               "gap": ""}
        parts = self.run_apply([f1, f10], [u1, u10])
        self.assertEqual(self.f106.read_text(), before)
        self.assertEqual(ac.texts(parts["human"]), [])                # verdicts and progress: information only
        self.assertEqual(len(parts["info"]), 2)
        self.assertIn("not done", parts["info"][0])        # short changed verdicts come first
        self.assertIn("partly done", parts["info"][1])
        self.assertIn(self.sha, parts["info"][1])
        # The same `not done` next week is not listed again; partly done still is.
        parts = self.run_apply([f1, f10], [u1, u10])
        self.assertEqual(len(parts["info"]), 1)
        saved = json.loads((self.ctx.notes.dir / "verdicts.json").read_text())
        self.assertEqual(saved[u10]["verdict"], "not done")

    def test_unclear_verdict_is_a_decision_every_run(self):
        u10 = f"{REL}/release_v1_0_6.md::TODO-10"
        f10 = {"unit": u10, "kind": "unclear", "text": "Cannot tell.", "parts": [], "searched": [], "gap": ""}
        for _ in range(2):                                   # listed again on the next run, not just once
            parts = self.run_apply([f10], [u10])
            self.assertEqual([(d["unit"], d["key"]) for d in parts["human"]], [(u10, "unclear")])
            self.assertEqual(parts["info"], [])

    def test_report_over_the_body_limit_keeps_changed_verdicts(self):
        # Run 44048336759 (2026-11-17): 69 `partly done` lines of ~1,000 characters plus 41 changed
        # `not done` / `unclear` lines made a 94,359-character report, and `gh pr create` failed with
        # "Body is too long (maximum is 65536 characters)". The body is now cut to fit, and the cut
        # (from the end) must fall on the long `partly done` lines, not on the changed verdicts.
        u1 = f"{REL}/release_v1_0_6.md::TODO-1"
        u10 = f"{REL}/release_v1_0_6.md::TODO-10"
        long_part = {"part": "p " + "y" * 150, "status": "not done",
                     "evidence": [{"ref": "R/EDI/R/inference_jack.R:" + str(i), "what": "x"} for i in range(4)]}
        partly = {"unit": u1, "kind": "partly done", "text": "Partly. " + "z" * 390, "searched": [], "gap": "",
                  "parts": [long_part] * 4}
        notdone = lambda i: {"unit": u10, "kind": "not done", "text": f"NOTDONE-{i} " + "w" * 300,
                             "parts": [], "searched": [], "gap": ""}
        findings = [partly] * 69 + [notdone(i) for i in range(41)]
        parts = self.run_apply(findings, [u1, u10])
        spec = {"title": "TODO-status audit"}
        report = ac.render_report(spec, parts, {"units in scope": 2054}, "https://run")
        self.assertGreater(len(report), 65536)                 # the failing size
        body = ac.fit_body(report, "https://run")
        self.assertLessEqual(len(body), 65536)
        for i in range(41):
            self.assertIn(f"NOTDONE-{i} ", body)
        self.assertIn("more line(s) not shown", body)
        self.assertIn("units in scope: 2054", body)

    def test_hash_ignores_the_tick(self):
        u = f"{REL}/release_v1_0_6.md::TODO-1"
        h1 = ts.units(self.ctx)[u]["hash"]
        self.run_apply([self.done(u, [self.sha])], [u])
        ts._CACHE.clear()
        self.assertEqual(ts.units(self.ctx)[u]["hash"], h1)


if __name__ == "__main__":
    unittest.main(verbosity=1)
