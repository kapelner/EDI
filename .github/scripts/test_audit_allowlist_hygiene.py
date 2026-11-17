#!/usr/bin/env python3
"""Checks for the allowlist-hygiene audit (.github/scripts/audits/allowlist_hygiene.py). Stdlib only."""
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import audit_common as ac  # noqa: E402
from audits import allowlist_hygiene as ah  # noqa: E402

REL = "R/package_metadata/future_release_plans"
PT = "R/package_tests"

CAL = ('"response_type","design","prob_T","inf_class","inf_procedure","formula","n","metric","accepted_level","reason"\n'
       '"incidence","DesignFixedBernoulli",0.5,"InferenceIncidFoo","wald","~.",50,"size",0.09,"v1.0.5 TODO-168: ticked, goes"\n'
       '"incidence","DesignFixedBernoulli",0.5,"InferenceIncidFoo","wald","~.",50,"coverage",0.91,"v1.1 TODO-173: open, stays"\n'
       '"incidence","DesignFixedBernoulli",0.5,"InferenceIncidFoo","lr","~.",50,"size",0.09,"v1.1 TODO-999: missing, goes"\n'
       '"incidence","DesignFixedBernoulli",0.5,"InferenceIncidGone","lr","~.",50,"size",0.09,"v1.1 TODO-173: class gone"\n'
       '"incidence","DesignFixedBernoulli",0.5,"InferenceIncidFoo","score","~.",50,"size",0.09,"v1.1 TODO-74: moved"\n'
       '"incidence","DesignFixedBernoulli",0.5,"InferenceIncidFoo","rand","~.",50,"size",0.09,"no citation at all"\n')
FAST = ('"response_type","design","prob_T","inference_class","method","formula","n","metric","accepted_level","reason"\n'
        '"count","DesignFixedBernoulli",0.5,"InferenceIncidFoo","wald","~1",200,"size",0.08,"v1.0.6 TODO-2: open; also TODO-168"\n')
PATHS = ('id,source,class_regex,row_regex,column_regex,kinds,tracked_in,reason,counting_rule_change\n'
         'a_open,*,^IncidFoo$,,.+,row_removed,release_v1_0_6.md:TODO-2,"open",\n'
         'b_ticked,*,^IncidFoo$,,.+,row_removed,release_v1_0_5.md:TODO-168,"ticked, with, commas",\n'
         'c_news,*,^IncidFoo$,,.+,row_removed,NEWS.md:1.0.5,"not a TODO",\n'
         'd_nomatch,*,^NoSuchClass,,.+,row_removed,release_v1_0_6.md:TODO-2,"matches nothing",\n')
STALE = ('response_type,class,function_run,before_timestamp,tracked_in,reason\n'
         'count,IncidFoo,compute_x,2026-09-18,todo:R/package_metadata/future_release_plans/release_v1_0_5.md:TODO-168,"ticked"\n'
         'count,IncidFoo,compute_x,2026-09-18,commit:abc1234,"historical"\n')
HELPER = ('# Tracked as v1.0.5 TODO-168 (release_v1_0_5.md).\n'
          'worker_invariance_known_failures = c("InferenceIncidFoo|incidence|bootstrap_ci")\n')
V105 = "> **Status: CLOSED to new TODOs (owner, 2026-11-12): soon to be released.**\n\n- [x] TODO-168: fixed.\n"
V106 = "- [ ] TODO-2: open.\n"
V110 = ("- [ ] TODO-173: open.\n"
        "- [ ] ~~TODO-74~~ **→ moved 2026-11-10 to `release_v1_0_6.md → TODO-1`** (owner): moved.\n")


class Hygiene(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.repo = self.tmp / "repo"
        files = {
            "R/EDI/DESCRIPTION": "Version: 1.0.4\n",
            "R/EDI/R/inference_incid_foo.R": 'InferenceIncidFoo = define_inference_class(\n\tclassname = "InferenceIncidFoo")\n',
            "R/EDI/R/design_bern.R": 'DesignFixedBernoulli = R6::R6Class("DesignFixedBernoulli")\n',
            "R/EDI/tests/testthat/helper-workers.R": HELPER,
            f"{REL}/release_v1_0_5.md": V105, f"{REL}/release_v1_0_6.md": V106, f"{REL}/release_v1_1_0.md": V110,
            f"{PT}/calibration/calibration_study_accepted.csv": CAL,
            f"{PT}/calibration/calibration_fast_tier_accepted.csv": FAST,
            f"{PT}/path_audits_regression_allowlist.csv": PATHS,
            f"{PT}/stale_ok_row_rules.csv": STALE,
        }
        for p, t in files.items():
            (self.repo / p).parent.mkdir(parents=True, exist_ok=True)
            (self.repo / p).write_text(t)
        run = lambda *a: subprocess.run(["git", *a], cwd=self.repo, check=True, capture_output=True)
        run("init", "-q", "-b", "main")
        run("add", "-A")
        spec = ac.spec_of(ah)
        self.ctx = ac.Context(spec, self.repo, ac.Notes(self.tmp / "notes", spec["name"]), self.tmp / "work")

    def mech(self):
        return [ac.normalise_finding("allowlist-hygiene", f, "mechanical") for f in ah.mechanical(self.ctx)]

    def kinds(self, mech):
        return sorted((f["kind"], f["unit"].split("::")[1]) for f in mech)

    def test_findings(self):
        k = self.kinds(self.mech())
        cal = "incidence / DesignFixedBernoulli / 0.5 / "
        self.assertIn(("todo-ticked", cal + "InferenceIncidFoo / wald / ~. / 50 / size"), k)
        self.assertIn(("todo-missing", cal + "InferenceIncidFoo / lr / ~. / 50 / size"), k)
        self.assertIn(("no-longer-triggers", cal + "InferenceIncidGone / lr / ~. / 50 / size"), k)
        self.assertIn(("todo-moved", cal + "InferenceIncidFoo / score / ~. / 50 / size"), k)
        self.assertIn(("no-citation", cal + "InferenceIncidFoo / rand / ~. / 50 / size"), k)
        self.assertIn(("todo-ticked", "b_ticked"), k)
        self.assertIn(("no-longer-triggers", "d_nomatch"), k)
        self.assertIn(("todo-ticked", "count / IncidFoo / compute_x / 2026-09-18"), k)
        self.assertIn(("embedded-todo-ticked", "worker_invariance_known_failures"), k)
        units = " ".join(u for _, u in k)
        self.assertNotIn("a_open", units)
        self.assertNotIn("c_news", units)                       # NEWS citations are not TODOs
        self.assertNotIn("count / DesignFixedBernoulli", units)  # fast tier: only the leading citation counts

    def test_apply_removes_only_removable_lines(self):
        mech = self.mech()
        parts = ah.apply(self.ctx, [], mech)
        cal = (self.repo / PT / "calibration/calibration_study_accepted.csv").read_text()
        self.assertNotIn("TODO-168: ticked, goes", cal)
        self.assertNotIn("TODO-999", cal)
        self.assertIn("TODO-173: open, stays", cal)
        self.assertIn("class gone", cal)                        # reported, not removed
        self.assertTrue(cal.startswith('"response_type","design"'))   # header and quoting untouched
        self.assertEqual(cal.count("\n"), CAL.count("\n") - 2)
        paths = (self.repo / PT / "path_audits_regression_allowlist.csv").read_text()
        self.assertNotIn("b_ticked", paths)
        self.assertIn("d_nomatch", paths)
        self.assertEqual((self.repo / PT / "stale_ok_row_rules.csv").read_text(), STALE)
        self.assertEqual((self.repo / "R/EDI/tests/testthat/helper-workers.R").read_text(), HELPER)
        self.assertEqual(len(parts["applied"]), 3)
        self.assertTrue(all(p["applied_file"] and p["applied_text"] == "" for p in parts["proposed"]))
        self.assertTrue(any("reclassify" in m for m in parts["mechanical"]))

    def test_rejected_removal_is_not_redone(self):
        mech = self.mech()
        gone = next(f for f in mech if f["unit"].endswith("b_ticked"))
        kept = ac.drop_rejected(mech, [{"id": gone["id"], "status": "rejected"}])
        ah.apply(self.ctx, [], kept)
        self.assertIn("b_ticked", (self.repo / PT / "path_audits_regression_allowlist.csv").read_text())

    def test_multiline_record_is_not_edited(self):
        p = self.repo / PT / "path_audits_regression_allowlist.csv"
        p.write_text(PATHS + 'e,*,^IncidFoo$,,.+,row_removed,release_v1_0_5.md:TODO-168,"two\nlines",\n')
        before = p.read_text()
        mech = self.mech()
        self.assertIn("not-line-safe", [f["kind"] for f in mech])
        ah.apply(self.ctx, [], mech)
        self.assertEqual(p.read_text(), before)

    def test_citation_parsing(self):
        self.assertEqual(ah.release_file("1.1"), "release_v1_1_0.md")
        r = {"cite": "reason-lead"}
        self.assertEqual(ah.citation_of({"reason": "v1.0.6-TODO-26: x"}, r)[:2], ("release_v1_0_6.md", "26"))
        self.assertIsNone(ah.citation_of({"reason": "see v1.1 TODO-3"}, r))
        t = {"cite": "tracked_in"}
        self.assertEqual(ah.citation_of({"tracked_in": "todo:R/x/plan_a.md:TODO-4"}, t)[:2], ("plan_a.md", "4"))
        self.assertIsNone(ah.citation_of({"tracked_in": "commit:abc1234"}, t))


if __name__ == "__main__":
    unittest.main(verbosity=1)
