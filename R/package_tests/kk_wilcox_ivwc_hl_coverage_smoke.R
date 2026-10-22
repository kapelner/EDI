# Coverage smoke test for InferenceAllKKWilcoxIVWC (v1.0.5 TODO-84, sweep finding F7).
# Uses the INSTALLED EDI (library(EDI)); never loads or compiles the checkout.
#
# DGP (from the plan's description): KK14 sequential design, n = 80, two N(0,1) covariates
# (not in the outcome), N(0,1) noise, treatment effect 1, 300 reps, nominal 95% asymptotic CI.
# Reconstructed 2026-10-22 because the original /tmp runner was never archived; seed and
# exact outcome model are therefore NOT identical to the 2026-10-14 run (281/300 = 93.7%).
# Before the F7 fix coverage was 80.7%. Run: Rscript R/package_tests/kk_wilcox_ivwc_hl_coverage_smoke.R
suppressMessages(library(EDI))
set.seed(20261022L)
n = 80L; reps = 300L; effect = 1
t0 = Sys.time()
res = vapply(seq_len(reps), function(r) {
	X = as.data.frame(matrix(rnorm(n * 2L), ncol = 2L)); names(X) = c("x1", "x2")
	noise = rnorm(n)
	des = DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	for (i in seq_len(n)) {
		w = des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
		des$add_one_subject_response(i, noise[i] + effect * as.numeric(w == 1))
	}
	obj = InferenceAllKKWilcoxIVWC$new(des)
	est = suppressWarnings(obj$compute_estimate())
	ci = suppressWarnings(obj$compute_asymp_confidence_interval())
	c(est = est, lo = ci[[1]], hi = ci[[2]])
}, numeric(3))
ok = is.finite(res["lo", ]) & is.finite(res["hi", ])
cover = mean(res["lo", ok] <= effect & effect <= res["hi", ok])
cat(sprintf("coverage = %.3f (%d finite CIs of %d reps), SD(est) = %.4f, %.1f s\n",
	cover, sum(ok), reps, sd(res["est", ], na.rm = TRUE),
	as.numeric(difftime(Sys.time(), t0, units = "secs"))))
quit(status = if (cover >= 0.90) 0L else 1L)
