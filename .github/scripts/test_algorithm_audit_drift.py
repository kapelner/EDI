"""Planted-fixture tests for check 4 (algorithm inventory) of algorithm_audit_drift.py.

Each test builds a tiny fake repo under $TMPDIR (R/EDI/src, R/EDI/R, the audits/
CSVs and row map), points the script's path globals at it, and checks that the
planted defect is flagged and a clean fixture is not. Offline: no URL is fetched.

Run: python3 .github/scripts/test_algorithm_audit_drift.py
"""
import csv
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import algorithm_audit_drift as drift  # noqa: E402

COLS = ["file", "symbol", "problem", "algorithm", "details", "complexity", "audit_row",
        "verdict", "refs", "watch", "source"]
WIKI = "https://en.wikipedia.org/wiki/Iteratively_reweighted_least_squares"


def entry(**kw):
    e = {"file": "R/EDI/src/fit.cpp", "symbol": "fit_irls", "problem": "logistic MLE",
         "algorithm": "IRLS", "details": "", "complexity": "", "audit_row": "A",
         "verdict": "Keep", "refs": WIKI, "watch": "A", "source": "test"}
    e.update(kw)
    return e


class InventoryCheckTests(unittest.TestCase):

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(dir=os.environ.get("TMPDIR"))
        root = Path(self.tmp.name)
        (root / "R/EDI/src").mkdir(parents=True)
        (root / "R/EDI/R").mkdir(parents=True)
        (root / "R/package_metadata/audits").mkdir(parents=True)
        (root / "R/EDI/src/fit.cpp").write_text("double fit_irls() { return 0; }\n")
        (root / "R/EDI/src/RcppExports.cpp").write_text("// generated\n")
        (root / "R/EDI/R/zzz.R").write_text(".onLoad <- function(lib, pkg) NULL\n")
        self.root = root
        self.saved = {k: getattr(drift, k) for k in
                      ("ROOT", "ROW_MAP", "INVENTORY", "REFERENCES", "SRC_DIR", "R_DIR")}
        audits = root / "R/package_metadata/audits"
        drift.ROOT = root
        drift.ROW_MAP = audits / "algorithm_audit_row_map.json"
        drift.INVENTORY = audits / "algorithm_inventory.csv"
        drift.REFERENCES = audits / "algorithm_references.csv"
        drift.SRC_DIR = root / "R/EDI/src"
        drift.R_DIR = root / "R/EDI/R"
        self.cfg = {"max_age_days": 180,
                    "exempt": {"R/EDI/src/RcppExports.cpp": "generated",
                               "R/EDI/R/zzz.R": "package hooks"},
                    "rows": {"A": {"title": "GLM fits", "reviewed": "2026-10-22"}}}
        self.entries = [entry()]
        self.refs = [WIKI]

    def tearDown(self):
        for k, v in self.saved.items():
            setattr(drift, k, v)
        self.tmp.cleanup()

    def run_check(self):
        drift.ROW_MAP.write_text(json.dumps(self.cfg))
        with drift.INVENTORY.open("w", newline="") as fh:
            w = csv.DictWriter(fh, fieldnames=COLS)
            w.writeheader()
            w.writerows(self.entries)
        with drift.REFERENCES.open("w", newline="") as fh:
            w = csv.writer(fh)
            w.writerow(["url", "kind", "title"])
            w.writerows([[u, "wikipedia", "t"] for u in self.refs])
        return drift.check_inventory(offline=True)

    def flags(self, out):
        return {k for k, _ in drift.INVENTORY_FLAGS if out[k]}

    def test_clean_fixture_is_clean(self):
        out = self.run_check()
        self.assertEqual(self.flags(out), set())
        flagged, text = drift.render(
            {"changed": [], "unpinned": [], "not_on_cran": [], "errors": [], "skipped": True},
            {"drifted": [], "stale": [], "max_age": 180},
            {"dangling": [], "untagged": []}, out)
        self.assertFalse(flagged)
        self.assertIn("_Complete and current._", text)

    def test_new_source_file_must_be_inventoried_or_exempt(self):
        (self.root / "R/EDI/R/new_estimator.R").write_text("f <- function() 1\n")
        self.assertEqual(self.run_check()["uncovered"], ["R/EDI/R/new_estimator.R"])

    def test_glob_exempt_covers_files(self):
        (self.root / "R/EDI/src/unity_01.cpp").write_text("")
        self.cfg["exempt"]["R/EDI/src/unity_*.cpp"] = "generated unity build"
        self.assertEqual(self.flags(self.run_check()), set())

    def test_stale_and_redundant_exempt_entries(self):
        self.cfg["exempt"]["R/EDI/src/gone.cpp"] = "deleted"
        self.cfg["exempt"]["R/EDI/src/fit.cpp"] = "also inventoried"
        out = self.run_check()
        self.assertEqual(out["stale_exempt"], ["R/EDI/src/gone.cpp"])
        self.assertEqual(out["exempt_inventoried"], ["R/EDI/src/fit.cpp"])

    def test_renamed_symbol_and_deleted_file(self):
        self.entries = [entry(symbol="fit_newton"), entry(file="R/EDI/src/gone.cpp")]
        out = self.run_check()
        self.assertEqual(len(out["bad_symbol"]), 1)
        self.assertEqual(len(out["bad_file"]), 1)

    def test_references_must_exist_resolve_and_be_used(self):
        self.entries = [entry(refs=""), entry(symbol="", refs="https://doi.org/10.1/x")]
        self.refs = [WIKI]
        out = self.run_check()
        self.assertEqual(len(out["no_refs"]), 1)
        self.assertEqual(len(out["unknown_ref"]), 1)
        self.assertEqual(out["orphan_ref"], [WIKI])

    def test_unknown_audit_rows_and_unwatched_rows(self):
        self.cfg["rows"]["B"] = {"title": "mixtures", "reviewed": "2026-10-22"}
        self.entries = [entry(audit_row="A + ZZ"), entry(symbol="", watch="Q")]
        out = self.run_check()
        self.assertEqual(len(out["bad_row"]), 2)
        self.assertEqual(out["unwatched_row"], ["B"])

    def test_watch_column_drives_kernel_drift_file_lists(self):
        inv = [entry(watch="A"), entry(file="R/EDI/R/x.R", watch=""),
               entry(file="R/EDI/src/y.cpp", watch="A B")]
        self.assertEqual(drift.row_files(inv),
                         {"A": ["R/EDI/src/fit.cpp", "R/EDI/src/y.cpp"], "B": ["R/EDI/src/y.cpp"]})


DIFF = """\
diff --git a/R/EDI/R/new.R b/R/EDI/R/new.R
+++ b/R/EDI/R/new.R
@@ -0,0 +1,4 @@
+fit_em = function(y, x) {
+  helper <- function(z) z
+	compute_tail = function(self) 1
+x <- 3
diff --git a/R/EDI/src/k.cpp b/R/EDI/src/k.cpp
+++ b/R/EDI/src/k.cpp
@@ -10,0 +11,6 @@ double old_kernel(int n)
+static double brent_root(double lo, double hi,
+Eigen::VectorXd solve_ldlt(const Eigen::MatrixXd& A) {
+    if (n > 3) {
+    return compute(x);
+    double y = f(x);
-    removed_fn(1);
+++ /dev/null
+not_parsed = function() 1
"""


class CurrencyContextTests(unittest.TestCase):

    def test_added_definitions_finds_r_and_cpp_functions_only(self):
        self.assertEqual(drift.added_definitions(DIFF), [
            ("R/EDI/R/new.R", "fit_em"), ("R/EDI/R/new.R", "helper"),
            ("R/EDI/R/new.R", "compute_tail"),
            ("R/EDI/src/k.cpp", "brent_root"), ("R/EDI/src/k.cpp", "solve_ldlt")])

    def test_changed_text_includes_hunk_header_function(self):
        touched = drift.changed_text_by_file(DIFF)["R/EDI/src/k.cpp"]
        self.assertIn("old_kernel", touched)      # git's enclosing-function hunk header
        self.assertIn("removed_fn", touched)      # removed lines count as changes


NEWS_HTML = """<html><head><style>p{}</style></head><body>
<h2>pkg 2.1-0</h2><ul>
<li><p>glmer() refreshes the working
weights before the Laplace <code>approximation</code> (numerical fix).</p></li>
<li><p>Typo in a vignette.</p></li></ul>
<h2>pkg 2.0-60</h2><ul><li><p>Default optimizer changed (not newer than the pin).</p></li></ul>
<h2>pkg 2.0-6</h2><ul><li><p>Old algorithm change.</p></li></ul>
</body></html>"""


class NewsParserTests(unittest.TestCase):

    def test_entries_are_whole_and_stop_at_the_pinned_heading(self):
        items = drift.news_items(NEWS_HTML)
        self.assertIn(("item", "glmer() refreshes the working weights before the Laplace "
                       "approximation (numerical fix)."), items)
        # 2.0-60 must not be mistaken for the pin 2.0-6; entries above 2.0-6 are kept
        self.assertEqual(drift.filter_news(items, "2.0-6"), [
            "glmer() refreshes the working weights before the Laplace approximation (numerical fix).",
            "Default optimizer changed (not newer than the pin)."])
        self.assertEqual(drift.filter_news(items, "2.0-60"), [
            "glmer() refreshes the working weights before the Laplace approximation (numerical fix)."])

    def test_missing_pinned_heading_is_said_not_hidden(self):
        out = drift.filter_news(drift.news_items(NEWS_HTML), "1.9-0")
        self.assertTrue(out[0].startswith("(no NEWS heading for the pinned 1.9-0"))


import algorithm_audit_research_report as report  # noqa: E402


class ResearchReportTests(unittest.TestCase):

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(dir=os.environ.get("TMPDIR"))
        self.dir = Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def put(self, task, data):
        (self.dir / f"{task}.json").write_text(json.dumps(data))

    def test_clean_when_every_task_reports_nothing(self):
        self.put("A", {"row": "A", "algorithms_reviewed": [
            {"algorithm": "IRLS", "conclusion": "no_faster_acceptable_found", "note": "ok"}],
            "not_reviewed": [], "findings": []})
        self.put("inventory", {"new_symbols": [{"file": "f", "symbol": "s",
                                                "is_algorithm": False, "reason": "getter"}],
                               "changed_entries": [{"file": "f", "symbol": "t", "stale": False}]})
        flagged, text = report.render(self.dir, ["A", "inventory"])
        self.assertFalse(flagged)
        self.assertIn("1 new functions judged plumbing; 1 changed entries still accurate", text)

    def test_missing_notrun_or_bad_output_is_never_clean(self):
        (self.dir / "B.notrun").write_text("ANTHROPIC_API_KEY repository secret is not set")
        (self.dir / "C.json").write_text("{not json")
        flagged, text = report.render(self.dir, ["A", "B", "C"])
        self.assertTrue(flagged)
        self.assertIn("**A**: no output", text)
        self.assertIn("**B**: ANTHROPIC_API_KEY", text)
        self.assertIn("**C**: output was not valid JSON", text)

    def test_batch_algorithm_in_neither_list_is_a_silent_skip(self):
        self.put("A.1", {"row": "A", "algorithms_reviewed": [
            {"algorithm": "IRLS", "conclusion": "no_faster_acceptable_found", "note": "ok"}],
            "not_reviewed": [], "findings": []})
        flagged, text = report.render(self.dir, ["A.1"], {"A.1": ["IRLS", "L-BFGS"]})
        self.assertTrue(flagged)
        self.assertIn("Batch A.1: L-BFGS (**silently skipped**", text)

    def test_findings_stale_rows_new_algorithms_and_skips_flag(self):
        self.put("J", {"row": "J", "algorithms_reviewed": [], "findings": [{
            "algorithm": "bootstrap loop", "entries": ["R/EDI/src/b.cpp::boot"],
            "current": "refit per replicate", "candidate": "one-step bootstrap",
            "claimed_speedup": "10x (Table 2 of url)", "applies_at_edi_sizes": "yes",
            "keeps_estimator": "no", "tradeoffs": "approximate", "sources": ["https://x"],
            "confidence": "low", "suggested_action": "prototype"}],
            "not_reviewed": [{"algorithm": "Bayesian bootstrap", "reason": "turn budget"}]})
        self.put("inventory", {"new_symbols": [{"file": "f.R", "symbol": "em", "is_algorithm": True,
                                                "reason": "EM", "proposed": {
                                                    "problem": "p", "algorithm": "EM",
                                                    "details": "d", "complexity": "O(n)",
                                                    "audit_row": "B", "refs": ["https://y"]}}],
                               "changed_entries": [{"file": "g.cpp", "symbol": "fit", "stale": True,
                                                    "issue": "now L-BFGS",
                                                    "may_affect_verdict": True}]})
        flagged, text = report.render(self.dir, ["J", "inventory"])
        self.assertTrue(flagged)
        for s in ("bootstrap loop → one-step bootstrap", "keeps the estimator: no",
                  "`f.R` `em`: EM (row B", "(may affect the verdict)",
                  "Batch J: Bayesian bootstrap (turn budget)"):
            self.assertIn(s, text)


import algorithm_audit_research_apply as research_apply  # noqa: E402


class ResearchApplyTests(InventoryCheckTests):
    """Reuses the planted repo; inherits (and so re-runs) the inventory tests too."""

    def write_agent_output(self, data):
        out = Path(self.tmp.name) / "research"
        out.mkdir(exist_ok=True)
        (out / "inventory.json").write_text(json.dumps(data))
        return out

    def test_new_row_added_with_known_ref_and_inherited_watch(self):
        (self.root / "R/EDI/src/fit.cpp").write_text(
            "double fit_irls() { return 0; }\ndouble brent_root() { return 1; }\n")
        self.run_check()  # writes the fixture CSVs
        d = self.write_agent_output({"new_symbols": [
            {"file": "R/EDI/src/fit.cpp", "symbol": "brent_root", "is_algorithm": True, "reason": "",
             "proposed": {"problem": "root", "algorithm": "Brent", "details": "d",
                          "complexity": "O(log)", "audit_row": "A", "refs": [WIKI, "https://x.org/y"]}},
            {"file": "R/EDI/src/fit.cpp", "symbol": "fit_irls", "is_algorithm": True, "reason": "",
             "proposed": {"problem": "p", "algorithm": "IRLS", "details": "d", "complexity": "c",
                          "audit_row": "A", "refs": [WIKI]}}],
            "changed_entries": []})
        applied, held, skipped = research_apply.apply(d, ["inventory"], "2026-11-16", offline=True)
        self.assertEqual((len(applied), held, skipped), (1, [], 1))
        row = [e for e in drift.load_inventory() if e["symbol"] == "brent_root"][0]
        self.assertEqual((row["refs"], row["watch"], row["verdict"]),
                         (WIKI, "A", "Not yet audited (added 2026-11-16)"))

    def test_unverifiable_refs_or_ambiguous_fixes_are_held_and_verdicts_untouched(self):
        self.entries = [entry(), entry(algorithm="L-BFGS", problem="other")]
        self.run_check()
        (self.root / "R/EDI/src/fit.cpp").write_text("double fit_irls() {}\ndouble em() {}\n")
        d = self.write_agent_output({"new_symbols": [
            {"file": "R/EDI/src/fit.cpp", "symbol": "em", "is_algorithm": True, "reason": "",
             "proposed": {"problem": "p", "algorithm": "EM", "details": "d", "complexity": "c",
                          "audit_row": "A", "refs": ["https://doi.org/10.1/unknown"]}}],
            "changed_entries": [
                {"file": "R/EDI/src/fit.cpp", "symbol": "fit_irls", "stale": True,
                 "issue": "changed", "suggested_details": "new text", "may_affect_verdict": True},
                {"file": "R/EDI/src/fit.cpp", "symbol": "fit_irls", "algorithm": "L-BFGS",
                 "stale": True, "issue": "changed", "suggested_details": "lbfgs text"}]})
        applied, held, _ = research_apply.apply(d, ["inventory"], "2026-11-16", offline=True)
        self.assertEqual(len(applied), 1)
        self.assertEqual(len(held), 2)  # unverifiable ref; fix matching two rows
        rows = {e["algorithm"]: e for e in drift.load_inventory()}
        self.assertEqual(rows["L-BFGS"]["details"], "lbfgs text")
        self.assertEqual(rows["IRLS"]["details"], "")
        self.assertEqual({e["verdict"] for e in rows.values()}, {"Keep"})


class PromptSchemaTests(unittest.TestCase):

    def test_schemas_are_json_without_single_quotes(self):
        # the workflow passes them as --json-schema '<schema>' inside claude_args
        prompts = Path(__file__).resolve().parents[1] / "prompts"
        for f in prompts.glob("*.schema.json"):
            text = f.read_text()
            json.loads(text)
            self.assertNotIn("'", text, f"{f.name} contains a single quote")


if __name__ == "__main__":
    unittest.main()
