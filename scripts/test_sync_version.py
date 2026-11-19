"""Tests for scripts/sync_version.py (DESCRIPTION is the single version source, owner 2026-11-19)."""
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import sync_version as sv  # noqa: E402


class SyncVersion(unittest.TestCase):
    def setUp(self):
        self.root = Path(tempfile.mkdtemp())
        files = {
            "R/EDI/DESCRIPTION": "Package: EDI\nVersion: 1.0.4\n",
            "CITATION.cff": 'cff-version: 1.2.0\nversion: 1.0.2\npreferred-citation:\n  version: 1.0.0\n',
            "codemeta.json": '{\n  "name": "EDI",\n  "version": "1.0.2",\n  "x": {"version": "9"}\n}\n',
            "python/pyproject.toml": '[build-system]\nrequires = []\n\n[project]\nname = "edi_kernels"\nversion = "1.0.4.post2"\n',
            "R/EDI/inst/CITATION": 'note = "R package version 1.0.1"\n',
            "python/README.md": "@software{x,\n  version = {1.0.5},\n}\n",
        }
        for p, t in files.items():
            (self.root / p).parent.mkdir(parents=True, exist_ok=True)
            (self.root / p).write_text(t)

    def read(self, p):
        return (self.root / p).read_text()

    def test_check_then_sync(self):
        v, stale = sv.sync(self.root, check=True)
        self.assertEqual(v, "1.0.4")
        self.assertEqual(sorted(stale), ["CITATION.cff", "R/EDI/inst/CITATION", "codemeta.json", "python/README.md"])
        self.assertIn("version: 1.0.2", self.read("CITATION.cff"))        # --check writes nothing
        sv.sync(self.root)
        self.assertIn("\nversion: 1.0.4\n", self.read("CITATION.cff"))
        self.assertIn("  version: 1.0.0", self.read("CITATION.cff"))      # preferred-citation untouched
        self.assertIn('"version": "1.0.4"', self.read("codemeta.json"))
        self.assertIn('"version": "9"', self.read("codemeta.json"))
        self.assertIn('version = "1.0.4.post2"', self.read("python/pyproject.toml"))  # .postN kept
        self.assertIn("R package version 1.0.4", self.read("R/EDI/inst/CITATION"))
        self.assertIn("version = {1.0.4}", self.read("python/README.md"))
        self.assertEqual(sv.sync(self.root, check=True)[1], [])

    def test_post_suffix_dropped_on_a_real_bump(self):
        (self.root / "R/EDI/DESCRIPTION").write_text("Version: 1.0.5\n")
        sv.sync(self.root)
        self.assertIn('version = "1.0.5"', self.read("python/pyproject.toml"))


if __name__ == "__main__":
    unittest.main()
