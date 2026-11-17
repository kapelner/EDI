#!/usr/bin/env python3
"""Tests for audits/ci_self_check.py with a fake GitHub API. No network, no gh. Stdlib only."""
import datetime as dt
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).parent))
from audits import ci_self_check as cs  # noqa: E402

NOW = dt.datetime(2026, 11, 20, 6, tzinfo=dt.timezone.utc)
REPO = "owner/repo"


def iso(d):
    return d.strftime("%Y-%m-%dT%H:%M:%SZ")


def run(day_offset, minutes, n=0):
    start = NOW - dt.timedelta(days=day_offset)
    return {"id": n, "created_at": iso(start), "run_started_at": iso(start),
            "updated_at": iso(start + dt.timedelta(minutes=minutes)), "html_url": f"https://x/runs/{n}"}


class FakeApi:
    def __init__(self, routes, fail=()):
        self.routes, self.fail, self.calls = routes, fail, []

    def __call__(self, path):
        self.calls.append(path)
        for prefix in self.fail:
            if path.startswith(prefix):
                raise cs.ApiError(f"gh api {path}: HTTP 404")
        for prefix, value in self.routes.items():
            if path.startswith(prefix):
                return value
        raise cs.ApiError(f"gh api {path}: HTTP 404 (no route)")


class Ctx:
    def __init__(self, repo):
        self.repo, self.now = Path(repo), NOW


def make_workflows(files):
    d = Path(tempfile.mkdtemp())
    (d / ".github" / "workflows").mkdir(parents=True)
    for name, text in files.items():
        (d / ".github" / "workflows" / name).write_text(text)
    return d


WF = """on: push
jobs:
  a:
    steps:
      - uses: actions/checkout@v4
      - uses: r-lib/actions/setup-r@v2
      - uses: "actions/cache@v5"   # current
      - uses: ./.github/actions/local
      - uses: docker://alpine:3
      - uses: some/pinned@0123456789abcdef0123456789abcdef01234567
      - uses: pypa/gh-action-pypi-publish@release/v1
  b:
    uses: ./.github/workflows/audit.yml
"""


class Actions(unittest.TestCase):
    def test_pins(self):
        repo = make_workflows({"a.yml": WF, "b.yaml": "steps:\n  - uses: actions/checkout@v4.1.0\n",
                               "notes.txt": "uses: x/y@v1\n"})
        pins = cs.action_pins(repo)
        self.assertEqual(pins[("actions/checkout", 4)], ["a.yml", "b.yaml"])
        self.assertIn(("r-lib/actions", 2), pins)                      # sub-path action -> its repo
        self.assertIn(("pypa/gh-action-pypi-publish", 1), pins)
        self.assertNotIn("some/pinned", {a for a, _ in pins})          # SHA pins skipped
        self.assertFalse(any(a.startswith(".") or a.startswith("docker") for a, _ in pins))
        self.assertNotIn("x/y", {a for a, _ in pins})                  # only workflow files

    def test_behind_latest_major(self):
        repo = make_workflows({"a.yml": WF})
        api = FakeApi({"repos/actions/checkout/releases/latest": {"tag_name": "v7.0.1"},
                       "repos/r-lib/actions/releases/latest": {"tag_name": "v2.11.3"},
                       "repos/actions/cache/releases/latest": {"tag_name": "v5.0.0"},
                       "repos/pypa/gh-action-pypi-publish/tags": [{"name": "v1.13.0"}, {"name": "release/v1"}]},
                      fail=("repos/pypa/gh-action-pypi-publish/releases",))
        f = cs.check_actions(api, repo)
        self.assertEqual([x["unit"] for x in f], ["action:actions/checkout@v4"])
        self.assertIn("latest major v7", f[0]["text"])
        self.assertEqual(sum("r-lib/actions" in c for c in api.calls), 1)   # one lookup per action repo

    def test_api_error_is_reported(self):
        repo = make_workflows({"a.yml": "- uses: gone/action@v1\n"})
        f = cs.check_actions(FakeApi({}, fail=("repos/gone",)), repo)
        self.assertEqual(f[0]["kind"], "api-error")


class Workflows(unittest.TestCase):
    def api(self, runs):
        return FakeApi({
            f"repos/{REPO}/actions/workflows/1/runs": {"workflow_runs": runs},
            f"repos/{REPO}/actions/workflows/2/runs": {"workflow_runs": []},
            f"repos/{REPO}/actions/workflows?": {"workflows": [
                {"id": 1, "path": ".github/workflows/nightly.yml", "name": "nightly", "state": "active"},
                {"id": 2, "path": ".github/workflows/old.yml", "name": "old", "state": "disabled_inactivity"},
                {"id": 3, "path": ".github/workflows/off.yml", "name": "off", "state": "disabled_manually"}]}})

    def test_disabled_and_slow(self):
        runs = [run(d, 20, d) for d in (40, 30, 20, 10)] + [run(1, 45, 99)]
        f = cs.check_workflows(self.api(runs), REPO, NOW)
        kinds = {x["unit"]: x["kind"] for x in f}
        self.assertEqual(kinds, {"workflow:.github/workflows/old.yml": "disabled",
                                 "runtime:.github/workflows/nightly.yml": "slow-run"})
        slow = [x for x in f if x["kind"] == "slow-run"][0]["text"]
        self.assertIn("45 min", slow)
        self.assertIn("median of 20 min", slow)
        self.assertIn("runs/99", slow)

    def test_not_slow_within_50_percent(self):
        runs = [run(d, 20, d) for d in (40, 30, 20, 10)] + [run(1, 29, 99)]
        self.assertIsNone(cs.slow_run("x", runs))

    def test_short_jobs_need_a_real_slowdown(self):
        runs = [{**run(d, 0, d), "updated_at": iso(NOW - dt.timedelta(days=d) + dt.timedelta(seconds=40))}
                for d in (40, 30, 20, 10, 1)]
        runs[-1]["updated_at"] = iso(NOW - dt.timedelta(days=1) + dt.timedelta(seconds=90))
        self.assertIsNone(cs.slow_run("x", runs))                     # 2.2x but only 50 s longer

    def test_too_few_runs(self):
        self.assertIsNone(cs.slow_run("x", [run(10, 10), run(1, 100)]))

    def test_latest_is_the_newest_run_whatever_the_order(self):
        runs = [run(1, 45, 99)] + [run(d, 20, d) for d in (10, 20, 30, 40)]
        self.assertIsNotNone(cs.slow_run("x", runs))


class Stale(unittest.TestCase):
    def test_bot_prs_and_branches(self):
        old, new = iso(NOW - dt.timedelta(days=40)), iso(NOW - dt.timedelta(days=3))
        api = FakeApi({
            f"repos/{REPO}/pulls": [
                {"number": 5, "created_at": old, "user": {"login": "github-actions[bot]", "type": "Bot"},
                 "head": {"ref": "audit/rd"}},
                {"number": 6, "created_at": old, "user": {"login": "someone", "type": "User"},
                 "head": {"ref": "feature/x"}},
                {"number": 7, "created_at": new, "user": {"login": "dependabot[bot]", "type": "Bot"},
                 "head": {"ref": "dependabot/x"}},
                {"number": 8, "created_at": old, "user": {"login": "owner", "type": "User"},
                 "head": {"ref": "algorithm-research/2026-10"}}],
            f"repos/{REPO}/branches": [
                {"name": "main", "commit": {"sha": "m"}},
                {"name": "audit/rd", "commit": {"sha": "a"}},
                {"name": "audit/old", "commit": {"sha": "b"}},
                {"name": "algorithm-research/fresh", "commit": {"sha": "c"}}],
            f"repos/{REPO}/commits/b": {"commit": {"committer": {"date": old}}},
            f"repos/{REPO}/commits/c": {"commit": {"committer": {"date": new}}}})
        f = cs.check_stale(api, REPO, NOW)
        self.assertEqual([x["unit"] for x in f], ["pr:5", "pr:8", "branch:audit/old"])
        self.assertFalse(any("commits/a" in c for c in api.calls))    # branch with an open PR not re-read

    def test_text_is_stable_week_to_week(self):
        old = iso(NOW - dt.timedelta(days=40))
        routes = {f"repos/{REPO}/pulls": [{"number": 5, "created_at": old, "user": {"type": "Bot", "login": "b"},
                                           "head": {"ref": "audit/rd"}}], f"repos/{REPO}/branches": []}
        a = cs.check_stale(FakeApi(routes), REPO, NOW)
        b = cs.check_stale(FakeApi(routes), REPO, NOW + dt.timedelta(weeks=1))
        self.assertEqual(a, b)


class Mechanical(unittest.TestCase):
    def test_failures_are_findings_not_clean(self):
        repo = make_workflows({"a.yml": "- uses: actions/checkout@v7\n"})
        with mock.patch.dict("os.environ", {"GITHUB_REPOSITORY": REPO}):
            f = cs.mechanical(Ctx(repo), api=FakeApi(
                {"repos/actions/checkout/releases/latest": {"tag_name": "v7.0.0"}},
                fail=(f"repos/{REPO}",)))
        self.assertEqual({x["kind"] for x in f}, {"not-run"})
        self.assertEqual(len(f), 2)
        parts = cs.apply(None, [], f)
        self.assertIn("2 not-run", parts["summary"])

    def test_paginated_output_is_merged(self):
        pages = '[{"a": 1}]\n[{"a": 2}]'
        proc = mock.Mock(returncode=0, stdout=pages, stderr="")
        with mock.patch.object(cs.subprocess, "run", return_value=proc):
            self.assertEqual(cs.gh_api("x"), [{"a": 1}, {"a": 2}])
        proc.stdout = json.dumps({"workflows": [1]}) + json.dumps({"workflows": [2], "total_count": 2})
        with mock.patch.object(cs.subprocess, "run", return_value=proc):
            self.assertEqual(cs.gh_api("x"), {"workflows": [1, 2], "total_count": 2})

    def test_real_workflows_parse(self):
        root = Path(__file__).parents[2]
        if (root / ".github" / "workflows").exists():
            pins = cs.action_pins(root)
            self.assertIn("actions/checkout", {a for a, _ in pins})


if __name__ == "__main__":
    unittest.main(verbosity=1)
