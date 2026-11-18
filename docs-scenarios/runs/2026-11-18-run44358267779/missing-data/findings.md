# Findings: missing-data (EDI 1.0.4 as installed)

### F1: A `model_formula` naming a covariate that was entirely `NA` (silently removed under `"impute"`) gives an `NA` estimate and `c(NA, NA)` CI, with only an unrelated `cbind` recycling warning
- Kind: silent NA
- Expected (and where the docs say so: help topic or vignette + section): `?InferenceContinOLS` `$new()` `model_formula`: "a new design matrix is constructed from the design's imputed covariates". When a formula names a covariate that is not in that matrix, EDI already stops with "model_formula contains variables not present in the available covariates: ...". It does this for an unknown name and for a column removed by `drop_column`. I expected the same error here, or an error/warning at enrollment that the all-`NA` column cannot be imputed. `?Design` `missingness_method` `"impute"` says it "preserves all covariates and all subjects".
- Observed: the all-`NA` column `x3` is dropped from `get_X()` with no message, even with `verbose = TRUE`. Then:
  ```
  WARNING: number of rows of result is not a multiple of vector length (arg 1)
  InferenceContinOLS estimate: NA  nonestimable: FALSE  reason: NULL
  [1] NA NA
  WARNING: number of rows of result is not a multiple of vector length (arg 1)
  InferenceContinLin estimate: NA  nonestimable: TRUE  reason: linear_model_design_unusable
  [1] NA NA
  ```
  For OLS, `is_nonestimable()` is `FALSE` even though the estimate is `NA`. The warning is an internal `cbind` message (`In cbind(`(Intercept)` = 1, treatment = private$w, Xc)`) that does not say which column is missing.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  suppressPackageStartupMessages(library(EDI))
  set.seed(1); n = 40
  X = data.frame(x1 = rnorm(n), x2 = rnorm(n), x3 = NA_real_)   # x3 never recorded for any subject
  X$x1[c(2, 5)] = NA
  des = DesignFixediBCRD$new(n = n, response_type = "continuous", missingness_method = "impute", verbose = TRUE)
  des$add_all_subjects_to_experiment(X); des$assign_w_to_all_subjects(w_precomputed = rep(0:1, n/2))
  des$add_all_subject_responses(1 + rep(0:1, n/2) + rnorm(n))
  colnames(des$get_X())    # x3 is gone, no message
  for (cls in c("InferenceContinOLS", "InferenceContinLin")) {
    inf = get(cls)$new(des, model_formula = ~ x1 + x3)
    est = withCallingHandlers(inf$compute_estimate(),
            warning = function(w) { cat("WARNING:", conditionMessage(w), "\n"); invokeRestart("muffleWarning") })
    cat(cls, "estimate:", est, " nonestimable:", inf$is_nonestimable(), " reason:", format(inf$get_nonestimable_reason()), "\n")
    print(tryCatch(inf$compute_asymp_confidence_interval(), error = function(e) paste("ERROR:", conditionMessage(e))))
  }
  ```
- Workaround used, if any: remove all-`NA` columns before enrolling. Compare: with `missingness_method = "drop_column"` and `model_formula = ~ x1 + x2` (x2 dropped), `$new()` stops correctly with "model_formula contains variables not present in the available covariates: x2."

### F2: With `missingness_method = "error"`, covariate-adaptive sequential designs assign the first subjects despite their `NA` covariates, then fail on a later subject whose own data are complete
- Kind: false docs
- Expected (and where the docs say so: help topic or vignette + section): `?Design`, `$new()`, `missingness_method`, `"error"`: "An error is thrown as soon as any missing value is detected in the covariate matrix. Use this when you want to guarantee that inference runs on exactly the data you supplied". I expected an error on the call that enrolls the subject with the `NA` (t = 1).
- Observed (`DesignSeqOneByOneAtkinson`, p = 2): subjects 1 to 4 are assigned with no error, although subject 1 has `x2 = NA`. The call for subject 5 (complete data) fails:
  `Missing values detected in covariate(s): x2. Set missingness_method = "impute" or "drop_column" to handle missing data automatically.`
  The error fires at t = 6 for KK14 and Atkinson with 3 covariates (NA at subject 1 or 2), and at the exact subject when the NA arrives later (t = 10, 60). The message does not name the subject that has the missing value. After it fires, the trial cannot enroll anyone else.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  set.seed(1); n = 20
  X = data.frame(x1 = rnorm(n), x2 = rnorm(n)); X$x2[1] = NA     # the FIRST subject has a missing covariate
  des = DesignSeqOneByOneAtkinson$new(n = n, response_type = "continuous", missingness_method = "error")
  for (t in 1:n) {
    r = tryCatch(des$add_one_subject_to_experiment_and_assign(X[t, , drop = FALSE]),
                 error = function(e) { cat("t =", t, "ERROR:", conditionMessage(e), "\n"); NULL })
    if (is.null(r)) break
    cat("t =", t, "assigned w =", r, "\n")
  }
  ```
- Workaround used, if any: none. Check `anyNA(x_new)` yourself before each call.

### F3: A failed `add_one_subject_to_experiment_and_assign()` (the `"error"` refusal) still enrolls the subject: `get_t()` goes up and `w` is left `NA`
- Kind: silent change of your input
- Expected (and where the docs say so: help topic or vignette + section): `?DesignSeqOneByOne` `add_one_subject_to_experiment_and_assign()`: "Adds a subject and assigns treatment". When it errors, I expected the design to be unchanged, so the call can be retried after the problem is fixed.
- Observed: after two refused calls, `get_t()` is 6 and `get_w()[1:6]` is `0 1 0 0 NA NA`. Each retry adds another unassigned subject.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  suppressPackageStartupMessages(library(EDI))
  set.seed(1); n = 20
  X = data.frame(x1 = rnorm(n), x2 = rnorm(n)); X$x2[1] = NA
  des = DesignSeqOneByOneAtkinson$new(n = n, response_type = "continuous", missingness_method = "error")
  for (t in 1:4) des$add_one_subject_to_experiment_and_assign(X[t, , drop = FALSE])
  for (t in 5:6) print(tryCatch(des$add_one_subject_to_experiment_and_assign(X[t, , drop = FALSE]),
                                error = function(e) conditionMessage(e)))
  des$get_t()          # 6: both failed calls enrolled a subject
  des$get_w()[1:6]     # subjects 5 and 6 have w = NA
  ```
- Workaround used, if any: none.

### F4: An `Inf` covariate is accepted at enrollment; inference then fails with an internal `qr.default` error
- Kind: useless message
- Expected (and where the docs say so: help topic or vignette + section): responses are checked for finiteness (`add_all_subject_responses()` with `Inf` gives "Assertion on 'y' failed: Must be finite."). Covariates are not checked. I expected enrollment to refuse `Inf`, or the missingness handling to treat it, with a message naming the column.
- Observed: `add_all_subjects_to_experiment()` accepts it silently, and `get_X()[3, ]` shows `Inf`. Then `compute_estimate()` fails with:
  `Error in qr.default(X_mat) : NA/NaN/Inf in foreign function call (arg 1)`
  (`NaN` in a covariate is treated as missing and imputed, which is reasonable.)
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  set.seed(1); n = 40
  X = data.frame(x1 = rnorm(n), x2 = rnorm(n)); X$x2[3] = Inf
  des = DesignFixediBCRD$new(n = n, response_type = "continuous")
  des$add_all_subjects_to_experiment(X)          # accepted, no warning
  des$assign_w_to_all_subjects(w_precomputed = rep(0:1, n/2))
  des$add_all_subject_responses(rnorm(n))
  print(des$get_X()[3, ])
  inf = InferenceContinOLS$new(des)
  inf$compute_estimate()
  ```
- Workaround used, if any: recode non-finite covariate values to `NA` before enrolling.

### F5: When `"drop_column"` removes every covariate, covariate-balancing designs (rerandomization, KK14, greedy, Atkinson) silently run without any covariates
- Kind: silent change of your input
- Expected (and where the docs say so: help topic or vignette + section): the article "Missing Covariate Values and Imputation", "Practical points", says designs that use covariates to assign "read the same model matrix, so the same `missingness_method` applies there". When that matrix ends up with 0 columns, the design no longer balances anything: `prop_acceptable` and KK matching become meaningless. I expected a warning, or at least a `verbose = TRUE` message, that the design has no covariates left.
- Observed: `dim(des$get_X())` is `40 0` and assignment goes ahead with no warning, even with `verbose = TRUE`. In my 60-farm trial, `DesignFixedRerandomization(prop_acceptable = 0.01)` under `drop_column` reached Mahalanobis imbalance 0.092 on the true covariates, against 0.019 under `impute` and 0.004 on complete data.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  set.seed(1); n = 40
  X = data.frame(x1 = rnorm(n), x2 = rnorm(n)); X$x1[c(2, 9)] = NA; X$x2[c(4, 20)] = NA
  des = DesignFixedRerandomization$new(n = n, response_type = "continuous", prop_acceptable = 0.01,
                                       missingness_method = "drop_column", verbose = TRUE, seed = 1)
  des$add_all_subjects_to_experiment(X)
  des$assign_w_to_all_subjects()       # no warning or message
  dim(des$get_X())                     # 40 x 0: the design balanced on nothing
  des2 = DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", missingness_method = "drop_column", verbose = TRUE)
  for (t in 1:n) des2$add_one_subject_to_experiment_and_assign(X[t, , drop = FALSE])
  dim(des2$get_X())
  ```
- Workaround used, if any: use `"impute"` for designs that assign on covariates.

### F6: The docs say "EDI 1.0.4 and earlier" gave the outcome to the imputation model, but the installed package is version 1.0.4 and does not
- Kind: inconsistency
- Expected (and where the docs say so: help topic or vignette + section): the article "Missing Covariate Values and Imputation", section "What impute uses", says: "(EDI 1.0.4 and earlier also gave the imputation model the outcome, and did not seed it ...)". The simulation section says the same ("what EDI 1.0.4 and earlier did by default"). The NEWS entry is under "EDI (development version)".
- Observed: `packageVersion("EDI")` is `1.0.4` and the startup banner says "Welcome to EDI v1.0.4". This build already has the fix: imputed values are identical for very different `y`. A user who checks their version against the article will conclude, wrongly, that their imputations are biased toward zero (or, with a real 1.0.4 install, cannot tell which behavior they have).
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  suppressPackageStartupMessages(library(EDI))
  packageVersion("EDI")      # 1.0.4
  set.seed(1); n = 40
  X = data.frame(age = round(rnorm(n, 50, 10)), bmi = round(rnorm(n, 28, 4), 1)); X$bmi[c(3, 8, 15)] = NA
  mk = function(y) { d = DesignFixediBCRD$new(n = n, response_type = "continuous", seed = 1)
    d$add_all_subjects_to_experiment(X); d$assign_w_to_all_subjects(w_precomputed = rep(0:1, n/2))
    d$add_all_subject_responses(y); d$get_X_imp() }
  identical(mk(rnorm(n)), mk(rnorm(n, 100, 50)))   # TRUE: this "1.0.4" does NOT use the outcome
  ```
- Workaround used, if any: checked the behavior directly, as above.

### F7: In sequential designs, `get_X_raw()` and `get_X()` reorder the covariate columns when the first subject has missing values
- Kind: silent change of your input
- Expected (and where the docs say so: help topic or vignette + section): `?Design` `get_X_raw()`: "A data frame of subject data", meaning the covariates as supplied, in the same column order. Fixed designs keep the input order.
- Observed: input columns `a b c`; after the first subject arrives with `a` and `c` missing, `names(des$get_X_raw())` is `"b" "a" "c"` and `colnames(des$get_X())` starts `"b" "a" "c"`. Values stay aligned by name, which I checked. Code that indexes columns by position, such as `get_X()[, 1]` or `get_covariates()` in an extension class, gets the wrong covariate.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  suppressPackageStartupMessages(library(EDI))
  set.seed(1); n = 20
  X = data.frame(a = rnorm(n), b = rnorm(n), c = rnorm(n)); X[1, c("a", "c")] = NA
  des = DesignSeqOneByOneAtkinson$new(n = n, response_type = "continuous")
  for (t in 1:n) des$add_one_subject_to_experiment_and_assign(X[t, , drop = FALSE])
  names(X)                       # a b c
  names(des$get_X_raw())         # b a c
  colnames(des$get_X())          # b a c ...
  ```
- Workaround used, if any: index columns by name.

### F8: `get_summary()` on `InferenceContinOLS` prints only the treatment row, though the docs promise the full coefficient table for model-based classes
- Kind: false docs
- Expected (and where the docs say so: help topic or vignette + section): `?Inference` `get_summary()`: "model-based classes show the full coefficient table when coefficient names and a covariance matrix are available, otherwise ... a one-row treatment summary." OLS is model-based with a closed-form covariance. With missing covariates, the full table is how a user would see what the imputed covariates and the `*_is_missing` indicators contribute.
- Observed (complete data, no missing values at all):
  ```
              Estimate Std. Error    t value  Pr(>|t|)
  treatment -0.05351646  0.2652229 -0.2017792 0.8412253
  ```
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  suppressPackageStartupMessages(library(EDI))
  set.seed(1); n = 40
  X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
  des = DesignFixediBCRD$new(n = n, response_type = "continuous")
  des$add_all_subjects_to_experiment(X); des$assign_w_to_all_subjects(w_precomputed = rep(0:1, n/2))
  des$add_all_subject_responses(1 + X$x1 + rnorm(n))
  inf = InferenceContinOLS$new(des); inf$compute_estimate()
  inf$get_summary()   # only the 'treatment' row; no intercept / x1 / x2 rows
  ```
- Workaround used, if any: refit with `lm()` on `get_X_imp()` to see the covariate coefficients.
