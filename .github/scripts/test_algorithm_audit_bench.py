#!/usr/bin/env python3
"""Tests for algorithm_audit_bench.py (stdlib only; no R: run_once and compare_results are faked)."""
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import algorithm_audit_bench as ab  # noqa: E402
import compiled_code_verify as cv  # noqa: E402

GOOD = {"finding_id": "cox-ph-fit#1.3", "kind": "pkg", "benchmarkable": True, "packages": ["coxdev"],
        "tier": "iterative", "tol": 1e-6,
        "setup": "bench_setup = function() list(x = 1)",
        "current": "bench_run = function(d) d$x", "candidate": "bench_run = function(d) d$x"}


class SpecTests(unittest.TestCase):

    def test_key_is_artifact_safe(self):
        self.assertEqual(ab.key("cox-ph-fit#43925959437.3"), "cox-ph-fit--43925959437-3")

    def test_spec_problems(self):
        self.assertEqual(ab.spec_problem(GOOD), "")
        self.assertIn("missing candidate", ab.spec_problem(dict(GOOD, candidate="")))
        self.assertIn("needs a numeric tol", ab.spec_problem(dict(GOOD, tol=None)))
        self.assertIn("unknown tier", ab.spec_problem(dict(GOOD, tier="close")))
        self.assertIn("bare CRAN", ab.spec_problem(dict(GOOD, packages=["any::coxdev"])))
        self.assertIn("not benchmarkable", ab.spec_problem(dict(GOOD, benchmarkable=False, why_not="needs C++")))
        self.assertEqual(ab.tolerance(dict(GOOD, tier="closed_form")), cv.FLOAT_TIER)

    def test_plan_lists_only_runnable_specs_with_their_packages(self):
        with tempfile.TemporaryDirectory(dir=os.environ.get("TMPDIR")) as d:
            Path(d, "a.json").write_text(json.dumps(GOOD))
            Path(d, "b.json").write_text(json.dumps(dict(GOOD, finding_id="x#1.1", candidate="")))
            Path(d, "c.json").write_text("{not json")
            out = Path(d, "gh_out")
            ab.main(["plan", "--specs", d, "--github-output", str(out)])
            kv = dict(line.split("=", 1) for line in out.read_text().splitlines())
            m = json.loads(kv["matrix"])
            self.assertEqual(kv["has"], "true")
            self.assertEqual([x["key"] for x in m], ["cox-ph-fit--1-3"])
            self.assertEqual(m[0]["packages"], "any::jsonlite, any::coxdev")


class ClassifyTests(unittest.TestCase):
    T = lambda self, r, lo, hi: {"ratio": r, "lo": lo, "hi": hi, "blocks": 20}

    def test_four_verdicts(self):
        self.assertEqual(ab.classify({"error": "boom"})[0], "not_benchmarked")
        self.assertEqual(ab.classify({"equal": True, "timing": self.T(0.5, 0.45, 0.55)})[0], "faster")
        self.assertEqual(ab.classify({"equal": True, "timing": self.T(0.95, 0.9, 0.97)})[0], "not_faster")
        v, why = ab.classify({"equal": True, "timing": self.T(1.2, 1.1, 1.3)})
        self.assertEqual(v, "not_faster")
        self.assertTrue(why.startswith("slower"))
        self.assertEqual(ab.classify({"equal": False, "equal_detail": "moved", "timing": self.T(0.5, 0.4, 0.6)})[0],
                         "faster_not_equivalent")
        self.assertEqual(ab.classify({"equal": False, "timing": self.T(0.99, 0.9, 1.1)})[0], "not_faster")
        self.assertEqual(ab.classify({"equal": True})[0], "not_benchmarked")


class BenchTests(unittest.TestCase):
    """cmd_bench with the compiled-code audit's helpers, but a fake process runner."""

    def setUp(self):
        self.saved = (cv.run_once, cv.compare_results)
        self.calls = []

        def fake_run(lib, code, outj, rds=None, timeout=900):
            self.calls.append(Path(code).name)
            if rds:
                Path(rds).write_text("x")
            return 1.0 if Path(code).name == "current.R" else 0.5   # candidate twice as fast
        cv.run_once = fake_run
        cv.compare_results = lambda a, b, tol=0: (True, f"OK tol={tol}")
        self.tmp = tempfile.TemporaryDirectory(dir=os.environ.get("TMPDIR"))
        self.d = Path(self.tmp.name)

    def tearDown(self):
        cv.run_once, cv.compare_results = self.saved
        self.tmp.cleanup()

    def run_bench(self, spec, blocks=3):
        Path(self.d, "s.json").write_text(json.dumps(spec))
        ab.main(["bench", "--spec", str(self.d / "s.json"), "--lib", "L", "--work", str(self.d / "w"),
                 "--out", str(self.d / "v.json"), "--blocks", str(blocks)])
        return json.loads(Path(self.d, "v.json").read_text())

    def test_same_build_current_vs_candidate_abba(self):
        v = self.run_bench(GOOD)
        self.assertEqual(v["verdict"], "faster")
        self.assertAlmostEqual(v["timing"]["ratio"], 0.5)
        self.assertEqual(v["equal_detail"], "OK tol=1e-06")
        # two agreement runs, then A B B A per block
        self.assertEqual(self.calls[:2], ["current.R", "candidate.R"])
        self.assertEqual(self.calls[2:6], ["current.R", "candidate.R", "candidate.R", "current.R"])
        w = self.d / "w"
        self.assertIn("bench_setup", (w / "candidate.R").read_text())

    def test_a_failing_side_is_not_benchmarked(self):
        def boom(lib, code, outj, rds=None, timeout=900):
            if Path(code).name == "candidate.R":
                raise RuntimeError("object 'fn' not found")
            return 1.0
        cv.run_once = boom
        v = self.run_bench(GOOD)
        self.assertEqual(v["verdict"], "not_benchmarked")
        self.assertIn("the candidate side fails: object 'fn' not found", v["reason"])

    def test_report_covers_every_spec(self):
        specs = self.d / "specs"
        specs.mkdir()
        Path(specs, "a.json").write_text(json.dumps(GOOD))
        Path(specs, "b.json").write_text(json.dumps(dict(GOOD, finding_id="y#1.1", benchmarkable=False,
                                                         why_not="needs a C++ kernel")))
        Path(specs, "c.json").write_text(json.dumps(dict(GOOD, finding_id="z#1.1")))  # job died: no verdict
        vd = self.d / "verdicts"
        vd.mkdir()
        Path(vd, "v.json").write_text(json.dumps({"finding_id": "cox-ph-fit#1.3", "verdict": "faster",
                                                  "reason": "+50.0% faster", "timing": {"ratio": 0.5}}))
        text, counts = ab.render(ab.load_specs(specs), [json.loads(Path(vd, "v.json").read_text())])
        self.assertEqual(counts, {"faster": 1, "not_benchmarked": 2})
        self.assertIn("needs a C++ kernel", text)
        self.assertIn("no verdict (the bench job failed", text)


if __name__ == "__main__":
    unittest.main()
