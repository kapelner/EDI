test_that("InferenceOrdinalKKGEE falls back to a QR-hardened candidate when the raw design is rank-deficient", {
	# Regression for the 2026-09-06 comprehensive-results investigation:
	# fit_ordinal_gee_mod() was called directly on the raw, unreduced
	# gee_predictors_df(), unlike the shared GEE mixin's own fits
	# (fit_gee_with_fallback, its bootstrap-weight loop), which already
	# iterate over gee_predictors_df_candidates() -- a QR-hardened sequence
	# of rank-reduced candidate designs. Some fixture covariate matrices
	# (e.g. "diamonds"'s ~0+. model.matrix, which keeps every level of its
	# first categorical factor) are rank-deficient, and
	# multgee::ordLORgee()'s vglm() backend refuses any non-full-rank
	# design ("vglm() only handles full-rank models"), an error the
	# original tryCatch silently swallowed into NULL -- reproduced here
	# with an exactly duplicated covariate column, which produces the
	# identical vglm error.
	n <- 100L
	set.seed(9903L)
	x1 <- rnorm(n)
	w <- rep(c(0, 1), n / 2)
	dup_pred_df <- data.frame(w = w, x1 = x1, x1_dup = x1)

	des <- DesignFixedBinaryMatch$new(n = n, response_type = "ordinal", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = x1))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(sample(1:4, n, replace = TRUE))
	inf <- InferenceOrdinalKKGEE$new(des, model_formula = ~ ., verbose = FALSE)
	priv <- inf$.__enclos_env__$private

	# The raw single-candidate fit genuinely fails on the collinear design
	# (confirms the reproduction is real, not a false negative).
	mod_raw <- priv$fit_ordinal_gee_mod(predictors_df = dup_pred_df)
	expect_null(mod_raw)

	# fit_ordinal_gee_mod_with_fallback() must recover by trying a
	# QR-hardened reduced candidate instead.
	old_gee_predictors_df <- priv$gee_predictors_df
	unlockBinding("gee_predictors_df", priv)
	priv$gee_predictors_df <- function() dup_pred_df
	on.exit({
		unlockBinding("gee_predictors_df", priv)
		priv$gee_predictors_df <- old_gee_predictors_df
		lockBinding("gee_predictors_df", priv)
	}, add = TRUE)
	lockBinding("gee_predictors_df", priv)

	mod_fallback <- priv$fit_ordinal_gee_mod_with_fallback()
	expect_false(is.null(mod_fallback))
	beta <- stats::coef(mod_fallback)
	expect_true(all(is.finite(beta)))
})
