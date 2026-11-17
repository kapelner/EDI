#!/usr/bin/env python3
"""Checks for the results-freshness audit (.github/scripts/audits/results_freshness.py). Stdlib only."""
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import audit_common as ac  # noqa: E402
from audits import results_freshness as rf  # noqa: E402

PT = "R/package_tests"
SIZE = ("inference_class,design,prob_T,response_type,beta_T,function_run,size,n_size,bonf_size_pval\n"
        "InferenceCountFoo (model_formula=~.) [design_formula=~1],Bernoulli,0.5,count,0,compute_x,0.05,100,1\n"
        "InferenceCountFoo (model_formula=~1) [design_formula=~1],Bernoulli,0.5,count,0,compute_x,0.05,100,1\n"
        "InferenceCountBar,Bernoulli,0.5,count,0,compute_x,0.05,100,1\n"
        "InferenceContinBaz,Bernoulli,0.5,continuous,0,compute_x,0.05,100,1\n")
CAL = ('"response_type","design","prob_T","inf_class","formula","n"\n'
       '"count","DesignFixedBernoulli",0.5,"InferenceCountFoo","~.",50\n')


class Freshness(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.repo = self.tmp / "repo"
        files = {
            "R/EDI/R/inference_all_abstract_base.R": 'InferenceBase = R6::R6Class("InferenceBase",\n\tpublic = list())\n',
            "R/EDI/R/inference_count_foo.R": 'InferenceCountFoo = define_inference_class(\n\tclassname = "InferenceCountFoo",\n\tinherit = InferenceBase,\n)\n',
            "R/EDI/R/inference_count_bar.R": 'InferenceCountBar = define_inference_class(\n\tclassname = "InferenceCountBar",\n\tinherit = Inference,\n)\n',
            "R/EDI/R/inference_continuous_baz.R": 'InferenceContinBaz = define_inference_class(\n\tclassname = "InferenceContinBaz",\n)\n',
            "R/EDI/src/fast_poisson_regression.cpp": "int poisson() { return 1; }\n",
            "R/EDI/DESCRIPTION": "Version: 1.0.4\n",
            f"{PT}/comprehensive_tests_size.csv": SIZE,
        }
        for p, t in files.items():
            self.write(p, t)
        self.git("init", "-q", "-b", "main")
        self.git("config", "user.email", "t@t")
        self.git("config", "user.name", "t")
        self.git("add", "-A")
        self.git("commit", "-qm", "results")
        self.gen = self.git("rev-parse", "HEAD").strip()
        spec = ac.spec_of(rf)
        self.ctx = ac.Context(spec, self.repo, ac.Notes(self.tmp / "notes", spec["name"]), self.tmp / "work")

    def write(self, p, t):
        (self.repo / p).parent.mkdir(parents=True, exist_ok=True)
        (self.repo / p).write_text(t)

    def git(self, *a):
        return subprocess.run(["git", *a], cwd=self.repo, check=True, capture_output=True, text=True).stdout

    def commit(self, p, t, msg="change"):
        self.write(p, t)
        self.git("add", "-A")
        self.git("commit", "-qm", msg)

    def found(self):
        return {(f["kind"], f["unit"].split("::", 1)[1]): f["text"] for f in rf.mechanical(self.ctx)}

    def test_fresh_and_comment_only(self):
        self.assertEqual(self.found(), {})
        self.commit("R/EDI/R/inference_count_foo.R",
                    (self.repo / "R/EDI/R/inference_count_foo.R").read_text() + "# a comment\n\n")
        self.commit("R/EDI/DESCRIPTION", "Version: 1.0.5\n")           # build files are not class changes
        self.assertEqual(self.found(), {})

    def test_class_and_ancestor_changes(self):
        self.commit("R/EDI/R/inference_all_abstract_base.R",
                    'InferenceBase = R6::R6Class("InferenceBase",\n\tpublic = list(x = 1))\n')
        f = self.found()
        self.assertIn(("stale-class", "InferenceCountFoo::count"), f)    # inherits the changed base
        t = f[("stale-class", "InferenceCountFoo::count")]
        self.assertIn("2 rows", t)                                       # both formula variants of the class
        self.assertIn("the file's last commit", t)
        self.assertIn("'^InferenceCountFoo'", t)
        self.assertNotIn(("stale-class", "InferenceCountBar::count"), f)
        # inference_all_* is shared code for every family (benchmark_gate's rule): family-wide elsewhere.
        self.assertIn(("stale-family", "family::continuous"), f)

    def test_kernel_change_is_family_wide(self):
        self.commit("R/EDI/src/fast_poisson_regression.cpp", "int poisson() { return 2; }\n")
        f = self.found()
        self.assertEqual(set(f), {("stale-family", "family::count")})
        t = f[("stale-family", "family::count")]
        self.assertIn("fast_poisson_regression.cpp", t)
        self.assertIn("InferenceCountBar", t)
        self.assertIn("InferenceCountFoo", t)

    def test_other_class_file_is_not_family_wide(self):
        self.commit("R/EDI/R/inference_count_bar.R",
                    'InferenceCountBar = define_inference_class(\n\tclassname = "InferenceCountBar", x = 2,\n)\n')
        f = self.found()
        self.assertEqual(set(f), {("stale-class", "InferenceCountBar::count")})

    def test_calibration_campaign(self):
        self.git("checkout", "-q", "--orphan", "cal")
        self.git("rm", "-rq", "--cached", ".")
        camp = self.repo / "campaigns/2026-11-15-abc"
        (camp / "summary").mkdir(parents=True)
        (camp / "campaign.env").write_text(f"SHA={self.gen}\nSTARTED=2026-11-15T17:22Z\n")
        (camp / "summary/calibration_summary.csv").write_text(CAL)
        self.git("add", "campaigns")
        self.git("commit", "-qm", "campaign")
        self.git("update-ref", "refs/remotes/origin/calibration-results", "HEAD")
        self.git("checkout", "-q", "-f", "main")
        self.commit("R/EDI/R/inference_count_foo.R",
                    'InferenceCountFoo = define_inference_class(\n\tclassname = "InferenceCountFoo", y = 1,\n'
                    '\tinherit = InferenceBase,\n)\n')
        f = self.found()
        key = ("stale-class", "InferenceCountFoo::count")
        texts = [t for (k, u), t in f.items() if k == "stale-class"]
        self.assertTrue(any("calibration-results:campaigns/2026-11-15-abc" in t and "--only InferenceCountFoo" in t
                            for t in [f[key]] + texts + [x["text"] for x in rf.mechanical(self.ctx)]))
        self.assertEqual(rf.apply(self.ctx, [], [])["applied"], [])

    def test_unknown_generation_commit(self):
        self.git("checkout", "-q", "--orphan", "cal")
        self.git("rm", "-rq", "--cached", ".")
        (self.repo / "campaigns/c1/summary").mkdir(parents=True)
        (self.repo / "campaigns/c1/campaign.env").write_text("SHA=" + "ab" * 20 + "\n")
        (self.repo / "campaigns/c1/summary/calibration_summary.csv").write_text(CAL)
        self.git("add", "campaigns")
        self.git("commit", "-qm", "campaign")
        self.git("update-ref", "refs/remotes/origin/calibration-results", "HEAD")
        self.git("checkout", "-q", "-f", "main")
        self.assertIn("unknown-commit", [f["kind"] for f in rf.mechanical(self.ctx)])


if __name__ == "__main__":
    unittest.main(verbosity=1)
