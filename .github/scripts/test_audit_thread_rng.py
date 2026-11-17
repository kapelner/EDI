#!/usr/bin/env python3
"""Checks for the thread and random-number audit (audits/thread_rng.py). Stdlib only. The
shared test runner and rotation are checked in test_audit_numerical_robustness.py."""
import datetime as dt
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import audit_common as ac  # noqa: E402
from audits import _testthat_verify as tv  # noqa: E402
from audits import thread_rng as tr  # noqa: E402

NOW = dt.datetime(2026, 12, 20, 6, tzinfo=dt.timezone.utc)   # third Sunday of December

FILES = {
    "R/EDI/src/omp_kernel.cpp": "// [[Rcpp::export]]\nNumericVector boot_cpp(int r, int num_cores) {\n"
                                "#pragma omp parallel for num_threads(num_cores)\n  for (int b = 0; b < r; b++) {}\n}\n",
    "R/EDI/src/rng_kernel.cpp": "// [[Rcpp::export]]\ndouble draw_cpp() { return R::runif(0, 1); }\n",
    "R/EDI/src/serial.cpp": "// [[Rcpp::export]]\ndouble serial_cpp(double x) { return x; }\n",
    "R/EDI/src/RNG.h": "#pragma once\nclass RRng {};\n",
    "R/EDI/R/boot.R": "InferenceBoot = define_inference_class(\"InferenceBoot\")\n"
                      "f = function() boot_cpp(10L, private$num_cores)\n",
    "R/EDI/R/serial.R": "g = function(x) serial_cpp(x)\n",
    "R/EDI/R/seeded.R": "h = function() { set.seed(1); runif(1) }\n",
    "R/package_tests/testthat_bulk/test-core-count-invariance.R": "set_num_cores(2)\n",
    "R/package_tests/testthat_bulk/test-boot.R": "InferenceBoot$new(d)\n",
}


class Units(unittest.TestCase):
    def setUp(self):
        self.root = Path(tempfile.mkdtemp())
        for rel, text in FILES.items():
            p = self.root / rel
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text(text)
        notes = ac.Notes(self.root / "notes", "thread-rng")
        self.ctx = ac.Context(ac.spec_of(tr), self.root, notes, self.root / "work", now=NOW)

    def tearDown(self):
        shutil.rmtree(self.root, ignore_errors=True)

    def test_only_parallel_or_rng_files(self):
        u = tr.units(self.ctx)
        self.assertEqual(sorted(u), ["R/EDI/R/boot.R", "R/EDI/R/seeded.R", "R/EDI/src/RNG.h",
                                     "R/EDI/src/omp_kernel.cpp", "R/EDI/src/rng_kernel.cpp"])

    def test_context(self):
        c = tr.units(self.ctx)["R/EDI/src/omp_kernel.cpp"]["context"]
        self.assertEqual(c["parallel_or_rng_lines"], [[3, "#pragma omp parallel for num_threads(num_cores)"]])
        self.assertEqual(c["r_classes"], ["InferenceBoot"])
        self.assertEqual(c["test_files"], ["R/package_tests/testthat_bulk/test-boot.R"])
        self.assertEqual(c["invariance_test_templates"],
                         ["R/package_tests/testthat_bulk/test-core-count-invariance.R"])

    def test_matching_lines_skip_comments_but_not_pragmas(self):
        hits = tr.matching_lines("// R::runif in a comment\n#pragma omp parallel\nx = R::rnorm(0, 1);\n", tr.CPP_PAT)
        self.assertEqual([n for n, _ in hits], [2, 3])

    def test_apply_needs_failing_test(self):
        f = {"unit": "R/EDI/src/omp_kernel.cpp", "kind": "seed_per_thread", "text": "draws depend on cores",
             "location": "R/EDI/src/omp_kernel.cpp:3", "test_name": "boot draws do not depend on cores",
             "test_file_slug": "boot-draws-core-count-invariant", "test_code": "expect_equal(1, 2)",
             "failure_contains": ""}
        orig = tv.r_available
        tv.r_available = lambda: (False, "R could not load testthat and EDI: no EDI")
        try:
            parts = tr.apply(self.ctx, [{"findings": [f], "_batch": "b001", "_units": [f["unit"]]}], [])
        finally:
            tv.r_available = orig
        self.assertEqual(parts["applied"], [])
        self.assertIn("NOT VERIFIED", ac.texts(parts["human"])[0])


if __name__ == "__main__":
    unittest.main(verbosity=1)
