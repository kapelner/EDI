# TODO-106: InferenceOrdinalRidit's asymptotic SE must include the reference arm's
# sampling variance (DeLong), so the Wald p-value tracks wilcox.test(correct = FALSE).

ridit_fx = function(seed, n, shift = 0.3, reference = "control") {
	set.seed(seed)
	des = DesignFixediBCRD$new(n = n, response_type = "ordinal", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$overwrite_all_subject_assignments(rep(0:1, length.out = n))
	w = des$get_w()
	y = as.integer(pmin(sample(1:5, n, TRUE, prob = c(.3, .25, .2, .15, .1)) + w * (runif(n) < shift), 5L))
	des$add_all_subject_responses(y)
	list(inf = InferenceOrdinalRidit$new(des, reference = reference, verbose = FALSE), w = w, y = y)
}

delong_ref = function(y, w) {
	# brute-force placement values
	yt = y[w == 1]; yc = y[w == 0]
	psi = function(a, b) (a > b) + 0.5 * (a == b)
	v10 = vapply(yt, function(a) mean(psi(a, yc)), 0)
	v01 = vapply(yc, function(b) mean(psi(yt, b)), 0)
	list(theta = mean(v10), se = sqrt(var(v10) / length(yt) + var(v01) / length(yc)))
}

test_that("ridit SE equals the DeLong SE for control and treatment references, (n_C/N) times it for pooled", {
	for (seed in 1:3) {
		for (ref in c("control", "treatment", "pooled")) {
			f = ridit_fx(seed, 70L, reference = ref)
			d = delong_ref(f$y, f$w)
			nc = sum(f$w == 0); N = length(f$w)
			scale = if (ref == "pooled") nc / N else 1
			expect_equal(f$inf$compute_estimate(), scale * (d$theta - 0.5), tolerance = 1e-10, info = ref)
			p = f$inf$.__enclos_env__$private
			expect_equal(p$cached_values$s_beta_hat_T, scale * d$se, tolerance = 1e-10, info = ref)
		}
	}
})

test_that("control and treatment references give the same p-value, within 0.01 of wilcox.test(correct = FALSE)", {
	for (seed in 1:4) {
		fc = ridit_fx(seed, 80L, reference = "control")
		ft = ridit_fx(seed, 80L, reference = "treatment")
		pc = fc$inf$compute_asymp_two_sided_pval(0)
		pt = ft$inf$compute_asymp_two_sided_pval(0)
		expect_equal(pc, pt, tolerance = 1e-10)
		pw = suppressWarnings(wilcox.test(fc$y[fc$w == 1], fc$y[fc$w == 0], correct = FALSE)$p.value)
		expect_lt(abs(pc - pw), 0.01)
	}
})

test_that("null type-I error of the asymptotic ridit test is near nominal (small simulation)", {
	set.seed(20261022)
	rej = 0L; R = 200L
	for (r in seq_len(R)) {
		n = 40L
		w = sample(rep(0:1, n / 2))
		y = sample(1:4, n, TRUE, prob = c(.4, .3, .2, .1))
		se = ridit_delong_se(y, w, "control")
		est = mean(vapply(y[w == 1], function(a) mean((a > y[w == 0]) + 0.5 * (a == y[w == 0])), 0)) - 0.5
		if (is.finite(se) && se > 0 && abs(est / se) > qnorm(0.975)) rej = rej + 1L
	}
	expect_lt(rej / R, 0.09)
	expect_gt(rej / R, 0.01)
})
