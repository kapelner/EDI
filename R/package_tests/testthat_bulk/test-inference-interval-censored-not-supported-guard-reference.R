library(testthat)
library(EDI)

# inference_all_abstract.R's Inference$initialize() checks, once centrally, whether the design has
# any interval-/left-censored subject (a finite y_R -- Design$has_general_censoring()) and, if so,
# whether the concrete class's own supports_interval_or_left_censored_data() (base default FALSE,
# overridden to TRUE only by the handful of classes that genuinely support the general case, e.g.
# InferenceSurvivalCoxPHRegr) says it can handle it. A class that doesn't override it (e.g.
# InferenceSurvivalStratCoxPHRegr) errors "<class> does not support left- or interval-censored
# survival data ...". Zero test references anywhere despite this being a foundational, always-run
# construction-time check for every survival-response class.

fx <- function(seed = 1L, n = 10L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	for (i in seq_len(n)) {
		if (i == 1L) {
			des$add_one_subject_response(i, y_L = 1, y_R = 2)   # interval-censored
		} else {
			des$add_one_subject_response(i, y = i + 0.5)
		}
	}
	des
}

test_that("constructing a class that doesn't support interval/left-censored data with such a subject errors with the documented message", {
	des <- fx(seed = 1L)
	expect_error(
		InferenceSurvivalStratCoxPHRegr$new(des, verbose = FALSE),
		"InferenceSurvivalStratCoxPHRegr does not support left- or interval-censored survival data"
	)
})

test_that("constructing a class that does support it (InferenceSurvivalCoxPHRegr) does not error", {
	des <- fx(seed = 2L)
	expect_no_error(InferenceSurvivalCoxPHRegr$new(des, verbose = FALSE))
})

test_that("a design with no interval-censored subjects constructs fine on a non-supporting class", {
	set.seed(3L)
	n <- 10L
	des <- DesignFixedBernoulli$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rexp(n))
	expect_no_error(InferenceSurvivalStratCoxPHRegr$new(des, verbose = FALSE))
})
