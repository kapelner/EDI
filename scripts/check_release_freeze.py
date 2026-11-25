#!/usr/bin/env python3
"""Refuse a push to main that touches frozen paths while a release freeze is on.

Release freeze (release_v1_0_5.md runbook, step 1): from the release commit until
the gates pass, main takes no R/EDI or comprehensive-harness commits; that work goes
to the short-lived dev-<version> branch, merged back after the tag (step 9).
Docs-only commits on main stay allowed.

The freeze is ON while a remote-tracking branch origin/dev-<version> exists
(e.g. origin/dev-1.0.6). Delete that branch after merging it at step 9 to lift it.

Frozen paths (any change counts, comments included: Rd files come from roxygen
comments, so a comment edit in R/EDI changes the built package):
  - R/EDI/**, except the docs the runbook lets main take during the freeze:
    R/EDI/NEWS.md, R/EDI/cran-comments.md (not in the build) and R/EDI/README.md
  - the comprehensive-test harness R scripts in R/package_tests/:
    comprehensive*.R, *_comprehensive_*.R, _dataset_load.R and the path audits
    (*path_audits*.R)
Result CSVs/HTML in R/package_tests are not frozen: the regeneration writes them.

Usage (from scripts/pre-push, once per ref pushed to refs/heads/main):
  python3 scripts/check_release_freeze.py <base_sha> <local_sha>
Exit 0 = allowed, 1 = refused. Bypass one push deliberately with
EDI_ALLOW_FROZEN_MAIN_PUSH=1 git push ...  (git push --no-verify skips every hook).
"""

import fnmatch
import os
import subprocess
import sys

HARNESS_PATTERNS = (
    "R/package_tests/comprehensive*.R",
    "R/package_tests/*_comprehensive_*.R",
    "R/package_tests/_dataset_load.R",
    "R/package_tests/*path_audits*.R",
)


def git(*args):
    return subprocess.run(("git",) + args, check=True, capture_output=True, text=True).stdout


def freeze_branches():
    out = git("for-each-ref", "--format=%(refname:short)", "refs/remotes/origin/")
    return [r for r in out.split() if fnmatch.fnmatch(r, "origin/dev-[0-9]*")]


DOCS_ALLOWED = {"R/EDI/NEWS.md", "R/EDI/cran-comments.md", "R/EDI/README.md"}


def is_frozen(path):
    if path in DOCS_ALLOWED:
        return False
    if path.startswith("R/EDI/"):
        return True
    # fnmatch's * crosses "/", so require the file to sit directly in R/package_tests/.
    if path.count("/") != 2:
        return False
    return any(fnmatch.fnmatch(path, p) for p in HARNESS_PATTERNS)


def main(argv):
    if len(argv) != 3:
        print(__doc__, file=sys.stderr)
        return 2
    base, local = argv[1], argv[2]
    branches = freeze_branches()
    if not branches:
        return 0
    changed = [p for p in git("diff", "--name-only", base, local).splitlines() if p]
    frozen = [p for p in changed if is_frozen(p)]
    if not frozen:
        return 0
    if os.environ.get("EDI_ALLOW_FROZEN_MAIN_PUSH") == "1":
        print(f"pre-push: release freeze ({', '.join(branches)}) bypassed with "
              f"EDI_ALLOW_FROZEN_MAIN_PUSH=1 for {len(frozen)} frozen file(s).", file=sys.stderr)
        return 0
    print(f"pre-push: main is frozen for the release ({', '.join(branches)} exists), and this push "
          f"changes {len(frozen)} frozen file(s):", file=sys.stderr)
    for p in frozen[:20]:
        print(f"  {p}", file=sys.stderr)
    if len(frozen) > 20:
        print(f"  ... and {len(frozen) - 20} more", file=sys.stderr)
    print(f"pre-push: commit this work on {branches[0].split('/', 1)[1]} instead (docs-only commits "
          "on main are fine). Deliberate override: EDI_ALLOW_FROZEN_MAIN_PUSH=1 git push ...", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
