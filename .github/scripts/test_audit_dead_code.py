#!/usr/bin/env python3
"""Checks for the dead-code audit (audits/dead_code.py). Stdlib only, no network, no compiler."""
import datetime as dt
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import audit_common as ac  # noqa: E402
from audits import dead_code as dc  # noqa: E402

NOW = dt.datetime(2026, 11, 9, 6, tzinfo=dt.timezone.utc)

FILES = {
    "R/EDI/NAMESPACE": "export(UsedInTest)\nexport(unused_fn)\nexport(CommentOnly)\nexport(InExample)\n"
                       "export(BaseClass)\nexport(Child)\nexport(wrapped_cpp)\nexport(\"quoted_fn\")\nexport(StringRef)\n"
                       "importFrom(stats,sd)\n",
    "R/EDI/R/a.R": "UsedInTest = function(x) x\n"
                   "unused_fn = function(x) {\n\tx + 1\n}\n"
                   "CommentOnly = function() 1  # see unused_fn\n"
                   "# CommentOnly is mentioned here only\n"
                   "InExample = function() 2\n"
                   "BaseClass = R6::R6Class(\"BaseClass\",\n\tpublic = list())\n"
                   "Child = R6::R6Class(\"Child\", inherit = BaseClass)\n"
                   "quoted_fn = function() 3\n"
                   "StringRef = function() 4\n"
                   "g = function() do.call(\"StringRef\", list())  # a string is a reference\n",
    "R/EDI/R/RcppExports.R": "wrapped_cpp <- function(x) .Call(`_EDI_wrapped_cpp`, x)\n"
                             "orphan_cpp <- function(x) .Call(`_EDI_orphan_cpp`, x)\n"
                             "renamed <- function(x) .Call(`_EDI_renamed`, x)\n",
    "R/EDI/R/b.R": "f = function() wrapped_cpp(1) + renamed(2)\n",
    "R/EDI/tests/testthat/test-a.R": "test_that(\"x\", expect_equal(UsedInTest(1), 1))\n",
    "R/EDI/man/InExample.Rd": "\\name{InExample}\n\\usage{InExample()}\n\\examples{\nInExample() # {braces}\n}\n",
    "R/EDI/man/quoted_fn.Rd": "\\name{quoted_fn}\n\\alias{quoted_fn}\n\\usage{quoted_fn()}\n",
    "R/EDI/src/RcppExports.cpp":
        "// wrapped_cpp\ndouble wrapped_cpp(double x);\nRcppExport SEXP _EDI_wrapped_cpp(SEXP xSEXP) {\nBEGIN_RCPP\n"
        "    rcpp_result_gen = Rcpp::wrap(wrapped_cpp(x));\nEND_RCPP\n}\n"
        "// orphan_cpp\nvoid orphan_cpp(double x);\nRcppExport SEXP _EDI_orphan_cpp(SEXP xSEXP) {\nBEGIN_RCPP\n"
        "    orphan_cpp(x);\nEND_RCPP\n}\n"
        "// renamed\ndouble inner_name(double x);\nRcppExport SEXP _EDI_renamed(SEXP xSEXP) {\nBEGIN_RCPP\n"
        "    rcpp_result_gen = Rcpp::wrap(inner_name(x));\nEND_RCPP\n}\n",
    "R/EDI/src/helpers.h": "double declared_only(double x);\n"
                           "inline double used_by_python(double x) {\n  return x;\n}\n"
                           "static double helper_called(double x) {\n  return x;\n}\n",
    "R/EDI/src/k.cpp": "#include \"helpers.h\"\n"
                       "// [[Rcpp::export]]\ndouble wrapped_cpp(double x) {\n  helper_called(x);\n  return x;\n}\n"
                       "// [[Rcpp::export]]\nvoid orphan_cpp(double x) {\n  return;\n}\n"
                       "// [[Rcpp::export(name = \"renamed\")]]\ndouble inner_name(double x) {\n  return x;\n}\n"
                       "double declared_only(double x) {\n  return 2 * x; // dead_in_comment(x)\n}\n"
                       "/* static double commented_out(double x) {\n  return x;\n} */\n"
                       "Eigen::VectorXd never_called(const Eigen::VectorXd& v) {\n  return v;\n}\n"
                       "double Fitter::member(double x) {\n  return x;\n}\n"
                       "static void called_on_own_line() {\n}\n"
                       "void runner() {\n  called_on_own_line();\n}\n",
    "R/EDI/src/runner_use.cpp": "void runner();\nvoid go() { runner(); }\n",
    "python/cpp/bindings.cpp": "void bind(py::module& m) {\n  m.def(\"u\", &used_by_python);\n}\n",
}


class Fixture(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.repo = self.tmp / "repo"
        for path, text in FILES.items():
            p = self.repo / path
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text(text)
        run = lambda *a: subprocess.run(["git", *a], cwd=self.repo, check=True, capture_output=True)
        run("init", "-q", "-b", "main")
        run("add", "-A")
        self.notes = ac.Notes(self.tmp / "notes", "dead-code")
        self.ctx = self.new_ctx()

    def new_ctx(self):
        return ac.Context(ac.spec_of(dc), self.repo, self.notes, self.tmp / "work", now=NOW)


class Candidates(Fixture):
    def test_r(self):
        c = dc.candidates(self.ctx)
        r = {k for k in c if k.startswith("R:")}
        self.assertEqual(r, {"R:unused_fn", "R:CommentOnly", "R:Child", "R:quoted_fn"})
        self.assertEqual(c["R:unused_fn"]["kind"], "exported R function")
        self.assertEqual(c["R:Child"]["kind"], "exported R class")
        self.assertEqual((c["R:unused_fn"]["file"], c["R:unused_fn"]["line"]), ("R/EDI/R/a.R", 2))

    def test_cpp(self):
        c = dc.candidates(self.ctx)
        cpp = {k: v for k, v in c.items() if k.startswith("cpp:")}
        self.assertEqual(set(cpp), {"cpp:R/EDI/src/k.cpp::orphan_cpp", "cpp:R/EDI/src/k.cpp::declared_only",
                                    "cpp:R/EDI/src/k.cpp::never_called", "cpp:R/EDI/src/runner_use.cpp::go"})
        self.assertEqual(cpp["cpp:R/EDI/src/k.cpp::orphan_cpp"]["kind"], "Rcpp export with no R caller")
        self.assertIn("no C++ reference", cpp["cpp:R/EDI/src/k.cpp::orphan_cpp"]["note"])
        self.assertEqual(cpp["cpp:R/EDI/src/k.cpp::never_called"]["line"], 21)

    def test_units_carry_context_and_skip_rejected(self):
        u = dc.units(self.ctx)
        ctx_ = u["R:unused_fn"]["context"]
        self.assertIn("x + 1", ctx_["definition"])
        self.assertIn("R/EDI/tests", ctx_["searched"])
        c = dc.candidates(self.ctx)["R:Child"]
        fid = ac.finding_id("dead-code", "R:Child", "dead-code", dc.finding_text(c))
        self.notes.save_findings([{"id": fid, "status": "rejected"}])
        self.assertNotIn("R:Child", dc.units(self.new_ctx()))

    def test_helpers(self):
        self.assertEqual(dc.strip_r_comment('x = "a#b" # c'), 'x = "a#b" ')
        self.assertEqual(dc.strip_cpp_comments('a("//x"); // c\n/* d\n e */ f'), 'a("//x");     \n    \n      f')
        self.assertEqual(dc.rd_examples("\\examples{\nf({1})\n\\dontrun{g()}\n}\n\\note{x}").strip(),
                         "f({1})\n\\dontrun{g()}")
        self.assertTrue(dc.is_declaration("double f(int x);", "f"))
        self.assertFalse(dc.is_declaration("  f(x);", "f"))
        self.assertFalse(dc.is_declaration("  return f(x);", "f"))
        self.assertEqual(dc.namespace_exports('export(a)\nexport("b")\nS3method(print,x)\n'), ["a", "b"])


class Apply(Fixture):
    def result(self, findings, checked=None):
        return {"units_checked": checked if checked is not None else [f["unit"] for f in findings],
                "findings": findings, "_batch": "b001", "_units": []}

    def test_apply(self):
        res = [self.result([
            {"unit": "R:unused_fn", "kind": "confirmed", "text": "no caller\n anywhere", "evidence": []},
            {"unit": "R:Child", "kind": "false_positive", "text": "registry", "evidence": ["x.R:1"]},
            {"unit": "cpp:R/EDI/src/k.cpp::orphan_cpp", "kind": "unsure", "text": "maybe python", "evidence": []},
            {"unit": "R:not_a_candidate", "kind": "confirmed", "text": "x", "evidence": []},
        ])]
        parts = dc.apply(self.ctx, res, [])
        body = (self.repo / dc.CANDIDATES_FILE).read_text()
        self.assertIn("- `R:unused_fn` (exported R function, R/EDI/R/a.R:2): no caller anywhere", body)
        self.assertNotIn("R:Child", body)
        self.assertNotIn("not_a_candidate", body)
        self.assertEqual(len(parts["proposed"]), 1)
        p = parts["proposed"][0]
        self.assertIn(p["applied_text"], body)
        self.assertTrue(any(h.startswith("Unsure") for h in parts["human"]))
        self.assertIn("ruled out 1", parts["summary"])
        self.assertEqual(len(parts["applied"]), 1)

        # Next run: unused_fn not re-read (its batch NOT RUN) keeps its line; never_called is confirmed.
        ctx2 = self.new_ctx()
        parts2 = dc.apply(ctx2, [self.result([
            {"unit": "cpp:R/EDI/src/k.cpp::never_called", "kind": "confirmed", "text": "none", "evidence": []}])], [])
        body2 = (self.repo / dc.CANDIDATES_FILE).read_text()
        self.assertIn("R:unused_fn", body2)
        self.assertIn("never_called", body2)
        self.assertEqual(len(parts2["proposed"]), 1)

        # The owner deleted the unused_fn line in the PR: rejected, so it leaves the file.
        f = ac.normalise_finding("dead-code", p, "claude")
        self.notes.save_findings([{**f, "status": "rejected"}])
        dc.apply(self.new_ctx(), [], [])
        self.assertNotIn("R:unused_fn", (self.repo / dc.CANDIDATES_FILE).read_text())

    def test_nothing_confirmed_writes_nothing(self):
        parts = dc.apply(self.ctx, [self.result([
            {"unit": "R:Child", "kind": "false_positive", "text": "used", "evidence": []}])], [])
        self.assertFalse((self.repo / dc.CANDIDATES_FILE).exists())
        self.assertEqual(parts["applied"], [])


if __name__ == "__main__":
    unittest.main(verbosity=1)
