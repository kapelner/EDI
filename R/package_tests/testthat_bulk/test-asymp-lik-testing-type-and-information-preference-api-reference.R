library(testthat)
library(EDI)

# InferenceAsympLik's testing-type / information-preference selection API:
# normalize_testing_type() / normalize_information_preference() aliases and
# errors, set_testing_type() / set_information_preference() validation and side
# effects, the supported-types / supported-preferences lists (incl. the marginal
# estimand restriction and Bartlett additions), the capability predicates and
# default information source, and the Bartlett dispatch guard rails
# (unsupported stop, exact-factor B warning). None had a direct test reference.

lik_priv <- function(n = 40L, seed = 2L) {
	set.seed(seed)
	des <- DesignFixediBCRD$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rbinom(n, 1, 0.4))
	inf <- InferenceIncidLogRegr$new(des, verbose = FALSE)
	list(inf = inf, priv = inf$.__enclos_env__$private)
}

test_that("testing-type aliases normalize to canonical names and unknown names are rejected", {
	f <- lik_priv()
	nt <- f$priv$normalize_testing_type
	expect_equal(nt("wald"), "wald")
	expect_equal(nt("Score"), "score")
	expect_equal(nt("gradient"), "gradient")
	for (a in c("lr", "lrt", "LIK_RATIO", "likelihood_ratio")) expect_equal(nt(a), "lik_ratio", info = a)
	for (a in c("lik_ratio_bartlett_approx", "lr_bartlett_approx", "lrb_approx", "bartlett_approx")) {
		expect_equal(nt(a), "lik_ratio_bartlett_approx", info = a)
	}
	for (a in c("lik_ratio_bartlett_exact", "lr_bartlett_exact", "lrb_exact", "bartlett_exact")) {
		expect_equal(nt(a), "lik_ratio_bartlett_exact", info = a)
	}
	expect_equal(nt(c("score", "wald")), "score")                       # only the first element is used
	expect_error(nt("bogus"), "testing_type must be one of")
})

test_that("information-preference aliases normalize and unknown names are rejected", {
	f <- lik_priv()
	np <- f$priv$normalize_information_preference
	expect_equal(np("auto"), "auto")
	expect_equal(np("FISHER"), "fisher")
	expect_equal(np("obs"), "observed")
	expect_equal(np("observed"), "observed")
	expect_equal(np(c("observed", "auto")), "observed")
	expect_error(np("expected"), "information_preference must be one of")
})

test_that("set_testing_type stores supported types (returning self) and rejects unsupported ones naming the class", {
	f <- lik_priv()
	expect_equal(f$inf$get_supported_testing_types(),
		c("wald", "score", "gradient", "lik_ratio", "lik_ratio_bartlett_approx"))
	res <- f$inf$set_testing_type("lrt")
	expect_identical(res, f$inf)
	expect_equal(f$inf$get_testing_type(), "lik_ratio")
	f$inf$set_testing_type("bartlett_approx")
	expect_equal(f$inf$get_testing_type(), "lik_ratio_bartlett_approx")
	expect_error(f$inf$set_testing_type("lik_ratio_bartlett_exact"),
		"InferenceIncidLogRegr does not support testing_type = \"lik_ratio_bartlett_exact\"")
	expect_error(f$inf$set_testing_type("nonsense"), "testing_type must be one of")
	expect_equal(f$inf$get_testing_type(), "lik_ratio_bartlett_approx")   # unchanged by failures
})

test_that("a non-conditional estimand restricts testing to Wald", {
	f <- lik_priv()
	expect_true(isTRUE(f$inf$supports("marginal_estimand")))
	f$inf$set_estimand("marginal_mean_diff")
	expect_equal(f$inf$get_supported_testing_types(), "wald")
	expect_error(f$inf$set_testing_type("score"), "does not support testing_type")
	f$inf$set_estimand("conditional")
	expect_true("score" %in% f$inf$get_supported_testing_types())
})

test_that("Bartlett types are appended according to the class capability predicates", {
	f <- lik_priv()
	p <- f$priv
	unlockBinding("supports_bartlett_likelihood_ratio_exact", p)
	p$supports_bartlett_likelihood_ratio_exact <- function() TRUE
	expect_equal(f$inf$get_supported_testing_types(),
		c("wald", "score", "gradient", "lik_ratio", "lik_ratio_bartlett_approx", "lik_ratio_bartlett_exact"))
	f$inf$set_testing_type("lrb_exact")
	expect_equal(f$inf$get_testing_type(), "lik_ratio_bartlett_exact")
	unlockBinding("supports_bartlett_likelihood_ratio_approx", p)
	p$supports_bartlett_likelihood_ratio_approx <- function() FALSE
	p$supports_bartlett_likelihood_ratio_exact <- function() FALSE
	expect_equal(f$inf$get_supported_testing_types(), c("wald", "score", "gradient", "lik_ratio"))
})

test_that("information preference: supported list, validation, side effects, and accessor", {
	f <- lik_priv()
	p <- f$priv
	expect_equal(f$inf$get_information_preference(), "auto")
	expect_equal(f$inf$get_supported_information_preferences(), c("auto", "observed"))

	p$information_source_used <- "fisher"
	p$cached_values$likelihood_test_eval_cache <- list(stale = 1)
	res <- f$inf$set_information_preference("obs")
	expect_identical(res, f$inf)
	expect_equal(f$inf$get_information_preference(), "observed")
	expect_null(f$inf$get_information_source_used())                       # reset on change
	expect_length(p$cached_values$likelihood_test_eval_cache, 0L)          # eval cache cleared

	expect_error(f$inf$set_information_preference("expected"), "information_preference must be one of")
	expect_equal(f$inf$get_information_preference(), "observed")
	f$inf$set_information_preference("auto")
	expect_equal(f$inf$get_information_preference(), "auto")
})

test_that("'fisher' cannot be selected even for a class that exposes Fisher information (real source quirk, not fixed)", {
	# SOURCE QUIRK (noted, not fixed): get_supported_information_preferences_impl()
	# only ever lists c("auto", "observed") (or just "auto"), never "fisher" -- even
	# when supports_fisher_information() is TRUE and the default source is Fisher.
	# set_information_preference("fisher") therefore always errors, although
	# get_information_matrix() fully implements a "fisher" preference and the
	# argument's own choice list advertises it.
	f <- lik_priv()
	expect_true(f$priv$supports_fisher_information())
	expect_equal(f$priv$get_default_information_source(), "fisher")
	expect_error(f$inf$set_information_preference("fisher"),
		"does not support information_preference = \"fisher\". Supported values are: auto, observed")
})

test_that("capability predicates and the default information source cascade fisher > observed > legacy", {
	f <- lik_priv()
	p <- f$priv
	for (nm in c("supports_information_preference", "supports_observed_information", "supports_fisher_information",
		"get_default_information_source", "get_supported_information_preferences_impl")) unlockBinding(nm, p)
	expect_true(p$supports_information_preference())
	expect_true(p$supports_observed_information())

	p$supports_fisher_information <- function() FALSE
	expect_equal(p$get_default_information_source(), "observed")
	p$supports_information_preference <- function() FALSE
	expect_equal(p$get_default_information_source(), "legacy")
	expect_equal(p$get_supported_information_preferences_impl(), "auto")
	p$supports_information_preference <- function() TRUE
	expect_equal(p$get_supported_information_preferences_impl(), c("auto", "observed"))
	p$supports_fisher_information <- function() TRUE
	expect_equal(p$get_default_information_source(), "fisher")
})

test_that("Bartlett dispatch: exact factor warns when B is supplied, and no available factor stops with a clear message", {
	f <- lik_priv()
	p <- f$priv
	for (nm in c("supports_bartlett_likelihood_ratio_exact", "supports_bartlett_likelihood_ratio_approx",
		"compute_lik_ratio_bartlett_exact_two_sided_pval_impl", "compute_lik_ratio_bartlett_approx_two_sided_pval_impl")) {
		unlockBinding(nm, p)
	}
	p$supports_bartlett_likelihood_ratio_exact <- function() TRUE
	p$compute_lik_ratio_bartlett_exact_two_sided_pval_impl <- function(delta) 0.31
	expect_equal(p$compute_lik_ratio_bartlett_two_sided_pval_impl(0, B_missing = TRUE), 0.31)
	expect_warning(v <- p$compute_lik_ratio_bartlett_two_sided_pval_impl(0, B = 50, B_missing = FALSE),
		"InferenceIncidLogRegr has an exact Bartlett correction factor.*B is ignored")
	expect_equal(v, 0.31)

	p$supports_bartlett_likelihood_ratio_exact <- function() FALSE
	seen_B <- NULL
	p$supports_bartlett_likelihood_ratio_approx <- function() TRUE
	p$compute_lik_ratio_bartlett_approx_two_sided_pval_impl <- function(delta, B) { seen_B <<- B; 0.22 }
	expect_equal(p$compute_lik_ratio_bartlett_two_sided_pval_impl(0, B = 77, B_missing = FALSE), 0.22)
	expect_equal(seen_B, 77)

	p$supports_bartlett_likelihood_ratio_approx <- function() FALSE
	expect_error(p$compute_lik_ratio_bartlett_two_sided_pval_impl(0),
		"InferenceIncidLogRegr does not support Bartlett-corrected likelihood-ratio inference")
	expect_error(p$stop_bartlett_unsupported(), "neither an exact nor an approximate factor")
	expect_warning(p$warn_bartlett_B_ignored_by_exact(), "no simulation is performed")
})
