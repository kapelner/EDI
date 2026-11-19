"""Tests for docs_scenarios.py (the weekly docs-only scenario job, v1.0.6-TODO-98). No network, no R.

Run: python3 .github/scripts/test_audit_docs_scenarios.py
"""
import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import docs_scenarios as ds  # noqa: E402

REPO = Path(__file__).resolve().parents[2]


def sh(cwd, *args):
    return subprocess.run(args, cwd=cwd, check=True, capture_output=True, text=True).stdout


def tmp_repo():
    """A git repo with significant_changes.py and one area's files."""
    d = Path(tempfile.mkdtemp())
    sh(d, "git", "init", "-q", "-b", "main")
    sh(d, "git", "config", "user.email", "t@t")
    sh(d, "git", "config", "user.name", "t")
    (d / "scripts").mkdir()
    shutil.copy(REPO / "scripts/significant_changes.py", d / "scripts/significant_changes.py")
    (d / "R/EDI/R").mkdir(parents=True)
    (d / "R/EDI/man").mkdir(parents=True)
    (d / "R/EDI/R/design_x.R").write_text("#' Docs\nf = function(x) {\n  x + 1\n}\n")
    (d / "R/EDI/man/DesignX.Rd").write_text("\\name{DesignX}\n")
    (d / "R/EDI/R/other.R").write_text("g = function() 2\n")
    sh(d, "git", "add", "-A")
    sh(d, "git", "commit", "-qm", "a")
    return d


def head(d):
    return sh(d, "git", "rev-parse", "HEAD").strip()


AREA = {"id": "x", "paths": ["R/EDI/R/design_x.R", "R/EDI/man/DesignX*.Rd"]}
CFG = {"common_paths": []}


class Config(unittest.TestCase):
    def test_config_loads_and_ids_are_unique(self):
        cfg = ds.load_config(REPO)
        ids = [a["id"] for a in cfg["areas"]]
        self.assertEqual(len(ids), len(set(ids)))
        self.assertGreaterEqual(len(ids), 10)
        for a in cfg["areas"]:
            for k in ("title", "task", "paths", "model", "max_turns", "max_budget_usd", "minutes"):
                self.assertTrue(a.get(k), f"{a['id']}: {k}")

    def test_every_path_glob_matches_a_tracked_file(self):
        cfg = ds.load_config(REPO)
        for a in cfg["areas"]:
            for p in ds.area_paths(a, cfg, REPO):
                hit = sh(REPO, "git", "ls-files", "--", f":(glob){p}").strip()
                self.assertTrue(hit, f"area {a['id']}: path {p!r} matches no tracked file (renamed?)")

    def test_articles_exist(self):
        for a in ds.load_config(REPO)["areas"]:
            for art in a["articles"]:
                self.assertTrue((REPO / ds.ARTICLES / art).exists(), f"{a['id']}: {art}")

    def test_python_kernels_expand(self):
        cfg = ds.load_config(REPO)
        py = next(a for a in cfg["areas"] if a["python"])
        paths = ds.area_paths(py, cfg, REPO)
        self.assertNotIn("@python_kernels", paths)
        self.assertTrue(any(p.startswith("R/EDI/src/fast_") for p in paths))

    def test_runbook_rules_are_section_4(self):
        rules = ds.runbook_rules(REPO)
        self.assertIn("**What you may read:**", rules)
        self.assertIn("**What counts as a finding:**", rules)
        self.assertNotIn("## 5.", rules)
        self.assertNotIn("Give these to the agent verbatim", rules)


class Skip(unittest.TestCase):
    def test_first_run_is_due(self):
        d = tmp_repo()
        self.assertTrue(ds.due_reason(d, AREA, CFG, None, head(d))[0])

    def test_unknown_commit_is_due(self):
        d = tmp_repo()
        due, why, _ = ds.due_reason(d, AREA, CFG, {"last_run_sha": "f" * 40}, head(d))
        self.assertTrue(due)
        self.assertIn("not in history", why)

    def test_comment_only_edit_is_not_due(self):
        d = tmp_repo()
        a = head(d)
        (d / "R/EDI/R/design_x.R").write_text("#' Docs, reworded\nf = function(x) {\n  x + 1   # one\n}\n")
        sh(d, "git", "commit", "-qam", "comment")
        self.assertFalse(ds.due_reason(d, AREA, CFG, {"last_run_sha": a}, head(d))[0])

    def test_other_area_change_is_not_due(self):
        d = tmp_repo()
        a = head(d)
        (d / "R/EDI/R/other.R").write_text("g = function() 3\n")
        sh(d, "git", "commit", "-qam", "other")
        self.assertFalse(ds.due_reason(d, AREA, CFG, {"last_run_sha": a}, head(d))[0])

    def test_code_change_is_due(self):
        d = tmp_repo()
        a = head(d)
        (d / "R/EDI/R/design_x.R").write_text("#' Docs\nf = function(x) {\n  x + 2\n}\n")
        sh(d, "git", "commit", "-qam", "code")
        due, why, changed = ds.due_reason(d, AREA, CFG, {"last_run_sha": a}, head(d))
        self.assertTrue(due)
        self.assertEqual(changed, ["R/EDI/R/design_x.R"])

    def test_docs_change_is_due(self):
        d = tmp_repo()
        a = head(d)
        (d / "R/EDI/man/DesignX.Rd").write_text("\\name{DesignX}\n\\title{New}\n")
        sh(d, "git", "commit", "-qam", "rd")
        self.assertTrue(ds.due_reason(d, AREA, CFG, {"last_run_sha": a}, head(d))[0])

    def test_same_commit_is_not_due(self):
        d = tmp_repo()
        self.assertFalse(ds.due_reason(d, AREA, CFG, {"last_run_sha": head(d)}, head(d))[0])

    def test_unchanged_area_rerun_after_42_days(self):
        # Owner decision 2026-11-18: unchanged areas re-run every 6 weeks.
        import datetime as _dt
        d = tmp_repo()
        cfg = {**CFG, "defaults": {**CFG.get("defaults", {}), "rerun_unchanged_after_days": 42}}
        now = _dt.datetime(2026, 12, 31, tzinfo=_dt.timezone.utc)
        recent = {"last_run_sha": head(d), "last_run_at": "2026-12-01T00:00:00Z"}
        old = {"last_run_sha": head(d), "last_run_at": "2026-11-01T00:00:00Z"}
        self.assertFalse(ds.due_reason(d, AREA, cfg, recent, head(d), now=now)[0])
        due, why, _ = ds.due_reason(d, AREA, cfg, old, head(d), now=now)
        self.assertTrue(due)
        self.assertTrue(why.startswith(ds.STALE_PREFIX))
        # without the setting, an unchanged area is never re-run
        self.assertFalse(ds.due_reason(d, AREA, {**CFG, "defaults": {}}, old, head(d), now=now)[0])

    def test_changed_areas_before_periodic_reruns(self):
        cfg = {"defaults": {"max_areas_per_run": 1}, "areas": [{"id": "a"}, {"id": "b"}]}
        state = {"areas": {"a": {"last_run_at": "2026-01-01T00:00:00Z"}, "b": {"last_run_at": "2026-06-01T00:00:00Z"}}}
        due = {"a": (True, ds.STALE_PREFIX + "300 days", []), "b": (True, "1 path(s) changed", ["x"])}
        chosen = ds.choose(cfg, state, due, "changed")
        first = chosen[0] if isinstance(chosen, tuple) else chosen
        self.assertEqual(list(first)[:1], ["b"])

    def test_choose_orders_and_caps(self):
        cfg = {"defaults": {"max_areas_per_run": 2}, "areas": [{"id": "a"}, {"id": "b"}, {"id": "c"}, {"id": "d"}]}
        state = {"areas": {"a": {"last_run_at": "2026-11-01"}, "b": {"last_run_at": "2026-10-01"}}}
        due = {"a": (True,), "b": (True,), "c": (True,), "d": (False,)}
        ids, deferred = ds.choose(cfg, state, due, "changed")
        self.assertEqual(ids, ["c", "b"])           # never run first, then the oldest
        self.assertEqual(deferred, ["a"])
        self.assertEqual(ds.choose(cfg, state, due, "all")[0], ["c", "d", "b", "a"])  # no cap on 'all'
        self.assertEqual(ds.choose(cfg, state, due, "d")[0], ["d"])
        with self.assertRaises(SystemExit):
            ds.choose(cfg, state, due, "nope")


class Findings(unittest.TestCase):
    TEXT = """### F1: NA with no warning
- Kind: Silent NA
- Expected (docs): a number
- Observed: NA
- Repro:
  ```r
  x = 1
  ```
- Workaround used, if any: none

### F2: no repro here
- Kind: false docs
- Repro:
  ```r
  ```
"""

    def test_parse(self):
        f = ds.parse_findings(self.TEXT)
        self.assertEqual([x["n"] for x in f], [1, 2])
        self.assertEqual(f[0]["kind"], "silent NA")
        self.assertTrue(f[0]["has_repro"])
        self.assertFalse(f[1]["has_repro"])
        self.assertEqual(ds.parse_findings("No new findings."), [])

    def test_redact(self):
        t = ds.redact("key sk-ant-abcdefghijklmnop and SECRETVALUE123 and ghs_" + "a" * 30, ["SECRETVALUE123"])
        self.assertNotIn("sk-ant-abc", t)
        self.assertNotIn("SECRETVALUE123", t)
        self.assertNotIn("ghs_aaa", t)

    def test_status_from_release_and_dismissed(self):
        d = Path(tempfile.mkdtemp())
        (d / "R/package_metadata/future_release_plans").mkdir(parents=True)
        (d / "R/package_metadata/audits").mkdir(parents=True)
        (d / "R/package_metadata/future_release_plans/release_v1_0_6.md").write_text(
            "- [ ] TODO-30 (added): **Bug.** found as `ds-x-11-f1`.\n  more text ds-x-11-f3\n"
            "- [x] TODO-31: done, `ds-x-11-f2`\n")
        (d / ds.DISMISSED).write_text("- `ds-x-11-f3`: not a bug (2026-11-20)\n")
        rows = [{"id": f"ds-x-11-f{i}"} for i in (1, 2, 3, 4)]
        ds.refresh_statuses(d, rows)
        self.assertEqual([(r["status"], r["todo"]) for r in rows],
                         [("filed", "v1.0.6-TODO-30"), ("closed", "v1.0.6-TODO-31"), ("dismissed", None), ("open", None)])


class EndToEnd(unittest.TestCase):
    def test_plan_render_collect_report(self):
        w = Path(tempfile.mkdtemp())
        notes, work = w / "notes", w / "work"
        rc = ds.main(["plan", "--repo", str(REPO), "--notes", str(notes), "--work", str(work),
                      "--requested", "custom-statistic,python-kernels", "--github-output", str(w / "o1")])
        self.assertEqual(rc, 0)
        o1 = (w / "o1").read_text()
        self.assertIn("has=true", o1)
        self.assertIn("python=true", o1)
        kit = work / "kits" / "custom-statistic"
        self.assertEqual(sorted(p.name for p in (kit / "pkg").iterdir()), ["DESCRIPTION"])  # no package source
        self.assertTrue((kit / "context/articles/custom-randomization-statistic.Rmd").exists())
        self.assertTrue((work / "kits/python-kernels/context/python/README_PYPI.md").exists())

        run = w / "run"
        ds.main(["render", "--kit", str(kit), "--lib", "/lib", "--run-dir", str(run), "--github-output", str(w / "o2")])
        prompt = (run / "prompt.md").read_text()
        self.assertNotIn("{{", prompt)
        self.assertIn("**What you may not read:**", prompt)
        self.assertIn(str(run / "context" / "learnings.md"), prompt)
        self.assertIn("model=claude-", (w / "o2").read_text())
        pyrun = w / "pyrun"
        ds.main(["render", "--kit", str(work / "kits/python-kernels"), "--lib", "/lib", "--run-dir", str(pyrun),
                 "--venv", "/venv", "--github-output", str(w / "o3")])
        self.assertIn("/venv/bin/python", (pyrun / "prompt.md").read_text())

        # the agent's files: one ok area, one area that timed out with findings only
        (run / "summary.md").write_text("did it")
        (run / "findings.md").write_text(Findings.TEXT)
        (run / "learnings_update.md").write_text("## Covered\n- trimmed means\n")
        res = w / "results"
        ds.main(["collect", "--kit", str(kit), "--run-dir", str(run), "--out", str(res / "custom-statistic"),
                 "--outcome", "success"])
        (pyrun / "findings.md").write_text(Findings.TEXT.split("### F2")[0])
        ds.main(["collect", "--kit", str(work / "kits/python-kernels"), "--run-dir", str(pyrun),
                 "--out", str(res / "python-kernels"), "--outcome", "failure"])
        self.assertEqual(json.loads((res / "python-kernels/result.json").read_text())["status"], "partial")

        repo = w / "repo"
        (repo / ds.RELEASE_GLOB.rsplit("/", 1)[0]).mkdir(parents=True)
        rc = ds.main(["report", "--repo", str(repo), "--notes", str(notes), "--plan", str(work / "plan.json"),
                      "--results", str(res), "--run-id", "77", "--date", "2026-11-21", "--report", str(w / "r.md"),
                      "--github-output", str(w / "o4")])
        self.assertEqual(rc, 0)
        o4 = (w / "o4").read_text()
        self.assertIn("status=FINDINGS", o4)
        self.assertIn("new=2", o4)    # F1 of each area; F2 has no repro
        f = repo / "R/package_metadata/audits/docs_scenario_findings/2026-11-21-run77.md"
        self.assertIn("ds-custom-statistic-77-f1", f.read_text())
        st = ds.State(notes)
        state = st.load()["areas"]
        head = json.loads((work / "plan.json").read_text())["head"]
        self.assertEqual(state["custom-statistic"]["last_run_sha"], head)      # ok: advanced
        self.assertNotIn("last_run_sha", state["python-kernels"])              # partial: re-runs next week
        self.assertIn("trimmed means", st.learnings("custom-statistic"))
        self.assertEqual(len(st.findings()), 2)
        # a second report of the same run does not register the findings twice
        ds.main(["report", "--repo", str(repo), "--notes", str(notes), "--plan", str(work / "plan.json"),
                 "--results", str(res), "--run-id", "77", "--date", "2026-11-21", "--report", str(w / "r.md"),
                 "--github-output", str(w / "o5")])
        self.assertEqual(len(st.findings()), 2)
        self.assertIn("status=NONE", (w / "o5").read_text())
        # the next plan shows them to the agent as known
        ds.main(["plan", "--repo", str(REPO), "--notes", str(notes), "--work", str(w / "work2"),
                 "--requested", "custom-statistic", "--github-output", str(w / "o6")])
        known = (w / "work2/kits/custom-statistic/context/known_findings.md").read_text()
        self.assertIn("ds-custom-statistic-77-f1", known)

    def test_notrun_result_when_agent_left_nothing(self):
        w = Path(tempfile.mkdtemp())
        ds.main(["plan", "--repo", str(REPO), "--notes", str(w / "n"), "--work", str(w / "k"),
                 "--requested", "factorial", "--github-output", str(w / "o")])
        ds.main(["collect", "--kit", str(w / "k/kits/factorial"), "--run-dir", str(w / "empty"),
                 "--out", str(w / "res"), "--notrun", "no key"])
        r = json.loads((w / "res/result.json").read_text())
        self.assertEqual((r["status"], r["note"]), ("notrun", "no key"))


class Workflow(unittest.TestCase):
    def test_agent_job_has_no_checkout(self):
        text = (REPO / ".github/workflows/audit-docs-scenarios.yml").read_text()
        scenario = text.split("\n  scenario:\n", 1)[1].split("\n  publish:\n", 1)[0]
        self.assertNotIn("uses: actions/checkout", scenario)
        self.assertIn("contents: read", scenario)
        self.assertNotIn("GH_TOKEN", scenario)


if __name__ == "__main__":
    unittest.main(verbosity=1)
