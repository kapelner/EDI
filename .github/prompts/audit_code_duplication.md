# Code-duplication audit (weekly): triage each duplicated-code candidate

You are one of the agents run by `.github/workflows/audit-code-duplication.yml` (module
`.github/scripts/audits/code_duplication.py`). A mechanical detector (jscpd, then a token diff) found
pairs of code regions in EDI that are copies of each other, most of them with a few lines that differ.
Your job, for each candidate in your batch, is to say what the duplication is.

Why this matters here: copies drift. In 2026-11 InferenceSurvivalLogRank got a sign fix in
`compute_shared_icen()` and its copy in InferenceSurvivalGehanWilcox did not (v1.0.6-TODO-117 and
v1.0.6-TODO-121); the GEE family parse is written out in `R/EDI/src/fast_gee.cpp` and again in
`python/cpp/bindings_incidence.cpp` (v1.0.6-TODO-103); a g-computation jackknife path skipped guards its
sibling had (v1.0.6-TODO-137). Finding the next one of these is the point of the audit.

You can read and search the repository (Read, Glob, Grep). You have no shell, cannot build or run
anything, and must not try to edit files.

## Your inputs

1. Your batch file (named in your task message), `.audit-work/batches/<batch>.json`: `units`, one per
   candidate, each with
   - `id`: the unit id you report back (`dup-<hex>`);
   - `files`: the two regions, `path:first-last`;
   - `kind`: `divergent` (structural differences), `renamed` (only names and literals differ) or `exact`;
   - `diff`: the structural differences, region A lines as `-`, region B lines as `+` (comments and
     whitespace removed, so read the files for the real text), then the renamings on one line;
   - `score`, `shared_lines`, `similarity`, `structural_differences`: what the detector measured;
   - `hints`: facts to weigh (an R/Python boundary, a legacy IVWC class, both regions in one file, a
     possible fast path);
   - `reason`: why it is in this run.
2. `.audit-work/decisions.md`: candidates the owner settled before, and conventions. Respect them.
3. `.audit-work/mechanical.json`: mechanical findings already reported.

## How to judge

Read both regions in full, plus enough around them to know what each function is for (its class,
its callers). Then pick ONE verdict:

- `intentional`: the copy has a reason to exist and nothing has drifted. Typical reasons here:
  - an R/Python boundary: a pybind11 binding in `python/cpp` mirrors an Rcpp entry point in
    `R/EDI/src` because the two front ends cannot share the wrapper; the kernel they call is shared;
  - a performance fast path that duplicates a general path on purpose (say what makes it faster);
  - a frozen legacy IVWC class (`*_ivwc.R`; they are kept unchanged and never published) next to its
    `*OneLik` successor;
  - per-family or per-response-type classes whose differences are the point (different link,
    likelihood or estimand), where a shared helper would need as many switches as it saves lines.
  Say the reason in one sentence.
- `refactor`: nothing is wrong today, but the two copies should share one helper because a future fix
  to one will very likely be missed in the other. Name the helper you would extract and where it
  would live (an existing helper file, a base class, a shared C++ header).
- `divergence_bug`: the copies drifted and one of them is now wrong: one side got a fix, a guard, a
  sign, a default or a warning the other lacks, and the other side's behavior is a bug, not a
  deliberate difference. This verdict needs evidence: the exact lines on both sides (`file:line`), what
  the wrong side does and why it is wrong, and how to see it (the input that shows it, or the test,
  commit, NEWS line or TODO that fixed the other side). If you cannot point to the lines that make it a
  bug, use `refactor` and say what you suspect in `text`.

A difference that is only names (`gw_score` vs `logrank_score`) or literals that differ by design
(`scores = "wmw"` vs `"logrank1"`) is not drift. A structural difference is drift only if the same
reasoning should apply to both sides. Check what you can read (NEWS.md, the release
files under `R/package_metadata/future_release_plans/`, comments citing a `v<version>-TODO-<n>`) to
see whether one side's extra lines are a recorded fix.

## Out of scope

- Proposing the refactor patch. The issue lists verdicts; the owner opens TODOs.
- Duplication between test files, or anything outside the two regions' files beyond what you need to
  judge them.
- Candidates not in your batch.

## Your output (the structured JSON the run asks for)

- `units_checked`: the `id` of every candidate you reached a verdict on.
- `findings`: one entry per checked candidate:
  - `unit`: its `id`;
  - `verdict`: `intentional`, `refactor` or `divergence_bug`;
  - `text`: one to three sentences: the reason (intentional), the helper to extract (refactor), or the
    bug and how to see it (divergence_bug). Cite TODOs as `v<version>-TODO-<n>`;
  - `evidence`: `file:line` references you relied on (required for `divergence_bug`).

Every verdict must rest on code you actually read. If you run out of turns, leave the remaining ids out
of `units_checked`; they come back next run.
