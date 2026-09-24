library(testthat)
library(EDI)

# DesignSeqOneByOneKK21's private compute_weights() dispatcher (design_seq_one_by_one_KK21.R) has a
# dedicated survival branch: `if (private$survival_use_speedup_for_no_censoring && all(deads == 1))
# return(kk21_continuous_weights_cpp(as.matrix(xs), as.numeric(log(ys))))`, falling back to
# `kk21_survival_weights_cpp(as.matrix(xs), as.numeric(ys), as.numeric(deads))` otherwise (either the
# flag is FALSE, or there IS censoring in the data so far). A codebase-wide grep for
# "survival_use_speedup_for_no_censoring" confirmed zero test references anywhere -- the class's other
# compute_weights()/compute_weight_KK21_* reference files (test-kk21-design-generic-per-covariate-
# weight-reference.R, test-kk21-design-survival-ordinal-count-per-covariate-weight-reference.R, etc.)
# exercise the per-covariate KERNELS directly or the response-type dispatch for other response types,
# never this specific flag's own branch selection for survival. Reached via a real
# DesignSeqOneByOneKK21 instance run past its matching burn-in with real survival subjects (some
# uncensored, some right-censored via y_L/y_R), calling the private compute_weights() dispatcher
# directly on its own compute_all_subject_data() -- independently cross-checked against the two
# candidate C++ kernels called directly with the same (X, y, dead) inputs.

kk21_past_burn_in_surv <- function(seed, n_burn_in = 15L, speedup = TRUE, censor = FALSE) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK21$new(n = n_burn_in + 5L, response_type = "survival", verbose = FALSE,
		survival_use_speedup_for_no_censoring = speedup)
	for (i in seq_len(n_burn_in)) {
		x1 <- rnorm(1); x2 <- rnorm(1)
		w <- des$add_one_subject_to_experiment_and_assign(data.frame(x1 = x1, x2 = x2))
		event_time <- rexp(1, rate = exp(-0.4 * x1 - 0.3 * w))
		if (censor && i %% 3 == 0) {
			des$add_one_subject_response(i, y_L = event_time * 0.5, y_R = Inf)
		} else {
			des$add_one_subject_response(i, y = event_time)
		}
	}
	des
}

test_that("survival_use_speedup_for_no_censoring = TRUE with an all-uncensored sample matches kk21_continuous_weights_cpp on log(y) exactly", {
	des <- kk21_past_burn_in_surv(1L, speedup = TRUE, censor = FALSE)
	priv <- des$.__enclos_env__$private
	asd <- priv$compute_all_subject_data()
	w_out <- priv$compute_weights(asd)

	i_present <- which(!(is.na(priv$y) & is.na(priv$y_L) & is.na(priv$y_R)))
	ys <- des$get_effective_time()[i_present]
	ref <- EDI:::kk21_continuous_weights_cpp(as.matrix(asd$X_all_with_y_scaled), as.numeric(log(ys)))
	expect_equal(as.numeric(w_out), as.numeric(ref))
})

test_that("survival_use_speedup_for_no_censoring = FALSE always uses kk21_survival_weights_cpp, even with no censoring", {
	des <- kk21_past_burn_in_surv(2L, speedup = FALSE, censor = FALSE)
	priv <- des$.__enclos_env__$private
	asd <- priv$compute_all_subject_data()

	i_present <- which(!(is.na(priv$y) & is.na(priv$y_L) & is.na(priv$y_R)))
	ys <- des$get_effective_time()[i_present]
	deads <- des$get_effective_dead()[i_present]

	set.seed(99); w_out <- priv$compute_weights(asd)
	set.seed(99); ref <- EDI:::kk21_survival_weights_cpp(as.matrix(asd$X_all_with_y_scaled), as.numeric(ys), as.numeric(deads))
	expect_equal(as.numeric(w_out), as.numeric(ref))

	ref_fast_path <- EDI:::kk21_continuous_weights_cpp(as.matrix(asd$X_all_with_y_scaled), as.numeric(log(ys)))
	expect_false(isTRUE(all.equal(as.numeric(w_out), as.numeric(ref_fast_path), tolerance = 1e-3)))
})

test_that("survival_use_speedup_for_no_censoring = TRUE but WITH censoring in the data falls back to kk21_survival_weights_cpp", {
	des <- kk21_past_burn_in_surv(3L, speedup = TRUE, censor = TRUE)
	priv <- des$.__enclos_env__$private
	asd <- priv$compute_all_subject_data()

	i_present <- which(!(is.na(priv$y) & is.na(priv$y_L) & is.na(priv$y_R)))
	deads <- des$get_effective_dead()[i_present]
	expect_true(any(deads == 0))

	ys <- des$get_effective_time()[i_present]
	set.seed(100); w_out <- priv$compute_weights(asd)
	set.seed(100); ref <- EDI:::kk21_survival_weights_cpp(as.matrix(asd$X_all_with_y_scaled), as.numeric(ys), as.numeric(deads))
	expect_equal(as.numeric(w_out), as.numeric(ref))
})
