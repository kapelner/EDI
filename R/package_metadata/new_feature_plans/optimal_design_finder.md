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
> to public Parquet/CSV in a public GitHub repo, queried directly. §5's
> verification mechanism went through its own sequence within that:
> full re-run → a fixed 100-replicate prefix check (cheap, but gameable,
> corrected) → CI-chosen random-index checking (correct, but exposed a
> real cost tension against `SimulationFramework`'s actual RNG structure)
> → the final posture, requiring `mirai`/fork execution rather than
> serial, which turned out to solve the cost tension *and* be the only
> resume-safe mode (a direct user question about interrupted contribution
> surfaced this) → TODO-4's fork/mirai-avoidance itself reframed as
> interim once a direct user proposal identified the actual fix (give
> serial the same per-replicate reseeding fork/mirai already use, not a
> result-chained seed). §4/§5 hold the current, superseding design; earlier
> revisions are kept legible in each section's own heading/prose rather
> than silently erased, per this session's own established convention.
> **Release target: v3.0.0** (assigned 2026-09-11, user decision) — the
> one item TODO-1's decision-gate bundle no longer carries open; the repo
> home for the public results data, Parquet vs. CSV, and PR-based vs.
> `workflow_dispatch`-based contribution flow remain genuinely open there,
> per TODO-1 below. Unlike every other item already in `release_v3_0_0.md`,
> this plan shares no TODO-1 decision gate, dependency, or scoping day with
> any of them — it lands in the same tentative release only because it,
> too, was scoped as landing after v2.0.0, the same reasoning that already
> put four unrelated items in one file. (Global ordering: see
> `_master.md`.)

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
- **Row shape, made complete and precise per a direct user question —
  "the dataset/scenario-generating parameters (n, p, effect size, ...)"
  was a loose placeholder, not an actual spec.** `SimulationFramework$new()`
  takes upwards of thirty parameters (confirmed by reading its full
  `@param` list, the same pass that found the fifth custom-function
  parameter). Most are purely operational — `verbose`,
  `results_filename`, `save_to_disk_every_n_rep`, `stop_on_error`,
  `reuse_cache`, `continue_from_last_result_row`,
  `keep_all_intermediate_data`, `turn_off_asserts_for_speed` — and don't
  change what gets computed, so they don't belong in the row at all.
  **`num_cores` is the one deliberate exception, promoted into the
  provenance tier below per direct user instruction.** It's still true
  that `num_cores` doesn't change a replicate's *statistical* output
  (§5's whole fork/mirai-vs-serial parity argument depends on exactly
  that), but it changes what §3's "wall-clock compute cost per fit"
  ranking criterion actually *means* — 50 seconds at `num_cores = 1` and
  50 seconds at `num_cores = 16` are not the same claim, so a timing
  column without it is not honestly interpretable, only decorative. The
  rest genuinely does, and needs to be recorded completely enough that
  CI's random-index check (TODO-4b) can actually reconstruct the call
  that produced any given row, not an approximation of it. Three tiers,
  not one flat list:
  - **Headline, indexed/queryable columns** — the fields people actually
    filter and group by, and the literal answer to "query by dataset
    type, response type, inference model type, inference action type":
    `response_type`, `design_class`, `inference_class`, **`inference_type`**
    (the `ci_method`/`pval_method` computation path — `"rand"`, `"boot"`,
    `"asymp"` — already tracked in `SimulationFramework`'s own output,
    per §1), `n`, `p`, `betaT`. **These fields already double as the
    "was a custom class used" answer** — a reviewed, registered custom
    `Design`/`Inference` class appears here under its own class name,
    indistinguishable from a built-in one, exactly the "clean payoff" §5
    already establishes; no separate custom-class field is needed.
  - **`scenario_config_json`** — every other statistically-relevant
    constructor argument that was set to a non-default value
    (`cond_exp_func_model`, `norm_sq_beta_vec`, `Nrep_W`, `Nrep_Y_w`,
    `alpha`, `B_boot`, `r_rand`, `pval_epsilon`, `sd_noise`,
    `prob_censoring`, `dgp_params`, the per-response-type clamp/epsilon/
    shift parameters, ...) as one serialized JSON object, rather than
    dozens of individually-indexed columns that would need a schema
    change every time `SimulationFramework` grows a new parameter. Not
    queried directly by the DuckDB examples below, but essential for
    exact reproduction — TODO-4b's random-index check reads it to know
    exactly what to recompute.
  - **Custom-component name references, one per function-parameter slot,
    `NA` when the built-in default was used** —
    `custom_replication_data_generator_name`,
    `custom_apply_treatment_and_noise_name`, `make_estimand_fn_name`,
    `custom_dgp_name`, `cov_draw_method_name`, each a bare name string
    (never a serialized function/closure — a row cannot and must not
    carry executable code, only a pointer to reviewed code) resolving to
    `R/custom_design_simulations/<matching subdirectory>/<name>.R` at
    the row's own `edi_commit`. Kept as explicit, separate, queryable
    columns rather than buried inside `scenario_config_json`, since
    "which rows used a custom DGP" is exactly the kind of question the
    public database should answer directly. A `custom_dataset_file` field
    completes the set for route (b) datasets (§5) — `NA` for route (a),
    where `dataset_package`/`dataset_package_version` (§5) already
    identify the dataset precisely.
  - Plus the §3 metrics (`power`, `size`, `size_pval`, `coverage`,
    `coverage_pval`, `mse`, `ci_length`) and **provenance** — expanded per
    direct user instruction ("`num_cores` should be recorded. Also force
    recording of timings of each row. Also force recording of system
    settings (OS, hardware specs, R version, compilation flags for EDI,
    etc)") into three groups, all **mandatory, not optional** — a
    submission missing any of them is rejected outright by CI (Tests,
    below), the actual "force" the instruction asked for, not merely a
    documented convention a contributor could skip:
    - **Identity/reproducibility provenance** (unchanged from the earlier
      draft): `edi_commit` (full git SHA, not just the `DESCRIPTION`
      version string, since two commits can share a version number
      between releases), `r_version`, `os`, and the `seed` used.
      `edi_commit` is also directly useful for querying, not just
      integrity — it lets a query pin to one commit ("what does the
      *current* code actually achieve") or group by commit over time
      ("has this class's power changed across releases"), which the flat
      metric columns alone couldn't answer.
    - **Performance provenance, kept as top-level queryable columns** —
      the fields needed to make a timing number mean something, not
      buried in JSON, because "how fast" and "on how many cores" are
      exactly the kind of thing a query should filter/group by directly,
      the same reasoning that keeps `response_type`/`design_class` in the
      headline tier rather than `scenario_config_json`: `num_cores`
      (promoted out of the excluded list above), `total_wall_time_sec`
      (renamed from the earlier draft's `time_sec` for clarity that it's
      the whole row's/cell's compute time, not one replicate's), and
      `mean_replicate_time_sec` (`total_wall_time_sec / Nrep` — the
      actual cross-hardware/cross-`num_cores`-comparable unit; a raw
      total conflates "this combination is slow" with "this run asked
      for more replicates").
    - **`system_provenance_json`** — hardware and EDI-build detail, one
      serialized JSON object per row, the same "don't force a schema
      migration on every new field" reasoning as `scenario_config_json`
      above, since filtering on exact CPU model or compiler flag is a
      rare, exploratory question, not the headline "query by dataset/
      response/inference type" use case. **Populated by calling
      `edi_tuning_hardware_fingerprint()`
      (`R/EDI/R/local_machine_tuning_persistence.R:111-211`) directly and
      serializing its return value — reused, not rebuilt, and expanded
      this session (twice, on direct follow-up) so one call covers this
      row's full "system settings" requirement end to end**: `cpu_model`,
      `cpu_vendor_id`, `cpu_architecture` (x86_64 vs. arm64 — matters for
      `-march=native`/vectorization), `logical_cores`, `physical_cores`,
      `total_ram_bytes`, `blas`, `lapack`, `platform`, `os_description`
      (human-readable, e.g. "Ubuntu 24.04 LTS"), `os_sysname`/
      `os_release`/`os_version`, and `sizeof_long`/`sizeof_longdouble`/
      `sizeof_pointer` (the three `.Machine` fields that can actually
      differ across platforms EDI targets and bear on C++
      reproducibility — `long` is 4 bytes on Windows/LLP64 vs. 8 on
      Linux/macOS/LP64) for the hardware/OS half (`r_version` is already
      the top-level column above, not duplicated here) — **now with real
      Windows and macOS coverage** (`cpu_model`/`total_ram_bytes` were
      Linux-only, silently `NA` elsewhere, before this session's
      follow-up; `wmic`/`sysctl` branches close that the same way
      `benchmarkme::get_cpu()`/`get_ram()` do, without taking on that
      package as a dependency just for two OS-probing functions this file
      already hand-rolls the same way for Linux/macOS); plus
      `edi_native_tuned_build` (`-march=native`/`-mtune=native` vs.
      portable) and `edi_lto_build` for the two highest-signal
      compile-time booleans, and the fuller compile-time set —
      `edi_build_capture_method`, `edi_build_timestamp`, `edi_build_host`,
      `edi_build_compiler` (`__VERSION__`),
      `edi_build_compiler_optimize_macro`,
      `edi_build_compiler_fast_math_macro`,
      `edi_build_eigen_vectorize_disabled`,
      `edi_build_disable_vectorization_env`, `edi_build_native_speed_env`,
      `edi_build_r_cxx20flags`, `edi_build_r_shlib_openmp_cxxflags`,
      `edi_build_pkg_cppflags`, `edi_build_pkg_cxxflags`,
      `edi_build_pkg_libs` — all pulled inside the fingerprint function
      itself from `edi_build_info_cpp()`
      (`R/EDI/src/build_info.cpp:66-101`, `.Call`-exported, compiled into
      the `.so` itself, so it reports what a given binary actually was
      built with, not merely what `Makevars` would request), `NA`
      throughout when the loaded binary predates that export or the
      build-info C++ symbol isn't available. A contributor's submission
      script does not need to call `edi_build_info_cpp()`, `sessionInfo()`,
      `Sys.info()`, or inspect `.Machine` separately, or hand-assemble any
      of this — one `edi_tuning_hardware_fingerprint()` call is now the
      whole "system settings" story for this row. **Deliberately not
      pulled in**: `Sys.info()`'s `login`/`user`/`effective_user` (actual
      account usernames — higher sensitivity than even a hostname, and no
      diagnostic value for a hardware/build fingerprint) and the ~26 of
      `.Machine`'s ~30 fields that are IEEE-754 constants and don't vary
      on any platform EDI targets — both excluded on purpose, not an
      oversight, per the function's own roxygen.
    - **Two privacy issues, decided directly by the user rather than left
      as an open either/or (an earlier draft of this section presented
      "strip vs. disclose" as unresolved — it wasn't, once asked).**
      - **`edi_build_host`/`hostname` (real machine hostname on a
        contributor's own run — an ephemeral runner name only for a
        CI-built reference commit): stripped, not disclosed, and
        enforced twice, not once.** TODO-5's submission template removes
        both fields from the fingerprint before writing
        `system_provenance_json` — but a template is just documented
        convention until something checks it, exactly this plan's own
        standing rule for anything reaching the public dataset (the
        config-list function/closure scan, Discovery correctness, both
        above, follow the identical logic). **CI's PR-validation job
        (§5, TODO-2b) independently rejects any submission where either
        field is non-`NA`** — a structural check on the submitted JSON,
        not trust that the template ran correctly or wasn't bypassed by
        a hand-edited submission.
      - **Path-bearing fields — `blas`, `lapack`, `edi_build_pkg_libs`,
        and `edi_build_pkg_cppflags`/`edi_build_pkg_cxxflags` — carry the
        identical leak in a narrower case, caught on direct follow-up,
        not by the original privacy pass.** On a system package manager's
        BLAS/LAPACK these are generic (`/usr/lib/...`); on a
        `conda`-installed or `R_LIBS_USER`-local build they resolve to
        `/home/<username>/...` or `/Users/<username>/...` — but unlike
        `edi_build_host`, the informative part (which BLAS backend —
        OpenBLAS, MKL, reference — genuinely matters to this plan's own
        cross-hardware performance-comparison use case, §4's "emergent
        capability" below) lives in the rest of the path, not the
        home-directory prefix, so dropping the field outright would
        throw away real signal to fix a narrower problem. **Resolution:
        sanitize, don't drop** — the submission template (and CI's same
        structural check, as a backstop) strips a leading
        `/home/<user>/`- or `/Users/<user>/`-shaped prefix from these
        four fields specifically (regex against `Sys.getenv("HOME")`,
        not a hardcoded pattern, so it also catches non-default home
        directories) while keeping everything after it intact — a
        submission with `/home/alice/miniconda3/envs/r/lib/libopenblas.so`
        publishes as `~/miniconda3/envs/r/lib/libopenblas.so`, same BLAS
        identity, no username. CI rejects a submission where any of these
        four fields still contains a `/home/` or `/Users/` segment after
        the contributor's own sanitization — the same "structural check,
        not trust the convention" pattern as the hostname fields above,
        just narrower (substring rejection, not whole-field rejection).
      - **Not a reason to change `edi_tuning_hardware_fingerprint()`
        itself** — the function is a general-purpose fingerprint used
        well beyond this one plan (§1's local machine-tuning persistence,
        never published, has no reason to sanitize or drop anything) —
        both fixes belong at this plan's own contributor-facing boundary
        (the TODO-5 template) and its CI backstop (TODO-2b), not in the
        shared function every caller relies on.
    - **The emergent capability this unlocks, worth stating explicitly
      per the user's own framing ("this allows us to understand EDI's
      speed and performance")**: because every row now carries
      `num_cores`, normalized timing, and hardware/build provenance, the
      same public dataset that answers "which design × inference
      combination is statistically best" also answers "how does EDI's
      own performance vary across hardware, core count, and build
      configuration" — a second, genuinely useful query surface
      (`edi_commit` already supported "has power changed across
      releases"; this adds "has *speed* changed across releases, or
      between portable and native-tuned builds") that falls out of the
      same rows for free, not a second data-collection effort.
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
- **A fixed prefix is gameable — corrected after a direct, correct
  challenge.** The original design here checked "the first 100
  replicates," reasoning that replicate `k`'s seed
  (`master_seed + splitmix64(k)`, §5's `draw_binary_match_assignments_cpp`
  citation) doesn't depend on the total replicate count requested. That
  math is real, but the *position* being fixed and predictable is exactly
  the flaw: a contributor who knows only replicates 1–100 will ever be
  checked can compute those honestly and fabricate or cut corners on the
  remaining 9,900, and never get caught. The fix has to be CI choosing
  **random replicate indices, using CI's own randomness, never derived
  from anything the contributor submitted or could predict** — no
  fixed-position check survives an adversarial contributor.
- **The cost problem is already solved — for two of `SimulationFramework`'s
  three execution paths — by a mechanism that already exists, verified by
  reading `R/EDI/R/simulations_framework.R` directly rather than
  assumed.** The **fork** path (line 1649) and the **mirai** path (line
  1768) both derive `rep_seed = private$seed + replicate_index` and call
  `set.seed(rep_seed)` **per replicate**, independently of every other
  replicate — the exact index-independent property random-index checking
  needs, already in production code, not a hypothetical refactor. CI can
  recompute an arbitrary replicate #4,832 directly (`set.seed(private$seed
  + 4832)`, run just that one), as cheaply as replicate #1. The **serial**
  path (`num_cores = 1`, from line 1877) is the outlier: no per-replicate
  `set.seed()` call exists anywhere in it — confirmed by searching the
  whole file — so it relies on the single `set.seed(private$seed)` at the
  top of `run()` and consumes R's RNG as one continuous stream across
  every replicate in sequence. Only the serial path has the cheapness
  problem; the parallel paths never did.
- **This has a second, larger consequence: it overturns TODO-4's earlier
  "accept only `num_cores = 1`" interim posture, per a direct user
  question about interrupted-and-resumed contribution.**
  `SimulationFramework`'s `continue_from_last_result_row` (the *default*)
  skips already-completed `(replicate, cell)` work on a resumed run
  without recomputing it. Under the fork/mirai per-replicate-independent
  seeding, that's safe — a resumed run's remaining replicates use the
  same stable `private$seed + index` they always would, so **start-stop-start
  reproduces a straight-through run exactly.** Under the serial path's
  single continuous stream, it is **not** safe — skipped replicates never
  advance the stream the way computing them would have, so the remaining
  replicates land at a different stream position after a resume than in
  an uninterrupted run, and very likely produce different numbers. Serial
  is exactly the mode that breaks under interruption, and real
  contributors (laptop sleep, a killed process, deliberately working
  across sessions) will hit this constantly — rejecting them for it would
  be rejecting good-faith data over an artifact of which code path they
  ran, not anything they did wrong. **Corrected recommendation: require
  fork/mirai execution (`num_cores > 1`) for accepted submissions and for
  CI's own verification re-run — not serial — precisely because it is
  resume-safe by construction, with the added benefit of also being what
  makes cheap random-index verification possible in the first place.**
  This follows directly from reading `simulations_framework.R` itself —
  the serial path's missing per-replicate reseeding (confirmed by
  searching the whole file), set against fork/mirai's demonstrated
  `private$seed + replicate_index` formula — with no need to lean on any
  other code path's behavior as supporting evidence. Until TODO-4's fix
  lands, CI must verify using the *same* execution-mode family a
  contributor used, never cross-check serial against parallel or the
  reverse — the two paths are not proven to agree today, so treat them as
  independent until they demonstrably are, not a reason to default to the
  worse choice here.
- **A cheap, complementary integrity primitive that genuinely is
  cryptographic — tamper-evidence, not correctness-proof — made concrete
  per direct user instruction.** A contributor's submission script
  computes and includes `digest::digest(raw_replicate_output, algo =
  "sha256")` — a SHA-256 hash over the *full* raw per-replicate output
  (every `estimate`/`ci_lo`/`ci_hi`/`pval`/`true_estimand` value per
  replicate, serialized in a fixed, documented order — not just the
  aggregated row), stored as one more field on the submission alongside
  `edi_commit`/`r_version`/`os`/`seed`. This doesn't prove the computation
  was done correctly — a wrong build produces a perfectly well-formed,
  self-consistent hash of its own wrong numbers, which is exactly why
  it's a *complement* to the random-index check above, not a replacement
  for it — but it does mean the aggregated metrics in the public dataset
  provably match what was actually computed at submission time, closing
  off a different attack: editing the reported numbers after the fact
  without redoing the run. CI's check is a one-line re-hash-and-compare,
  effectively free next to any re-simulation cost. Any third-party
  auditor can independently re-verify the same hash later without needing
  CI's own infrastructure, since the check is just "does this raw output,
  if you have it, hash to what was published" — a small but genuine
  transparency property beyond CI's own checking.
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
- **`SimulationFramework$run()` picks its parallelism backend by OS** —
  `parallel::makeForkCluster()` on Unix only, the cross-platform `mirai`
  package otherwise (`R/EDI/R/simulations_framework.R:833`) — but this is
  a smaller risk than it first looked once the actual seed derivation was
  read directly: **fork (line 1649) and mirai (line 1768) both compute
  `rep_seed` from the identical formula, `private$seed +
  replicate_index`** — the same code shape, just different loop-variable
  names. The two backends *should* agree, by construction, not by luck —
  still worth the direct cross-platform test already in "Tests" above
  rather than taking on faith, but this is no longer the open question it
  first appeared to be. **CI's own verification standardizes on `mirai`
  specifically** (available on every OS CI runs on, unlike fork) for a
  single consistent backend across CI's own multi-OS matrix; contributors
  may use either fork or mirai on their own machines.
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
- **A related, but out-of-scope, confirmed bug — noted for precision,
  not because it affects this plan.** `test-seed-determinism.R` (the
  actively-running suite) only exercises `num_cores = 1L` throughout
  (verified by direct inspection), so it provides no serial-vs-parallel
  coverage for anything. A separate, already-quarantined test
  (`testthat_bulk_quarantine/test-inference-suite-run-all-inference-seq-vs-parallel.R`)
  does target exactly that comparison, and confirms it currently fails —
  but for `InferenceSuite$run_all_inference()`, a code path this plan's
  pipeline never touches (confirmed by grepping `simulations_framework.R`
  for any reference to it — none exist). Not this plan's problem to fix
  or test around; TODO-4/4b's own scope is `SimulationFramework` only.
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

**Custom functions, custom datasets, and custom `Design`/`Inference`
classes — reviewed and merged, never accepted as loose contributor code
or data, per direct user correction and a direct user follow-up
extending the same principle to class-level extensions.**
`SimulationFramework` gives contributors substantial latitude beyond the
closed `design`/`inference`/`response_type` grid this plan has scoped so
far — confirmed by reading its constructor's full `@param` list (not
just the parameters found by an earlier, narrower search), it accepts
**five distinct optional-function parameters**:
`custom_replication_data_generator`, `custom_apply_treatment_and_noise`,
`make_estimand_fn`, `custom_dgp`, and **`cov_draw_method`** (draws the
`n * p` i.i.d. covariate values per replication; defaults to
`stats::rnorm`, a risk only when a contributor overrides it — found on a
direct follow-up question, missed in the first pass, exactly the kind of
gap worth re-checking rather than assuming the earlier count was
complete). Accepting a contributor's own R closures for any of these
alongside a results submission would mean CI (or anyone reproducing
results) has to `source()`/`eval()` untrusted code to verify them — a
real remote-code-execution risk for a public CI system, not merely a
quality concern, and a gap the rest of this plan's integrity design
didn't close. Custom **datasets** — the actual mechanism is `X_mat`, a
literal user-supplied `n × p` covariate matrix (`random_X_draws`, named
similarly, is a different and unrelated setting — whether covariates
redraw every replication or are reused per cell, not a data-supply
mechanism; corrected here after conflating the two in an earlier pass) —
are the same underlying problem in a different guise: arbitrary,
unreviewed *data* instead of arbitrary, unreviewed *code*. And custom
**`Design`/`Inference` classes** — EDI already has a
first-class, documented extension contract for exactly this
(`R/EDI/R/design_custom_extensions.R`, `inference_custom_extensions.R`,
the `vignettes/extending-edi.Rmd` contract, `define_design_class()`/
`define_inference_class()` as the registration path every built-in class
already goes through) — are the same problem in a third guise: a whole
class definition instead of one function. All three need the identical
fix, not three different ones.

**The rule: only reviewed-and-merged functions/datasets/classes may
appear in a public submission, full stop.**

**Location, final per direct user decision: `R/custom_design_simulations/`,
one subdirectory per extension point, not one shared bucket** — a
category-per-directory refinement of the earlier flat-directory draft,
now eight entries (`custom_cov_draw_methods/` added after the follow-up
audit above found the fifth function parameter):

```
R/custom_design_simulations/
  custom_replication_data_generators/   # SimulationFramework's custom_replication_data_generator
  custom_apply_treatment_and_noises/    # custom_apply_treatment_and_noise
  make_estimand_fns/                    # make_estimand_fn
  custom_dgps/                          # custom_dgp
  custom_cov_draw_methods/              # cov_draw_method (+ cov_draw_method_args)
  custom_datasets/                      # route (b) datasets, below — the X_mat mechanism
  custom_design_classes/                # define_design_class() extensions
  custom_inference_classes/             # define_inference_class() extensions
```

Every subdirectory keeps the same **one file per contribution, not one
shared growing file** convention already established — a monolithic file
many independent contributors all edit invites needless merge conflicts
between semantically-unrelated PRs, and this repo's own
`new_feature_plans/` directory already uses "one file per topic" for
exactly this reason; splitting by extension point *in addition* makes it
immediately legible from a path alone which of `SimulationFramework`'s
four injection points, which class registry, or which dataset route a
given file serves — no need to open it to find out.

- **The five `SimulationFramework` function parameters**
  (`custom_replication_data_generator`, `custom_apply_treatment_and_noise`,
  `make_estimand_fn`, `custom_dgp`, `cov_draw_method`) each get their own
  subdirectory above, matching the parameter name 1:1
  (`cov_draw_method_args`, its companion argument list, travels with
  whichever `cov_draw_method` file uses it — plain config values, not a
  second function, so it needs no subdirectory of its own). A contributor
  proposing a genuinely
  new one submits it as its *own* pull request to the matching
  subdirectory, reviewed like any other code change, merged before any
  benchmark result using it can be submitted. **Not inside `R/EDI/`'s
  installable package source** — coupling every new benchmark scenario to
  a full CRAN package release would throttle contribution pace against
  this repo's own release cadence and bloat the CRAN-facing package with
  benchmark-only code most package users never need; this sibling,
  version-controlled, PR-reviewed location (alongside the existing
  `R/package_metadata/`/`R/package_tests/` siblings of `R/EDI/`) gets the
  identical review/trust guarantee without that coupling, `source()`-able
  directly by both a contributor's local run and CI's verification, no
  package rebuild required either way.
- **Custom datasets**: `custom_datasets/`, exactly two accepted routes,
  both requiring PR review, per direct user proposal — (a) a versioned
  CRAN package added to `Suggests` via its own PR, with the exact package
  **version** (not just the name) recorded on every row that uses it,
  since an unpinned package name is not actually reproducible as the
  package evolves; or (b) the raw dataset file committed directly into
  `custom_datasets/`, with the commit that added/last-changed it
  implicitly pinned by that submission's own `edi_commit` field (§4's row
  schema) — no new provenance field needed for this route, the existing
  one already covers it. No third route; a dataset that is neither an
  installed, versioned `Suggests` package nor a committed
  `custom_datasets/` file is not eligible, full stop.
- **Custom `Design`/`Inference` classes**: `custom_design_classes/` and
  `custom_inference_classes/` respectively — two separate directories,
  not one, matching the two separate registries
  (`define_design_class()`/`define_inference_class()`) they go through.
  Submitted as a PR going through the *exact same* registration every
  built-in class already uses — not a lighter-weight, second-class path.
  This is a materially higher bar than the function/dataset routes above:
  the extension has to satisfy the full contract
  `vignettes/extending-edi.Rmd` documents and
  `test-custom-extension-contract.R` already pins for every class in this
  codebase, not just "does it run deterministically." **The clean payoff
  of holding that bar**: once merged and registered this way, a custom
  class is indistinguishable from a built-in one to
  `discover_applicable_inference_classes()`/the design registry — TODO-2's
  scenario-grid discovery, and the "Discovery correctness" test, need no
  special-casing for custom classes at all, since the registry doesn't
  know or care that a class arrived via this route rather than shipping
  in `R/EDI/` itself.
- **Row schema addition**: `dataset_package` + `dataset_package_version`
  (populated only for route (a); `NA` otherwise) alongside the fields §4
  already specifies — the same "pin exact provenance, not just a name"
  discipline `edi_commit`/`r_version`/`os` already established for code.
- **Mechanical enforcement, same pattern as the existing "Discovery
  correctness" check**: a submission referencing a scenario-function name
  not found in its matching subdirectory, a dataset package+version that
  doesn't resolve to a real installable CRAN release, or a
  `custom_datasets/` path not present at the pinned commit is rejected
  outright by CI — mechanical, not a judgment call, and not a new
  integrity mechanism, just the existing validity check's scope widened
  from "is this design/inference combination structurally valid" to also
  cover "is this scenario function/dataset actually a reviewed, resolvable
  thing."
- **A residual risk worth closing structurally, not just documenting
  around**: `dgp_params` and other named-list config parameters
  (`cov_draw_method_args`, any per-inference-type extra params) are
  plain configuration values by convention — `dgp_params`'s own roxygen
  already says "Recommended over using closures to pass DGP parameters,"
  the package's own authors steering away from exactly this — but R does
  not enforce that at the type level; a named list can hold a function or
  environment object as easily as a number. CI's validation should
  reject any submission whose config-list fields contain a
  function/closure/environment value, not merely trust that contributors
  follow the documented convention.
- **This composes with, rather than duplicates, the already-established
  blessed-commit-set mechanism (§5, above)** — a submission's
  `edi_commit` already identifies which commit of the whole repository
  (the new custom-function/`datasets/` locations included) CI checks out
  to verify against, so a function or dataset's reviewed-and-merged
  status is automatically what CI reproduces from. Reproducibility and
  code-review trust are the same guarantee here, not two systems to
  build and keep in sync.

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
- **Superseded — real/external datasets are now in scope, gated by §5's
  governance, not excluded.** An earlier draft of this plan deferred
  real-world datasets entirely; that framing didn't survive the custom-
  dataset governance work above, which explicitly designs the two
  accepted routes (a versioned `Suggests` package, or a committed
  `R/custom_design_simulations/custom_datasets/` file) rather than ruling
  real data out. What's still excluded, and this *is* the real
  boundary: **any dataset that is neither of those two reviewed
  routes** — a contributor's own arbitrary local file, an unreviewed
  download, anything not PR-merged and version/commit-pinned. Synthetic
  data-generating processes remain the default and the lower-friction
  path; real data is opt-in, reviewed, and additive to it.

## Tests / validation

- **Foundational note**: the tests below validate this plan's own
  contribution/integrity workflow once built; they assume the underlying
  package-level guarantee — replicate output is identical across
  execution modes for a fixed seed — already holds. That guarantee is
  not yet true (TODO-4) and its own rigorous test plan is TODO-4b, not
  duplicated here.
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
- **Cross-platform reproducibility, extending `test-seed-determinism.R`
  (which currently only exercises `num_cores = 1L`, not the mode this
  plan actually requires)**: the same `(design, inference, scenario,
  seed)` cell, run under `mirai` (CI's own standardized backend, §5) on
  at least Linux, macOS, and Windows, agrees within the stated numerical
  tolerance — the concrete check behind §5's "fork and mirai should agree
  by construction" claim, run before, not discovered after, the first
  external contribution is accepted. A fork-vs-mirai agreement check on
  a single OS (where both are available) is a useful companion, not a
  substitute for the cross-OS check.
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
- **Random-index check validity**: a CI-chosen random replicate index,
  recomputed via fork/mirai's existing `private$seed + replicate_index`
  derivation, matches that same index in the contributor's full
  submission (within §5's stated tolerance) — the specific claim §5's
  cheap-verification design depends on, checked directly rather than
  assumed from the general seed-determinism property.
- **Check-index unpredictability**: the distribution CI draws random
  replicate indices from is not derivable by a contributor from anything
  in their own submission (the seed, the commit, or any other field) —
  the actual property that makes the random-index check resistant to the
  fixed-prefix gaming this design was originally vulnerable to.
- **Start-stop-start reproducibility, fork/mirai specifically**: an
  interrupted-and-resumed run (`continue_from_last_result_row = TRUE`,
  the default) produces results identical to an uninterrupted run under
  fork/mirai execution, across at least a few different interruption
  points — the concrete check behind §5's "resume-safe by construction"
  claim, and the reason TODO-4 requires fork/mirai rather than serial for
  accepted submissions.
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
- **Provenance completeness — the concrete form of "force recording,"
  per direct user instruction.** A submission missing `num_cores`,
  `total_wall_time_sec`, `mean_replicate_time_sec`, or any field of
  `system_provenance_json` (§4) is rejected by CI outright, the same way
  a submission naming an inapplicable design/inference combination is
  (Discovery correctness, above) — this is a mandatory field check, not
  a documented-but-unenforced convention a contributor's script could
  silently skip.
- **Privacy scrubbing enforced, not merely requested.** Two fixture
  cases: (a) a submission with `edi_build_host`/`hostname` populated is
  rejected outright; (b) a submission whose `blas`/`lapack`/
  `edi_build_pkg_libs`/`edi_build_pkg_cppflags`/`edi_build_pkg_cxxflags`
  still contains a `/home/`- or `/Users/`-shaped segment is rejected,
  while an already-sanitized value (`~/miniconda3/envs/r/lib/libopenblas.so`)
  passes — the concrete form of §4's "sanitize, don't just document"
  resolution, run on every submission unconditionally, not sampled like
  the random-index check.

## TODOs

- [ ] TODO-1: **Decision gate** (ask the user, no code) — **release
  placement is settled (v3.0.0, 2026-09-11, per the header above); what's
  still open here** is the repo home for the public results data (a
  `benchmarks/` directory in `EDI` itself, an orphan branch, or a
  dedicated sibling repo — affects clone size and CI scope for the main
  package repo); Parquet vs. CSV; PR-based vs. `workflow_dispatch`-based
  contribution flow. `R/custom_design_simulations/`'s eight-subdirectory
  structure (TODO-2b) is settled too, not an open item here.
- [ ] TODO-2: **Scenario-grid definition** — the parameter ranges per
  response type/axis, and the applicability-discovery wiring from §1 that
  generates valid cells rather than a hand-written list — the set of
  cells the priority list (§5) and the contribution CI's validity check
  (§5) both need.
- [ ] TODO-2b: **Custom function/dataset/class governance** (§5) — stand
  up `R/custom_design_simulations/`'s eight subdirectories
  (`custom_replication_data_generators/`, `custom_apply_treatment_and_noises/`,
  `make_estimand_fns/`, `custom_dgps/`, `custom_cov_draw_methods/`,
  `custom_datasets/`, `custom_design_classes/`, `custom_inference_classes/`),
  one file per contribution in each; the PR-review process for adding a
  new function, dataset, or class to its matching subdirectory — for
  classes, going through `define_design_class()`/`define_inference_class()` and
  the existing `extending-edi.Rmd` contract, not a lighter bar — separate
  from and prerequisite to any results submission using it; the
  mechanical CI check rejecting a submission whose
  `cond_exp_func_model`/custom-function name, `dataset_package` +
  `dataset_package_version`, or `custom_datasets/` path doesn't resolve
  against the blessed commit (custom classes need no separate check here, per
  §5's note — the existing registry-discovery machinery, TODO-2, already
  can't tell a registered custom class from a built-in one) — the same
  "Discovery correctness" pattern (Tests, above) widened to cover
  functions and datasets; **and the config-list scan (§5) rejecting any
  submission whose `dgp_params`/`cov_draw_method_args`/per-inference-type
  extra params contain a function, closure, or environment value** — a
  structural check, not reliance on the documented convention against it.
  A prerequisite for TODO-5's contribution workflow, not optional
  hardening added later — an open door here
  undermines the integrity model no matter how well TODO-4/4b's RNG work
  turns out.
- [ ] TODO-3: **Public dataset schema + partitioning** — the row shape
  and `response_type`/`design_class` partitioning from §4, including the
  mandatory performance-provenance columns (`num_cores`,
  `total_wall_time_sec`, `mean_replicate_time_sec`) and
  `system_provenance_json` (populated from
  `edi_tuning_hardware_fingerprint()`, §4) — the submission script writes
  all of them on every row, never leaves them `NULL`; a worked example
  DuckDB `httpfs` query against a seeded fixture dataset, checked into
  the repo so the query test in "Tests" above has something concrete to
  run against.
- [ ] TODO-4: **Fix `SimulationFramework`'s serial-path resume/cheap-
  verification gap — a well-understood, well-scoped fix.** Per direct
  user proposal: give the serial path
  (`R/EDI/R/simulations_framework.R`, from line 1877) the same
  per-replicate reseeding fork/mirai already use —
  `set.seed(private$seed + rep)` at the top of each iteration of the
  serial `for (rep in seq_len(private$Nrep_W))` loop, the identical
  formula already proven at lines 1649–1650 and 1768, not a redesign.
  **Must be position-derived, never chained from a previous replicate's
  computed *result*** — a result-chained seed would still require
  replicate k−1 to actually be computed before replicate k could be
  seeded, silently reintroducing the same resume-unsafety and
  expensive-to-verify properties this fix exists to remove. **One real
  cost to do this properly, not a reason to skip it**: this changes what
  a serial run with a given nominal seed produces (today's
  continuous-stream output won't match post-fix index-derived output) —
  exactly the class of change this codebase's "bit-for-bit defaults"
  standing constraint (used throughout its own release plans) requires to
  ship opt-in or as an explicitly documented default change, never
  silently. Once fixed and shipped that way: extend the audit to the
  other kernels the scenario grid (TODO-2)
  exercises (confirm the `private$seed + replicate_index` discipline
  fork/mirai already demonstrate, §5's citation, generalizes cleanly —
  confirmed for `simulations_framework.R` itself this session, not yet
  audited into every kernel a cell might call), measure the actual
  cross-platform floating-point tolerance needed (§5) rather than
  guessing a number, and add the cross-platform (same seed, same
  `num_cores`, different OS) test that was found not to exist
  anywhere, quarantined or active. **Interim posture until this closes,
  corrected after a direct user question about interrupted/resumed
  contribution: require fork/mirai execution (`num_cores > 1`) for
  accepted submissions and CI's own verification, not serial** — serial
  is resume-unsafe (§5: no per-replicate reseeding, confirmed by reading
  the code) and would reject good-faith contributors who paused and
  resumed, which is exactly the outcome to avoid; fork/mirai's
  per-replicate independent seeding is both resume-safe and what makes
  cheap random-index verification possible, so there is no longer a
  tradeoff between the two properties this TODO originally worried about
  needing to choose between.
- [ ] TODO-4b: **Rigorous replicate-level seed-parity test suite for
  `SimulationFramework` — the concrete deliverable behind "don't reject
  good-faith contributors over an artifact of which code path ran."**
  Scoped to `SimulationFramework` only, per direct user correction: this
  plan's pipeline runs exclusively through it, never through
  `InferenceSuite$run_all_inference()` — confirmed by grepping
  `simulations_framework.R` for any reference to `InferenceSuite` or
  `run_all_inference` (none exist; they are fully independent code
  paths). An earlier draft of this TODO pulled in a real, separately
  confirmed bug in `InferenceSuite$run_all_inference()`'s own fork
  dispatch (`run_all_inference_fork_dispatch()`,
  `R/EDI/R/inference_suite.R:1323` — forks a new child per task via a
  rolling window with **no `set.seed()` anywhere in its dispatch path**,
  so each child inherits whatever RNG state the parent happens to have at
  that exact fork moment, dependent on scheduling timing rather than a
  stable per-task identifier) — genuinely worth fixing, but not reachable
  by anything this project does, so out of scope here; removed rather
  than left as dead weight, though worth surfacing to the user separately
  from this plan.

  Comparisons at **raw, per-replicate output**, never only aggregated
  summary statistics — an aggregate (mean power, mean coverage) can hide
  a real per-replicate divergence that happens to cancel out on average,
  which is exactly the kind of bug a weaker test would miss:
  - For a fixed seed, every replicate's raw
    `estimate`/`ci_lo`/`ci_hi`/`pval`/`true_estimand` matches exactly
    (within §5's numerical tolerance) across `num_cores = 1` (post-TODO-4
    fix), `num_cores > 1` via fork, and `num_cores > 1` via `mirai` —
    three-way agreement, not just two.
  - Swept across: at least one design/inference/response-type combination
    per family (the 19 families `model_diagnostics_framework.md`
    §3B/§3C already catalogue, not one arbitrarily-chosen example),
    multiple `Nrep_W` values (small, e.g. 5, and larger, e.g. 500), and
    multiple `num_cores` values (1, 2, 4+).
  - **The independence property itself, not just equal formulas**:
    replicate k computed alone (`Nrep_W = k`, i.e. a from-scratch run
    asking only up to k) matches replicate k computed as part of a much
    larger batch (e.g. `Nrep_W = 10k`) — the actual guarantee
    random-index verification and resume-safety depend on, tested
    directly rather than inferred from "the formula looks index-based."
  - **Cross-platform**: the above repeated on at least Linux, macOS, and
    Windows — not assumed to generalize from one OS, per §5's existing
    cross-platform testing commitment.
  - **Promotion, not a test living forever in isolation**: once the
    TODO-4 fix lands and the above passes reliably (multiple clean runs,
    not a single lucky pass — RNG bugs are exactly the kind that
    intermittently "happen to" pass), add it to the active
    `testthat_bulk/` suite so it gets real, ongoing CI coverage rather
    than being a one-time validation exercise.
- [ ] TODO-5: **Contribution workflow** — the public GitHub Actions flow
  (§5): a template R script a contributor runs locally to produce a
  submission file plus a SHA-256 commitment hash
  (`digest::digest(raw_replicate_output, algo = "sha256")`, §5) of its
  full raw per-replicate output in a fixed, documented serialization
  order; **the template script wraps the actual `SimulationFramework$run()`
  call in timing (`system.time()`/`proc.time()`) to populate
  `total_wall_time_sec`/`mean_replicate_time_sec`, and calls
  `edi_tuning_hardware_fingerprint()` once to populate
  `system_provenance_json` (§4) — both non-optional steps the template
  performs automatically, so "force recording" doesn't depend on every
  contributor remembering to do it by hand — **and applies §4's privacy
  fixes before writing it**: drops `edi_build_host`/`hostname` entirely,
  and sanitizes any leading `/home/<user>/`- or `/Users/<user>/`-shaped
  prefix out of `blas`/`lapack`/`edi_build_pkg_libs`/
  `edi_build_pkg_cppflags`/`edi_build_pkg_cxxflags` while keeping the rest
  of each path (§4) — **both re-checked structurally by the CI validation
  job itself, immediately below, not trusted to the template alone**; the CI job implementing the
  trust-tiered **random-index** check
  (§5, not a fixed prefix — cheap because fork/mirai's existing
  `private$seed + replicate_index` derivation makes any single replicate
  independently recomputable) at the submitted
  `seed`/`edi_commit`/`r_version`/`os`, **same execution-mode family
  (fork/mirai) the contributor used — never serial**, within TODO-4's
  tolerance, with CI drawing the check indices from its own randomness,
  never derivable from the submission; sampled at a high rate for
  new/low-trust contributors and a small rate for established ones, plus
  anomaly-triggered checks — never a full re-run of the whole submission;
  the blessed-commit-set mechanism (§5) making each of those checks cheap
  via a cached build rather than bounding how many submissions get
  checked; **a privacy structural check** — reject outright if
  `edi_build_host` or `hostname` is non-`NA`, or if `blas`/`lapack`/
  `edi_build_pkg_libs`/`edi_build_pkg_cppflags`/`edi_build_pkg_cxxflags`
  still contains a `/home/` or `/Users/` segment (§4) — run unconditionally
  on every submission, not sampled like the random-index check, since it's
  a cheap string check, not a re-simulation; and the merge/ingestion step
  that appends an accepted
  submission into the partitioned dataset.
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
