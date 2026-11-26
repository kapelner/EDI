#!/usr/bin/env python3
"""Check that design-balance-real-data.yml lists every design kernel (v1.0.7-TODO-103).

The workflow runs only when Design code changed since its last successful run. "Design code"
is R/EDI/R/design_*.R plus the C++ files those R files call into. The C++ list is written out
in the workflow, between the lines `# design-kernels:begin` and `# design-kernels:end`, one
`R/EDI/src/<file>.cpp` per line. This script derives the list from the sources: every
`// [[Rcpp::export]]` function in R/EDI/src/*.cpp, matched against the identifiers called in
R/EDI/R/design_*.R (comments stripped). It exits 1 when a kernel is missing from the workflow
(a new design kernel would otherwise not trigger the benchmark) and lists extras as warnings.

Usage: python3 .github/scripts/check_design_balance_kernels.py [--print]
  --print   print the derived list in the workflow's format and exit 0.
"""
import glob
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
WORKFLOW = os.path.join(ROOT, ".github", "workflows", "design-balance-real-data.yml")
EXPORT = re.compile(
    r'//\s*\[\[Rcpp::export(?:\(\s*(?:name\s*=\s*)?"?([\w.]+)"?\s*\))?\]\]\s*\n\s*[\w:<>,\s*&]+?\b(\w+)\s*\(')


def exported_functions():
    out = {}
    for f in sorted(glob.glob(os.path.join(ROOT, "R", "EDI", "src", "*.cpp"))):
        if os.path.basename(f) == "RcppExports.cpp":
            continue
        with open(f, errors="ignore") as fh:
            src = fh.read()
        for m in EXPORT.finditer(src):
            out[m.group(1) or m.group(2)] = os.path.basename(f)
    return out


def derived_kernels():
    exports = exported_functions()
    used = set()
    for f in glob.glob(os.path.join(ROOT, "R", "EDI", "R", "design_*.R")):
        with open(f) as fh:
            src = re.sub(r"#[^\n]*", "", fh.read())
        for tok in re.findall(r"([A-Za-z_.][\w.]*)\s*\(", src):
            if tok in exports:
                used.add(exports[tok])
    return sorted("R/EDI/src/" + k for k in used)


def listed_kernels():
    with open(WORKFLOW) as fh:
        text = fh.read()
    m = re.search(r"# design-kernels:begin\n(.*?)# design-kernels:end", text, re.S)
    if not m:
        sys.exit(f"{WORKFLOW}: no '# design-kernels:begin' ... '# design-kernels:end' block")
    return sorted(re.findall(r"R/EDI/src/[\w.]+\.cpp", m.group(1)))


def main():
    derived = derived_kernels()
    if "--print" in sys.argv[1:]:
        for k in derived:
            print(f"            '{k}'")
        return 0
    listed = listed_kernels()
    missing = sorted(set(derived) - set(listed))
    extra = sorted(set(listed) - set(derived))
    for k in extra:
        print(f"warning: {k} is listed but no design_*.R file calls into it")
    if missing:
        print("design-balance-real-data.yml is missing design kernel(s) called from R/EDI/R/design_*.R:")
        for k in missing:
            print(f"  {k}")
        print("Add them to the design-kernels block (python3 .github/scripts/check_design_balance_kernels.py --print).")
        return 1
    print(f"design-balance-real-data.yml lists all {len(derived)} design kernels.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
