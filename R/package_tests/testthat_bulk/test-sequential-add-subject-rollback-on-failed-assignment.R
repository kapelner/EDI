library(testthat)
library(EDI)

# v1.0.6-TODO-196 (docs-scenarios missing-data F3): a refused
# add_one_subject_to_experiment_and_assign() used to leave the subject enrolled
# (t advanced, row stored, w = NA), so every retry added another unassigned
# subject. The call now rolls the design back when the add or the assignment
# fails. The KK n = NULL failure at the 5th assignment
# (ds-sequential-designs-44358267779-f2, v1.0.6-TODO-38) left the same
# half-added subject.

seq_rollback_state = function(d) {
	p = d$.__enclos_env__$private
	list(t = d$get_t(), w = d$get_w(), X = as.data.frame(d$get_X_raw()), m = p$m)
}

test_that("a refused subject (missingness_method = 'error') is not enrolled", {
	set.seed(1)
	n = 20
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
	X$x2[1] = NA
	des = DesignSeqOneByOneAtkinson$new(n = n, response_type = "continuous", missingness_method = "error", verbose = FALSE)
	for (t in 1:4) des$add_one_subject_to_experiment_and_assign(X[t, , drop = FALSE])
	before = seq_rollback_state(des)
	for (t in 5:6) {
		expect_error(des$add_one_subject_to_experiment_and_assign(X[t, , drop = FALSE]), "Missing values")
	}
	expect_identical(des$get_t(), 4L)
	expect_identical(seq_rollback_state(des), before)
})

test_that("a failing assign_wt() leaves t, w, X and the KK match state as they were, and a retry matches an uninterrupted run", {
	for (cls in c("DesignSeqOneByOneKK21", "DesignSeqOneByOneKK14", "DesignSeqOneByOneEfron")) {
		for (fixed_n in c(TRUE, FALSE)) {
			set.seed(3)
			n = 24L
			X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
			make = function() get(cls)$new(n = if (fixed_n) n else NULL, response_type = "continuous", seed = 11, verbose = FALSE)
			ref = make()
			w_ref = vapply(seq_len(n), function(i) as.numeric(ref$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])), numeric(1))

			d = make()
			for (i in 1:15) d$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
			before = seq_rollback_state(d)
			orig_assign = d$assign_wt
			unlockBinding("assign_wt", d)
			d$assign_wt = function() stop("injected assignment failure")
			expect_error(d$add_one_subject_to_experiment_and_assign(X[16, , drop = FALSE]), "injected", info = cls)
			expect_identical(seq_rollback_state(d), before, info = paste(cls, fixed_n))
			d$assign_wt = orig_assign
			lockBinding("assign_wt", d)
			w_retry = c(before$w[1:15], vapply(16:n, function(i) as.numeric(d$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])), numeric(1)))
			expect_equal(w_retry, w_ref, info = paste(cls, fixed_n))
			expect_identical(d$get_t(), n)
		}
	}
})
