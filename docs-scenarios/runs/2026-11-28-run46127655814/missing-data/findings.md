### F1: With `missingness_method = "error"`, `DesignFixedBlocking` (and `DesignSeqOneByOnePocockSimon`) randomize on a stratum column with `NA` without any error, making the missing values a block of their own
- Kind: false docs
- Expected (and where the docs say so: help topic or vignette + section): `?Design`, `$new()` argument `missingness_method`, `"error"`: "An error is thrown as soon as any missing value is detected in the covariate matrix. Use this when you want to guarantee that inference runs on exactly the data you supplied, with no silent modification." Article "Missing Covariate Values and Imputation", "Practical points": designs that use the covariates to assign treatment read the same model matrix, "so the same `missingness_method` applies there". The fixed covariate designs do this: `DesignFixedGreedyDOptimal`, `DesignFixedOptimal`, `DesignFixedMatchingGreedyPairSwitching` and `DesignFixedBinaryMatch` all stop at `assign_w_to_all_subjects()` under `"error"`. `?DesignFixedBlocking` does not say what happens to an `NA` in a `strata_cols` column.
- Observed: `DesignFixedBlocking(strata_cols = "region", missingness_method = "error")` assigns all subjects with no error, warning or message. The 4 subjects with `region = NA` become their own block 2 (table below). The refusal comes only later, from `get_X()` or the inference constructor. The same happens with `"impute"` and `"drop_column"`: the blocks are built from the raw column, not from the imputed or dropped model matrix. Under `"drop_column"` the region column is dropped from the model but still used for blocking. `DesignSeqOneByOnePocockSimon` with `missingness_method = "error"` also assigns all 60 farms. Its assignments are identical to those under `"impute"` and `"drop_column"`; its help page does document "missing values are treated as their own level", but not that `"error"` is ignored. By contrast, the GreedyDOptimal design in the same script errors as the docs say.
  ```
        block
  region  1  2  3  4
    a    15  0  0  0
    b     0  0 12  0
    c     0  0  0  9
    <NA>  0  4  0  0
  [1] "Missing values detected in covariate(s): region. Set missingness_method = \"impute\" or \"drop_column\" to handle missing data automatically."
  ```
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  set.seed(1)
  n = 40
  X = data.frame(region = factor(sample(c("a","b","c"), n, TRUE)), x = rnorm(n))
  X$region[c(2, 9, 17, 30)] = NA
  des = DesignFixedBlocking$new(strata_cols = "region", response_type = "continuous", n = n,
                                equal_block_sizes = FALSE, missingness_method = "error", seed = 1)
  des$add_all_subjects_to_experiment(X)
  des$assign_w_to_all_subjects()          # no error
  print(table(region = X$region, block = des$get_block_ids(), useNA = "ifany"))
  des2 = DesignFixedGreedyDOptimal$new(response_type = "continuous", n = n, missingness_method = "error", seed = 1)
  des2$add_all_subjects_to_experiment(X)
  tryCatch(des2$assign_w_to_all_subjects(), error = function(e) conditionMessage(e))   # refuses
  ```
- Workaround used, if any: none needed for the analysis. I kept the NA-region block as a deliberate "region unknown" stratum. For a strict refusal, check `anyNA(X[strata_cols])` yourself before assigning.

### F2: `missingness_method = "error"` refuses a covariate that `design_formula` leaves out of the model, although `"impute"` and `"drop_column"` give the same complete-data fit
- Kind: inconsistency
- Expected (and where the docs say so: help topic or vignette + section): `?Design`, `$new()` argument `missingness_method`: "`"error"`: An error is thrown as soon as any missing value is detected in the covariate matrix", and the `missingness_method` description reads "How to handle missing values in covariates when building the model matrix for inference". The article "Missing Covariate Values and Imputation" (table "The three options") says "Inference stops with an error naming the incomplete columns". With `design_formula = ~ x1 + x2`, the model matrix contains no missing value, so `"error"` should let inference run, exactly as it would on complete data.
- Observed: `"impute"` and `"drop_column"` both give `1.172017`, which equals `lm(y ~ w + x1 + x2)`, so nothing in the model was imputed or dropped. `"error"` stops instead, naming a column the formula does not use:
  ```
  [1] 1.172017
  [1] 1.172017
  [1] "Missing values detected in covariate(s): notes. Set missingness_method = \"impute\" or \"drop_column\" to handle missing data automatically."
         w
  1.172017
  ```
  The same happens on the farm data: with `design_formula = ~ soil_ph + herd` and `NA` only in `region`, `"error"` refuses with "Missing values detected in covariate(s): region."
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  set.seed(1)
  n = 40
  X = data.frame(x1 = rnorm(n), x2 = rnorm(n), notes = rnorm(n))
  X$notes[c(3, 11, 25)] = NA                  # incomplete column the formula does not use
  w = rep(0:1, n / 2); y = 1 + w + X$x1 + rnorm(n)
  fit = function(method) {
    des = DesignFixediBCRD$new(n = n, response_type = "continuous", design_formula = ~ x1 + x2,
                               missingness_method = method, seed = 1)
    des$add_all_subjects_to_experiment(X)
    des$assign_w_to_all_subjects(w_precomputed = w)
    des$add_all_subject_responses(y)
    tryCatch(InferenceContinOLS$new(des)$compute_estimate(), error = function(e) conditionMessage(e))
  }
  fit("impute"); fit("drop_column")   # identical: nothing in the model was imputed or dropped
  fit("error")                         # refuses, naming a column that is not in the model
  coef(lm(y ~ w + x1 + x2, data = X))["w"]
  ```
- Workaround used, if any: pass only the columns you model, `X[, c("x1", "x2")]`, to `add_all_subjects_to_experiment()`.

