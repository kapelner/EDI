#!/usr/bin/env python3
"""Checks for the generated-file drift audit (audits/generated_drift.py). Stdlib only, no R, no network."""
import datetime as dt
import re
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import audit_common as ac  # noqa: E402
from audits import generated_drift as gd  # noqa: E402

NOW = dt.datetime(2026, 11, 17, 7, tzinfo=dt.timezone.utc)


class Repo(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.repo = self.tmp / "repo"
        for d in ("R/EDI/man", "R/EDI/R", "R/EDI/src", "R/EDI/vignettes"):
            (self.repo / d).mkdir(parents=True)
        for i in range(20):
            (self.repo / f"R/EDI/man/topic{i}.Rd").write_text(f"\\name{{topic{i}}}\n")
        (self.repo / "R/EDI/NAMESPACE").write_text("export(a)\n")
        (self.repo / "R/EDI/R/RcppExports.R").write_text("a <- function() .Call(`_EDI_a`)\n")
        (self.repo / "R/EDI/src/RcppExports.cpp").write_text("// gen\n")
        (self.repo / "R/EDI/vignettes/procedure-trust.Rmd").write_text("x\n")
        (self.repo / "R/EDI/DESCRIPTION").write_text("Package: EDI\nVersion: 1\n")
        (self.repo / "R/EDI/R/code.R").write_text("f = 1\n")
        self.git("init", "-q", "-b", "main")
        self.git("config", "user.email", "t@t")
        self.git("config", "user.name", "t")
        self.git("add", "-A")
        self.git("commit", "-qm", "start")
        self.notes = ac.Notes(self.tmp / "notes", "generated-drift")
        self.ctx = ac.Context(ac.spec_of(gd), self.repo, self.notes, self.tmp / "work", now=NOW)
        self.saved = gd.run_generators, gd.roxygen_version
        gd.roxygen_version = lambda ctx: "9.9.9"

    def tearDown(self):
        gd.run_generators, gd.roxygen_version = self.saved

    def git(self, *a):
        return subprocess.run(["git", *a], cwd=self.repo, check=True, capture_output=True, text=True).stdout

    def generators(self, edits, logs=None, codes=None):
        def fake(ctx):
            for path, text in edits.items():
                p = ctx.repo / path
                if text is None:
                    p.unlink()
                else:
                    p.write_text(text)
            logs_ = logs or {}
            codes_ = codes or {}
            return {g: (codes_.get(g, 0), logs_.get(g, "")) for g in gd.GENERATORS}
        gd.run_generators = fake

    def test_clean(self):
        self.generators({})
        parts = gd.apply(self.ctx, [], [])
        self.assertEqual(parts["applied"], [])
        self.assertIn("matches what is committed", parts["summary"])

    def test_drift_is_proposed_and_strays_reverted(self):
        self.generators({
            "R/EDI/man/topic1.Rd": "\\name{topic1}\n\\title{New}\n",
            "R/EDI/man/new_topic.Rd": "\\name{new_topic}\n",
            "R/EDI/man/topic2.Rd": None,
            "R/EDI/R/RcppExports.R": "a <- function(x) .Call(`_EDI_a`, x)\n",
            "R/EDI/R/code.R": "f = 2\n",                       # no generator may write this
            "R/Rplots.pdf": "junk",
            "R/EDI/DESCRIPTION": "Package: EDI\nVersion: 1\nRoxygenNote: 9.9.9\n",
        }, logs={"roxygen": "Writing topic1.Rd\n✖ topic3.Rd: @param y not used\n"})
        parts = gd.apply(self.ctx, [], [])
        status = self.git("status", "--porcelain", "--untracked-files=all")
        self.assertNotIn("code.R", status)
        self.assertNotIn("Rplots", status)
        self.assertNotIn("DESCRIPTION", status)
        self.assertIn("topic1.Rd", status)
        self.assertEqual(len(parts["applied"]), 4)
        self.assertTrue(any("code.R" in h for h in ac.texts(parts["human"])))
        self.assertFalse(any("Rplots" in h and "DESCRIPTION" in h for h in ac.texts(parts["human"])))
        self.assertTrue(any("@param y" in m for m in parts["mechanical"]))
        self.assertIn("version line", parts["summary"])
        by = {p["unit"]: p for p in parts["proposed"]}
        self.assertEqual(by["R/EDI/man/topic1.Rd"]["applied_text"], "\\title{New}")
        self.assertEqual(by["R/EDI/man/new_topic.Rd"]["applied_text"], "\\name{new_topic}")
        self.assertNotIn("applied_file", by["R/EDI/man/topic2.Rd"])          # a deletion has no text to find
        for p in parts["proposed"]:
            if p.get("applied_file"):
                self.assertIn(p["applied_text"], (self.repo / p["applied_file"]).read_text())

    def test_roxygen8_version_line_is_left_out(self):
        # roxygen2 8 writes Config/roxygen2/version, not RoxygenNote
        self.generators({
            "R/EDI/man/topic1.Rd": "\\name{topic1}\n\\title{New}\n",
            "R/EDI/DESCRIPTION": "Package: EDI\nVersion: 1\nConfig/roxygen2/version: 9.9.9\n",
        })
        parts = gd.apply(self.ctx, [], [])
        status = self.git("status", "--porcelain", "--untracked-files=all")
        self.assertNotIn("DESCRIPTION", status)
        self.assertIn("topic1.Rd", status)
        self.assertIn("version line", parts["summary"])

    def test_failed_generator_is_not_applied(self):
        self.generators({"R/EDI/man/topic1.Rd": "half written\n", "R/EDI/vignettes/procedure-trust.Rmd": "y\n"},
                        logs={"roxygen": "Error in parse: bad\n"}, codes={"roxygen": 1})
        parts = gd.apply(self.ctx, [], [])
        self.assertEqual((self.repo / "R/EDI/man/topic1.Rd").read_text(), "\\name{topic1}\n")
        self.assertEqual([p["unit"] for p in parts["proposed"]], ["R/EDI/vignettes/procedure-trust.Rmd"])
        self.assertTrue(any("failed (exit 1)" in h for h in ac.texts(parts["human"])))

    def test_mass_rd_change_is_held_back(self):
        self.generators({f"R/EDI/man/topic{i}.Rd": f"% roxygen 9\n\\name{{topic{i}}}\n" for i in range(8)}
                        | {"R/EDI/NAMESPACE": "# new header\nexport(a)\n", "R/EDI/src/RcppExports.cpp": "// new\n"})
        parts = gd.apply(self.ctx, [], [])
        self.assertEqual([p["unit"] for p in parts["proposed"]], ["R/EDI/src/RcppExports.cpp"])
        self.assertTrue(any("roxygen2 9.9.9" in h and "8 of 20" in h for h in ac.texts(parts["human"])))
        self.assertNotIn("man/", self.git("status", "--porcelain"))

    def test_mass_rd_change_names_the_pinned_build(self):
        # v1.0.6-TODO-66: the report says which roxygen2 commit the runner was meant to install
        sha = "c9203b7f504b8d01cf29411f6166efa584e377d8"
        (self.repo / ".github/workflows").mkdir(parents=True)
        (self.repo / gd.AUDIT_WORKFLOW).write_text(f"env:\n  ROXYGEN2_REF: someone/roxygen2@{sha}\n")
        self.git("add", "-A")
        self.git("commit", "-qm", "pin")
        self.generators({f"R/EDI/man/topic{i}.Rd": f"% roxygen 9\n\\name{{topic{i}}}\n" for i in range(8)})
        parts = gd.apply(self.ctx, [], [])
        self.assertTrue(any(f"someone/roxygen2@{sha}" in h for h in ac.texts(parts["human"])))

    def test_rejected_output_is_not_proposed_again(self):
        edit = {"R/EDI/man/topic1.Rd": "\\name{topic1}\n\\title{New}\n"}
        self.generators(edit)
        first = gd.apply(self.ctx, [], [])
        f = ac.normalise_finding("generated-drift", first["proposed"][0], "mechanical")
        self.notes.save_findings([{**f, "status": "rejected"}])
        self.git("checkout", "--", ".")
        second = gd.apply(self.ctx, [], [])
        self.assertEqual(second["proposed"], [])
        self.assertEqual(self.git("status", "--porcelain"), "")
        self.assertIn("rejected before", second["summary"])
        # A different output from the generator is a new finding.
        self.generators({"R/EDI/man/topic1.Rd": "\\name{topic1}\n\\title{Newer}\n"})
        third = gd.apply(self.ctx, [], [])
        self.assertEqual(len(third["proposed"]), 1)

    def test_setup_leftovers_are_removed(self):
        (self.repo / "R/EDI/.github").mkdir()
        (self.repo / "R/EDI/.github/pkg.lock").write_text("{}")
        (self.repo / ".github").mkdir()
        (self.repo / ".github/R-version").write_text("4.5")
        self.generators({"R/EDI/man/topic1.Rd": "\\name{topic1}\n\\title{T}\n"})
        parts = gd.apply(self.ctx, [], [])
        self.assertEqual([p["unit"] for p in parts["proposed"]], ["R/EDI/man/topic1.Rd"])
        self.assertNotIn("pkg.lock", self.git("status", "--porcelain", "--untracked-files=all"))

    def test_dirty_tree_stops(self):
        (self.repo / "R/EDI/R/code.R").write_text("f = 3\n")
        self.generators({"R/EDI/man/topic1.Rd": "changed\n"})
        parts = gd.apply(self.ctx, [], [])
        self.assertIn("not clean", parts["summary"])
        self.assertEqual((self.repo / "R/EDI/man/topic1.Rd").read_text(), "\\name{topic1}\n")


class Helpers(unittest.TestCase):
    def test_owner_of(self):
        self.assertEqual(gd.owner_of("R/EDI/man/a.Rd"), "roxygen")
        self.assertIsNone(gd.owner_of("R/EDI/man/sub/a.Rd"))
        self.assertIsNone(gd.owner_of("R/EDI/man/a.Rd.orig"))
        self.assertEqual(gd.owner_of("R/EDI/vignettes/procedure-trust.Rmd"), "trust")
        self.assertIsNone(gd.owner_of("R/EDI/DESCRIPTION"))

    def test_log_warnings(self):
        lines, more = gd.log_warnings("ok\n✖ a.Rd: x\nWarning message:\nfine\n", limit=1)
        self.assertEqual(lines, ["✖ a.Rd: x"])
        self.assertEqual(more, 1)


    def test_pinned_roxygen2_ref(self):
        tmp = Path(tempfile.mkdtemp())
        self.assertIsNone(gd.pinned_roxygen2_ref(tmp))                        # no audit.yml
        (tmp / ".github/workflows").mkdir(parents=True)
        wf = tmp / gd.AUDIT_WORKFLOW
        wf.write_text("env:\n  ROXYGEN2_REF: r-lib/roxygen2@main\n")
        self.assertIsNone(gd.pinned_roxygen2_ref(tmp))                        # a branch is not a pin
        wf.write_text("env:\n  ROXYGEN2_REF: r-lib/roxygen2@" + "a" * 40 + "\n")
        self.assertEqual(gd.pinned_roxygen2_ref(tmp), "r-lib/roxygen2@" + "a" * 40)


class RoxygenPinInTheRealWorkflows(unittest.TestCase):
    """v1.0.6-TODO-66: the runner's roxygen2 is pinned by full commit SHA in one place (ROXYGEN2_REF in
    audit.yml), every roxygen2 install in the workflows goes through it, and the finish job checks the
    installed commit against it."""
    ROOT = Path(__file__).resolve().parents[2]

    def test_pin_is_a_full_sha(self):
        ref = gd.pinned_roxygen2_ref(self.ROOT)
        self.assertIsNotNone(ref, "ROXYGEN2_REF in .github/workflows/audit.yml must be <owner>/<repo>@<40-hex SHA>")
        self.assertRegex(ref, r"/roxygen2@[0-9a-f]{40}$")

    def test_every_roxygen2_install_uses_the_pin(self):
        text = (self.ROOT / gd.AUDIT_WORKFLOW).read_text()
        self.assertIn("${{ env.ROXYGEN2_REF }}", text)
        self.assertEqual(len(gd.ROXYGEN2_REF_LINE.findall(text)), 1)
        for wf in sorted((self.ROOT / ".github/workflows").glob("*.y*ml")):
            for n, line in enumerate(wf.read_text().splitlines(), 1):
                code = line.split("#", 1)[0]
                if re.search(r"roxygen2@|any::roxygen2|cran::roxygen2|install\.packages\([^)]*roxygen2", code) \
                        and not gd.ROXYGEN2_REF_LINE.match(line):
                    self.fail(f"{wf.name}:{n} installs roxygen2 without ROXYGEN2_REF: {line.strip()}")

    def test_finish_job_checks_the_installed_commit(self):
        text = (self.ROOT / gd.AUDIT_WORKFLOW).read_text()
        step = text.split("name: Check the roxygen2 pin", 1)[1].split("- name:", 1)[0]
        for needle in ("Config/roxygen2/version", "RemoteSha", "ROXYGEN2_REF"):
            self.assertIn(needle, step)


if __name__ == "__main__":
    unittest.main(verbosity=1)
