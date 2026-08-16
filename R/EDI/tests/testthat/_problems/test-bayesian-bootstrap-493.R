# Extracted from test-bayesian-bootstrap.R:493

# setup ------------------------------------------------------------------------
library(testthat)
test_env <- simulate_test_env(package = "EDI", path = "..")
attach(test_env, warn.conflicts = FALSE)

# prequel ----------------------------------------------------------------------
context("Bayesian bootstrap")
make_seq_design_for_bayes_boot = function(response_type, y){
	des = DesignSeqOneByOneBernoulli$new(n = length(y), response_type = response_type)
	for (i in seq_along(y)) {
		des$add_one_subject_to_experiment_and_assign(data.frame(x1 = i / 10))
	}
	des$overwrite_all_subject_assignments(rep(c(0, 1), length.out = length(y)))
	des$add_all_subject_responses(y)
	des
}
make_survival_design_for_bayes_boot = function(y, dead){
	des = DesignSeqOneByOneBernoulli$new(n = length(y), response_type = "survival")
	for (i in seq_along(y)) {
		des$add_one_subject_to_experiment_and_assign(data.frame(x1 = i / 10))
	}
	des$overwrite_all_subject_assignments(rep(c(0, 1), length.out = length(y)))
	# (ys, deads) positional convention was removed in the y/y_L/y_R migration
	# (interval_censored_survival_response.md TODO-15).
	y_exact = ifelse(dead == 1, y, NA_real_)
	y_L = ifelse(dead == 1, NA_real_, y)
	y_R = ifelse(dead == 1, NA_real_, Inf)
	des$add_all_subject_responses(y_exact, y_L, y_R)
	des
}
make_kk_design_for_weighted_bayes_boot = function(response_type, y, n_pairs = 3L, n_single = 2L){
	n = 2L * n_pairs + n_single
	des = DesignSeqOneByOneKK14$new(n = n, response_type = response_type, verbose = FALSE)
	for (i in seq_len(n)) {
		des$add_one_subject_to_experiment_and_assign(data.frame(x1 = i / 10, x2 = (i %% 3) / 10))
	}
	des$.__enclos_env__$private$m <- c(rep(seq_len(n_pairs), each = 2L), rep(0L, n_single))
	des$add_all_subject_responses(y)
	des
}

# test -------------------------------------------------------------------------
skip_if_not_installed("mirai")
skip_if(
		identical(Sys.getenv("R_COVR"), "true"),
		"avoid spawning real mirai daemons under covr's gcov-instrumented build"
	)
on.exit(unset_num_cores(), add = TRUE)
des = make_seq_design_for_bayes_boot("count", c(0L, 1L, 1L, 2L, 3L, 1L, 0L, 2L))
serial_inf = InferenceCountPoisson$new(des)
mirai_inf = InferenceCountPoisson$new(des)
serial_inf$num_cores = 1L
set.seed(20260515)
serial_boot = serial_inf$approximate_bayesian_bootstrap_distribution_beta_hat_T(
		B = 11L,
		show_progress = FALSE
	)
set_num_cores(2L, force_mirai = TRUE)
