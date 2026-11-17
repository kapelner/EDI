"""Run the testthat tests an audit agent wrote, and add the ones that fail as claimed to the
suite. Shared by numerical-robustness and thread-rng (both keep a finding only when its test
fails on the current code). Not an audit (leading underscore).

Verification, per finding, in the finish stage (the caller sets `finish_install_edi: true`, so
EDI from this commit is installed):

1. The test body is wrapped in `test_that()` with no skip and written to a temp file under
   ctx.workdir.
2. It runs in its own `Rscript` (testthat + EDI attached) with a time limit, and the runner
   writes every expectation's class and message.
3. The finding is kept only if at least one expectation FAILED, none errored or skipped, the
   failure is not a wrong-call message ("could not find function", "unused argument", ...),
   and, when the agent gave `failure_contains`, that text is in a failure message. A test that
   uses expect_error / expect_no_error / expect_silent must give `failure_contains`, since a
   wrong call would fail it too.
4. A kept test is added under R/package_tests/testthat_bulk/ as test-<slug>.R with
   skip("open a release TODO for this") as its first line, so the suite stays green until the
   owner opens a release TODO; R/package_tests/ci/test_runtimes.csv is refreshed so the shard
   planner knows the new file.

If R, testthat or EDI cannot be loaded, nothing is run or added and every proposal is reported
under "Needs a human" as NOT VERIFIED.
"""
import os
import re
import subprocess
import time
from pathlib import Path

import audit_common as ac

BULK = "R/package_tests/testthat_bulk"
SKIP_LINE = 'skip("open a release TODO for this")'
WRONG_CALL = re.compile(
    r"could not find function|unused argument|is not an exported object|object '[^']+' not found|"
    r"argument \"[^\"]+\" is missing, with no default|attempt to apply non-function|there is no package called|"
    r"non-numeric argument to|subscript out of bounds|\$ operator is invalid", re.I)
NEEDS_PATTERN = re.compile(r"\bexpect_(error|no_error|silent|no_warning|warning|condition|no_condition)\s*\(")

RUNNER = r"""
args = commandArgs(trailingOnly = TRUE)
test_path = args[[1]]
out_path = args[[2]]
load_edi = identical(args[[3]], "1")
suppressPackageStartupMessages(library(testthat))
if (load_edi) suppressPackageStartupMessages(library(EDI))
clean = function(x) gsub("[\r\n\t]+", " ", paste(x, collapse = " "))
rows = character(0)
res = tryCatch(
	testthat::test_file(test_path, reporter = "silent", stop_on_failure = FALSE),
	error = function(e) {
		rows <<- c(rows, paste0("error\t", clean(conditionMessage(e))))
		NULL
	}
)
if (!is.null(res)) {
	for (t in res) {
		for (e in t$results) {
			kind = if (inherits(e, "expectation_failure")) "fail"
				else if (inherits(e, "expectation_error")) "error"
				else if (inherits(e, "expectation_skip")) "skip"
				else if (inherits(e, "expectation_warning")) "warning"
				else "pass"
			rows = c(rows, paste0(kind, "\t", clean(conditionMessage(e))))
		}
	}
}
writeLines(rows, out_path)
"""


def r_test_name(s):
    s = re.sub(r"\s+", " ", str(s or "")).strip() or "audit finding"
    return s.replace("\\", "\\\\").replace('"', '\\"')[:150]


def slugify(s):
    s = re.sub(r"[^a-z0-9]+", "-", str(s or "").lower()).strip("-")
    s = re.sub(r"todo-?\d+-?", "", s).strip("-")           # never a TODO number in a test file name
    s = re.sub(r"-+", "-", s)
    return (s or "audit-finding")[:90].strip("-")


def indent(body):
    lines = str(body or "").replace("\r\n", "\n").strip("\n").splitlines()
    return "\n".join(("\t" + l) if l.strip() else "" for l in lines)


def test_text(name, body, skip=False):
    head = f'test_that("{r_test_name(name)}", {{\n'
    return head + (f"\t{SKIP_LINE}\n" if skip else "") + indent(body) + "\n})\n"


def comment_block(lines):
    out = []
    for l in lines:
        for piece in re.sub(r"\s+", " ", str(l)).strip().split("\n"):
            while len(piece) > 100:
                cut = piece.rfind(" ", 0, 100)
                cut = cut if cut > 20 else 100
                out.append("# " + piece[:cut].rstrip())
                piece = piece[cut:].lstrip()
            out.append(("# " + piece).rstrip())
    return "\n".join(out) + "\n"


def parse_rows(text):
    counts = {"fail": 0, "error": 0, "skip": 0, "warning": 0, "pass": 0}
    msgs = []
    for line in (text or "").splitlines():
        kind, _, msg = line.partition("\t")
        if kind in counts:
            counts[kind] += 1
            if kind != "pass":
                msgs.append((kind, msg))
    return counts, msgs


def r_available(load_edi=True, timeout=180):
    """(ok, reason)."""
    code = "suppressPackageStartupMessages(library(testthat))"
    if load_edi:
        code += "; suppressPackageStartupMessages(library(EDI))"
    try:
        r = subprocess.run(["Rscript", "-e", code + '; cat("ok")'], capture_output=True, text=True,
                           timeout=timeout)
    except (OSError, subprocess.TimeoutExpired) as e:
        return False, f"Rscript could not run ({e.__class__.__name__})"
    if r.returncode or "ok" not in r.stdout:
        return False, "R could not load testthat" + (" and EDI" if load_edi else "") + ": " + \
            (r.stderr.strip().splitlines() or ["no message"])[-1][:200]
    return True, ""


def run_test(workdir, key, name, body, timeout=240, load_edi=True):
    """Run one test (no skip). Returns {"counts", "messages", "timed_out", "seconds", "path"}."""
    d = Path(workdir) / "verify"
    d.mkdir(parents=True, exist_ok=True)
    runner = d / "run_one_test.R"
    if not runner.exists():
        runner.write_text(RUNNER)
    tp = d / f"test-{key}.R"
    tp.write_text(test_text(name, body))
    op = d / f"result-{key}.txt"
    if op.exists():
        op.unlink()
    t0 = time.time()
    timed_out = False
    try:
        subprocess.run(["Rscript", str(runner), str(tp), str(op), "1" if load_edi else "0"],
                       capture_output=True, text=True, timeout=timeout,
                       env={**os.environ, "NOT_CRAN": "true"})
    except subprocess.TimeoutExpired:
        timed_out = True
    counts, msgs = parse_rows(op.read_text() if op.exists() else "")
    return {"counts": counts, "messages": msgs, "timed_out": timed_out,
            "seconds": round(time.time() - t0, 1), "path": str(tp)}


def judge(run, finding):
    """(kept: bool, reason)."""
    c, msgs = run["counts"], run["messages"]
    if run["timed_out"]:
        return False, f"the test hit the {run.get('timeout', 'time')} limit"
    if sum(c.values()) == 0:
        return False, "the test ran no expectations (it may not parse, or R crashed)"
    if c["error"]:
        m = next((m for k, m in msgs if k == "error"), "")
        return False, f"the test errored instead of failing an expectation: {m[:300]}"
    if c["skip"]:
        return False, "the test skipped itself"
    if not c["fail"]:
        return False, "the test passed on the current code"
    fails = [m for k, m in msgs if k == "fail"]
    joined = " ".join(fails)
    if WRONG_CALL.search(joined):
        return False, f"the failure looks like a wrong call, not the bug: {fails[0][:300]}"
    want = (finding.get("failure_contains") or "").strip()
    if NEEDS_PATTERN.search(finding.get("test_code", "")) and not want:
        return False, "the test checks for an error or condition but gives no failure_contains to tell the bug from a wrong call"
    if want and want not in joined:
        return False, f"the failure message does not contain {want!r}: {fails[0][:300]}"
    return True, fails[0][:300]


def unique_test_path(repo, slug, taken):
    base = f"{BULK}/test-{slug}"
    p, i = f"{base}.R", 2
    while p in taken or (Path(repo) / p).exists():
        p, i = f"{base}-{i}.R", i + 1
    taken.add(p)
    return p


def refresh_runtime_manifest(repo):
    script = Path(repo) / "R/package_tests/ci/refresh_manifest.py"
    if not script.exists():
        return "R/package_tests/ci/refresh_manifest.py not found; test_runtimes.csv not refreshed"
    r = subprocess.run(["python3", str(script)], cwd=repo, capture_output=True, text=True)
    return "" if r.returncode == 0 else f"refresh_manifest.py failed: {r.stderr.strip()[-300:]}"


def finding_label(f):
    loc = f.get("location") or f.get("unit", "")
    return f"`{loc}` ({f.get('kind', 'finding')}): {f.get('text', '').strip()}"


def apply_tests(ctx, results, title, per_test_timeout=240, total_budget=1800, availability=None,
                runner=None, today=None):
    """The apply stage for an audit whose findings are failing tests.

    `availability` and `runner` are injectable for the unit tests (default: r_available,
    run_test). Returns the parts dict audit_run.finish expects.
    """
    availability = availability or r_available
    runner = runner or run_test
    today = today or ctx.now.date().isoformat()
    findings = []
    for r in results:
        for f in r.get("findings") or []:
            if isinstance(f, dict):
                findings.append(f)
    applied, human, proposed = [], [], []
    summary = [f"{len(findings)} proposed finding(s) with a test."]
    if not findings:
        return {"summary": summary[0], "applied": [], "mechanical": [], "human": [], "proposed": []}

    ok, why = availability()
    if not ok:
        for f in findings:
            human.append(ac.decision(f"NOT VERIFIED ({why}): {finding_label(f)}", unit=f.get("unit"), key="not-verified"))
            proposed.append({**f, "status_note": "not verified"})
        summary.append("R or EDI was not available, so no test was run and nothing was added.")
        return {"summary": " ".join(summary), "applied": [], "mechanical": [], "human": human,
                "proposed": proposed}

    start, taken, kept = time.time(), set(), 0
    for i, f in enumerate(findings, 1):
        label = finding_label(f)
        body = f.get("test_code") or ""
        if not body.strip():
            human.append(ac.decision(f"NOT VERIFIED (no test code): {label}", unit=f.get("unit"), key="not-verified"))
            proposed.append(f)
            continue
        if time.time() - start > total_budget:
            human.append(ac.decision(f"NOT VERIFIED (the run's {total_budget // 60}-minute test budget was used up): {label}", unit=f.get("unit"), key="not-verified"))
            proposed.append(f)
            continue
        run = runner(ctx.workdir, f"{i:03d}", f.get("test_name") or f.get("text"), body, per_test_timeout)
        run.setdefault("timeout", f"{per_test_timeout} s")
        keep, reason = judge(run, f)
        if not keep:
            human.append(ac.decision(f"Not kept ({reason}): {label}", unit=f.get("unit"), key="not-kept"))
            proposed.append({**f, "status_note": "test did not fail as claimed"})
            continue
        rel = unique_test_path(ctx.repo, slugify(f.get("test_file_slug") or f.get("test_name") or f.get("text")),
                               taken)
        header = comment_block([
            f"{title} audit, {today}: {f.get('text', '').strip()}",
            f"Where: {f.get('location') or f.get('unit', '')} (kind: {f.get('kind', 'finding')}).",
            f"On commit {ctx.sha[:12] or 'unknown'} this test failed with: {reason}",
            "Remove the skip() once a release TODO covers this finding, and cite that TODO here "
            "(v<version>-TODO-<n>).",
        ])
        text = header + "\n" + test_text(f.get("test_name") or f.get("text"), body, skip=True)
        ctx.path(rel).parent.mkdir(parents=True, exist_ok=True)
        ctx.path(rel).write_text(text)
        first = text.split("\n\n", 1)[1].splitlines()[0]
        applied.append(f"`{rel}`: {label} (failed with: {reason})")
        proposed.append({**f, "applied_file": rel, "applied_text": first})
        kept += 1
    if kept:
        note = refresh_runtime_manifest(ctx.repo)
        if note:
            human.append(note)
    summary.append(f"{kept} test(s) failed as claimed and were added (skipped until a release TODO "
                   f"is opened); {len(findings) - kept} not kept.")
    return {"summary": " ".join(summary), "applied": applied, "mechanical": [], "human": human,
            "proposed": proposed}
