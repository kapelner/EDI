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


if __name__ == "__main__":
    unittest.main(verbosity=1)
