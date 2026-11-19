#!/usr/bin/env python3
"""Checks for the untested-code audit (.github/scripts/audits/untested_code.py). Stdlib only.

Fixtures: a small git repository with an R file, a C++ file, NAMESPACE, an Rd method anchor, the
coverage registry and codecov.yml; a covr export CSV and a cobertura XML written by hand; gcov JSON
lines as gcov prints them. No R, no gcov and no network are needed.
"""
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import audit_common as ac  # noqa: E402
from audits import dead_code as dc  # noqa: E402
from audits import untested_code as uc  # noqa: E402

R_FILE = """#' @export
compute_thing = function(x) {
	if (x < 0) {
		stop("x must be non-negative")
	}
	y = x + 1
	y * 2
}
helper_internal = function(z) {
	if (is.na(z)) return(NA_real_)
	z
}
on_windows = function() {
	if (.Platform$OS.type == "windows") {
		message("windows")
		return(1)
	}
	0
}
skipped = function() {
	cat("a") # nocov
}
"""

CPP_FILE = """#include <Rcpp.h>
// [[Rcpp::export]]
double kernel_cpp(double x) {
  if (x > 1e6) {
    Rcpp::stop("too large");
  }
  double y = x * 2;
  return y;
}
static double helper(double z) {
  double w = z + 1;
  return w;
}
#ifdef _WIN32
double win_only(double a) {
  return a;
}
#endif
"""

# covr expressions: (file, first, last, fn, value).
COV_ROWS = [
    ("R/EDI/R/thing.R", 2, 8, "compute_thing", 5),
    ("R/EDI/R/thing.R", 3, 5, "compute_thing", 5),
    ("R/EDI/R/thing.R", 4, 4, "compute_thing", 0),          # the guard never ran
    ("R/EDI/R/thing.R", 6, 6, "compute_thing", 5),
    ("R/EDI/R/thing.R", 7, 7, "compute_thing", 5),
    ("R/EDI/R/thing.R", 10, 10, "helper_internal", 0),      # whole helper unrun
    ("R/EDI/R/thing.R", 11, 11, "helper_internal", 0),
    ("R/EDI/R/thing.R", 14, 14, "on_windows", 3),
    ("R/EDI/R/thing.R", 15, 15, "on_windows", 0),           # platform branch
    ("R/EDI/R/thing.R", 16, 16, "on_windows", 0),
    ("R/EDI/R/thing.R", 18, 18, "on_windows", 3),
    ("R/EDI/R/thing.R", 21, 21, "skipped", 0),              # nocov
    ("R/EDI/src/kern.cpp", 4, 4, "", 7),
    ("R/EDI/src/kern.cpp", 5, 5, "", 0),                    # guard in an Rcpp export
    ("R/EDI/src/kern.cpp", 7, 7, "", 7),
    ("R/EDI/src/kern.cpp", 8, 8, "", 7),
    ("R/EDI/src/kern.cpp", 11, 11, "", 0),                  # isolated arithmetic line: -O2 noise
    ("R/EDI/src/kern.cpp", 12, 12, "", 4),
    ("R/EDI/src/kern.cpp", 16, 16, "", 0),                  # inside #ifdef _WIN32
    ("R/EDI/R/ignored.R", 1, 1, "f", 0),                    # codecov.yml ignores the file
    ("R/EDI/R/artifact.R", 1, 1, "g", 0),                   # registry: excluded
]


def lines_csv(rows, commit="", measured="2026-11-18T00:00:00Z"):
    out = [f"# commit={commit} measured_at={measured} covr=4.0.0", '"file","first_line","last_line","fn","value"']
    out += [f'"{f}",{a},{b},"{fn}",{v}' for f, a, b, fn, v in rows]
    return "\n".join(out) + "\n"


COBERTURA = """<?xml version="1.0" ?>
<coverage version="7.16.1"><sources><source>/w/EDI/python</source></sources><packages>
<package name="src.edi_kernels"><classes>
<class name="_checks.py" filename="src/edi_kernels/_checks.py"><lines>
<line number="3" hits="1"/><line number="4" hits="0"/></lines></class>
</classes></package></packages></coverage>
"""

GCOV_JSON = json.dumps({"format_version": "2", "files": [
    {"file": "kern.cpp", "lines": [{"line_number": 5, "count": 2}, {"line_number": 7, "count": 2}]},
    {"file": "/usr/include/c++/13/cmath", "lines": [{"line_number": 1, "count": 9}]}]})


class _Notes(ac.Notes):
    pass


def git(repo, *a):
    return subprocess.run(["git", *a], cwd=repo, check=True, capture_output=True, text=True).stdout


class Fixture(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.repo = self.tmp / "repo"
        files = {
            "R/EDI/R/thing.R": R_FILE,
            "R/EDI/R/ignored.R": "f = function() 1\n",
            "R/EDI/R/artifact.R": "g = function() 1\n",
            "R/EDI/src/kern.cpp": CPP_FILE,
            "R/EDI/NAMESPACE": "export(compute_thing)\n",
            "R/EDI/man/Thing.Rd": '\\if{html}{\\out{<a id="method-Thing-compute_thing"></a>}}\n',
            "R/EDI/DESCRIPTION": "Version: 1.0.5\n",
            "R/package_tests/coverage_gap_registry.csv": "file,status\nR/EDI/R/artifact.R,excluded\nR/EDI/R/thing.R,pending\n",
            "codecov.yml": 'ignore:\n  - "R/benchmark/**"\n  - "R/EDI/R/ignored.R"\n\ncomment:\n  layout: x\n',
            "R/package_metadata/future_release_plans/release_v1_0_6.md": "- [ ] TODO-2: open.\n- [x] TODO-3: done.\n",
            "python/src/edi_kernels/_checks.py": "import os\n\ndef check(x):\n    return x\n",
        }
        for p, t in files.items():
            (self.repo / p).parent.mkdir(parents=True, exist_ok=True)
            (self.repo / p).write_text(t)
        git(self.repo, "init", "-q", "-b", "main")
        git(self.repo, "-c", "user.name=t", "-c", "user.email=t@t", "add", "-A")
        git(self.repo, "-c", "user.name=t", "-c", "user.email=t@t", "commit", "-qm", "init")
        self.sha = git(self.repo, "rev-parse", "HEAD").strip()
        spec = ac.spec_of(uc)
        self.notes_root = self.tmp / "notes"
        self.ctx = ac.Context(spec, self.repo, ac.Notes(self.notes_root, spec["name"]), self.tmp / "work",
                              scope="auto", sha=self.sha)
        meta, rows = uc.parse_lines_csv(lines_csv(COV_ROWS, self.sha))
        self.coverage = {"lines": uc.expressions_to_lines(rows), "sha": self.sha, "py_sha": "",
                         "sources": ["fixture"], "errors": []}

    def analyse(self):
        self.ctx._unt = None
        return uc.analyse(self.ctx, coverage=self.coverage)


# ---------------------------------------------------------------- coverage parsing

class CoverageParsing(unittest.TestCase):
    def test_lines_csv_and_line_tally(self):
        meta, rows = uc.parse_lines_csv(lines_csv(COV_ROWS, "abc123"))
        self.assertEqual(meta["commit"], "abc123")
        self.assertEqual(meta["covr"], "4.0.0")
        self.assertEqual(len(rows), len(COV_ROWS))
        lines = uc.expressions_to_lines(rows)["R/EDI/R/thing.R"]
        self.assertEqual(lines[4][0], 0)        # inner expression unrun -> line unrun despite the outer one
        self.assertEqual(lines[6][0], 5)
        self.assertEqual(lines[3][1], "compute_thing")

    def test_narrowest_expression_names_the_line(self):
        rows = [("a.R", 1, 9, 1, "outer"), ("a.R", 3, 3, 1, "inner")]
        self.assertEqual(uc.expressions_to_lines(rows)["a.R"][3][1], "inner")

    def test_bad_rows_are_skipped(self):
        meta, rows = uc.parse_lines_csv('"file","first_line","last_line","fn","value"\n"a.R",x,1,"f",1\n"a.R",1,1,"f",0\n')
        self.assertEqual(rows, [("a.R", 1, 1, 0.0, "f")])

    def test_cobertura(self):
        py = uc.parse_cobertura(COBERTURA)
        self.assertEqual(py, {"python/src/edi_kernels/_checks.py": {3: [1.0, ""], 4: [0.0, ""]}})

    def test_gcov_json(self):
        src = Path(tempfile.mkdtemp())
        (src / "R/EDI/src").mkdir(parents=True)
        out = uc.merge_gcov_json("noise\n" + GCOV_JSON + "\n", src / "R/EDI/src", src, {})
        self.assertEqual(out, {"R/EDI/src/kern.cpp": {5: 2, 7: 2}})     # the system header is dropped


# ---------------------------------------------------------------- moving lines to HEAD

class LineMapping(unittest.TestCase):
    DIFF = ("diff --git a/x.R b/x.R\n--- a/x.R\n+++ b/x.R\n@@ -3,0 +4,2 @@\n+a\n+b\n@@ -10,2 +12,1 @@\n-c\n-d\n+e\n"
            "diff --git a/gone.R b/gone.R\n--- a/gone.R\n+++ /dev/null\n@@ -1,3 +0,0 @@\n-x\n-y\n-z\n")

    def test_parse_diff(self):
        d = uc.parse_diff(self.DIFF)
        self.assertEqual(d["x.R"]["hunks"], [(3, 0, 4, 2), (10, 2, 12, 1)])
        self.assertTrue(d["gone.R"]["deleted"])

    def test_map_line(self):
        h = uc.parse_diff(self.DIFF)["x.R"]["hunks"]
        self.assertEqual(uc.map_line(h, 3), 3)          # before the insertion
        self.assertEqual(uc.map_line(h, 4), 6)          # shifted by the 2 inserted lines
        self.assertIsNone(uc.map_line(h, 10))           # changed
        self.assertIsNone(uc.map_line(h, 11))
        self.assertEqual(uc.map_line(h, 12), 13)        # +2 -2 +1
        self.assertEqual(uc.changed_new_lines(h), {4, 5, 12})


class MoveToHead(Fixture):
    def test_lines_follow_an_insertion_and_drop_changed_lines(self):
        p = self.repo / "R/EDI/R/thing.R"
        text = p.read_text().replace("#' @export\n", "#' @export\n# a new comment line\n")
        text = text.replace("\ty = x + 1\n", "\ty = x + 2\n")
        p.write_text(text)
        git(self.repo, "-c", "user.name=t", "-c", "user.email=t@t", "commit", "-qam", "edit")
        moved, dropped = uc.move_to_head({"R/EDI/R/thing.R": self.coverage["lines"]["R/EDI/R/thing.R"]}, self.sha, self.repo)
        m = moved["R/EDI/R/thing.R"]
        self.assertEqual(m[5][0], 0)           # the guard line 4 is now line 5
        self.assertNotIn(7, m)                 # old line 6 changed: not measured as it is now
        self.assertEqual(dropped, 1)


# ---------------------------------------------------------------- sources

class Sources(unittest.TestCase):
    def test_cpp_functions(self):
        f = uc.cpp_functions(CPP_FILE)
        names = {n: (a, b) for n, a, b in f}
        self.assertEqual(names["kernel_cpp"], (3, 9))
        self.assertEqual(names["helper"], (10, 13))
        self.assertEqual(uc.enclosing(f, 5)[0], "kernel_cpp")
        self.assertIsNone(uc.enclosing(f, 1))

    def test_cpp_namespaces_and_strings(self):
        text = 'namespace a {\nstruct S { int v; };\nint f(int x) {\n  const char* s = "{";\n  return x;\n}\n}\n'
        self.assertEqual(uc.cpp_functions(text), [("f", 3, 6)])

    def test_nocov_and_platform(self):
        src = R_FILE.splitlines()
        self.assertIn(21, uc.nocov_lines(src))
        self.assertEqual(uc.nocov_lines(["a", "# nocov start", "b", "# nocov end", "c"]), {2, 3, 4})
        self.assertIn(16, uc.cpp_platform_lines(CPP_FILE.splitlines()))
        self.assertNotIn(11, uc.cpp_platform_lines(CPP_FILE.splitlines()))

    def test_controlling_line(self):
        src = R_FILE.splitlines()
        self.assertIn(".Platform$OS.type", uc.controlling_line(src, 15))
        self.assertEqual(uc.controlling_line(src, 6), "")          # the block opener is the function line

    def test_codecov_ignores_and_registry(self):
        self.assertEqual(uc.codecov_ignores('x: 1\nignore:\n  - "a/**"\n  # c\n  - b.R\nnext: 2\n  - "z"\n'), ["a/**", "b.R"])
        self.assertTrue(uc.glob_match("a/b/c.R", "a/**"))
        self.assertFalse(uc.glob_match("ab/c.R", "a/**"))
        self.assertEqual(uc.registry_excluded("file,status\nx.R,excluded\ny.R,pending\n"), {"x.R"})


# ---------------------------------------------------------------- regions, ids, exclusions, ranking

class Regions(Fixture):
    def test_regions_exclusions_and_order(self):
        res = self.analyse()
        self.assertEqual(res["errors"], [])
        got = {(r["file"], r["first"], r["last"]): r for r in res["regions"]}
        self.assertIn(("R/EDI/R/thing.R", 4, 4), got)
        self.assertIn(("R/EDI/R/thing.R", 10, 11), got)
        self.assertIn(("R/EDI/src/kern.cpp", 5, 5), got)
        files = {r["file"] for r in res["regions"]}
        self.assertNotIn("R/EDI/R/ignored.R", files)
        self.assertNotIn("R/EDI/R/artifact.R", files)
        lines = {(r["file"], n) for r in res["regions"] for n in r["lines"]}
        for excluded in [("R/EDI/R/thing.R", 15), ("R/EDI/R/thing.R", 21), ("R/EDI/src/kern.cpp", 11),
                         ("R/EDI/src/kern.cpp", 16)]:
            self.assertNotIn(excluded, lines)
        self.assertEqual(res["excluded"], {"codecov.yml ignores the file": 1, "coverage registry marks the file excluded": 1,
                                           "platform branch": 2, "nocov": 1, "-O2 line noise": 1})
        # Ranked by risk: the exported compute_thing guard (public + entry point + guard) first, then
        # the guard in the Rcpp export (kernel + guard), then the internal helper's guard.
        order = [(r["file"], r["first"]) for r in res["regions"]]
        self.assertEqual(order[0], ("R/EDI/R/thing.R", 4))
        self.assertEqual(order[1], ("R/EDI/src/kern.cpp", 5))
        top = res["regions"][0]
        self.assertIn("error/guard branch", top["signals"])
        self.assertTrue(any(s.startswith("public API") for s in top["signals"]))
        self.assertIn("compute_* / design entry point", top["signals"])
        self.assertIn("Rcpp-exported kernel", res["regions"][1]["signals"])

    def test_region_id_survives_a_line_move_but_not_an_edit(self):
        src = R_FILE.splitlines()
        a = uc.region_id("R/EDI/R/thing.R", "helper_internal", src, [10, 11])
        moved = ["# new"] * 3 + src
        self.assertEqual(a, uc.region_id("R/EDI/R/thing.R", "helper_internal", moved, [13, 14]))
        edited = list(src)
        edited[9] = "\tif (is.na(z)) return(NA_integer_)"
        self.assertNotEqual(a, uc.region_id("R/EDI/R/thing.R", "helper_internal", edited, [10, 11]))
        self.assertNotEqual(a, uc.region_id("R/EDI/R/other.R", "helper_internal", src, [10, 11]))
        self.assertRegex(a, r"^unt-[0-9a-f]{12}$")

    def test_identical_regions_get_distinct_ids(self):
        lines = {"a.R": {1: [0, "f"], 2: [1, "f"], 3: [0, "f"]}}
        regs = uc.build_regions(lines, {"a.R": "x = 1\ny = 2\nx = 1\n"})
        self.assertEqual(len(regs), 2)
        self.assertNotEqual(regs[0]["id"], regs[1]["id"])

    def test_a_covered_line_or_a_new_function_splits_regions(self):
        lines = {"a.R": {1: [0, "f"], 2: [0, "f"], 3: [0, "g"], 4: [2, "g"], 5: [0, "g"]}}
        regs = uc.build_regions(lines, {"a.R": "a\nb\nc\nd\ne\n"})
        self.assertEqual([r["lines"] for r in regs], [[1, 2], [3], [5]])

    def test_trivial_lines_do_not_make_regions(self):
        regs = uc.build_regions({"a.R": {1: [0, "f"], 2: [0, "f"]}}, {"a.R": "}\n  else {\n"})
        self.assertEqual(regs, [])

    def test_recent_and_todo_signals(self):
        src = R_FILE.splitlines()
        r = {"file": "R/EDI/R/thing.R", "fn": "helper_internal", "lines": [10, 11], "first": 10, "last": 11, "lang": "R"}
        base = uc.score_region(dict(r), src, set(), {}, {}, {}, {})
        s = uc.score_region(r, src, set(), {}, {}, {"R/EDI/R/thing.R": {11}}, {"R/EDI/R/thing.R": {10}})
        self.assertAlmostEqual(s - base, 3.0)
        self.assertIn("on a line a current-release TODO fix changed", r["signals"])

    def test_risk_beats_size(self):
        src = ["x = 1"] * 200
        big = {"file": "a.R", "fn": "internal", "lines": list(range(1, 150)), "first": 1, "last": 149, "lang": "R"}
        small = {"file": "a.R", "fn": "compute_x", "lines": [160], "first": 160, "last": 160, "lang": "R"}
        self.assertGreater(uc.score_region(small, src, {"compute_x"}, {}, {}, {}, {}),
                           uc.score_region(big, src, set(), {}, {}, {}, {}))

    def test_diversify(self):
        regs = [{"file": f"f{i % 2}.R", "fn": "same", "id": str(i)} for i in range(6)]
        regs += [{"file": f"g{i}.R", "fn": f"h{i}", "id": f"g{i}"} for i in range(3)]
        got = uc.diversify(regs, 5, per_fn=2, per_file=3)
        self.assertEqual([r["id"] for r in got], ["0", "1", "g0", "g1", "g2"])


class Allowlist(Fixture):
    def state(self, base, num):
        return {("release_v1_0_6.md", "2"): ("open", ""), ("release_v1_0_6.md", "3"): ("ticked", "done")}.get(
            (base, num), ("missing", "no such TODO"))

    def test_validation(self):
        rows = uc.read_allowlist('match,reason\nunt-0123456789ab,"v1.0.6-TODO-2: mirai paths"\n'
                                 'R/EDI/src/x.cpp::f,"v1.0.6-TODO-3: done"\nR/EDI/R/a.R,"no citation"\n'
                                 'R/EDI/R/b.R,"v1.0.6 TODO-2: old style"\n,"v1.0.6-TODO-2: empty"\n'
                                 'R/EDI/R/c.R,"v1.0.6-TODO-99: missing"\n')
        valid, problems = uc.validate_allowlist(rows, self.state)
        self.assertEqual([v["match"] for v in valid], ["unt-0123456789ab"])
        self.assertEqual(len(problems), 5)
        self.assertTrue(any("is ticked" in p for p in problems))
        self.assertTrue(any("is missing" in p for p in problems))
        self.assertTrue(any("must start with an open release TODO" in p for p in problems))

    def test_matching(self):
        rows = [{"match": "unt-aaaaaaaaaaaa", "reason": "r"}, {"match": "R/EDI/src/*.cpp::helper*", "reason": "r"},
                {"match": "R/EDI/R/z.R", "reason": "r"}]
        self.assertTrue(uc.allow_match({"id": "unt-aaaaaaaaaaaa", "file": "q.R", "fn": ""}, rows))
        self.assertTrue(uc.allow_match({"id": "unt-b", "file": "R/EDI/src/k.cpp", "fn": "helper2"}, rows))
        self.assertFalse(uc.allow_match({"id": "unt-b", "file": "R/EDI/src/k.cpp", "fn": "kernel"}, rows))
        self.assertTrue(uc.allow_match({"id": "unt-b", "file": "R/EDI/R/z.R", "fn": "any"}, rows))

    def test_an_open_row_excludes_and_a_ticked_one_does_not(self):
        rid = next(r["id"] for r in self.analyse()["regions"] if r["file"] == "R/EDI/src/kern.cpp")
        (self.repo / uc.ALLOWLIST).parent.mkdir(parents=True, exist_ok=True)
        (self.repo / uc.ALLOWLIST).write_text(f'match,reason\n{rid},"v1.0.6-TODO-3: ticked, excuses nothing"\n')
        res = self.analyse()
        self.assertIn(rid, [r["id"] for r in res["regions"]])
        self.assertEqual(len(res["allow_problems"]), 1)
        (self.repo / uc.ALLOWLIST).write_text(f'match,reason\n{rid},"v1.0.6-TODO-2: open"\n')
        res = self.analyse()
        self.assertNotIn(rid, [r["id"] for r in res["regions"]])
        self.assertEqual(res["excluded"].get("allowlisted"), 1)


# ---------------------------------------------------------------- selection and state

class Selection(Fixture):
    def test_due(self):
        now = ac.parse_time("2026-11-18T00:00:00+00:00")
        self.assertTrue(uc.due(None, now))
        self.assertFalse(uc.due({"status": "proposed"}, now))
        self.assertFalse(uc.due({"status": "unreachable"}, now))
        self.assertFalse(uc.due({"status": "failed", "attempts": 1, "last_attempt": "2026-11-10T00:00:00+00:00"}, now))
        self.assertTrue(uc.due({"status": "failed", "attempts": 1, "last_attempt": "2026-10-01T00:00:00+00:00"}, now))
        self.assertFalse(uc.due({"status": "failed", "attempts": 2, "last_attempt": "2026-01-01T00:00:00+00:00"}, now))

    def test_units_skip_when_no_code_changed(self):
        self.analyse()
        self.ctx.manifest["code_sha"] = self.sha
        self.assertEqual(uc.units(self.ctx), {})
        self.assertIn("no code or test change", self.ctx._unt["skipped"])
        saved = uc.load_analysis(self.ctx)
        self.assertIn("skipped", saved)

    def test_units_carry_context_and_respect_state(self):
        res = self.analyse()
        top = res["regions"][0]["id"]
        uc.save_regions_state(self.ctx, {top: {"status": "proposed"}})
        out = uc.units(self.ctx)
        self.assertNotIn(top, out)
        self.assertTrue(out)
        u = next(iter(out.values()))
        self.assertIn(">>", u["context"]["excerpt"])
        self.assertEqual(u["hash"], next(iter(out)))
        self.assertTrue(uc.load_analysis(self.ctx)["regions"])

    def test_python_regions_are_listed_not_sent(self):
        cov = dict(self.coverage)
        cov["lines"] = {**cov["lines"], "python/src/edi_kernels/_checks.py": {3: [0.0, ""], 4: [0.0, ""]}}
        self.coverage = cov
        self.analyse()
        out = uc.units(self.ctx)
        self.assertFalse(any(k for k, v in out.items() if v["context"]["file"].startswith("python/")))
        self.assertEqual(len(self.ctx._unt["python_regions"]), 1)
        # In the report: a tracked mechanical finding keyed by region id, not a "For information" line.
        parts = uc.apply(self.ctx, [], [], verifier=lambda c, t: {}, availability=lambda: (True, ""))
        py = [x for x in parts["mechanical"] if isinstance(x, dict)]
        self.assertEqual([(x["unit"], x["kind"]) for x in py], [(uc.PY_UNIT, "python-region")])
        self.assertEqual(py[0]["key"], self.ctx._unt["python_regions"][0]["id"])
        self.assertIn(uc.PY_UNIT, parts["mechanical_scope_units"])
        self.assertFalse(any("Python region" in x for x in parts["info"]))


# ---------------------------------------------------------------- verification and apply

def run_result(counts=None, msgs=(), r_hits=None, c_hits=None, timed_out=False):
    c = {"fail": 0, "error": 0, "skip": 0, "warning": 0, "pass": 0}
    c.update(counts or {"pass": 2})
    return {"counts": c, "messages": list(msgs), "timed_out": timed_out, "seconds": 3.0,
            "r_hits": r_hits or {}, "c_hits": c_hits or {}, "timeout": "600 s"}


class Judging(unittest.TestCase):
    REG = {"file": "R/EDI/R/thing.R", "lang": "R", "lines": [10, 11]}

    def test_asserts_behaviour(self):
        self.assertTrue(uc.asserts_behaviour("expect_equal(f(1), 4, tolerance = 1e-12)")[0])
        self.assertTrue(uc.asserts_behaviour('expect_error(f(-1), "non-negative")')[0])
        self.assertTrue(uc.asserts_behaviour('expect_error(f(-1), regexp = "x")')[0])
        self.assertFalse(uc.asserts_behaviour("expect_no_error(f(1))")[0])
        self.assertFalse(uc.asserts_behaviour("expect_true(TRUE); f(1)")[0])
        self.assertFalse(uc.asserts_behaviour("expect_error(f(-1))")[0])

    def test_judge(self):
        hits = {"R/EDI/R/thing.R": {10: 1, 11: 1}}
        self.assertTrue(uc.judge_test(run_result(r_hits=hits), self.REG, "expect_equal(1, 1)")[0])
        ok, why = uc.judge_test(run_result(r_hits={"R/EDI/R/thing.R": {10: 1}}), self.REG, "expect_equal(1, 1)",
                                min_share=0.75)
        self.assertFalse(ok)
        self.assertIn("1 of the region's 2 lines", why)
        self.assertFalse(uc.judge_test(run_result({"pass": 1, "fail": 1}, [("fail", "x")], hits), self.REG, "expect_equal(1,1)")[0])
        self.assertFalse(uc.judge_test(run_result({"pass": 0, "error": 1}, [("error", "boom")], hits), self.REG, "expect_equal(1,1)")[0])
        self.assertFalse(uc.judge_test(run_result({"skip": 1}, r_hits=hits), self.REG, "expect_equal(1,1)")[0])
        self.assertFalse(uc.judge_test(run_result({"pass": 0}, r_hits=hits), self.REG, "expect_equal(1,1)")[0])
        self.assertFalse(uc.judge_test(run_result(r_hits=hits, timed_out=True), self.REG, "expect_equal(1,1)")[0])
        self.assertFalse(uc.judge_test(run_result(r_hits=hits), self.REG, "expect_no_error(f())")[0])
        cpp = {"file": "R/EDI/src/kern.cpp", "lang": "C++", "lines": [5]}
        self.assertTrue(uc.judge_test(run_result(c_hits={"R/EDI/src/kern.cpp": {5: 2}}), cpp, "expect_equal(1,1)")[0])


class Apply(Fixture):
    def setUp(self):
        super().setUp()
        res = self.analyse()
        uc.save_analysis(self.ctx, res)
        self.reg = {r["file"] + ":" + str(r["first"]): r for r in res["regions"]}
        self.guard = self.reg["R/EDI/R/thing.R:4"]
        self.helper = self.reg["R/EDI/R/thing.R:10"]
        self.kernel = self.reg["R/EDI/src/kern.cpp:5"]
        (self.ctx.workdir / "plan.json").write_text(json.dumps({"units": {r["id"]: {} for r in res["regions"]}}))
        self.calls = []

    def finding(self, region, outcome, code="expect_equal(compute_thing(1), 4)", **kw):
        return {"unit": region["id"], "outcome": outcome, "text": f"{outcome} text", "evidence": "a.R:1",
                "test_name": f"{outcome} name", "test_file_slug": f"thing-{outcome}-reference", "test_code": code,
                "reference": "closed form", "failure_contains": kw.get("failure_contains", "")}

    def verifier(self, results):
        def v(ctx, tests):
            self.calls.append([t["key"] for t in tests])
            return {t["key"]: results[t["finding"]["unit"]] for t in tests}
        return v

    def test_apply(self):
        findings = [
            self.finding(self.guard, "test", 'expect_error(compute_thing(-1), "non-negative")'),
            self.finding(self.helper, "test", "expect_equal(helper_internal(2), 2)"),
            self.finding(self.kernel, "bug", "expect_equal(kernel_cpp(2e6), 4e6)", failure_contains="4e+06"),
        ]
        unreach = {"unit": "unt-not-ranked", "outcome": "test"}      # not a region of this run: ignored
        results = [{"findings": findings + [unreach]}]
        runs = {
            self.guard["id"]: run_result(r_hits={"R/EDI/R/thing.R": {4: 1}}),
            self.helper["id"]: run_result(r_hits={"R/EDI/R/thing.R": {9: 1}}),   # passes, misses its lines
            self.kernel["id"]: run_result({"pass": 0, "fail": 1}, [("fail", "kernel_cpp(2e6) not equal to 4e+06")]),
        }
        parts = uc.apply(self.ctx, results, [], verifier=self.verifier(runs), availability=lambda: (True, ""))
        self.assertEqual(len(self.calls), 1)                          # one verification pass for all
        self.assertEqual(len(parts["applied"]), 1)
        written = list((self.repo / uc.BULK).glob("test-*.R"))
        self.assertEqual(len(written), 1)
        text = written[0].read_text()
        self.assertIn("library(testthat)\nlibrary(EDI)", text)
        self.assertIn(self.guard["id"], text)
        self.assertNotIn("skip(", text)
        self.assertNotIn("todo", written[0].name.lower())
        self.assertEqual(parts["proposed"][0]["unit"], self.guard["id"])
        self.assertTrue(parts["proposed"][0]["applied_text"].startswith("test_that("))
        human = " ".join(ac.texts(parts["human"]))
        self.assertIn("Possible bug", human)                          # reported ...
        self.assertFalse(any("kernel" in p.name for p in written))    # ... never committed
        state = uc.regions_state(self.ctx)
        self.assertEqual(state[self.guard["id"]]["status"], "proposed")
        self.assertEqual(state[self.helper["id"]]["status"], "failed")
        self.assertIn("executed 0 of", state[self.helper["id"]]["last_reason"])
        self.assertEqual(state[self.kernel["id"]]["status"], "bug")
        self.assertTrue(self.ctx.notes.manifest().get("code_sha"))

    def test_unreachable_feeds_the_dead_code_audit(self):
        results = [{"findings": [self.finding(self.helper, "unreachable", code="")]}]
        parts = uc.apply(self.ctx, results, [], verifier=self.verifier({}), availability=lambda: (True, ""))
        self.assertEqual(self.calls, [])
        data = json.loads((self.ctx.notes.dir / "unreachable.json").read_text())
        self.assertIn(self.helper["id"], data)
        self.assertTrue(any("Dead-code candidate" in x for x in parts["info"]))
        # The dead-code audit reads it from the same notes clone.
        dspec = ac.spec_of(dc)
        dctx = ac.Context(dspec, self.repo, ac.Notes(self.notes_root, dspec["name"]), self.tmp / "work2")
        cands = dc.untested_candidates(dctx)
        self.assertIn(f"region:{self.helper['id']}", cands)
        self.assertEqual(cands[f"region:{self.helper['id']}"]["file"], "R/EDI/R/thing.R")

    def test_second_failure_becomes_a_decision(self):
        uc.save_regions_state(self.ctx, {self.helper["id"]: {"status": "failed", "attempts": 1}})
        results = [{"findings": [self.finding(self.helper, "test", "expect_equal(helper_internal(2), 2)")]}]
        runs = {self.helper["id"]: run_result({"pass": 0, "error": 1}, [("error", "object not found")])}
        parts = uc.apply(self.ctx, results, [], verifier=self.verifier(runs), availability=lambda: (True, ""))
        self.assertEqual(uc.regions_state(self.ctx)[self.helper["id"]]["status"], "gave_up")
        self.assertTrue(any("No test after 2 attempts" in t for t in ac.texts(parts["human"])))

    def test_no_r_means_nothing_runs_or_lands(self):
        results = [{"findings": [self.finding(self.guard, "test")]}]
        parts = uc.apply(self.ctx, results, [], verifier=self.verifier({}), availability=lambda: (False, "no R"))
        self.assertEqual(self.calls, [])
        self.assertEqual(parts["applied"], [])
        self.assertTrue(any("NOT VERIFIED (no R)" in t for t in ac.texts(parts["human"])))

    def test_intended_is_a_decision_naming_the_allowlist(self):
        results = [{"findings": [self.finding(self.helper, "intended", code="")]}]
        parts = uc.apply(self.ctx, results, [], verifier=self.verifier({}), availability=lambda: (True, ""))
        self.assertTrue(any(uc.ALLOWLIST in t for t in ac.texts(parts["human"])))
        self.assertEqual(uc.regions_state(self.ctx)[self.helper["id"]]["status"], "intended")

    def test_gone_regions_leave_the_state(self):
        uc.save_regions_state(self.ctx, {"unt-gonegonegone": {"status": "proposed"}})
        (self.ctx.notes.dir / "unreachable.json").write_text(json.dumps({"unt-gonegonegone": {"file": "x.R"}}))
        uc.apply(self.ctx, [], [], verifier=self.verifier({}), availability=lambda: (True, ""))
        self.assertNotIn("unt-gonegonegone", uc.regions_state(self.ctx))
        self.assertEqual(json.loads((self.ctx.notes.dir / "unreachable.json").read_text()), {})


class Spec(unittest.TestCase):
    def test_spec_and_prompt_files(self):
        spec = ac.spec_of(uc)
        self.assertEqual(spec["name"], "untested-code")
        self.assertEqual(uc.TOP_N, 12)
        root = Path(__file__).resolve().parents[2]
        schema_text = (root / ".github/prompts/audit_untested_code.schema.json").read_text()
        self.assertNotIn("'", schema_text)          # passed as --json-schema '...'
        schema = json.loads(schema_text)
        self.assertEqual(schema["properties"]["findings"]["items"]["properties"]["outcome"]["enum"], list(uc.OUTCOMES))
        self.assertTrue((root / ".github/prompts/audit_untested_code.md").exists())
        wf = (root / ".github/workflows/audit-untested-code.yml").read_text()
        self.assertIn("name: audit · weekly · untested-code", wf)
        self.assertIn('"audit · weekly · untested-code"', (root / ".github/workflows/audit-status.yml").read_text())


if __name__ == "__main__":
    unittest.main(verbosity=1)
