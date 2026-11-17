#!/usr/bin/env python3
"""Checks for the README / vignette drift audit (audits/readme_drift.py). Stdlib only, no R."""
import datetime as dt
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import audit_common as ac  # noqa: E402
from audits import _doc_audit_shared as sh  # noqa: E402
from audits import readme_drift as rdr  # noqa: E402

NOW = dt.datetime(2026, 11, 19, 6, tzinfo=dt.timezone.utc)

VIGNETTE = """---
title: "x"
---

```{r, include = FALSE}
knitr::opts_chunk$set(collapse = TRUE, comment = "#>")
```

```{r install, eval = FALSE, purl = FALSE}
install.packages("EDI")
```

The estimate is about 0.42 and the p-value is 0.03.

```{r fit}
est = 0.4213
est
```

The design has 10 subjects.
"""

GLOBAL_OFF = """```{r, include = FALSE}
knitr::opts_chunk$set(eval = FALSE)
```

```{r}
x = 1
```

```{r, eval = TRUE}
y = 2
```
"""


def make_ctx():
    tmp = Path(tempfile.mkdtemp())
    repo = tmp / "repo"
    (repo / "R/EDI/vignettes/articles").mkdir(parents=True)
    (repo / "R/EDI/README.md").write_text("# EDI\n\n```r\ninstall.packages('EDI')\n```\n")
    (repo / "R/EDI/vignettes/a.Rmd").write_text(VIGNETTE)
    (repo / "R/EDI/vignettes/articles/b.Rmd").write_text(GLOBAL_OFF)
    spec = ac.spec_of(rdr)
    ctx = ac.Context(spec, repo, ac.Notes(tmp / "notes", spec["name"]), tmp / "work", now=NOW)
    (ctx.workdir / rdr.OUT_DIR).mkdir(parents=True)
    return ctx


def record(doc, output="> est\n[1] 0.4213", error=None, finished=True):
    return {"doc": doc, "finished": finished, "chunks": [
        {"index": 1, "eval": True, "output": "> knitr::opts_chunk$set()", "error": None, "warnings": []},
        {"index": 2, "eval": False, "output": "(not run: eval = FALSE)"},
        {"index": 3, "eval": True, "label": "fit", "start_line": 15, "output": output, "error": error,
         "warnings": ["w"] if error else []}]}


class Chunks(unittest.TestCase):
    def test_rmd(self):
        ch = rdr.extract_chunks(VIGNETTE)
        self.assertEqual([(c["label"], c["eval"]) for c in ch], [("", True), ("install", False), ("fit", True)])
        self.assertEqual((ch[2]["start_line"], ch[2]["end_line"]), (15, 18))

    def test_global_eval_false(self):
        ch = rdr.extract_chunks(GLOBAL_OFF)
        self.assertEqual([c["eval"] for c in ch], [True, False, True])

    def test_markdown_fences(self):
        ch = rdr.extract_chunks("```r\nx = 1\n```\n\n```bash\nls\n```\n", markdown=True)
        self.assertEqual(len(ch), 1)

    def test_documents(self):
        ctx = make_ctx()
        self.assertEqual(rdr.documents(ctx.repo), ["R/EDI/README.md", "R/EDI/vignettes/a.Rmd",
                                                   "R/EDI/vignettes/articles/b.Rmd"])
        (ctx.repo / "R/EDI/README.Rmd").write_text("x")
        self.assertEqual(rdr.documents(ctx.repo)[0], "R/EDI/README.Rmd")


class Mechanical(unittest.TestCase):
    def test_findings(self):
        doc = "R/EDI/vignettes/a.Rmd"
        f = rdr.findings_for_run(doc, record(doc, error="boom"), rdr.extract_chunks(VIGNETTE))
        self.assertEqual([x["kind"] for x in f], ["chunk-error", "chunk-warning"])
        f = rdr.findings_for_run(doc, {**record(doc), "finished": False, "timed_out": True,
                                       "chunks": record(doc)["chunks"][:1]}, rdr.extract_chunks(VIGNETTE))
        self.assertEqual(f[-1]["kind"], "doc-time-limit")
        self.assertIn("chunk 3", f[-1]["text"])


class Units(unittest.TestCase):
    def test_only_docs_with_output_and_deps_follow_output(self):
        ctx = make_ctx()
        doc = "R/EDI/vignettes/a.Rmd"
        sh.write_json(rdr.outputs_path(ctx, doc), record(doc))
        sh.write_json(rdr.outputs_path(ctx, "R/EDI/README.md"),
                      {"chunks": [{"index": 1, "eval": True, "output": "> library(EDI)"}]})
        u = rdr.units(ctx)
        self.assertEqual(list(u), [doc])               # README printed nothing but its echo
        self.assertEqual(u[doc]["context"]["outputs_file"], ".audit-work/readme_outputs/R_EDI_vignettes_a.Rmd.json")
        sh.write_json(rdr.outputs_path(ctx, doc), record(doc, output="> est\n[1] 0.5"))
        u2 = rdr.units(ctx)
        self.assertEqual(u[doc]["hash"], u2[doc]["hash"])
        self.assertNotEqual(u[doc]["deps"], u2[doc]["deps"])
        m = {"units": {doc: {"hash": u[doc]["hash"], "deps": u[doc]["deps"]}}}
        self.assertEqual(ac.select_units(u2, m, "auto", 10 ** 6, NOW)[0], [doc])


class NumberFix(unittest.TestCase):
    OUT = "> est\n[1] 0.4213"

    def fix(self, **kw):
        f = {"kind": "number-drift", "old_text": "The estimate is about 0.42", "old_number": "0.42",
             "new_number": "0.39", "output_line": "[1] 0.3901"}
        f.update(kw)
        return f

    def test_supports(self):
        self.assertTrue(rdr.supports("[1] 0.3901", "0.39"))
        self.assertTrue(rdr.supports("p = 3%", "3%"))
        self.assertFalse(rdr.supports("[1] 0.3951", "0.39"))
        self.assertTrue(rdr.supports("n = 12", "12"))

    def test_rules(self):
        out = "> est\n[1] 0.3901"
        ok, why, new = rdr.check_number_fix(VIGNETTE, out, self.fix())
        self.assertTrue(ok, why)
        self.assertIn("The estimate is about 0.39 and", new)
        self.assertEqual(new.count("0.39"), 1)
        cases = [
            (self.fix(output_line="[1] 0.9999"), "not in the recorded output"),
            (self.fix(new_number="0.5", output_line="[1] 0.3901"), "does not contain"),
            (self.fix(old_text="0.42 and the"[:4]), "occurs"),
            (self.fix(old_text="est = 0.4213", old_number="0.4213", new_number="0.39"), "inside a code chunk"),
            (self.fix(kind="claim-drift"), "not a number fix"),
            (self.fix(old_text="The estimate is about 0.42 and the p-value is 0.03.", old_number="0.5"),
             "exactly one number"),
        ]
        for f, why_part in cases:
            ok, why, _ = rdr.check_number_fix(VIGNETTE, out, f)
            self.assertFalse(ok, f)
            self.assertIn(why_part, why, f)

    def test_apply(self):
        ctx = make_ctx()
        doc = "R/EDI/vignettes/a.Rmd"
        sh.write_json(rdr.outputs_path(ctx, doc), record(doc, output="> est\n[1] 0.3901"))
        res = [{"findings": [{"unit": doc, "text": "estimate changed", **self.fix()},
                             {"unit": doc, "kind": "claim-drift", "text": "the p-value claim is stale"}]}]
        parts = rdr.apply(ctx, res, [])
        self.assertIn("about 0.39 and", (ctx.repo / doc).read_text())
        self.assertEqual(len(parts["applied"]), 1)
        self.assertEqual(len(parts["human"]), 1)
        p = parts["proposed"][0]
        self.assertIn(p["applied_text"], (ctx.repo / doc).read_text())

    def test_rejected_not_reapplied(self):
        ctx = make_ctx()
        doc = "R/EDI/vignettes/a.Rmd"
        sh.write_json(rdr.outputs_path(ctx, doc), record(doc, output="[1] 0.3901"))
        fid = ac.finding_id("readme-drift", doc, "number-drift", "The estimate is about 0.42: 0.42 -> 0.39")
        ctx.notes.save_findings([{"id": fid, "status": "rejected"}])
        rdr.apply(ctx, [{"findings": [{"unit": doc, "text": "x", **self.fix()}]}], [])
        self.assertEqual((ctx.repo / doc).read_text(), VIGNETTE)


if __name__ == "__main__":
    unittest.main(verbosity=1)
