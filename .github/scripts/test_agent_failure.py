#!/usr/bin/env python3
"""Checks for agent_failure.py and the audits' not-run banner. Stdlib only, no network."""
import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import agent_failure as af  # noqa: E402
import audit_run  # noqa: E402

# The shape of a refused run's transcript (research task adjacent-cat-cr-logit-mle, run
# 44358397244, 2026-11-18), trimmed to the fields agent_failure reads.
LIMIT = "You've hit your weekly limit · resets Nov 20, 3am (UTC)"
REFUSED = [
    {"type": "system", "subtype": "init"},
    {"type": "assistant", "message": {"model": "<synthetic>", "content": [{"type": "text", "text": LIMIT}]},
     "error": "rate_limit", "is_api_error_message": True, "api_error_status": 429,
     "api_error": "usage_limit_reached", "api_error_type": "rate_limit_error"},
    {"type": "result", "subtype": "success", "is_error": True, "num_turns": 1, "total_cost_usd": 0,
     "terminal_reason": "api_error", "api_error_status": 429, "api_error": "usage_limit_reached",
     "result": LIMIT},
]
EXPECTED = f"API refused the request (429 usage_limit_reached): {LIMIT}"


def write(text, suffix=".json"):
    f = tempfile.NamedTemporaryFile("w", suffix=suffix, delete=False)
    f.write(text)
    f.close()
    return f.name


class Reason(unittest.TestCase):
    def test_a_refused_run_names_the_api_error(self):
        self.assertEqual(af.reason(write(json.dumps(REFUSED)), "failure"), EXPECTED)

    def test_stream_json_lines_work_too(self):
        path = write("\n".join(json.dumps(m) for m in REFUSED) + "\nnot json\n", ".jsonl")
        self.assertEqual(af.reason(path, "failure"), EXPECTED)

    def test_an_error_result_without_an_api_error(self):
        msgs = [{"type": "result", "subtype": "error_max_turns", "is_error": True}]
        self.assertEqual(af.reason(write(json.dumps(msgs))), "agent ended with an error: error_max_turns")

    def test_no_transcript_falls_back_to_the_step_outcome(self):
        self.assertEqual(af.reason("", "failure"), "agent produced no structured output (step outcome: failure)")
        self.assertEqual(af.reason("/no/such/file", ""), "agent produced no structured output (step outcome: unknown)")

    def test_a_successful_run_is_not_an_api_error(self):
        msgs = [{"type": "result", "subtype": "success", "is_error": False, "result": "done"}]
        self.assertTrue(af.reason(write(json.dumps(msgs)), "failure").startswith("agent produced no structured"))

    def test_refused_by_quota_picks_out_api_refusals(self):
        self.assertEqual(af.refused_by_quota([EXPECTED, "agent produced no structured output"]), [EXPECTED])


class Banner(unittest.TestCase):
    def test_quota_refusals_say_so_and_when_to_rerun(self):
        b = audit_run.not_run_banner([{"batch": "b005", "reason": EXPECTED},
                                      {"batch": "b006", "reason": EXPECTED}], 10)
        self.assertIn("**2 of 10 batch(es) did not run**", b)
        self.assertIn("marked failed", b)
        self.assertIn("resets Nov 20", b)

    def test_other_reasons_are_listed(self):
        b = audit_run.not_run_banner([{"batch": "b001", "reason": "agent ended with an error: error_max_turns"}], 3)
        self.assertIn("> - agent ended with an error: error_max_turns", b)


class DocsScenarios(unittest.TestCase):
    """The same guard in the docs-only scenario job (docs_scenarios.py, audit-docs-scenarios.yml)."""

    def setUp(self):
        import docs_scenarios
        self.ds = docs_scenarios
        self.w = Path(tempfile.mkdtemp())

    def collect(self, area, transcript, outcome="failure", files=None):
        kit, run = self.w / "kits" / area, self.w / "runs" / area
        kit.mkdir(parents=True)
        run.mkdir(parents=True)
        (kit / "area.json").write_text(json.dumps({"id": area, "head": "abc1234def", "reason": "first run"}))
        for name, text in (files or {}).items():
            (run / name).write_text(text)
        tr = self.w / f"{area}.jsonl"
        tr.write_text(transcript)
        self.ds.main(["collect", "--kit", str(kit), "--run-dir", str(run), "--out", str(self.w / "res" / area),
                      "--outcome", outcome, "--transcripts", str(tr), str(self.w / f"{area}.stderr")])
        return json.loads((self.w / "res" / area / "result.json").read_text())

    def test_collect_records_the_api_refusal(self):
        r = self.collect("factorial", "\n".join(json.dumps(m) for m in REFUSED) + "\n")
        self.assertEqual((r["status"], r["note"]), ("notrun", EXPECTED))

    def test_collect_partial_run_keeps_the_refusal_in_its_note(self):
        r = self.collect("factorial", "\n".join(json.dumps(m) for m in REFUSED) + "\n",
                         files={"findings.md": "### F1: x\n- Kind: false docs\n"})
        self.assertEqual(r["status"], "partial")
        self.assertIn(EXPECTED, r["note"])

    def test_collect_without_an_error_keeps_the_old_note(self):
        r = self.collect("factorial", json.dumps({"type": "result", "is_error": False}) + "\n", outcome="success")
        self.assertEqual(r["status"], "notrun")
        self.assertIn("left no summary.md or findings.md (step outcome: success)", r["note"])

    def test_banner_counts_scenario_agents(self):
        b = self.ds.not_run_banner([("factorial", EXPECTED), ("survival", EXPECTED)], 5)
        self.assertIn("**2 of 5 scenario agent(s) did not run**", b)
        self.assertIn("`factorial`", b)
        self.assertIn("marked failed", b)
        self.assertIn("resets Nov 20", b)
        other = self.ds.not_run_banner([("x", "agent ended with an error: error_max_turns")], 1)
        self.assertIn("> - agent ended with an error: error_max_turns", other)

    def test_report_prepends_the_banner_and_outputs_the_count(self):
        self.collect("factorial", "\n".join(json.dumps(m) for m in REFUSED) + "\n")
        self.collect("survival", "", outcome="success", files={"summary.md": "did it"})
        plan = self.w / "plan.json"
        plan.write_text(json.dumps({"head": "abc1234def", "areas": ["factorial", "survival"], "deferred": [],
                                    "due": {}}))
        (self.w / "repo").mkdir()
        rc = self.ds.main(["report", "--repo", str(self.w / "repo"), "--notes", str(self.w / "notes"),
                           "--plan", str(plan), "--results", str(self.w / "res"), "--run-id", "9",
                           "--date", "2026-11-21", "--report", str(self.w / "r.md"),
                           "--github-output", str(self.w / "o")])
        self.assertEqual(rc, 0)
        report = (self.w / "r.md").read_text()
        self.assertTrue(report.startswith("> [!WARNING]\n> **1 of 2 scenario agent(s) did not run**"))
        self.assertIn("resets Nov 20", report)
        self.assertIn("notrun=1", (self.w / "o").read_text())
        state = self.ds.State(self.w / "notes").load()["areas"]
        self.assertNotIn("last_run_sha", state["factorial"])    # stays due
        self.assertIn("last_run_sha", state["survival"])

    def test_kit_ships_agent_failure_and_workflow_fails_last(self):
        repo = Path(__file__).resolve().parents[2]
        self.assertIn('"agent_failure.py"', (repo / ".github/scripts/docs_scenarios.py").read_text())
        wf = (repo / ".github/workflows/audit-docs-scenarios.yml").read_text()
        publish = wf.split("\n  publish:\n", 1)[1]
        self.assertIn("name: Fail if any scenario agent did not run", publish)
        last = publish.rsplit("\n      - ", 1)[1]
        self.assertTrue(last.startswith("name: Fail if any scenario agent did not run"))
        self.assertIn("steps.report.outputs.notrun", last)


if __name__ == "__main__":
    unittest.main(verbosity=1)
