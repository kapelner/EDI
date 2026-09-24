library(testthat)
library(EDI)

# DesignSeqOneByOneKK21's private compute_weights() dispatcher (design_seq_one_by_one_KK21.R) has an
# ordinal_use_speedup branch parallel to the survival_use_speedup_for_no_censoring branch closed
# earlier this session (test-kk21-design-compute-weights-survival-use-speedup-for-no-censoring-branch-
# reference.R): `if (response_type == "ordinal" && ordinal_use_speedup) return(kk21_continuous_
# weights_cpp(X, y))`, else `return(kk21_ordinal_weights_cpp(X, y))`. A codebase-wide grep confirmed
# neither branch of this dispatcher, reached through the base (non-stepwise) DesignSeqOneByOneKK21's
# own compute_weights() on a real ordinal design, had any test reference anywhere -- the existing
# ordinal-response coverage for this class (test-kk21-design-survival-ordinal-count-per-covariate-
# weight-reference.R) calls the per-covariate kernel compute_weight_KK21_ordinal() directly (a
# different, fallback-loop-only code path unreachable for real response types), and the
# ordinal_use_speedup argument itself is only ever exercised on the DIFFERENT (stepwise) sibling class
# DesignSeqOneByOneKK21stepwise. Reached via a real DesignSeqOneByOneKK21 instance run past its
# matching burn-in with real ordinal-response subjects, calling the private compute_weights()
# dispatcher directly on its own compute_all_subject_data() -- independently cross-checked against the
# two candidate C++ kernels called directly with the same inputs.

kk21_past_burn_in_ordinal <- function(seed, n_burn_in = 15L, speedup = TRUE) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK21$new(n = n_burn_in + 5L, response_type = "ordinal", verbose = FALSE,
		ordinal_use_speedup = speedup)
	levs <- c("low", "med", "high")
	for (i in seq_len(n_burn_in)) {
		x1 <- rnorm(1); x2 <- rnorm(1)
		des$add_one_subject_to_experiment_and_assign(data.frame(x1 = x1, x2 = x2))
		y <- factor(sample(levs, 1), levels = levs, ordered = TRUE)
		des$add_one_subject_response(i, y)
	}
	des
}

test_that("ordinal_use_speedup = TRUE (the default) matches kk21_continuous_weights_cpp on the raw integer-coded ordinal levels", {
	des <- kk21_past_burn_in_ordinal(1L, speedup = TRUE)
	priv <- des$.__enclos_env__$private
	asd <- priv$compute_all_subject_data()
	w_out <- priv$compute_weights(asd)

	i_present <- which(!(is.na(priv$y) & is.na(priv$y_L) & is.na(priv$y_R)))
	ys <- priv$y[i_present]
	ref <- EDI:::kk21_continuous_weights_cpp(as.matrix(asd$X_all_with_y_scaled), as.numeric(ys))
	expect_equal(as.numeric(w_out), as.numeric(ref))
})

test_that("ordinal_use_speedup = FALSE dispatches to kk21_ordinal_weights_cpp instead, differing from the fast path", {
	des <- kk21_past_burn_in_ordinal(2L, speedup = FALSE)
	priv <- des$.__enclos_env__$private
	asd <- priv$compute_all_subject_data()

	i_present <- which(!(is.na(priv$y) & is.na(priv$y_L) & is.na(priv$y_R)))
	ys <- priv$y[i_present]

	set.seed(50); w_out <- priv$compute_weights(asd)
	set.seed(50); ref <- EDI:::kk21_ordinal_weights_cpp(as.matrix(asd$X_all_with_y_scaled), as.numeric(ys))
	expect_equal(as.numeric(w_out), as.numeric(ref))

	ref_fast_path <- EDI:::kk21_continuous_weights_cpp(as.matrix(asd$X_all_with_y_scaled), as.numeric(ys))
	expect_false(isTRUE(all.equal(as.numeric(w_out), as.numeric(ref_fast_path), tolerance = 1e-3)))
})
