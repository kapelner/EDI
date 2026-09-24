library(testthat)
library(EDI)

# Two separate geepack-required guards, both fired only when use_rcpp = FALSE:
#   1. InferenceMixinKKGEEShared's init_kk_gee_shared() (inference_mixin_kk_gee_shared.R), composed
#      into every "generic" KK-GEE class (InferenceIncidKKGEE/InferenceCountKKGEE/
#      InferenceOrdinalKKGEE/...): "Package 'geepack' is required for <classname> when use_rcpp=FALSE.
#      Please install it."
#   2. InferencePropKKGEE's OWN initialize() (inference_proportion_KK_combined.R, a distinct
#      fractional-logit GEE implementation that does not compose the shared mixin's initialize
#      directly): "Package 'geepack' is required for InferencePropKKGEE. Please install it." -- a
#      differently-worded but analogous guard.
# A codebase-wide grep confirmed neither exact message had any test reference anywhere, despite both
# classes being otherwise extensively tested elsewhere (test-kk-gee-parity.R exercises use_rcpp = TRUE
# and use_rcpp = FALSE side by side, but always with the real geepack package installed) -- the
# "package unavailable" branch itself was never exercised on either site. Reached via
# with_mocked_bindings(check_package_installed = function(...) FALSE, .package = "EDI"), the same
# established pattern used for the nbpMatching/quantreg/glmmTMB "package unavailable" guards elsewhere
# in this suite.

test_that("InferenceIncidKKGEE (shared init_kk_gee_shared mixin) errors with the documented message under use_rcpp = FALSE when geepack is (mocked as) unavailable", {
	set.seed(1L)
	n <- 30L
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "incidence", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	des$add_all_subject_responses(rbinom(n, 1, plogis(0.3 * w)))

	with_mocked_bindings(
		check_package_installed = function(...) FALSE,
		.package = "EDI",
		code = {
			expect_error(
				InferenceIncidKKGEE$new(des, use_rcpp = FALSE, verbose = FALSE),
				"Package 'geepack' is required for InferenceIncidKKGEE when use_rcpp=FALSE. Please install it.",
				fixed = TRUE
			)
			# use_rcpp = TRUE never reaches the guard, even with geepack mocked as unavailable
			expect_no_error(InferenceIncidKKGEE$new(des, use_rcpp = TRUE, verbose = FALSE))
		}
	)
})

test_that("InferencePropKKGEE's own initialize() errors with its own documented message under use_rcpp = FALSE when geepack is (mocked as) unavailable", {
	set.seed(2L)
	n <- 30L
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "proportion", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	des$add_all_subject_responses(plogis(rnorm(n) + 0.3 * w))

	with_mocked_bindings(
		check_package_installed = function(...) FALSE,
		.package = "EDI",
		code = {
			expect_error(
				InferencePropKKGEE$new(des, use_rcpp = FALSE, verbose = FALSE),
				"Package 'geepack' is required for InferencePropKKGEE. Please install it.",
				fixed = TRUE
			)
			expect_no_error(InferencePropKKGEE$new(des, use_rcpp = TRUE, verbose = FALSE))
		}
	)
})
