library(testthat)
library(EDI)

# TODO-129 (release_v1_0_5.md, owner decision G6 #44; TODO-124 "Remains (a)"):
# bootstrap CIs came back NA for some seeds on DesignFixedBinaryMatch n = 60 for
# the KK OneLik classes, robust IVWC and InferenceContinOLS with a fully finite
# bootstrap distribution.
#  - Cause of the NA: the default CI type is BCa, and at B = 101 the documented
#    TODO-101 guard (adjusted tail probability within two order statistics of
#    the end) returns NA with reason "bootstrap_bca_adjustment_on_boundary".
#    Correct behavior; percentile at B = 101 and BCa at B >= 501 are finite.
#  - Real bug found on the way: the KK pass-through bootstrap (matched-pair
#    resampling) ignored set_seed(), so a seeded object drew from the caller's
#    global RNG stream and the "seed-dependent" NA pattern was not reproducible.

make_todo129_design = function(seed, n = 60L) {
	set.seed(seed)
	des = DesignFixedBinaryMatch$new(response_type = "continuous", n = n,
		m = rep(seq_len(n / 2L), each = 2L), verbose = FALSE)
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
	des$add_all_subjects_to_experiment(X)
	w = as.vector(replicate(n / 2L, sample(0:1)))
	des$assign_w_to_all_subjects(w)
	des$add_all_subject_responses(1 * w + 0.3 * X$x1 + rep(rnorm(n / 2L), each = 2L) + rnorm(n, sd = 0.6))
	des
}

todo129_boot = function(cl, des, B = 31L, seed = 4L) {
	inf = get(cl)$new(des, verbose = FALSE)
	inf$set_seed(seed)
	inf$num_cores = 1L
	inf$approximate_bootstrap_distribution_beta_hat_T(B = B, show_progress = FALSE)
}

test_that("seeded KK matched-pair bootstrap is reproducible and leaves the caller's RNG alone", {
	des = make_todo129_design(4L)
	for (cl in c("InferenceContinKKOLSOneLik", "InferenceContinKKRobustRegrIVWC")) {
		set.seed(1L); a = todo129_boot(cl, des)
		set.seed(2L); before = .Random.seed
		b = todo129_boot(cl, des)
		expect_true(identical(.Random.seed, before), info = paste(cl, "caller RNG untouched"))
		expect_identical(a, b, info = cl)
		expect_true(all(is.finite(a)), info = cl)
	}
})

test_that("seeded KK bootstrap replicates equal fresh fits on the seeded pair draws", {
	des = make_todo129_design(4L)
	cl = "InferenceContinKKOLSOneLik"
	B = 5L
	a = todo129_boot(cl, des, B = B)
	dp = des$.__enclos_env__$private
	set.seed(4L)
	draws = replicate(B, dp$draw_bootstrap_indices(NULL), simplify = FALSE)
	X = as.data.frame(des$get_X()); w = des$get_w(); y = des$get_y()
	ref = vapply(draws, function(dr) {
		i = dr$i_b
		db = DesignFixedBinaryMatch$new(response_type = "continuous", n = length(i),
			m = as.integer(dr$m_vec_b), verbose = FALSE)
		Xb = X[i, , drop = FALSE]; rownames(Xb) = NULL
		db$add_all_subjects_to_experiment(Xb)
		db$assign_w_to_all_subjects(w[i])
		db$add_all_subject_responses(y[i])
		get(cl)$new(db, verbose = FALSE)$compute_estimate()
	}, numeric(1L))
	expect_equal(a, ref, tolerance = 1e-8)
})

test_that("BCa at B = 101 can be NA on the documented boundary guard; percentile and B = 501 are finite", {
	des = make_todo129_design(1L)
	cl = "InferenceContinKKOLSOneLik"
	inf = get(cl)$new(des, verbose = FALSE)
	inf$set_seed(1L)
	inf$num_cores = 1L
	n_warn = 0L
	ci = withCallingHandlers(
		inf$compute_bootstrap_confidence_interval(B = 101L, type = "bca", show_progress = FALSE),
		edi_bootstrap_bca_boundary_warning = function(w) { n_warn <<- n_warn + 1L; invokeRestart("muffleWarning") })
	expect_true(all(is.na(ci)))
	expect_identical(n_warn, 1L)
	expect_identical(inf$.__enclos_env__$private$cached_values$procedure_failure_reason$bootstrap,
		"bootstrap_bca_adjustment_on_boundary")
	expect_true(all(is.finite(inf$approximate_bootstrap_distribution_beta_hat_T(B = 101L, show_progress = FALSE))))
	for (spec in list(list(type = "percentile", B = 101L), list(type = "bca", B = 501L))) {
		inf2 = get(cl)$new(des, verbose = FALSE)
		inf2$set_seed(1L)
		inf2$num_cores = 1L
		ci2 = inf2$compute_bootstrap_confidence_interval(B = spec$B, type = spec$type, show_progress = FALSE)
		expect_true(all(is.finite(ci2)), info = paste(spec$type, spec$B))
		expect_lt(ci2[1], ci2[2])
	}
})
