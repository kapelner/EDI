#!/usr/bin/env python3
"""Tests for audits/cran_watcher.py on saved HTML fixtures. No network. Stdlib only."""
import sys
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).parent))
from audits import cran_watcher as cw  # noqa: E402


def row(flavor, status, cls="check_ok"):
    return (f'<tr> <td>  <a href="check_flavors.html#{flavor}"> <span class="CRAN"> {flavor} </span> </a> </td> '
            f'<td> 1.0.2 </td> <td class="r"> 1587.19 </td> <td class="r"> 482.02 </td> <td class="r"> 2069.21 </td> '
            f'<td class="{cls}"> <a href="https://www.R-project.org/nosvn/R.check/{flavor}/EDI-00check.html"> '
            f'{status} </a> </td> <td>  </td> </tr>\n')


def page(rows, details="", extra=""):
    return ("<!DOCTYPE html><html><body><div class=\"container\">\n"
            "<h2>CRAN Package Check Results for Package <a href=\"../packages/EDI/index.html\"> "
            "<span class=\"CRAN\"> EDI </span> </a> </h2>\n<p>\nLast updated on 2026-11-17 05:52:47 CET.\n</p>\n"
            "<table>\n<tr> <th> Flavor </th> <th> Version </th> <th> T<sub>install</sub> </th> "
            "<th> T<sub>check</sub> </th> <th> T<sub>total</sub> </th> <th> Status </th> <th> Flags </th> </tr>\n"
            + "".join(rows) + "</table>\n" + extra + details + "</div></body></html>")


DETAILS = """<h3>Check Details</h3>

<p>
Version: 1.0.2
<br>
Check: installed package size
<br>
Result: NOTE
<span style="font-family: monospace; white-space: pre;">
    installed size is 61.3Mb
    sub-directories of 1Mb or more:
      libs  58.9Mb
</span>
Flavors: <a href="https://www.r-project.org/nosvn/R.check/r-devel-linux-x86_64-fedora-clang/EDI-00check.html"><span class="CRAN">r-devel-linux-x86_64-fedora-clang</span></a>, <a href="https://www.r-project.org/nosvn/R.check/r-release-macos-arm64/EDI-00check.html"><span class="CRAN">r-release-macos-arm64</span></a>
</p>

<p>
Version: 1.0.2
<br>
Check: tests
<br>
Result: ERROR
<span style="font-family: monospace; white-space: pre;">
    Running 'testthat.R' [12m/14m]
  Running the tests in 'tests/testthat.R' failed.
  Last 13 lines of output:
    line 4
    line 5
    line 6
    line 7 should not appear
</span>
Flavors: <a href="https://www.r-project.org/nosvn/R.check/r-devel-windows-x86_64/EDI-00check.html"><span class="CRAN">r-devel-windows-x86_64</span></a>
</p>
"""

CLEAN = page([row("r-devel-linux-x86_64-debian-clang", "OK"), row("r-release-windows-x86_64", "OK")])
DIRTY = page([row("r-devel-linux-x86_64-debian-clang", "OK"),
              row("r-devel-linux-x86_64-fedora-clang", "NOTE", "check_yo"),
              row("r-release-macos-arm64", "NOTE", "check_yo"),
              row("r-devel-windows-x86_64", "ERROR", "check_error"),
              row("r-oldrel-windows-x86_64", "WARN", "check_warn")],
             DETAILS,
             extra='<p>\nAdditional issues:\n<a href="https://www.stats.ox.ac.uk/pub/bdr/memtests/clang-UBSAN/EDI">'
                   '<span class="CRAN">clang-UBSAN</span></a>\n</p>\n')


class Parse(unittest.TestCase):
    def test_clean_page_has_no_findings(self):
        self.assertEqual(cw.findings_from_page(CLEAN), [])
        self.assertIsNone(cw.parse_deadline(CLEAN))

    def test_flavors_and_statuses(self):
        self.assertEqual(dict(cw.parse_flavors(DIRTY))["r-oldrel-windows-x86_64"], "WARN")
        self.assertEqual(len(cw.parse_flavors(DIRTY)), 5)

    def test_one_finding_per_bad_flavor_with_details(self):
        f = cw.findings_from_page(DIRTY)
        flav = {x["unit"]: x for x in f if x["kind"] != "additional-issue"}
        self.assertEqual(set(flav), {"r-devel-linux-x86_64-fedora-clang", "r-release-macos-arm64",
                                     "r-devel-windows-x86_64", "r-oldrel-windows-x86_64"})
        self.assertIn("installed size is 61.3Mb", flav["r-release-macos-arm64"]["text"])
        err = flav["r-devel-windows-x86_64"]
        self.assertEqual(err["kind"], "error")
        self.assertIn("ERROR: tests", err["text"])
        self.assertNotIn("line 7", err["text"])                   # only the first lines
        self.assertIn("no check details", flav["r-oldrel-windows-x86_64"]["text"])

    def test_additional_issues(self):
        f = [x for x in cw.findings_from_page(DIRTY) if x["kind"] == "additional-issue"]
        self.assertEqual([x["unit"] for x in f], ["additional:clang-UBSAN"])

    def test_deadline(self):
        p = page([row("r-devel-windows-x86_64", "ERROR", "check_error")],
                 extra="<p>Please correct before 2026-12-01 to safely retain your package on CRAN.</p>")
        self.assertIn("2026-12-01", cw.parse_deadline(p))
        self.assertIn("2026-12-05", cw.parse_deadline("<p>Deadline: 2026-12-05 for EDI 1.0.2.</p>"))

    def test_changed_layout_is_not_clean(self):
        f = cw.findings_from_page("<html><body>maintenance</body></html>")
        self.assertEqual(f[0]["kind"], "unreadable")

    def test_texts_are_stable_between_runs(self):
        # The issue is updated only when the findings change: timings must not be in the text.
        a = cw.findings_from_page(DIRTY)
        b = cw.findings_from_page(DIRTY.replace("1587.19", "1600.00").replace("2026-11-17", "2026-11-18"))
        self.assertEqual(a, b)


class Mechanical(unittest.TestCase):
    def test_fetch_failure_is_a_finding(self):
        with mock.patch.object(cw, "fetch", side_effect=RuntimeError("timed out")):
            f = cw.mechanical(None)
        self.assertEqual(len(f), 1)
        self.assertEqual(f[0]["kind"], "unreadable")

    def test_deadline_from_package_page(self):
        pages = {cw.CHECK_URL: DIRTY,
                 cw.PACKAGE_URL: "<p>Please correct before 2026-12-01 to safely retain your package on CRAN.</p>"}
        with mock.patch.object(cw, "fetch", side_effect=lambda u: pages[u]):
            f = cw.mechanical(None)
        self.assertEqual(f[0]["kind"], "deadline")
        parts = cw.apply(None, [], f)
        self.assertIn("4 CRAN flavor(s) not OK", parts["summary"])
        self.assertEqual(len(parts["mechanical"]), len(f))

    def test_clean(self):
        with mock.patch.object(cw, "fetch", side_effect=lambda u: CLEAN if u == cw.CHECK_URL else "<p>ok</p>"):
            self.assertEqual(cw.mechanical(None), [])
        self.assertEqual(cw.apply(None, [], [])["mechanical"], [])

    def test_user_agent_is_generic(self):
        self.assertNotIn("@", cw.USER_AGENT)


if __name__ == "__main__":
    unittest.main(verbosity=1)
