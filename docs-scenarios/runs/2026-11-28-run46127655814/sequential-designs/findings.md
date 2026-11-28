# Findings: sequential-designs (run 2026-11-28, EDI 1.0.5)

### F1: With `missingness_method = "error"`, KK14 and Atkinson accept and assign a subject whose covariate is missing during the first few arrivals, then refuse every later (complete) arrival, so the trial can never continue
- Kind: documented option fails
- Expected (and where the docs say so: help topic or vignette + section): `?Design`, `$new()` argument `missingness_method`, `"error"`: "An error is thrown as soon as any missing value is detected in the covariate matrix." The article "Running a Sequential Trial" ("Fix the covariate list") says a subject that cannot be entered "is refused with an error naming the column and the design is left as it was, so you can correct the value and add the subject again". So the arrival that carries the `NA` should be refused, and the design should stay usable. When the `NA` subject arrives later (t = 10), KK14 and Atkinson do refuse that arrival and stay usable.
- Observed: if the `NA` arrives early (t = 3: KK14 before matching starts, Atkinson in its Bernoulli fallback), the subject is assigned (`w = 1`, t becomes 3) with no error or warning. Arrival 4 is also assigned. From arrival 5 on, every subject, all with complete covariates, is refused with
  `Missing values detected in covariate(s): age_z. Set missingness_method = "impute" or "drop_column" to handle missing data automatically.`
  t stays at 4 for good. You cannot fix the stored `NA` (it belongs to an already-assigned subject), so with `n = NULL` or with `n = 40` the trial is stuck. The error is also raised for a subject other than the one with the missing value. It happens for both `n = NULL` and `n = 40`, and for KK14 and Atkinson alike. Efron and Bernoulli never refuse the `NA` subject at enrollment; their `InferenceContinOLS$new()` then fails at the end with the same message. That fits the "for inference" wording, but it also means the `NA` gets into the trial.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  set.seed(1)
  X = data.frame(age_z = round(rnorm(12), 2), severity = round(rnorm(12), 2))
  X$age_z[3] = NA                                   # subject 3 arrives with a missing covariate
  for (nn in list(NULL, 40)) {
    d = DesignSeqOneByOneKK14$new(response_type = "continuous", n = nn, seed = 9,
                                  missingness_method = "error")
    for (t in 1:12) {
      r = tryCatch(paste("w =", d$add_one_subject_to_experiment_and_assign(X[t, , drop = FALSE])),
                   error = function(e) paste("ERROR:", conditionMessage(e)))
      cat(sprintf("n=%-4s arrival %2d -> %s (t = %d)\n", format(nn), t, substr(r, 1, 70), d$get_t()))
    }
  }
  # arrivals 1-4 assigned (including the NA one at 3); arrivals 5-12 all ERROR, t stuck at 4.
  # Replace DesignSeqOneByOneKK14 with DesignSeqOneByOneAtkinson: same pattern.
  ```
- Workaround used, if any: use `missingness_method = "impute"` (the default) in sequential designs, or check each arrival for `NA` before calling `add_one_subject_to_experiment_and_assign()`.

### F2: With `n = NULL`, the KK14 (and KK21 fallback) matching threshold is undefined in the docs: the documented cutoff formula needs the planned `n`, and the help only says what happens to `t_0_pct`
- Kind: insufficient docs
- Expected (and where the docs say so: help topic or vignette + section): `?DesignSeqOneByOneKK14`, Description, "Matching test": the cutoff is `T^2_cutoff = p(n-1)/(n-p) F_{p,t-p}(lambda)`, "where ... n is the design's target (planned) sample size". The article "Matching on the Fly" ("KK14: Mahalanobis distance and an F threshold") says the same. For `n = NULL`, the `t_0_pct` argument entry says what happens ("matching begins once ... more than p + 2 subjects have arrived"), and `n = NULL` is the documented default. KK21's page says it "applies the KK14 rule" until it has 2(p+2) responses. So I expected one sentence on which `n` the cutoff uses when there is no planned sample size (the current `t`? something else?).
- Observed: an `n = NULL` KK14 design forms pairs from subject 5 on (25 to 30 pairs out of 60 arrivals), so some cutoff is in use. Its pair structure is not the same as that of the same design with `n` fixed at 60, 61, 200 or 1e5 (all with `t_0_pct = 0`), so you cannot find out from the docs, or by matching to a fixed `n`, which threshold was used. A protocol has to state the matching rule, and here it cannot be written down without reading the source.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  set.seed(3); n = 60
  X = data.frame(age_z = round(rnorm(n), 2), severity = round(rnorm(n), 2))
  fill = function(nn) {
    d = if (is.null(nn)) DesignSeqOneByOneKK14$new(response_type = "continuous", n = NULL, seed = 3, lambda = 0.3)
        else DesignSeqOneByOneKK14$new(response_type = "continuous", n = nn, seed = 3, lambda = 0.3, t_0_pct = 0)
    for (t in 1:n) d$add_one_subject_to_experiment_and_assign(X[t, , drop = FALSE]); d }
  a = fill(NULL)
  cat("n = NULL: pairs", max(a$get_block_ids()), "\n")
  for (nn in c(60, 61, 200, 1e5)) cat("n =", nn, "same pairs as n = NULL:",
      identical(a$get_block_ids(), fill(nn)$get_block_ids()), "\n")
  # all FALSE; the help gives no formula for the cutoff when n is NULL
  ```
- Workaround used, if any: none. For a protocol that must state the rule, set `n`.

### F3: `?DesignSeqOneByOnePocockSimon` documents an i.i.d. nonparametric bootstrap via `draw_bootstrap_indices()`, but the bootstrap is refused for this design and the method is not available on the object
- Kind: false docs
- Expected (and where the docs say so: help topic or vignette + section): `?DesignSeqOneByOnePocockSimon`, Description, "*Non-resampling bootstrap.*": "`draw_bootstrap_indices()` always performs a plain i.i.d. nonparametric bootstrap over subjects ...". From that I expected `compute_bootstrap_confidence_interval()` to work on a Pocock-Simon design. The article "Matching on the Fly" says instead that "EDI does not offer the nonparametric bootstrap on sequential designs".
- Observed: `InferenceContinOLS$new(d)$compute_bootstrap_confidence_interval(B = 100)` and `compute_bootstrap_two_sided_pval(B = 100)` both fail with `This method is not supported for DesignSeqOneByOne designs.`; `"draw_bootstrap_indices" %in% names(d)` is `FALSE` (calling it gives `attempt to apply non-function`). The help page describes a feature that the design does not offer.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  set.seed(1); n = 20
  Xc = data.frame(sex = factor(sample(c("F", "M"), n, TRUE)), age_z = rnorm(n))
  d = DesignSeqOneByOnePocockSimon$new(strata_cols = "sex", response_type = "continuous", n = NULL, seed = 2)
  for (t in 1:n) { d$add_one_subject_to_experiment_and_assign(Xc[t, , drop = FALSE]); d$add_one_subject_response(t, rnorm(1)) }
  "draw_bootstrap_indices" %in% names(d)          # FALSE
  tryCatch(InferenceContinOLS$new(d)$compute_bootstrap_confidence_interval(B = 100, show_progress = FALSE),
           error = function(e) conditionMessage(e))  # "This method is not supported for DesignSeqOneByOne designs."
  ```
- Workaround used, if any: asymptotic and randomization inference only.

