#!/usr/bin/env python3
"""Checks for the docs claims audit (audits/docs_claims.py). Stdlib only."""
import datetime as dt
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import audit_common as ac  # noqa: E402
from audits import docs_claims as dc  # noqa: E402

NOW = dt.datetime(2026, 11, 14, 6, tzinfo=dt.timezone.utc)

SRC = """#' Foo inference
#'
#' The default number of draws is 501.
#' @export
Foo = define_inference_class(
	classname = "Foo",
	inherit = Inference,
	public = list(
		#' @description Errors when n < 2.
		initialize = function(n) NULL
	)
)

#' Not exported
Bar = R6::R6Class("Bar")

#' Scratch first
#' @export
Baz = R6::R6Class("BazScratch")
Baz = define_design_class("Baz", inherit = Design)

helper = function() Foo
"""


def make_ctx():
    tmp = Path(tempfile.mkdtemp())
    repo = tmp / "repo"
    (repo / "R/EDI/R").mkdir(parents=True)
    (repo / "R/EDI/tests/testthat").mkdir(parents=True)
    (repo / "R/package_tests/testthat_bulk").mkdir(parents=True)
    (repo / "R/EDI/R/foo.R").write_text(SRC)
    (repo / "R/EDI/NAMESPACE").write_text("export(Foo)\nexport(Baz)\nexport(helper)\n")
    (repo / "R/EDI/tests/testthat/test-foo.R").write_text('test_that("x", { f = Foo$new(3) })\n')
    (repo / "R/package_tests/testthat_bulk/test-bulk.R").write_text("Foo; Bazooka; FooBar\n")
    spec = ac.spec_of(dc)
    return ac.Context(spec, repo, ac.Notes(tmp / "notes", spec["name"]), tmp / "work", now=NOW)


class Units(unittest.TestCase):
    def test_classes_and_tests(self):
        ctx = make_ctx()
        defs = dc.class_definitions(ctx.repo)
        self.assertEqual(defs["Foo"]["inherit"], "Inference")
        self.assertEqual(defs["Baz"]["line"], 20)            # the last definition wins
        u = dc.units(ctx)
        self.assertEqual(sorted(u), ["Baz", "Foo"])           # Bar is not exported; helper is no class
        self.assertEqual(u["Foo"]["context"]["test_files"], ["R/EDI/tests/testthat/test-foo.R",
                                                             "R/package_tests/testthat_bulk/test-bulk.R"])
        self.assertEqual(u["Baz"]["context"]["test_files"], [])   # Bazooka is not Baz
        self.assertEqual(u["Foo"]["context"]["roxygen_blocks"][1], {"file": "R/EDI/R/foo.R", "lines": "9-9"})

    def test_test_change_and_rotation_change_deps(self):
        ctx = make_ctx()
        u1 = dc.units(ctx)
        (ctx.repo / "R/EDI/tests/testthat/test-foo.R").write_text('test_that("y", { Foo$new(1) })\n')
        u2 = dc.units(ctx)
        self.assertEqual(u1["Foo"]["hash"], u2["Foo"]["hash"])
        self.assertNotEqual(u1["Foo"]["deps"], u2["Foo"]["deps"])
        spec = ac.spec_of(dc)
        self.assertEqual((spec["period"], spec["cycle_weeks"]), ("month", 6))
        m = {"units": {k: {"hash": v["hash"], "deps": v["deps"]} for k, v in u2.items()}}
        picks = {k: 0 for k in u2}
        for mo in range(6):
            now = dt.datetime(2027, mo + 1, 13, tzinfo=dt.timezone.utc)
            for k in ac.select_units(u2, m, "auto", 6, now, period="month")[0]:
                picks[k] += 1
        self.assertEqual(set(picks.values()), {1})

    def test_unchanged_class_waits(self):
        ctx = make_ctx()
        u = dc.units(ctx)
        m = {"units": {k: {"hash": v["hash"], "deps": v["deps"]} for k, v in u.items()}}
        chosen, reasons, _ = ac.select_units(u, m, "auto", 6, NOW, period="month")
        self.assertTrue(all("rotation" in reasons[k] for k in chosen))


class Apply(unittest.TestCase):
    def test_grouped_by_class_and_nothing_changed(self):
        ctx = make_ctx()
        res = [{"units_checked": ["Foo", "Baz"],
                "claims": [{"unit": "Foo", "claim": "a", "documented_at": "R/EDI/R/foo.R:3", "status": "uncovered"},
                           {"unit": "Foo", "claim": "b", "documented_at": "R/EDI/R/foo.R:9", "status": "covered"}],
                "findings": [
                    {"unit": "Foo", "kind": "uncovered-claim", "text": "no test", "claim": "The default number of draws is 501.",
                     "documented_at": "R/EDI/R/foo.R:3", "suggested_test": "check the default"},
                    {"unit": "Foo", "kind": "contradicted-claim", "text": "test-foo.R:1 passes n = 1",
                     "claim": "Errors when n < 2.", "documented_at": "R/EDI/R/foo.R:9"},
                    {"unit": "Baz", "kind": "partly-covered-claim", "text": "only for Bernoulli", "claim": "c",
                     "documented_at": "R/EDI/R/foo.R:17"}]}]
        before = (ctx.repo / "R/EDI/R/foo.R").read_text()
        parts = dc.apply(ctx, res, [])
        self.assertEqual((ctx.repo / "R/EDI/R/foo.R").read_text(), before)
        self.assertEqual(parts["applied"], [])
        self.assertEqual(parts["proposed"], [])
        self.assertEqual([h.split(" ")[0] for h in ac.texts(parts["human"])], ["`Baz`", "`Foo`"])
        foo = ac.texts(parts["human"])[1]
        self.assertIn("(2):", foo)
        self.assertIn("“The default number of draws is 501.” (R/EDI/R/foo.R:3; no test)", foo)
        self.assertIn("test-foo.R:1 passes n = 1", foo)
        self.assertIn("2 testable claims checked: 1 covered", parts["summary"])


if __name__ == "__main__":
    unittest.main(verbosity=1)
