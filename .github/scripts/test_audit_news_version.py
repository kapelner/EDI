#!/usr/bin/env python3
"""Checks for the NEWS and version consistency audit (.github/scripts/audits/news_version.py). Stdlib only."""
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import audit_common as ac  # noqa: E402
from audits import news_version as nv  # noqa: E402

FILES = {
    "R/EDI/DESCRIPTION": "Package: EDI\nVersion: 1.0.4\n",
    "R/EDI/NEWS.md": "# EDI 1.0.4\n\n## Bug fixes\n\n* `InferenceFoo` fixed.\n\n# EDI 1.0.2\n\n* old.\n",
    "R/EDI/inst/CITATION": 'note = sprintf("R package version %s", meta$Version)\n',
    "python/pyproject.toml": '[build-system]\nrequires = ["x"]\n\n[project]\nname = "edi_kernels"\nversion = "1.0.4.post2"\n'
                             '\n[tool.x]\nminimum-version = "1.0"\n',
    "python/CHANGELOG.md": "# Changelog\n\n## [1.0.4] - Unreleased\n\n## [1.0.2]\n",
    "python/CITATION.cff": "cff-version: 1.2.0\nversion: 1.0.5\npreferred-citation:\n  version: 1.0.0\n",
    "CITATION.cff": 'cff-version: 1.2.0\nversion: "1.0.4"\n',
    "codemeta.json": '{"name": "EDI", "version": "1.0.2"}\n',
    "python/README.md": "```bibtex\n@software{x,\n  version = {1.0.4},\n}\n```\n",
    "R/EDI/R/foo.R": "x = 1\n",
}


class NewsVersion(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.repo = self.tmp / "repo"
        for p, t in FILES.items():
            (self.repo / p).parent.mkdir(parents=True, exist_ok=True)
            (self.repo / p).write_text(t)
        self.git("init", "-q", "-b", "main")
        self.git("config", "user.email", "t@t")
        self.git("config", "user.name", "t")
        self.git("add", "-A")
        self.git("commit", "-qm", "release")
        self.git("tag", "v1.0.4")
        self.git("tag", "py-v1.0.9")                     # Python tags are not release tags
        spec = ac.spec_of(nv)
        (self.tmp / "work").mkdir()
        self.ctx = ac.Context(spec, self.repo, ac.Notes(self.tmp / "notes", spec["name"]), self.tmp / "work")

    def git(self, *a):
        return subprocess.run(["git", *a], cwd=self.repo, check=True, capture_output=True, text=True).stdout

    def commit(self, path, text, msg):
        (self.repo / path).parent.mkdir(parents=True, exist_ok=True)
        (self.repo / path).write_text(text)
        self.git("add", "-A")
        self.git("commit", "-qm", msg)
        return self.git("rev-parse", "--short", "HEAD").strip()

    def test_versions(self):
        m = {(f["unit"], f["kind"]) for f in nv.mechanical(self.ctx)}
        self.assertEqual(m, {("python/CITATION.cff", "version-mismatch"), ("codemeta.json", "version-mismatch")})
        self.assertEqual(nv.core("1.0.4.post2"), (1, 0, 4))
        self.assertEqual(nv.core("1.0.4.9000"), (1, 0, 4))
        self.assertEqual(nv.last_release_tag(self.repo), ("v1.0.4", (1, 0, 4)))

    def test_behind_tag_and_news(self):
        self.git("tag", "v1.0.5")
        sha = self.commit("R/EDI/src/k.cpp", "int k;\n", "fix kernel")
        m = {f["kind"]: f["text"] for f in nv.mechanical(self.ctx)}
        self.assertIn("behind-tag", m)
        self.assertNotIn("version-behind", m)                    # NEWS top equals DESCRIPTION
        self.assertIn("no-section-after-tag", m)
        self.assertIn("1 commit(s)", m["no-section-after-tag"])
        self.assertTrue(sha)

    def test_units_are_code_commits_since_the_tag(self):
        a = self.commit("R/EDI/R/foo.R", "x = 2\n", "change the default of foo")
        self.commit("README.md", "docs\n", "docs only")
        b = self.commit("R/EDI/src/k.cpp", "int k;\n", "kernel fix\n\nlonger body")
        u = nv.units(self.ctx)
        self.assertEqual(sorted(u), sorted([f"commit:{a}", f"commit:{b}"]))
        c = u[f"commit:{b}"]["context"]
        self.assertEqual(c["body"], "longer body")
        self.assertIn("R/EDI/src/k.cpp", c["diffstat"])
        self.assertTrue((self.tmp / "work/news_commits" / f"{b}.diff").exists())
        self.assertIn("# EDI 1.0.4", (self.tmp / "work/news_top.md").read_text())
        self.assertNotIn("# EDI 1.0.2", (self.tmp / "work/news_top.md").read_text())
        deps = u[f"commit:{a}"]["deps"]
        self.commit("R/EDI/NEWS.md", "# EDI 1.0.5\n\n* new.\n\n" + FILES["R/EDI/NEWS.md"], "news")
        self.assertNotEqual(nv.units(self.ctx)[f"commit:{a}"]["deps"], deps)   # a NEWS edit re-checks all

    def test_apply_never_edits(self):
        before = (self.repo / "R/EDI/NEWS.md").read_text()
        res = [{"_units": ["commit:a", "commit:b", "commit:c"], "findings": [
            {"unit": "commit:a", "kind": "missing", "text": "Default changed.", "news_section": "Breaking changes",
             "news_line": "* `foo()` now defaults to 2."},
            {"unit": "commit:b", "kind": "covered", "text": "In NEWS.", "news_section": "", "news_line": ""},
            {"unit": "commit:c", "kind": "unclear", "text": "Hard to say.", "news_section": "", "news_line": ""},
            {"unit": "commit:zzz", "kind": "missing", "text": "not in the batch", "news_section": "", "news_line": ""}]}]
        parts = nv.apply(self.ctx, res, [])
        self.assertEqual((self.repo / "R/EDI/NEWS.md").read_text(), before)
        self.assertEqual(parts["applied"], [])
        self.assertEqual(len(ac.texts(parts["human"])), 2)
        self.assertIn("`foo()` now defaults to 2.", ac.texts(parts["human"])[0])
        self.assertIn("1 covered", parts["summary"])


if __name__ == "__main__":
    unittest.main(verbosity=1)
