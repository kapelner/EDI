library(testthat)
library(EDI)

# Two separate geepack-required guards, both fired only when use_rcpp = FALSE:
#   1. InferenceMixinKKGEEShared's init_kk_gee_shared() (inference_mixin_kk_gee_shared.R), composed
#      into every "generic" KK-GEE class (InferenceIncidKKGEE/InferenceCountKKGEE/
#      InferenceOrdinalKKGEE/...): "Package 'geepack' is required for <classname> when use_rcpp=FALSE.
#      Please install it." The "when use_rcpp=FALSE" clause appears only for a class whose constructor
#      has a use_rcpp argument. InferenceOrdinalKKGEE has none (it passes use_rcpp = FALSE itself), so
#      its message is "Package 'geepack' is required for InferenceOrdinalKKGEE. Please install it."
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

# docs-claims audit, finding docs-claims-dfabf84ea: InferenceOrdinalKKGEE always requires 'multgee' and errors at
# construction without it (no use_rcpp escape hatch).
test_that("InferenceOrdinalKKGEE errors at construction when multgee is (mocked as) unavailable", {
	set.seed(3L)
	n <- 30L
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "ordinal", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	des$add_all_subject_responses(sample(1:4, n, replace = TRUE))
	with_mocked_bindings(
		check_package_installed = function(pkg, ...) !identical(pkg, "multgee"),
		.package = "EDI",
		code = expect_error(
			InferenceOrdinalKKGEE$new(des, verbose = FALSE),
			"Package 'multgee' is required for InferenceOrdinalKKGEE. Please install it.",
			fixed = TRUE
		)
	)
	expect_false("use_rcpp" %in% names(formals(InferenceOrdinalKKGEE$public_methods$initialize)))
})

# InferenceOrdinalKKGEE hard-codes use_rcpp = FALSE into the shared mixin, so the mixin's geepack guard
# always runs for it. Its message used to say "when use_rcpp=FALSE", naming an argument the class does
# not have; it now omits that clause, and keeps it for the classes that expose use_rcpp (above).
test_that("InferenceOrdinalKKGEE's geepack error names no use_rcpp argument; a class with use_rcpp keeps the clause", {
	set.seed(4L)
	n <- 30L
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "ordinal", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	des$add_all_subject_responses(sample(1:4, n, replace = TRUE))
	msg <- with_mocked_bindings(
		check_package_installed = function(pkg, ...) !identical(pkg, "geepack"),
		.package = "EDI",
		code = tryCatch(InferenceOrdinalKKGEE$new(des, verbose = FALSE), error = function(e) e)
	)
	expect_s3_class(msg, "simpleError")
	expect_identical(conditionMessage(msg),
		"Package 'geepack' is required for InferenceOrdinalKKGEE. Please install it.")
	expect_false(grepl("use_rcpp", conditionMessage(msg), fixed = TRUE))

	set.seed(5L)
	des_c <- DesignSeqOneByOneKK14$new(n = n, response_type = "count", verbose = FALSE)
	for (i in seq_len(n)) des_c$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	des_c$add_all_subject_responses(rpois(n, 3))
	expect_true("use_rcpp" %in% names(formals(InferenceCountPoissonKKGEE$public_methods$initialize)))
	msg_c <- with_mocked_bindings(
		check_package_installed = function(pkg, ...) !identical(pkg, "geepack"),
		.package = "EDI",
		code = tryCatch(InferenceCountPoissonKKGEE$new(des_c, use_rcpp = FALSE, verbose = FALSE), error = function(e) e)
	)
	expect_s3_class(msg_c, "simpleError")
	expect_identical(conditionMessage(msg_c),
		"Package 'geepack' is required for InferenceCountPoissonKKGEE when use_rcpp=FALSE. Please install it.")
})
