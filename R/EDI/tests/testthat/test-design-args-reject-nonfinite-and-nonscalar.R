library(testthat)
library(EDI)

# v1.0.6-TODO-106 (audit of checkmate defaults beyond any.missing): design
# arguments that checkmate let through by default -- Inf (no finite = TRUE), a
# vector where a scalar is meant (no len = 1), n = 0 (assertCount without
# positive = TRUE), NA in character vectors (assertCharacter's any.missing
# default) -- are now rejected where they are supplied. The 0/1 check on
# overwrite_all_subject_assignments() guards correctness (a w = 2 subject is in
# neither arm), so it runs with asserts on and off.

dnsnf_with_asserts = function(on, code) {
	old = EDI:::edi_env$asserts_user
	toggle_asserts(on)
	on.exit(toggle_asserts(if (is.null(old)) TRUE else old), add = TRUE)
	force(code)
}

dnsnf_fixed = function(rt, n = 6L) {
	set.seed(106)
	d = DesignFixedBernoulli$new(n = n, response_type = rt, verbose = FALSE)
	d$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	d$assign_w_to_all_subjects()
	d
}

test_that("Design construction rejects n = 0 and a length-2 prob_T", {
	expect_error(DesignFixedBernoulli$new(response_type = "continuous", n = 0), "'n'")
	expect_error(DesignFixedBernoulli$new(response_type = "continuous", n = 10, prob_T = c(0.4, 0.6)), "Must have length 1")
	expect_s3_class(DesignFixedBernoulli$new(response_type = "continuous", n = 1), "Design")
})

test_that("continuous and exact survival responses must be finite", {
	d = dnsnf_fixed("continuous")
	expect_error(d$add_all_subject_responses(c(rnorm(5), Inf)), "Must be finite")
	expect_error(d$add_one_subject_response(1, y = -Inf), "Must be finite")
	d = dnsnf_fixed("survival")
	expect_error(d$add_all_subject_responses(c(rexp(5), Inf)), "Must be finite")
	expect_error(d$add_one_subject_response(1, y = Inf), "Must be finite")
	# right-censoring is still y_L with y_R = Inf
	expect_silent(d$add_one_subject_response(1, y_L = 1, y_R = Inf))
})

test_that("Pocock-Simon rejects a length-2 p_best and an infinite weight", {
	expect_error(
		DesignSeqOneByOnePocockSimon$new(strata_cols = "x", p_best = c(0.7, 0.9), response_type = "continuous", n = 10),
		"Must have length 1"
	)
	expect_error(
		DesignSeqOneByOnePocockSimon$new(strata_cols = c("x", "z"), weights = c(1, Inf), response_type = "continuous", n = 10),
		"Must be finite"
	)
	expect_error(
		DesignSeqOneByOnePocockSimon$new(strata_cols = c("x", NA), response_type = "continuous", n = 10),
		"missing values"
	)
})

test_that("urn design rejects infinite alpha and beta", {
	expect_error(DesignSeqOneByOneUrn$new(alpha = Inf, response_type = "continuous", n = 10), "Must be finite")
	expect_error(DesignSeqOneByOneUrn$new(beta = Inf, response_type = "continuous", n = 10), "Must be finite")
})

test_that("blocking flags must be a single TRUE/FALSE and strata names may not be NA", {
	expect_error(DesignFixedBlocking$new(strata_cols = "x", exact_num_blocks = NA, response_type = "continuous", n = 10), "exact_num_blocks")
	expect_error(DesignFixedBlocking$new(strata_cols = "x", equal_block_sizes = c(TRUE, FALSE), response_type = "continuous", n = 10), "equal_block_sizes")
	expect_error(DesignFixedBlocking$new(strata_cols = NA_character_, response_type = "continuous", n = 10), "missing values")
	expect_error(DesignFixedCluster$new(cluster_col = NA_character_, response_type = "continuous", n = 10), "missing values")
})

for (asserts_on in c(TRUE, FALSE)) {
	test_that(sprintf("overwrite_all_subject_assignments rejects non-0/1 and wrong-length w (asserts %s)", asserts_on), {
		dnsnf_with_asserts(asserts_on, {
			d = dnsnf_fixed("continuous")
			expect_error(d$overwrite_all_subject_assignments(c(0, 0, 0, 1, 1, 2)), "0 \\(control\\) or 1 \\(treated\\)|<= 1")
			expect_error(d$overwrite_all_subject_assignments(c(0, 1, 0, 1, 0, NA)), "0 \\(control\\) or 1 \\(treated\\)|missing values")
			expect_error(d$overwrite_all_subject_assignments(c(0, 1, 0, 1)), "length|subjects")
			d$overwrite_all_subject_assignments(c(0, 1, 0, 1, 0, 1))
			expect_identical(d$get_w(), c(0, 1, 0, 1, 0, 1))

			set.seed(1)
			ds = DesignSeqOneByOneBernoulli$new(response_type = "continuous", n = 3, verbose = FALSE)
			for (i in 1:3) ds$add_one_subject_to_experiment_and_assign(data.frame(x = rnorm(1)))
			expect_error(ds$overwrite_all_subject_assignments(c(0, 1, 3)), "0 \\(control\\) or 1 \\(treated\\)|<= 1")
		})
	})
}
