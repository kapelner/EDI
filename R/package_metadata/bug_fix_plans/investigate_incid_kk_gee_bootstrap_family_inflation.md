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
in Git or among the retained local snapshots; the stamp itself is also
untracked. Thus no committed snapshot plus documented filter reproduces
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

Originally-suspected cause: naive row-level bootstrap breaking GEE
matched-pair structure — resampling rows independently would ignore the
matched-pair clustering, understating true variance and inflating Type-I
error, a well-known failure mode for cluster-correlated data under a naive
bootstrap.

## Hypothesis (reservoir-singleton mishandling) — REFUTED 2026-09-23 by code trace AND direct reproduction, high confidence on the code being correct

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

**Refuted**: read the full chain — `design_matching_abstract.R:55-114`
(separates reservoir-singleton indices from matched-pair row pairs, both
cached in `init_matching_bootstrap_structure()`) and
`bootstrap_match_indices.cpp:92-130` (`draw_matching_bootstrap_sample_cpp`,
the actual C++ resampler). This is textbook-correct cluster bootstrap:
reservoir singletons resampled i.i.d. with replacement, matched pairs
resampled as intact 2-member units with fresh relabeled pair IDs. No
mishandling of the singleton case found.

## Direct reproduction attempt — ALSO did not reproduce the historical inflation

A fresh true-null `InferenceIncidKKGEE` fixture (`DesignSeqOneByOneKK14`,
loaded via `pkgload`, no compilation) gave:
- `compute_bayesian_bootstrap_two_sided_pval(type="wald")` = **0.050**
  (n=100, B=200, 40 reps — exactly nominal).
- default variant = **0.025** (mildly conservative).
- A second, smaller check (n=60, B=100, 25 reps) gave **0/25 rejections** —
  consistent with nominal/conservative, not inflated.

Neither run is remotely close to the historical 0.306–0.314.

## Open question, not yet checked (the concrete next step)

The reproduction fixture used a single simple covariate and default
settings, while the flagged historical rows were at `model_formula=~1` AND
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

## Next steps (none done yet)

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

## Bottom line

This may be resolved/noise, may need the exact triggering dataset to
reproduce, or may not be a real defect at all — genuinely unclear. Do not
write a fix plan or attempt a code change without first pulling the exact
historical dataset/design/formula and confirming the inflation reproduces
on it.

### TODO-21 independence/provenance checkpoint (2026-10-18)

TODO-21 can remain independently scoped while TODO-20 is investigated: its
specific class, method-family headlines, and refuted reservoir-singleton
mechanism are already documented here. However, it cannot be independently
reproduced from the retained artifacts: neither the tracked audit baseline,
current incidence CSV, nor older local snapshot contains the three headline
rates, and the stamped 2026-09-27 raw input (561,975,056 bytes) is unavailable.
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

## Standing constraints

No `R CMD INSTALL`/rebuild of `R/EDI` without being asked in that turn;
verify via `pkgload::load_all(".", compile = FALSE)` only, never a full
build (hard project rule, see top-level `CLAUDE.md`).
