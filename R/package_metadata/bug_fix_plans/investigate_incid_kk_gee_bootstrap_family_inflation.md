# Investigation: `InferenceIncidKKGEE` Bootstrap-Family Type-I Inflation — Historical Finding Not Reproduced, Leading Hypothesis Refuted

> **Depends on:** none. (Global ordering: see `../new_feature_plans/_master.md`.) Slated for
> `release_v1_0_5.md → TODO-21`. Added 2026-09-23, same audit-triage wave as
> TODO-17/18/19/20. Possibly related in kind (not mechanism) to
> `investigate_contin_quantile_regr_bootstrap_family_inflation.md`
> (TODO-20) — both are "asymptotic-SE-based methods whose variance
> estimator has known finite-sample fragility under resampling." **This is
> an open investigation, not a confirmed bug.** `release_v1_0_5.md`'s own
> TODO-21 entry explicitly says: "Do not write a plan file without first
> pulling the exact historical dataset/design/formula and confirming the
> inflation reproduces on it." That has NOT been done. This file exists to
> give the thread a durable home and record what's been ruled out so far —
> it is not a green light to start fixing anything, and the bottom line
> below is deliberately "genuinely unclear," not a diagnosis.

## The finding

Historical `comprehensive_tests` CSV rows show `InferenceIncidKKGEE` with
the same consistent-direction bootstrap-family inflation shape as TODO-20:
- `compute_bayesian_bootstrap_two_sided_pval_wald`: 0.314 vs. nominal 0.05.
- `compute_bayesian_bootstrap_two_sided_pval`: 0.306 vs. nominal 0.05.
- `compute_rand_bootstrap_two_sided_pval_symmetric-percentile-t`: 0.185 vs.
  nominal 0.05.

**Provenance reconciliation (read-only, 2026-10-16):** Those three headline
rates are not traceable to the tracked audit baseline, the current raw CSV,
or the older local raw snapshot inspected below. The tracked
`comprehensive_results_audit_baseline.csv` (mtime 2026-09-24 15:59:56 +0300;
756,199 bytes) was committed alongside this plan in `2d382ee1`
(2026-09-24 00:21:22 +0300), but its `InferenceIncidKKGEE` entries do not
report .306/.314/.185. For `model_formula=~1`, it records the symmetric BB
variant (not the unsuffixed default function) and BB-Wald rejection rates
of .054 (n=130 each), plus symmetric-percentile-t BRT of .065 (n=123); the
audit's nonuniformity flags in these rows reflect an excess of large
p-values, not those headline rejection fractions.

The audit implementation's denominator/filtering is: retain
`status == "ok"`, finite `result_1` p-values in [0,1], exclude function names
containing `(delta=`, and select `beta_T == 0`; aggregate by bare class,
`model_formula`, and `function_run`. It pools dataset, design, and
`design_formula`. The audit stamp records its older incidence input as
561,975,056 bytes with mtime epoch 1790497128 (2026-09-27 08:18:48 UTC).
The currently retained
`comprehensive_tests_results_nc_1_incidence.csv` is a different artifact:
525,863,531 bytes, mtime 2026-10-09 01:14:03 +0300. Its available
`pima`/`KK21stepwise`/n=148 rows carry source commit
`5d8246300ea034bed7f4591d7f2258a7215436eb` (2026-09-07 14:16:40 +0300).
For beta_T=0, stratifying these rows by (`model_formula`,
`design_formula`) gives BRT symmetric-percentile-t rejection rates .028
(1/36) for `(~., ~.)`, .162 (6/37) for `(~., ~1)`, .028 (1/36) for
`(~1, ~.)`, and .108 (4/37) for `(~1, ~1)`; BB default/Wald rates are
.025–.10 across those strata. These are not the
three headline rates, and the current strata are narrower than the audit's
pooling rule. The plan/release headline has no recorded raw-input path,
source stamp, denominator, or aggregation definition, so its original input
and grouping cannot be recovered from the retained files. An alternate run
or aggregation is possible but unverified; no causal attribution is
justified until the original input artifact and its aggregation are
recovered. Keep this investigation open.

**Older snapshot check (read-only, 2026-10-16):** The only earlier raw
incidence snapshot found locally is the non-Git backup
`/tmp/edi-v105-r6-benchmark.eQ0PpT/R/package_tests/comprehensive_tests_results_nc_1_incidence.csv.pre_anomaly_fix_removal.bak`
(523,788,866 bytes; file mtime 2026-09-07 17:54:14 +0300). Its rows identify
source commit `8918bada0547a6bfb5454b8623c69e8d50ccc6b5` (2026-08-24
11:00:32 +0300), so it is an earlier, differently-versioned run, not the
missing 2026-09-27 stamped input. Applying the documented audit p-value
filter to this snapshot (`status=ok`, `beta_T=0`, finite `result_1` in
[0,1], no delta-shifted function), then grouping across dataset/design by
`(bare class, model_formula, function_run)` and counting `result_1 < .05`,
gives unsuffixed BB-default rates 3/153=.0196 (`~.`) and 2/158=.0127 (`~1`), and BB
Wald rates 4/153=.0261 (`~.`) and 3/158=.0190 (`~1`). It contains no
`InferenceIncidKKGEE` symmetric-percentile-t randomization-bootstrap rows,
so it cannot reproduce the .185 headline at all. These earlier rows also do
not yield .306/.314. The tracked baseline at the headline's plan commit
`2d382ee1` includes the symmetric BB, BB-Wald, and BRT families (but not
the exact unsuffixed BB-default function), and reports rejection fractions
.054, .054, and .065 for `model_formula=~1` (n=130, 130, 123 respectively),
not the headline. The raw CSV named by the
audit stamp (561,975,056 bytes, mtime 2026-09-27 08:18:48 UTC) is not present
in Git or among the retained local snapshots; the stamp itself is untracked.
Thus no committed snapshot plus documented filter reproduces
the headline, and the missing raw input, source/run commit, denominator,
and aggregation strata are the exact unresolved provenance.

**Candidate-file checksum audit (read-only, 2026-10-16):** no accessible file
under `/tmp` or `R/package_tests` matched the stamped 561,975,056-byte size.
The retained full CSV is 525,863,531 bytes (SHA-256
`03f9ba580d55d0664f6f85a3e3f20f62a5a426dd546e1cdb03656ae688d50436`); the
2026-10-15 full snapshot is 525,208,409 bytes (SHA-256
`cdbd73e119a72d30a983dbb0a47153a42aca63399958451f3342ff4b084b2a01`); the
27,124,848-byte filtered diagnostic is a distinct subset (SHA-256
`57ee1554cacf7ae1a64b38ff2413b7ea90d0ba3247438b39f6ab6cc73caca417`); and
the 523,788,866-byte Sep 7 backup has SHA-256
`be7dbb7503c0e44c805816bf64831229abd9b904693e642221cc9991716ad1d4`.
The full snapshot in the TODO-56 scratch tree is byte-identical to the
retained full CSV, and the TODO-9 scratch backup is byte-identical to the
Sep 7 backup; neither is another historical candidate. These checks confirm
the missing stamped input among the retained accessible candidates, but do
not establish that the .306/.314/.185 rates were erroneous or that the
current code is free of the reported behavior. Without that exact raw input
(or a source/run seed plus equivalent fixture), the historical class,
dataset/design/formula rows cannot be replayed or used to justify a fix.

**Stamp recovery (read-only, 2026-10-20):** the audit stamp is now located at
`R/package_tests/.comprehensive_results_audit_stamp` and an identical copy is
at `/tmp/edi-v105-r6-benchmark.eQ0PpT/R/package_tests/.comprehensive_results_audit_stamp`.
Both are 403 bytes, dated 2026-09-27 13:08 +0300; the workspace copy is
ignored by `.gitignore` and neither path has tracked Git history. The stamp
records the incidence input as 561,975,056 bytes with mtime epoch 1790497128,
confirming the exact file size/mtime metadata quoted above. It lists only
response-CSV names, sizes, and mtimes; it contains no CSV contents, DGP,
dataset/design/formula strata, RNG seed schedule, source/run commit, or
aggregation rule. The extant full incidence CSV is still 525,863,531 bytes
(2026-10-09), the Sep 7 backup is 523,788,866 bytes, and the known TODO-9
scratch incidence file is a 27,124,848-byte subset; none is the stamped
input. Thus the stamp metadata is recoverable, but the historical raw CSV
and the provenance needed to replay its headline cells remain missing.

Originally-suspected cause: naive row-level bootstrap breaking GEE
matched-pair structure — resampling rows independently would ignore the
matched-pair clustering, understating true variance and inflating Type-I
error, a well-known failure mode for cluster-correlated data under a naive
bootstrap.

## Hypothesis (reservoir-singleton mishandling) — pair-vs-singleton grouping hypothesis refuted; a separate scalar-resampling defect was found 2026-10-20

**Claim**: `InferenceIncidKKGEE` uses matching-aware bootstrap machinery
(`bootstrap_sample_indices()` → design's `draw_bootstrap_indices()` →
`private$draw_matching_bootstrap_indices()` for matching-capable designs,
`design_matching_abstract.R:107-113`), shared across 4 `KKGEE`-family
classes (`InferenceCountPoissonKKGEE`, `InferenceIncidKKGEE`,
`InferenceOrdinalKKGEE`, `InferencePropKKGEE`,
`inference_class_registry.R:326-331`). Each cluster is either a matched
pair (2 members) or a reservoir singleton (1 member), per
`inference_incidence_KK_combined.R:6-7`. Pair-resampling logic that's
correct for 2-member clusters could plausibly mishandle 1-member ones
(e.g. resampling a "singleton pair" as if it always had 2 members, or
losing the cluster boundary entirely for singletons).

**Pair-vs-singleton grouping hypothesis refuted**: read the full chain — `design_matching_abstract.R:55-114`
(separates reservoir-singleton indices from matched-pair row pairs, both
cached in `init_matching_bootstrap_structure()`) and
`bootstrap_match_indices.cpp:92-130` (`draw_matching_bootstrap_sample_cpp`,
the actual C++ resampler). The output grouping is correct: matched pairs
remain intact and receive fresh pair IDs. However, a new focused singleton
fixture found that `sample_fn(i_reservoir, size, replace=TRUE)` is not correct
for a length-one numeric row-index vector: R interprets `sample(7L, ...)` as
sampling from `1:7`, rather than repeatedly drawing the sole row index 7.
The focused installed-package test failed this new fixture (4/4 returned
indices differed from 7). The checkout source now samples positions and maps
them back to reservoir row indices; this source edit has **not** been
compiled or validated against a rebuilt native library. Thus the original
pair-grouping concern is refuted, but the blanket conclusion that singleton
resampling is correct was too broad. This is a concrete kernel defect, but
the historical `.306/.314/.185` rates remain unproven and cannot yet be
attributed to it.

## Direct reproduction attempt — ALSO did not reproduce the historical inflation

A fresh true-null `InferenceIncidKKGEE` fixture (`DesignSeqOneByOneKK14`,
loaded via `pkgload`, no compilation) gave:
- `compute_bayesian_bootstrap_two_sided_pval(type="wald")` = **0.050**
  (n=100, B=200, 40 reps — exactly nominal).
- default variant = **0.025** (mildly conservative).
- A second, smaller check (n=60, B=100, 25 reps) gave **0/25 rejections** —
  consistent with nominal/conservative, not inflated.

Neither run is remotely close to the historical 0.306–0.314.

## Historical replay limitation (owner disposition recorded 2026-10-21)

The available replacement-fixture reproductions used a single simple
covariate/default settings or Pima data, while the flagged historical rows
were at `model_formula=~1` AND
`~.` (both flagged, different rates) on whatever specific dataset the
harness used for this class — the **same shape as the already-CONFIRMED**
`InferenceContinLin` bug (`contin_lin_param_bootstrap_bad_type1_error.md`
/ TODO-15's sibling finding), where `~1` vs `~.` on one specific real
dataset with near-collinear covariates was the actual trigger, not a
generic class property. The reproduction attempt above did not use that
exact dataset/design/formula combination — it built a fresh simplified
fixture instead, which is exactly the kind of substitution that already
failed to reproduce TODO-19's historical finding.

Also not checked: whether the other three `KKGEE`-family classes
(`InferenceCountPoissonKKGEE`, `InferenceOrdinalKKGEE`, `InferencePropKKGEE`)
show the same historical pattern — if they do, that argues for a shared
mechanism (weakening the "specific dataset/formula trigger" explanation);
if they don't, that strengthens it.

## Historical replay path if this investigation is reopened

**Disposition:** on 2026-10-21 the owner closed the historical-inflation
claim as not reproducible on the available evidence. The exact historical
input and full execution provenance remain unavailable, so the claim was not
independently replayed; that evidence gap does not leave this historical
investigation open. This disposition does not validate or close the separate
2026-10-20 scalar-resampling source fix, whose native-provenance validation
remains independent. The older replay checklists and open-status wording
below predate this decision; they describe optional work only if the
historical investigation is reopened, not an active v1.0.5 acceptance gate.

**Static CSV re-audit 2026-10-09:** the retained size rows do preserve the
triggering design/formula strata even though they do not retain the source
dataset name. The largest historical BRT inflation is concentrated in
`KK21stepwise` at `model_formula = ~1` and `~.` (for example the
studentized and symmetric-percentile-t variants are 0.1622 over 37 rows);
the same family has materially smaller FixedBinaryMatch rows. This supports
the plan's requirement to replay the exact harness dataset and both model
formulae, and it does not justify a code change. Runtime replay remains
pending because this host's `Rscript` cannot load `libmkl_gf_lp64.so.2`.

- [ ] Pull the *exact* historical dataset/design/`model_formula` combination
  from the flagged `comprehensive_tests` CSV rows (both the `~1` and `~.`
  rows) — not a fresh simplified fixture — and attempt reproduction with
  that exact combination.
- [ ] Check whether `InferenceCountPoissonKKGEE`, `InferenceOrdinalKKGEE`,
  `InferencePropKKGEE` show the same historical inflation pattern in the
  CSV, to determine whether this is class-specific or shared across the
  `KKGEE` family.
- [ ] If reproduced, check whether it's specifically a near-collinear-
  covariates-under-`~.`-formula trigger (matching `InferenceContinLin`'s
  confirmed mechanism) rather than a generic bootstrap-correctness bug,
  given the code trace above already ruled out the resampling machinery
  itself.
- [ ] If NOT reproduced even with the exact historical dataset/formula,
  treat this as likely resolved/noise (per the historical CSV possibly
  predating a fix, or reflecting a since-corrected upstream issue) and
  close TODO-21 without a code change, documenting that conclusion in
  `release_v1_0_5.md`.
- [ ] Only write a proper `# Fix:` plan if the above confirms a concrete,
  currently-broken mechanism.

## Bottom line (historical assessment before the 2026-10-21 disposition)

This may be resolved/noise, may need the exact triggering dataset to
reproduce, or may not be a real defect at all — genuinely unclear. Do not
write a fix plan or attempt a code change without first pulling the exact
historical dataset/design/formula and confirming the inflation reproduces
on it.

### TODO-21 independence/provenance checkpoint (2026-10-18; predates closure)

TODO-21 can remain independently scoped while TODO-20 is investigated: its
specific class, method-family headlines, and refuted reservoir-singleton
mechanism are already documented here. However, it cannot be independently
reproduced from the retained artifacts: neither the tracked audit baseline,
current incidence CSV, nor older local snapshot contains the three headline
rates, and the stamped 2026-09-27 raw input (561,975,056 bytes) is unavailable
(its byte/mtime audit stamp has since been recovered, but is metadata only).
Do not use TODO-20's evidence as a substitute or let its outcome close this
item. The next useful input is that exact historical raw CSV plus its audit
stamp/source provenance, or an equivalent row export preserving both formulae,
dataset/design, method family, denominator and run identifiers. Only then can
the exact cells and remaining KKGEE-family comparisons be selected without
another all-data scan. No simulation or code change was performed for this
checkpoint.

**Cross-family baseline check (same date):** a bounded read-only query of the
tracked `comprehensive_results_audit_baseline.csv` found p-value-miscalibration
rows for neighboring `InferenceCountPoissonKKGEE` (including
Bayesian-bootstrap and studentized-bootstrap methods), but none for
`InferenceOrdinalKKGEE` or `InferencePropKKGEE`. This older pooled baseline
does not preserve source dataset/run identity, has a different response type,
and its `InferenceIncidKKGEE` rows do not reproduce the three headline rates;
therefore it cannot establish a shared KKGEE mechanism. Keep TODO-21 separate
from TODO-20 and defer any broader conclusion until the exact stamped raw
input is recovered. No result CSV or simulation was touched.

**Tracked-artifact schema audit (read-only, 2026-10-18):** directly reading
the tracked `comprehensive_results_audit_baseline.csv` (756,199 bytes) shows
only `key`, `check`, `response_type`, `class`, `formula`, `function_run`, and
`detail`; its 13 `InferenceIncidKKGEE` entries are aggregate summaries, not
seed-level rows. The `~1` summaries for the three implicated methods report
their own baseline denominators/rates (BB-Wald 130/.054, symmetric BB
130/.054, BRT 123/.065), but do not match .314/.306/.185. The artifact has
no dataset, design, `design_formula`, DGP parameters, seed schedule,
individual results, or execution commit/runtime stamp. The tracked commit
that contains this summary is known, but is not a substitute for the missing
source/run provenance of the headline. Consequently, no retained
comprehensive artifact reconstructs those historical cells; the current
incidence raw CSV and TODO-56 scratch output were not read. No simulation or
canonical output was touched.

**Independent resampling-invariant check, 2026-10-20:** the focused
`test-matching-bootstrap-draw-grouping-and-match-stats-kernels-reference.R`
passed 1,216 expectations against installed EDI 1.0.3. Its 200-draw structural
fixture verifies that reservoir observations are sampled as singleton units
and matched pairs remain intact with freshly assigned pair IDs. This is
consistent with the code-trace finding that refuted the reservoir-singleton
hypothesis; it does not exercise the historical KKGEE null rates, recover the
missing input, or establish current-checkout native provenance. No historical
CSV, broad simulation, or canonical output was read or written.

**Focused kernel regression, installed-package evidence (2026-10-20):**
`test-compute-bootstrap-matching-stats-kernel-reservoir-pairs-and-column-pruning-reference.R`
completed with exit status 0: 342 expectations passed, with 0 failures,
warnings, or skips. The tested package was EDI 1.0.3 from
`/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`; loaded native library
`/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI/libs/EDI.so` had MD5
`a75519a9256c0b3121398032314291d4` and SHA-256
`dd9dd9a4c3c13619c473b29c6e90fd4b44d75903e25e6fa5ab78c91457c18716`.
Command: `Rscript -e 'library(EDI); cat("Version:", as.character(packageVersion("EDI")), "\nLibrary:", find.package("EDI"), "\n"); dll <- getLoadedDLLs()[["EDI"]][["path"]]; cat("DLL:", dll, "\nMD5:", unname(tools::md5sum(dll)), "\n"); testthat::test_file("R/package_tests/testthat_bulk/test-compute-bootstrap-matching-stats-kernel-reservoir-pairs-and-column-pruning-reference.R")'`.
Checkout HEAD at recording time was `4f7a6e4ca82829e880c15a76699701a95e5e83b9`;
this run loaded the installed EDI 1.0.3 artifact, not the checkout source/native
library, so it is focused regression evidence but not current-checkout native
validation. The historical `.306/.314/.185` result remains unconfirmed: its
stamped raw input, DGP, seed schedule, denominator, and pooling provenance are
still missing. No historical CSV or canonical output was read or written.

**Installed/checkout native artifact identity recheck (2026-10-20):** the
currently installed EDI 1.0.3 DLL at
`/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI/libs/EDI.so` and the
checkout artifact `R/EDI/src/EDI.so` are byte-identical (both 14,727,184
bytes; SHA-256
`dd9dd9a4c3c13619c473b29c6e90fd4b44d75903e25e6fa5ab78c91457c18716`, MD5
`a75519a9256c0b3121398032314291d4`). Both had mtimes within the same second
on 2026-10-20 09:38:02 +0300. The R runtime reported package version 1.0.3,
library `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`, and loaded
that installed DLL. This establishes artifact identity between the installed
DLL and the checkout's existing `src/EDI.so`; it does **not** establish that
the binary was built from checkout HEAD. HEAD remains
`4f7a6e4ca82829e880c15a76699701a95e5e83b9`, while
`R/EDI/src/bootstrap_match_indices.cpp` is modified in the worktree relative
to HEAD with the reservoir-position sampling fix. No build/install or focused
test was run at that checkpoint. The historical inflation inputs and
current-head native validation gates remained open then.

**Current installed-artifact singleton regression recheck, 2026-10-20:**
`Rscript -e 'library(EDI); testthat::test_file("R/package_tests/testthat_bulk/test-matching-bootstrap-draw-grouping-and-match-stats-kernels-reference.R", reporter = "summary")'`
passed 1,216 expectations with 0 failures, warnings, or skips. The fixture
covers paired-unit preservation, a length-one reservoir index, multi-row
seeded sampling and RNG state, and grouping/statistics invariants. The installed EDI 1.0.3 DLL SHA-256
`db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041` is
byte-identical to checkout `R/EDI/src/EDI.so`. This validates the focused
resampling mechanics in the available artifact, not the historical
`.306/.314/.185` rates or their cause; artifact identity alone does not supply
a build manifest. The stamped historical input and its DGP, seed schedule,
denominator, and pooling provenance remain missing. No build/install,
simulation, historical CSV, or canonical output was used.

**Checkout-R-source overlay regression recheck, 2026-10-20:** the same focused
`test-matching-bootstrap-draw-grouping-and-match-stats-kernels-reference.R`
passed 1,225 expectations across seven test blocks (0 failures, warnings, or
skips) after `pkgload::load_all("R/EDI", compile = FALSE, quiet = TRUE)`.
Runtime was R Under development (unstable) (2026-10-13 r90668), package
version 1.0.3, and the namespace source path was the checkout
`/home/kapelner/workspace/EDI/R/EDI`. The loaded DLL MD5 was
`8b3ca30492d7b1c790deeebe94b201ad`; this is source-overlay R-layer evidence
using an existing native DLL, not a build or validation of the modified
checkout C++ reservoir fix. The test verifies deterministic match-stat and
reservoir/pair-grouping contracts; it does not reproduce or attribute the
historical `.306/.314/.185` rejection rates. The stamped historical inputs
(dataset/design/formula, DGP, seed/RNG state, denominator, and pooling rule),
or a maintainer-approved equivalent, remain required. No build/install,
simulation, historical CSV, or canonical output was used.

**Retained-input provenance recheck (read-only), 2026-10-20:** the workspace
audit stamp is 403 bytes (SHA-256
`ea3dd4ef6872c4a7e398fb20469ba438ed59d6f781bfe684811adf7b05a93b70`) and
lists response-CSV names, byte sizes, and mtime epochs only; it contains no
dataset/design/formula strata, DGP, RNG state or seed schedule, source/runtime
identity, denominator, or pooling rule. Its incidence entry expects
561,975,056 bytes at epoch `1790497128`. The named current incidence CSV is
525,863,531 bytes (2026-10-09); metadata-only filename search found retained
same-name copies of 525,208,409 bytes and 27,124,848 bytes, none matching the
stamped input. A second full-size copy is byte-size/mtime-identical to the
current file, not an independent historical candidate. No class-filtered
historical `InferenceIncidKKGEE` incidence CSV or owner-approved replacement
manifest was found by the scoped filename/plan audit; the 298-byte
`/tmp/edi-todo21-kkgee-provenance-20261020.csv` contains only a header and no
attempt rows. This confirms the evidence gap, not the absence of every
possible backup. The 1,225-expectation source-overlay test remains a
resampling-mechanics regression only; it is not an empirical reproduction of
the historical `.306/.314/.185` rates. No large CSV was read, no R process
was run, and no result or canonical artifact was changed.

## Standing constraints

No `R CMD INSTALL`/rebuild of `R/EDI` without being asked in that turn;
verify via `pkgload::load_all(".", compile = FALSE)` only, never a full
build (hard project rule, see top-level `CLAUDE.md`).

## Fresh true-null simulation 2026-10-21 (300 reps; does NOT reproduce the inflation)

`InferenceIncidKKGEE`, Pima (Tr+Te) rows, n=148, `DesignSeqOneByOneKK21stepwise`,
response = diabetes status independent of assignment (true null), B = 101, 300
seeds per formula, installed EDI 1.0.3 (no compile; `compute_rand_two_sided_pval`
is unsupported for this incidence class so it is not testable here). Rejection
rate at 0.05 / 0.10 (SE about 1.3 points):

| formula | BB (default) | BB Wald | BRT percentile | BRT studentized | BRT sym-pct-t |
|---|---|---|---|---|---|
| ~1 | .050 / .073 | .050 / .083 | .053 / .090 | .067 / .090 | .060 / .083 |
| ~bmi+age | .050 / .093 | .050 / .093 | .050 / .113 | .057 / .110 | .043 / .097 |

All rates are nominal or slightly conservative; the historical .306 / .314 /
.185 was not reproduced (consistent with the tracked baseline's ~.054 / .065).
Limits: one dataset and design, fixed n, B=101; this does not test the
2026-10-20 scalar-resampling kernel defect separately, and the original harness
cell was never recovered. Suggested disposition (owner's call): close the
historical-inflation claim as not reproducible; keep the kernel defect on its own
validation track.

**Closed 2026-10-21 by owner decision: not reproducible.** This applies the plan's own "if NOT reproduced" rule; the open boxes above are moot. The separate scalar-resampling kernel defect (2026-10-20) is not covered by this closure.
