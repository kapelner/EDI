# Feature Plan: Inference-class demo generator (`edi_inference_demo()`)

> **Depends on:** `../future_release_plans/release_v1_5_0.md` (slate).
> Reads the dataset catalogs `../experimental_datasets.csv` and
> `../observational_datasets.csv`, built by `../build_*_datasets_csv.R`.

## Goal

A user names an Inference class and gets runnable demo code that:

1. loads a real catalog dataset,
2. builds the matching design object from its group, outcome, and covariate columns,
3. passes that design into the Inference class, and
4. runs every method the class supports for that design, printing the summary.

## Why this is mostly wiring

- `run_all_inference_class_applicable_methods()` (`R/EDI/R/inference_suite.R:687`)
  already filters a class's methods to those applicable to a given design.
- `define_inference_class()` (`R/EDI/R/contracts_mixins.R:3647`) holds the class
  metadata (response types, randomization requirement) that the recommender needs.
- The catalogs already carry source package, object name, group column, outcome
  column and type, censoring, design status, and redistribution flag.

So the new code is a catalog-to-design mapping, a template renderer, and a
recommender. No estimator changes.

## Design

### Components

1. **Class metadata reader.** Given a class name, return its supported response
   types, whether it requires randomization, and whether it needs covariates.
   Source: `define_inference_class()` metadata. Fail with a clear message for
   unknown classes.
2. **Catalog matcher.** Filter catalog rows whose response type is in the class's
   supported set and whose design status matches the class's requirement:
   randomized-only classes match `design_status == "documented"` experimental rows;
   covariate-adjusting observational classes also match observational rows.
   Rank by `n` (descending, capped) and `p`.
3. **Design mapping.** Translate a catalog row into a design constructor call:
   group column → treatment, outcome column(s) → response, remaining numeric
   columns → covariates. Survival rows add the censoring indicator.
4. **Template renderer.** Emit a standalone R script:
   - data load (CRAN object via `cran_fetch_object_auto()`, or the cached
     archive from `download_*_datasets.R`);
   - design construction;
   - `inf <- <Class>$new(des)`;
   - `run_all_inference_class_applicable_methods(...)` and `print(summary)`.
   For rows whose `redistribution` is not plain `yes` (`no: …`, `unclear: …`,
   `conditional: …`), emit a fetch step with a comment and never embed data.
5. **Entry point.** `edi_inference_demo(class, dataset = NULL, demo_number = 1, fast = TRUE, write_to = NULL)`.
   Prints the script, or writes it to `write_to`. `demo_number` selects one of the
   candidate demos for that class (see "Demo number" below).

### Guardrails

- Generated code uses `library(EDI)` or `pkgload::load_all(".", compile = FALSE)`.
  Never a build step (see the project CLAUDE.md).
- `fast = TRUE` skips bootstrap and jackknife families.
- Methods that do not apply are skipped by the existing filter, so demos do not
  error on unsupported combinations.

## Access and data sources (added 2026-10-06, user direction)

### Who uses demos

Package users (installed EDI) and repo developers. The spec files and helpers
must ship with the installed package, not only live in the repository:

- Demo specs go to `inst/demos/<ClassName>.json` (installed with EDI).
- The pairing helper moves into `R/` as an internal function. Its
  `optmatch` call stays behind a check that gives a clear error if the
  package is missing.
- Catalog CSVs stay out of the installed package. Specs reference catalog
  rows by name, and the index builder runs in the repo, not at install time.
- The ICPSR rows are never shipped in any form.

### Eligible sources for v1

A demo may use only rows whose source is CRAN or base R and whose
`redistribution` value starts with `yes`. (The column was re-valued 2026-10-08 — see
`dataset_license_audit.md`: `yes` / `yes, with attribution (…)` / `conditional: …` /
`unclear: …` / `no: <reason>`; the old "not flagged" / "not permitted" values are gone.)
Before the redistribution filter, that is 338 of the 371 catalog rows (248 + 89 CRAN,
1 base R); the filter then removes 37 (31 `no:`, 5 `unclear:`, 1 `conditional:`),
leaving 301. Excluded for v1:

- **Dataverse** (15 experimental, 2 observational): needs a guestbook form.
- **GitHub** (6 experimental, 7 observational): pinned commits can disappear.
- **ICPSR** (2 experimental, 1 observational): account and terms of use.
- Any CRAN row whose `redistribution` is not `yes`. Examples: `surrosurv::gastadv`
  (research-only conditions), `coxphw::biofeedback` (non-commercial), `mediation::jobs`
  (ICPSR-derived). 29 of the 31 `no:` rows are `no: GPL-2 only`, which bars *embedding*
  the data in a GPL-3 package but not fetching it at run time — see Open decisions.

The index builder rejects a spec that points to an ineligible row and says why.
Dataverse and GitHub can be added later as separate steps.

### How the data is fetched (no package install)

A CRAN demo does not install the source package. It downloads the data only:

1. Download the source tarball with `curl` (CRAN current version, or
   `src/contrib/Archive/<pkg>/` for the pinned version in the catalog).
2. Extract only `data/` from it.
3. Find the file that holds the named object (`.rda`, `.RData`, `.csv`, or
   `.R`) and load it with the matching base-R reader.

The tarball is downloaded whole, since CRAN does not let a single file be
fetched from it. Most data-bearing packages are a few MB, far smaller than an
install. The fetch logic is the same as `cran_fetch_object_auto()` in
`R/package_metadata/compute_covariate_missingness.R`, and the catalog download
scripts already use it. Move it into one shared helper that both the catalog
download scripts and the demos call.

A demo needs only EDI and, for pair-based classes, `optmatch`. It never needs
the CRAN source package's own imports.

### Printed summary and caching (added 2026-10-06, user direction)

`edi_inference_demo()` prints a summary before anything is downloaded:

- class, dataset, source package and version, license, `n`, and the design
  with its provenance (actual or imposed, see below);
- the file it will write;
- a download notice: "the data for this demo will be downloaded from CRAN
  (about N MB) unless it is already cached"; if cached, the notice says where
  the cached copy is and that nothing will be downloaded.

### Demo number (added 2026-10-06, user direction)

`edi_inference_demo()` takes `demo_number`, default `1`. Candidates for a class are
ranked (see the matcher step below), and `demo_number` picks the k-th one. The
output names the position: "demo k of M", where M is the number of candidate demos
in the demo registry for that class, counting only datasets present in the
catalog and the data sources we can fetch. If `demo_number` is greater than M, the
function stops and says M. Classes with one candidate always print "demo 1 of 1".

### Demo registry regeneration (added 2026-10-06, user direction)

The demo registry (the class-to-dataset index that feeds `demo_number` and the
coverage check) is a generated file, not hand-edited. A builder script reads both
catalog CSVs and the per-dataset structure flags, and writes the registry. It
must be rerun whenever a dataset is added to a catalog or a structure column
changes. The builder runs the coverage check after it writes, so a new dataset
that changes a class's count or gaps shows up at once. The registry records the
catalog row count it was built from, and `edi_inference_demo()` warns when the
catalogs are newer than the registry.

### Design provenance in the summary (added 2026-10-06, user direction)

The summary prints the design the demo uses and states where that design
comes from. Two cases:

- **Actual design.** The dataset's own design produced the treatment
  assignment, and the catalog records it (`design_status == "documented"` for
  randomized rows, or an observational design named in the catalog). The
  summary says: "Design: <name>. This is the design that generated the data
  (documented in the catalog)."
- **Imposed design.** The demo applies a design the data did not come from,
  for example a KK pairing and reservoir applied to observed arms. The summary
  says: "Design: <name>. This is NOT the design that generated the data. The
  demo imposes it on <dataset> only to exercise <class>. Estimates are for
  demonstration, not a causal claim about this study."

Which case applies is decided by the spec and the catalog, never by the
user's input. The imposed case is always printed, not only in a comment, and
the generated script repeats the same statement at the top.

The cache lives in `tools::R_user_dir("EDI", "cache")`. The fetch helper
(TODO-11) checks it first, keyed by package, version, and object name, so
repeat runs and other demos reuse the same file. The cache holds only the
extracted data object, not the tarball, and it is never shipped with the
package. The user can clear it with a documented helper.

### KK reservoir share (added 2026-10-06, user direction)

`edi_inference_demo()` gets a `prop_reservoir` argument, default `0.2`. It applies to
KK demos only, the classes that pair subjects and keep the rest in the
reservoir.

The caliper is calibrated to hit the target. `caliper_for_reservoir()` in
`R/package_metadata/demo_helpers/caliper_reservoir_pairs.R` bisects on
log(caliper). A larger caliper admits more pairs, so the reservoir share falls.
The achieved share is discrete (two subjects per pair), so it can differ from
the target by up to 2/n. The summary prints the caliper and the achieved share
next to the target.

If the target is unreachable (for example, all covariate distances are too
large for any cross-arm pair), the demo says so and does not run.

Non-KK demos ignore `prop_reservoir`. A spec that sets it for a non-KK class is
rejected by the index builder.

### Seed (added 2026-10-06, user direction; revised after review)

`edi_inference_demo()` gets a `seed` argument, default `1`. The demo must not change the
user's random-number state. A bare `set.seed()` at the top of the script
overwrites the user's own seed, so it is not used.

- Each design and inference object is built with `seed = seed` in its
  constructor. That is the primary control, and it matches how the package
  is designed to be reproduced.
- Any other random draw in the demo (for example, subsampling or the
  data-fetch step) runs inside a helper that saves `.Random.seed`, sets the
  seed, evaluates the code, and restores the saved state on exit. A small
  `with_demo_seed(seed, expr)` helper does this. If the user had no
  `.Random.seed`, the helper removes the one it created.
- Design constructors call `set.seed()` internally (`maybe_set_seed()`), so
  object construction also touches the global RNG. The demo wraps each
  construction in `with_demo_seed()` too, so the user's state is restored
  afterward.
- `seed = NULL` passes `NULL` to every constructor and runs no seeded helper.
  The summary says results will differ between runs.
- The pairing helpers draw no random numbers, so they take no seed.
- The seed appears in the generated script header and in the summary.

### Coverage check (added 2026-10-06, user direction)

Response-type coverage does not guarantee a demo for every class, because a
class also depends on design, structure, censoring, covariates, and model
needs. So coverage is computed, not assumed.

- The index builder checks every exported Inference class against the
  eligible catalog rows (CRAN or base R, `redistribution` starts with `yes`).
- For each class it lists the matching datasets, or reports why none match:
  missing response type, wrong design (randomized vs observational), missing
  ID or cluster column, censoring type not present, no covariates, or no
  exposure column.
- It writes `demo_coverage.csv` (one row per class) and prints a short list
  of uncovered classes.
- **Structure gaps can be rigged, not just reported.** When a dataset has the
  right response type and design but no pair, block, or cluster column, the
  demo may construct the structure itself with `optmatch` (pairs via
  `caliper_reservoir_pairs()`, with `caliper = Inf` for no caliper). Such a
  demo is always labeled "imposed design" in its summary (see design
  provenance above). The coverage check marks these classes as "covered by
  constructed structure" rather than "covered by data," so the two cases stay
  distinct in `demo_coverage.csv`.
- **Constructed structure, by type** (decided 2026-10-06):
  - **Pairs** from covariates (caliper `optmatch`, `caliper = Inf` allowed):
    allowed for KK classes when the data has both arms with covariates.
  - **Blocks** from covariates (quantile strata, or `optmatch::fullmatch()`
    groups with both arms present): allowed for blocking and blocked classes.
    Every block must contain at least one treated and one control subject.
    Blocks that fail are merged or dropped, and the merge and drop counts are
    printed. Classes that require equal block sizes are covered only when the
    builder can produce equal sizes; otherwise they are reported as uncovered.
  - **Clusters** from a nominal covariate (decided 2026-10-06, user direction):
    allowed as imposed clusters, with the same "imposed" label as imposed
    blocks. Rule: pick one nominal covariate that is not the treatment or the
    response and is not strongly tied to treatment assignment. Use it only when
    it has 5 to 50 levels, no level has fewer than 3 units, and level sizes are
    not wildly unbalanced. The printed summary must say that the outcome
    dependence within levels is invented by the demo, so the output shows the
    mechanics, not a finding. A real cluster column, when the registry has one,
    always takes precedence over an imposed one.
  - Classes that need clusters stay "no demo in v1" when the dataset has
    neither a real cluster column nor a nominal covariate that meets the rule.
  - **Specific classes covered by imposed blocks** (decided 2026-10-06, user
    direction): `InferenceIncidExtendedRobins` (requires a blocking design) and
    `InferenceIncidCMH` (blocked incidence). Both run on covariate-built blocks
    with the imposed-design label. `InferenceIndicidenceExactFisher` accepts
    matching designs, so it is covered by imposed pairs, not blocks.
  - **Classes covered by real or imposed cluster columns** (decided
    2026-10-06, user direction): classes that need clusters for resampling,
    jackknife, or variance (the cluster-robust and frailty families listed in
    the class survey) run on catalog rows with a real cluster ID column, or,
    failing that, an imposed cluster built from a nominal covariate under the
    rule above. The TODO-9 scan has recorded a real cluster column for 46
    catalog rows (44 experimental, 2 observational); the rest fall back to an
    imposed cluster when a covariate qualifies, and otherwise stay uncovered.
    The KK classes are a special case: their clusters are matched pairs plus
    the reservoir, which are constructed pairs and are covered by the
    imposed-pairs rule, not this one.
  - **Real cluster or block columns** in a catalog row (for example, a site or
    household ID the source paper used) are used as-is, with no construction
    label beyond the design provenance.
- Every constructed structure is labeled "imposed" in the summary and the
  coverage output, with its construction rule.
  supplies the ID column.
- Each uncovered class is then either closed by adding a dataset to the
  catalog or recorded as "no demo in v1" with the reason.
- Baseline at the time of writing: eligible rows cover all six response types
  in both designs (randomized: continuous 121, incidence 30, count 22,
  ordinal 17, proportion 13, survival 46; observational: continuous 27,
  incidence 15, count 14, ordinal 4, proportion 2, survival 29). About 104
  Inference classes are exported.

### Documentation (added 2026-10-06, user direction)

`edi_inference_demo()` is a pointer from the reference docs, not a runnable example.

- **Roxygen `@examples` stay as they are.** They show the API on simulated data
  and run in `R CMD check`, so they must stay fast, offline, and free of
  network access. They are not replaced.
- **Each class's roxygen gets a "Real-data demo" line**, for example
  ``Real-data demo: edi_inference_demo("InferenceContinKKOLSIVWC")``, in the description
  text, not inside `@examples`. Added only for classes that have a demo spec.
- **`edi_inference_demo()` is never called in `@examples`.** It needs network access
  for the first download and takes longer than CRAN allows.
- **The vignette (TODO-7)** lists the available demos, explains design
  provenance (actual vs imposed), the reservoir share, and the seed.
- **Ordering.** The roxygen lines are added only after `edi_inference_demo()` exists,
  because regenerating Rd files earlier would point users to a function that
  is not there. The Rd regeneration follows the existing rule for doc batches
  (no interim roxygenize; see project memory).

### Demo access paths

1. `edi_inference_demo("<ClassName>")` prints the runnable script to the console.
2. `edi_inference_demo("<ClassName>", write_to = "demo.R")` writes it to a file.
3. A vignette section (TODO-7) shows one demo per response type.
4. The class's help page links to its demo.

## Data-structure matching (added 2026-10-04, user direction)

Response type alone is not enough. A demo must use a dataset whose *structure*
matches what the class assumes. Examples:

- KK matched-pair classes need data with matched pairs (a pair or cluster ID per
  subject in the data).
- Blocked-design classes need a block column.
- Cluster / GEE / GLMM classes need a cluster ID with more than one subject per cluster.
- Repeated-measures classes need a subject ID appearing more than once.
- Survival classes need a time and an event column (already in the catalog).
- Plain designs (Bernoulli, complete randomization) accept any dataset.

### Requirements

1. **Class declares its structure.** Add a `required_structure` entry to each
   Inference class's metadata (values: `none`, `paired`, `blocked`, `clustered`,
   `repeated`). Unknown structure defaults to `none` and is flagged in the
   output rather than silently accepted.
2. **Catalog declares dataset structure.** Add columns to both catalogs:
   `has_pairs`, `has_blocks`, `has_clusters`, `has_repeats` (yes/no), each with
   the ID column name when present (e.g. `pair_id`, `cluster`). Populated by a
   per-dataset scan. These columns are a cheap prefilter.
3. **Runtime verification.** The catalog flag is a hint, not proof. The generated
   script (and `edi_inference_demo()` when run with `verify = TRUE`) loads the data, checks
   the ID column exists and has the expected shape (e.g. every pair has exactly
   two subjects, every block has the expected size), and only then builds the
   design. Failed checks move the dataset down the ranking with the reason printed.
4. **Matcher.** Rank candidates that satisfy both the response-type and the
   structure requirement. If none qualifies, `edi_inference_demo()` says so and names the
   closest candidate and the missing structure, rather than emitting a demo that
   cannot run.

### Constructed pairs: caliper matching, leftovers to the reservoir

For KK classes the demo forms pairs with caliper matching and sends every
subject it cannot pair into the KK reservoir. This removes the equal-arm-size
requirement and the subsampling step from the earlier draft: the reservoir
absorbs whatever is unmatched, which is what KK expects.

Steps:

1. Standardize covariates (or use Mahalanobis distance, as the existing helper does).
2. Build the distance for nonbipartite matching:

       D[i, j] = d_cov(x_i, x_j) + BIG * (w_i == w_j)   # cross-arm only
       D[i, j] = BIG                                     # if d_cov(x_i, x_j) > caliper

   `BIG` is finite (`.Machine$double.xmax` in the existing helper). The
   `Inf * (w_1 - w_2)` form from the earlier draft fails for the reasons given
   before (`0 * Inf` is `NaN`; `-Inf` is preferred).
3. Run `nbpMatching::nonbimatch()`. Keep only pairs with distance below `BIG`.
   Both members of every discarded pair go to the reservoir.
4. Report the match rate, the number of pairs, and the reservoir size.

Parameters: `caliper` (default chosen from the standardized covariate scale and
exposed as an argument) and `mahal_match`.

Open for the implementation step:

- The existing `compute_binary_match_structure()` (`R/EDI/R/helper_matching.R`)
  has no caliper and no cross-arm constraint. Either extend it with `w` and
  `caliper` arguments (package code, needs its own TODO and tests) or write a
  demo-side helper.
- Check `design_observational_matching.R` before reusing or duplicating its logic.
- Status: demo-side helper at `R/package_metadata/demo_helpers/caliper_reservoir_pairs.R` (2026-10-06) uses optimal bipartite matching via `optmatch` (added to EDI's Suggests). Leftover subjects are handled by augmenting the cost matrix with per-subject dummies, because `pairmatch()` returns all NA unless a perfect match exists. Self-check passes. `caliper = Inf` gives unconstrained optimal bipartite matching, for demos of `DesignFixedBinaryMatch`. Not yet wired into `edi_inference_demo()`.
- Caveat for `DesignFixedBinaryMatch` demos: the package class pairs subjects on covariates before treatment is assigned (non-bipartite, then a coin flip within each pair). The demo pairs already-observed arms, so it reproduces the pairing rule on observed data, not the design itself. The demo text should say so.

### Extra TODOs

- [ ] TODO-8: Add `required_structure` to every Inference class's metadata; a
  test that each class has one (with `none` as an explicit choice, not a default).
- [ ] TODO-9: Add the four structure columns to both catalog builders and fill
  them via a scan of the candidate datasets. Hand-verify the paired and blocked
  rows.
- [ ] TODO-11: Shared CRAN fetch helper (tarball via `curl`, extract `data/`,
  load by format, check and fill the `tools::R_user_dir("EDI", "cache")` cache,
  documented clear-cache helper). Refactor `cran_fetch_object_auto()` and the catalog download
  scripts onto it. Test: fetch and load one object from each format (`.rda`,
  `.RData`, `.csv`, `.R`), and a pinned archive version.
- [ ] TODO-12: Eligibility filter in the index builder (CRAN or base R only,
  `redistribution` starts with `yes`). Test: an ICPSR row, a Dataverse row, a GitHub
  row, and a `no:`/`unclear:` CRAN row (e.g. `surrosurv::gastadv`) are each rejected with a reason.
- [ ] TODO-14: Summary renderer prints design provenance (actual vs imposed) from the spec and catalog. Test: a documented randomized row prints the actual case; a KK demo on observational data prints the imposed case with the warning.
- [ ] TODO-15: `prop_reservoir` argument (default 0.2, KK only). Caliper calibration via `caliper_for_reservoir()`, printing the caliper and achieved share. Tests: achieved share within 2/n of target across targets 0.1, 0.2, 0.4; an unreachable target gives a clear message; a non-KK spec with `prop_reservoir` is rejected.
- [ ] TODO-16: `seed` argument (default 1), passed to every design and inference constructor, plus `with_demo_seed()` for other draws. No bare `set.seed()` in the demo. Tests: two runs with the same seed give identical output; the user's `.Random.seed` is identical before and after `edi_inference_demo()` runs; `seed = NULL` leaves the RNG untouched and passes `NULL` to constructors; the seed appears in the summary and header.
- [ ] TODO-17: Coverage check in the index builder: every exported Inference class mapped to matching eligible datasets, with a reason for each class that has none. Writes `demo_coverage.csv`. Tests: a known-covered class (e.g. a continuous KK class) lists at least one dataset; a class needing an ID column the catalog lacks is reported with that reason.
- [ ] TODO-18: Demo registry builder script that reads both catalog CSVs and the structure flags, writes the class-to-dataset registry with its source row count, runs the TODO-17 coverage check, and is rerun whenever a dataset is added. `edi_inference_demo()` warns when the catalogs are newer than the registry. Tests: adding a row to a catalog changes the registry count for the matching class; a stale registry triggers the warning.
- [ ] TODO-19: CI smoke run of a sample of generated demos (network allowed, a fixed small set of catalog rows covering each response type), so a broken catalog row fails CI instead of a user's session. Full-catalog runs stay out of CI.
- [ ] TODO-20: Cache helper `edi_dataset_cache(action = c("info", "clear"))`: report location and size, and clear all or one dataset's cached archive. Named for what it caches (datasets), not the feature that triggers the download, so it also covers any future non-demo fetch.
- [ ] TODO-21: Offline behavior. With no network and no cached copy, the demo stops before generating output and says where the cache directory is and which file to place there by hand.
- [x] TODO-22: Pinned-version defect (resolved 2026-10-07). Checked all 151 unique
  CRAN package/version pairs in both catalogs against CRAN's Archive and current
  index: most of the "dotted version" rows were never wrong (many packages use
  dotted versions natively on CRAN). Only 4 pairs were real transcription bugs
  (`survival 3.8.6`, `AER 1.2.17`, `granova 2.0.0`, `R4HCR 0.1.0` — 22 catalog
  rows), fixed to the real CRAN strings (`3.8-6`, `1.2-17`, `2.0`, `0.1`). Both
  catalog CSVs rebuilt; all 151 pairs now resolve exactly. Separately, the 15
  datasets the earlier scan reported as unloaded all fetch fine on retest; that
  was transient network failure during the scan, not a catalog defect.
- [ ] TODO-23: Redistribution messaging. Restricted rows (ICPSR, Dataverse terms) print the required manual step and target path at the top of the summary, before any download is attempted.
- [ ] TODO-24: Publish the class-to-dataset coverage table in the reference docs, generated from the registry from TODO-18, so users can see which classes have demos.
- [ ] TODO-25: Decide Python parity for the demos (in scope for v1, or documented as R-only).
- [ ] TODO-26: Small items: confirm `print` is in the signature (the summary planned it); a line in each demo's output stating what it does not show (for example, that imposed clusters are invented); a per-dataset citation line so users credit the source.
- [ ] TODO-13: Move the specs to `inst/demos/` and the pairing helper into
  `R/`. Test: a fresh install with no repo checkout runs `edi_inference_demo()` for one
  class.
- [ ] TODO-10: Pair construction helper (cross-arm caliper nonbipartite match; unmatched subjects to the reservoir), with tests that no pair is same-arm, that no pair exceeds the caliper, and that every subject is in exactly one pair or the reservoir; runtime structure verification and the "no qualifying dataset"
  message in `edi_inference_demo()`.

## TODO

- [ ] TODO-1: Class metadata reader + unit test on three classes (one continuous,
  one incidence, one survival).
- [ ] TODO-2: Catalog matcher against both CSVs, including the redistribution
  filter. Test: ICPSR rows never produce embedded data.
- [ ] TODO-3: Design-mapping function per response type (continuous, incidence,
  count, proportion, survival, ordinal). Test: each produces a valid design on a
  small catalog dataset.
- [ ] TODO-4: Template renderer. Test: every emitted script parses with `parse()`.
- [ ] TODO-5: `edi_inference_demo()` entry point with `dataset`, `fast`, `write_to` arguments.
- [ ] TODO-6: Smoke test: one generated script per response type runs to completion
  under `fast = TRUE` (run in a test, not in CI for the full catalog).
- [ ] TODO-7: Roxygen "Real-data demo" lines (after `edi_inference_demo()` exists) and a vignette section (no roxygenize mid-batch; see
  project memory on doc batches).

## Open decisions (defaults chosen; confirm before implementing)

Resolved 2026-10-06: data-only CRAN fetch instead of install; CRAN and base R sources only in v1; ICPSR and redistribution-flagged rows excluded.

Open (2026-10-08, after the `redistribution` column was re-valued): demos fetch data at
run time and never embed it, so the 29 `no: GPL-2 only` rows (HSAUR3, PASWR2, COUNT,
ISLR, vegan, …) are not actually barred from a demo — only from being bundled. Default
kept as "starts with `yes`" (301 rows) for simplicity; relaxing the filter to
"`yes` or `no: GPL-2 only`" would add those 29.


1. **Output.** Default: print to console; `write_to` writes a file. Files are not
   stored under `R/demos/` in v1.
2. **Speed.** Default: `fast = TRUE`. Full runs are opt-in.
3. **Dataset choice.** Superseded 2026-10-06 by `demo_number`: candidates are
   ranked, `demo_number = 1` (default) returns the top-ranked match, and
   `demo_number = k` returns the k-th; `dataset =` overrides the ranking
   outright. See "Demo number" above.
4. **Mixed-design rows.** Still open. Default: excluded (`lalonde.psid`,
   `nsw_benchmark` remain out of the catalog until decided).

Also resolved since this section was first written, each covered in its own
section above rather than repeated here: imposed clusters from a nominal
covariate (2026-10-06), `demo_number` and "demo k of M" (2026-10-06), and demo
registry regeneration via a builder script (2026-10-06).

## Out of scope for v1

- Precomputed results for every class × dataset pair.
- Running demos in CI across the full catalog (too slow; TODO-19 runs a sample only).
- Interactive or web UI.
