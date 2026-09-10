# Optimal Design × Inference Finder — Continuous Large-Scale Simulation Benchmark

> **Depends on:** `SimulationFramework` (`R/EDI/R/simulations_framework.R`)
> as the core computational primitive — this plan is an orchestration and
> publishing layer on top of it, not a new simulation engine.
> `discover_applicable_inference_classes()`
> (`R/EDI/R/inference_suite.R:136`) and `applicable_inference_class_names_for_design()`
> (`R/EDI/R/design_abstract.R:624`) for scenario-grid validity — reused,
> never hand-maintained. Publishing and coordination depend on the
> Artifact platform's `db` and `assets` capabilities (runtime contract
> 0.2.45 at time of writing — re-verify at implementation time) — §4/§5
> ground every claim against the authoritative `db.d.ts` type definitions
> read this session, not a remembered API shape. **Release target: not
> assigned** — unlike every other plan scoped this session, no release
> placement was requested; TODO-1 records this as an open decision rather
> than assuming one. (Global ordering: see `_master.md`.)

Written 2026-09-11 (user request: "a giant simulation to find the best
designs x inference combinations for a variety of datasets for all
response types," running continuously with results auto-published via an
Artifact page, coordinating multiple computers' runs through that same
artifact).

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

## 4. Architecture — publishing via an Artifact page (corrected after a direct challenge to the first draft's reasoning)

**Publication mechanism: settled — an Artifact page**, per direct user
decision. Grounded against the authoritative `db.d.ts` runtime contract
(0.2.45, read this session) rather than a remembered shape.

**What the constraint actually is (corrected — the first pass of this
section conflated two different platform limits and over-reacted to the
wrong one):**

- **Per-document size (256 KiB) is not the binding constraint, and one
  result row does not need to be big.** A single row — design class,
  dataset/scenario id, inference class, and a dozen-ish numeric fields
  (power, empirical size + its test-vs-nominal p-value, coverage + its
  p-value, MSE, CI length, compute time) — serializes to roughly 250–400
  bytes of JSON. Nowhere near the size cap.
- **Document *count* (5,000 total per artifact) is the binding
  constraint, and it is indifferent to how small each document is.** One
  document per raw row would exhaust it once the grid gets large — the
  fix is packing many rows as a JSON array inside fewer documents, not
  making any individual row bigger.
- **The actual headroom, worked out rather than assumed:** at ~300
  bytes/row, one 256 KiB document holds on the order of 800 rows before
  approaching the cap. Grouping rows by `(design_class, inference_class)`
  pair needs one document-group per pair actually run — even a genuinely
  large grid (say 200 pairs × 500 dataset/scenario rows each = 100,000
  total rows) needs only ~125 documents at 800 rows/document, nowhere
  near 5,000. The count cap only becomes a real concern past roughly
  4,000,000 total accumulated rows — far beyond what this plan's grid
  plausibly reaches from a one-time run. It reappears as a *long-run*
  concern for a system meant to run indefinitely (§ below), which is a
  different problem than "does today's grid fit," and is handled
  differently.

**A real gotcha this schema has to design around:** `db.d.ts` states
plainly that `update()`'s merge is recursive for nested *objects* but
"anything else (arrays included) replaces that field wholesale." A shared
document with a `rows: [...]` array that multiple workers `update()`
concurrently is **not** an append — each writer's update replaces the
whole array with whatever it read-then-appended-to, and "last-writer-wins,
no transactions" means two workers finishing near-simultaneously can
silently clobber each other's rows. The fix is **workers never share a
mutable array field**: each finished batch of rows becomes its own new,
small document, never an update to an existing one.

**Data model, matching the row shape directly (nested one level deeper
than "one document per row," not restructured):**

```
db.collection("results/" + design_class + "__" + inference_class + "/batches")
  .add({
    rows: [ {dataset, response_type, power, size, size_pval,
              coverage, coverage_pval, mse, ci_length, time_sec}, ... ],
    worker_id, finished_at
  })
```

`.add()` mints a fresh id per call — no two workers' batches can collide,
no read-modify-write, no array-replace race. A small, separate
`results_index/<design>__<inference_class>` document (or a query over the
`batches` subcollection) tracks progress for the leaderboard to read. The
published page's leaderboard renders by querying/aggregating across a
pair's `batches` subcollection — compact per query (`limit`, `where`) even
though the underlying history keeps growing.

**Long-run compaction, since "continuous" means unbounded time, not just
one large grid.** Even with ~125 documents for one pass over a 100,000-row
grid, a system meant to run indefinitely keeps producing new batch
documents forever — that *does* eventually approach 5,000, just on a time
axis instead of a grid-size axis. The fix is the same idea one level up:
periodically (e.g. weekly) consolidate many old, small batch documents
for a pair into one larger compacted document (still comfortably under
256 KiB given how small each row is), and delete the now-redundant
originals. Flagged as a real TODO-4 item, not fully specified here —
exactly how "periodically" gets triggered depends on TODO-1's worker
execution model.

**`assets` — a convenience export, not load-bearing.** Given the
arithmetic above, `db` alone comfortably holds the full raw-results
history; `assets.upload()` of a full CSV snapshot is offered only as an
easy "download everything" link for offline analysis, not because
anything requires it to fit.

**Reused, not rebuilt:** `SimulationFramework` still does the actual
fitting-many-replicates work (§1) — this architecture only changes where
its output *lands*, not how it's computed.

## 5. Compute: multiple machines, coordinated through the same artifact

Per direct user decision: the actual simulation compute is **distributed
across multiple computers**, coordinated by reading and writing the same
published artifact's `db` — not a single scheduled runner as the earlier
draft proposed. This has a real, non-obvious platform boundary worth
stating precisely rather than glossing over:

**The strong lease primitive (`DocumentReference.acquire()`) is
client-side-JS-only.** `db.d.ts` documents `acquire({holder, ttlMs,
data})` as the correct single-writer/no-double-claim primitive — but it
is a method on the namespace a *published page's own runtime JS* obtains
via `await claude.use("db")`. The mechanism available to **me** (a Claude
Code session, acting as a worker, calling the `Artifact` tool's
`read_db`/`write_db` actions from *outside* the page) is a simpler
get/list/query/set/update/delete/batch surface — it does **not** expose
`acquire`. This means:

- **Job-claiming across worker machines is best-effort, not race-free.**
  Terminology note to avoid confusion with §4's results-storage
  "batches" subcollection: the unit a worker claims here is called a
  **task** (a `(design_class, inference_class)` pair, or a handful of
  dataset/scenario cells within one) — claiming and finishing a task is
  what produces one new results *batch* document in §4's schema. A worker
  reads the task-coordination documents (`read_db` `query`/`get`), picks
  an unclaimed or stale-claimed task, and writes a claim (`write_db`
  `update`, its own worker id + timestamp). Two workers racing on the same
  instant can both believe they claimed it — `db.d.ts` itself warns "a
  bare get-then-set races and both callers believe they won," and that
  warning applies exactly here since `acquire` isn't available on this
  path.
- **This is an acceptable trade-off for this use case, stated honestly
  rather than hidden:** the cost of an occasional double-claim is a
  *little* wasted redundant compute (two workers independently re-derive
  the same task's results, each producing its own harmless extra results
  batch) — not a correctness bug. Mitigate, don't chase a strong
  guarantee: claim coarse tasks (fewer claim operations → fewer race
  windows than claiming individual cells would), add a small
  random jitter before a worker's claim attempt, and treat a stale claim
  (past some age threshold with no progress update) as re-claimable so a
  crashed worker doesn't permanently orphan a task.
- If a future version of this plan wants the stronger guarantee, the only
  documented path is moving the claim step *into the published page's own
  runtime JS* (so it runs with `acquire` available) and having each
  worker call that page rather than the `db` store directly — a
  meaningfully different, heavier architecture not scoped here.

**What "a computer" actually is in this design.** Calling the `Artifact`
tool's `read_db`/`write_db` is something *I* (a Claude Code session) do —
there is no public API a bare `Rscript` cron job can call directly
without an agent in the loop. So each participating machine's realistic
setup is: a plain `R`/`SimulationFramework` process does the actual
compute locally (this can run as a normal cron/scheduled job, no agent
needed for the compute itself), and a **separate, much less frequent**
Claude Code invocation (interactive, or headless via the CLI's
non-interactive mode) does the sync step — claim a task, hand its
parameters to the local R process, and once finished, write results back
and update the leaderboard. Batching the "talk to Claude" step (once per
finished task, not once per scenario cell) keeps this cheap relative to
running an agent continuously. **This execution model — who schedules the
sync step on each machine, and how often — is a real open decision
(TODO-1)**, not committed here; a GitHub Actions runner could also be one
of the participating "computers" under this same model, alongside the
user's own machines, if that's wanted.

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

- **Discovery correctness**: every scheduled scenario cell is a
  structurally valid `(design, inference, response_type)` combination per
  the existing discovery functions (§1) — never a hand-maintained list
  that can drift from the actual registries.
- **Double-claim tolerance**: inject a simulated race (two workers
  claiming the same task near-simultaneously) and confirm the outcome is
  two harmless extra results-batch documents (§4) for that task, never
  corrupted or silently overwritten data — the honest consequence of §5's
  best-effort claiming, verified rather than assumed.
- **Document-cap discipline, both axes**: (a) at a simulated large-grid
  one-time run (§2), the `results/*/batches` document count stays far
  under the 5,000-per-artifact cap per §4's worked arithmetic — a
  regression guard against a future change reverting to
  one-document-per-row; (b) simulating months of continuous accumulation
  confirms the §4 compaction step actually keeps long-run document count
  bounded, not just today's grid size.
- **Report determinism**: the same accumulated `db` state always
  regenerates a byte-identical leaderboard render — no run-to-run
  cosmetic drift from something like unstable row ordering.
- **Ranking honesty**: a combination whose empirical type-I error exceeds
  nominal never appears ranked above a valid combination on power alone
  (assert directly on a fixture with a known-invalid combination injected).

## TODOs

- [ ] TODO-1: **Decision gate** (ask the user, no code) — release
  placement (genuinely open, unlike every other plan this session);
  **worker execution model** (§5's open question: who schedules the
  sync-to-artifact step on each participating machine, and how often —
  cron-launched headless Claude Code CLI invocations, manual periodic
  runs, a GitHub Actions runner as one more worker, or a mix); the task
  granularity for §2's scenario-cell grouping (per §4's arithmetic, coarse
  enough to keep claim-race windows small without needing to be coarse
  for document-count reasons — that constraint turned out much looser
  than first assumed); real-dataset scope (v1 synthetic-only, per
  Non-goals, confirmed or overridden).
- [ ] TODO-2: **Scenario-grid definition** — the parameter ranges per
  response type/axis, and the applicability-discovery wiring from §1 that
  generates valid cells rather than a hand-written list; grouped into
  TODO-1's chosen task granularity.
- [ ] TODO-3: **Publish the artifact** — declare `capabilities: {db: {},
  assets: {}}`; the task-coordination collection schema, the
  `results/<design>__<inference_class>/batches` results-storage schema,
  and the compaction job from §4; the page's own client-side rendering of
  the leaderboard from `db` (querying/aggregating across each pair's
  `batches` subcollection).
- [ ] TODO-4: **Worker sync script** — the claim/compute/report cycle
  described in §5 (`read_db` query for an unclaimed or stale task,
  best-effort `write_db` claim with jitter, hand the task's parameters to
  a local `SimulationFramework` run, `write_db` `.add()` a new results
  batch per §4 — never `update()` a shared rows array) — one script, run
  identically on every participating machine regardless of TODO-1's
  scheduling choice.
- [ ] TODO-5: **Double-claim and cap-discipline tests** per the Tests
  section above, before the first real multi-machine run.
- [ ] TODO-6: **Documentation** — what the leaderboard means, how to read
  a row, how to add a new worker machine, and an explicit caveat that it
  reports empirical performance on synthetic scenarios, not a guarantee
  for any specific real dataset.
