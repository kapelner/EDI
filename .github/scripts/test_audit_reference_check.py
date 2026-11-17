#!/usr/bin/env python3
"""Checks for the reference check (audits/reference_check.py). Stdlib only, no network: Crossref
and doi.org are replaced by a fake."""
import datetime as dt
import io
import sys
import tempfile
import unittest
import urllib.error
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import audit_common as ac  # noqa: E402
from audits import _doc_audit_shared as sh  # noqa: E402
from audits import reference_check as rc  # noqa: E402

NOW = dt.datetime(2026, 11, 16, 6, tzinfo=dt.timezone.utc)

REFS = """# EDI Package Reference Map

## Design methods

- **[Efron1971]** Efron, B. (1971). "Forcing a sequential experiment to be
  balansed." *Biometrika*, 58(3), 403-417. [doi:10.1093/biomet/58.3.403](https://doi.org/10.1093/biomet/58.3.403). —
  Used by: `DesignSeqOneByOneEfron`.
- **[Fisher1935]** Fisher, R. A. (1935). *The Design of Experiments*. No DOI.
- **[Zelen1974]** Zelen, M. (1947). "The randomization and stratification of
  patients to clinical trials." [doi:10.1016/0021-9681(74)90015-0](https://doi.org/10.1016/0021-9681%2874%2990015-0).
"""

URN_R = """#' Urn design
#'
#' @references Wei, L. J. (1977). "A class of designs for sequential clinical trials."
#'   \\emph{JASA}, 72(358), 382-386,
#'   \\doi{10.1080/01621459.1977.10481006}; Wei, L. J. (1978). "The adaptive biased coin
#'   design for sequential experiments." \\emph{The Annals of Statistics}, 6(1), 92-100,
#'   \\doi{10.1214/aos/1176344068}. See also the vignette.
#' @export
Urn = function() NULL
"""

RECORDS = {
    "10.1093/biomet/58.3.403": {"DOI": "10.1093/biomet/58.3.403", "title": ["Forcing a sequential experiment to be balanced"],
                                "author": [{"given": "Bradley", "family": "Efron"}],
                                "issued": {"date-parts": [[1971, 12]]}, "container-title": ["Biometrika"]},
    "10.1016/0021-9681(74)90015-0": {"title": ["The randomization and stratification of patients to clinical trials"],
                                     "author": [{"given": "M.", "family": "Zelen"}],
                                     "issued": {"date-parts": [[1974]]}, "published-print": {"date-parts": [[1974, 9]]}},
    "10.1080/01621459.1977.10481006": {"title": ["A Class of Designs for Sequential Clinical Trials"],
                                       "issued": {"date-parts": [[1977]]}},
}


class FakeWeb:
    def __init__(self, missing_ra=None, fail=()):
        self.calls, self.missing_ra, self.fail = [], missing_ra or {}, set(fail)

    def __call__(self, url, timeout=25):
        self.calls.append(url)
        import urllib.parse
        if url.startswith(rc.CROSSREF):
            doi = urllib.parse.unquote(url[len(rc.CROSSREF):])
            if doi in self.fail:
                raise urllib.error.URLError("down")
            if doi in RECORDS:
                return {"message": RECORDS[doi]}
            raise urllib.error.HTTPError(url, 404, "nf", {}, io.BytesIO(b""))
        doi = urllib.parse.unquote(url[len(rc.DOI_RA):])
        return [{"DOI": doi, **({"RA": self.missing_ra[doi]} if doi in self.missing_ra
                               else {"status": "DOI does not exist"})}]


def make_ctx():
    tmp = Path(tempfile.mkdtemp())
    repo = tmp / "repo"
    (repo / "R/EDI/R").mkdir(parents=True)
    (repo / rc.REFS).write_text(REFS)
    (repo / "R/EDI/R/urn.R").write_text(URN_R)
    spec = ac.spec_of(rc)
    ctx = ac.Context(spec, repo, ac.Notes(tmp / "notes", spec["name"]), tmp / "work", now=NOW)
    ctx.workdir.mkdir(parents=True)
    return ctx


NO_ROX = lambda repo, files: {"ran": False, "ok": True, "note": f"roxygen would run for {files}", "kept": [], "reverted": []}


class Extraction(unittest.TestCase):
    def test_dois(self):
        self.assertEqual(rc.dois_in("[doi:10.1/x(1)](https://doi.org/10.1/x%281%29). \\doi{10.2/y}."),
                         ["10.1/x(1)", "10.2/y"])

    def test_md_entries(self):
        es = rc.references_md_entries(REFS)
        self.assertEqual([e["id"] for e in es], ["R/EDI/REFERENCES.md#[Efron1971]", "R/EDI/REFERENCES.md#[Zelen1974]"])
        self.assertEqual((es[0]["start"], es[0]["end"]), (5, 7))
        self.assertEqual(es[1]["dois"], ["10.1016/0021-9681(74)90015-0"])

    def test_roxygen_entries(self):
        ctx = make_ctx()
        es = rc.roxygen_entries(ctx.repo)
        self.assertEqual([e["id"] for e in es], ["R/EDI/R/urn.R#10.1080/01621459.1977.10481006",
                                                 "R/EDI/R/urn.R#10.1214/aos/1176344068"])
        self.assertTrue(es[0]["text"].startswith("Wei, L. J. (1977)"))
        self.assertTrue(es[1]["text"].startswith("Wei, L. J. (1978)"))
        self.assertEqual((es[0]["start"], es[0]["end"]), (3, 5))
        self.assertEqual((es[1]["start"], es[1]["end"]), (5, 7))


class Crossref(unittest.TestCase):
    def test_lookup(self):
        web = FakeWeb(missing_ra={"10.5281/zenodo.1": "DataCite"})
        ok = rc.lookup("10.1093/biomet/58.3.403", web)
        self.assertEqual(ok["record"]["issued"], 1971)
        self.assertEqual(ok["record"]["authors"], ["Bradley Efron"])
        self.assertEqual(rc.lookup("10.5281/zenodo.1", web), {"status": "missing", "ra": "DataCite"})
        self.assertEqual(rc.lookup("10.9/none", web)["ra"], "DOI does not exist")
        self.assertTrue(all("User-Agent" not in u for u in web.calls))

    def test_user_agent_is_generic(self):
        self.assertNotRegex(rc.USER_AGENT, r"@|mailto|kapelner")

    def test_cache_and_delay(self):
        web, slept = FakeWeb(), []
        cache = {}
        n = rc.resolve(["10.1093/biomet/58.3.403", "10.9/none"], cache, NOW, get=web, sleep=slept.append)
        self.assertEqual(n, 2)
        self.assertEqual(slept, [rc.DELAY])
        n2 = rc.resolve(["10.1093/biomet/58.3.403", "10.9/none"], cache, NOW + dt.timedelta(days=10), get=web,
                        sleep=slept.append)
        self.assertEqual(n2, 0)
        n3 = rc.resolve(["10.1093/biomet/58.3.403"], cache, NOW + dt.timedelta(days=61), get=web, sleep=slept.append)
        self.assertEqual(n3, 1)

    def test_mechanical(self):
        ctx = make_ctx()
        f = rc.mechanical(ctx, get=FakeWeb(), sleep=lambda s: None)
        self.assertEqual([x["kind"] for x in f], ["doi-unknown"])
        self.assertIn("10.1214/aos/1176344068", f[0]["text"])
        self.assertIn("does not exist", f[0]["text"])
        self.assertTrue((ctx.notes.dir / rc.CACHE).exists())
        u = rc.units(ctx)
        self.assertEqual(sorted(u), ["R/EDI/R/urn.R#10.1080/01621459.1977.10481006",
                                     "R/EDI/REFERENCES.md#[Efron1971]", "R/EDI/REFERENCES.md#[Zelen1974]"])
        c = u["R/EDI/REFERENCES.md#[Efron1971]"]["context"]
        self.assertEqual(c["crossref"]["10.1093/biomet/58.3.403"]["title"], "Forcing a sequential experiment to be balanced")

    def test_lookup_errors_are_not_findings(self):
        ctx = make_ctx()
        f = rc.mechanical(ctx, get=FakeWeb(fail={"10.1093/biomet/58.3.403"}), sleep=lambda s: None)
        self.assertEqual([x["kind"] for x in f], ["doi-unknown"])
        self.assertIn("NOT CHECKED", " ".join(sh.read_json(ctx.workdir / "reference_status.json")))


class Rotation(unittest.TestCase):
    def test_monthly_one_in_six(self):
        spec = ac.spec_of(rc)
        self.assertEqual((spec["period"], spec["cycle_weeks"]), ("month", 6))
        ctx = make_ctx()
        rc.mechanical(ctx, get=FakeWeb(), sleep=lambda s: None)
        u = rc.units(ctx)
        m = {"units": {k: {"hash": v["hash"], "deps": v["deps"]} for k, v in u.items()}}
        picks = {k: 0 for k in u}
        for mo in range(6):
            now = dt.datetime(2027, mo + 1, 16, tzinfo=dt.timezone.utc)
            for k in ac.select_units(u, m, "auto", spec["cycle_weeks"], now, period=spec["period"])[0]:
                picks[k] += 1
        self.assertEqual(set(picks.values()), {1})   # each unchanged entry once in six monthly runs


class Fixes(unittest.TestCase):
    def setUp(self):
        self.ctx = make_ctx()
        rc.mechanical(self.ctx, get=FakeWeb(), sleep=lambda s: None)

    def entry(self, uid):
        return {e["id"]: e for e in sh.read_json(self.ctx.workdir / "reference_entries.json")}[uid]

    def rec(self, doi):
        return sh.read_json(self.ctx.workdir / "crossref.json")[doi.lower()]["record"]

    def test_year_rules(self):
        e, r = self.entry("R/EDI/REFERENCES.md#[Zelen1974]"), self.rec("10.1016/0021-9681(74)90015-0")
        good = {"kind": "year", "old_text": "1947", "new_text": "1974", "crossref_field": "issued", "crossref_value": "1974"}
        self.assertTrue(rc.check_fix(e, r, good)[0])
        self.assertFalse(rc.check_fix(e, r, {**good, "new_text": "1975", "crossref_value": "1975"})[0])
        self.assertFalse(rc.check_fix(e, r, {**good, "crossref_field": "title"})[0])
        e2 = {**e, "text": e["text"].replace("1947", "1974")}
        self.assertFalse(rc.check_fix(e2, r, {**good, "old_text": "1974", "new_text": "1974"})[0])

    def test_title_rules(self):
        e, r = self.entry("R/EDI/REFERENCES.md#[Efron1971]"), self.rec("10.1093/biomet/58.3.403")
        f = {"kind": "title-typo", "old_text": "balansed", "new_text": "balanced", "crossref_field": "title",
             "crossref_value": "Forcing a sequential experiment to be balanced"}
        self.assertFalse(rc.check_fix(e, r, f)[0])            # new_text must be the whole title
        e2 = {**e, "text": 'Efron, B. (1971). "Forcing a sequential experiment to be balansed." ...'}
        f2 = {**f, "old_text": "Forcing a sequential experiment to be balansed",
              "new_text": "Forcing a sequential experiment to be balanced"}
        self.assertTrue(rc.check_fix(e2, r, f2)[0])
        self.assertFalse(rc.check_fix(e2, r, {**f2, "new_text": "Forcing A Sequential Experiment To Be Balansed"})[0])
        case_only = {**e2, "text": e2["text"].replace("balansed", "Balanced")}
        self.assertIn("case", rc.check_fix(case_only, r, {**f2, "old_text": "Forcing a sequential experiment to be Balanced"})[1])
        self.assertFalse(rc.check_fix(e2, r, {**f2, "old_text": "Efron"})[0])

    def test_apply(self):
        res = [{"findings": [
            {"unit": "R/EDI/REFERENCES.md#[Zelen1974]", "kind": "year", "text": "1947 vs 1974", "old_text": "1947",
             "new_text": "1974", "crossref_field": "issued", "crossref_value": "1974"},
            {"unit": "R/EDI/REFERENCES.md#[Efron1971]", "kind": "authors", "text": "initials"},
            {"unit": "R/EDI/R/urn.R#10.1080/01621459.1977.10481006", "kind": "year", "text": "x",
             "old_text": "1977", "new_text": "1978", "crossref_field": "issued", "crossref_value": "1978"}]}]
        parts = rc.apply(self.ctx, res, [], roxygen=NO_ROX)
        body = (self.ctx.repo / rc.REFS).read_text()
        self.assertIn("Zelen, M. (1974)", body)
        self.assertEqual(body.count("1974"), REFS.count("1974") + 1)
        self.assertEqual(len(parts["applied"]), 1)
        self.assertEqual(len(parts["human"]), 2)
        self.assertEqual((self.ctx.repo / "R/EDI/R/urn.R").read_text(), URN_R)
        self.assertIn(parts["proposed"][0]["applied_text"], body)


if __name__ == "__main__":
    unittest.main(verbosity=1)
