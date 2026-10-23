# DRAFT upstream bug report: `ordinal::clmm()` fits log-log for `link = "cloglog"` and cloglog for `link = "loglog"`

> **Status:** DRAFT, written 2026-10-22 for v1.0.5 TODO-31 (plan `clmm_sigma_collapse_false_convergence.md`,
> TODO-6 item 4; owner decision G6 #45 (i)). **Not posted.** The owner reviews it and sends it to the ordinal
> maintainer (Rune Haubo B. Christensen; package `ordinal` on CRAN, issue tracker at
> https://github.com/runehaubo/ordinal/issues). Reproducer verified locally with ordinal 2026.7.26 on R-devel r90668
> (script copy: `/tmp/claude-1000/todo31_impl/upstream_repro.R`). Everything below the line is the proposed text.

---

**Title:** `clmm()`: `link = "cloglog"` fits the log-log model and `link = "loglog"` fits the complementary log-log model

**Package version:** ordinal 2026.7.26 (R-devel 2026-10-13 r90668, x86_64-pc-linux-gnu). We have not checked
older versions.

### Summary

When `clmm()` is asked for `link = "cloglog"`, the likelihood it maximizes and reports is the **log-log** model's.
When it is asked for `link = "loglog"`, it uses the **complementary log-log** model. `clm()` is not affected. The
two links are mirror images (F_loglog(z) = 1 - F_cloglog(-z)), so the fits look plausible and nothing errors.
Users get the other model's estimates without any warning.

### Minimal reproducible example

We simulate from a true complementary log-log random-intercept model, P(Y <= k | b) = 1 - exp(-exp(theta_k - 0.6 w - b)),
with b ~ N(0, 1.2^2) and 400 groups of 2. Then we fit both link names and compare `-logLik()` with the marginal
likelihood computed independently by `integrate()`:

```r
library(ordinal)
set.seed(1)
G <- 400; n <- 2 * G; g <- rep(1:G, each = 2)
w <- rbinom(n, 1, 0.5); b <- rnorm(G, 0, 1.2)[g]
eta <- 0.6 * w + b; theta <- c(-1, 0, 1)
F_cloglog <- function(z) 1 - exp(-exp(z))
F_loglog  <- function(z) exp(-exp(-z))
y <- 1 + rowSums(runif(n) > sapply(theta, function(t) F_cloglog(t - eta)))
d <- data.frame(y = factor(y, ordered = TRUE), w = w, g = factor(g))

fit_c <- clmm(y ~ w + (1 | g), data = d, link = "cloglog", nAGQ = 10)
fit_l <- clmm(y ~ w + (1 | g), data = d, link = "loglog",  nAGQ = 10)

# Marginal -log-likelihood by numerical integration, for a given link CDF F
marg_nll <- function(fit, F) {
  cf <- coef(fit); th <- cf[1:3]; beta <- cf["w"]; s <- fit$ST[[1]][1]
  up <- c(th, Inf)[y]; lo <- c(-Inf, th)[y]; et <- beta * w
  -sum(sapply(1:G, function(gg) { i <- which(g == gg)
    log(integrate(function(bb) sapply(bb, function(b1)
      prod(F(up[i] - et[i] - b1) - F(lo[i] - et[i] - b1))) * dnorm(bb, 0, s),
      -10 * s, 10 * s, rel.tol = 1e-10)$value) }))
}
rbind(cloglog = c(w = coef(fit_c)[["w"]], sigma = fit_c$ST[[1]][1], minus_logLik = -c(logLik(fit_c)),
                  integrated_cloglog = marg_nll(fit_c, F_cloglog), integrated_loglog = marg_nll(fit_c, F_loglog)),
      loglog  = c(w = coef(fit_l)[["w"]], sigma = fit_l$ST[[1]][1], minus_logLik = -c(logLik(fit_l)),
                  integrated_cloglog = marg_nll(fit_l, F_cloglog), integrated_loglog = marg_nll(fit_l, F_loglog)))
```

Output:

| `clmm(link = ...)` | w | sigma | -logLik | integrated NLL, cloglog F | integrated NLL, log-log F |
|---|---|---|---|---|---|
| `"cloglog"` | 0.6527 | 1.3133 | 1031.907 | 1109.878 | **1031.911** |
| `"loglog"` | 0.5942 | 1.2218 | 1029.482 | **1029.484** | 1110.950 |

- The `-logLik()` that `clmm(link = "cloglog")` reports equals the integrated **log-log** likelihood at its
  estimates (1031.907 vs 1031.911). It does not equal the cloglog likelihood (1109.878).
- `clmm(link = "loglog")` reports the integrated **cloglog** likelihood (1029.482 vs 1029.484). It also recovers the
  true cloglog parameters (w 0.594 vs 0.6, sigma 1.22 vs 1.2).
- The remaining differences of about 4e-3 come from 10-point quadrature versus `integrate()`.
- Laplace (`nAGQ = 1`) shows the same swap.
- On a second, unrelated dataset, `clmm(link = "loglog")` with the random-effect variance going to 0 reproduces
  `clm(link = "cloglog")` exactly (-logLik 80.89729 for both). So `clm()` uses the documented convention and
  `clmm()` does not.

### Where it seems to come from

The R-level link functions that `clmm` sets up (`ordinal:::setLinks`) map the names as documented. The swap
appears in the compiled likelihood path. One low-level symptom:

```r
ordinal:::getFittedC(c(0.5, 1, -0.3), c(-Inf, 0, -2), "cloglog")
#> [1] -0.1922956  0.3018914  0.3966993
F_cloglog(c(0.5, 1, -0.3)) - F_cloglog(c(-Inf, 0, -2))
#> [1]  0.8077044  0.3018914  0.3966993
```

The first element is F(0.5) - 1 instead of F(0.5) - 0, so the infinite lower bound is not handled correctly for
`"cloglog"`. The same call with `"loglog"` matches the log-log CDF. We have not inspected the C source, so we
cannot say whether this is the same defect or a separate one.

### Impact

Any `clmm(link = "cloglog")` or `clmm(link = "loglog")` fit reports the other model's coefficients, variance
component and likelihood. Comparisons between these two links using `clmm()` are reversed.

### Workaround we use

We fit both names once on a fixed dataset and keep the one whose `-logLik()` matches an `integrate()` evaluation
of the cloglog likelihood. A fixed mapping would break silently once this is fixed.

Thank you for maintaining ordinal.
