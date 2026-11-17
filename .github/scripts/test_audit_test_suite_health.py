#!/usr/bin/env python3
"""Checks for the test-suite-health audit (audits/test_suite_health.py). Stdlib only, no network."""
import datetime as dt
import io
import json
import shutil
import subprocess
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import audit_common as ac  # noqa: E402
from audits import test_suite_health as tsh  # noqa: E402

NOW = dt.datetime(2026, 11, 17, 6, tzinfo=dt.timezone.utc)
T = "R/EDI/tests/testthat/test-a.R"


def parsed_file(path, tests=(), functions=(), skips=(), error=None):
    if error:
        return {"file": path, "error": error}
    return {"file": path, "tests": list(tests), "functions": list(functions), "skips": list(skips)}


class Literals(unittest.TestCase):
    def test_never_lifts(self):
        self.assertTrue(tsh.never_lifts("skip_if", "skip_if(TRUE)"))
        self.assertTrue(tsh.never_lifts("skip_if", "testthat::skip_if( T , 'why')"))
        self.assertTrue(tsh.never_lifts("skip_if_not", "skip_if_not(FALSE)"))
        self.assertTrue(tsh.never_lifts("skip_on_os", 'skip_on_os(c("windows", "mac", "linux", "solaris"))'))
        self.assertIsNone(tsh.never_lifts("skip_on_os", 'skip_on_os(c("windows", "mac"))'))
        self.assertIsNone(tsh.never_lifts("skip_if", "skip_if(TRUE_FLAG)"))
        self.assertIsNone(tsh.never_lifts("skip_if", "skip_if(!has_pkg)"))
        self.assertIsNone(tsh.never_lifts("skip_if_not", "skip_if_not(TRUE)"))


class Static(unittest.TestCase):
    def test_helpers_propagate_through_calls_not_variables(self):
        parsed = [
            parsed_file("h.R", functions=[
                {"name": "inner", "calls": ["expect_equal"], "symbols": []},
                {"name": "outer", "calls": ["inner"], "symbols": []},
                {"name": "reads_var", "calls": ["sum"], "symbols": ["outer"]},   # a variable, not a call
                {"name": "passes", "calls": ["lapply"], "symbols": ["expect_true"]},
            ]),
        ]
        self.assertEqual(tsh.expectation_helpers(parsed), {"inner", "outer", "passes"})

    def test_findings(self):
        parsed = [
            parsed_file("h.R", functions=[{"name": "check", "calls": ["expect_true"], "symbols": []}]),
            parsed_file(T, tests=[
                {"line": 1, "desc": "\"empty\"", "calls": ["test_that", "sum"], "symbols": ["x"]},
                {"line": 5, "desc": "\"helper\"", "calls": ["test_that", "check"], "symbols": []},
                {"line": 9, "desc": "\"by name\"", "calls": ["test_that", "lapply"], "symbols": ["check"]},
                {"line": 12, "desc": "\"stop\"", "calls": ["test_that", "stopifnot"], "symbols": []},
                {"line": 15, "desc": "\"skipped\"", "calls": ["test_that", "skip"], "symbols": []},
                {"line": 18, "desc": "\"cond\"", "calls": ["test_that", "skip", "expect_equal"], "symbols": []},
            ], skips=[
                {"line": 15, "fn": "skip", "text": "skip(\"later\")", "test_line": 15, "unconditional": True},
                {"line": 18, "fn": "skip", "text": "skip(\"x\")", "test_line": 18, "unconditional": False},
                {"line": 30, "fn": "skip_if", "text": "skip_if(TRUE)", "test_line": None, "unconditional": True},
                {"line": 31, "fn": "skip", "text": "skip(\"all\")", "test_line": None, "unconditional": True},
            ]),
            parsed_file("R/EDI/tests/testthat/test-bad.R", error="1:3: unexpected '{'\nmore"),
            parsed_file("R/EDI/tests/testthat/fixtures/f.R", error="not a test file"),
        ]
        out = tsh.static_findings(parsed, {T, "R/EDI/tests/testthat/test-bad.R"})
        by = {(f["kind"], f["unit"]) for f in out}
        self.assertIn(("no-expectation", f"{T} :: empty"), by)
        self.assertIn(("no-expectation", f"{T} :: stop"), by)
        self.assertNotIn(("no-expectation", f"{T} :: helper"), by)
        self.assertNotIn(("no-expectation", f"{T} :: by name"), by)
        self.assertNotIn(("no-expectation", f"{T} :: skipped"), by)     # reported as a skip instead
        self.assertIn(("unconditional-skip", f"{T} :: skipped"), by)
        self.assertNotIn(("unconditional-skip", f"{T} :: cond"), by)
        self.assertIn(("never-lifts", f"{T} (file level)"), by)
        self.assertIn(("unconditional-skip", f"{T} (file level)"), by)
        self.assertIn(("parse-error", "R/EDI/tests/testthat/test-bad.R"), by)
        self.assertEqual(sum(1 for f in out if f["kind"] == "parse-error"), 1)
        stop = [f for f in out if f["unit"] == f"{T} :: stop"][0]
        self.assertIn("stopifnot", stop["text"])

    def test_skip_citing_a_todo(self):
        tests = [{"line": i, "desc": f'"t{i}"', "calls": ["test_that", "skip"], "symbols": []} for i in (1, 2, 3)]
        skips = [{"line": 1, "fn": "skip", "text": 'skip("known bug, v1.0.6-TODO-51")', "test_line": 1, "unconditional": True},
                 {"line": 2, "fn": "skip", "text": 'skip("known bug, v1.0.6-TODO-7")', "test_line": 2, "unconditional": True},
                 {"line": 3, "fn": "skip", "text": 'skip("known bug, v9.9.9-TODO-1")', "test_line": 3, "unconditional": True}]
        todos = {("1.0.6", 51): True, ("1.0.6", 7): False}
        out = tsh.static_findings([parsed_file(T, tests=tests, skips=skips)], {T}, todos)
        by = {f["unit"]: f["text"] for f in out}
        self.assertNotIn(f"{T} :: t1", by)                       # open TODO: tracked
        self.assertIn("which is done", by[f"{T} :: t2"])
        self.assertIn("which no release file has", by[f"{T} :: t3"])
        self.assertEqual(len(out), 2)                             # skipped tests are not also "no expectation"
        # without the release files every unconditional skip is reported, as before
        self.assertEqual(len(tsh.static_findings([parsed_file(T, tests=tests, skips=skips)], {T})), 3)

    def test_todo_states(self):
        tmp = Path(tempfile.mkdtemp())
        try:
            d = tmp / "R/package_metadata/future_release_plans"
            d.mkdir(parents=True)
            (d / "release_v1_0_6.md").write_text("- [ ] TODO-51 (added): x\n  - [x] sub\n- [x] TODO-7 done\n")
            self.assertEqual(tsh.todo_states(tmp), {("1.0.6", 51): True, ("1.0.6", 7): False})
        finally:
            shutil.rmtree(tmp)

    def test_todo_names(self):
        files = ["d/test-strat-cox-todo110.R", "d/test-todo98-smoke.R", "d/test-x-todo-stub-guards-reference.R",
                 "d/test-plain.R", "d/test-TODO-7-upper.R"]
        out = tsh.todo_name_findings(files)
        self.assertEqual({f["unit"]: f["todo"] for f in out},
                         {"d/test-strat-cox-todo110.R": 110, "d/test-todo98-smoke.R": 98, "d/test-TODO-7-upper.R": 7})
        self.assertEqual(tsh.new_name("d/test-strat-cox-todo110.R"), "d/test-strat-cox.R")
        self.assertEqual(tsh.new_name("d/test-todo98-smoke.R"), "d/test-smoke.R")
        self.assertIsNone(tsh.new_name("d/test-todo98.R"))


@unittest.skipUnless(shutil.which("Rscript"), "R is not installed")
class Parser(unittest.TestCase):
    def test_parser_on_a_fixture(self):
        tmp = Path(tempfile.mkdtemp())
        (tmp / "test-x.R").write_text(
            'h = function(x) expect_true(x)\n'
            'test_that("a", { x = 1 })\n'
            'test_that("b", { skip("no"); h(1) })\n'
            'test_that("c", { if (FALSE) skip("x"); expect_equal(1, 1) })\n'
            'f = function() { skip("in a helper") }\n'
            'skip_if(TRUE)\n'
            'test_that("d", { lapply(1, h) })\n')
        (tmp / "test-bad.R").write_text('test_that("bad" {\n')
        try:
            parsed = tsh.parse_r(tmp, ["test-x.R", "test-bad.R"], tmp / "out.json")
        except RuntimeError as e:
            if "jsonlite" in str(e):
                self.skipTest("jsonlite is not installed")
            raise
        out = tsh.static_findings(parsed, {"test-x.R", "test-bad.R"})
        got = sorted((f["kind"], f["unit"]) for f in out)
        self.assertEqual(got, [("never-lifts", "test-x.R (file level)"), ("no-expectation", "test-x.R :: a"),
                               ("parse-error", "test-bad.R"), ("unconditional-skip", "test-x.R :: b")])


def artifact_zip(rows):
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w") as z:
        z.writestr("timings.csv", "test_file,runtime_tier,elapsed_seconds,status\n"
                   + "".join(f"{f},correctness,1,{s}\n" for f, s in rows))
    return buf.getvalue()


class History(unittest.TestCase):
    def setUp(self):
        self.saved = tsh._gh

    def tearDown(self):
        tsh._gh = self.saved

    def test_flaky(self):
        def run(i, sha, st):
            return {"created_at": f"2026-11-{i:02d}T00:00:00Z", "sha": sha, "statuses": st}
        cache = {
            "1": run(1, "a", {"f.R": "complete", "g.R": "complete", "h.R": "complete", "k.R": "complete"}),
            "2": run(2, "b", {"f.R": "error", "g.R": "error", "h.R": "complete", "k.R": "complete"}),
            "3": run(3, "c", {"f.R": "complete", "g.R": "error", "h.R": "complete", "k.R": "complete"}),
            "4": run(4, "d", {"f.R": "running", "g.R": "complete", "h.R": "complete", "k.R": "error"}),
            "5": run(5, "d", {"k.R": "complete"}),   # a re-run of the same commit
        }
        out = {f["unit"]: f for f in tsh.flaky_findings(cache)}
        self.assertIn("f.R", out)                 # pass, fail, pass, fail
        self.assertNotIn("g.R", out)              # broke once and was fixed
        self.assertNotIn("h.R", out)
        self.assertIn("k.R", out)                 # differed on the same commit
        self.assertIn("same commit", out["k.R"]["detail"])
        self.assertNotIn("same commit", out["f.R"]["detail"])
        # The text (and so the finding id) does not change with the counts.
        self.assertEqual(out["f.R"]["text"], out["k.R"]["text"])

    def test_update_history_reads_only_new_runs(self):
        calls = []

        def fake(*args):
            calls.append(args[0])
            path = args[0]
            if "/workflows/" in path:
                return "\n".join(json.dumps(r) for r in [
                    {"id": 10, "created_at": "2026-11-10T00:00:00Z", "head_sha": "s10", "run_attempt": 1,
                     "conclusion": "failure"},
                    {"id": 9, "created_at": "2026-11-09T00:00:00Z", "head_sha": "s9", "run_attempt": 1,
                     "conclusion": "success"},
                    {"id": 8, "created_at": "2026-11-08T00:00:00Z", "head_sha": "s8", "run_attempt": 1,
                     "conclusion": "cancelled"}]).encode()
            if path.endswith("/runs/10/artifacts?per_page=100"):
                return "\n".join(json.dumps(a) for a in [
                    {"id": 100, "name": "correctness-shard-1", "expired": False},
                    {"id": 101, "name": "correctness-shard-plan", "expired": False},
                    {"id": 102, "name": "correctness-shard-2", "expired": True}]).encode()
            if path.endswith("/artifacts/100/zip"):
                return artifact_zip([("a.R", "complete"), ("b.R", "error")])
            raise AssertionError(path)

        tsh._gh = fake
        old = {"9": {"created_at": "2026-11-09T00:00:00Z", "sha": "s9", "statuses": {"a.R": "complete"}},
               "1": {"created_at": "2026-08-01T00:00:00Z", "sha": "old", "statuses": {}}}
        cache, note = tsh.update_history(old, "o/r", NOW)
        self.assertEqual(set(cache), {"9", "10"})            # 1 is too old, 8 was cancelled
        self.assertEqual(cache["10"]["statuses"], {"a.R": "complete", "b.R": "error"})
        self.assertFalse(any("/runs/9/" in c for c in calls))  # cached runs are not downloaded again
        self.assertIn("created=%3E%3D2026-09-22", calls[0])
        self.assertIn("2 bulk run(s)", note)

    def test_gh_failure_is_reported_not_raised_by_mechanical(self):
        def broken(*a):
            raise RuntimeError("HTTP 403")
        tsh._gh = broken
        with self.assertRaises(RuntimeError):
            tsh.update_history({}, "o/r", NOW)


class Apply(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.repo = self.tmp / "repo"
        d = self.repo / "R/EDI/tests/testthat"
        d.mkdir(parents=True)
        (self.repo / "R/package_tests/ci").mkdir(parents=True)
        (self.repo / "R/package_metadata/future_release_plans").mkdir(parents=True)
        (self.repo / "R/package_metadata/audits").mkdir(parents=True)
        (d / "test-cox-matched-todo110.R").write_text('test_that("x", expect_true(TRUE))\n')
        (d / "test-alpha-todo12.R").write_text("# old note\n")
        (d / "test-beta-todo13.R").write_text("# v1.0.6 TODO-13: cited in the file\n")
        (d / "test-gamma-todo14.R").write_text("\n")
        (d / "test-delta-todo15.R").write_text("\n")
        (d / "test-delta.R").write_text("\n")
        (self.repo / "R/package_tests/ci/test_runtimes.csv").write_text(
            "test_file,runtime_tier,estimated_seconds,estimate_source\n"
            "R/EDI/tests/testthat/test-cox-matched-todo110.R,correctness,1,m\n"
            "R/EDI/tests/testthat/test-cox-matched-todo110.Rx,correctness,1,m\n")
        (self.repo / "R/package_metadata/future_release_plans/release_v1_0_5.md").write_text(
            "- [x] TODO-110 the fix; test `test-cox-matched-todo110.R`.\n- [ ] TODO-111 other\n")
        (self.repo / "R/helper.R").write_text('source("tests/testthat/test-cox-matched-todo110.R")\n')
        run = lambda *a: subprocess.run(["git", *a], cwd=self.repo, check=True, capture_output=True)
        run("init", "-q", "-b", "main")
        run("config", "user.email", "t@t"); run("config", "user.name", "t")
        run("add", "-A"); run("commit", "-qm", "start")
        (d / "test-gamma-todo14.R").write_text("# edited\n")
        run("commit", "-qam", "v1.1.0-TODO-14: add the gamma check")
        notes = ac.Notes(self.tmp / "notes", "test-suite-health")
        self.ctx = ac.Context(ac.spec_of(tsh), self.repo, notes, self.tmp / "work", now=NOW)
        self.ctx.workdir.mkdir(parents=True)

    def test_resolve_release(self):
        d = "R/EDI/tests/testthat/"
        self.assertEqual(tsh.resolve_release(self.ctx, d + "test-cox-matched-todo110.R", 110), "1.0.5")
        self.assertEqual(tsh.resolve_release(self.ctx, d + "test-beta-todo13.R", 13), "1.0.6")
        self.assertEqual(tsh.resolve_release(self.ctx, d + "test-gamma-todo14.R", 14), "1.1.0")
        self.assertIsNone(tsh.resolve_release(self.ctx, d + "test-alpha-todo12.R", 12))

    def test_apply(self):
        d = "R/EDI/tests/testthat/"
        mech = [ac.normalise_finding("test-suite-health", f, "mechanical") for f in
                tsh.todo_name_findings([d + n for n in ("test-cox-matched-todo110.R", "test-alpha-todo12.R",
                                                        "test-delta-todo15.R")])]
        mech.append(ac.normalise_finding("test-suite-health", {
            "unit": d + "test-delta.R :: empty", "kind": "no-expectation",
            "text": "test_that() block calls no expectation", "line": 3}, "mechanical"))
        (self.repo / "R/package_metadata/future_release_plans/release_v1_0_5.md").write_text(
            "- [x] TODO-110 the fix; test `test-cox-matched-todo110.R`.\n"
            "- [ ] TODO-15 delta `test-delta-todo15.R`\n")
        parts = tsh.apply(self.ctx, [], mech)
        new = self.repo / d / "test-cox-matched.R"
        self.assertTrue(new.exists())
        self.assertFalse((self.repo / d / "test-cox-matched-todo110.R").exists())
        first = new.read_text().splitlines()[0]
        self.assertEqual(first, "# v1.0.5-TODO-110 (this file was test-cox-matched-todo110.R).")
        self.assertEqual(new.read_text().splitlines()[1], 'test_that("x", expect_true(TRUE))')
        rt = (self.repo / "R/package_tests/ci/test_runtimes.csv").read_text()
        self.assertIn(d + "test-cox-matched.R,correctness", rt)
        self.assertIn("test-cox-matched-todo110.Rx", rt)            # only exact paths are rewritten
        self.assertEqual(len(parts["applied"]), 1)
        self.assertIn("R/helper.R", parts["applied"][0])          # other referrers are named
        self.assertEqual(len(ac.texts(parts["human"])), 2)                  # alpha: no release; delta: name taken
        self.assertTrue(any("is taken" in h for h in ac.texts(parts["human"])))
        findings_file = (self.repo / tsh.FINDINGS_FILE).read_text()
        for p in parts["proposed"]:
            self.assertIn(p["applied_text"], (self.repo / p["applied_file"]).read_text())
        self.assertIn("test-delta.R :: empty", findings_file)
        self.assertNotIn("todo110", findings_file)
        self.assertEqual(len(parts["mechanical"]), 1)

    def test_findings_file_untouched_when_nothing_to_say(self):
        parts = tsh.apply(self.ctx, [], [])
        self.assertFalse((self.repo / tsh.FINDINGS_FILE).exists())
        self.assertEqual(parts["applied"], [])
        # Once the file exists, a clean run says so.
        (self.repo / tsh.FINDINGS_FILE).write_text("old\n")
        tsh.apply(self.ctx, [], [])
        self.assertIn("No open findings", (self.repo / tsh.FINDINGS_FILE).read_text())


if __name__ == "__main__":
    unittest.main(verbosity=1)
