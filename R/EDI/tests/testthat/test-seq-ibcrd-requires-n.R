# v1.0.6-TODO-187: DesignSeqOneByOneiBCRD requires n (owner decision 2026-11-19). With n = NULL it
# used to fall back to a Bernoulli coin while its randomization redraw still forced exact balance,
# so the randomization distribution was wrong. n = NULL is now refused at construction; with n the
# design is unchanged (goldens below were recorded before the change).

library(testthat)
library(EDI)

ibcrd_enroll = function(n, prob_T, set_seed = NULL, seed_arg = NULL) {
	if (!is.null(set_seed)) set.seed(set_seed)
	d = DesignSeqOneByOneiBCRD$new(n = n, prob_T = prob_T, response_type = "continuous", seed = seed_arg, verbose = FALSE)
	for (t in seq_len(n)) d$add_one_subject_to_experiment_and_assign(data.frame(x1 = t / n))
	d
}

test_that("DesignSeqOneByOneiBCRD refuses n = NULL with a clear message", {
	msg = "DesignSeqOneByOneiBCRD needs n.*use DesignSeqOneByOneBernoulli when n is unknown"
	expect_error(DesignSeqOneByOneiBCRD$new(response_type = "continuous"), msg)
	expect_error(DesignSeqOneByOneiBCRD$new(response_type = "continuous", n = NULL), msg)
	expect_error(DesignSeqOneByOneiBCRD$new(response_type = "incidence", n = NULL, prob_T = 0.3), msg)
})

test_that("DesignSeqOneByOneiBCRD refuses n = NULL even with asserts off", {
	old = options(edi.run_asserts = FALSE)
	on.exit(options(old), add = TRUE)
	expect_error(DesignSeqOneByOneiBCRD$new(response_type = "continuous"), "needs n")
})

test_that("DesignSeqOneByOneiBCRD refuses an n that is not a positive count", {
	expect_error(DesignSeqOneByOneiBCRD$new(response_type = "continuous", n = 0))
	expect_error(DesignSeqOneByOneiBCRD$new(response_type = "continuous", n = 2.5))
	expect_error(DesignSeqOneByOneiBCRD$new(response_type = "continuous", n = NA))
})

test_that("DesignSeqOneByOneiBCRD with n assigns exactly as before the change", {
	paste_w = function(d) paste(d$get_w(), collapse = "")
	a = ibcrd_enroll(21L, 0.5, set_seed = 1L)
	b = ibcrd_enroll(20L, 0.3, set_seed = 2L)
	c = ibcrd_enroll(15L, 0.5, seed_arg = 77L)
	expect_identical(paste_w(a), "000010001111010100111")
	expect_identical(paste_w(b), "01001101000010010000")
	expect_identical(paste_w(c), "010110110101001")
	# Exact terminal balance at round(n * prob_T).
	expect_equal(sum(a$get_w()), round(21 * 0.5))
	expect_equal(sum(b$get_w()), round(20 * 0.3))
	expect_equal(sum(c$get_w()), round(15 * 0.5))
})

test_that("DesignSeqOneByOneiBCRD redraws keep the realized number treated", {
	# n * prob_T not on a .5 tie here: at a tie (e.g. n = 21, prob_T = 0.5) assign_wt() rounds half to
	# even (10) while the C++ redraw kernel rounds half away from zero (11); that mismatch predates
	# v1.0.6-TODO-187 and is reported separately.
	for (cfg in list(list(n = 20L, p = 0.3, s = 2L), list(n = 15L, p = 0.5, s = 3L))) {
		d = ibcrd_enroll(cfg$n, cfg$p, set_seed = cfg$s)
		set.seed(5L)
		ws = d$draw_ws_according_to_design(50)
		expect_identical(dim(ws), c(cfg$n, 50L))
		expect_true(all(colSums(ws) == sum(d$get_w())), info = cfg$n)
	}
})
