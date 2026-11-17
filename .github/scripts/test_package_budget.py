#!/usr/bin/env python3
"""Checks for package_budget.py (stdlib only)."""
import datetime as dt
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import package_budget as b  # noqa: E402

LOG = """* using log directory '/x/EDI.Rcheck'
* checking whether package 'EDI' can be installed ... [412s/398s] OK
* checking examples ... [61s/64s] OK
* checking tests ...
  Running 'testthat.R' [23m/24m]
 OK
"""
LOG_WINDOWS = """* checking whether package 'EDI' can be installed ... [530s] OK
* checking examples ... [75s] OK
* checking tests ...
  Running 'testthat.R' [1480s]
 OK
"""


class ParseLog(unittest.TestCase):
    def test_unix_times(self):
        self.assertEqual(b.parse_check_log(LOG), {"install_s": 398, "examples_s": 64, "tests_s": 24 * 60})

    def test_windows_times(self):
        self.assertEqual(b.parse_check_log(LOG_WINDOWS), {"install_s": 530, "examples_s": 75, "tests_s": 1480})

    def test_untimed_steps_are_left_out(self):
        self.assertEqual(b.parse_check_log("* checking examples ... OK\n"), {})


class Collect(unittest.TestCase):
    def test_collect_reads_check_dir(self):
        d = tempfile.mkdtemp()
        os.makedirs(f"{d}/check/EDI.Rcheck/EDI/libs")
        Path(f"{d}/check/EDI_1.0.4.tar.gz").write_bytes(b"x" * 3000)
        Path(f"{d}/check/EDI.Rcheck/EDI/libs/EDI.so").write_bytes(b"x" * 4096)
        Path(f"{d}/check/EDI.Rcheck/00check.log").write_text(LOG)
        b.main(["collect", "--check-dir", f"{d}/check", "--leg", "ubuntu-release", "--commit", "abc",
                "--check-seconds", "1700", "--out", f"{d}/out/r.json"])
        r = json.load(open(f"{d}/out/r.json"))
        self.assertEqual(r["tarball_bytes"], 3000)
        self.assertEqual(r["installed_kb"], 4)
        self.assertEqual(r["tests_s"], 1440)
        self.assertEqual(r["check_s"], 1700)


class Judge(unittest.TestCase):
    now = dt.datetime(2026, 11, 17, tzinfo=dt.timezone.utc)

    def hist(self, leg, values, metric="tests_s", days_ago=1):
        return [{"leg": leg, "commit": f"c{i}", metric: v,
                 "at": (self.now - dt.timedelta(days=days_ago + i)).isoformat()} for i, v in enumerate(values)]

    def test_jump_over_median_is_a_breach(self):
        h = self.hist("u", [1000] * 6)
        _, br = b.judge([{"leg": "u", "commit": "new", "tests_s": 1300}], h, self.now)
        self.assertEqual(len(br), 1)
        self.assertIn("+30%", br[0]["verdict"])

    def test_small_rise_and_floor(self):
        h = self.hist("u", [100] * 6, metric="install_s")
        _, br = b.judge([{"leg": "u", "commit": "new", "install_s": 150}], h, self.now)
        self.assertEqual(br, [])  # +50% but only 50 s, under the 60 s floor

    def test_too_little_history_judges_no_jump(self):
        h = self.hist("u", [1000] * 3)
        rows, br = b.judge([{"leg": "u", "commit": "new", "tests_s": 5000}], h, self.now)
        self.assertEqual(br, [])
        self.assertIsNone(rows[0]["median"])

    def test_old_history_and_other_legs_ignored(self):
        h = self.hist("u", [1000] * 6, days_ago=60) + self.hist("w", [1000] * 6)
        _, br = b.judge([{"leg": "u", "commit": "new", "tests_s": 5000}], h, self.now)
        self.assertEqual(br, [])

    def test_tarball_limits(self):
        _, br = b.judge([{"leg": "u", "commit": "n", "tarball_bytes": 4 * b.MB + 1}], [], self.now)
        self.assertIn("4 MB", br[0]["verdict"])
        _, br = b.judge([{"leg": "u", "commit": "n", "tarball_bytes": 5 * b.MB}], [], self.now)
        self.assertIn("5 MB", br[0]["verdict"])

    def test_rerun_of_same_commit_is_not_its_own_baseline(self):
        h = [{"leg": "u", "commit": "same", "tests_s": 1000,
              "at": (self.now - dt.timedelta(days=1)).isoformat()}] * 6
        rows, _ = b.judge([{"leg": "u", "commit": "same", "tests_s": 1000}], h, self.now)
        self.assertIsNone(rows[0]["median"])


class Report(unittest.TestCase):
    def test_report_writes_markdown_history_and_output(self):
        d = tempfile.mkdtemp()
        os.makedirs(f"{d}/rec/a")
        json.dump({"leg": "u", "commit": "abcdef12", "at": "2026-11-17T00:00:00+00:00",
                   "tarball_bytes": 5 * b.MB},
                  open(f"{d}/rec/a/r.json", "w"))
        b.main(["report", "--records", f"{d}/rec", "--history", f"{d}/h/history.jsonl", "--append-history",
                "--now", "2026-11-17T00:00:00+00:00", "--out", f"{d}/r.md", "--github-output", f"{d}/o"])
        self.assertIn("over CRAN's 5 MB limit", Path(f"{d}/r.md").read_text())
        self.assertIn("breach=true", Path(f"{d}/o").read_text())
        hist = [json.loads(x) for x in Path(f"{d}/h/history.jsonl").read_text().splitlines()]
        self.assertEqual(len(hist), 1)
        self.assertEqual(hist[0]["leg"], "u")


class Slowest(unittest.TestCase):
    def test_slowest_and_over_estimate(self):
        d = tempfile.mkdtemp()
        os.makedirs(f"{d}/t/correctness-shard-1"); os.makedirs(f"{d}/t/correctness-shard-2")
        Path(f"{d}/t/correctness-shard-1/timings.csv").write_text(
            "test_file,runtime_tier,elapsed_seconds,status\n"
            "a/test-big.R,correctness,300,passed\na/test-small.R,correctness,2,passed\n")
        Path(f"{d}/t/correctness-shard-2/timings.csv").write_text(
            "test_file,runtime_tier,elapsed_seconds,status\n"
            "a/test-grew.R,correctness,120,passed\na/test-hung.R,correctness,NA,running\n")
        Path(f"{d}/est.csv").write_text(
            "test_file,runtime_tier,estimated_seconds,estimate_source\n"
            "a/test-big.R,correctness,400,m\na/test-small.R,correctness,1,m\na/test-grew.R,correctness,60,m\n")
        b.main(["slowest", "--timings", f"{d}/t", "--estimates", f"{d}/est.csv", "--top", "2",
                "--out", f"{d}/s.md", "--github-output", f"{d}/o"])
        md = Path(f"{d}/s.md").read_text()
        self.assertIn("3 test files", md)                     # the unfinished row is left out
        self.assertLess(md.index("test-big.R"), md.index("test-grew.R"))
        over = md.split("### Over their estimate")[1]
        self.assertIn("test-grew.R", over)                    # 120 s vs 60 s
        self.assertNotIn("test-small.R", over)                # 1 s over: under the floor
        self.assertNotIn("test-big.R", over)
        self.assertIn("over=1", Path(f"{d}/o").read_text())


if __name__ == "__main__":
    unittest.main(verbosity=1)
