#!/usr/bin/env python3
"""Checks for the numerical-robustness audit and the helpers it shares with thread-rng
(audits/_edi_index.py, audits/_rotation.py, audits/_testthat_verify.py). Stdlib only;
the R checks run only when Rscript and testthat are installed, and never load EDI."""
import datetime as dt
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import audit_common as ac  # noqa: E402
from audits import _edi_index as ei  # noqa: E402
from audits import _rotation as rot  # noqa: E402
from audits import _testthat_verify as tv  # noqa: E402
from audits import numerical_robustness as nr  # noqa: E402

NOW = dt.datetime(2026, 12, 5, 6, tzinfo=dt.timezone.utc)   # first Saturday of December

CPP = """#include "bar.h"
#include <cmath>
//' Fit foo.
// [[Rcpp::export]]
List fast_foo_cpp(const Eigen::Map<Eigen::MatrixXd>& X,
                  double tol = 1e-8, int maxit = 50) {
    return foo_internal(X, tol, maxit);
}

// [[Rcpp::export]]
double plain_helper_cpp(double x) { return std::log(x); }
"""
HDR = "#pragma once\ninline double bar(double x) { return x; }\n"
R_FIT = """InferenceFoo = define_inference_class(
\t"InferenceFoo",
\tpublic = list(
\t\tfit = function() {
\t\t\t# fast_foo_cpp() is called below
\t\t\tres = fast_foo_cpp(X, tol = 1e-6)
\t\t\tres
\t\t}
\t)
)
"""
R_PLAIN = "print_something = function(x) cat(x)\n"
RCPP_EXPORTS_R = "fast_foo_cpp <- function(X, tol, maxit) .Call(`_EDI_fast_foo_cpp`, X, tol, maxit)\n"


def make_repo(root):
    root = Path(root)
    (root / "R/EDI/src").mkdir(parents=True)
    (root / "R/EDI/R").mkdir(parents=True)
    (root / "R/EDI/tests/testthat").mkdir(parents=True)
    (root / "R/package_tests/testthat_bulk").mkdir(parents=True)
    (root / "R/EDI/src/fast_foo.cpp").write_text(CPP)
    (root / "R/EDI/src/bar.h").write_text(HDR)
    (root / "R/EDI/src/RcppExports.cpp").write_text("// generated\n")
    (root / "R/EDI/R/inference_foo.R").write_text(R_FIT)
    (root / "R/EDI/R/print.R").write_text(R_PLAIN)
    (root / "R/EDI/R/RcppExports.R").write_text(RCPP_EXPORTS_R)
    (root / "R/package_tests/testthat_bulk/test-foo-fit.R").write_text("x = InferenceFoo$new(d)\n")
    (root / "R/EDI/tests/testthat/test-unrelated.R").write_text("expect_true(TRUE)\n")
    return root


class Index(unittest.TestCase):
    def setUp(self):
        self.root = make_repo(tempfile.mkdtemp())
        self.idx = ei.Index(self.root)

    def tearDown(self):
        shutil.rmtree(self.root, ignore_errors=True)

    def test_exports_and_includes(self):
        self.assertEqual(self.idx.exports["R/EDI/src/fast_foo.cpp"], ["fast_foo_cpp", "plain_helper_cpp"])
        self.assertNotIn("R/EDI/src/RcppExports.cpp", self.idx.src)
        self.assertEqual(self.idx.includes("R/EDI/src/fast_foo.cpp"), ["R/EDI/src/bar.h"])
        self.assertEqual(self.idx.includers("R/EDI/src/bar.h"), ["R/EDI/src/fast_foo.cpp"])

    def test_explicit_export_name(self):
        self.assertEqual(ei.rcpp_exports('// [[Rcpp::export(name = "nice")]]\nint ugly(int x) {}\n'), ["nice"])
        self.assertEqual(ei.rcpp_exports("// [[Rcpp::export]]\nList\nmultiline_name(\n int x) {}\n"),
                         ["multiline_name"])

    def test_callers_skip_comments_and_generated_wrappers(self):
        c = self.idx.callers(["fast_foo_cpp"])
        self.assertEqual([x["file"] for x in c], ["R/EDI/R/inference_foo.R"])   # not RcppExports.R
        self.assertEqual([n for n, _ in c[0]["lines"]], [6])                     # the comment line is skipped
        self.assertEqual(self.idx.classes["R/EDI/R/inference_foo.R"], ["InferenceFoo"])
        self.assertEqual(self.idx.tests_naming(["InferenceFoo"]),
                         ["R/package_tests/testthat_bulk/test-foo-fit.R"])

    def test_signature(self):
        sig = ei.export_signature(CPP, "fast_foo_cpp")
        self.assertIn("double tol = 1e-8", sig)
        self.assertNotIn("{", sig)


class Units(unittest.TestCase):
    def setUp(self):
        self.root = make_repo(tempfile.mkdtemp())

    def tearDown(self):
        shutil.rmtree(self.root, ignore_errors=True)

    def ctx(self, event="schedule"):
        notes = ac.Notes(Path(self.root) / "notes", "numerical-robustness")
        return ac.Context(ac.spec_of(nr), self.root, notes, Path(self.root) / "work", now=NOW, event=event)

    def test_unit_set(self):
        u = nr.units(self.ctx())
        self.assertEqual(sorted(u), ["R/EDI/R/inference_foo.R", "R/EDI/src/bar.h", "R/EDI/src/fast_foo.cpp"])
        c = u["R/EDI/src/fast_foo.cpp"]["context"]
        self.assertEqual(c["r_classes"], ["InferenceFoo"])
        self.assertEqual(c["test_files"], ["R/package_tests/testthat_bulk/test-foo-fit.R"])
        h = u["R/EDI/src/bar.h"]["context"]
        self.assertEqual(h["included_by"], ["R/EDI/src/fast_foo.cpp"])
        self.assertEqual([x["file"] for x in h["r_callers"]], ["R/EDI/R/inference_foo.R"])  # via the includer
        r = u["R/EDI/R/inference_foo.R"]["context"]
        self.assertEqual(r["cpp_kernels_called"], [{"export": "fast_foo_cpp", "file": "R/EDI/src/fast_foo.cpp"}])

    def test_r_deps_follow_kernel_signature_not_body(self):
        before = nr.units(self.ctx())["R/EDI/R/inference_foo.R"]["deps"]
        p = Path(self.root) / "R/EDI/src/fast_foo.cpp"
        p.write_text(CPP.replace("return foo_internal(X, tol, maxit);", "return foo_internal(X, tol, 2 * maxit);"))
        self.assertEqual(nr.units(self.ctx())["R/EDI/R/inference_foo.R"]["deps"], before)
        p.write_text(CPP.replace("double tol = 1e-8", "double tol = 1e-10"))
        self.assertNotEqual(nr.units(self.ctx())["R/EDI/R/inference_foo.R"]["deps"], before)

    def test_unchanged_units_only_in_their_month(self):
        ctx = self.ctx()
        u = nr.units(ctx)
        manifest = {"units": {k: {"hash": v["hash"], "deps": v.get("deps"),
                                  "audited_at": "2026-11-01T00:00:00+00:00"} for k, v in u.items()}}
        spec = ac.spec_of(nr)
        self.assertEqual((spec["period"], spec["cycle_weeks"]), ("month", 6))
        chosen, reasons, _ = ac.select_units(u, manifest, "auto", 6, NOW, period="month")
        expect = [k for k in u if ac.in_rotation(k, 6, NOW, "month")]
        self.assertEqual(sorted(chosen), sorted(expect))
        (Path(self.root) / "R/EDI/R/print.R").write_text(R_PLAIN + "# fit with optim(par, fn)\n")
        u2 = nr.units(ctx)
        self.assertIn("R/EDI/R/print.R", u2)                 # optim( makes it a fitting file
        chosen, reasons, _ = ac.select_units(u2, manifest, "auto", 6, NOW, period="month")
        self.assertEqual(reasons["R/EDI/R/print.R"], "new")


class Rotation(unittest.TestCase):
    def test_each_unit_once_in_six_monthly_runs(self):
        # the framework's monthly clock: a unit is in exactly one of 6 consecutive runs
        months = [dt.datetime(2027, m, 6, tzinfo=dt.timezone.utc) for m in range(1, 7)]
        for uid in ("a", "R/EDI/src/x.cpp", "y" * 80):
            self.assertEqual(sum(ac.in_rotation(uid, 6, m, "month") for m in months), 1, uid)

    def test_push_and_never(self):
        self.assertEqual(rot.unit_cycle(6, "schedule"), 6)
        self.assertEqual(rot.unit_cycle(6, "push"), rot.NEVER)
        self.assertFalse(any(ac.in_rotation(f"u{i}", rot.NEVER, dt.datetime(2026 + y, m, 1, tzinfo=dt.timezone.utc),
                                            "month") for i in range(60) for y in range(3) for m in range(1, 13)))


class Verify(unittest.TestCase):
    def run_result(self, fail=0, error=0, skip=0, passed=0, msgs=(), timed_out=False):
        return {"counts": {"fail": fail, "error": error, "skip": skip, "warning": 0, "pass": passed},
                "messages": list(msgs), "timed_out": timed_out}

    def test_slug_and_text(self):
        self.assertEqual(tv.slugify("Robust IRLS: converged flag (TODO-12) ignores tol!"),
                         "robust-irls-converged-flag-ignores-tol")
        self.assertNotRegex(tv.slugify("todo123 thing"), r"todo")
        t = tv.test_text('say "hi"', "x = 1\nexpect_equal(x, 2)", skip=True)
        self.assertTrue(t.startswith('test_that("say \\"hi\\"", {\n\tskip("open a release TODO for this")\n\tx = 1'))
        self.assertTrue(t.endswith("})\n"))

    def test_judge(self):
        f = {"test_code": "expect_true(is.finite(x))"}
        self.assertFalse(tv.judge(self.run_result(passed=2), f)[0])
        self.assertFalse(tv.judge(self.run_result(error=1, msgs=[("error", "boom")]), f)[0])
        self.assertFalse(tv.judge(self.run_result(skip=1), f)[0])
        self.assertFalse(tv.judge(self.run_result(timed_out=True), f)[0])
        self.assertFalse(tv.judge(self.run_result(), f)[0])
        self.assertTrue(tv.judge(self.run_result(fail=1, msgs=[("fail", "is.finite(x) is not TRUE")]), f)[0])
        wrong = self.run_result(fail=1, msgs=[("fail", 'Expected `f()` not to throw. could not find function "f"')])
        self.assertFalse(tv.judge(wrong, {"test_code": "expect_no_error(f())", "failure_contains": "x"})[0])
        need = self.run_result(fail=1, msgs=[("fail", "threw an error: singular")])
        self.assertFalse(tv.judge(need, {"test_code": "expect_no_error(g())", "failure_contains": ""})[0])
        self.assertTrue(tv.judge(need, {"test_code": "expect_no_error(g())", "failure_contains": "singular"})[0])
        self.assertFalse(tv.judge(need, {"test_code": "expect_no_error(g())", "failure_contains": "other"})[0])

    def test_parse_rows(self):
        c, m = tv.parse_rows("fail\tExpected 1 to equal 2.\npass\tsuccess\nerror\tboom\n")
        self.assertEqual((c["fail"], c["pass"], c["error"]), (1, 1, 1))
        self.assertEqual(m, [("fail", "Expected 1 to equal 2."), ("error", "boom")])


class Apply(unittest.TestCase):
    def setUp(self):
        self.root = make_repo(tempfile.mkdtemp())
        notes = ac.Notes(Path(self.root) / "notes", "numerical-robustness")
        self.ctx = ac.Context(ac.spec_of(nr), self.root, notes, Path(self.root) / "work", now=NOW,
                              sha="0123456789abcdef")
        self.finding = {"unit": "R/EDI/src/fast_foo.cpp", "kind": "log_zero", "text": "log(0) when p hits 1",
                        "location": "R/EDI/src/fast_foo.cpp:11", "test_name": "foo loglik stays finite",
                        "test_file_slug": "foo-loglik-finite-at-boundary", "test_code": "expect_true(is.finite(1))",
                        "failure_contains": ""}

    def tearDown(self):
        shutil.rmtree(self.root, ignore_errors=True)

    def results(self, *fs):
        return [{"units_checked": ["R/EDI/src/fast_foo.cpp"], "findings": list(fs), "_batch": "b001",
                 "_units": ["R/EDI/src/fast_foo.cpp"]}]

    def test_no_r_means_not_verified_and_nothing_added(self):
        parts = tv.apply_tests(self.ctx, self.results(self.finding), "X",
                               availability=lambda: (False, "R could not load EDI"))
        self.assertEqual(parts["applied"], [])
        self.assertTrue(ac.texts(parts["human"])[0].startswith("NOT VERIFIED (R could not load EDI)"))
        self.assertFalse(any(p.get("applied_file") for p in parts["proposed"]))
        self.assertEqual(list((Path(self.root) / tv.BULK).glob("test-foo-loglik*")), [])

    def test_failing_test_is_added_skipped(self):
        runs = {"001": {"counts": {"fail": 1, "error": 0, "skip": 0, "warning": 0, "pass": 0},
                        "messages": [("fail", "is.finite(ll) is not TRUE")], "timed_out": False},
                "002": {"counts": {"fail": 0, "error": 0, "skip": 0, "warning": 0, "pass": 1},
                        "messages": [], "timed_out": False}}
        runner = lambda wd, key, name, body, timeout: runs[key]
        passing = {**self.finding, "text": "a claim that is wrong", "test_file_slug": "other"}
        parts = tv.apply_tests(self.ctx, self.results(self.finding, passing), "Numerical-robustness review",
                               availability=lambda: (True, ""), runner=runner)
        self.assertEqual(len(parts["applied"]), 1)
        p = Path(self.root) / tv.BULK / "test-foo-loglik-finite-at-boundary.R"
        text = p.read_text()
        self.assertIn('\tskip("open a release TODO for this")\n', text)
        self.assertIn("# Numerical-robustness review audit, 2026-12-05: log(0) when p hits 1", text)
        self.assertIn("0123456789ab", text)
        kept = [x for x in parts["proposed"] if x.get("applied_file")]
        self.assertEqual(kept[0]["applied_file"], f"{tv.BULK}/test-foo-loglik-finite-at-boundary.R")
        self.assertIn(kept[0]["applied_text"], text)
        self.assertTrue(any("passed on the current code" in h for h in ac.texts(parts["human"])))
        self.assertTrue(any("refresh_manifest.py not found" in h for h in ac.texts(parts["human"])))

    def test_name_clash_gets_suffix(self):
        (Path(self.root) / tv.BULK / "test-foo-loglik-finite-at-boundary.R").write_text("# exists\n")
        runner = lambda *a: {"counts": {"fail": 1, "error": 0, "skip": 0, "warning": 0, "pass": 0},
                             "messages": [("fail", "x")], "timed_out": False}
        parts = tv.apply_tests(self.ctx, self.results(self.finding), "X", availability=lambda: (True, ""),
                               runner=runner)
        self.assertIn("test-foo-loglik-finite-at-boundary-2.R", parts["applied"][0])


@unittest.skipUnless(shutil.which("Rscript") and subprocess.run(
    ["Rscript", "-e", "library(testthat)"], capture_output=True).returncode == 0, "Rscript + testthat needed")
class RunnerWithR(unittest.TestCase):
    """The R runner itself, without EDI (load_edi=False)."""

    def test_counts(self):
        wd = tempfile.mkdtemp()
        try:
            r = tv.run_test(wd, "a", "fails", "x = 1\nexpect_equal(x, 2)", timeout=120, load_edi=False)
            self.assertEqual(r["counts"]["fail"], 1)
            self.assertTrue(tv.judge(r, {"test_code": "expect_equal(x, 2)"})[0])
            r = tv.run_test(wd, "b", "errors", "stop('boom')", timeout=120, load_edi=False)
            self.assertEqual(r["counts"]["error"], 1)
            self.assertFalse(tv.judge(r, {"test_code": ""})[0])
            r = tv.run_test(wd, "c", "passes", "expect_true(TRUE)", timeout=120, load_edi=False)
            self.assertEqual((r["counts"]["pass"], r["counts"]["fail"]), (1, 0))
        finally:
            shutil.rmtree(wd, ignore_errors=True)


if __name__ == "__main__":
    unittest.main(verbosity=1)
