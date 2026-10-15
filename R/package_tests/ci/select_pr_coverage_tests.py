#!/usr/bin/env python3
"""Pick the tests a pull request's coverage run should execute; no R, no compilation.

Full instrumented coverage (test-coverage-R.yaml) is ~100 shards and ~1.5 h, which
is too slow for pull-request feedback, so test-coverage-R-pr.yaml runs ONE shard:

  * every fast-tier file (R/EDI/tests/testthat/test-*.R) -- the always-on baseline,
    never subject to the budget;
  * bulk test files, under ONE runtime budget (--budget-seconds, manifest
    coverage-tier estimates), ranked: first every bulk test the PR itself adds or
    edits, then the bulk tests most related to the PR's changed R/C++ source files.
    "Related" is the same heuristic contracts/coverage_test_writing.md section 1
    tells a human to apply by hand: grep the suite for the names the changed files
    define (top-level R assignments, define_inference_class()/R6Class() class
    names, [[Rcpp::export]] kernels) and for the changed files' own basenames,
    scored by how many distinct names each test file mentions.

Two guards keep the heuristic honest on real diffs (both found by dry-running it
on this repo's history):
  * generated files (RcppExports.*, unity_*.cpp) contribute no names -- a change
    to RcppExports.R lists every kernel in the package, which would select ~300
    unrelated files; the hand-written file that really changed is in the diff too;
  * a name that appears in more than --ubiquity-fraction of the candidate files
    (e.g. the base class `Inference`) is dropped as non-discriminative.

The result is a shard JSON in exactly the shape plan_shards.py emits, so run_shard.R
consumes it unchanged. Everything dropped for budget -- including changed tests, if
a sweep edits more than fit -- is listed in selection_report.json next to the shard,
so a reviewer can see what the PR's patch coverage did NOT see. Uploaded under the
`r` flag, this gives Codecov head-commit data for the changed R lines -- the one
thing a patch-coverage status needs -- at a cost bounded by one ordinary shard.
"""
import argparse
import csv
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
FAST_TIER_DIR = "R/EDI/tests/testthat"
BULK_DIR = "R/package_tests/testthat_bulk"
SOURCE_RE = re.compile(r"^R/EDI/(R/.*\.R|src/.*\.(cpp|h|hpp))$")
BULK_TEST_RE = re.compile(rf"^{re.escape(BULK_DIR)}/test-.*\.R$")
FAST_TEST_RE = re.compile(rf"^{re.escape(FAST_TIER_DIR)}/test-.*\.R$")
# Generated, not authored: their contents enumerate the whole package.
GENERATED_RE = re.compile(r"^R/EDI/(R/RcppExports\.R|src/RcppExports\.cpp|src/unity_[0-9]+\.cpp)$")

# Identifier-shaped names too generic to say anything about which tests are related.
STOPLIST = {
    "initialize", "function", "public", "private", "active", "classname", "inherit",
    "components", "metadata", "overrides", "list", "value", "result", "self", "super",
    "print", "clone", "finalize", "estimate", "compute", "default", "options", "params",
    "names", "length", "return", "setup", "cleanup", "helper", "helpers", "utils",
    "Inference", "Design", "Source", "Rcpp", "RcppExports", "RcppExport", "EDI",
    "NULL", "TRUE", "FALSE", "NA",
}
MIN_TOKEN_LEN = 5
CHANGED_TEST_PRIORITY = 1_000  # ranks above any relevance score a related file can reach

R_TOPLEVEL_ASSIGN_RE = re.compile(r"^([A-Za-z.][A-Za-z0-9_.]*)\s*(?:=|<-)")
R_CLASSNAME_RE = re.compile(r"""(?:classname\s*=\s*|R6Class\(\s*)["']([A-Za-z][A-Za-z0-9_.]*)["']""")
CPP_EXPORT_RE = re.compile(r"//\s*\[\[Rcpp::export(?:\([^)]*\))?\]\]")
CPP_FUNC_NAME_RE = re.compile(r"\b([A-Za-z_][A-Za-z0-9_]*)\s*\(")
CPP_TYPE_WORDS = {"const", "inline", "static", "template", "typename", "return", "if", "for", "while"}


def changed_files(base, head, root):
    out = subprocess.run(
        ["git", "-C", str(root), "diff", "--name-only", "--diff-filter=ACMR", f"{base}...{head}"],
        check=True, capture_output=True, text=True,
    ).stdout
    return [line.strip() for line in out.splitlines() if line.strip()]


def stem_tokens_for(path):
    stem = Path(path).stem
    if len(stem) < MIN_TOKEN_LEN:
        return set()
    return {stem, stem.replace("_", "-")}


def tokens_for_source(path, root):
    """Names a changed, hand-written source file defines, plus its own basename."""
    rel = Path(path)
    tokens = set(stem_tokens_for(path))
    try:
        text = (root / rel).read_text(errors="replace")
    except OSError:
        return tokens
    lines = text.splitlines()
    if rel.suffix == ".R":
        for line in lines:
            m = R_TOPLEVEL_ASSIGN_RE.match(line)
            if m:
                tokens.add(m.group(1))
        for m in R_CLASSNAME_RE.finditer(text):
            tokens.add(m.group(1))
    else:
        for i, line in enumerate(lines):
            if not CPP_EXPORT_RE.search(line):
                continue
            # The exported function's name is on the first following non-empty line,
            # as the last identifier before the opening parenthesis.
            for follow in lines[i + 1:i + 4]:
                if not follow.strip() or follow.strip().startswith("//"):
                    continue
                names = [n for n in CPP_FUNC_NAME_RE.findall(follow) if n not in CPP_TYPE_WORDS]
                if names:
                    tokens.add(names[-1])
                break
    return {t for t in tokens if len(t) >= MIN_TOKEN_LEN and t not in STOPLIST}


def load_manifest(manifest):
    with Path(manifest).open() as stream:
        rows = [row for row in csv.DictReader(stream) if row["runtime_tier"] == "coverage"]
    return {row["test_file"]: float(row["estimated_seconds"]) for row in rows}


def score_bulk_files(candidates, tokens, stem_tokens, root, ubiquity_fraction):
    """Rank bulk tests by how many distinct changed-source names they mention.

    Returns (scores, ubiquitous): scores maps path -> (score, hits); ubiquitous is the
    set of tokens discarded for matching more than `ubiquity_fraction` of candidates."""
    word_res = {t: re.compile(rf"(?<![A-Za-z0-9_.]){re.escape(t)}(?![A-Za-z0-9_])") for t in tokens}
    texts = {}
    for path in candidates:
        try:
            texts[path] = (root / path).read_text(errors="replace")
        except OSError:
            continue
    token_hits = {t: {p for p, text in texts.items() if rx.search(text)} for t, rx in word_res.items()}
    limit = ubiquity_fraction * max(1, len(texts))
    ubiquitous = {t for t, paths in token_hits.items() if len(paths) > limit}
    scored = {}
    for path in texts:
        name = Path(path).name
        score, hits = 0, []
        for st in sorted(stem_tokens):
            if st in name:
                score += 3
                hits.append(f"filename:{st}")
        for tok in sorted(token_hits):
            if tok in ubiquitous or path not in token_hits[tok]:
                continue
            score += 1
            hits.append(tok)
        if score:
            scored[path] = (score, hits)
    return scored, ubiquitous


def select(changed, manifest_rows, root, budget_seconds, ubiquity_fraction=0.25):
    fast = sorted(p for p in manifest_rows if FAST_TEST_RE.match(p))
    changed_bulk_tests = sorted(p for p in changed if BULK_TEST_RE.match(p) and p in manifest_rows)
    sources = [p for p in changed if SOURCE_RE.match(p) and not GENERATED_RE.match(p)]
    generated_ignored = [p for p in changed if GENERATED_RE.match(p)]

    tokens, stem_tokens = set(), set()
    for src in sources:
        tokens |= tokens_for_source(src, root)
        stem_tokens |= stem_tokens_for(src)

    candidates = [p for p in sorted(manifest_rows) if BULK_TEST_RE.match(p) and p not in changed_bulk_tests]
    scored, ubiquitous = (score_bulk_files(candidates, tokens, stem_tokens, root, ubiquity_fraction)
                          if tokens else ({}, set()))

    # One ranked list under one budget: the PR's own test edits first, then relevance
    # (highest first; among ties the cheaper file, so the budget buys more distinct
    # evidence). Files that no longer fit are reported, never silently dropped.
    ranked = [(CHANGED_TEST_PRIORITY, p) for p in changed_bulk_tests]
    ranked += [(scored[p][0], p) for p in scored]
    ranked.sort(key=lambda sp: (-sp[0], manifest_rows[sp[1]], sp[1]))
    selected, dropped, spent = [], [], 0.0
    for _, path in ranked:
        cost = manifest_rows[path]
        if spent + cost <= budget_seconds:
            selected.append(path)
            spent += cost
        else:
            dropped.append(path)

    def entry(p):
        kind = "changed_test" if p in changed_bulk_tests else "related"
        score, hits = (CHANGED_TEST_PRIORITY, ["edited by this PR"]) if kind == "changed_test" else scored[p]
        return {"test_file": p, "kind": kind, "score": score, "hits": hits, "estimated_seconds": manifest_rows[p]}

    test_files = fast + selected
    total = sum(manifest_rows[p] for p in test_files)
    report = {
        "changed_files": changed,
        "changed_source_files": sources,
        "generated_files_ignored": generated_ignored,
        "tokens": sorted(tokens - ubiquitous),
        "tokens_dropped_as_ubiquitous": sorted(ubiquitous),
        "fast_tier_files": len(fast),
        "fast_tier_estimated_seconds": sum(manifest_rows[p] for p in fast),
        "bulk_selected": [entry(p) for p in selected],
        "bulk_dropped_for_budget": [entry(p) for p in dropped],
        "bulk_budget_seconds": budget_seconds,
        "bulk_spent_seconds": spent,
        "total_estimated_seconds": total,
    }
    shard = {"shard": 0, "estimated_seconds": total, "test_files": test_files}
    return shard, report


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--base", help="base commit/ref of the pull request")
    parser.add_argument("--head", help="head commit/ref of the pull request")
    parser.add_argument("--changed-files-from", type=Path,
                        help="newline-separated list of changed paths (instead of git diff; used by the self-test)")
    parser.add_argument("--output", type=Path, required=True, help="directory for shard-0.json and selection_report.json")
    parser.add_argument("--budget-seconds", type=float, default=900,
                        help="manifest-estimated seconds of bulk tests (changed first, then related) on top of the fast tier")
    parser.add_argument("--ubiquity-fraction", type=float, default=0.25,
                        help="drop a name that matches more than this fraction of candidate bulk files")
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--manifest", type=Path, default=None)
    args = parser.parse_args(argv)

    root = args.root.resolve()
    manifest = args.manifest or (root / "R/package_tests/ci/test_runtimes.csv")
    if args.changed_files_from:
        changed = [l.strip() for l in args.changed_files_from.read_text().splitlines() if l.strip()]
    elif args.base and args.head:
        changed = changed_files(args.base, args.head, root)
    else:
        parser.error("give --base and --head, or --changed-files-from")

    manifest_rows = load_manifest(manifest)
    shard, report = select(changed, manifest_rows, root, args.budget_seconds, args.ubiquity_fraction)

    args.output.mkdir(parents=True, exist_ok=True)
    (args.output / "shard-0.json").write_text(json.dumps(shard, indent=2) + "\n")
    (args.output / "selection_report.json").write_text(json.dumps(report, indent=2) + "\n")
    n_changed = sum(e["kind"] == "changed_test" for e in report["bulk_selected"])
    n_related = len(report["bulk_selected"]) - n_changed
    n_dropped_changed = sum(e["kind"] == "changed_test" for e in report["bulk_dropped_for_budget"])
    print(f"pr coverage shard: {len(shard['test_files'])} files = {report['fast_tier_files']} fast-tier "
          f"({report['fast_tier_estimated_seconds'] / 60:.1f} est min) + {n_changed} changed bulk + {n_related} related bulk "
          f"({report['bulk_spent_seconds'] / 60:.1f} of {report['bulk_budget_seconds'] / 60:.1f} est min budget); "
          f"{len(report['bulk_dropped_for_budget'])} dropped for budget"
          f"{f' (INCLUDING {n_dropped_changed} tests this PR edits)' if n_dropped_changed else ''}; "
          f"total {shard['estimated_seconds'] / 60:.1f} estimated minutes")
    if report["generated_files_ignored"]:
        print(f"  generated files ignored for name extraction: {', '.join(report['generated_files_ignored'])}")
    if report["tokens_dropped_as_ubiquitous"]:
        print(f"  names dropped as ubiquitous: {', '.join(report['tokens_dropped_as_ubiquitous'])}")
    for e in report["bulk_selected"]:
        print(f"  + [{e['kind']}] {e['test_file']}  score={e['score']}  hits={','.join(e['hits'])}")
    for e in report["bulk_dropped_for_budget"]:
        print(f"  - (budget) [{e['kind']}] {e['test_file']}  score={e['score']}  est={e['estimated_seconds']:.0f}s")
    return 0


if __name__ == "__main__":
    sys.exit(main())
