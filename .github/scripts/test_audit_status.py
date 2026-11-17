"""Tests for audit_status.py (the audits' status table). No network.

Run: cd .github/scripts && python3 test_audit_status.py
"""
import tempfile
import unittest
from pathlib import Path

import audit_status as st

CALLER = """name: audit · {freq} · {name}
on:
  schedule:
    - cron: "{cron}"
jobs:
  audit:
    uses: ./.github/workflows/audit.yml
    with:
      audit: {name}
      nth: {nth}
"""


class Status(unittest.TestCase):
    def test_describe(self):
        self.assertEqual(st.describe("0 7 * * *", 0), {"freq": "daily", "schedule": "daily 07:00 UTC"})
        self.assertEqual(st.describe("0 6 * * 6", 0), {"freq": "weekly", "schedule": "Sat 06:00 UTC"})
        self.assertEqual(st.describe("0 6 * * 0", 3), {"freq": "monthly", "schedule": "3rd Sun 06:00 UTC"})
        self.assertEqual(st.describe(None, 0)["freq"], "manual")

    def test_callers_grouped_and_sorted(self):
        d = Path(tempfile.mkdtemp())
        (d / "audit-rd.yml").write_text(CALLER.format(freq="weekly", name="rd", cron="0 6 * * 6", nth=0))
        (d / "audit-dead-code.yml").write_text(CALLER.format(freq="monthly", name="dead-code", cron="0 6 * * 1", nth=2))
        (d / "audit-cran-watcher.yml").write_text(CALLER.format(freq="daily", name="cran-watcher", cron="0 7 * * *", nth=0))
        (d / "audit-status.yml").write_text("name: audit status\n")
        (d / "audit.yml").write_text("name: reusable\n")
        got = st.callers(d)
        self.assertEqual([c["audit"] for c in got], ["cran-watcher", "rd", "dead-code"])
        self.assertEqual(got[2]["schedule"], "2nd Mon 06:00 UTC")

    def test_result_of(self):
        self.assertEqual(st.result_of(None, []), "never run")
        self.assertEqual(st.result_of({"status": "in_progress"}, []), "running")
        self.assertEqual(st.result_of({"status": "completed", "conclusion": "startup_failure"}, []), "FAILED to start")
        done = {"status": "completed", "conclusion": "success"}
        gated = [{"name": "audit / prepare", "conclusion": "success"},
                 {"name": "audit / claude", "conclusion": "skipped"},
                 {"name": "audit / finish", "conclusion": "skipped"},
                 {"name": "verify-plan", "conclusion": "success"}]
        self.assertEqual(st.result_of(done, gated), "not due (gate)")
        ran = [{"name": "audit / prepare", "conclusion": "success"},
               {"name": "audit / claude", "conclusion": "skipped"},
               {"name": "audit / finish", "conclusion": "success"}]
        self.assertEqual(st.result_of(done, ran), "passed")

    def test_render(self):
        rows = [{"audit": "rd", "file": "audit-rd.yml", "freq": "weekly", "schedule": "Sat 06:00 UTC",
                 "result": "FAILED", "open": [{"kind": "PR", "number": 5, "url": "u", "draft": True}],
                 "last_at": "2026-11-17T07:00:00Z", "last_url": "r", "last_event": "workflow_dispatch"},
                {"audit": "dead-code", "file": "audit-dead-code.yml", "freq": "monthly",
                 "schedule": "2nd Mon 06:00 UTC", "result": "not due (gate)", "open": [],
                 "last_real": {"at": "2026-11-10T06:00:00Z", "url": "r2"},
                 "last_at": "2026-11-17T06:00:00Z", "last_url": "r3", "last_event": "schedule"}]
        body = st.render(rows, "2026-11-17T08:00:00+00:00", "https://run", "o/r")
        self.assertIn("## Weekly", body)
        self.assertIn("## Monthly", body)
        self.assertNotIn("## Daily", body)
        self.assertIn("1 failed on their last run: `rd`", body)
        self.assertIn("[draft PR #5](u)", body)
        self.assertIn("last real run [2026-11-10 06:00 UTC](r2)", body)
        self.assertIn("https://github.com/o/r/actions/workflows/audit-rd.yml", body)


class Repo(unittest.TestCase):
    def test_every_caller_triggers_the_status_workflow(self):
        wf = Path(__file__).resolve().parents[1] / "workflows"
        status = (wf / "audit-status.yml").read_text()
        names = [c["name"] for c in st.callers(wf)]
        self.assertGreaterEqual(len(names), 21)
        for n in names:
            self.assertRegex(n, r"^audit · (daily|weekly|monthly) · [\w-]+$")
            self.assertIn(f'- "{n}"', status, f"add {n} to audit-status.yml workflow_run")


if __name__ == "__main__":
    unittest.main(verbosity=1)
