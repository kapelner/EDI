# Settled decisions

Findings the owner rejected, and conventions. The audit agents read this file and must not raise a finding that matches one below. The owner may edit it by hand.

- `R/EDI/R/design_fixed_greedy_d_optimal.R`: #'     refuses these; this class runs them. The identity above holds for any fixed -> #'     also accepts these (any prob_T in (0, 1)); the identity above holds for any fixed (rejected in PR #31; id 56a7cf7311b4)
- `R/EDI/R/design_seq_one_by_one_KK14.R`: #' all prior subjects' covariates, ridge-regularized by \code{.Machine$double.eps}) to -> #' all prior subjects' covariates, ridge-regularized by \code{sqrt(.Machine$double.eps)} times the mean covariate variance) to (rejected in PR #31; id 627088e196e7)
- `R/EDI/src/fast_cpoisson_combined.cpp`: //' skipped entirely, returning only \code{b}, \code{params}, and -> //' skipped entirely, returning \code{b}, \code{params}, the iteration diagnostics, and (rejected in PR #68; id cfd893a554bd)
