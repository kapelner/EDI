# Risk-ratio subsampling / m-out-of-n p-values that almost never reject (2026-11-19)

Manual investigation of v1.0.6-TODO-191 (owner request 2026-11-19), not output of the monthly research job. Literature
claims are cited to the primary sources listed at the end; the theorem conditions quoted below were read from the
papers' full text (Politis, Romano and Wolf 2001; Bickel and Sakov 2008). Simulation numbers are measurements with
EDI's own classes (loaded with `pkgload::load_all(compile = FALSE)`, no package code changed) plus a glm/Firth replica
of the g-computation estimator that matches `InferenceIncidGCompRiskRatio$compute_estimate()` to 2e-8 on all 200
datasets.

Scripts and results: `/tmp/claude-1000/t191_rr/` (`sim.R`: EDI draws; `sim2.R`: replica variants; `q2.R`: repro
quantification; `res_*.rds`, `res2_*.rds`: per-dataset p-values). Repro dataset: `/tmp/claude-1000/t179/dbg.R`
(seed 1005).

## 1. What happens

Setup (as in the v1.0.6-TODO-179 study): n = 80, `DesignFixedBernoulli`, x1, x2 ~ N(0, 1), y ~ Bernoulli(plogis(-0.4 +
0.5 x1)), no treatment effect (event rate ~0.41). `compute_rr_resampling_pivot()` (`R/helper_gcomp.R`) draws B = 199
subsamples of size b = floor(n^0.7) = 21 (m = 21 with replacement for m-out-of-n), forms
`sqrt(b) * (log RR* - log RR_hat)`, and `resampling_centered_pval()` returns
`2 * min(mean(piv <= t_obs), mean(piv >= t_obs))` with `t_obs = sqrt(n) * (log RR_hat - log delta)`.

In a subsample of 21 (about 10 per arm, about 4 events per arm) one arm has no events, or the logistic fit is
(quasi-)separated, with non-negligible probability. The marginal risk of that arm is then numerically 0, so
log RR* is about +/-20 (the IRLS stops at a finite but huge coefficient) and the pivot is about +/-90. These draws are
not dropped: `finite = draws[is.finite(draws) & draws > 0]` keeps them because they are finite.

Three facts turn this into a test that never rejects:

1. **The atoms sit in the tail the test uses.** A dataset whose log RR_hat is far from 0 has few events in one arm;
   its subsamples are exactly the ones that lose all events in that arm, so the atom lands on the same side as
   `t_obs`. Over the 200 null datasets, 79 % (subsampling) and 76 % (m-out-of-n) of the degenerate draws were on the
   side of `t_obs`.
2. **The atoms put a floor under the p-value.** If a fraction `a` of the B draws are atoms on the side of `t_obs`,
   then `mean(piv >= t_obs) >= a` whatever `t_obs` is, so `p >= 2a`. In the 11 null datasets with Wald p < 0.05 the
   floor `2a` was 0.01-0.32 for subsampling (median 0.09) and 0.00-0.37 for m-out-of-n (median 0.10); the observed
   p-values sat just above it (table in section 4).
3. **Away from the tails nothing is wrong.** In the v1.0.6-TODO-179 data the subsampling and Wald p-values correlate
   0.975 and have the same median (0.48). Only the lower tail of the p-value distribution is cut off (1 % quantile
   0.06-0.12 instead of 0.01), which is why the size is 0.000-0.005 rather than, say, 0.03. The CIs are wide for the
   same reason (the 2.5 % / 97.5 % quantiles land in the atoms).

The m-out-of-n bootstrap is worse than subsampling because a with-replacement resample of 21 has only ~18 distinct
units, so empty arms and separation are more frequent (degenerate fraction 2.9 % vs 1.6 % on average).

### Quantification (question 2)

Repro dataset (seed 1005): arm 0 has 12/39 events, arm 1 has 15/41. Exact hypergeometric probability that a
size-b subsample (without replacement) has a zero-event arm, and the with-replacement analogue:

| b (or m) | subsampling: zero-event arm | m-out-of-n: zero-event arm |
|---:|---:|---:|
| 10 | 0.285 | 0.322 |
| 15 | 0.098 | 0.132 |
| **21 (default, n = 80)** | **0.025** | **0.046** |
| 25 | 0.009 | 0.023 |
| 30 | 0.002 | 0.010 |
| 40 (= n/2, EDI's cap) | 0.0001 | 0.0018 |
| 80 | ~0 | ~0 |

Monte Carlo on the same data (4,000 subsamples, glm replica): zero/all-event arm 2.2 %, numerical separation of any
kind 2.5 % at b = 21 (6.6 % for m = 21), giving pivot quantiles (2.5 %, 97.5 %) of (-6.2, 7.6) for subsampling and
(-7.3, **82.3**) for m-out-of-n, against a non-degenerate pivot SD of about 2.9. At b = 40 the degenerate fraction is
0 (subsampling) / 0.2 % (m-out-of-n).

Population version (event rate p per arm, balanced arms): P(some arm has no events) ~ 1 - (1 - (1 - p/2)^b)^2.

| event rate p | b = 21 | b = 40 | b needed for P <= 0.005 | expected events per arm at that b |
|---:|---:|---:|---:|---:|
| 0.40 | 0.018 | 0.0003 | 27 | 5.4 |
| 0.20 | 0.21 | 0.029 | 57 | 5.7 |
| 0.10 | 0.57 | 0.24 | 117 | 5.9 |
| 0.05 | 0.83 | 0.59 | 237 | 5.9 |

So b must grow like (2/p) log(2/eps): each arm of a subsample has to expect about 6 events before the atoms become
negligible at the 5 % level. With EDI's cap b <= n/2 this is impossible for p <= 0.2 at n = 80 (and for p = 0.1 it
needs n >= 234). The default b = n^0.7 ignores the event rate entirely. Separation from the covariates adds to this
(4 parameters on 21 rows; see Candes and Sur 2020 for the existence threshold of the logistic MLE).

## 2. Literature verdict (question 1)

**The subsampling theorem.** Politis, Romano and Wolf (2001, Statistica Sinica 11, Theorem 2.1; Theorem 2.2.1 in the
1999 book is the fixed-b version) assume only:

> "Assumption 2.1. There exists a limit law J(P) such that J_n(P) converges weakly to J(P) as n -> infinity."

plus, for the block sizes, `j_n -> infinity`, `k_n/n -> 0`, `tau_{k_n}/tau_n -> 0`, and
`(k_n - j_n + 1) exp(-d n/k_n) -> 0`; conclusions (iii)-(iv) (uniform convergence and correct coverage) also need
`J(., P)` continuous. The test version (Theorem 3.1) assumes "G_n(P) converges weakly to a continuous limit law" under
the null. All of these hold for the g-computation log RR: it is asymptotically normal at rate sqrt(n), the limit is
continuous, and b = n^0.7 satisfies the rate conditions. The estimator does not need finite moments; subsampling was
designed for exactly that kind of statistic, and P(log RR_hat = +/-infinity) -> 0 exponentially in n.

**So no assumption of the theorem is violated; the failure is finite-sample.** PRW's own motivation explains it:
"For any i, Y_i is a random sample of size b from P. Hence, the exact distribution of tau_b(theta_hat_{n,b,i} -
theta(P)) is J_b(P)." Subsampling estimates **J_b**, the sampling distribution at sample size b, and relies on J_b
being close to J_n. The proof splits the error into (a) the U-statistic error `U_{n,b} - J_b` (Hoeffding, fine with
B = 199), (b) `J_b - J`, and (c) the centering error `tau_b (theta_hat_n - theta)`. Here term (b) is the whole
problem: at b = 21, J_b puts 1-3 % of its mass at +/-infinity (+/-90 after the IRLS cap) while J_80 puts ~0 there.
Mapping to the four candidate explanations in the TODO:

- (a) *estimator infinite with positive probability / no moments*: true at size b, and it is the mechanism, but it is
  not a violated assumption. It matters only through (b).
- (b) *b too small relative to the rate at which P(zero-event arm) vanishes*: **this is the cause.** The asymptotics
  need b -> infinity; the finite-sample requirement is that P(degenerate subsample) be << alpha/2, i.e. about 6
  expected events per arm (section 1). b = 21 meets that only for p >= ~0.55.
- (c) *rate tau_b = sqrt(b), continuity of the limit*: correct as stated. A secondary finite-sample effect is real,
  though: the variance of `sqrt(b)(theta*_b - theta_hat_n)` without replacement is about `(1 - b/n)` times the
  variance of J_b (finite-population correction; it vanishes only because b/n -> 0), and the non-degenerate part of
  J_b is wider than J_n (small-sample logistic inflation, Sur and Candes 2019). At b = 21 these two roughly cancel
  (non-degenerate pivot SD 2.9 vs ~2.8 for sqrt(80)(log RR_hat - log RR)); at b = n/2 they do not (section 3).
- (d) *centering*: not the cause. Centering at log RR_hat is the PRW construction; term (c) of the proof is
  O(sqrt(b/n)), and a symmetric (|T|) p-value has the same floor `a`.

**m-out-of-n.** Bickel, Gotze and van Zwet (1997) and Bickel and Sakov (2008) require m -> infinity, m/n -> 0, and
(for resampling with replacement) that "T_m is not affected much by the order of sqrt(m) ties" (Bickel and Sakov 2008,
Section 2, citing BGvZ 1997). Ties are exactly what pushes a 21-out-of-80 resample into empty arms and separation more
often than a subsample. More to the point, both papers say m < n is a remedy for **bootstrap failure**; log RR is a
smooth function of means, the ordinary n-bootstrap works (EDI's own bootstrap paths have size 0.055-0.08 in the
v1.0.6-TODO-179 study), and Bickel and Sakov's adaptive rule is shown to choose `m_hat/n -> 1` in that case
(Corollary 1). BGvZ's title states the trade-off: resampling fewer than n observations has "losses" when the
bootstrap already works. The small m is pure loss here.

**Sparse binary data.** That log RR / log OR is infinite on a positive-probability event (a zero cell) is classical:
Haldane (1956) and Anscombe (1956) add 0.5 to each cell to get a finite estimator with smaller bias; Albert and
Anderson (1984) characterize when the logistic MLE does not exist (complete or quasi-complete separation); Firth
(1993) penalized likelihood always gives finite estimates; in the saturated 2x2 logistic model it reduces to the
Haldane-Anscombe 0.5 correction for the log OR (a standard property of the Jeffreys-prior penalty; I did not locate
the exact statement in the full text of the papers cited here). Heinze and Schemper (2002) and Heinze
(2006) recommend Firth for separated or nearly separated data and (as reported in secondary sources; not checked in
the full text) note that separation can occur in bootstrap resamples even when the original sample is fine. Sweeting,
Sutton and Lambert (2004) review continuity corrections for zero cells in sparse 2x2 tables. I found no paper that
studies subsampling or m-out-of-n for log risk ratios with sparse arms specifically; the diagnosis above follows
directly from the PRW proof.

## 3. Remedies and evidence (questions 3 and 4)

Null size at alpha = 0.05 (and 0.10), 200 null datasets, B = 199, seeds 1000 + s; Monte Carlo SE about 0.015 at
0.05. "EDI" rows use EDI's own `approximate_subsampling_distribution_beta_hat_T()` /
`approximate_m_out_of_n_bootstrap_distribution_beta_hat_T()` draws with the p-value formula of
`resampling_centered_pval()`; "replica" rows use the glm/Firth replica on its own subsample indices.

**n = 80** (b = m = 21 default):

| method | subsampling 0.05 | (0.10) | m-out-of-n 0.05 | (0.10) |
|---|---:|---:|---:|---:|
| Wald (reference) | 0.055 | (0.130) | | |
| **current** (EDI API, b = 21) | **0.005** | (0.035) | **0.000** | (0.005) |
| drop degenerate draws, EDI (abs(log RR* - log RR_hat) > 5) | 0.040 | (0.090) | 0.035 | (0.045) |
| drop degenerate draws, replica (threshold 2, 3, 5 or 8: identical) | 0.050 | (0.095) | 0.035-0.040 | (0.050) |
| Firth fits inside subsamples (and full data), sqrt(b) pivot, replica | 0.050 | (0.135) | 0.015 | (0.095) |
| b = m = 40 (= n/2), sqrt(b) pivot, EDI | 0.090 | (0.190) | 0.005 | (0.050) |
| b = 40 with finite-population scaling sqrt(b/(1 - b/n)), EDI | 0.020 | (0.050) | n/a | |
| b = 21 with sqrt(b/(1 - b/n)), EDI | 0.005 | (0.015) | n/a | |
| studentized (delta-method SE per subsample), replica | 0.115 | (0.180) | 0.080 | (0.145) |
| studentized with (1 - b/n) correction, replica | 0.085 | (0.130) | 0.080 | (0.145) |
| Firth + studentized (with correction), replica | 0.120 | (0.185) | 0.125 | (0.205) |

**n = 200** (b = m = 40 default; degenerate fraction 0.03 % for subsampling, 0.06 % for m-out-of-n):

| method | subsampling 0.05 | (0.10) | m-out-of-n 0.05 | (0.10) |
|---|---:|---:|---:|---:|
| Wald (reference) | 0.040 | (0.105) | | |
| **current** (EDI API, b = m = 40) | **0.025** | (0.080) | **0.010** | (0.055) |
| drop degenerate draws, EDI | 0.025 | (0.080) | 0.010 | (0.055) |
| Firth inside subsamples, replica | 0.075 | (0.115) | 0.040 | (0.080) |
| b = m = 100 (= n/2), sqrt(b) pivot, EDI | 0.155 | (0.220) | 0.025 | (0.075) |
| b = 100 with sqrt(b/(1 - b/n)), EDI | 0.025 | (0.075) | n/a | |
| studentized, replica | 0.085 | (0.140) | 0.075 | (0.125) |

At n = 200 the atoms are gone (b = 40 gives ~6.5 expected events per arm, matching the rule in section 1) and the
current subsampling test is only mildly conservative (0.025 vs Wald 0.040); dropping changes nothing because nothing
is dropped. m-out-of-n stays conservative (0.010) with almost no atoms, so for it there is a second, atom-free
cause: with-replacement resamples of 40 contain ties, and the non-degenerate part of J_m is wider than J_n (the
"order of sqrt(m) ties" condition of BGvZ 1997 holding only asymptotically). b = n/2 without the correction is
clearly anti-conservative (0.155), confirming the (1 - b/n) effect.

Remedy by remedy:

- **Drop (condition on) non-degenerate subsamples.** Best calibrated in the simulation (0.035-0.050), cheap, and
  insensitive to where the cut is put (thresholds 2 to 8 on |log RR* - log RR_hat| give identical p-values: the atoms
  are far from the bulk). Theory: if `q_hat` is the fraction of dropped draws, the conditional subsampling cdf differs
  from the unconditional one by at most `q_hat / (1 - q_hat)` in sup norm; since P(degenerate subsample) -> 0
  exponentially in b, PRW Theorem 2.1 carries over unchanged. Conditioning does change the finite-sample target to
  J_b(. | MLE exists), but the full-data estimate is also only used when it exists, and J_n(. | exists) ~ J_n at these
  n. It is a band-aid, not a cure, once `q_hat` is large (p = 0.1 at n = 80 drops ~50 % of subsamples, and the
  survivors are a selected, less-sparse population): it needs a cap on `q_hat` above which the method reports NA with
  a reason. This is close in spirit to the truncation used to repair inconsistent bootstrap variance estimators for
  statistics without moments (Shao and Tu 1995). Better to detect degeneracy directly (an arm with zero or all
  events in the subsample, or the subsample fit reporting non-convergence / separation) than through a numeric
  threshold.
- **Firth (penalized) fits inside subsamples** (the regression analogue of the Haldane-Anscombe 0.5 correction).
  Supported by Firth (1993) / Heinze and Schemper (2002): estimates always finite, bias O(n^-2). Subsampling stays
  first-order valid because the Firth and ML estimators are asymptotically equivalent, so J_b still converges to the
  same J. Simulation: 0.050 for subsampling, 0.015 for m-out-of-n (still conservative: Firth shrinks the subsample
  log OR, but with m = 21 and ties the shrunken values are still widely spread). Costs a second fitting routine in the
  g-computation path and changes the estimator inside subsamples only (or everywhere, if the full-data fit is also
  made Firth).
- **Larger b (b/n -> lambda > 0).** PRW's theorem needs b/n -> 0. With b = n/2 and the plain sqrt(b) pivot the test is
  anti-conservative (0.090), as the (1 - b/n) finite-population factor predicts. Rescaling by sqrt(b/(1 - b/n)) (the
  normalization of the delete-d jackknife histogram, Wu 1990; Shao and Wu 1989; valid for asymptotically normal
  statistics when b/n -> lambda in (0, 1)) over-corrects at n = 80 (0.020), because J_40 is still wider than J_80.
  A larger default b alone does not fix ratio estimands for rare events (b <= n/2 cannot reach 6 expected events per
  arm when p is small), so it is not a general fix.
- **Data-driven b (PRW minimum volatility, Bickel-Sakov).** EDI already has a minimum-volatility selector
  (`select_optimal_b_subsampling`, used when `b` is a list). Not simulated here. For this statistic the Bickel-Sakov
  theory predicts m_hat -> n (the n-bootstrap works), which EDI's n/2 cap forbids; minimum volatility searches the
  range where the atoms make the quantiles jumpy, so it should move b up, but at b near n/2 it meets the
  anti-conservative (1 - b/n) effect above. Not recommended without its own study.
- **Studentized subsampling.** Anti-conservative here (0.08-0.12 at n = 80, 0.075-0.085 at n = 200, also with the
  (1 - b/n) correction and with Firth). The likely reason is the Hauck-Donner (1977) effect: in degenerate and near-separated subsamples the delta-method SE
  explodes faster than the estimate, so those t* values collapse toward 0 instead of spreading the tails, and the
  remaining t* distribution is too narrow. Studentized subsampling needs the subsample SE to behave like the
  full-sample SE at size b, which it does not at these b. Not recommended.
- **Symmetric / two-sided pivot.** Does not help: `mean(abs(piv) >= abs(t_obs))` has the same floor `a`.
- **Log-OR scale.** Same zero-cell degeneracy (log OR is infinite on the same events), so no help.
- **RD scale.** The RD sibling is calibrated (0.065 / 0.070 in v1.0.6-TODO-179) because a zero-event arm gives a
  finite RD. For delta = 1, H0: RR = 1 is the same null as RD = 0, so the p-value at delta = 1 could be taken from the
  RD subsampling distribution. It does not give RR intervals or tests of delta != 1, so it is at most a special case.

## 4. Datasets where Wald rejects (n = 80, mechanism check)

| dataset | Wald p | subsampling p | floor 2a | p after drop | m-out-of-n p | floor 2a | p after drop |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 115 | 0.025 | 0.131 | 0.101 | 0.032 | 0.171 | 0.131 | 0.043 |
| 131 | 0.039 | 0.201 | 0.191 | 0.011 | 0.291 | 0.291 | 0.012 |
| 153 | 0.003 | 0.060 | 0.050 | 0.010 | 0.101 | 0.090 | 0.011 |
| 175 | 0.012 | 0.060 | 0.030 | 0.031 | 0.171 | 0.070 | 0.104 |
| 16 | 0.035 | 0.181 | 0.111 | 0.074 | 0.241 | 0.231 | 0.011 |
| 22 | 0.034 | 0.332 | 0.322 | 0.012 | 0.392 | 0.372 | 0.025 |
| 44 | 0.023 | 0.080 | 0.040 | 0.041 | 0.201 | 0.101 | 0.106 |
| 66 | 0.026 | 0.151 | 0.090 | 0.063 | 0.141 | 0.070 | 0.073 |
| 102 | 0.034 | 0.151 | 0.090 | 0.063 | 0.221 | 0.121 | 0.107 |
| 152 | 0.043 | 0.101 | 0.010 | 0.091 | 0.121 | 0.000 | 0.121 |
| 168 | 0.002 | 0.010 | 0.010 | 0.010 | 0.050 | 0.010 | 0.041 |

`a` = fraction of the 199 draws that are degenerate (abs(log RR* - log RR_hat) > 5) and on the side of `t_obs`.

## 5. Recommendation (owner decision)

1. Treat a subsample whose fit is degenerate (an arm with zero or all events, or a non-converged / separated fit) as
   unusable rather than as a finite draw: drop it in `compute_rr_resampling_pivot()`, count it, and return NA with a
   recorded reason (e.g. `subsampling_degenerate_fraction_too_high`) when the dropped fraction exceeds a cap (0.05 or
   0.10; owner's choice). This is the smallest change, keeps the PRW asymptotics, and brought the n = 80 size from
   0.005 / 0.000 to 0.040 / 0.035.
2. Optionally, in a later release, fit the subsamples with Firth's penalty instead, which removes the degeneracy
   instead of discarding it (size 0.050 for subsampling, still 0.015 for m-out-of-n).
3. Do not switch to a studentized pivot, and do not just raise the default b: both were mis-sized here.
4. Document in the RR classes' roxygen that subsampling and m-out-of-n are conservative for ratio estimands when an
   arm can expect fewer than ~6 events in a subsample of size b, and that the ordinary bootstrap (which is valid for
   this smooth estimator) is the better resampling choice. m-out-of-n stays conservative at n = 200 (0.010) even
   without atoms; fix 1 does not change that, and it would need its own study (larger default m, or extrapolation as
   in BGvZ 1997).

The same mechanism should be checked (not verified here) in other subsampling / m-out-of-n paths whose estimator is
infinite on a zero cell or zero-event arm: odds-ratio classes, the KK risk-ratio class (size 0.015 / 0.000 in
v1.0.6-TODO-179), count rate ratios with an all-zero arm, and hazard ratios with no events in an arm.

## Bibliography

- Albert, A. and Anderson, J. A. (1984). On the existence of maximum likelihood estimates in logistic regression
  models. *Biometrika* 71(1), 1-10. https://doi.org/10.1093/biomet/71.1.1
- Anscombe, F. J. (1956). On estimating binomial response relations. *Biometrika* 43(3/4), 461-464.
  https://doi.org/10.1093/biomet/43.3-4.461
- Bickel, P. J., Gotze, F. and van Zwet, W. R. (1997). Resampling fewer than n observations: gains, losses, and
  remedies for losses. *Statistica Sinica* 7(1), 1-31. https://www3.stat.sinica.edu.tw/statistica/j7n1/j7n11/j7n11.htm
- Bickel, P. J. and Sakov, A. (2008). On the choice of m in the m out of n bootstrap and confidence bounds for extrema.
  *Statistica Sinica* 18(3), 967-985. https://www3.stat.sinica.edu.tw/statistica/J18N3/J18N38/J18N38.html
- Candes, E. J. and Sur, P. (2020). The phase transition for the existence of the maximum likelihood estimate in
  high-dimensional logistic regression. *Annals of Statistics* 48(1), 27-42. https://doi.org/10.1214/18-AOS1789
- Firth, D. (1993). Bias reduction of maximum likelihood estimates. *Biometrika* 80(1), 27-38.
  https://doi.org/10.1093/biomet/80.1.27
- Haldane, J. B. S. (1956). The estimation and significance of the logarithm of a ratio of frequencies. *Annals of
  Human Genetics* 20(4), 309-311. https://doi.org/10.1111/j.1469-1809.1955.tb01285.x
- Hauck, W. W. and Donner, A. (1977). Wald's test as applied to hypotheses in logit analysis. *Journal of the American
  Statistical Association* 72(360), 851-853. https://doi.org/10.1080/01621459.1977.10479969
- Heinze, G. (2006). A comparative investigation of methods for logistic regression with separated or nearly
  separated data. *Statistics in Medicine* 25(24), 4216-4226. https://doi.org/10.1002/sim.2687
- Heinze, G. and Schemper, M. (2002). A solution to the problem of separation in logistic regression. *Statistics in
  Medicine* 21(16), 2409-2419. https://doi.org/10.1002/sim.1047
- Politis, D. N. and Romano, J. P. (1994). Large sample confidence regions based on subsamples under minimal
  assumptions. *Annals of Statistics* 22(4), 2031-2050. https://doi.org/10.1214/aos/1176325770
- Politis, D. N., Romano, J. P. and Wolf, M. (1999). *Subsampling*. Springer Series in Statistics, Springer, New York.
  https://doi.org/10.1007/978-1-4612-1554-7 (Theorem 2.2.1; Chapter 9, choice of the block size; Chapter 10,
  extrapolation)
- Politis, D. N., Romano, J. P. and Wolf, M. (2001). On the asymptotic theory of subsampling. *Statistica Sinica*
  11(4), 1105-1124. https://www3.stat.sinica.edu.tw/statistica/j11n4/j11n49/j11n49.htm
- Shao, J. and Tu, D. (1995). *The Jackknife and Bootstrap*. Springer, New York.
  https://doi.org/10.1007/978-1-4612-0795-5
- Shao, J. and Wu, C. F. J. (1989). A general theory for jackknife variance estimation. *Annals of Statistics* 17(3),
  1176-1197. https://doi.org/10.1214/aos/1176347263
- Sur, P. and Candes, E. J. (2019). A modern maximum-likelihood theory for high-dimensional logistic regression.
  *PNAS* 116(29), 14516-14525. https://doi.org/10.1073/pnas.1810420116
- Sweeting, M. J., Sutton, A. J. and Lambert, P. C. (2004). What to add to nothing? Use and avoidance of continuity
  corrections in meta-analysis of sparse data. *Statistics in Medicine* 23(9), 1351-1375.
  https://doi.org/10.1002/sim.1761
- Wu, C. F. J. (1990). On the asymptotic properties of the jackknife histogram. *Annals of Statistics* 18(3),
  1438-1452. https://doi.org/10.1214/aos/1176347759

Verification note: the PRW (2001) and Bickel-Sakov (2008) quotes were read from the papers' text; the BGvZ (1997)
abstract, the Haldane, Heinze (2006) and Wu (1990) bibliographic data were checked online. The Anscombe, Candes-Sur,
Sur-Candes, Sweeting et al., Shao-Tu, Shao-Wu and Politis-Romano (1994) DOIs are standard references not re-fetched in
this session. The Heinze-Schemper remark about separation in bootstrap resamples comes from a secondary source.
