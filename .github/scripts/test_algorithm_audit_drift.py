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
        "problem_id", "method_id", "verdict", "refs", "watch", "source"]
TERMS = {"synonyms": ["Fisher scoring"], "broader": ["second-order methods"],
         "narrower": ["step-halving IRLS"], "software": ["glm"]}
TAXONOMY = {"problems": {"binary-glm-mle": {"title": "binary GLM MLE", "description": "",
                                            "search_terms": ["logistic regression fitting"]}},
            "methods": {"irls": dict(title="IRLS", **TERMS), "lbfgs": dict(title="L-BFGS", **TERMS)}}
WIKI = "https://en.wikipedia.org/wiki/Iteratively_reweighted_least_squares"


def entry(**kw):
    e = {"file": "R/EDI/src/fit.cpp", "symbol": "fit_irls", "problem": "logistic MLE",
         "algorithm": "IRLS", "details": "", "complexity": "", "audit_row": "A",
         "problem_id": "binary-glm-mle", "method_id": "irls",
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
                      ("ROOT", "ROW_MAP", "INVENTORY", "REFERENCES", "SRC_DIR", "R_DIR",
                       "TAXONOMY", "RESEARCH_LOG", "TRIAGE", "RELEASES")}
        audits = root / "R/package_metadata/audits"
        drift.ROOT = root
        drift.ROW_MAP = audits / "algorithm_audit_row_map.json"
        drift.INVENTORY = audits / "algorithm_inventory.csv"
        drift.REFERENCES = audits / "algorithm_references.csv"
        drift.SRC_DIR = root / "R/EDI/src"
        drift.R_DIR = root / "R/EDI/R"
        drift.TAXONOMY = audits / "algorithm_taxonomy.json"
        drift.RESEARCH_LOG = audits / "research_log.json"
        drift.TRIAGE = audits / "research_triage.csv"          # never the real repo file
        drift.RELEASES = root / "R/package_metadata/future_release_plans"
        self.taxonomy = json.loads(json.dumps(TAXONOMY))
        self.taxonomy["methods"].pop("lbfgs")  # only methods the fixture uses
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
        drift.TAXONOMY.write_text(json.dumps(self.taxonomy))
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
        self.put("A", {"problem_id": "A", "methods_reviewed": [
            {"method_id": "irls", "conclusion": "no_faster_acceptable_found", "note": "ok",
             "vs_previous": "new"}], "not_reviewed": [], "findings": []})
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

    def finding(self, **kw):
        f = {"methods": ["irls"], "entries": [], "current": "", "candidate": "x",
             "claimed_speedup": "", "applies_at_edi_sizes": "unknown", "keeps_estimator": "yes",
             "tradeoffs": "", "sources": ["https://x"], "confidence": "low", "suggested_action": ""}
        f.update(kw)
        return f

    def problem(self, **kw):
        d = {"problem_id": "binary-glm-mle", "not_reviewed": [], "findings": [], "searches": [],
             "proposed_terms": [], "methods_reviewed": [
                 {"method_id": "irls", "conclusion": "no_faster_acceptable_found", "note": "",
                  "vs_previous": "new"}]}
        d.update(kw)
        return d

    def test_method_in_neither_list_is_a_silent_skip(self):
        self.put("binary-glm-mle", self.problem())
        flagged, text = report.render(self.dir, ["binary-glm-mle"],
                                      {"binary-glm-mle": ["irls", "lbfgs"]})
        self.assertTrue(flagged)
        self.assertIn("binary-glm-mle: `lbfgs` (**silently skipped**", text)

    def test_finding_and_conclusion_must_agree(self):
        self.put("binary-glm-mle", self.problem(
            findings=[self.finding(methods=["irls"]), self.finding(methods=["orphan"])],
            methods_reviewed=[
                {"method_id": "irls", "conclusion": "no_faster_acceptable_found", "note": "", "vs_previous": "new"},
                {"method_id": "lbfgs", "conclusion": "faster_option_found", "note": "", "vs_previous": "new"}]))
        flagged, text = report.render(self.dir, ["binary-glm-mle"])
        self.assertTrue(flagged)
        self.assertIn("## 4. Inconsistent agent output", text)
        self.assertIn("binary-glm-mle: `irls`: has a finding but is marked `no_faster_acceptable_found`", text)
        self.assertIn("binary-glm-mle: `lbfgs`: marked `faster_option_found` but has no finding", text)
        self.assertIn("binary-glm-mle: `orphan`: has a finding but is not in methods_reviewed", text)

    def test_one_finding_can_name_several_methods(self):
        self.put("binary-glm-mle", self.problem(
            findings=[self.finding(methods=["irls", "lbfgs"], candidate="coordinate descent")],
            methods_reviewed=[
                {"method_id": "irls", "conclusion": "faster_option_found", "note": "", "vs_previous": "new"},
                {"method_id": "lbfgs", "conclusion": "faster_option_found", "note": "", "vs_previous": "new"}]))
        _, text = report.render(self.dir, ["binary-glm-mle"])
        self.assertIn("### binary-glm-mle: irls, lbfgs → coordinate descent", text)
        self.assertNotIn("Inconsistent agent output", text)

    def test_search_plan_coverage_gaps_are_flagged(self):
        searches = [
            {"query": "logistic regression fitting fast", "where": "web", "term_classes": ["problem"],
             "method_ids": [], "result": ""},
            {"query": "Fisher scoring OR IRLS logistic", "where": "arxiv",
             "term_classes": ["synonym", "broader"], "method_ids": ["irls"], "result": ""},
            {"query": "https://cran.r-project.org/web/views/", "where": "cran-task-views",
             "term_classes": ["software"], "method_ids": ["irls"], "result": ""}]
        self.put("binary-glm-mle", self.problem(searches=searches))
        flagged, text = report.render(self.dir, ["binary-glm-mle"], {"binary-glm-mle": ["irls"]}, TAXONOMY)
        self.assertTrue(flagged)
        self.assertIn("## 5. Search-plan gaps", text)
        self.assertIn("`irls`: no narrower search", text)
        self.assertIn("venue not checked: jss", text)
        self.assertIn("venue not checked: r-journal", text)
        self.assertNotIn("no problem-level search", text)
        self.assertNotIn("`irls`: no synonym search", text)

    def test_trivial_methods_need_no_per_term_searches(self):
        tax = json.loads(json.dumps(TAXONOMY))
        tax["methods"]["lbfgs"]["trivial"] = True
        searches = [{"query": q, "where": w, "term_classes": c, "method_ids": m, "result": ""}
                    for q, w, c, m in [
                        ("logistic fitting", "web", ["problem"], []),
                        ("IRLS variants", "arxiv", ["synonym", "broader", "narrower", "software"], ["irls"]),
                        ("views", "cran-task-views", ["other"], []), ("jss", "jss", ["other"], []),
                        ("rj", "r-journal", ["other"], [])]]
        self.put("binary-glm-mle", self.problem(searches=searches))
        flagged, text = report.render(self.dir, ["binary-glm-mle"], {"binary-glm-mle": ["irls", "lbfgs"]}, tax)
        self.assertIn("`lbfgs` (**silently skipped**", text)  # still must be accounted for
        self.assertNotIn("`lbfgs`: no", text)                 # but no term searches required
        tax["methods"]["lbfgs"]["trivial"] = False
        _, text = report.render(self.dir, ["binary-glm-mle"], {"binary-glm-mle": ["irls", "lbfgs"]}, tax)
        self.assertIn("`lbfgs`: no synonym search", text)

    def test_complete_search_plan_has_no_gaps(self):
        searches = [{"query": q, "where": w, "term_classes": c, "method_ids": m, "result": ""}
                    for q, w, c, m in [
                        ("logistic fitting", "web", ["problem"], []),
                        ("IRLS variants", "arxiv", ["synonym", "broader", "narrower", "software"], ["irls"]),
                        ("views", "cran-task-views", ["other"], []), ("jss", "jss", ["other"], []),
                        ("rj", "r-journal", ["other"], [])]]
        self.put("binary-glm-mle", self.problem(searches=searches))
        flagged, text = report.render(self.dir, ["binary-glm-mle"], {"binary-glm-mle": ["irls"]}, TAXONOMY)
        self.assertFalse(flagged, text)

    def test_reported_searches_must_be_backed_by_the_transcript(self):
        self.put("binary-glm-mle", self.problem(searches=[
            {"query": f"q{i}", "where": "web", "term_classes": ["other"], "method_ids": [], "result": ""}
            for i in range(5)]))
        (self.dir / "binary-glm-mle.searches.json").write_text(json.dumps(
            {"searches": [{"tool": "WebSearch", "query": "q0"}, {"tool": "WebFetch", "url": "u"}]}))
        flagged, text = report.render(self.dir, ["binary-glm-mle"])
        self.assertTrue(flagged)
        self.assertIn("reports 5 searches but its transcript shows 2", text)

    def test_open_source_implementations_listed_compatible_first(self):
        impl = lambda n, c: {"name": n, "url": f"https://x/{n}", "license": "L", "license_source":
                             f"https://x/{n}/LICENSE", "gpl3_compatible": c, "language": "C++",
                             "methods": ["irls"], "relevance": "port | test"}
        self.put("binary-glm-mle", self.problem(implementations=[
            impl("zeta", "no"), impl("alpha", "yes"), impl("beta", "conditional")]))
        _, text = report.render(self.dir, ["binary-glm-mle"])
        self.assertLess(text.index("## 6."), text.index("## 7.")) if "## 6." in text else None
        sec = text.split("## 7. Open-source implementations found", 1)[1]
        self.assertLess(sec.index("alpha"), sec.index("beta"))
        self.assertLess(sec.index("beta"), sec.index("zeta"))
        self.put("binary-glm-mle", self.problem(implementations=[dict(impl("alpha", "yes"), license="GPL-2 | GPL-3")]))
        _, text2 = report.render(self.dir, ["binary-glm-mle"])
        self.assertIn("[GPL-2 \\| GPL-3](https://x/alpha/LICENSE)", text2)  # pipe escaped
        self.assertIn("| yes | [alpha](https://x/alpha) | [L](https://x/alpha/LICENSE) | "
                      "binary-glm-mle: irls | C++ | port \\| test |", sec)

    def test_denied_tool_use_in_the_transcript_is_flagged(self):
        self.put("binary-glm-mle", self.problem())
        (self.dir / "binary-glm-mle.searches.json").write_text(json.dumps(
            {"searches": [], "tool_counts": {"Read": 4, "Bash": 9, "WebFetch": 2}}))
        flagged, text = report.render(self.dir, ["binary-glm-mle"])
        self.assertTrue(flagged)
        self.assertIn("called denied tools: Bash x9", text)

    def test_inventory_items_missing_from_a_shard_are_flagged(self):
        self.put("inventory.12", {"new_symbols": [], "changed_entries": [
            {"file": "a.R", "symbol": "f", "stale": True, "issue": "x"}]})
        ctx = {"inventory.12": {"new_symbols": [{"file": "a.R", "symbol": "g"}],
                                "changed_entries": [{"file": "a.R", "symbol": "f"}, {"file": "b.R", "symbol": "h"}]}}
        flagged, text = report.render(self.dir, ["inventory.12"], inventory_ctx=ctx)
        self.assertTrue(flagged)
        self.assertIn("inventory.12: new function `a.R` `g` (**silently skipped**", text)
        self.assertIn("inventory.12: changed entry `b.R` `h` (**silently skipped**", text)
        self.assertNotIn("`a.R` `f` (**silently", text)
        # a whole file reported as plumbing covers its new functions (not its changed entries)
        self.put("inventory.12", {"new_symbols": [{"file": "a.R", "symbol": "*", "is_algorithm": False, "reason": "R6 plumbing"}],
                                  "changed_entries": [{"file": "a.R", "symbol": "f", "stale": False},
                                                      {"file": "b.R", "symbol": "h", "stale": False}]})
        flagged, text = report.render(self.dir, ["inventory.12"], inventory_ctx=ctx)
        self.assertNotIn("silently skipped", text)

    def test_findings_stale_rows_new_algorithms_and_skips_flag(self):
        self.put("binary-glm-mle", self.problem(
            findings=[self.finding(candidate="one-step bootstrap", keeps_estimator="no")],
            methods_reviewed=[{"method_id": "irls", "conclusion": "faster_option_found", "note": "",
                               "vs_previous": "new"}],
            not_reviewed=[{"method_id": "lbfgs", "reason": "turn budget"}],
            proposed_terms=[{"target": "method", "id": "irls", "term_class": "synonyms",
                             "term": "Newton-Raphson for GLMs", "why": "used by paper"}]))
        self.put("inventory", {"new_symbols": [{"file": "f.R", "symbol": "em", "is_algorithm": True,
                                                "reason": "EM", "proposed": {
                                                    "problem": "p", "algorithm": "EM",
                                                    "details": "d", "complexity": "O(n)",
                                                    "audit_row": "B", "problem_id": "mixture-mle",
                                                    "method_id": "em", "refs": ["https://y"]}}],
                               "changed_entries": [{"file": "g.cpp", "symbol": "fit", "stale": True,
                                                    "issue": "now L-BFGS",
                                                    "may_affect_verdict": True}]})
        flagged, text = report.render(self.dir, ["binary-glm-mle", "inventory"])
        self.assertTrue(flagged)
        for s in ("irls → one-step bootstrap", "keeps the estimator: no",
                  "`f.R` `em`: EM (problem `mixture-mle`, method `em`, row B",
                  "(may affect the verdict)", "binary-glm-mle: `lbfgs` (turn budget)",
                  "## 6. Taxonomy terms proposed by agents",
                  'method `irls` synonyms: "Newton-Raphson for GLMs"'):
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
                          "complexity": "O(log)", "audit_row": "A", "problem_id": "binary-glm-mle",
                          "method_id": "irls", "refs": [WIKI, "https://x.org/y"]}},
            {"file": "R/EDI/src/fit.cpp", "symbol": "fit_irls", "is_algorithm": True, "reason": "",
             "proposed": {"problem": "p", "algorithm": "IRLS", "details": "d", "complexity": "c",
                          "audit_row": "A", "problem_id": "binary-glm-mle", "method_id": "irls",
                          "refs": [WIKI]}}],
            "changed_entries": []})
        applied, held, skipped = research_apply.apply(d, ["inventory"], "2026-11-16", offline=True)
        self.assertEqual((len(applied), held, skipped), (1, [], 1))
        row = [e for e in drift.load_inventory() if e["symbol"] == "brent_root"][0]
        self.assertEqual((row["refs"], row["watch"], row["verdict"], row["problem_id"], row["method_id"]),
                         (WIKI, "A", "Not yet audited (added 2026-11-16)", "binary-glm-mle", "irls"))

    def test_inventory_shards_are_merged(self):
        (self.root / "R/EDI/src/fit.cpp").write_text("double fit_irls() {}\ndouble em() {}\ndouble mm() {}\n")
        self.run_check()
        out = Path(self.tmp.name) / "research"
        out.mkdir()
        mk = lambda sym: {"new_symbols": [{"file": "R/EDI/src/fit.cpp", "symbol": sym, "is_algorithm": True,
            "reason": "", "proposed": {"problem": "p", "algorithm": sym, "details": "d", "complexity": "c",
            "audit_row": "A", "problem_id": "binary-glm-mle", "method_id": "irls", "refs": [WIKI]}}],
            "changed_entries": []}
        (out / "inventory.1.json").write_text(json.dumps(mk("em")))
        (out / "inventory.2.json").write_text(json.dumps(mk("mm")))
        applied, held, _ = research_apply.apply(out, ["inventory.1", "inventory.2"], "2026-11-16", offline=True)
        self.assertEqual((len(applied), held), (2, []))

    def test_problem_level_synonyms_go_to_search_terms(self):
        self.run_check()
        out = Path(self.tmp.name) / "research"
        out.mkdir()
        (out / "binary-glm-mle.json").write_text(json.dumps({"proposed_terms": [
            {"target": "problem", "id": "binary-glm-mle", "term_class": "broader", "term": "cheap bootstrap", "why": ""}]}))
        added, held = research_apply.add_proposed_terms(out, ["binary-glm-mle"])
        self.assertEqual((len(added), held), (1, []))
        self.assertIn("cheap bootstrap", drift.load_taxonomy()["problems"]["binary-glm-mle"]["search_terms"])

    def test_new_row_with_unknown_taxonomy_ids_is_held(self):
        (self.root / "R/EDI/src/fit.cpp").write_text("double fit_irls() {}\ndouble em() {}\n")
        self.run_check()
        d = self.write_agent_output({"new_symbols": [
            {"file": "R/EDI/src/fit.cpp", "symbol": "em", "is_algorithm": True, "reason": "",
             "proposed": {"problem": "p", "algorithm": "EM", "details": "d", "complexity": "c",
                          "audit_row": "A", "problem_id": "no-such-problem", "method_id": "irls",
                          "refs": [WIKI]}}], "changed_entries": []})
        applied, held, _ = research_apply.apply(d, ["inventory"], "2026-11-16", offline=True)
        self.assertEqual(applied, [])
        self.assertIn("not in the taxonomy", held[0])

    def test_proposed_terms_extend_the_taxonomy(self):
        self.run_check()
        out = Path(self.tmp.name) / "research"
        out.mkdir()
        (out / "binary-glm-mle.json").write_text(json.dumps({"proposed_terms": [
            {"target": "method", "id": "irls", "term_class": "synonyms", "term": "Newton-Raphson for GLMs", "why": ""},
            {"target": "method", "id": "irls", "term_class": "synonyms", "term": "fisher SCORING", "why": "dup"},
            {"target": "method", "id": "nope", "term_class": "synonyms", "term": "x", "why": ""},
            {"target": "problem", "id": "binary-glm-mle", "term_class": "software", "term": "fracreg", "why": ""}]}))
        added, held = research_apply.add_proposed_terms(out, ["binary-glm-mle"])
        self.assertEqual(len(added), 2)  # the case-insensitive duplicate is skipped
        self.assertEqual(drift.load_taxonomy()["problems"]["binary-glm-mle"]["software"], ["fracreg"])
        self.assertEqual(len(held), 1)   # unknown method id
        self.assertIn("Newton-Raphson for GLMs", drift.load_taxonomy()["methods"]["irls"]["synonyms"])

    def test_unverifiable_refs_or_ambiguous_fixes_are_held_and_verdicts_untouched(self):
        self.entries = [entry(), entry(algorithm="L-BFGS", problem="other")]
        self.run_check()
        (self.root / "R/EDI/src/fit.cpp").write_text("double fit_irls() {}\ndouble em() {}\n")
        d = self.write_agent_output({"new_symbols": [
            {"file": "R/EDI/src/fit.cpp", "symbol": "em", "is_algorithm": True, "reason": "",
             "proposed": {"problem": "p", "algorithm": "EM", "details": "d", "complexity": "c",
                          "audit_row": "A", "problem_id": "binary-glm-mle", "method_id": "irls",
                          "refs": ["https://doi.org/10.1/unknown"]}}],
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


class CanonicalCranUrlTests(unittest.TestCase):

    def test_mirrors_move_to_cran_r_project_org(self):
        c = drift.canonical_cran_url
        cases = {
            "https://mirror.linux.duke.edu/pub/cran/web/packages/ordinal/vignettes/clm_article.pdf":
                "https://cran.r-project.org/web/packages/ordinal/vignettes/clm_article.pdf",
            "https://cloud.r-project.org/web/packages/lme4/news.html":
                "https://cran.r-project.org/web/packages/lme4/news.html",
            "https://cran.rstudio.com/src/contrib/Archive/lme4/":
                "https://cran.r-project.org/src/contrib/Archive/lme4/",
            "https://rdrr.io/cran/fastglm/man/fastglm_nb.html": "https://cran.r-project.org/package=fastglm",
            "https://github.com/cran/survival/blob/master/R/coxph.R":
                "https://cran.r-project.org/package=survival",
            "http://CRAN.R-project.org/package=coin": "https://cran.r-project.org/package=coin",
        }
        for src, want in cases.items():
            self.assertEqual(c(src), want, src)
        for keep in ("https://en.wikipedia.org/wiki/Bisection_method", "https://doi.org/10.2307/2531595",
                     "https://github.com/lme4/lme4/pull/961"):
            self.assertEqual(c(keep), keep)

    def test_report_sources_are_canonicalized(self):
        with tempfile.TemporaryDirectory(dir=os.environ.get("TMPDIR")) as tmp:
            Path(tmp, "A.1.json").write_text(json.dumps({"row": "A", "algorithms_reviewed": [],
                "not_reviewed": [], "findings": [{"algorithm": "a", "entries": [], "current": "",
                "candidate": "b", "claimed_speedup": "", "applies_at_edi_sizes": "unknown",
                "keeps_estimator": "yes", "tradeoffs": "", "confidence": "low", "suggested_action": "",
                "sources": ["https://mirror.dogado.de/cran/web/packages/fastglm/vignettes/x.html"]}]}))
            _, text = report.render(Path(tmp), ["A.1"])
        self.assertIn("https://cran.r-project.org/web/packages/fastglm/vignettes/x.html", text)
        self.assertNotIn("dogado", text)


class InventoryShardTests(unittest.TestCase):

    def test_shards_keep_a_files_items_together_and_cover_everything(self):
        ctx = {"window_days": 40, "today": "x",
               "new_symbols": [{"file": f"f{i % 7}.R", "symbol": f"n{i}"} for i in range(50)],
               "changed_entries": [{"file": f"f{i % 7}.R", "symbol": f"c{i}"} for i in range(30)]}
        saved = drift.currency_context
        drift.currency_context = lambda days: ctx
        try:
            shards = drift.inventory_shards(size=25)
        finally:
            drift.currency_context = saved
        self.assertEqual(list(shards), [f"inventory.{i + 1}" for i in range(len(shards))])
        files = [{x["file"] for k in ("new_symbols", "changed_entries") for x in sh[k]}
                 for sh in shards.values()]
        for i, a in enumerate(files):  # each file in exactly one shard
            for b in files[i + 1:]:
                self.assertFalse(a & b)
        self.assertEqual(sum(len(sh["new_symbols"]) for sh in shards.values()), 50)
        self.assertEqual(sum(len(sh["changed_entries"]) for sh in shards.values()), 30)
        self.assertTrue(all(sh["window_days"] == 40 for sh in shards.values()))
        self.assertTrue(drift.is_inventory_task("inventory.3") and drift.is_inventory_task("inventory"))
        self.assertFalse(drift.is_inventory_task("inventory-like-problem"))


class AddOpenCopiesTests(unittest.TestCase):

    def run_add(self, sources, access):
        with tempfile.TemporaryDirectory(dir=os.environ.get("TMPDIR")) as tmp:
            Path(tmp, "p.json").write_text(json.dumps({"findings": [{"methods": ["m"], "sources": sources}]}))
            saved = drift.doi_access
            research_apply.drift.doi_access = lambda doi: access[doi]
            try:
                research_apply.add_open_copies(Path(tmp), ["p"], offline=False)
            finally:
                research_apply.drift.doi_access = saved
            return json.loads(Path(tmp, "p.json").read_text())["findings"][0]

    def test_already_cited_open_copy_counts_as_found(self):
        f = self.run_add(["https://arxiv.org/abs/2408.06213", "https://doi.org/10.1002/spe.3369"],
                         {"10.1002/spe.3369": ("blocked", ["https://arxiv.org/abs/2408.06213"])})
        self.assertNotIn("source_access", f)   # not reported as "no open copy"
        self.assertNotIn("open_copies", f)     # and not repeated

    def test_uncited_copy_is_added_and_none_found_is_reported(self):
        f = self.run_add(["https://doi.org/10.1000/a", "https://doi.org/10.1000/b"],
                         {"10.1000/a": ("blocked", ["https://arxiv.org/abs/1"]), "10.1000/b": ("closed", [])})
        self.assertEqual(f["open_copies"], ["https://arxiv.org/abs/1"])
        self.assertEqual(f["source_access"], {"10.1000/b": "closed"})


class OpenCopyTests(unittest.TestCase):

    def test_doi_of_finds_dois_in_publisher_urls(self):
        self.assertEqual(drift.doi_of("https://doi.org/10.1093/bioinformatics/btaa1009"),
                         "10.1093/bioinformatics/btaa1009")
        self.assertEqual(drift.doi_of("https://onlinelibrary.wiley.com/doi/10.1111/biom.12345?x=1"),
                         "10.1111/biom.12345")
        self.assertIsNone(drift.doi_of("https://academic.oup.com/bioinformatics/article/36/24/5701/6029133"))
        self.assertEqual(drift.doi_of("https://projecteuclid.org/journals/annals-of-statistics/volume-27/"
                                      "issue-5/x/10.1214/aos/1021379865.full"), "10.1214/aos/1021379865")
        self.assertEqual(drift.doi_of("https://onlinelibrary.wiley.com/doi/abs/10.1002/sim.3095/abstract"),
                         "10.1002/sim.3095")

    def test_open_copies_prefer_preprints_then_pmc_never_publisher(self):
        # shape of OpenAlex's record for glmGamPoi (doi:10.1093/bioinformatics/btaa1009), 2026-11-16
        work = {"locations": [
            {"is_oa": True, "landing_page_url": "https://doi.org/10.1093/bioinformatics/btaa1009"},
            {"is_oa": True, "landing_page_url": "https://pmc.ncbi.nlm.nih.gov/articles/PMC8023675/"},
            {"is_oa": True, "landing_page_url": "https://doi.org/10.1101/2020.08.13.249623"},
            {"is_oa": False, "landing_page_url": "https://pubmed.ncbi.nlm.nih.gov/33295604"},
            {"is_oa": True, "landing_page_url": "https://doi.org/10.48550/arxiv.2101.00001"}]}
        self.assertEqual(drift.pick_open_copies(work), [
            "https://arxiv.org/abs/2101.00001", "https://doi.org/10.1101/2020.08.13.249623",
            "https://pmc.ncbi.nlm.nih.gov/articles/PMC8023675/"])
        self.assertEqual(drift.pick_open_copies({"locations": [
            {"is_oa": True, "landing_page_url": "https://academic.oup.com/x"}]}), [])
        # arXiv PDF and versioned URLs (seen in run 43922480182) give one clean abs link each
        self.assertEqual(drift.pick_open_copies({"locations": [
            {"is_oa": True, "landing_page_url": "https://arxiv.org/pdf/1312.0531.pdf"},
            {"is_oa": True, "landing_page_url": "http://arxiv.org/abs/1312.0531"},
            {"is_oa": True, "landing_page_url": "https://arxiv.org/abs/2310.01589v2"}]}),
            ["https://arxiv.org/abs/1312.0531", "https://arxiv.org/abs/2310.01589v2"])

    def test_report_shows_open_copies(self):
        with tempfile.TemporaryDirectory(dir=os.environ.get("TMPDIR")) as tmp:
            Path(tmp, "A.1.json").write_text(json.dumps({"row": "A", "not_reviewed": [],
                "algorithms_reviewed": [{"algorithm": "a", "conclusion": "faster_option_found", "note": ""}],
                "findings": [{"algorithm": "a", "entries": [], "current": "", "candidate": "b",
                "claimed_speedup": "", "applies_at_edi_sizes": "unknown", "keeps_estimator": "yes",
                "tradeoffs": "", "confidence": "low", "suggested_action": "",
                "sources": ["https://doi.org/10.1093/bioinformatics/btaa1009", "https://doi.org/10.2307/1"],
                "source_access": {"10.1093/bioinformatics/btaa1009": "blocked"},
                "open_copies": ["https://doi.org/10.1101/2020.08.13.249623"]}]}))
            _, text = report.render(Path(tmp), ["A.1"])
        self.assertIn("- **Open copies** (publisher page blocks automated access): "
                      "https://doi.org/10.1101/2020.08.13.249623", text)

    def test_publisher_first_then_openalex(self):
        oa_work = {"primary_location": {"is_oa": True}, "locations": [
            {"is_oa": True, "landing_page_url": "https://doi.org/10.1101/2020.08.13.249623"}]}
        closed_work = dict(oa_work, primary_location={"is_oa": False})
        access = drift.doi_access
        # publisher loads and is open: use it, no fallback copies
        self.assertEqual(access("10.1/a", reachable=lambda d: True, work_of=lambda d: oa_work),
                         ("publisher", []))
        self.assertEqual(access("10.1/a", reachable=lambda d: True, work_of=lambda d: None),
                         ("publisher", []))
        # publisher blocks us (403): fall back to OpenAlex's open copies
        self.assertEqual(access("10.1/a", reachable=lambda d: False, work_of=lambda d: oa_work),
                         ("blocked", ["https://doi.org/10.1101/2020.08.13.249623"]))
        # publisher page loads but is paywalled: fall back too
        self.assertEqual(access("10.1/a", reachable=lambda d: True, work_of=lambda d: closed_work),
                         ("closed", ["https://doi.org/10.1101/2020.08.13.249623"]))
        # blocked and no OpenAlex record: say so, no copies
        self.assertEqual(access("10.1/a", reachable=lambda d: False, work_of=lambda d: None),
                         ("blocked", []))
        # an arXiv DOI is the open copy itself: no lookup at all
        boom = lambda d: (_ for _ in ()).throw(AssertionError("must not be called"))
        self.assertEqual(access("10.48550/arXiv.2310.01589", reachable=boom, work_of=boom),
                         ("publisher", []))

        # OpenAlex unreachable: never reported as "no open copy"
        def fail(d):
            raise drift.LookupFailed("429")
        self.assertEqual(access("10.1/a", reachable=lambda d: False, work_of=fail), ("lookup_failed", []))
        self.assertEqual(access("10.1/a", reachable=lambda d: True, work_of=fail), ("publisher", []))

    def test_report_says_when_no_open_copy_exists(self):
        with tempfile.TemporaryDirectory(dir=os.environ.get("TMPDIR")) as tmp:
            Path(tmp, "A.1.json").write_text(json.dumps({"row": "A", "not_reviewed": [],
                "algorithms_reviewed": [{"algorithm": "a", "conclusion": "faster_option_found", "note": ""}],
                "findings": [{"algorithm": "a", "entries": [], "current": "", "candidate": "b",
                "claimed_speedup": "", "applies_at_edi_sizes": "unknown", "keeps_estimator": "yes",
                "tradeoffs": "", "confidence": "low", "suggested_action": "",
                "sources": ["https://doi.org/10.2307/2531595"],
                "source_access": {"10.2307/2531595": "closed"}}]}))
            _, text = report.render(Path(tmp), ["A.1"])
        self.assertIn("- **No open copy found** for doi:10.2307/2531595 (publisher version is paywalled)", text)

    def test_failed_lookup_is_not_reported_as_no_open_copy(self):
        with tempfile.TemporaryDirectory(dir=os.environ.get("TMPDIR")) as tmp:
            Path(tmp, "p.json").write_text(json.dumps({"problem_id": "p", "not_reviewed": [],
                "methods_reviewed": [{"method_id": "m", "conclusion": "faster_option_found", "note": "", "vs_previous": "new"}],
                "findings": [{"methods": ["m"], "entries": [], "current": "", "candidate": "b",
                "claimed_speedup": "", "applies_at_edi_sizes": "unknown", "keeps_estimator": "yes",
                "tradeoffs": "", "confidence": "low", "suggested_action": "",
                "sources": ["https://doi.org/10.1/x"], "source_access": {"10.1/x": "lookup_failed"}}]}))
            _, text = report.render(Path(tmp), ["p"])
        self.assertIn("- **Open-copy lookup failed** for doi:10.1/x", text)
        self.assertNotIn("No open copy found", text)


class ResearchLogTests(InventoryCheckTests):
    """Reuses the planted repo (not a git checkout, so no code commits are found)."""

    def test_log_round_trip_keeps_unreviewed_methods_and_unrun_problems(self):
        old_m = {"conclusion": "no_faster_acceptable_found", "note": "old", "last_researched": "2026-10-01"}
        old = {"last_researched": "2026-10-01", "run": "1", "methods": {"irls": old_m, "lbfgs": old_m},
               "findings": [], "sources": []}
        drift.RESEARCH_LOG.write_text(json.dumps({"problems": {"binary-glm-mle": old, "other": old}}))
        out = Path(self.tmp.name) / "research"
        out.mkdir()
        (out / "binary-glm-mle.json").write_text(json.dumps({"problem_id": "binary-glm-mle",
            "methods_reviewed": [{"method_id": "irls", "conclusion": "faster_option_found",
                                  "note": "new", "vs_previous": "updated"}],
            "not_reviewed": [{"method_id": "lbfgs", "reason": "turn budget"}],
            "findings": [{"methods": ["irls"], "candidate": "x", "confidence": "low",
                          "sources": ["https://mirror.dogado.de/cran/web/packages/a/b.html"],
                          "open_copies": ["https://doi.org/10.1101/1"]}]}))
        n = research_apply.update_research_log(out, ["binary-glm-mle", "other", "inventory"],
                                               "2026-11-16", "42")
        log = drift.load_research_log()
        self.assertEqual(n, 1)
        self.assertEqual(log["other"], old)  # task did not run: kept whole
        p = log["binary-glm-mle"]
        self.assertEqual((p["last_researched"], p["run"]), ("2026-11-16", "42"))
        self.assertEqual(p["methods"]["lbfgs"], old_m)  # not reviewed: kept
        self.assertEqual(p["methods"]["irls"]["conclusion"], "faster_option_found")
        self.assertEqual(p["findings"][0]["methods"], ["irls"])
        self.assertEqual(p["sources"], ["https://cran.r-project.org/web/packages/a/b.html",
                                        "https://doi.org/10.1101/1"])

    def test_log_keeps_implementations_across_runs(self):
        drift.RESEARCH_LOG.write_text(json.dumps({"problems": {"p": {"last_researched": "2026-10-01",
            "methods": {}, "findings": [], "sources": [],
            "implementations": [{"name": "fastglm", "license": "GPL-2.0-or-later", "last_seen": "2026-10-01"}]}}}))
        out = Path(self.tmp.name) / "research"
        out.mkdir()
        (out / "p.json").write_text(json.dumps({"methods_reviewed": [
            {"method_id": "irls", "conclusion": "no_faster_acceptable_found", "note": "", "vs_previous": "unchanged"}],
            "implementations": [{"name": "glm2", "url": "https://mirror.dogado.de/cran/web/packages/glm2/index.html",
                                 "license": "GPL-2.0-or-later", "gpl3_compatible": "yes"}]}))
        research_apply.update_research_log(out, ["p"], "2026-11-16", "1")
        impls = {i["name"]: i for i in drift.load_research_log()["p"]["implementations"]}
        self.assertEqual(set(impls), {"fastglm", "glm2"})  # earlier finds are kept
        self.assertEqual(impls["glm2"]["url"], "https://cran.r-project.org/web/packages/glm2/index.html")

    def test_previous_results_for_a_problem(self):
        drift.RESEARCH_LOG.write_text(json.dumps({"problems": {"binary-glm-mle": {
            "last_researched": "2026-11-16", "methods": {}, "findings": [], "sources": []}}}))
        inv = [entry()]
        self.assertEqual(drift.previous_results("never-seen", inv), {"no_previous": True})
        prev = drift.previous_results("binary-glm-mle", inv)
        self.assertEqual((prev["last_researched"], prev["code_changed_since"],
                          prev["code_commits_since"]), ("2026-11-16", False, []))

    def test_tasks_are_problems_with_their_methods(self):
        inv = [entry(), entry(symbol="", method_id="lbfgs"), entry(problem_id="other", method_id="irls")]
        self.assertEqual(drift.research_batches(inv),
                         {"binary-glm-mle": ["irls", "lbfgs"], "other": ["irls"]})

    def test_inventory_check_validates_taxonomy(self):
        self.entries = [entry(), entry(symbol="", problem_id="nope")]
        self.taxonomy["methods"]["unused"] = dict(title="u", **TERMS)
        self.taxonomy["methods"]["irls"].pop("narrower")
        out = self.run_check()
        self.assertEqual(len(out["bad_taxonomy_id"]), 1)
        self.assertEqual(out["unused_taxonomy"], ["method `unused`"])
        self.assertEqual(out["taxonomy_terms"], ["method `irls` lacks narrower"])

    def collecting_taxonomy(self):
        self.taxonomy["methods"]["chol"] = dict(title="Cholesky", researched_in="dense-la", **TERMS)
        self.taxonomy["problems"]["dense-la"] = {"title": "LA", "description": "",
                                                 "search_terms": ["small matrix"], "collects_methods": ["chol"]}
        self.entries = [entry(), entry(symbol="", method_id="chol"),
                        entry(symbol="", problem_id="binary-glm-mle", method_id="chol", file="R/EDI/src/fit.cpp")]

    def test_collecting_problem_gets_shared_methods_and_their_rows(self):
        self.collecting_taxonomy()
        out = self.run_check()
        self.assertEqual(out["unused_taxonomy"], [])  # a collecting problem needs no rows of its own
        self.assertEqual(out["taxonomy_terms"], [])
        inv = drift.load_inventory()
        self.assertEqual(drift.research_batches(inv),
                         {"binary-glm-mle": ["chol", "irls"], "dense-la": ["chol"]})
        self.assertEqual(len(drift.task_rows("dense-la", inv)), 2)
        self.assertEqual(len(drift.task_rows("binary-glm-mle", inv)), 3)

    def test_skip_research_problem_gets_no_task_but_stays_inventoried(self):
        self.taxonomy["problems"]["own-design"] = {"title": "t", "description": "", "search_terms": [],
                                                   "edi_original": "KK 2014", "skip_research": "own"}
        self.entries = [entry(), entry(symbol="", problem_id="own-design")]
        out = self.run_check()
        self.assertEqual((out["bad_taxonomy_id"], out["unused_taxonomy"], out["taxonomy_terms"]), ([], [], []))
        self.assertEqual(list(drift.research_batches(drift.load_inventory())), ["binary-glm-mle"])

    def test_researched_in_must_point_at_a_collecting_problem(self):
        self.collecting_taxonomy()
        self.taxonomy["problems"]["dense-la"]["collects_methods"] = []
        self.assertIn("method `chol` is researched_in `dense-la`, which does not collect it",
                      self.run_check()["taxonomy_terms"])

    def test_report_skips_methods_researched_elsewhere(self):
        self.collecting_taxonomy()
        self.run_check()
        tax = drift.load_taxonomy()
        out = Path(self.tmp.name) / "research"
        out.mkdir()
        base = [{"query": q, "where": w, "term_classes": c, "method_ids": m, "result": ""}
                for q, w, c, m in [("p", "web", ["problem"], []), ("v1", "arxiv", ["other"], []),
                                   ("v2", "cran-task-views", ["other"], []), ("v3", "jss", ["other"], []),
                                   ("v4", "r-journal", ["other"], [])]]
        irls_s = [{"query": "irls", "where": "web", "term_classes": ["synonym", "broader", "narrower", "software"],
                   "method_ids": ["irls"], "result": ""}]
        rev = lambda ms: [{"method_id": m, "conclusion": "no_faster_acceptable_found", "note": "",
                           "vs_previous": "new"} for m in ms]
        (out / "binary-glm-mle.json").write_text(json.dumps({"methods_reviewed": rev(["irls", "chol"]),
            "not_reviewed": [], "findings": [], "searches": base + irls_s}))
        (out / "dense-la.json").write_text(json.dumps({"methods_reviewed": rev(["chol"]),
            "not_reviewed": [], "findings": [], "searches": base}))
        _, text = report.render(out, ["binary-glm-mle", "dense-la"],
                                {"binary-glm-mle": ["chol", "irls"], "dense-la": ["chol"]}, tax)
        gaps = text.split("## 5. Search-plan gaps", 1)[1].split("\n\n", 1)[0]
        self.assertNotIn("binary-glm-mle", gaps)                    # skipped outside its home
        self.assertIn("dense-la: `chol`: no synonym search", gaps)  # strict in its own problem
        self.assertIn("binary-glm-mle: `chol`: no_faster_acceptable_found", text)  # still reviewed

    def test_report_counts_vs_previous(self):
        out = Path(self.tmp.name) / "research"
        out.mkdir()
        (out / "p.json").write_text(json.dumps({"problem_id": "p", "not_reviewed": [], "findings": [],
            "methods_reviewed": [
                {"method_id": "a", "conclusion": "no_faster_acceptable_found", "note": "", "vs_previous": "unchanged"},
                {"method_id": "b", "conclusion": "no_faster_acceptable_found", "note": "", "vs_previous": "unchanged"},
                {"method_id": "c", "conclusion": "no_faster_acceptable_found", "note": "", "vs_previous": "new"}]}))
        _, text = report.render(out, ["p"])
        self.assertIn("Compared with the previous results (`research_log.json`): 1 new, 2 unchanged.", text)


import algorithm_audit_search_log as search_log  # noqa: E402


class SearchLogTests(unittest.TestCase):
    # shape of a real Claude Code stream-json transcript (checked 2026-11-16)
    LINES = [
        {"type": "system", "subtype": "init", "tools": ["WebSearch"]},
        {"type": "assistant", "message": {"content": [
            {"type": "text", "text": "searching"},
            {"type": "tool_use", "id": "t1", "name": "WebSearch",
             "input": {"query": "iteratively reweighted least squares logistic regression"}}]}},
        {"type": "user", "message": {"content": [{"type": "tool_result", "tool_use_id": "t1"}]}},
        {"type": "assistant", "message": {"content": [
            {"type": "tool_use", "id": "t2", "name": "WebFetch",
             "input": {"url": "https://arxiv.org/abs/2310.01589", "prompt": "speed claims?"}},
            {"type": "tool_use", "id": "t3", "name": "Read", "input": {"file_path": "README.md"}}]}},
        {"type": "result", "subtype": "success", "num_turns": 4, "total_cost_usd": 0.02,
         "is_error": False}]

    def test_extract_and_render(self):
        with tempfile.TemporaryDirectory(dir=os.environ.get("TMPDIR")) as tmp:
            t = Path(tmp, "exec.jsonl")
            t.write_text("\n".join(json.dumps(x) for x in self.LINES))
            rec = search_log.extract(search_log._load_transcript(t))
            self.assertEqual(rec["tool_counts"], {"WebSearch": 1, "WebFetch": 1, "Read": 1})
            self.assertEqual(rec["searches"][0], {"tool": "WebSearch", "query":
                             "iteratively reweighted least squares logistic regression"})
            self.assertEqual(rec["searches"][1]["url"], "https://arxiv.org/abs/2310.01589")
            self.assertEqual((rec["num_turns"], rec["is_error"]), (4, False))
            Path(tmp, "p.searches.json").write_text(json.dumps(dict(task="p", **rec)))
            md = search_log.render(tmp, ["p", "missing"])
        self.assertIn("Totals: 1 searches and 1 fetches across 1 agents.", md)
        self.assertIn("- search: `iteratively reweighted least squares logistic regression`", md)
        self.assertIn("- fetch: https://arxiv.org/abs/2310.01589 (speed claims?)", md)
        self.assertIn("## missing\n_No search log", md)

    def test_json_array_transcript_and_duplicate_envelopes(self):
        call = {"type": "tool_use", "id": "x", "name": "WebSearch", "input": {"query": "q"}}
        rec = search_log.extract([{"message": {"content": [call]}}, {"wrapped": call}])
        self.assertEqual(len(rec["searches"]), 1)


import algorithm_audit_triage as triage_mod  # noqa: E402


class TriageTests(InventoryCheckTests):
    """Reuses the planted repo; RELEASES points at a scratch folder with one release file."""

    def setUp(self):
        super().setUp()
        self.saved_rel, self.saved_tri = drift.RELEASES, drift.TRIAGE
        drift.RELEASES = self.root / "R/package_metadata/future_release_plans"
        drift.RELEASES.mkdir(parents=True)
        (drift.RELEASES / "release_v1_1_0.md").write_text("- [ ] TODO-7 (added ...): **x**\n")
        drift.TRIAGE = self.root / "R/package_metadata/audits/research_triage.csv"
        drift.RESEARCH_LOG.write_text(json.dumps({"problems": {"binary-glm-mle": {
            "last_researched": "2026-11-16", "methods": {}, "sources": [],
            "findings": [{"id": "binary-glm-mle#1.1", "candidate": "irls default"},
                         {"id": "binary-glm-mle#1.2", "candidate": "x"}]}}}))

    def tearDown(self):
        drift.RELEASES, drift.TRIAGE = self.saved_rel, self.saved_tri
        super().tearDown()

    def write_triage(self, rows):
        with drift.TRIAGE.open("w", newline="") as fh:
            w = csv.DictWriter(fh, fieldnames=drift.TRIAGE_COLS)
            w.writeheader()
            w.writerows([dict({c: "" for c in drift.TRIAGE_COLS}, **r) for r in rows])

    def test_triage_validation(self):
        self.write_triage([
            {"finding_id": "binary-glm-mle#1.1", "decision": "investigate", "status": "approved", "todo": "v1.1.0-TODO-7"},
            {"finding_id": "binary-glm-mle#1.2", "decision": "investigate", "status": "approved", "todo": "v1.1.0-TODO-99"},
            {"finding_id": "nope#1.1", "decision": "maybe", "status": "draft"},
            {"finding_id": "binary-glm-mle#1.2", "decision": "defer", "status": "proposed", "revisit": "2000-01-01"}])
        out = self.run_check()
        bad = " ".join(out["bad_triage"])
        self.assertIn("v1.1.0-TODO-99` not found in release_v1_1_0.md", bad)
        self.assertIn("decision `maybe`", bad)
        self.assertIn("status `draft`", bad)
        self.assertIn("finding id not in research_log.json", bad)
        self.assertNotIn("TODO-7", bad)
        self.assertEqual(len(out["triage_due"]), 1)

    def test_triage_old_todo_form_rejected(self):
        """CLAUDE.md: release TODOs are cited release-first (v1.1.0-TODO-7), never TODO-7-v1.1.0."""
        self.write_triage([{"finding_id": "binary-glm-mle#1.1", "decision": "investigate",
                            "status": "approved", "todo": "TODO-7-v1.1.0"}])
        bad = " ".join(self.run_check()["bad_triage"])
        self.assertIn("needs a v<version>-TODO-<n>, got `TODO-7-v1.1.0`", bad)

    def test_previous_results_carry_triage(self):
        self.write_triage([{"finding_id": "binary-glm-mle#1.1", "problem_id": "binary-glm-mle",
                            "decision": "reject", "status": "approved", "reason": "changes the estimator"}])
        self.run_check()
        prev = drift.previous_results("binary-glm-mle", [entry()])
        self.assertEqual(prev["triage"][0]["decision"], "reject")

    def test_rereported_finding_keeps_its_id_and_is_labelled(self):
        self.run_check()
        self.write_triage([{"finding_id": "binary-glm-mle#1.1", "problem_id": "binary-glm-mle",
                            "decision": "reject", "status": "approved", "reason": "changes the estimator"}])
        out = Path(self.tmp.name) / "research"
        out.mkdir()
        f = lambda **kw: dict({"methods": ["irls"], "candidate": "c", "sources": ["https://x"]}, **kw)
        (out / "binary-glm-mle.json").write_text(json.dumps({"problem_id": "binary-glm-mle",
            "methods_reviewed": [{"method_id": "irls", "conclusion": "faster_option_found", "note": "", "vs_previous": "updated"}],
            "not_reviewed": [], "searches": [],
            "findings": [f(previous_finding_id="binary-glm-mle#1.1"), f(candidate="brand new")]}))
        flagged, text = report.render(out, ["binary-glm-mle"], run_id="9", log=drift.load_research_log(),
                                      triage=drift.load_triage())
        self.assertIn("## 1b. Previously triaged findings, re-reported", text)
        self.assertIn("- **Previously triaged:** reject (approved). changes the estimator", text)
        self.assertIn("`binary-glm-mle#9.2`", text)  # the new one gets this run's id
        self.assertIn("## 8. Re-reported despite a reject / defer decision", text)  # no new_evidence
        research_apply.update_research_log(out, ["binary-glm-mle"], "2026-12-03", "9")
        ids = [x["id"] for x in drift.load_research_log()["binary-glm-mle"]["findings"]]
        self.assertEqual(ids, ["binary-glm-mle#1.1", "binary-glm-mle#9.2"])  # id kept

    def test_annotate_is_idempotent(self):
        folder = self.root / "findings"
        folder.mkdir()
        md = folder / "2026-11-16-run1.md"
        md.write_text("## 1. F\n### binary-glm-mle: irls → c `binary-glm-mle#1.1`\n- **Current:** x\n")
        rows = [{"finding_id": "binary-glm-mle#1.1", "decision": "investigate", "status": "approved",
                 "todo": "v1.1.0-TODO-7", "reason": "benchmark first", "revisit": "", "decided": "2026-11-17"}]
        for _ in range(2):
            n, missing = triage_mod.annotate(rows, folder)
        text = md.read_text()
        self.assertEqual((n, missing), (1, []))
        self.assertEqual(text.count("- **Triage:**"), 1)
        self.assertIn("- **Triage:** investigate (approved), v1.1.0-TODO-7, 2026-11-17. benchmark first", text)


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
