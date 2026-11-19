#!/usr/bin/env python3
"""Checks for the open-decisions list (audit_decisions.py). Stdlib only, no network."""
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import audit_common as ac  # noqa: E402
import audit_decisions as ad  # noqa: E402


def rec(text, first="2026-11-17T10:00:00+00:00"):
    return {"text": text, "first_seen": first, "last_seen": first, "unit": None, "key": None}


class Repo(unittest.TestCase):
    """A checkout whose `audit-notes` branch holds two audits' decisions_open.json."""

    def setUp(self):
        self.repo = Path(tempfile.mkdtemp())
        run = lambda *a: subprocess.run(["git", *a], cwd=self.repo, check=True, capture_output=True)
        run("init", "-q", "-b", "main")
        run("config", "user.email", "t@example.com")
        run("config", "user.name", "t")
        rel = self.repo / "R/package_metadata/future_release_plans/release_v1_0_6.md"
        rel.parent.mkdir(parents=True)
        rel.write_text("# v1.0.6\n\n- [ ] **TODO-1** fix the page (audit decision rd-d00000002)\n"
                       "- [x] **TODO-2** done (audit decision rd-d00000003)\n"
                       "- [ ] TODO-3 docs gap (ds-designs-77-f2)\n")
        dis = self.repo / ac.DISMISSED_FILE
        dis.parent.mkdir(parents=True)
        dis.write_text("# Dismissed\n\n- `rd-d00000004`: the docs are right (2026-11-18)\n"
                       "- `rd-m00000004`: intended (2026-11-19)\n"
                       "- `ds-designs-77-f3`: not a docs gap (2026-11-19)\n")
        run("add", "-A")
        run("commit", "-qm", "main")
        run("checkout", "-q", "--orphan", "audit-notes")
        run("rm", "-rqf", ".")
        for audit, recs in {
            "rd": {"rd-d00000001": rec("`A.Rd` (unclear): first\nsecond line", "2026-11-18T00:00:00+00:00"),
                   "rd-d00000002": rec("cited"), "rd-d00000003": rec("cited by a done TODO"),
                   "rd-d00000004": rec("dismissed")},
            "news-version": {"news-version-d00000005": rec("NEWS gap")},
            "privacy": {},
        }.items():
            (self.repo / audit).mkdir()
            (self.repo / audit / "decisions_open.json").write_text(json.dumps(recs))
        (self.repo / "rd" / "mechanical_open.json").write_text(json.dumps({
            "rd-m00000011": rec("`B.Rd`: checkRd: title ends in a period"), "rd-m00000004": rec("dismissed")}))
        (self.repo / "docs-scenarios").mkdir()
        (self.repo / "docs-scenarios" / "findings.jsonl").write_text("".join(json.dumps(
            {"id": f"ds-designs-77-f{n}", "area": "designs", "title": f"gap {n}", "kind": "docs-gap",
             "date": "2026-11-16", "status": "open"}) + "\n" for n in (1, 2, 3)))
        run("add", "-A")
        run("commit", "-qm", "notes")
        run("update-ref", "refs/remotes/origin/audit-notes", "HEAD")
        run("checkout", "-q", "main")

    def test_select_and_render(self):
        by = ad.load_open(self.repo)
        self.assertEqual(set(by), {"rd", "news-version", "privacy"})
        sel, counts = ad.select(by, ac.cited_decisions(self.repo), ac.dismissed_decisions(self.repo))
        self.assertEqual(counts, {"cited": 1, "dismissed": 1})
        self.assertEqual(list(sel), ["news-version", "rd"])            # empty audits left out, sorted
        self.assertEqual([d for d, _ in sel["rd"]], ["rd-d00000003", "rd-d00000001"])   # oldest first
        body = ad.render(sel, counts, "2026-11-18T09:00:00+00:00", "o/r")
        self.assertIn("**3 open decision(s)** across 2 audit(s); not listed: 1 cited by an open release TODO, "
                      "1 dismissed.", body)
        self.assertIn("- `rd-d00000001` · since 2026-11-18 · `A.Rd` (unclear): first\nsecond line", body)
        self.assertIn("blob/audit-notes/rd/decisions_open.json", body)
        self.assertIn("standing list, not a task", body)
        self.assertNotIn("rd-d00000002", body)
        self.assertNotIn("rd-d00000004", body)

    def test_mechanical_section(self):
        cited, dismissed = ac.cited_decisions(self.repo), ac.dismissed_decisions(self.repo)
        sel, counts = ad.select(ad.load_open(self.repo), cited, dismissed)
        mech, mcounts = ad.select(ad.load_open(self.repo, name="mechanical_open.json"), cited, dismissed)
        self.assertEqual(list(mech), ["rd"])
        body = ad.render(sel, counts, "2026-11-18T09:00:00+00:00", "o/r", mech=mech, mcounts=mcounts)
        self.assertIn("# Mechanical findings", body)
        self.assertIn("**1 open mechanical finding(s)** across 1 audit(s)", body)
        self.assertIn("- `rd-m00000011` · since 2026-11-17 · `B.Rd`: checkRd", body)
        self.assertIn("blob/audit-notes/rd/mechanical_open.json", body)
        self.assertIn("**3 open decision(s)**", body)          # decisions unchanged
        self.assertNotIn("rd-m00000004", body)                # dismissed
        self.assertIn("not listed: 1 dismissed", body)

    def test_docs_scenarios_section(self):
        docs, dcounts = ad.load_docs_scenarios(self.repo)
        self.assertEqual(list(docs["docs-scenarios"]), ["ds-designs-77-f1"])   # f2 filed, f3 dismissed
        self.assertEqual(dcounts, {"cited": 1, "dismissed": 1})
        body = ad.render({}, {}, "2026-11-18T09:00:00+00:00", "o/r", docs=docs, dcounts=dcounts)
        self.assertIn("# Docs-scenario findings", body)
        self.assertIn("- `ds-designs-77-f1` · since 2026-11-16 · [designs] docs-gap: gap 1", body)
        self.assertIn("not listed: 1 cited by a release TODO, 1 dismissed", body)

    def test_main_writes_out(self):
        out = self.repo / "out.md"
        ad.main(["--repo", "o/r", "--checkout", str(self.repo), "--out", str(out)])
        self.assertIn("news-version-d00000005", out.read_text())


class Fitting(unittest.TestCase):
    def test_long_lists_are_cut_to_fit(self):
        sel = {"rd": [(f"rd-d{i:08x}", rec("x " * 2000)) for i in range(60)]}
        body = ad.render_fitting(sel, {}, "2026-11-18T09:00:00+00:00", "o/r")
        self.assertLessEqual(len(body), ad.MAX_BODY)
        self.assertIn("Long items are cut at", body)
        self.assertEqual(body.count("- `rd-d"), 60)                     # every item still listed

    def test_short_lists_are_whole(self):
        sel = {"rd": [("rd-d00000001", rec("short"))]}
        self.assertNotIn("cut at", ad.render_fitting(sel, {}, "2026-11-18T09:00:00+00:00"))


if __name__ == "__main__":
    unittest.main(verbosity=1)
