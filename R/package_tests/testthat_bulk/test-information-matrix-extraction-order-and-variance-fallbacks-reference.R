library(testthat)
library(EDI)

# InferenceExtInformationMatrix's get_information_matrix() source-resolution
# order (spec method > fit field > information_type-tagged fit$information >
# legacy), its error behavior under an explicit preference, and the
# compute_variance_from_information_matrix() / compute_standard_error_from_
# information_matrix() edge branches. The sibling test-ext-information-matrix.R
# covers the fisher/observed preference selection, a diagonal example and the ridge
# score-test fallback; these branches had no direct reference.

im_priv <- function(n = 40L, seed = 2L) {
	set.seed(seed)
	des <- DesignFixediBCRD$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rbinom(n, 1, 0.4))
	inf <- InferenceIncidLogRegr$new(des, verbose = FALSE)
	list(inf = inf, priv = inf$.__enclos_env__$private)
}

test_that("under an undecided default source the Fisher information wins, then observed, then legacy", {
	f <- im_priv()
	p <- f$priv
	# For this likelihood class the default source resolves to Fisher outright; the
	# fisher -> observed -> legacy chain applies when the default is neither, so pin
	# that fallback by stubbing the default source.
	expect_equal(p$get_default_information_source(), "fisher")
	unlockBinding("get_default_information_source", p)
	p$get_default_information_source <- function() "any"
	fisher <- diag(c(2, 4)); observed <- diag(c(3, 9)); legacy <- diag(c(5, 7))
	expect_equal(p$information_preference, "auto")

	all_three <- list(full_fit = list(fisher_information = fisher, observed_information = observed, information = legacy), j = 2L)
	expect_equal(p$get_information_matrix(spec = all_three), fisher)
	expect_equal(f$inf$get_information_source_used(), "fisher")

	no_fisher <- list(full_fit = list(observed_information = observed, information = legacy), j = 2L)
	expect_equal(p$get_information_matrix(spec = no_fisher), observed)
	expect_equal(f$inf$get_information_source_used(), "observed")

	legacy_only <- list(full_fit = list(information = legacy), j = 2L)
	expect_equal(p$get_information_matrix(spec = legacy_only), legacy)
	expect_equal(f$inf$get_information_source_used(), "legacy")

	expect_null(p$get_information_matrix(spec = list(full_fit = list(other = 1), j = 2L)))
})

test_that("spec accessor functions take precedence over fit fields, and tagged fit$information is honored", {
	f <- im_priv()
	p <- f$priv
	from_spec <- list(
		full_fit = list(fisher_information = diag(2)),
		fisher_information = function(fit) diag(c(10, 20)),
		j = 2L
	)
	expect_equal(p$get_information_matrix(spec = from_spec), diag(c(10, 20)))

	unlockBinding("get_default_information_source", p)
	p$get_default_information_source <- function() "any"
	tagged_fisher <- list(full_fit = list(information = diag(c(1, 2)), information_type = "fisher"), j = 2L)
	expect_equal(p$get_information_matrix(spec = tagged_fisher), diag(c(1, 2)))
	expect_equal(f$inf$get_information_source_used(), "fisher")
	tagged_observed <- list(full_fit = list(information = diag(c(3, 4)), information_type = "observed"), j = 2L)
	expect_equal(p$get_information_matrix(spec = tagged_observed), diag(c(3, 4)))
	expect_equal(f$inf$get_information_source_used(), "observed")

	# An explicit fit argument overrides the spec's full fit; a failing accessor is skipped.
	expect_equal(p$get_information_matrix(spec = from_spec, fit = list(fisher_information = diag(3))), diag(c(10, 20)))
	broken <- list(full_fit = list(observed_information = diag(2)), fisher_information = function(fit) stop("boom"), j = 2L)
	expect_equal(p$get_information_matrix(spec = broken), diag(2))
	expect_equal(f$inf$get_information_source_used(), "observed")
})

test_that("an explicit preference errors, naming the class, when that information is not exposed", {
	f <- im_priv()
	p <- f$priv
	spec <- list(full_fit = list(other = 1), j = 2L)
	p$information_preference <- "fisher"
	expect_error(p$get_information_matrix(spec = spec), "InferenceIncidLogRegr does not expose Fisher information")
	p$information_preference <- "observed"
	expect_error(p$get_information_matrix(spec = spec), "does not expose observed information")
	# With no arguments the class's own fitted spec supplies a real square matrix.
	p$information_preference <- "auto"
	real <- p$get_information_matrix()
	expect_true(is.matrix(real) && nrow(real) == ncol(real))
})

test_that("missing spec or fit yields NULL, and the SE helper degrades to NA", {
	f <- im_priv()
	p <- f$priv
	unlockBinding("get_likelihood_test_spec", p)
	p$get_likelihood_test_spec <- function() NULL
	expect_null(p$get_information_matrix())
	expect_true(is.na(p$compute_standard_error_from_information_matrix()))
	expect_null(p$get_information_matrix(spec = list(full_fit = NULL, j = 1L), fit = NULL))
})

test_that("variance from information: 1x1, PD, invalid index, non-square and non-finite cases", {
	f <- im_priv()
	v <- f$priv$compute_variance_from_information_matrix
	expect_equal(v(matrix(4), 1L), 0.25)
	expect_true(is.na(v(matrix(-4), 1L)))
	expect_true(is.na(v(matrix(0), 1L)))
	expect_true(is.na(v(matrix(NA_real_), 1L)))

	pd <- matrix(c(2, 1, 1, 3), 2)
	expect_equal(v(pd, 1L), solve(pd)[1, 1], tolerance = 1e-10)
	expect_equal(v(pd, 2L), solve(pd)[2, 2], tolerance = 1e-10)
	big <- crossprod(matrix(c(1, 2, 0, 1, 3, 1, 2, 2, 5), 3)) + diag(3)
	for (j in 1:3) expect_equal(v(big, j), solve(big)[j, j], tolerance = 1e-8)

	expect_true(is.na(v(pd, 0L)))
	expect_true(is.na(v(pd, 3L)))
	expect_true(is.na(v(pd, NA_integer_)))
	expect_true(is.na(v(pd, c(1L, 2L))))
	expect_true(is.na(v(matrix(1:6, 2), 1L)))                    # non-square
	expect_true(is.na(v(matrix(c(1, NaN, NaN, 1), 2), 1L)))      # non-finite entries
})

test_that("a singular (or non-finite) information matrix has no variance", {
	f <- im_priv()
	expect_true(is.na(f$priv$compute_variance_from_information_matrix(matrix(1, 2, 2), 1L)))
	expect_true(is.na(f$priv$compute_variance_from_information_matrix(matrix(c(1, 2, 2, 4), 2), 2L)))
	expect_true(is.na(f$priv$compute_variance_from_information_matrix(cbind(c(1, 0, 1), c(0, 1, 1), c(1, 1, 2)), 3L)))
	expect_true(is.na(f$priv$compute_standard_error_from_information_matrix(
		spec = list(full_fit = list(fisher_information = matrix(1, 2, 2)), j = 1L))))
})

test_that("SE from information uses spec$j by default, square-roots non-negative variances and NA otherwise", {
	f <- im_priv()
	p <- f$priv
	fisher <- diag(c(2, 4))
	spec <- list(full_fit = list(fisher_information = fisher), j = 2L)
	expect_equal(p$compute_standard_error_from_information_matrix(spec = spec), 0.5)
	expect_equal(p$compute_standard_error_from_information_matrix(spec = spec, j = 1L), sqrt(1 / 2))
	expect_true(is.na(p$compute_standard_error_from_information_matrix(spec = spec, j = 5L)))

	neg <- list(full_fit = list(fisher_information = matrix(-4)), j = 1L)
	expect_true(is.na(p$compute_standard_error_from_information_matrix(spec = neg)))
	none <- list(full_fit = list(other = 1), j = 1L)
	expect_true(is.na(p$compute_standard_error_from_information_matrix(spec = none)))
	expect_equal(p$get_score_test_information_matrix(spec, NULL), fisher)
})
