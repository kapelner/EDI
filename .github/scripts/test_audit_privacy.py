#!/usr/bin/env python3
"""Tests for audits/privacy.py. The key property: no term text ever reaches a finding, the
report, a batch file, the notes, the work dir or the log. No network. Stdlib only."""
import contextlib
import io
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).parent))
import audit_common as ac  # noqa: E402
import audit_run  # noqa: E402
from audits import privacy as pv  # noqa: E402

# Made-up terms; the test checks none of them leaks (case-insensitive).
TERMS_RAW = "# comment line, skipped\nZorblatt|person\n\nQuixley\nabc\nFrobnitz Labs|project\n"
TERMS = ["zorblatt", "quixley", "abc", "frobnitz labs"]

FILES = {
    "README.md": "Thanks to Zorblatt for the data.\nNothing here.\n",           # exact, term #1
    "R/EDI/R/a.R": "# by the Quixleyson group\nx = 1\ny = 2\n",                # partial, term #2
    "docs/notes.md": "line one\nwe met Quixlee at the abcdef meeting\nline three\n",  # near #2, short #3 masked
    "docs/zorblatt_notes.md": "plain text\n",                                  # term in a path (partial)
    "Frobnitz Labs.txt": "ok\n",                                               # exact phrase in a path
    "data/blob.bin": b"\0\1\2Zorblatt\0",                                      # binary: skipped
    "paper.md": "Work with frobnitz labs, and Zorblatt's notes.\n",            # phrase + possessive exact
}


def make_repo(files=FILES):
    d = Path(tempfile.mkdtemp())
    repo = d / "repo"
    repo.mkdir()
    run = lambda *a: subprocess.run(["git", *a], cwd=repo, check=True, capture_output=True)
    run("init", "-q", "-b", "main"); run("config", "user.email", "t@t"); run("config", "user.name", "t")
    for rel, text in files.items():
        p = repo / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_bytes(text if isinstance(text, bytes) else text.encode())
    run("add", "-A"); run("commit", "-qm", "x")
    return d, repo


def assert_no_terms(test, text, where):
    low = text.lower()
    for t in TERMS:
        if t == "abc":
            # "abc" is short; also check it is not left inside a masked word.
            test.assertNotIn("abcdef", low, where)
            continue
        test.assertNotIn(t, low, f"term text leaked into {where}")
    test.assertNotIn("quixleyson", low, where)
    test.assertNotIn("quixlee", low, where)


class Units(unittest.TestCase):
    def test_load_terms(self):
        t = pv.load_terms(TERMS_RAW)
        self.assertEqual([(x["n"], x["category"]) for x in t], [(1, "person"), (2, None), (3, None), (4, "project")])
        self.assertEqual(pv.load_terms(""), [])
        self.assertEqual(pv.load_terms("\n# only a comment\n"), [])

    def test_within_one_edit(self):
        e = pv.within_one_edit
        self.assertTrue(e("quixlee", "quixley"))      # substitution
        self.assertTrue(e("quixly", "quixley"))       # deletion
        self.assertTrue(e("quixleys", "quixley"))     # insertion
        self.assertTrue(e("quxiley", "quixley"))      # adjacent swap
        self.assertFalse(e("quixley", "quixley"))
        self.assertFalse(e("qiuxlee", "quixley"))

    def test_hit_kinds(self):
        sc = pv.Scanner(pv.load_terms(TERMS_RAW))
        kinds = lambda s: sorted((k, t["n"]) for k, t, _, _ in sc.hits(s))
        self.assertEqual(kinds("Zorblatt said"), [("exact", 1)])
        self.assertEqual(kinds("ZORBLATT's"), [("exact", 1)])          # case-insensitive
        self.assertEqual(kinds("Quixleyson"), [("partial", 2)])
        self.assertEqual(kinds("Quixlee"), [("near", 2)])
        self.assertEqual(kinds("abcdef"), [("masked", 3)])             # short: masked, not judged
        self.assertEqual(kinds("at frobnitz  labs"), [])               # phrase needs its exact spacing
        self.assertEqual(kinds("at Frobnitz Labs."), [("exact", 4)])
        self.assertEqual(sc.mask("by Quixleyson, abcdef and Zorblatt"), "by [TERM #2], [TERM #3] and [TERM #1]")


class Mechanical(unittest.TestCase):
    def ctx(self, repo, tmp):
        return ac.Context(ac.spec_of(pv), repo, ac.Notes(tmp / "notes", "privacy"), tmp / "work")

    def test_not_configured(self):
        tmp, repo = make_repo()
        with mock.patch.dict(os.environ, {pv.ENV: ""}):
            ctx = self.ctx(repo, tmp)
            f = pv.mechanical(ctx)
            self.assertEqual(pv.units(ctx), {})
        self.assertEqual([x["kind"] for x in f], ["not-configured"])
        self.assertIn("not configured", pv.apply(ctx, [], f)["mechanical"][0])

    def test_exact_and_borderline(self):
        tmp, repo = make_repo()
        with mock.patch.dict(os.environ, {pv.ENV: TERMS_RAW}):
            ctx = self.ctx(repo, tmp)
            f = pv.mechanical(ctx)
            u = pv.units(ctx)
        units = {x["unit"] for x in f}
        self.assertEqual(units, {"README.md:1", "paper.md:1", "[TERM #4].txt (file path)"})
        self.assertEqual(sorted(x["text"].split("term #")[1] for x in f if x["unit"] == "paper.md:1"),
                         ["1.", "4."])
        self.assertFalse(any("blob.bin" in x["unit"] for x in f))      # binary skipped
        self.assertEqual(set(u), {"R/EDI/R/a.R:1#term2", "docs/notes.md:2#term2",
                                  "docs/[TERM #1].md (file path)#term1"})
        a = u["R/EDI/R/a.R:1#term2"]["context"]
        self.assertEqual(a["masked_line"], "# by the [TERM #2] group")
        self.assertEqual(a["match"], "partial-word")
        self.assertNotIn("category", a)                                 # term #2 has none
        self.assertEqual(u["docs/[TERM #1].md (file path)#term1"]["context"]["category"], "person")
        n = u["docs/notes.md:2#term2"]["context"]
        self.assertEqual(n["match"], "near match")
        self.assertEqual(n["masked_context"][1], "2: we met [TERM #2] at the [TERM #3] meeting")
        for x in f:
            assert_no_terms(self, json.dumps(x), "a mechanical finding")
        assert_no_terms(self, json.dumps(u), "the units")
        assert_no_terms(self, (tmp / "work" / pv.SPANS).read_text(), "the span sidecar")

    def test_overflow(self):
        tmp, repo = make_repo({"a.md": "Zorblatt\n" * (pv.MAX_PER_TERM + 5)})
        with mock.patch.dict(os.environ, {pv.ENV: "Zorblatt"}):
            f = pv.mechanical(self.ctx(repo, tmp))
        self.assertEqual(len(f), pv.MAX_PER_TERM + 1)
        self.assertIn("5 more", f[-1]["text"])


class EndToEnd(unittest.TestCase):
    """prepare -> agent result (which quotes the word it should not) -> finish; then every file
    the run wrote, and the log, must be free of term text."""

    def test_no_term_text_anywhere(self):
        tmp, repo = make_repo()
        out = tmp / "out.txt"
        args = lambda cmd, *x: [cmd, "--audit", "privacy", "--repo", str(repo), "--notes", str(tmp / "notes"),
                                "--work", str(tmp / "work"), "--github-output", str(out), *x]
        log = io.StringIO()
        with mock.patch.dict(os.environ, {pv.ENV: TERMS_RAW}), contextlib.redirect_stdout(log):
            audit_run.main(args("prepare", "--no-harvest"))
        batches = json.loads(dict(l.split("=", 1) for l in out.read_text().splitlines())["batches"])
        self.assertEqual(len(batches), 1)
        b = json.loads((tmp / "work/batches/b001.json").read_text())
        self.assertEqual(len(b["units"]), 3)

        res = tmp / "results"
        res.mkdir()
        (res / "b001.json").write_text(json.dumps({
            "units_checked": ["R/EDI/R/a.R:1#term2", "docs/notes.md:2#term2"],
            "findings": [
                {"unit": "R/EDI/R/a.R:1#term2", "kind": "exposes",
                 "text": "The Quixleyson group is named in a code comment; quixley is the term."},
                {"unit": "docs/notes.md:2#term2", "kind": "benign", "text": "A different word."}]}))
        out.write_text("")
        with mock.patch.dict(os.environ, {}, clear=False), contextlib.redirect_stdout(log):
            os.environ.pop(pv.ENV, None)                                 # finish has no word list
            audit_run.main(args("finish", "--results", str(res)))
        report = (tmp / "work/report.md").read_text()
        self.assertIn("R/EDI/R/a.R:1#term2", report)
        self.assertIn("exposes", report)
        self.assertIn("[TERM #2] group", report)                         # the agent's text, scrubbed
        self.assertIn("not judged yet", report)                          # the third hit was not in the result
        self.assertIn("README.md:1", report)

        for root in (tmp / "work", tmp / "notes"):
            for p in root.rglob("*"):
                if p.is_file():
                    assert_no_terms(self, p.read_text(errors="replace"), str(p.relative_to(tmp)))
        assert_no_terms(self, log.getvalue(), "the log")
        self.assertEqual(subprocess.run(["git", "status", "--porcelain"], cwd=repo, capture_output=True,
                                        text=True).stdout, "")           # nothing applied

        # Second run: judged hits are not sent again, and the exposes verdict is still listed.
        out.write_text("")
        with mock.patch.dict(os.environ, {pv.ENV: TERMS_RAW}), contextlib.redirect_stdout(log):
            audit_run.main(args("prepare", "--no-harvest"))
        plan = json.loads((tmp / "work/plan.json").read_text())
        self.assertEqual(plan["chosen"], ["docs/[TERM #1].md (file path)#term1"])
        out.write_text("")
        with contextlib.redirect_stdout(log):
            audit_run.main(args("finish", "--results", str(tmp / "none")))
        self.assertIn("R/EDI/R/a.R:1#term2`: exposes", (tmp / "work/report.md").read_text())
        for p in (tmp / "notes").rglob("*"):
            if p.is_file():
                assert_no_terms(self, p.read_text(errors="replace"), str(p))


if __name__ == "__main__":
    unittest.main(verbosity=1)
