# v1.0.6-TODO-75, v1.0.6-TODO-114, v1.0.6-TODO-92: the BCa bootstrap p-value (the default type)
# returned NA with no warning when the null value lay outside the bootstrap distribution, and also
# when the BCa adjustment was on the boundary (where the BCa CI warns). It now returns the 2 / B
# floor in the first case (as the percentile type does) and warns in the second. The boundary
# warning no longer recommends "B >= 501" when B is already >= 501.

bca_pval_ols_fx = function(){
	set.seed(20261117); n = 60
	X = data.frame(age = round(rnorm(n, 45, 12)), bmi = round(rnorm(n, 27, 4), 1), male = rbinom(n, 1, .5))
	des = DesignFixedRerandomization$new(n = n, response_type = "continuous", prop_acceptable = 0.05, seed = 7)
	des$add_all_subjects_to_experiment(X); des$assign_w_to_all_subjects(); w = des$get_w()
	des$add_all_subject_responses(10 + 2.5 * w + 0.1 * X$age - 0.3 * X$bmi + rnorm(n, sd = 3))
	inf = InferenceContinOLS$new(des, verbose = FALSE); inf$num_cores = 1L; inf$set_seed(1)
	inf
}

test_that("BCa p-value is the 2 / B floor, with no warning, when 0 is outside the bootstrap distribution", {
	inf = bca_pval_ols_fx()
	expect_no_warning(p <- inf$compute_bootstrap_two_sided_pval(B = 501, show_progress = FALSE))
	expect_equal(p, 2 / 501)
	expect_equal(inf$compute_bootstrap_two_sided_pval(B = 501, type = "percentile", show_progress = FALSE), 2 / 501)
	# a null value inside the distribution still goes through the BCa formula
	p1 = inf$compute_bootstrap_two_sided_pval(B = 501, delta = 1, show_progress = FALSE)
	expect_true(is.finite(p1) && p1 > 2 / 501 && p1 < 1)
})

test_that("bca_pval_core: unreachable deltas get the floor on both sides; the formula is unchanged inside", {
	inf = bca_pval_ols_fx()
	p = inf$.__enclos_env__$private
	set.seed(5)
	boot = rnorm(400, 0.5, 0.3)
	jack = rnorm(30, 0.5, 0.1)
	fail = function(reason) reason
	expect_equal(p$bca_pval_core(boot, 0.5, min(boot) - 1, jack, "bca_", fail), 2 / 400)
	expect_equal(p$bca_pval_core(boot, 0.5, max(boot) + 1, jack, "bca_", fail), 2 / 400)
	# reference value inside the support (independent BCa inversion)
	z0 = qnorm(mean(boot < 0.5)); jb = mean(jack); a = sum((jb - jack)^3) / (6 * sum((jb - jack)^2)^1.5)
	s = qnorm(mean(boot < 0.2)) - z0; adj = s / (1 + a * s) - z0
	expect_equal(p$bca_pval_core(boot, 0.5, 0.2, jack, "bca_", fail), 2 * pnorm(-abs(adj)), tolerance = 1e-12)
	# p-value shrinks monotonically toward the floor as delta leaves the centre
	ds = seq(0.5, min(boot) - 0.1, length.out = 25)
	ps = vapply(ds, function(d) p$bca_pval_core(boot, 0.5, d, jack, "bca_", fail), numeric(1))
	expect_true(all(diff(ps) <= 1e-12))
	expect_equal(tail(ps, 1), 2 / 400)
	# (The 1 + a s <= 0 floor branch is not tested: the jackknife acceleration is at most about 1/6,
	# so z0 - 1/a is beyond what any practical B can reach inside the support.)
})

fx_bca_boundary_114 = function(seed){
	set.seed(seed); n = 60
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
	des = DesignFixedBernoulli$new(n = n, response_type = "continuous")
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(as.numeric(des$get_w()) * 0.5 + X$x1 + rnorm(n))
	inf = InferenceContinOLS$new(des, verbose = FALSE)
	inf$num_cores = 1L
	inf
}

test_that("BCa p-value NA on the adjustment boundary warns once, like the CI, and the CI still warns", {
	inf = fx_bca_boundary_114(1)  # BCa boundary at B = 101 (see test-bootstrap-bca-boundary-reason-and-warning.R)
	got = list()
	h = function(w) { got[[length(got) + 1L]] <<- w; invokeRestart("muffleWarning") }
	p = withCallingHandlers(inf$compute_bootstrap_two_sided_pval(B = 101, show_progress = FALSE),
		edi_bootstrap_bca_boundary_warning = h)
	expect_true(is.na(p))
	expect_length(got, 1L)
	expect_identical(got[[1]]$what, "p-value")
	expect_identical(got[[1]]$reason, "bootstrap_bca_adjustment_on_boundary")
	expect_match(conditionMessage(got[[1]]), "The returned p-value is NA")
	# once per object for the p-value
	withCallingHandlers(inf$compute_bootstrap_two_sided_pval(B = 101, show_progress = FALSE),
		edi_bootstrap_bca_boundary_warning = h)
	expect_length(got, 1L)
	# the CI keeps its own once-per-object warning
	ci = withCallingHandlers(inf$compute_bootstrap_confidence_interval(B = 101, show_progress = FALSE),
		edi_bootstrap_bca_boundary_warning = h)
	expect_true(all(is.na(ci)))
	expect_length(got, 2L)
	expect_identical(got[[2]]$what, "interval")
	expect_match(conditionMessage(got[[2]]), "The returned interval is NA")
})

test_that("boundary warning advises a larger B only when B < 501", {
	inf = fx_bca_boundary_114(4)
	pr = inf$.__enclos_env__$private
	msg_at = function(B){
		pr$cached_values$bca_boundary_warned = NULL
		w = tryCatch(edi_warn_bca_boundary_once(inf, pr, B, "bca", "bootstrap_bca_adjustment_on_boundary"),
			edi_bootstrap_bca_boundary_warning = function(w) w)
		conditionMessage(w)
	}
	m200 = msg_at(200)
	expect_match(m200, "at B = 200")
	expect_match(m200, "increase B \\(>= 501 recommended\\)")
	expect_match(m200, "type = \"percentile\"", fixed = TRUE)
	m501 = msg_at(501)
	expect_match(m501, "at B = 501")
	expect_false(grepl("increase B", m501, fixed = TRUE))
	expect_false(grepl("501 recommended", m501, fixed = TRUE))
	expect_match(m501, "type = \"percentile\"", fixed = TRUE)
})
