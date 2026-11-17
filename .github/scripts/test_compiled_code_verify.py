"""Tests for compiled_code_verify.py (the compiled-code audit's benchmark check). No network, no EDI.

Run: cd .github/scripts && python3 test_compiled_code_verify.py
"""
import json
import math
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

import compiled_code_verify as cv

HAVE_R = shutil.which("Rscript") is not None


def prop(pid, old="a = 1;", new="a = 2;", file="R/EDI/src/x.cpp", **kw):
    return {"id": pid, "unit": f"{file}::f", "function": "f(int)", "file": file, "old_code": old,
            "new_code": new, "bench_code": "bench_setup = function() 1\nbench_run = function(d) d\n",
            "text": "hoist", "removes": "libm_in_loop exp", "risk_to_results": "none", **kw}


class PlanAndPatch(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        (self.tmp / "R/EDI/src").mkdir(parents=True)
        (self.tmp / "R/EDI/src/x.cpp").write_text("int f() {\n  a = 1;\n  b = 1;\n}\n")

    def tearDown(self):
        shutil.rmtree(self.tmp)

    def test_plan_outputs(self):
        fu = self.tmp / "fu"
        fu.mkdir()
        (fu / "proposals.json").write_text(json.dumps([prop("p1"), prop("p2", old="b = 1;")]))
        gho = self.tmp / "out.txt"
        cv.main(["plan", "--followup", str(fu), "--github-output", str(gho)])
        kv = dict(l.split("=", 1) for l in gho.read_text().splitlines())
        self.assertEqual(kv["has"], "true")
        self.assertEqual(json.loads(kv["builds"]), ["base", "p1", "p2"])
        self.assertEqual(json.loads(kv["proposals"]), ["p1", "p2"])

    def test_plan_without_artifact(self):
        gho = self.tmp / "out.txt"
        cv.main(["plan", "--followup", str(self.tmp / "missing"), "--github-output", str(gho)])
        self.assertIn("has=false", gho.read_text())

    def test_patch_one_and_two(self):
        pj = self.tmp / "p.json"
        pj.write_text(json.dumps([prop("p1"), prop("p2", old="b = 1;", new="b = 3;")]))
        self.assertEqual(cv.main(["patch", "--proposals", str(pj), "--ids", "p2", "--repo", str(self.tmp)]), 0)
        text = (self.tmp / "R/EDI/src/x.cpp").read_text()
        self.assertIn("a = 1;", text)          # only the named proposal
        self.assertIn("b = 3;", text)
        self.assertEqual(cv.main(["patch", "--proposals", str(pj), "--ids", "p1", "--repo", str(self.tmp)]), 0)
        self.assertIn("a = 2;", (self.tmp / "R/EDI/src/x.cpp").read_text())

    def test_patch_that_does_not_apply(self):
        res = cv.apply_proposals(self.tmp, [prop("p1", old="zzz"), prop("p2", file="R/EDI/src/none.cpp")])
        self.assertIn("occurs 0 times", res[0][1])
        self.assertIn("does not exist", res[1][1])
        # two proposals with overlapping old code: the second no longer applies after the first
        res = cv.apply_proposals(self.tmp, [prop("p1"), prop("p2")])
        self.assertIsNone(res[0][1])
        self.assertIn("occurs 0 times", res[1][1])


class Stats(unittest.TestCase):
    def test_abba_order(self):
        self.assertEqual(cv.abba_order(2), [(0, "A"), (0, "B"), (0, "B"), (0, "A"),
                                            (1, "A"), (1, "B"), (1, "B"), (1, "A")])

    def test_block_diffs_cancel_linear_drift(self):
        # runner slows down linearly; B is truly 10% faster: A B B A cancels the drift exactly
        times, k = {}, 0
        for b, x in cv.abba_order(5):
            drift = 1 + 0.01 * k
            times.setdefault(b, {}).setdefault(x, []).append((1.0 if x == "A" else 0.9) * drift)
            k += 1
        for d in cv.block_diffs(times):
            self.assertAlmostEqual(math.exp(d), 0.9, places=2)

    def test_incomplete_block_is_skipped(self):
        self.assertEqual(cv.block_diffs({0: {"A": [1, 1], "B": [1]}}), [])

    def test_summarize_and_decide(self):
        ok = {"tests": {"status": "pass"}, "equal": True}
        fast = cv.summarize([math.log(0.9) + e for e in (-0.01, 0.0, 0.01, -0.005, 0.005) * 4])
        self.assertLess(fast["hi"], 0.98)
        keep, why = cv.decide({**ok, "timing": fast})
        self.assertTrue(keep, why)
        self.assertIn("faster", why)
        noise = cv.summarize([e for e in (-0.05, 0.04, -0.03, 0.05, 0.0) * 4])
        keep, why = cv.decide({**ok, "timing": noise})
        self.assertFalse(keep)
        self.assertIn("not clearly faster", why)
        slow = cv.summarize([math.log(1.1) + e for e in (-0.01, 0.0, 0.01) * 6])
        keep, why = cv.decide({**ok, "timing": slow})
        self.assertFalse(keep)
        self.assertTrue(why.startswith("slower"))

    def test_decide_gates(self):
        t = cv.summarize([math.log(0.8)] * 10)
        self.assertFalse(cv.decide({"error": "boom"})[0])
        self.assertIn("tests failed", cv.decide({"tests": {"status": "fail", "failed": ["t.R"]},
                                                 "equal": True, "timing": t})[1])
        self.assertIn("did not run", cv.decide({"tests": {"status": "missing"}, "equal": True, "timing": t})[1])
        self.assertIn("results changed", cv.decide({"tests": {"status": "pass"}, "equal": False,
                                                    "equal_detail": "moved", "timing": t})[1])
        self.assertTrue(cv.decide({"tests": {"status": "none"}, "equal": True, "timing": t})[0])

    def test_summarize_is_deterministic(self):
        d = [0.01 * i for i in range(-5, 6)]
        self.assertEqual(cv.summarize(d), cv.summarize(d))
        self.assertIsNone(cv.summarize([]))


class Report(unittest.TestCase):
    def test_render(self):
        props = [prop("p1"), prop("p2", old="b = 1;")]
        verdicts = {"p1": {"keep": True, "reason": "+9.8% faster"},
                    "p2": {"keep": False, "reason": "slower: -3.0% faster"}}
        body, kept = cv.render(props, verdicts, "https://x/run")
        self.assertEqual([p["id"] for p in kept], ["p1"])
        self.assertIn("| p1 | `f(int)` | `R/EDI/src/x.cpp` | kept |", body)
        self.assertIn("| p2 |", body)
        self.assertIn("dropped", body)
        self.assertIn("1 of 2 kept", body)

    def test_missing_verdict_is_dropped(self):
        body, kept = cv.render([prop("p1")], {})
        self.assertEqual(kept, [])
        self.assertIn("did not finish", body)

    def test_report_without_publish_writes_the_body(self):
        tmp = Path(tempfile.mkdtemp())
        try:
            (tmp / "p.json").write_text(json.dumps([prop("p1")]))
            (tmp / "v").mkdir()
            (tmp / "v" / "verdict-p1.json").write_text(json.dumps({"id": "p1", "keep": True, "reason": "fast"}))
            cv.main(["report", "--proposals", str(tmp / "p.json"), "--verdicts", str(tmp / "v"),
                     "--repo", str(tmp), "--sha", "HEAD", "--out", str(tmp / "o.md")])
            self.assertIn("1 of 1 kept", (tmp / "o.md").read_text())
        finally:
            shutil.rmtree(tmp)


@unittest.skipUnless(HAVE_R, "Rscript not installed")
class CompareResults(unittest.TestCase):
    def rds(self, expr):
        f = tempfile.NamedTemporaryFile(suffix=".rds", delete=False).name
        subprocess.run(["Rscript", "-e", f"saveRDS({expr}, {json.dumps(f)})"], check=True)
        return f

    def test_tiers(self):
        base = self.rds("list(est = c(1.5, 2e6), n = 10L, ok = TRUE, lab = 'a', ci = c(-Inf, NA))")
        same = self.rds("list(est = c(1.5 + 1e-12, 2e6 * (1 + 1e-12)), n = 10L, ok = TRUE, lab = 'a', ci = c(-Inf, NA))")
        moved = self.rds("list(est = c(1.5 + 1e-6, 2e6), n = 10L, ok = TRUE, lab = 'a', ci = c(-Inf, NA))")
        other_int = self.rds("list(est = c(1.5, 2e6), n = 11L, ok = TRUE, lab = 'a', ci = c(-Inf, NA))")
        other_na = self.rds("list(est = c(1.5, 2e6), n = 10L, ok = TRUE, lab = 'a', ci = c(-Inf, 0))")
        self.assertTrue(cv.compare_results(base, same)[0])
        ok, why = cv.compare_results(base, moved)
        self.assertFalse(ok)
        self.assertIn("moved by", why)
        self.assertIn("must be exact", cv.compare_results(base, other_int)[1])
        self.assertIn("non-finite", cv.compare_results(base, other_na)[1])

    def test_bench_script_parses(self):
        r = subprocess.run(["Rscript", "-e", f"invisible(parse({json.dumps(str(cv.BENCH_R))}))"],
                           capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=1)
