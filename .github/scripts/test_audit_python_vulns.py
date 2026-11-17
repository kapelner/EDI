#!/usr/bin/env python3
"""Tests for audits/python_vulns.py with saved pip-audit JSON. No network. Stdlib only."""
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).parent))
import audit_common as ac  # noqa: E402
from audits import python_vulns as pv  # noqa: E402

PYPROJECT = '''[build-system]
requires = [
    "scikit-build-core>=1.0",
    "pybind11>=2.13",
]
build-backend = "scikit_build_core.build"

[project]
name = "edi_kernels"
version = "1.0.4"
dependencies = [
    "numpy>=1.24",
    "scipy-openblas32; platform_machine == 'x86_64'",
]
[project.optional-dependencies]
test = ["pytest>=7.0", "scipy>=1.10", "numpy>=1.24"]
'''

AUDIT_JSON = json.dumps({"dependencies": [
    {"name": "numpy", "version": "2.3.1", "vulns": []},
    {"name": "requests", "version": "2.31.0", "vulns": [
        {"id": "GHSA-9wx4-h78v-vm56", "fix_versions": ["2.32.0"], "aliases": ["CVE-2024-35195"],
         "description": "..."},
        {"id": "PYSEC-2024-1", "fix_versions": ["2.32.4"], "aliases": [], "description": "..."}]},
    {"name": "Jinja2", "version": "3.1.2", "vulns": [
        {"id": "GHSA-h5c8-rqwp-cp95", "fix_versions": [], "aliases": ["CVE-2024-22195"]}]},
    {"name": "edi-kernels", "skip_reason": "could not be audited: not on PyPI"},
], "fixes": []})


class Ctx:
    def __init__(self, repo, work):
        self.repo, self.workdir = Path(repo), Path(work)

    def read(self, rel):
        p = self.repo / rel
        return p.read_text() if p.exists() else None


def make_repo(files):
    d = Path(tempfile.mkdtemp())
    run = lambda *a: subprocess.run(["git", *a], cwd=d, check=True, capture_output=True)
    run("init", "-q")
    for rel, text in files.items():
        (d / rel).parent.mkdir(parents=True, exist_ok=True)
        (d / rel).write_text(text)
    run("add", "-A")
    return d


class Requirements(unittest.TestCase):
    def test_pyproject_all_groups_deduplicated(self):
        r = pv.pyproject_requirements(PYPROJECT)
        self.assertEqual(r, ["scikit-build-core>=1.0", "pybind11>=2.13", "numpy>=1.24",
                             "scipy-openblas32; platform_machine == 'x86_64'", "pytest>=7.0", "scipy>=1.10"])

    def test_fallback_parser_without_tomllib(self):
        with mock.patch.object(pv, "_toml_load", return_value=None):
            r = pv.pyproject_requirements(PYPROJECT)
        self.assertEqual(set(r), {"scikit-build-core>=1.0", "pybind11>=2.13", "numpy>=1.24",
                                  "scipy-openblas32; platform_machine == 'x86_64'", "pytest>=7.0", "scipy>=1.10"})

    def test_requirements_files_are_added(self):
        repo = make_repo({"python/pyproject.toml": PYPROJECT,
                          "python/docs/requirements-docs.txt": "sphinx>=7  # docs\n-r other.txt\n\nnumpy>=1.24\n",
                          "python/.venv/lib/requirements.txt": "ignored==1\n"})
        reqs, sources = pv.collect(Ctx(repo, repo / "w"))
        self.assertIn("sphinx>=7", reqs)
        self.assertEqual(reqs.count("numpy>=1.24"), 1)
        self.assertEqual(sources, ["python/pyproject.toml", "python/docs/requirements-docs.txt"])
        self.assertNotIn("ignored==1", reqs)

    def test_real_pyproject_parses(self):
        real = Path(__file__).parents[2] / pv.PYPROJECT
        if real.exists():
            r = pv.pyproject_requirements(real.read_text())
            self.assertTrue(any(x.startswith("numpy") for x in r))


class Parse(unittest.TestCase):
    def test_one_finding_per_vulnerable_package(self):
        f = pv.findings_from_audit(pv.parse_pip_audit(AUDIT_JSON))
        self.assertEqual([x["unit"] for x in f], ["Jinja2", "requests"])
        req = f[1]["text"]
        self.assertIn("GHSA-9wx4-h78v-vm56 (CVE-2024-35195)", req)
        self.assertIn("PYSEC-2024-1", req)
        self.assertIn("Fixed in: 2.32.0, 2.32.4.", req)
        self.assertIn("Fixed in: none published.", f[0]["text"])

    def test_old_list_layout(self):
        old = json.dumps([{"name": "x", "version": "1", "vulns": [{"id": "PYSEC-1", "fix_versions": ["2"]}]}])
        self.assertEqual(pv.parse_pip_audit(old)[0]["vulns"][0]["id"], "PYSEC-1")

    def test_clean(self):
        self.assertEqual(pv.parse_pip_audit(json.dumps({"dependencies": [{"name": "a", "version": "1",
                                                                          "vulns": []}]})), [])


class Mechanical(unittest.TestCase):
    def setUp(self):
        self.repo = make_repo({"python/pyproject.toml": PYPROJECT})
        self.ctx = Ctx(self.repo, self.repo.parent / (self.repo.name + "-work"))

    def test_vulnerable(self):
        with mock.patch.object(pv, "run_pip_audit", return_value=(1, AUDIT_JSON, "")) as m:
            f = pv.mechanical(self.ctx)
        req_file = m.call_args[0][0]
        self.assertTrue(str(req_file).startswith(str(self.ctx.workdir)))   # scratch only in the work dir
        self.assertIn("numpy>=1.24", Path(req_file).read_text())
        self.assertEqual(len(f), 2)
        self.assertIn("2 vulnerable", pv.apply(self.ctx, [], f)["summary"])

    def test_pip_audit_failure_is_a_finding(self):
        with mock.patch.object(pv, "run_pip_audit", return_value=(2, "", "ResolutionImpossible\nboom")):
            f = pv.mechanical(self.ctx)
        self.assertEqual(f[0]["kind"], "not-run")
        self.assertIn("boom", f[0]["text"])

    def test_missing_tool(self):
        with mock.patch.object(pv, "run_pip_audit", return_value=(127, "", "No such file")):
            self.assertEqual(pv.mechanical(self.ctx)[0]["kind"], "not-run")

    def test_clean_run(self):
        with mock.patch.object(pv, "run_pip_audit", return_value=(0, '{"dependencies": []}', "")):
            f = pv.mechanical(self.ctx)
        self.assertEqual(f, [])
        self.assertFalse(ac.has_findings(pv.apply(self.ctx, [], f)))

    def test_no_pyproject(self):
        repo = make_repo({"README.md": "x"})
        f = pv.mechanical(Ctx(repo, repo / "w"))
        self.assertEqual(f[0]["kind"], "no-dependencies")


if __name__ == "__main__":
    unittest.main(verbosity=1)
