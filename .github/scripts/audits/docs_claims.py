"""Docs claims vs behaviour: does a test back each testable claim in an exported class's docs?

Plan: R/package_metadata/new_feature_plans/v1_0_6/audit_jobs_framework.md, Part 4 ("Docs claims vs
behaviour": monthly, 2nd Saturday, rotation over all exported classes, Opus).

No mechanical checks. Units: every exported R6 class (exported in R/EDI/NAMESPACE and defined with
R6Class, define_inference_class or define_design_class), with its roxygen text and the test files
that mention it (precomputed: the agent has no shell). New or changed classes, classes whose tests
changed, and a 1/6 monthly rotation are read. The agent lists the class's testable claims and, for
each, the test that covers it or that none does.
Apply: nothing is changed. Uncovered and contradicted claims go to "Needs a human", grouped by
class, each with the claim and where it is documented.
"""
import re
from pathlib import Path

import audit_common as ac
from audits import _doc_audit_shared as sh

SPEC = {
    "name": "docs-claims",
    "title": "Docs claims audit",
    "report": "pr",
    "claude": True,
    "model": ac.OPUS,
    "batch_size": 4,       # a class's docs plus its tests is a lot to read
    "period": "month",     # the rotation counts this job's monthly runs
    "cycle_weeks": 6,      # a 1/6 rotation: each unchanged unit is re-read once every 6 monthly runs
    "max_batches": 6,
    "tools": "Read,Glob,Grep",
    "max_turns": 80,
}
TEST_DIRS = ("R/EDI/tests", "R/package_tests/testthat_bulk")
MAX_TEST_FILES = 40
_CLASS_DEF = re.compile(r"^(`[^`]+`|[A-Za-z.][A-Za-z0-9._]*)\s*(=|<-)\s*(R6::R6Class|R6Class|define_inference_class|"
                        r"define_design_class)\(")


def exported(repo):
    ns = Path(repo, sh.PKG, "NAMESPACE")
    return set(re.findall(r"^export\(([^)]+)\)", ns.read_text(), re.M)) if ns.exists() else set()


def class_definitions(repo):
    """{class: {"file", "line", "inherit"}} for top-level R6 class definitions (the last one wins:
    some files define a scratch class first and reassign the real one later)."""
    out = {}
    for p in sorted(Path(repo, sh.R_DIR).glob("*.R")):
        rel = p.relative_to(repo).as_posix()
        lines = p.read_text(encoding="utf-8", errors="replace").split("\n")
        for i, line in enumerate(lines):
            m = _CLASS_DEF.match(line)
            if not m:
                continue
            name = m.group(1).strip("`")
            head = "\n".join(lines[i:i + 8])
            inh = re.search(r"\binherit\s*=\s*([A-Za-z.][A-Za-z0-9._]*)", head)
            out[name] = {"file": rel, "line": i + 1, "inherit": inh.group(1) if inh else None}
    return out


def test_files(repo):
    files = []
    for d in TEST_DIRS:
        root = Path(repo, d)
        if root.exists():
            files += sorted(p for p in root.rglob("*.R") if p.is_file())
    return files


def tests_mentioning(repo, names):
    """{class: [repo-relative test files that mention it as a whole word]}, plus {file: hash}."""
    hits, hashes = {n: [] for n in names}, {}
    for p in test_files(repo):
        rel = p.relative_to(repo).as_posix()
        text = p.read_text(encoding="utf-8", errors="replace")
        hashes[rel] = ac.text_hash(text)
        for tok in set(re.findall(r"[A-Za-z.][A-Za-z0-9._]*", text)) & set(names):
            hits[tok].append(rel)
    return hits, hashes


def units(ctx):
    repo = ctx.repo
    defs = class_definitions(repo)
    classes = sorted(n for n in exported(repo) if n in defs)
    idx = sh.RoxygenIndex(repo)
    hits, hashes = tests_mentioning(repo, classes)
    out = {}
    for c in classes:
        blocks = idx.by_stem.get(sh.nice_name(c), [])
        if not blocks:
            continue   # undocumented: nothing to extract claims from
        rd = f"{sh.MAN_DIR}/{sh.nice_name(c)}.Rd"
        tf = sorted(hits.get(c, []))
        out[c] = {
            "hash": ac.text_hash(*[b.text() for b in blocks]),
            "deps": ac.text_hash([(f, hashes[f]) for f in tf]),
            "context": {
                "class": c,
                "defined_in": f"{defs[c]['file']}:{defs[c]['line']}",
                "inherits_from": defs[c]["inherit"],
                "rd_file": rd if ctx.path(rd).exists() else None,
                "roxygen_blocks": sh.blocks_context(blocks),
                "test_files": tf[:MAX_TEST_FILES],
                "n_test_files": len(tf),
                "test_files_note": (f"{len(tf) - MAX_TEST_FILES} more test files mention it; use Grep over "
                                    f"{' and '.join(TEST_DIRS)} to find them") if len(tf) > MAX_TEST_FILES else "",
            },
        }
    return out


def apply(ctx, results, mech):
    by_class, counts = {}, {"claims": 0, "covered": 0, "partly": 0, "uncovered": 0, "contradicted": 0}
    for r in results:
        for cl in r.get("claims") or []:
            counts["claims"] += 1
            st = cl.get("status", "")
            if st in counts:
                counts[st] += 1
        for f in r.get("findings") or []:
            by_class.setdefault(f.get("unit", ""), []).append(f)
    human = []
    label = {"uncovered-claim": "no test", "partly-covered-claim": "partly tested",
             "contradicted-claim": "a test or the code contradicts it"}
    for c in sorted(by_class):
        items = []
        for f in sorted(by_class[c], key=lambda x: (x.get("documented_at", ""), x.get("claim", x.get("text", "")))):
            claim = f.get("claim") or f.get("text", "")
            s = f"“{claim}” ({f.get('documented_at') or 'location not given'}; {label.get(f.get('kind'), f.get('kind'))})"
            if f.get("kind") != "uncovered-claim" and f.get("text") and f.get("text") != claim:
                s += f": {f['text']}"
            if f.get("covered_by"):
                s += f"; nearest test: {f['covered_by']}"
            if f.get("suggested_test"):
                s += f"; test idea: {f['suggested_test']}"
            items.append(s)
        human.append(f"`{c}` ({len(items)}):\n" + "\n".join(f"  - {x}" for x in items))
    summary = (f"- {counts['claims']} testable claims checked: {counts['covered']} covered, {counts['partly']} partly, "
               f"{counts['uncovered']} with no test, {counts['contradicted']} contradicted.\n"
               "- This audit changes no file, so its findings go in this issue (label "
               "`audit-docs-claims`), which closes itself on a clean run.")
    return {"summary": summary, "applied": [], "mechanical": [m["text"] for m in mech], "human": human,
            "proposed": []}
