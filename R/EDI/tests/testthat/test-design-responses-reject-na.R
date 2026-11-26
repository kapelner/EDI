library(testthat)
library(EDI)

# v1.0.6-TODO-58 (assertNumeric calls that let NA through), v1.0.6-TODO-53
# (add_one_subject_response(1, y = NA) accepted silently) and v1.0.6-TODO-52 (a
# missing non-survival response gave an error about survival-only y_Ls/y_Rs).
# NA responses and NA design parameters must be rejected at the call that
# supplies them, with asserts on and with asserts off, since these checks guard
# correctness rather than only giving a clearer message.

na_resp_with_asserts = function(on, code) {
	old = EDI:::edi_env$asserts_user
	toggle_asserts(on)
	on.exit(toggle_asserts(if (is.null(old)) TRUE else old), add = TRUE)
	force(code)
}

na_resp_seq_design = function(rt) {
	set.seed(93)
	d = DesignSeqOneByOneBernoulli$new(response_type = rt, n = 4, verbose = FALSE)
	d$add_one_subject_to_experiment_and_assign(data.frame(x = 0.3))
	d
}

na_resp_fixed_design = function(rt, n = 6L) {
	set.seed(94)
	d = DesignFixediBCRD$new(n = n, response_type = rt, verbose = FALSE)
	d$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	d$assign_w_to_all_subjects()
	d
}

na_resp_no_outcome_msg = "responses may not be NA for response_type = \"%s\".*missing-covariates"

for (asserts_on in c(TRUE, FALSE)) {
	test_that(sprintf("add_one_subject_response rejects y = NA for non-survival types (asserts %s)", asserts_on), {
		na_resp_with_asserts(asserts_on, {
			for (rt in c("continuous", "incidence", "proportion", "count", "ordinal")) {
				d = na_resp_seq_design(rt)
				expect_error(d$add_one_subject_response(1, y = NA_real_),
					sprintf(na_resp_no_outcome_msg, rt), info = rt)
				expect_error(d$add_one_subject_response(1, y = NA),
					sprintf(na_resp_no_outcome_msg, rt), info = rt)
				expect_true(all(is.na(d$get_y())), info = rt)
			}
			d = na_resp_seq_design("ordinal")
			expect_error(
				d$add_one_subject_response(1, y = factor(NA, levels = c("a", "b"), ordered = TRUE)),
				sprintf(na_resp_no_outcome_msg, "ordinal")
			)
		})
	})

	test_that(sprintf("add_one_subject_response on survival: NA y and NA bounds rejected (asserts %s)", asserts_on), {
		na_resp_with_asserts(asserts_on, {
			d = na_resp_seq_design("survival")
			expect_error(d$add_one_subject_response(1, y = NA_real_), "supply y_L and y_R instead of y")
			expect_error(d$add_one_subject_response(1, y_L = NA_real_, y_R = Inf), "y_L|missing values")
			expect_error(d$add_one_subject_response(1, y_L = 1, y_R = NA_real_), "y_R|missing values")
			# a right-censored response is still accepted
			expect_silent(d$add_one_subject_response(1, y_L = 1, y_R = Inf))
		})
	})

	test_that(sprintf("add_all_subject_responses names the first NA subject for non-survival types (asserts %s)", asserts_on), {
		na_resp_with_asserts(asserts_on, {
			for (rt in c("continuous", "incidence", "count")) {
				d = na_resp_fixed_design(rt)
				y = switch(rt, continuous = rnorm(6), incidence = c(0, 1, 0, 1, 0, 1), count = c(1, 2, 3, 0, 1, 2))
				y[c(3, 5)] = NA
				expect_error(d$add_all_subject_responses(y),
					paste0("subject 3 .*", sprintf(na_resp_no_outcome_msg, rt)), info = rt)
			}
			# the sequential (non-fixed) Design method shares the message
			d = DesignSeqOneByOneBernoulli$new(response_type = "continuous", n = 3, verbose = FALSE)
			for (i in 1:3) d$add_one_subject_to_experiment_and_assign(data.frame(x = i))
			expect_error(d$add_all_subject_responses(c(1, NA, 2)),
				paste0("subject 2 .*", sprintf(na_resp_no_outcome_msg, "continuous")))
		})
	})

	test_that(sprintf("add_all_subject_responses on survival keeps the y_Ls/y_Rs wording (asserts %s)", asserts_on), {
		na_resp_with_asserts(asserts_on, {
			d = na_resp_fixed_design("survival", n = 4L)
			expect_error(d$add_all_subject_responses(c(1, NA, 2, 3)), "Subject 2 has no response.*y_Ls and y_Rs")
			# NA in ys is legitimate when that subject is censored through y_Ls/y_Rs
			d$add_all_subject_responses(ys = c(1, NA, 2, 3), y_Ls = c(NA, 1.5, NA, NA), y_Rs = c(NA, Inf, NA, NA))
			expect_equal(d$get_y_L()[2], 1.5)
		})
	})

	test_that(sprintf("design constructors reject NA prob_T, p_best and weights (asserts %s)", asserts_on), {
		na_resp_with_asserts(asserts_on, {
			expect_error(DesignSeqOneByOneBernoulli$new(prob_T = NA_real_, response_type = "continuous", n = 4),
				"prob_T")
			expect_error(DesignFixedBernoulli$new(prob_T = NA_real_, response_type = "continuous", n = 4),
				"prob_T")
			expect_error(DesignSeqOneByOnePocockSimon$new(strata_cols = "x", p_best = NA_real_,
				response_type = "continuous", n = 4), "p_best")
			expect_error(DesignSeqOneByOnePocockSimon$new(strata_cols = c("x", "z"), weights = c(1, NA),
				response_type = "continuous", n = 4), "weights")
		})
	})
}

test_that("add_one_subject_response rejects an NA subject index", {
	d = na_resp_seq_design("continuous")
	expect_error(d$add_one_subject_response(NA_real_, y = 1))
})
