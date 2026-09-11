# Optimal Design × Inference Finder — Continuous Large-Scale Simulation Benchmark

> **Depends on:** `SimulationFramework` (`R/EDI/R/simulations_framework.R`)
> as the core computational primitive — this plan is an orchestration and
> publishing layer on top of it, not a new simulation engine.
> `discover_applicable_inference_classes()`
> (`R/EDI/R/inference_suite.R:136`) and `applicable_inference_class_names_for_design()`
> (`R/EDI/R/design_abstract.R:624`) for scenario-grid validity — reused,
> never hand-maintained. **Revision history matters here — read before
> trusting any single section**: publication was first scoped as GitHub
> Pages, then (user decision) revised to an Artifact-`db`-coordinated
> design, then (user decision, genuinely open participation) revised again
> to public Parquet/CSV in a public GitHub repo, queried directly — §4/§5
> hold the current, superseding design; earlier revisions are kept
> legible in each section's own heading rather than silently erased, per
> this session's own established convention. **Release target: not
> assigned** — unlike every other plan scoped this session, no release
> placement was requested; TODO-1 records this as an open decision rather
> than assuming one. (Global ordering: see `_master.md`.)

Written 2026-09-11 (user request: "a giant simulation to find the best
designs x inference combinations for a variety of datasets for all
response types," running continuously with results auto-published,
**genuinely open participation**, queryable by anyone by dataset type,
response type, inference model type, and inference action type).

## Scope

EDI already lets a user run `SimulationFramework` for *one* design ×
inference × response-type combination at a time, on demand. What doesn't
exist: a systematic, at-scale empirical benchmark across the *entire*
combinatorial space of what EDI already ships, answering "for a dataset
shaped like *this*, which design + inference combination actually performs
best, and by how much." This is a research/benchmarking artifact — it
informs documentation, sensible defaults, and future methods papers — not
a new statistical method and not new package functionality.

## 1. What already exists (reuse, don't rebuild)

- **`SimulationFramework`** — the engine that fits `(design, inference,
  response_type)` at a chosen `(n, p, effect size, ...)` many times and
  reports power, empirical size (with a test against nominal), coverage
  (with a test against nominal), MSE, and CI length per cell (verified
  this session against `SimulationFrameworkReport$summarize()`'s actual
  output while scoping `simulation_framework_visualization.md`). This
  plan schedules many more of these cells, it does not reimplement what a
  cell computes.
- **`discover_applicable_inference_classes(des_obj)`** and
  `applicable_inference_class_names_for_design()` — already resolve which
  of the package's inference classes are structurally valid for a given
  design (compatible design family, required packages installed, no
  response-type mismatch). The scenario grid below is built *from* this
  discovery, never a hand-maintained cross-product — the same discipline
  every registry-driven feature this session followed.
- **The `package_tests/` CSV-tracking culture** —
  `comprehensive_suite_registry.csv`, `public_api_inventory.csv`, and the
  pre-push hook that auto-regenerates drifted CSVs (per this repo's git
  log: "pre-push: auto-regenerate drifted package_tests CSVs") are direct
  precedent for "a generated, periodically-refreshed artifact tracked
  against source of truth" — this plan's accumulated-results store and
  leaderboard report follow the same shape, at a larger scale and on a
  schedule rather than per-push.

## 2. The combinatorial scenario space

Axes: response type (6: continuous, incidence, count, proportion,
survival, ordinal), design class (every concrete `Design*`, fixed and
sequential), inference class (up to 102 concrete classes — see
`model_diagnostics_framework.md` §3B/§3C for the verified count — though
per-response-type/per-design applicability discovery narrows this sharply
for any given cell), and data-generating parameters (`n`, `p`, effect
size, covariate correlation structure, distributional shape/skew,
missingness rate; for survival specifically, censoring rate and pattern).

The full Cartesian product is computationally intractable to run
exhaustively, let alone "continuously forever" — this needs a
prioritization strategy, not brute force:

- **v1 (this plan's actual scope):** stratified random sampling of
  scenario cells, weighted toward (a) response-type/design combinations
  with the most applicable inference classes (highest information value
  per cell fitted) and (b) cells with the fewest accumulated replicates
  so far (breadth-first coverage before depth).
- **Explicitly deferred, not v1:** adaptive / Bayesian-optimization-style
  cell selection — prioritizing regions of the scenario space where the
  current leaderboard is most uncertain, or where two combinations are
  close competitors and more replicates would actually change the
  ranking. Flagged as a real, separate research question; scoping it
  requires its own design pass once v1's simpler sampling is running and
  its actual coverage rate is measured.

## 3. Ranking criterion — a leaderboard, not a single "winner"

No single scalar score. Every scenario profile's report row shows, per
competing combination:

- **Power** at fixed nominal type-I error — the standard RCT-design
  criterion, and the most intuitive "which one wins" number.
- **Empirical type-I error / coverage accuracy** — a combination whose
  actual error rate exceeds nominal is disqualified from "best" outright,
  not merely penalized; power achieved by an invalid test isn't power.
- **MSE** and **CI length** — catches combinations that are "powerful" via
  a biased or needlessly wide estimator.
- **Wall-clock compute cost per fit** — a combination 2% more powerful but
  50× slower is not an unambiguous "better" recommendation for a
  practitioner; report it, don't hide it.

This mirrors a pattern this session kept landing on independently —
`InferenceSuite`'s Cauchy-combination design and `model_diagnostics_framework.md`'s
severity taxonomy both resist collapsing multiple valid signals into one
blended verdict. A leaderboard row here does the same: full information,
reader weighs the trade-off.

## 4. Architecture — a genuinely public, queryable dataset (second revision: Artifact `db` ruled out, not merely adjusted)

**Why the Artifact `db` design is abandoned here, not patched.** `db.d.ts`
states plainly: "a declaring artifact is organization-internal and cannot
be shared publicly, so every reader and writer is a signed-in member of
the owner's organization." That is not a configuration choice to work
around — it is what the capability *is*. Once the actual goal is
genuinely open participation and public queryability (this session's
clarification), no amount of schema redesign fixes an access boundary;
the mechanism itself has to change. §4/§5 of the prior revision (the
`db`-backed task/batch schema, the compaction job) are superseded, not
extended, by what follows.

**The mechanism: public, columnar data files in a public GitHub repo,
queried directly — no server, no API, no login.**

- Results are committed as **Parquet** (preferred — columnar, compresses
  well, and every mainstream query tool reads it directly over HTTPS) or
  CSV, **partitioned by `response_type` and `design_class`** (e.g.
  `results/response_type=survival/design_class=DesignFixedBernoulli/*.parquet`)
  so a query touching one slice doesn't have to scan everything.
- **Row shape is exactly what was proposed two turns ago, extended with
  provenance fields the open-contribution model now requires** (the
  original metric/key columns were always right — only the storage layer
  under them changed, and one thing was missing: the row didn't yet say
  *which version of EDI* produced it, load-bearing once results come from
  outside contributors on their own checkouts, added per direct user
  decision): `response_type`, `design_class`, `inference_class`,
  **`inference_type`** (the specific computation path/action within a
  class — `ci_method`/`pval_method`, e.g. `"rand"`, `"boot"`, `"asymp"` —
  already a tracked column in `SimulationFramework`'s own output, per §1;
  this is the literal answer to "inference action type"), the
  dataset/scenario-generating parameters (`n`, `p`, effect size, ...), the
  §3 metrics (`power`, `size`, `size_pval`, `coverage`, `coverage_pval`,
  `mse`, `ci_length`, `time_sec`), and **provenance**: `edi_commit` (full
  git SHA, not just the `DESCRIPTION` version string, since two commits
  can share a version number between releases), `r_version`, `os`, and
  the `seed` used. `edi_commit` is also directly useful for querying, not
  just integrity — it lets a query pin to one commit ("what does the
  *current* code actually achieve") or group by commit over time ("has
  this class's power changed across releases"), which the flat metric
  columns alone couldn't answer.
- **Anyone can query it with zero setup**, which is the literal ask:
  DuckDB's `httpfs` extension (or `pandas.read_parquet`, or R's `arrow`
  package) reads a Parquet file straight off a `raw.githubusercontent.com`
  URL —
  `SELECT * FROM read_parquet('https://raw.githubusercontent.com/.../results/**/*.parquet')
  WHERE response_type = 'survival' AND inference_class = 'InferenceSurvivalCoxPHRegr'`
  — no API key, no rate limit beyond GitHub's own CDN, no account.
  Partitioning by `response_type`/`design_class` in the path means a
  filtered query like that one only fetches the matching files, not the
  whole dataset.
- **A thin, optional dashboard** (an Artifact page, or a GitHub Pages
  page — either works equally well here since neither needs a privileged
  capability) can render a summary leaderboard by fetching the same
  public Parquet/CSV directly (plain `fetch()`, or a WASM query engine
  running client-side) — genuinely public because the *data* is public,
  not because of anything the page itself grants. This is a presentation
  layer over the real store, not the store.

**Reused, not rebuilt:** `SimulationFramework` still does the actual
fitting-many-replicates work (§1) — this architecture only changes where
its output *lands*, not how it's computed.

## 5. Contribution: genuinely open, with integrity checked rather than assumed

**Mechanism: a public GitHub Actions workflow anyone can trigger from
their own fork** — `workflow_dispatch`, or a PR-based flow (contributor
opens a PR adding their result file; CI validates it; a maintainer or a
bot merges) — the standard, well-understood open-source pattern for
accepting external contributions, and unlike the `db`-worker design, it
needs **no Claude Code session and no agent in the loop** for a
contributor to participate: clone, run the R script, submit. This is a
meaningfully lower participation bar than the previous design, which is
the right direction for "genuinely open."

**Integrity, since "anyone can write" is a real risk this design must
answer, not one the org-gated version had to face.** A contributor's
submitted numbers must be checked before they join a public benchmark
dataset people will query and trust — this is not optional for a
"high-quality" claim with anonymous contributors, confirmed directly.
But CI cannot re-run *every* submitted row itself: that would mean CI
doing 100% of the compute a second time, which defeats the actual point
of distributing it in the first place (a direct, correct challenge to an
earlier draft of this section). The fix is the standard volunteer/
distributed-computing trust model — spot-check, not full redundant
computation, weighted by how proven a contributor is, plus let
independent contributors corroborate each other for free:

- **New or low-trust contributor**: CI verifies a *high* fraction (up to
  all) of their first handful of submissions — cheap in absolute terms,
  since a brand-new contributor's early volume is naturally small, and
  it's exactly where the risk of a first bad-faith or badly-configured
  submission is highest.
- **Established contributor with a track record of passing checks**:
  CI's ongoing verification rate drops to a small random sample (a
  single-digit percentage, tuned once real submission volume exists) —
  a credible deterrent, not exhaustive re-computation. Anyone submitting
  at real scale has a low but non-trivial per-submission chance of being
  checked, and a near-certain chance of eventually being caught if they
  cheat systematically.
- **Cross-contributor agreement, essentially free.** Because §5's
  coordination model already treats overlapping contributions as added
  precision rather than a race to avoid, two independent contributors
  submitting the same cell is a *normal*, even encouraged, outcome — not
  a special case built for this purpose. When it happens, their numbers
  should agree within tolerance; a disagreement is itself a quality
  signal (flag that cell, trigger a targeted CI check) that cost nothing
  extra to obtain, since neither submission was made *for* checking.
- **Anomaly-triggered checks, independent of trust tier**: a submission
  that's a statistical outlier against comparable cells or against that
  contributor's own history gets checked regardless of how established
  the contributor otherwise is.
- **What actually makes frequent checking cheap: verify a deterministic
  prefix, not the full replicate count — not exotic cryptography, just
  the seed structure already in place.** Direct answer to "is there a
  cryptographic trick for fast verification": the heavyweight tools for
  this exist but don't fit — zero-knowledge proofs of arbitrary
  computation (zk-SNARKs/zkVMs) are built for circuit-friendly,
  fixed-point/integer computation, and proving BLAS-heavy floating-point
  numerical code through one today would be a major, disproportionate
  research effort, likely slower than just re-running it; Trusted
  Execution Environments (hardware attestation, e.g. SGX/Nitro Enclaves)
  are a real, lighter alternative but require contributors to run inside
  specific attestable hardware/cloud instances — trading cheap
  verification for a meaningfully higher participation bar, directly
  against the "genuinely open, anyone" goal. Neither is proposed here.
  What's actually available is simpler and already implied by
  §5's/`draw_binary_match_assignments_cpp`'s own seed derivation
  (`master_seed + splitmix64(replicate_index)`, cited above): replicate
  `k` of a properly-seeded run depends only on the master seed and `k`
  itself, **not** on how many total replicates were requested — so the
  first, say, 100 replicates of a contributor's 10,000-replicate
  submission are byte-identical to the first 100 replicates of a
  from-scratch run with the same seed asking for only 100. CI verifies
  that short prefix — orders of magnitude cheaper than the contributor's
  full run — rather than the whole submission. A systematic bug or a
  fabricated result overwhelmingly shows up in *any* prefix, since it
  isn't a late-replicate-only phenomenon; a genuinely subtle,
  replicate-index-dependent discrepancy that only appears past replicate
  100 is the one failure mode this doesn't catch, which is exactly what
  the trust-tier escalation and anomaly-triggered checks above are for —
  belt and suspenders, not a single silver bullet.
- **A cheap, complementary integrity primitive that genuinely is
  cryptographic — tamper-evidence, not correctness-proof.** Have a
  contributor submit a hash (e.g. SHA-256) of their *full* raw
  per-replicate output alongside the aggregated row. This doesn't prove
  the computation was done correctly — a wrong build produces a
  perfectly well-formed, self-consistent hash of its own wrong numbers —
  but it does mean the aggregated metrics in the public dataset provably
  match what was actually computed at submission time, closing off a
  different attack (editing the reported numbers after the fact without
  redoing the run). Cheap to compute and to check; worth including
  alongside the prefix-check, not instead of it.
- **Net effect**: CI's own compute stays a small fraction of total
  contributed compute — the actual point of distributing the work is
  preserved — while every submission still carries *some* chance of
  being checked, and systematic bad-faith submission at any real scale is
  caught with high probability, not merely deterred by an unenforced
  policy. This is the actual gate, not merely a format check — but per
  direct user instruction, "deterministic given a seed" needs to actually
  hold **across every method and every operating
system**, not just be assumed, so it was checked against the real code
rather than taken on faith:

- **The good news, with a concrete citation.** At least one C++ kernel
  (`draw_binary_match_assignments_cpp`,
  `R/EDI/src/binary_match_search.cpp:33`) already does exactly the right
  thing for parallel reproducibility: it draws one master seed serially
  from R's own RNG (`Rcpp::RNGScope` + `R::unif_rand()`, properly
  bracketed), then derives each parallel replicate's substream
  deterministically as `splitmix64_seed(master_seed + j)` — never calling
  R's (thread-unsafe) RNG concurrently inside the OpenMP loop. This is
  the textbook-correct pattern, and its derivation is pure arithmetic on
  the replicate index, not dependent on thread scheduling or completion
  order. A `test-seed-determinism.R` suite already exists
  (`R/package_tests/testthat_bulk/`) — the integrity check should extend
  it, not invent a parallel testing story.
- **The real, concrete risk this session's research surfaced:**
  `SimulationFramework$run()` picks its parallelism backend **by OS** —
  `parallel::makeForkCluster()` on Unix only, the cross-platform `mirai`
  package otherwise (`R/EDI/R/simulations_framework.R:833`). Two
  structurally different execution paths producing the "same" seeded run
  is exactly the kind of place cross-platform determinism could
  plausibly break, and nothing found this session proves the two
  backends assign identical seeds to identical logical replicates.
  **Practical fix, not a research project:** CI's verification re-run
  forces `num_cores = 1` (serial), which `SimulationFramework` already
  supports as an ordinary parameter — sidesteps the fork-vs-`mirai`
  question entirely for the one thing that actually needs to be exact,
  rather than trying to prove both backends agree. A contributor's
  *original* submission is free to use whatever parallelism they want for
  speed; only CI's check needs to be serial.
- **Exact bit-equality is the wrong bar; this repo already knows that.**
  BLAS/compiler/SIMD differences across platforms and architectures can
  shift floating-point results in the last few bits even with identical
  RNG draws — `performance_profiling_and_upgrades.md`'s own standing
  constraint already concedes this for at least one kernel family
  ("libmvec, ≤4 ulp result differences... ships opt-in or as a documented
  default change with re-justified equivalence tolerances"). The
  integrity check should compare **within a stated numerical tolerance**,
  the same discipline, not bit-for-bit — and pin `r_version` in the
  comparison, since R's own RNG algorithm defaults have changed across R
  versions historically.
- **This is a confirmed, currently-failing bug, not a hypothetical to
  audit for (TODO-4) — checked directly, per a direct user question.**
  `R/package_tests/testthat_bulk_quarantine/test-inference-suite-run-all-inference-seq-vs-parallel.R`
  targets exactly this comparison for `InferenceSuite$run_all_inference()`
  — and is quarantined (that directory's own README: "never run by GitHub
  CI or the `.githooks/pre-push` hook") because it currently fails. Per
  its header comments: CI run `33072346506` (2026-08-27) found "a real,
  non-hanging pval mismatch between `num_cores = 1` and `num_cores = 2`,"
  and a second check in the same file found "NA-count and 'status'
  mismatches even with `EDI_TESTING_DISABLE_FORK_CLUSTER = 'true'`" —
  meaning it is **not** just the already-tracked fork-deadlock hazard
  (`parallel_fork_cluster_test_safety.md`), but a separate, deeper,
  **not-yet-root-caused** divergence in the task-building/result-reassembly
  logic itself. The actively-running `test-seed-determinism.R` gives no
  cover here either — it exercises only `num_cores = 1L` throughout
  (verified by direct inspection), so it cannot and does not catch this.
  **Practical consequence for this plan, stated plainly: genuinely open,
  parallel-friendly contribution is not safe to launch until this is
  root-caused.** A contributor computing under `num_cores > 1` (the
  whole point of contributing spare compute) could have their entirely
  legitimate submission fail CI's serial-verification check for reasons
  that have nothing to do with fraud — or worse, if verification isn't
  careful, a wrong parallel-computed result could look "confirmed" against
  an equally-wrong parallel re-check. The only currently-safe interim
  posture: **require `num_cores = 1` for every accepted submission**
  until this bug is fixed, accepting slower individual contributions as
  the cost of a trustworthy dataset, rather than treating parallel
  contribution as safe by assumption. And even once fixed, coverage
  should extend past this one entry point — no dedicated seq-vs-parallel
  test was found for individual `Inference*` classes' own bootstrap/
  randomization/jackknife paths or for `SimulationFramework`'s internal
  parallelism, and no cross-platform (same seed, same `num_cores`,
  different OS) test was found at all, quarantined or active.
- **Build cost — a CI-minutes/throughput question, not a `CLAUDE.md`
  concern.** Verifying a submission against its claimed `edi_commit`
  means CI can build/install *that* commit, not just current `HEAD` — a
  real cost per unique commit, but on GitHub-hosted runners, not the
  user's own machine — `EDI/CLAUDE.md`'s standing rule against full
  rebuilds is specifically about not locking up the user's local
  development machine (the file says so directly: the concern is a
  second build racing the user's own tooling), and GitHub CI is exactly
  the ephemeral, dedicated compute that rule was never written to
  restrict; corrected after a direct user clarification rather than
  assumed. The real, separate reason to still bound this: GitHub Actions
  has finite per-job time limits and a monthly minutes budget regardless
  of whose machine it is, so rebuilding from scratch per submission is
  still wasteful throughput-wise, not a correctness or policy problem.
  The practical mitigation is the same either way: accept submissions
  against a small, "blessed" set of commits (tagged releases, or periodic
  snapshots of `main`) rather than arbitrary history, so CI needs a small
  number of pre-built (and cacheable) reference environments, not a fresh
  build per submission — good CI hygiene, not a compliance requirement.

**Coordination, reframed rather than engineered around.** The previous
design treated two contributors computing the same cell as a race to
avoid ("wasted redundant compute"). That framing was specific to a
private worker pool paying its own compute cost for no additional
statistical benefit. Under genuinely open contribution, it's the wrong
frame: **more independent replicates of the same cell is strictly more
Monte Carlo precision, not waste** — the aggregation step (whatever
periodically rebuilds the leaderboard from the accumulated Parquet files)
should *pool* same-cell submissions into a running estimate rather than
treat a second submission as redundant. No atomic claim is needed at all;
what's actually useful is a **visible priority list** (rendered on the
dashboard, computed from the current public dataset: which
response-type/design/inference/scenario cells have the fewest
accumulated replicates so far) so contributors' effort concentrates where
it adds the most value, without anyone needing to "claim" anything
first.

## Non-goals

- **Not a runtime "recommend a design for my data" API.** This is a
  research/benchmarking artifact that informs documentation, defaults,
  and future work — not a new user-facing function a caller queries at
  fit time. That would be a much larger, separately-scoped commitment
  (a live recommendation contract, versioning as the leaderboard changes
  underneath it, etc.) and isn't proposed here.
- **Not proposing any new `Design` or `Inference` class.** Purely a
  benchmark of what already exists; the scenario grid is built from
  discovery over the current registries, not a wishlist of what should
  exist.
- **Not scoped to real/external datasets in v1.** Synthetic
  data-generating processes only, matching `SimulationFramework`'s
  existing paradigm and avoiding new data-provenance/licensing questions.
  Folding in reference real-world datasets (e.g. from published trials)
  is a flagged possible future extension, not committed here.

## Tests / validation

- **Discovery correctness**: every scenario cell anyone can contribute
  results for is a structurally valid `(design, inference, response_type)`
  combination per the existing discovery functions (§1) — the PR-validation
  CI rejects a submission naming an inapplicable combination, never a
  hand-maintained list that can drift from the actual registries.
- **Reproducibility-gate correctness**: CI's seed-based re-run (§5) both
  (a) accepts a genuine, correctly-computed submission (no false
  rejections from, say, floating-point/platform nondeterminism that isn't
  actually a fabrication) and (b) rejects a deliberately falsified
  fixture — tested in both directions, not just "the happy path works."
- **Cross-platform reproducibility, extending `test-seed-determinism.R`**:
  the same `(design, inference, scenario, seed)` cell, run serially
  (`num_cores = 1`) on at least Linux, macOS, and Windows, agrees within
  the stated numerical tolerance (§5) — the concrete check behind §5's
  claim, run before, not discovered after, the first external
  contribution is accepted.
- **Query correctness**: a DuckDB `httpfs` query filtered on
  `response_type`/`design_class`/`inference_class`/`inference_type`
  against the published partitioned Parquet returns exactly the rows a
  direct read of the source files would — the literal capability the
  dataset exists to offer, verified rather than assumed to follow from
  "the files are public."
- **Pooling correctness**: two independent submissions for the same cell
  are combined into a tighter running estimate (smaller SE, not a
  duplicate or overwritten row) in the aggregated leaderboard view — the
  concrete form of §5's "redundancy is precision, not waste" reframing.
- **Prefix-check validity**: a from-scratch, 100-replicate run at a given
  seed is byte-identical (within §5's stated tolerance) to the first 100
  replicates of a full-size run at the same seed — the specific claim
  §5's cheap-verification design depends on, checked directly rather than
  assumed from the general seed-determinism property.
- **Spot-check budget honesty**: over a simulated population of
  contributors including a modeled fraction of bad-faith ones, the
  trust-tiered sampling rate (§5) both (a) keeps CI's total verification
  compute to the intended small fraction of contributed compute, and (b)
  catches sustained bad-faith submission with high probability — the two
  competing goals §5's design has to satisfy simultaneously, verified
  together rather than each in isolation.
- **Ranking honesty**: a combination whose empirical type-I error exceeds
  nominal never appears ranked above a valid combination on power alone
  (assert directly on a fixture with a known-invalid combination injected).

## TODOs

- [ ] TODO-1: **Decision gate** (ask the user, no code) — release
  placement (genuinely open, unlike every other plan this session); the
  repo home for the public results data (a `benchmarks/` directory in
  `EDI` itself, an orphan branch, or a dedicated sibling repo — affects
  clone size and CI scope for the main package repo); Parquet vs. CSV;
  PR-based vs. `workflow_dispatch`-based contribution flow; real-dataset
  scope (v1 synthetic-only, per Non-goals, confirmed or overridden).
- [ ] TODO-2: **Scenario-grid definition** — the parameter ranges per
  response type/axis, and the applicability-discovery wiring from §1 that
  generates valid cells rather than a hand-written list — the set of
  cells the priority list (§5) and the contribution CI's validity check
  (§5) both need.
- [ ] TODO-3: **Public dataset schema + partitioning** — the row shape
  and `response_type`/`design_class` partitioning from §4; a worked
  example DuckDB `httpfs` query against a seeded fixture dataset, checked
  into the repo so the query test in "Tests" above has something concrete
  to run against.
- [ ] TODO-4: **Blocking prerequisite, not routine scoping work — root-cause
  the confirmed `num_cores = 1` vs. `num_cores > 1` divergence in
  `InferenceSuite$run_all_inference()`** (§5's citation:
  `testthat_bulk_quarantine/test-inference-suite-run-all-inference-seq-vs-parallel.R`,
  quarantined since 2026-08-27 for exactly this failure). This plan's
  entire CI-verification integrity model (§5) assumes serial and parallel
  execution agree; right now, for at least this one entry point, they
  provably don't, for reasons distinct from the already-tracked
  fork-deadlock hazard. Do not schedule TODO-5's contribution workflow
  ahead of this — it would either reject good parallel submissions or
  (worse) validate against an equally-broken parallel re-check. Once
  fixed: extend coverage to the other kernels the scenario grid (TODO-2)
  exercises (audit for the master-seed-plus-`splitmix64` discipline
  `draw_binary_match_assignments_cpp` already demonstrates, §5's
  citation — one compliant kernel found this session is not a package-wide
  guarantee), measure the actual cross-platform floating-point tolerance
  needed (§5) rather than guessing a number, and add the cross-platform
  (same seed, same `num_cores`, different OS) test that was found not to
  exist anywhere, quarantined or active. Interim posture until this
  closes: accept only `num_cores = 1` submissions (§5).
- [ ] TODO-5: **Contribution workflow** — the public GitHub Actions flow
  (§5): a template R script a contributor runs locally to produce a
  submission file plus a SHA-256 commitment hash of its full raw
  per-replicate output; the CI job implementing the trust-tiered
  prefix-check (§5) — a short, cheap from-scratch re-run at the submitted
  `seed`/`edi_commit`/`r_version`/`os` (serial, within TODO-4's
  tolerance), sampled at a high rate for new/low-trust contributors and a
  small rate for established ones, plus anomaly-triggered checks — never
  a full re-run of the whole submission; the blessed-commit-set mechanism
  (§5) making each of those checks cheap via a cached build rather than
  bounding how many submissions get checked; and the merge/ingestion step
  that appends an accepted submission into the partitioned dataset.
- [ ] TODO-6: **Dashboard** — the thin public leaderboard + priority-list
  page (§4/§5), fetching the public Parquet/CSV directly; Artifact vs.
  GitHub Pages is a real but low-stakes choice, unlike the earlier
  Artifact-`db` decision which turned out not to be a choice at all.
- [ ] TODO-7: **Integrity and query tests** per the Tests section above,
  before accepting the first real external contribution.
- [ ] TODO-8: **Documentation** — how to contribute a run, how to query
  the dataset (the DuckDB one-liner is the whole onboarding story — lead
  with it), what the leaderboard means, and an explicit caveat that it
  reports empirical performance on synthetic scenarios, not a guarantee
  for any specific real dataset.
