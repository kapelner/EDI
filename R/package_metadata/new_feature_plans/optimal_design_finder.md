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
dataset people will query and trust. The mitigation is that
`SimulationFramework` results are **deterministic given a seed** — CI
independently re-runs a contributor's claimed `(design, inference,
response_type, inference_type, scenario)` cell, or a random subsample of
a large submission, at the submitted `seed`/`edi_commit`/`r_version`/`os`
and rejects the PR on mismatch. This is the actual gate, not merely a
format check — but per direct user instruction, "deterministic given a
seed" needs to actually hold **across every method and every operating
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
- **Genuinely open, not yet verified: an audit, not an assumption
  (TODO-4).** One kernel following the master-seed/`splitmix64` pattern
  correctly doesn't mean every kernel the benchmark's scenario grid
  actually exercises does. This needs a real audit before the first
  external contribution is accepted, not an inference from one example.
- **Build cost, stated honestly.** Verifying a submission against its
  claimed `edi_commit` means CI can build/install *that* commit, not just
  current `HEAD` — a real, non-trivial cost per unique commit (and
  `EDI/CLAUDE.md`'s own standing rule against full package rebuilds
  applies to CI the same as anywhere else — this still needs to be a
  deliberate, bounded build, not an unconstrained one triggered per PR).
  The practical mitigation: only accept submissions against a small,
  "blessed" set of commits (tagged releases, or periodic snapshots of
  `main`) rather than arbitrary history, so CI needs a small number of
  pre-built reference environments, not a fresh build per submission.

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
- [ ] TODO-4: **Cross-platform/cross-method RNG reproducibility audit**
  (§5) — before anything else here matters: confirm every kernel the
  scenario grid (TODO-2) actually exercises follows the
  master-seed-plus-deterministic-substream discipline
  `draw_binary_match_assignments_cpp` already demonstrates (§5's
  citation), not just the one function checked this session; measure the
  actual cross-platform floating-point tolerance needed (§5) rather than
  guessing a number; confirm `num_cores = 1` genuinely sidesteps the
  fork-vs-`mirai` backend divergence rather than assuming it does.
- [ ] TODO-5: **Contribution workflow** — the public GitHub Actions flow
  (§5): a template R script a contributor runs locally to produce a
  submission file, the CI job that re-runs a contributor's claimed cells
  at their stated `seed`/`edi_commit`/`r_version`/`os` (serial, within
  TODO-4's tolerance) and rejects a mismatch, the blessed-commit-set
  mechanism (§5) bounding how many reference builds CI ever needs, and
  the merge/ingestion step that appends an accepted submission into the
  partitioned dataset.
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
