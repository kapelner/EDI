# Negative-Binomial Poisson-Boundary Convergence Acceptance

## Status

Implemented as a conservative interim mitigation on 2026-08-27. The eventual
fix is the Option 1 reparameterization project in
`../new_feature_plans/negbin_dispersion_convergence.md`, catalogued for
v1.1.0. This document preserves the completed Option 2 work; it is not the
long-term convergence design.

## What was implemented

The three negative-binomial-family kernels share a post-fit boundary check
through `src/_negbin_boundary_convergence.h`, without changing the generic
optimizer. A failed joint fit is reclassified as usable for the other
coefficients only when all of the following hold:

1. dispersion is free and `log_theta >= log(1e4)`;
2. the norm of the free non-dispersion gradient is at most
   `max(10 * tol, 1e-6)`;
3. the dispersion gradient is negative, so increasing `theta` still improves
   the negative log likelihood; and
4. a probe at `log_theta + log(2)` is finite, does not worsen the objective,
   and retains a non-positive dispersion gradient.

Accepted fits set `dispersion_at_poisson_boundary = TRUE`. Coefficient
covariance is computed conditional on the Poisson boundary by excluding the
dispersion coordinate; the dispersion row and column of a full covariance
result are `NA`. The R score-test callers preserve the matrix shape while
removing the singular nuisance direction.

## Scope and limitation

This mitigation makes treatment-coefficient inference available when the only
failure is a nuisance dispersion parameter approaching the Poisson limit. It
does not make the dispersion estimate an ordinary interior estimate, does not
alter the generic optimizer convergence contract, and must not be interpreted
as evidence that all failed fits are safe.

The implementation remains intentionally conservative. Regression coverage
must include genuinely non-overdispersed data, interior overdispersed data,
fixed dispersion parameters, singular/non-finite fits, and all three affected
kernel families. The finished mitigation stays in place until the selected
Option 1 reparameterization has equivalent or better fit, covariance, and
inference behavior.
