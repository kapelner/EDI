"""Generated-file drift audit (weekly, mechanical only).

Plan: R/package_metadata/new_feature_plans/v1_0_6/audit_jobs_framework.md (Part 4, "Generated-file drift").

Regenerates, in the finish stage, the committed files whose generator needs neither a compiled EDI
nor a timing run, and proposes any difference from what is committed:

- R/fast_roxygenize.R, the repo's own generator (the one scripts/gitpush_with_hooks_safe.sh runs):
  Rcpp::compileAttributes() (R/EDI/R/RcppExports.R, R/EDI/src/RcppExports.cpp; it writes the
  wrappers and compiles nothing) and roxygen2 with the R code sourced, not built (R/EDI/man/*.Rd,
  R/EDI/NAMESPACE);
- the registry block of R/EDI/vignettes/procedure-trust.Rmd, from
  R/package_tests/render_procedure_trust_tables.R (base R; reads the regime registry file only).

Not regenerated here:
- the drift artifacts of R/package_tests/drift_artifacts.sh: their generators load EDI with
  pkgload::load_all(compile = FALSE), which needs a compiled R/EDI/src, and some of them time the
  cases they run (public_argument_combination_slowest_cases.csv). test-coverage-R-advanced.yml
  already regenerates and diffs them on every push;
- the counts block of procedure-trust.Rmd (needs EDI loaded and the calibration scripts);
- the benchmark reports and anything else timed.

The PR is the regenerated files. A regenerated output the owner rejected (PR closed, or the file
reverted on the branch) is not proposed again until the generator writes something different.
"""
import os
import re
import subprocess

import audit_common as ac

SPEC = {
    "name": "generated-drift",
    "title": "Generated-file drift",
    "report": "pr",
    "claude": False,
}

GENERATORS = {
    "roxygen": "R/fast_roxygenize.R (Rcpp::compileAttributes + roxygen2)",
    "trust": "R/package_tests/render_procedure_trust_tables.R (registry block)",
}
# What each generator may write. Anything else that changes is reverted and reported.
OUTPUTS = [
    (re.compile(r"R/EDI/man/[^/]+\.Rd"), "roxygen"),
    (re.compile(r"R/EDI/NAMESPACE"), "roxygen"),
    (re.compile(r"R/EDI/R/RcppExports\.R"), "roxygen"),
    (re.compile(r"R/EDI/src/RcppExports\.cpp"), "roxygen"),
    (re.compile(r"R/EDI/vignettes/procedure-trust\.Rmd"), "trust"),
]
# More changed Rd files than this share of man/ looks like a different roxygen2 version on the
# runner, not drift: nothing under man/ is applied then.
MAX_RD_SHARE = 0.25
TIMEOUT = 25 * 60
# Files the R setup actions write into the checkout (r-lib/actions setup-r-dependencies). They are
# not the generators' output and must not reach the PR.
SETUP_LEFTOVERS = re.compile(r"(?:^|.*/)\.github/(?:pkg\.lock|R-version|depends\.Rds)")

TRUST_R = r"""
env = new.env()
sys.source("R/package_tests/render_procedure_trust_tables.R", envir = env)
reg = env$trust_load_registry(".")
path = env$trust_vignette_path(".")
lines = readLines(path, warn = FALSE)
lines = env$trust_splice_block(lines, "registry", env$trust_render_registry_block(reg))
writeLines(lines, path)
"""


def _run(cmd, cwd, log):
    try:
        r = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, timeout=TIMEOUT)
    except FileNotFoundError as e:
        return 127, str(e)
    except subprocess.TimeoutExpired:
        return 124, f"timed out after {TIMEOUT} s"
    text = (r.stdout or "") + (r.stderr or "")
    log.write_text(text)
    return r.returncode, text


def run_generators(ctx):
    """Run every generator in the work tree. Returns {generator: (exit status, log text)}.

    Tests replace this function."""
    ctx.workdir.mkdir(parents=True, exist_ok=True)
    return {
        "roxygen": _run(["Rscript", "fast_roxygenize.R"], ctx.repo / "R", ctx.workdir / "roxygen.log"),
        "trust": _run(["Rscript", "-e", TRUST_R], ctx.repo, ctx.workdir / "trust.log"),
    }


def roxygen_version(ctx):
    r = subprocess.run(["Rscript", "-e", 'cat(as.character(packageVersion("roxygen2")))'], cwd=ctx.repo,
                       capture_output=True, text=True)
    return r.stdout.strip() if r.returncode == 0 else "unknown"


def log_warnings(text, limit=15):
    """Lines of a generator log that report a problem (roxygen2 prints them with a cross or 'Warning')."""
    pat = re.compile(r"^\s*(?:✖|x |Warning|Error|warning:)", re.I)
    lines = [l.strip() for l in text.splitlines() if pat.match(l)]
    return lines[:limit], max(0, len(lines) - limit)


def changed_files(repo):
    """(status, path) for every change in the work tree, renames split into delete + add."""
    out = []
    for line in ac.git("status", "--porcelain", "--untracked-files=all", cwd=repo).splitlines():
        st, path = line[:2], line[3:]
        if " -> " in path:
            a, b = path.split(" -> ", 1)
            out += [("D", a), ("A", b)]
        else:
            out.append(("??" if st == "??" else st.strip() or "M", path.strip('"')))
    return out


def owner_of(path):
    for pat, gen in OUTPUTS:
        if pat.fullmatch(path):
            return gen
    return None


def revert(repo, status, path):
    if status == "??":
        try:
            (repo / path).unlink()
        except OSError:
            pass
    else:
        ac.git("checkout", "--", path, cwd=repo, check=False)


def first_added_line(repo, path):
    """A line the regenerated file has and the committed one does not (for marking the fix later)."""
    diff = ac.git("diff", "-U0", "--", path, cwd=repo, check=False)
    for line in diff.splitlines():
        if line.startswith("+") and not line.startswith("+++") and line[1:].strip():
            return line[1:]
    return None


def only_roxygen_note(repo):
    """True if DESCRIPTION's only change is the version line roxygen2 writes (RoxygenNote up to
    7.x, Config/roxygen2/version from 8.0)."""
    diff = ac.git("diff", "-U0", "--", "R/EDI/DESCRIPTION", cwd=repo, check=False)
    body = [l for l in diff.splitlines() if l[:1] in "+-" and not l.startswith(("+++", "---"))]
    return bool(body) and all(re.match(r"[+-](RoxygenNote|Config/roxygen2/version):", l) for l in body)


def mechanical(ctx):
    return []


def apply(ctx, results, mech):
    repo = ctx.repo
    before = []
    for status, path in changed_files(repo):
        if status == "??" and SETUP_LEFTOVERS.fullmatch(path):
            revert(repo, status, path)
        else:
            before.append((status, path))
    if before:
        return {"summary": "The work tree was not clean before the generators ran; nothing was regenerated.",
                "human": [f"`{p}` ({s})" for s, p in before[:20]], "applied": [], "mechanical": [],
                "proposed": []}
    runs = run_generators(ctx)
    rejected = {h["id"] for h in ctx.notes.findings() if h.get("status") == "rejected"}
    applied, human, mechanical, proposed, notes = [], [], [], [], []

    failed = set()
    for gen, (code, text) in runs.items():
        warn, more = log_warnings(text)
        for w in warn:
            mechanical.append(f"{GENERATORS[gen]}: {w}")
        if more:
            mechanical.append(f"{GENERATORS[gen]}: {more} more problem line(s) in the run log")
        if code:
            failed.add(gen)
            tail = " / ".join(l.strip() for l in text.strip().splitlines()[-3:])[:400]
            human.append(f"{GENERATORS[gen]} failed (exit {code}): {tail}; its outputs were not applied")

    changes = changed_files(repo)
    rd_total = len(list((repo / "R/EDI/man").glob("*.Rd"))) or 1
    rd_changed = [p for s, p in changes if owner_of(p) == "roxygen" and p.endswith(".Rd")]
    rd_blocked = len(rd_changed) > MAX_RD_SHARE * rd_total
    if rd_blocked:
        human.append(f"roxygen2 {roxygen_version(ctx)} on the runner changes {len(rd_changed)} of {rd_total} Rd "
                     "files, which looks like a different roxygen2 version from the one the committed files "
                     "were written with, not drift. Nothing under man/ or NAMESPACE was applied; regenerate "
                     "locally with `Rscript fast_roxygenize.R` from R/ if the change is wanted.")

    for status, path in changes:
        gen = owner_of(path)
        if path == "R/EDI/DESCRIPTION" and only_roxygen_note(repo):
            revert(repo, status, path)
            notes.append("roxygen2 wrote its version line into DESCRIPTION; left out")
            continue
        if gen is None:
            revert(repo, status, path)
            human.append(f"`{path}` changed although no generator here should write it; reverted")
            continue
        if gen in failed or (rd_blocked and gen == "roxygen" and (path.endswith(".Rd") or path.endswith("NAMESPACE"))):
            revert(repo, status, path)
            continue
        content = ctx.read(path)
        out_hash = ac.text_hash(content) if content is not None else "deleted"
        what = {"??": "new file", "D": "deleted"}.get(status, "regenerated")
        text = f"{what}: differs from what {GENERATORS[gen]} writes (output {out_hash[:10]})"
        f = {"unit": path, "kind": "drift", "text": text, "generator": gen}
        if ac.finding_id(SPEC["name"], path, "drift", text) in rejected:
            revert(repo, status, path)
            notes.append(f"`{path}`: this output was rejected before; not proposed again")
            continue
        applied.append(f"`{path}`: {what} by {GENERATORS[gen]}")
        added = first_added_line(repo, path) if status != "D" else None
        if status == "??" and content:
            added = next((l for l in content.splitlines() if l.strip()), None)
        if added is not None:
            f.update(applied_file=path, applied_text=added)
        proposed.append(f)

    summary = [f"Regenerated with {', '.join(GENERATORS.values())}.",
               f"{len(applied)} file(s) differ from what is committed."
               if applied else "Every regenerated file matches what is committed."]
    summary += [n + "." for n in notes]
    summary.append("Not regenerated: the drift artifacts of R/package_tests/drift_artifacts.sh (they need a "
                   "compiled EDI and some are timed; test-coverage-R-advanced.yml diffs them on every push), "
                   "the counts block of procedure-trust.Rmd, and the benchmark reports.")
    return {"summary": "\n".join(summary), "applied": applied, "mechanical": mechanical, "human": human,
            "proposed": proposed}
