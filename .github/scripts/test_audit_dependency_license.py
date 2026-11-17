#!/usr/bin/env python3
"""Tests for audits/dependency_license.py with saved CRAN HTML. No network. Stdlib only."""
import datetime as dt
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).parent))
import audit_common as ac  # noqa: E402
import audit_run  # noqa: E402
from audits import dependency_license as dl  # noqa: E402

NOW = dt.datetime(2026, 12, 7, 6, tzinfo=dt.timezone.utc)

DESCRIPTION = """Package: EDI
Version: 1.0.5
Depends:
    R (>= 4.1.0)
LinkingTo:
    Rcpp,
    RcppEigen
Imports:
    R6,
    Rcpp,
    survival,
    methods,
    stats
Suggests:
    coin,
    betareg (>= 3.2-6),
    oldpkg
VignetteBuilder: knitr
"""

DATASET_MD = """# Dataset license audit

### Ten rows deliberately pinned to old, GPL-3-compatible releases

| Rows | Pinned release (license) | Current release (license) |
|---|---|---|
| `coin::rotarod` | coin 0.6-4 (`GPL`) | 1.4-6 (`GPL-2`) |
| `pscl::bioChemists` (obs) | pscl 0.92 (`GPL`) | 1.5.9 (`GPL-2`) |

### Another section

| Rows | x |
|---|---|
| `survival::veteran` | survival 3.8-6 |
"""


def index_page(version, license, news="news/news.html"):
    news_row = f'<tr>\n<td>NEWS:</td>\n<td><a href="{news}"><span class="CRAN">NEWS</span></a> </td>\n</tr>' \
        if news else ""
    return (f"<html><body><table>\n<tr>\n<td>Version:</td>\n<td>{version}</td>\n</tr>\n"
            f"<tr>\n<td>License:</td>\n<td><a href=\"../../licenses/GPL-2\"><span class=\"CRAN\">{license}"
            f"</span></a></td>\n</tr>\n{news_row}\n</table></body></html>")


ARCHIVED = """<html><body><div class="container">
<p>Package &lsquo;oldpkg&rsquo; was removed from the CRAN repository.</p>
<p>
Archived on 2026-11-02 as issues were not corrected in time.
</p></div></body></html>"""

SURVIVAL_NEWS = """<html><body>
<h2>Changes in version 3.9-0</h2>
<ul><li><p>The <code>survConcordance()</code> function is now defunct; use <code>concordance()</code>.</p></li>
<li><p>coxph now checks convergence with a relative tolerance.</p></li></ul>
<h2>Changes in version 3.8-6</h2>
<ul><li><p>Old item that must not be in the excerpt.</p></li></ul>
</body></html>"""


def pages(survival_version="3.9-0", survival_license="LGPL (>= 2)", coin_version="1.4-6",
          r6_license="MIT + file LICENSE"):
    return {
        f"{dl.CRAN}/R6/index.html": index_page("2.6.1", r6_license, news=None),
        f"{dl.CRAN}/Rcpp/index.html": index_page("1.1.0", "GPL (>= 2)"),
        f"{dl.CRAN}/RcppEigen/index.html": index_page("0.3.4.0.2", "GPL (>= 2) | file LICENSE"),
        f"{dl.CRAN}/survival/index.html": index_page(survival_version, survival_license, news="NEWS"),
        f"{dl.CRAN}/survival/NEWS": SURVIVAL_NEWS,
        f"{dl.CRAN}/coin/index.html": index_page(coin_version, "GPL-2"),
        f"{dl.CRAN}/coin/news/news.html": "<h2>coin 9.9</h2><p>changed</p>",
        f"{dl.CRAN}/betareg/index.html": index_page("3.2-6", "GPL-2 | GPL-3"),
        f"{dl.CRAN}/oldpkg/index.html": ARCHIVED,
    }


def fetcher(routes):
    def f(url):
        if url in routes:
            return routes[url]
        raise RuntimeError(f"{url}: HTTP 404")
    return f


class Repo:
    def __init__(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.repo = self.tmp / "repo"
        files = {"R/EDI/DESCRIPTION": DESCRIPTION,
                 "R/EDI/NAMESPACE": "importFrom(survival, survConcordance)\nimport(R6)\n",
                 "R/EDI/R/cox.R": "fit = function(d) {\n\tsurvival::coxph(Surv(y, e) ~ x, d)\n"
                                  "\tsurvival::survConcordance(Surv(y, e) ~ p)\n}\n",
                 "R/package_metadata/dataset_license_audit.md": DATASET_MD}
        for rel, text in files.items():
            (self.repo / rel).parent.mkdir(parents=True, exist_ok=True)
            (self.repo / rel).write_text(text)
        run = lambda *a: subprocess.run(["git", *a], cwd=self.repo, check=True, capture_output=True)
        run("init", "-q", "-b", "main"); run("config", "user.email", "t@t"); run("config", "user.name", "t")
        run("add", "-A"); run("commit", "-qm", "x")
        self.notes = ac.Notes(self.tmp / "notes", "dependency-license")
        self.work = self.tmp / "work"

    def ctx(self):
        return ac.Context(ac.spec_of(dl), self.repo, self.notes, self.work, now=NOW)

    def snapshot(self, **over):
        snap = {"R6": {"version": "2.6.1", "license": "MIT + file LICENSE"},
                "Rcpp": {"version": "1.1.0", "license": "GPL (>= 2)"},
                "RcppEigen": {"version": "0.3.4.0.2", "license": "GPL (>= 2) | file LICENSE"},
                "survival": {"version": "3.8-6", "license": "LGPL (>= 2)"},
                "coin": {"version": "1.4-5", "license": "GPL-2"},
                "betareg": {"version": "3.2-6", "license": "GPL-2 | GPL-3"},
                "oldpkg": {"version": "1.0", "license": "GPL-3"}}
        snap.update(over)
        (self.notes.dir / dl.SNAPSHOT).write_text(json.dumps({"packages": snap}))


class Parsers(unittest.TestCase):
    def test_description(self):
        d = dl.description_packages(DESCRIPTION)
        self.assertEqual(set(d), {"Rcpp", "RcppEigen", "R6", "survival", "coin", "betareg", "oldpkg"})
        self.assertEqual((d["Rcpp"], d["RcppEigen"]), ("Imports", "LinkingTo"))
        self.assertNotIn("methods", d)

    def test_pinned_only_from_the_pinned_table(self):
        r = Repo()
        self.assertEqual(dl.pinned_packages(r.repo), {"coin", "pscl"})

    def test_real_catalog_pins(self):
        root = Path(__file__).parents[2]
        if (root / "R/package_metadata/dataset_license_audit.md").exists():
            self.assertTrue({"coin", "pscl", "PASWR", "s20x", "nlmeU", "Epi"} <= dl.pinned_packages(root))

    def test_package_page(self):
        info = dl.parse_package_page(index_page("1.4-6", "GPL-2"))
        self.assertEqual((info["version"], info["license"], info["archived"], info["news"]),
                         ("1.4-6", "GPL-2", None, "news/news.html"))
        self.assertIn("2026-11-02", dl.parse_package_page(ARCHIVED)["archived"])

    def test_news_excerpt_and_deprecations(self):
        e = dl.news_excerpt(dl._text(SURVIVAL_NEWS), "3.9-0", "3.8-6")
        self.assertIn("relative tolerance", e)
        self.assertNotIn("Old item", e)
        self.assertEqual(dl.deprecated_names(e), {"survConcordance", "concordance"})
        long = dl.news_excerpt("3.9-0\n" + "x" * 10000, "3.9-0", "3.8-6", limit=100)
        self.assertTrue(long.endswith("[... truncated]"))


class Stages(unittest.TestCase):
    def test_first_run_records_only(self):
        r = Repo()
        ctx = r.ctx()
        f = dl.mechanical(ctx, fetcher(pages()))
        self.assertEqual([x["kind"] for x in f], ["archived"])           # nothing to compare yet
        self.assertEqual(dl.units(ctx), {})
        parts = dl.apply(ctx, [], f)
        self.assertIn("First run", parts["summary"])
        snap = json.loads((r.notes.dir / dl.SNAPSHOT).read_text())["packages"]
        self.assertEqual(snap["survival"]["version"], "3.9-0")

    def test_license_change_archive_deprecated_and_units(self):
        r = Repo()
        r.snapshot()
        ctx = r.ctx()
        f = dl.mechanical(ctx, fetcher(pages(r6_license="GPL-3")))
        kinds = sorted((x["unit"], x["kind"]) for x in f)
        self.assertIn(("R6", "license-changed"), kinds)
        self.assertIn(("oldpkg", "archived"), kinds)
        dep = [x for x in f if x["kind"] == "deprecated-call"]
        self.assertEqual({x["text"].split("`")[1] for x in dep}, {"survival::survConcordance"})
        self.assertTrue(any("R/EDI/R/cox.R:3" in x["text"] for x in dep))
        self.assertTrue(any("R/EDI/NAMESPACE:1" in x["text"] for x in dep))
        u = dl.units(ctx)
        self.assertEqual(set(u), {"survival"})                            # coin changed but is pinned
        c = u["survival"]["context"]
        self.assertEqual((c["old_version"], c["new_version"]), ("3.8-6", "3.9-0"))
        self.assertIn("relative tolerance", c["news_excerpt"])
        self.assertIn("R/EDI/R/cox.R:2", c["edi_references"])

    def test_pinned_package_license_still_compared_but_no_version_drift(self):
        r = Repo()
        r.snapshot(coin={"version": "1.4-5", "license": "GPL (>= 2)"})
        ctx = r.ctx()
        f = dl.mechanical(ctx, fetcher(pages()))
        coin = [x for x in f if x["unit"] == "coin"]
        self.assertEqual([x["kind"] for x in coin], ["license-changed"])
        self.assertIn("pins an older release", coin[0]["text"])
        self.assertNotIn("coin", dl.units(ctx))

    def test_unreadable_page_keeps_the_snapshot(self):
        r = Repo()
        r.snapshot()
        routes = pages()
        del routes[f"{dl.CRAN}/betareg/index.html"]
        ctx = r.ctx()
        f = dl.mechanical(ctx, fetcher(routes))
        self.assertIn(("betareg", "unreadable"), [(x["unit"], x["kind"]) for x in f])
        pending = json.loads((r.work / dl.PENDING).read_text())["packages"]
        self.assertEqual(pending["betareg"]["version"], "3.2-6")

    def test_apply_lists_agent_checks_and_not_run(self):
        r = Repo()
        r.work.mkdir(parents=True)
        (r.work / "plan.json").write_text(json.dumps({"units": {"survival": {}, "Rcpp": {}}}))
        (r.work / dl.PENDING).write_text('{"packages": {}}')
        results = [{"_batch": "b001", "_units": ["survival"], "units_checked": ["survival"], "findings": [
            {"unit": "survival", "kind": "check", "text": "survConcordance is defunct; cox.R:3 uses it.",
             "edi_files": ["R/EDI/R/cox.R:3"]}]}]
        parts = dl.apply(r.ctx(), results, [])
        self.assertEqual(parts["applied"], [])                             # nothing automatic
        self.assertEqual(parts["human"][0], "`Rcpp`: version changed; NEWS not summarised (agent NOT RUN).")
        self.assertIn("survConcordance is defunct", parts["human"][1])
        self.assertEqual(parts["proposed"][0]["kind"], "news-check")
        self.assertNotIn("applied_file", parts["proposed"][0])
        self.assertEqual(subprocess.run(["git", "status", "--porcelain"], cwd=r.repo, capture_output=True,
                                        text=True).stdout, "")            # work tree untouched


class EndToEnd(unittest.TestCase):
    def test_prepare_and_finish(self):
        r = Repo()
        r.snapshot()
        out = r.tmp / "out.txt"
        args = lambda cmd, *x: [cmd, "--audit", "dependency-license", "--repo", str(r.repo),
                                "--notes", str(r.tmp / "notes"), "--work", str(r.work),
                                "--github-output", str(out), *x]
        with mock.patch.object(dl, "fetch", fetcher(pages())):
            audit_run.main(args("prepare", "--no-harvest"))
        batches = json.loads(dict(l.split("=", 1) for l in out.read_text().splitlines())["batches"])
        self.assertEqual(len(batches), 1)
        b = json.loads((r.work / "batches" / "b001.json").read_text())
        self.assertEqual(b["units"][0]["id"], "survival")
        self.assertIn("news_excerpt", b["units"][0])
        out.write_text("")
        audit_run.main(args("finish", "--results", str(r.tmp / "none")))
        report = (r.work / "report.md").read_text()
        self.assertIn("NOT RUN", report)
        self.assertIn("archived", report)
        snap = json.loads((r.notes.dir / dl.SNAPSHOT).read_text())["packages"]
        self.assertEqual(snap["survival"]["version"], "3.9-0")             # recorded in finish


if __name__ == "__main__":
    unittest.main(verbosity=1)
