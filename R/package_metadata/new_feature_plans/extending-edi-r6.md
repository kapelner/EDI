# Extending EDI with Custom R6 Inference Classes

EDI is implemented with R6 classes. Advanced users can define their own R6
classes outside the package and reuse EDI's design storage, response handling,
randomization, bootstrap, and summary methods.

The custom-extension base classes are intentionally internal while the extension
contract is experimental. Retrieve them with `getFromNamespace()`:

```r
library(EDI)
library(R6)

InferenceCustomAsymp <- getFromNamespace("InferenceCustomAsymp", "EDI")
InferenceCustomRand <- getFromNamespace("InferenceCustomRand", "EDI")
InferenceCustomBoot <- getFromNamespace("InferenceCustomBoot", "EDI")
```

## Inference Contract

A custom asymptotic inference class should inherit from `InferenceCustomAsymp`
and implement a public `fit(estimate_only = FALSE)` method. `fit()` returns a
named list with:

- `estimate`: required numeric scalar treatment-effect estimate.
- `se`: optional numeric scalar standard error.
- `df`: optional degrees of freedom. Use `NA_real_` for z inference.
- `model`: optional fitted model object retained by `get_mod()`.
- `nonestimable_reason`: optional character scalar used when the estimate or
  standard error is unavailable.

Use public accessors instead of private fields:

- `get_response()`
- `get_treatment()`
- `get_covariates()`
- `get_analysis_data()`
- `get_design_object()`
- `get_response_type()`

### Randomization Inference

Custom randomization-inference classes should inherit from
`InferenceCustomRand`. This base class inherits from `Inference`, includes the
`RandomizationTest` component, and has `likelihood_tier = "none"`.

Subclasses implement `fit(estimate_only = FALSE)` and return a named list with
the same required `estimate` field used by `InferenceCustomAsymp`. Standard
errors and degrees of freedom are not part of this minimal contract; the class
only promises `fit()`/`compute_estimate()` behavior plus the randomization-test
machinery supplied by EDI.

### Bootstrap Inference

Custom bootstrap-inference classes should inherit from `InferenceCustomBoot`.
This base class inherits from `InferenceJackknife`, so subclasses reuse EDI's
jackknife and bootstrap machinery while supplying only the estimator.

Subclasses implement `fit(estimate_only = FALSE)` and return a named list with
the required numeric scalar `estimate`. Optional `model` and
`nonestimable_reason` fields are supported, but no standard error or degrees of
freedom is required for the minimal bootstrap extension contract.

## Example

```r
InferenceMedianDiff <- R6Class(
  "InferenceMedianDiff",
  inherit = InferenceCustomAsymp,
  public = list(
    fit = function(estimate_only = FALSE) {
      dat <- self$get_analysis_data()
      y_t <- dat$y[dat$w == 1]
      y_c <- dat$y[dat$w == 0]

      est <- stats::median(y_t) - stats::median(y_c)
      if (estimate_only) {
        return(list(estimate = est))
      }

      list(
        estimate = est,
        se = sqrt(stats::var(y_t) / length(y_t) + stats::var(y_c) / length(y_c)),
        df = length(y_t) + length(y_c) - 2,
        model = NULL
      )
    }
  )
)

des <- DesignFixedBernoulli$new(n = 20, response_type = "continuous")
des$add_all_subjects_to_experiment(data.frame(x = seq_len(20)))
des$overwrite_all_subject_assignments(rep(c(0, 1), each = 10))
des$add_all_subject_responses(rnorm(20))

inf <- InferenceMedianDiff$new(des)
inf$compute_estimate()
inf$compute_asymp_two_sided_pval()
inf$compute_asymp_confidence_interval()
inf$compute_bootstrap_two_sided_pval(B = 501)
```

## Custom Designs

EDI also provides internal bases for user-defined designs:

```r
DesignFixedCustom <- getFromNamespace("DesignFixedCustom", "EDI")
DesignCustomSequential <- getFromNamespace("DesignCustomSequential", "EDI")
```

For fixed designs, implement `draw_assignments(r)` and return an `n x r` 0/1
assignment matrix. For sequential designs, implement `assignment_rule()` and
return a scalar 0/1 assignment for the current subject. EDI handles subject
storage, response recording, and validation.

## Custom Shell Audit

The current custom shell set is sufficient for the documented extension
contract:

- `DesignFixedCustom` covers fixed-sample assignment generators.
- `DesignCustomSequential` covers one-subject-at-a-time assignment rules.
- `InferenceCustomAsymp` covers custom estimators that provide Wald-style
  standard errors and optional degrees of freedom.
- `InferenceCustomRand` covers custom estimators that should reuse EDI's
  randomization-test machinery.
- `InferenceCustomBoot` covers custom estimators that should reuse EDI's
  jackknife/bootstrap machinery without requiring an asymptotic standard error.

Do not add response-family-specific custom inference shells unless a concrete
extension use case needs response-specific behavior beyond the generic analysis
data accessors. Most response/model R6 classes in `EDI/R` are concrete
implementations, not separate user extension surfaces.

No `InferenceCustomExact` or parametric-bootstrap custom shell is needed for
this contract. `InferenceExact` dispatches exact p-value and interval methods
through private exact-test implementations, and `InferenceParamBootstrap`
requires likelihood-null simulation/refit hooks. Those are not simple
`fit()`/`compute_estimate()` shells, so exposing them would need a separate API
design rather than another thin custom R6 wrapper.
