#!/usr/bin/env python3
"""Checks for the audit framework (audit_common.py, audit_run.py). Stdlib only."""
import datetime as dt
import json
import os
import shutil
import subprocess
import sys
import tempfile
import types
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import audit_common as ac  # noqa: E402
import audit_run  # noqa: E402

NOW = dt.datetime(2026, 11, 17, 6, tzinfo=dt.timezone.utc)
SPEC = {**ac.DEFAULT_SPEC, "name": "demo", "title": "Demo", "label": "audit-demo", "claude": True}


class Schedule(unittest.TestCase):
    def test_nth_weekday(self):
        self.assertEqual([ac.nth_weekday_of_month(d) for d in (1, 7, 8, 14, 15, 22, 28, 29)],
                         [1, 1, 2, 2, 3, 4, 4, 5])

    def test_due_today(self):
        third = dt.datetime(2026, 11, 21, tzinfo=dt.timezone.utc)      # a Saturday, days 15-21
        self.assertTrue(ac.due_today(3, third, "schedule"))
        self.assertFalse(ac.due_today(1, third, "schedule"))
        self.assertTrue(ac.due_today(1, third, "workflow_dispatch"))   # manual runs always run
        self.assertTrue(ac.due_today(0, third, "schedule"))            # weekly jobs always run

    def test_rotation_visits_each_unit_once_per_cycle(self):
        weeks = [NOW + dt.timedelta(weeks=w) for w in range(8)]
        for uid in ("a", "b", "man/foo.Rd", "x" * 50):
            self.assertEqual(sum(ac.in_rotation(uid, 8, w) for w in weeks), 1, uid)
        self.assertTrue(ac.in_rotation("a", 1, NOW))

    def test_monthly_rotation_counts_months(self):
        months = [dt.datetime(2026 + (m // 12), m % 12 + 1, 10, tzinfo=dt.timezone.utc) for m in range(6)]
        for uid in ("a", "b", "src/x.cpp"):
            self.assertEqual(sum(ac.in_rotation(uid, 6, t, "month") for t in months), 1, uid)


class Selection(unittest.TestCase):
    def units(self):
        return {u: {"hash": f"h{u}", "deps": "d"} for u in "abcdef"}

    def manifest(self, **over):
        m = {"units": {u: {"hash": f"h{u}", "deps": "d", "audited_at": "2026-11-01T00:00:00+00:00"}
                       for u in "abcdef"}}
        for u, v in over.items():
            m["units"][u].update(v)
        return m

    def test_unchanged_units_wait_for_rotation(self):
        chosen, reasons, _ = ac.select_units(self.units(), self.manifest(), "auto", 1000, NOW)
        self.assertTrue(all("rotation" in reasons[u] for u in chosen))
        self.assertLessEqual(len(chosen), 1)

    def test_new_changed_deps_open(self):
        m = self.manifest(b={"hash": "old"}, c={"deps": "old"}, d={"open_findings": 2})
        del m["units"]["a"]
        chosen, reasons, _ = ac.select_units(self.units(), m, "auto", 1000, NOW)
        self.assertEqual(reasons["a"], "new")
        self.assertEqual(reasons["b"], "changed")
        self.assertIn("depends", reasons["c"])
        self.assertEqual(reasons["d"], "open finding")
        self.assertEqual(chosen[-1], "d")       # open findings rank after new and changed

    def test_scopes(self):
        self.assertEqual(len(ac.select_units(self.units(), self.manifest(), "all", 8, NOW)[0]), 6)
        self.assertEqual(ac.select_units(self.units(), {}, "none", 8, NOW)[0], [])

    def test_cap_rolls_oldest_last(self):
        chosen, _, rolled = ac.select_units(self.units(), {}, "auto", 8, NOW, max_units=4)
        self.assertEqual(len(chosen), 4)
        self.assertEqual(len(rolled), 2)

    def test_priority_orders_within_a_class(self):
        units = {u: {"hash": "h", "priority": p} for u, p in (("a", 2), ("b", 0), ("c", 1))}
        chosen, _, rolled = ac.select_units(units, {}, "auto", 8, NOW, max_units=2)
        self.assertEqual(chosen, ["b", "c"])
        self.assertEqual(rolled, ["a"])

    def test_batches_split_by_model(self):
        units = {f"u{i}": {"hash": "h", "model": ac.OPUS if i < 3 else None} for i in range(12)}
        b = ac.make_batches(list(units), units, {**SPEC, "batch_size": 4})
        self.assertEqual([(x["model"], len(x["units"])) for x in b],
                         [(ac.OPUS, 3), (ac.SONNET, 4), (ac.SONNET, 4), (ac.SONNET, 1)])


class Findings(unittest.TestCase):
    def test_ids_ignore_whitespace_and_case(self):
        self.assertEqual(ac.finding_id("rd", "u", "k", "Fix  This"), ac.finding_id("rd", "u", "k", "fix this"))

    def test_rejected_are_dropped(self):
        f = [ac.normalise_finding("rd", {"unit": "u", "text": "t"}, "claude")]
        hist = [{"id": f[0]["id"], "status": "rejected"}]
        self.assertEqual(ac.drop_rejected(f, hist), [])

    def test_harvest(self):
        hist = [
            {"id": "1", "pr": 7, "status": "proposed", "applied_file": "a.R", "applied_text": "good"},
            {"id": "2", "pr": 7, "status": "proposed", "applied_file": "a.R", "applied_text": "dropped"},
            {"id": "3", "pr": 6, "status": "proposed", "applied_file": "a.R", "applied_text": "x"},
        ]
        hist, lines = ac.harvest_pr(hist, "MERGED", 7, lambda p: "this is good text")
        self.assertEqual([h["status"] for h in hist], ["fixed", "rejected", "proposed"])
        self.assertEqual(len(lines), 1)
        hist2, lines2 = ac.harvest_pr([{"id": "4", "pr": 8, "status": "proposed", "applied_file": "b"}],
                                      "CLOSED", 8, lambda p: "")
        self.assertEqual(hist2[0]["status"], "rejected")


DEMO = '''
import audit_common as ac
SPEC = {"name": "demo", "title": "Demo", "claude": True, "batch_size": 2}
def mechanical(ctx):
    return [{"unit": "a.txt", "kind": "lint", "text": "trailing space"}]
def units(ctx):
    return {f: {"hash": ac.file_hash(ctx.path(f)), "context": {"file": f}} for f in ("a.txt", "b.txt", "c.txt")}
def apply(ctx, results, mech):
    applied, proposed = [], []
    for r in results:
        for f in r.get("findings", []):
            p = ctx.path(f["unit"])
            p.write_text(p.read_text() + f["fix"] + "\\n")
            applied.append(f"{f['unit']}: {f['text']}")
            proposed.append({**f, "applied_file": f["unit"], "applied_text": f["fix"]})
    return {"applied": applied, "mechanical": [m["text"] for m in mech], "proposed": proposed}
'''


class EndToEnd(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.repo = self.tmp / "repo"
        self.repo.mkdir()
        run = lambda *a: subprocess.run(["git", *a], cwd=self.repo, check=True, capture_output=True)
        run("init", "-q", "-b", "main")
        run("config", "user.email", "t@t"); run("config", "user.name", "t")
        for f in ("a.txt", "b.txt", "c.txt"):
            (self.repo / f).write_text(f + "\n")
        run("add", "-A"); run("commit", "-qm", "x")
        pkg = self.tmp / "mods" / "audits"
        pkg.mkdir(parents=True)
        (pkg / "__init__.py").write_text("")
        (pkg / "demo.py").write_text(DEMO)
        sys.path.insert(0, str(self.tmp / "mods"))
        sys.modules.pop("audits", None); sys.modules.pop("audits.demo", None)
        self.out = self.tmp / "out.txt"

    def tearDown(self):
        sys.path.remove(str(self.tmp / "mods"))
        sys.modules.pop("audits", None); sys.modules.pop("audits.demo", None)
        sys.path.insert(0, str(Path(__file__).parent))

    def args(self, cmd, *extra):
        return [cmd, "--audit", "demo", "--repo", str(self.repo), "--notes", str(self.tmp / "notes"),
                "--work", str(self.tmp / "work"), "--github-output", str(self.out), *extra]

    def outputs(self):
        return dict(l.split("=", 1) for l in self.out.read_text().splitlines())

    def test_prepare_finish_and_second_run(self):
        audit_run.main(self.args("prepare", "--no-harvest"))
        o = self.outputs()
        batches = json.loads(o["batches"])
        self.assertEqual(len(batches), 2)                          # 3 units, 2 per batch
        b1 = json.loads((self.tmp / "work/batches/b001.json").read_text())
        self.assertEqual(b1["units"][0]["reason"], "new")
        self.assertEqual(b1["units"][0]["file"], "a.txt")          # the unit's context is passed on
        res = self.tmp / "results"; res.mkdir()
        (res / "b001.json").write_text(json.dumps({"units_checked": ["a.txt", "b.txt"], "findings": [
            {"unit": "b.txt", "kind": "typo", "text": "add a line", "fix": "FIXED"}]}))
        (res / "b002.notrun").write_text("no key")
        self.out.write_text("")
        audit_run.main(self.args("finish", "--results", str(res)))
        o = self.outputs()
        self.assertEqual(o["changed"], "true")
        self.assertIn("FIXED", (self.repo / "b.txt").read_text())
        report = (self.tmp / "work/report.md").read_text()
        self.assertIn("b002 (no key)", report)                     # NOT RUN, never clean
        self.assertIn("trailing space", report)
        notes = ac.Notes(self.tmp / "notes", "demo")
        m = notes.manifest()
        self.assertEqual(set(m["units"]), {"a.txt", "b.txt"})      # c.txt was not covered: stays due
        self.assertEqual(m["units"]["b.txt"]["open_findings"], 1)
        hist = notes.findings()
        self.assertEqual(sorted(h["status"] for h in hist), ["proposed", "reported"])

        # The owner rejects the PR: the finding must not come back.
        for h in hist:
            if h["status"] == "proposed":
                h["pr"] = 5
        hist, lines = ac.harvest_pr(hist, "CLOSED", 5, lambda p: "")
        notes.save_findings(hist); notes.add_decisions(lines)
        self.assertIn("add a line", notes.decisions())
        subprocess.run(["git", "checkout", "--", "."], cwd=self.repo, check=True)
        self.out.write_text("")
        audit_run.main(self.args("prepare", "--no-harvest"))
        plan = json.loads((self.tmp / "work/plan.json").read_text())
        self.assertIn("c.txt", plan["chosen"])                     # still new
        self.assertIn("b.txt", plan["chosen"])                     # had an open finding
        self.assertIn("add a line", (self.tmp / "work/decisions.md").read_text())
        res2 = self.tmp / "results2"; res2.mkdir()
        (res2 / "b001.json").write_text(json.dumps({"findings": [
            {"unit": "b.txt", "kind": "typo", "text": "Add a  line", "fix": "AGAIN"}]}))
        self.out.write_text("")
        audit_run.main(self.args("finish", "--results", str(res2)))
        hist = ac.Notes(self.tmp / "notes", "demo").findings()
        self.assertEqual(sum(1 for h in hist if h["text"].lower().startswith("add a")), 1)  # not re-recorded

    def test_mechanical_only_audit(self):
        (self.tmp / "mods/audits/demo.py").write_text(
            'SPEC = {"name": "demo", "report": "issue"}\n'
            'def mechanical(ctx):\n    return [{"unit": "x", "text": "bad"}]\n')
        audit_run.main(self.args("prepare", "--no-harvest"))
        self.assertEqual(self.outputs()["claude"], "false")
        self.out.write_text("")
        audit_run.main(self.args("finish"))
        self.assertEqual(self.outputs()["findings"], "true")
        self.assertIn("bad", (self.tmp / "work/report.md").read_text())


class Repo(unittest.TestCase):
    """Every audit module in the repository loads and has what its stages need."""

    def test_audit_modules(self):
        here = Path(__file__).parent
        prompts = here.parent / "prompts"
        workflows = here.parent / "workflows"
        for mod_file in sorted((here / "audits").glob("*.py")):
            if mod_file.name.startswith("_"):
                continue
            name = mod_file.stem
            mod = ac.load_audit(name)
            spec = ac.spec_of(mod)
            self.assertEqual(spec["name"].replace("-", "_"), name)
            self.assertIn(spec["report"], ("pr", "issue"), name)
            if spec["claude"]:
                self.assertTrue(hasattr(mod, "units"), name)
                self.assertTrue((prompts / f"audit_{name}.md").exists(), name)
                schema = (prompts / f"audit_{name}.schema.json").read_text()
                self.assertNotIn("'", schema, f"{name}: schemas are passed in single quotes")
                json.loads(schema)
            wf = workflows / f"audit-{spec['name']}.yml"
            self.assertTrue(wf.exists(), f"{name}: no caller workflow {wf.name}")
            self.assertIn(f"audit: {spec['name']}", wf.read_text(), name)


class Body(unittest.TestCase):
    def test_fit_body(self):
        short = "## A\n\n- one\n"
        self.assertEqual(ac.fit_body(short), short)
        lines = "\n".join(f"- finding {i} " + "x" * 200 for i in range(2000))
        report = "## TODO-status audit\n\n" + lines + "\n\n### Coverage\n\n- units in scope: 2054\n\nRun: https://r\n"
        out = ac.fit_body(report, "https://r")
        self.assertLessEqual(len(out), ac.BODY_LIMIT)
        self.assertTrue(out.startswith("## TODO-status audit"))
        self.assertIn("### Coverage", out)
        self.assertIn("units in scope: 2054", out)
        self.assertIn("more line(s) not shown", out)
        self.assertIn("https://r", out)
        # no Coverage section: still cut to fit
        self.assertLessEqual(len(ac.fit_body("x\n" * 50000)), ac.BODY_LIMIT)



class IssueNote(unittest.TestCase):
    def test_says_not_a_task(self):
        n = ac.issue_note({"name": "results-freshness"})
        self.assertIn("not a task", n)
        self.assertIn("audit-results-freshness.yml", n)
        self.assertTrue(n.startswith("> [!NOTE]"))


class SettleOpenCounts(unittest.TestCase):
    def test_merged_pr_clears_open_findings(self):
        m = {"units": {"a": {"hash": "h", "open_findings": 2}, "b": {"hash": "h", "open_findings": 1},
                       "c": {"hash": "h", "open_findings": 1}}}
        ac.settle_open_counts(m, [{"unit": "a"}, {"unit": "a"}, {"unit": "b"}, {"unit": "gone"}])
        self.assertEqual([m["units"][u]["open_findings"] for u in "abc"], [0, 0, 1])
        now = ac.now_utc()
        chosen, reasons, _ = ac.select_units({u: {"hash": "h"} for u in "abc"}, m, "auto", 10**6, now)
        self.assertEqual(chosen, ["c"])          # only the unit with a still-open finding


class Decisions(unittest.TestCase):
    def track(self, items, prev, covered=(), units=("u1", "u2"), cited=(), dismissed=(), keep=False):
        return ac.track_decisions("rd", items, prev, set(covered), set(units), set(cited), set(dismissed),
                                  "2026-11-17T00:00:00+00:00", keep_unlisted=keep)

    def test_id_is_stable_across_wording(self):
        a = ac.decision_id("rd", "u1", "example", "it fails on seed 3")
        self.assertEqual(a, ac.decision_id("rd", "u1", "example", "seed 3 fails, says the agent"))
        self.assertRegex(a, r"^rd-d[0-9a-f]{8}$")
        self.assertNotEqual(a, ac.decision_id("rd", "u2", "example", "x"))

    def test_carried_resolved_cited_dismissed(self):
        first, lines, _ = self.track([ac.decision("A fails", "u1", "example"), ac.decision("B odd", "u2", "x"),
                                      "mechanical thing"], {})
        self.assertEqual(len(first), 3)
        self.assertTrue(all("open since 2026-11-17" in l for l in lines))
        ida, idb, idm = list(first)
        # next run: nothing reported; u1 not re-read (carried), u2 re-read (resolved), text-only item gone
        nxt, lines, _ = ac.track_decisions("rd", [], first, {"u2"}, {"u1", "u2"}, set(), set(), "2026-11-24T00:00:00+00:00")
        self.assertEqual(list(nxt), [ida])
        self.assertIn("not re-checked this run", lines[0])
        self.assertIn("open since 2026-11-17", lines[0])          # first_seen kept
        # a unit that is no longer an audit unit is resolved, unless the audit keeps unlisted units
        self.assertEqual(self.track([], first, units=())[0], {})
        self.assertEqual(set(self.track([], first, units=(), keep=True)[0]), {ida, idb})
        # cited by an open TODO: kept, not listed; dismissed: dropped
        kept, lines, counts = self.track([ac.decision("A fails", "u1", "example")], first, covered=("u1", "u2"), cited={ida})
        self.assertIn(ida, kept)
        self.assertEqual(lines, [])
        self.assertEqual(counts["cited"], 1)
        kept, lines, counts = self.track([ac.decision("A fails", "u1", "example")], first, covered=("u1", "u2"), dismissed={ida})
        self.assertNotIn(ida, kept)
        self.assertEqual(counts["dismissed"], 1)

    def test_same_unit_and_key_twice(self):
        kept, _, _ = self.track([ac.decision("one", "u1", "k"), ac.decision("two", "u1", "k")], {})
        self.assertEqual(len(kept), 2)

    def test_multiline_item_tag_on_first_line(self):
        _, lines, _ = self.track([ac.decision("head\n  - detail", "u1", "k")], {})
        self.assertTrue(lines[0].startswith("head <sub>`rd-d"))
        self.assertTrue(lines[0].endswith("\n  - detail"))

    def test_cited_and_dismissed_from_files(self):
        tmp = Path(tempfile.mkdtemp())
        try:
            d = tmp / "R/package_metadata/future_release_plans"
            d.mkdir(parents=True)
            (d / "release_v1_0_6.md").write_text("- [ ] TODO-1 x (rd-d0123abcd)\n- [x] TODO-2 y (rd-d99999999)\n")
            self.assertEqual(ac.cited_decisions(tmp), {"rd-d0123abcd"})
            (tmp / ac.DISMISSED_FILE).parent.mkdir(parents=True)
            (tmp / ac.DISMISSED_FILE).write_text("- `rpy-parity-d00000001`: intended difference\n")
            self.assertEqual(ac.dismissed_decisions(tmp), {"rpy-parity-d00000001"})
        finally:
            shutil.rmtree(tmp)

    def test_render_sections(self):
        md = ac.render_report({"title": "T"}, {"human": ["decide this"], "info": ["fyi"],
                                               "decision_note": "note"}, {"k": 1}, "u")
        self.assertIn("### Decisions for you (1)", md)
        self.assertIn("<details><summary>For information (1)", md)
        self.assertNotIn("Needs a human", md)
        self.assertLess(md.index("Decisions for you"), md.index("For information"))
        self.assertFalse(ac.has_findings({"info": ["fyi"]}))       # information alone opens nothing

    def test_cut_inside_details_closes_it(self):
        md = ac.render_report({"title": "T"}, {"info": [f"line {i} " + "x" * 80 for i in range(200)]}, {"k": 1}, "u")
        cut = ac.fit_body(md, "", limit=4000)
        self.assertEqual(cut.count("<details>"), cut.count("</details>"))
        self.assertIn("### Coverage", cut)

if __name__ == "__main__":
    unittest.main(verbosity=1)
