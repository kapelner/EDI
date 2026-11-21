### F1: Bootstrap on a KK14/KK21 sequential design stops with "This method is not supported for DesignSeqOneByOne designs", but the same call works on another DesignSeqOneByOne design, and the KK analysis help page lists the bootstrap as one of its methods
- Kind: false message
- Expected (and where the docs say so: help topic or vignette + section): `?InferenceContinKKOLSOneLik` (the inference-method table) lists `bootstrap` (asymptotic, unit "pairs + reservoir") as a method of this class, and `des$supports_resampling()` returns `TRUE` for a KK14 design. `vignette("reproducibility")` ("An inference object's own seed") runs `compute_bootstrap_confidence_interval()` on a `DesignSeqOneByOneBernoulli`, and that works. If the bootstrap really is unavailable for matching-on-the-fly designs, the error should say so ("not supported for KK matching designs"). As it stands, it names the whole `DesignSeqOneByOne` family, which includes designs where the call works.
- Observed: `InferenceContinOLS` on `DesignSeqOneByOneBernoulli` returns a percentile CI. The same inference class on `DesignSeqOneByOneKK14` (or KK21), and `InferenceContinKKOLSOneLik` on KK14/KK21, stop with
  `Error : This method is not supported for DesignSeqOneByOne designs.`
  This happens for both `compute_bootstrap_confidence_interval()` and `compute_bootstrap_two_sided_pval()`. The message names no method and no reason. Meanwhile `d_kk14$supports_resampling()` is `TRUE`. `inf$capabilities()` for `InferenceContinKKOLSOneLik` does not list a nonparametric bootstrap, which disagrees with the help-page table.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  set.seed(1); n = 40; X = data.frame(x1 = rnorm(n), x2 = rnorm(n)); y = X$x1 + rnorm(n)
  run = function(des) { for (i in 1:n) { des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE]); des$add_one_subject_response(i, y[i]) }; des }
  d_bern = run(DesignSeqOneByOneBernoulli$new(response_type = "continuous", n = n, seed = 3))
  d_kk14 = run(DesignSeqOneByOneKK14$new(response_type = "continuous", n = n, seed = 3))
  i_bern = InferenceContinOLS$new(d_bern, verbose = FALSE)
  i_kk14 = InferenceContinOLS$new(d_kk14, verbose = FALSE)
  i_bern$compute_bootstrap_confidence_interval(B = 501, type = "percentile", show_progress = FALSE)  # works: Bernoulli is a DesignSeqOneByOne
  try(i_kk14$compute_bootstrap_confidence_interval(B = 501, type = "percentile", show_progress = FALSE))
  d_kk14$supports_resampling()   # TRUE
  i_kk = InferenceContinKKOLSOneLik$new(d_kk14, verbose = FALSE)
  try(i_kk$compute_bootstrap_two_sided_pval(B = 501, show_progress = FALSE))
  ```
- Workaround used, if any: For the KK trial I used the asymptotic CI and p-value, plus the randomization p-value and CI. I did not use the bootstrap.

### F2: `clone(deep = TRUE)` of a stratified sequential design (SPBR, RandomBlockSize, PocockSimon) shares the per-stratum state with the original: advancing the copy changes the original's later assignments and breaks SPBR's permuted blocks
- Kind: inconsistency
- Expected (and where the docs say so: help topic or vignette + section): `?DesignSeqOneByOne` / `?Design` ("Seed and reproducibility") say a seeded sequential design's allocation "depends only on the seed and the subjects' covariates", and they offer `$clone(deep = TRUE)` ("Whether to make a deep clone"). A deep clone is the natural in-memory checkpoint of a trial, the counterpart of the saved file. Using it must not change the original. `saveRDS()`/`readRDS()` copies are independent (last line of the repro gives 0), so the two ways of copying a trial disagree.
- Observed: after `backup = d$clone(deep = TRUE)` at t = 30, running the copy to n = 50 changes 12 of the original's next 20 SPBR assignments. Those assignments differ from an uninterrupted run with the same seed, and 2 complete permuted blocks of 4 in the original no longer hold 2 treated and 2 control. Output: `copy_vs_uninterrupted 0, original_vs_uninterrupted 12`; `uninterrupted 0, original_after_clone 2`; saveRDS copy: `0`. The same run with the trial data in this folder: PocockSimon 8, SPBR 12, RandomBlockSize 10 of 20 assignments change. Atkinson, KK14, KK21, Efron, Urn, iBCRD and Bernoulli all give 0. No warning is shown.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  set.seed(20261122); n = 50
  S = data.frame(site = factor(sample(c("A", "B", "C"), n, replace = TRUE, prob = c(.5, .3, .2))),
                 sex = factor(sample(c("F", "M"), n, replace = TRUE)))
  mk = function() DesignSeqOneByOneSPBR$new(strata_cols = c("site", "sex"), block_size = 4,
                                            response_type = "continuous", n = n, seed = 5)
  ref = mk(); for (i in 1:n) ref$add_one_subject_to_experiment_and_assign(S[i, , drop = FALSE])
  d = mk(); for (i in 1:30) d$add_one_subject_to_experiment_and_assign(S[i, , drop = FALSE])
  backup = d$clone(deep = TRUE)            # in-memory checkpoint of the trial at t = 30
  for (i in 31:n) backup$add_one_subject_to_experiment_and_assign(S[i, , drop = FALSE])  # what-if run on the copy
  for (i in 31:n) d$add_one_subject_to_experiment_and_assign(S[i, , drop = FALSE])       # real trial continues
  c(copy_vs_uninterrupted = sum(backup$get_w() != ref$get_w()),
    original_vs_uninterrupted = sum(d$get_w() != ref$get_w()))   # both expected 0
  st = interaction(S$site, S$sex, drop = TRUE)
  bad_blocks = function(w) sum(sapply(split(w, st), function(ws) { k = floor(length(ws) / 4) * 4
    if (k == 0) 0 else sum(tapply(ws[seq_len(k)], rep(seq_len(k / 4), each = 4), sum) != 2) }))
  c(uninterrupted = bad_blocks(ref$get_w()), original_after_clone = bad_blocks(d$get_w()))
  # saveRDS/readRDS copy instead of clone: independent
  d2 = mk(); for (i in 1:30) d2$add_one_subject_to_experiment_and_assign(S[i, , drop = FALSE])
  f = tempfile(); saveRDS(d2, f); cp2 = readRDS(f)
  for (i in 31:n) cp2$add_one_subject_to_experiment_and_assign(S[i, , drop = FALSE])
  for (i in 31:n) d2$add_one_subject_to_experiment_and_assign(S[i, , drop = FALSE])
  sum(d2$get_w() != ref$get_w())           # 0
  ```
- Workaround used, if any: For checkpoints, copy the trial with `readRDS()` of a saved file (or `unserialize(serialize(d, NULL))`), never with `clone(deep = TRUE)`.

### F3: After a restore, one covariate value arriving as text silently converts that covariate to character for every earlier subject, dummy-codes it, changes later assignments, and the final analysis returns `NA` estimate, `NA` CI and `NA` p-value with no warning
- Kind: silent NA
- Expected (and where the docs say so: help topic or vignette + section): the article "Running a Sequential Trial" ("Before the first subject": "Fix the covariate list") says "A column whose type changes partway through (an integer that arrives as a character string, say) produces a warning." The warning does appear, once. The docs do not mention the consequences: the stored column for subjects already enrolled is rewritten, the covariate is then treated as a categorical with one level per distinct value, and inference later yields `NA`. A careful user would expect EDI to refuse the arrival or coerce the new value back to the established type. At the least, `compute_estimate()` should not return `NA` silently on finite inputs.
- Observed: one warning at the first text arrival, `You entered data type character for attribute named age_z that was previously entered with data type numeric`, and none for the 14 arrivals after it. Afterwards `class(des$get_X_raw()$age_z)` is `"character"` for all 40 subjects (including the 25 entered as numeric before the save) and `dim(des$get_X())` is `40 38` instead of `40 2`. `InferenceContinKKOLSOneLik`: `compute_estimate()` gives `NA`, `compute_asymp_confidence_interval()` gives `NA NA`, and `compute_asymp_two_sided_pval()` gives `NA`, with no warning or error. With the trial data in this folder (n = 50, t = 30 at the save), 7 of the 20 post-restore KK21 assignments differ from the all-numeric run, so the design-time distances were also affected.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  set.seed(3); n = 40
  X = data.frame(age_z = round(rnorm(n), 2), severity = round(rnorm(n), 2))
  y0 = 1.5 * X$severity + rnorm(n)
  des = DesignSeqOneByOneKK21$new(response_type = "continuous", n = n, seed = 5)
  for (i in 1:25) { w = des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE]); des$add_one_subject_response(i, y0[i] + 0.7 * w) }
  f = tempfile(fileext = ".rds"); saveRDS(des, f, version = 2)
  # --- machine B: covariates come from a CSV export where age_z was read as text ---
  des = readRDS(f)
  Xb = X; Xb$age_z = as.character(Xb$age_z)
  for (i in 26:n) { w = des$add_one_subject_to_experiment_and_assign(Xb[i, , drop = FALSE]); des$add_one_subject_response(i, y0[i] + 0.7 * w) }
  class(des$get_X_raw()$age_z)   # "character": earlier subjects' values were converted too
  dim(des$get_X())               # 40 38
  inf = InferenceContinKKOLSOneLik$new(des, verbose = FALSE)
  inf$compute_estimate()                              # NA, no warning
  inf$compute_asymp_confidence_interval(alpha = 0.05) # NA NA
  inf$compute_asymp_two_sided_pval()                  # NA
  ```
- Workaround used, if any: In `analysis.R`, check `sapply(x_new, class)` against the classes saved at t = 1 before each `add_one_subject_to_experiment_and_assign()`, and stop on a mismatch. A design that has already been converted cannot be repaired without a replay from the audit log.

### F4: The installed package reports version 1.0.4 and stamps saved designs "1.0.4", but the docs describe its sequential seeding as "v1.0.6" behaviour and say that earlier versions seeded differently, so a trial file's version stamp points to the wrong allocation rule
- Kind: inconsistency
- Expected (and where the docs say so: help topic or vignette + section): `?Design` ("Saving and loading": "A sequential design (v1.0.6) seeds each assignment from (seed, the subject's index t)") and `vignette("reproducibility")` ("What a design's seed guarantees": "Since v1.0.6; before that the sequential seed was applied once, in the constructor, and every later assignment drew from the global stream") make the allocation rule depend on the version. The article "Running a Sequential Trial" ("The audit trail", checklist step 1) says to record the EDI version, and `get_edi_version_created()` is the stamp for this. The stamp and `packageVersion("EDI")` should name a version whose documented seeding rule matches what this build does.
- Observed: `packageVersion("EDI")` is `1.0.4` and `get_edi_version_created()` is `"1.0.4"`. Yet the build already has the per-subject seeding with stream restore that the docs date to v1.0.6 (`identical(u_alone, u_around)` is `TRUE`). NEWS.md is headed "EDI (development version)" with v1.0.6 TODO tags. An auditor who reads the docs and replays a trial file stamped "1.0.4" with a released 1.0.4 would, by the docs' own account, get the old constructor-only seeding and a different allocation. The major-version check on reload cannot catch this either: per `?Design`, minor/patch differences are silent.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  packageVersion("EDI")                # 1.0.4
  set.seed(1); X = data.frame(x1 = rnorm(10))
  des = DesignSeqOneByOneBernoulli$new(response_type = "continuous", n = 10, seed = 42)
  des$get_edi_version_created()        # "1.0.4"
  set.seed(7); u_alone = runif(2)
  set.seed(7); u_around = c(runif(1), { for (i in 1:10) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE]); runif(1) })
  identical(u_alone, u_around)         # TRUE: the "v1.0.6" per-subject seeding is present
  grepl("1.0.6", readLines(system.file("doc", "reproducibility.Rmd", package = "EDI"))[70])  # TRUE: "Since v1.0.6; ..."
  ```
- Workaround used, if any: In the trial file's audit log I recorded `packageVersion("EDI")` together with a fingerprint of the allocation rule (the first 10 assignments of a reference run with a fixed seed), so a replay can detect a different seeding rule.

### F5: A sequential design with a fixed `n` silently accepts subject n + 1; `check_experiment_completed()` then returns `TRUE` and inference analyzes n + 1 subjects while `get_n()` still reports n
- Kind: accepted bad input
- Expected (and where the docs say so: help topic or vignette + section): the article "Running a Sequential Trial" ("Set n") and `?DesignSeqOneByOne` ("Sample size and stopping") say the caller must stop at exactly `n` and that "EDI's fixed-sample analysis assumes that the number of subjects was fixed before enrollment". The article ("When some outcomes never arrive") says "The same check refuses an analysis when fewer than n subjects enrolled". So enrollment is not stopped for you, but a completion check should equally refuse, or at least warn, when *more* than `n` enrolled. In a trial resumed from a file on another machine, a subject entered twice is a realistic error. Today it goes undetected: the protocol's `n` and the analyzed sample differ, and nothing says so.
- Observed: with `n = 30`, the 31st `add_one_subject_to_experiment_and_assign()` returns an assignment with no message. Then `c(n = 30, t = 31, length_w = 31)`, `check_experiment_completed()` returns `TRUE`, and `InferenceContinKKOLSOneLik$new()` / `compute_estimate()` run on 31 subjects with no warning. The same happens on KK21 with n = 50 (51 subjects, estimate 1.0396 instead of 1.0330).
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  set.seed(4); n = 30; X = data.frame(x1 = rnorm(n + 1), x2 = rnorm(n + 1)); y = X$x1 + rnorm(n + 1)
  des = DesignSeqOneByOneKK14$new(response_type = "continuous", n = n, seed = 1)
  for (i in 1:20) { des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE]); des$add_one_subject_response(i, y[i]) }
  f = tempfile(); saveRDS(des, f); des = readRDS(f)          # resumed on another machine
  for (i in 21:(n + 1)) { des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE]); des$add_one_subject_response(i, y[i]) }  # one too many
  c(n = des$get_n(), t = des$get_t(), length_w = length(des$get_w()))   # 30 31 31
  des$check_experiment_completed()                            # TRUE, no warning
  inf = InferenceContinKKOLSOneLik$new(des, verbose = FALSE)  # no warning
  inf$compute_estimate()
  ```
- Workaround used, if any: My `enroll()` wrapper in `analysis.R` stops when `des$get_t() >= des$get_n()` before assigning.

