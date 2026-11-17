#!/usr/bin/env python3
"""Checks for the source-comment-rot audit (audits/source_comment_rot.py). Stdlib only, no network."""
import datetime as dt
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import audit_common as ac  # noqa: E402
from audits import source_comment_rot as scr  # noqa: E402

NOW = dt.datetime(2026, 11, 22, 6, tzinfo=dt.timezone.utc)

R_FILE = (
    "#' @param tol Tolerance. Default 1e-6.\n"
    "fit = function(x, tol = 1e-8) {\n"
    "\t# TODO: handle NA here\n"
    "\t# TODO (v1.1.0-TODO-48): seed per draw\n"
    "\ty = x + 1  # always positive\n"
    "\ts = \"# TODO: not a note, a string\"\n"
    "\t# FIXME: named in the release file\n"
    "\t# XXX check this\n"
    "\t#   continues; see release_v1_0_6.md TODO-3\n"
    "\t# same\n"
    "\t# same\n"
    "\ty\n"
    "}\n")
CPP_FILE = (
    "// max 50 iterations\n"
    "int f(int n) {\n"
    "  /* block start\n"
    "   * uses Newton steps\n"
    "   */\n"
    "  int k = 100; // FIXME tune\n"
    "  return n * k; // returns n squared\n"
    "}\n"
    "const char* s = \"// TODO in a string\";\n")


class Fixture(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.repo = self.tmp / "repo"
        files = {
            "R/EDI/R/fit.R": R_FILE,
            "R/EDI/R/RcppExports.R": "# TODO: generated\n",
            "R/EDI/src/f.cpp": CPP_FILE,
            "R/EDI/src/notes.txt": "TODO: not a source file\n",
            "R/package_metadata/future_release_plans/release_v1_0_6.md":
                "- [ ] TODO-9 fix the note in `fit.R` (FIXME: named in the release file)\n",
            "R/package_metadata/new_feature_plans/v1_0_6/plan.md": "see f.cpp:6 for the tuning note\n",
        }
        for path, text in files.items():
            p = self.repo / path
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text(text)
        run = lambda *a: subprocess.run(["git", *a], cwd=self.repo, check=True, capture_output=True)
        run("init", "-q", "-b", "main")
        run("add", "-A")
        self.ctx = ac.Context(ac.spec_of(scr), self.repo, ac.Notes(self.tmp / "notes", "source-comment-rot"),
                              self.tmp / "work", now=NOW)


class Notes(Fixture):
    def test_uncited_notes(self):
        out = scr.mechanical(self.ctx)
        got = sorted((f["unit"], f["line"]) for f in out)
        # fit.R:3 is uncited; :4 cites itself; :6 is a string; :7 is named in a release file; :8 is cited
        # by the comment line after it. f.cpp:6 is named by file:line in a plan; the string is skipped.
        self.assertEqual(got, [("R/EDI/R/fit.R", 3)])
        self.assertIn("TODO: handle NA here", out[0]["text"])

    def test_units(self):
        u = scr.units(self.ctx)
        self.assertEqual(set(u), {"R/EDI/R/fit.R", "R/EDI/src/f.cpp"})
        c = u["R/EDI/R/fit.R"]["context"]
        self.assertEqual(c["language"], "R")
        self.assertEqual(len(c["uncited_notes"]), 1)
        self.assertEqual(u["R/EDI/src/f.cpp"]["context"]["comment_lines"], 6)
        self.assertEqual(u["R/EDI/R/fit.R"]["hash"], ac.text_hash(R_FILE))

    def test_code_only(self):
        self.assertEqual(scr.code_only("a.R", 'x = "#a" # c\n# d'), 'x = "#a"\n')
        self.assertEqual(scr.code_only("a.cpp", "a; // c\n/* x\n * y */ b;"), "a;\n\n        b;")


class Apply(Fixture):
    def apply(self, *findings):
        return scr.apply(self.ctx, [{"units_checked": ["R/EDI/R/fit.R"], "findings": list(findings),
                                     "_batch": "b001", "_units": []}], [])

    def f(self, unit, old, new, kind="contradiction", line=1):
        return {"unit": unit, "kind": kind, "line": line, "old": old, "new": new, "text": "claim vs code",
                "evidence": []}

    def test_applies_comment_only_change(self):
        parts = self.apply(
            self.f("R/EDI/R/fit.R", "#' @param tol Tolerance. Default 1e-6.", "#' @param tol Tolerance. Default 1e-8."),
            self.f("R/EDI/R/fit.R", "\ty = x + 1  # always positive", "\ty = x + 1  # positive when x > -1"),
            self.f("R/EDI/src/f.cpp", "   * uses Newton steps", "   * uses fixed-point steps"),
            self.f("R/EDI/src/f.cpp", "  return n * k; // returns n squared", "  return n * k; // returns 100 n"))
        self.assertEqual(len(parts["applied"]), 4, ac.texts(parts["human"]))
        r = (self.repo / "R/EDI/R/fit.R").read_text()
        self.assertIn("Default 1e-8.", r)
        self.assertIn("# positive when x > -1", r)
        self.assertIn("fixed-point", (self.repo / "R/EDI/src/f.cpp").read_text())
        for p in parts["proposed"]:
            self.assertIn(p["applied_text"], (self.repo / p["applied_file"]).read_text())

    def test_refuses(self):
        cases = [
            self.f("R/EDI/R/fit.R", "\ty = x + 1  # always positive", "\ty = x + 2  # always positive"),  # code
            self.f("R/EDI/R/fit.R", "\t# same", "\t# different"),                                   # twice
            self.f("R/EDI/R/fit.R", "\ty", "\ty  # the result"),                                    # no comment
            self.f("R/EDI/R/fit.R", "\t# nonexistent", "\t# x"),                                    # missing
            self.f("R/EDI/R/fit.R", "\ty = x + 1  # always positive", "\ty = x + 1  # a\n\tz = 1"),  # two lines
            self.f("R/EDI/src/f.cpp", "// max 50 iterations", "int g; // max 100 iterations"),     # code added
            self.f("R/EDI/src/f.cpp", "  int k = 100; // FIXME tune", "  int k = 100; /* tune */ int j;"),
            self.f("R/EDI/R/RcppExports.R", "# TODO: generated", "# x"),                             # not covered
        ]
        parts = self.apply(*cases)
        self.assertEqual(parts["applied"], [])
        self.assertEqual(len(ac.texts(parts["human"])), len(cases))
        self.assertTrue(any("touches code" in h for h in ac.texts(parts["human"])))
        self.assertTrue(any("2 times" in h for h in ac.texts(parts["human"])))
        self.assertTrue(any("holds no comment" in h for h in ac.texts(parts["human"])))
        self.assertTrue(any("0 times" in h for h in ac.texts(parts["human"])))
        self.assertTrue(any("one line" in h for h in ac.texts(parts["human"])))
        self.assertEqual((self.repo / "R/EDI/R/fit.R").read_text(), R_FILE)
        self.assertEqual((self.repo / "R/EDI/src/f.cpp").read_text(), CPP_FILE)

    def test_code_may_be_wrong_goes_to_human(self):
        parts = self.apply(self.f("R/EDI/R/fit.R", "\ty = x + 1  # always positive", "", kind="code_may_be_wrong"))
        self.assertEqual(parts["applied"], [])
        self.assertIn("may be the wrong side", ac.texts(parts["human"])[0])
        self.assertEqual((self.repo / "R/EDI/R/fit.R").read_text(), R_FILE)

    def test_second_fix_of_the_same_line_is_refused(self):
        parts = self.apply(
            self.f("R/EDI/R/fit.R", "\ty = x + 1  # always positive", "\ty = x + 1  # nonnegative"),
            self.f("R/EDI/R/fit.R", "\ty = x + 1  # always positive", "\ty = x + 1  # other"))
        self.assertEqual(len(parts["applied"]), 1)
        self.assertEqual(len(ac.texts(parts["human"])), 1)


if __name__ == "__main__":
    unittest.main(verbosity=1)
