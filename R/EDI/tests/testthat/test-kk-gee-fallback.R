MockKKGEEFallback <- R6::R6Class(
	"MockKKGEEFallback",
	inherit = InferenceIncidKKGEE,
	private = list(
		gee_predictors_df = function() data.frame(w = private$w),
		fit_gee_on_data = function(fit_data, std_err = TRUE, estimate_only = FALSE) {
			cluster_sizes = table(fit_data$id_sorted)
			if (any(cluster_sizes == 1L)) return(NULL)
			list(
				beta = c(`(Intercept)` = 0.25, w = 0.5),
				vcov = structure(diag(c(0.04, 0.09), nrow = 2L), dimnames = list(c("(Intercept)", "w"), c("(Intercept)", "w"))),
				converged = TRUE
			)
		}
	)
)

test_that("KK GEE falls back to matched-only fit when reservoir singletons break the full fit", {
	des <- DesignSeqOneByOneKK14$new(n = 8, response_type = "incidence", verbose = FALSE)
	X <- data.frame(x1 = seq_len(8), x2 = seq_len(8) %% 2)
	for (i in seq_len(nrow(X))) {
		des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	}
	des$add_all_subject_responses(c(0, 1, 0, 1, 0, 1, 0, 1))
	des$.__enclos_env__$private$m <- c(1L, 1L, 2L, 2L, 0L, 0L, 0L, 0L)

	inf <- MockKKGEEFallback$new(des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private

	expect_true(priv$gee_has_reservoir())
	expect_null(priv$fit_gee(std_err = FALSE, include_reservoir = TRUE))
	mod_fb = priv$fit_gee_with_fallback(std_err = FALSE, estimate_only = TRUE)
	expect_true(!is.null(mod_fb))
	expect_true(is.finite(priv$extract_gee_treatment_estimate(mod_fb)))
})

test_that("gee_predictors_df_candidates() actually generates a QR-reduced candidate for a collinear design", {
	# Regression for a bug found 2026-09-06 alongside the InferenceOrdinalKKGEE
	# rank-deficient-fallback fix: this function read the nonexistent field
	# attempt$X_fit (fit_with_hardened_qr_column_dropping() returns its
	# result under `fit`/`X`/`keep`, never `X_fit`), so normalize_candidate(NULL)
	# always fell back to the unreduced original design -- the QR-based
	# candidate was never actually generated for ANY class composing this
	# shared GEE mixin (continuous/count/incidence/proportion GEE, plus
	# ordinal KK GEE once it started calling this function too).
	# create_design_matrix() itself already de-duplicates exactly collinear
	# raw covariates, so a genuinely rank-deficient gee_predictors_df() (the
	# scenario that actually reaches this code in production, e.g. a
	# `~0+.` model.matrix that keeps every level of a factor) is reproduced
	# directly here by overriding gee_predictors_df(), bypassing
	# create_design_matrix() entirely.
	des <- DesignSeqOneByOneKK14$new(n = 8, response_type = "incidence", verbose = FALSE)
	x1 <- c(1, 2, 3, 4, 5, 6, 7, 8)
	X <- data.frame(x1 = x1)
	for (i in seq_len(nrow(X))) {
		des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	}
	des$add_all_subject_responses(c(0, 1, 0, 1, 0, 1, 0, 1))

	inf <- InferenceIncidKKGEE$new(des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	dup_pred_df <- data.frame(w = priv$w, x1 = x1, x1_dup = x1)
	unlockBinding("gee_predictors_df", priv)
	priv$gee_predictors_df <- function() dup_pred_df
	lockBinding("gee_predictors_df", priv)

	candidates <- priv$gee_predictors_df_candidates()

	expect_gt(length(candidates), 1L)
	reduced_found <- any(vapply(candidates, function(cand) !("x1_dup" %in% colnames(cand)) && "w" %in% colnames(cand), logical(1)))
	expect_true(reduced_found)
})
