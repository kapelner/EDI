library(testthat)
library(EDI)

make_stereotype_multimodal_fixture <- function(seed = 1005L){
	set.seed(seed)
	n = 50L
	w = rep(0:1, each = n / 2L)
	x = rnorm(n)
	X = cbind(treatment = w, x = x)
	eta = .7 * x
	alpha = c(-.2, .2)
	phi = c(0, .5, 1)
	probs = t(vapply(eta, function(e){
		logits = c(0, alpha + phi[2:3] * e)
		p = exp(logits - max(logits))
		p / sum(p)
	}, numeric(3)))
	y = apply(probs, 1L, function(p) sample.int(3L, 1L, prob = p))
	list(X = X, y = y)
}

test_that("stereotype full-data multistart escapes a reproducible inferior optimum", {
	fixture = make_stereotype_multimodal_fixture()
	primary = EDI:::fast_stereotype_logit_with_var_cpp(fixture$X, fixture$y)
	primary_lik = EDI:::fast_stereotype_logit_cpp(
		fixture$X, fixture$y,
		warm_start_params = primary$params,
		warm_start_fisher_info = primary$fisher_information,
		estimate_only = TRUE
	)
	primary$ssq_b_j = primary$ssq_b_1
	primary$neg_loglik = primary_lik$neg_loglik
	usable = EDI:::OrdinalStereotypeLikelihoodSource$private$stereotype_fit_is_usable

	selected = EDI:::.stereotype_full_data_multistart(
		fixture$X, fixture$y, primary, FALSE, usable
	)

	expect_gt(selected$multistart_improvement, 1)
	expect_lt(selected$neg_loglik, primary$neg_loglik - 1)
	expect_identical(selected$multistart_selected_start, "gamma_joint_1.5")
	expect_identical(selected$multistart_n_tried, 7L)
	expect_true(usable(selected, require_standard_error = TRUE))
})

test_that("stereotype multistart selection preserves ties and refits a winning start for variance", {
	X = cbind(treatment = c(0, 1, 0), x = c(-1, 0, 1))
	y = c(1, 2, 3)
	primary = list(
		params = rep(0, 5), b = 0, ssq_b_1 = .25, ssq_b_j = .25,
		neg_loglik = 10, converged = TRUE, fisher_information = diag(5)
	)
	usable = function(fit, require_standard_error = FALSE) !is.null(fit) && isTRUE(fit$converged)

	tie_fit = function(X, y, warm_start_params, ...){
		list(
			params = warm_start_params, b = warm_start_params[3L],
			neg_loglik = 10, converged = TRUE, fisher_information = diag(5)
		)
	}
	tied = EDI:::.stereotype_full_data_multistart(
		X, y, primary, TRUE, usable, fit_cpp = tie_fit
	)
	expect_equal(tied$params, primary$params)
	expect_identical(tied$multistart_selected_start, "primary")
	expect_identical(tied$multistart_improvement, 0)

	variance_start = NULL
	winning_fit = function(X, y, warm_start_params, ...){
		nll = if (isTRUE(all.equal(warm_start_params[5L], 1.5))) 8 else 10
		list(
			params = warm_start_params, b = warm_start_params[3L],
			neg_loglik = nll, converged = TRUE, fisher_information = diag(5)
		)
	}
	winning_var_fit = function(X, y, warm_start_params, ...){
		variance_start <<- warm_start_params
		list(
			params = warm_start_params, b = warm_start_params[3L],
			ssq_b_1 = .36, converged = TRUE, fisher_information = diag(5)
		)
	}
	winner = EDI:::.stereotype_full_data_multistart(
		X, y, primary, FALSE, usable,
		fit_cpp = winning_fit,
		fit_with_var_cpp = winning_var_fit
	)
	expect_equal(variance_start[5L], 1.5)
	expect_equal(winner$neg_loglik, 8)
	expect_identical(winner$multistart_selected_start, "gamma_joint_1.5")
	expect_equal(winner$ssq_b_j, .36)
})

test_that("stereotype data-seeded starts do not consume the global RNG", {
	fixture = make_stereotype_multimodal_fixture(44L)
	primary = EDI:::fast_stereotype_logit_cpp(fixture$X, fixture$y)
	set.seed(9123)
	state_before = .Random.seed
	candidates_a = EDI:::.stereotype_multistart_candidates(
		primary$params, fixture$X, fixture$y
	)
	state_after = .Random.seed
	candidates_b = EDI:::.stereotype_multistart_candidates(
		primary$params, fixture$X, fixture$y
	)

	expect_identical(state_after, state_before)
	expect_identical(candidates_b, candidates_a)
})

test_that("generate_mod wires the full-data multistart selector into ordinary fitting", {
	set.seed(1L)
	n <- 200L
	x <- rnorm(n)
	des <- DesignFixediBCRD$new(n = n, response_type = "ordinal", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- as.integer(cut(0.9 * w + rlogis(n), c(-Inf, -1, 0.4, 1.5, Inf)))
	des$add_all_subject_responses(y)
	inf <- InferenceOrdinalStereotypeLogitRegr$new(des, model_formula = ~1, verbose = FALSE)
	mod <- inf$.__enclos_env__$private$generate_mod()

	# The lower-level selector tests above prove how candidate fits are
	# selected; this integration assertion guards the ordinary full-data
	# generate_mod() call site. It is not a calibration estimate or a claim
	# about the separate repeated randomization/bootstrap refit paths.
	expect_true(length(mod$b) >= 2L && is.finite(mod$b[2L]))
	expect_true(mod$multistart_n_tried > 1L)
	expect_true(is.character(mod$multistart_selected_start) && nzchar(mod$multistart_selected_start))
})
