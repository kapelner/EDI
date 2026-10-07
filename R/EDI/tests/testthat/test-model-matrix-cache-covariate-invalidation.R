make_model_matrix_cache_fixture <- function(class_name) {
	set.seed(21L)
	n <- 80L
	x <- rnorm(n)
	w <- rep(0:1, n / 2L)
	response_type <- if (grepl("Incid", class_name)) "incidence" else "count"
	y <- if (identical(response_type, "incidence")) {
		rbinom(n, 1L, plogis(-1 + 0.4 * w + 0.5 * x))
	} else {
		rpois(n, exp(0.4 + 0.3 * w + 0.4 * x))
	}
	des <- DesignFixedBernoulli$new(n = n, response_type = response_type, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	des$overwrite_all_subject_assignments(w)
	des$add_all_subject_responses(y)
	inf <- get(class_name, envir = asNamespace("EDI"))$new(des, model_formula = ~ x, verbose = FALSE)
	inf$.__enclos_env__$private
}

test_that("model-matrix caches follow changed covariates at fixed treatment", {
	caches <- c(
		InferenceIncidLogRegr = "logit_X_full_cache",
		InferenceIncidLogBinomial = "logbin_X_full_cache",
		InferenceCountPoisson = "poisson_X_full_cache",
		InferenceCountNegBin = "negbin_X_full_cache"
	)
	for (class_name in names(caches)) {
		priv <- make_model_matrix_cache_fixture(class_name)
		priv$generate_mod(estimate_only = TRUE)
		before <- priv[[caches[[class_name]]]]
		expect_equal(nrow(before), 80L, info = class_name)
		w_before <- priv$w

		priv$X <- priv$X[rev(seq_len(80L)), , drop = FALSE]
		fit_after <- priv$generate_mod(estimate_only = TRUE)
		after <- priv[[caches[[class_name]]]]
		expect_identical(priv$w, w_before, info = class_name)
		expect_false(identical(after, before), info = class_name)
		expect_equal(unname(after[, -(1:2), drop = FALSE]),
			unname(as.matrix(priv$get_X())), info = class_name)
		if (identical(class_name, "InferenceIncidLogRegr")) {
			fresh <- make_model_matrix_cache_fixture(class_name)
			fresh$X <- fresh$X[rev(seq_len(80L)), , drop = FALSE]
			fit_ref <- fresh$generate_mod(estimate_only = TRUE)
			expect_true(is.finite(fit_after$beta_hat_T))
			expect_equal(fit_after$beta_hat_T, fit_ref$beta_hat_T, tolerance = 1e-5)
		}
	}
})
