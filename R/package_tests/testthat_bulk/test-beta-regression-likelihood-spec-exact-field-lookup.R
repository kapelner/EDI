library(testthat)
library(EDI)

# Found while auditing the likelihood-test spec hooks after the zero-augmented Poisson
# fix (test-zero-augmented-likelihood-spec-exact-field-lookup.R; v1.1.0-TODO-174 work).
# InferencePropBetaRegr's spec uses generate_mod()'s wrapper list as its full fit. That
# list carries `information_invertible` but no `information`, and the information() hook
# read `fit$information %||% ...`; `$` partially matches list names, so it returned the
# TRUE/FALSE/NA flag instead of the Fisher information. The hooks now read fields by
# exact name.

beta_spec_design = function() {
	set.seed(20261126)
	n = 120L
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
	d = DesignFixedBernoulli$new(n = n, response_type = "proportion", verbose = FALSE)
	d$add_all_subjects_to_experiment(X)
	d$assign_w_to_all_subjects()
	w = d$get_w()
	mu = plogis(-0.2 + 0.4 * w + 0.3 * X$x1 - 0.2 * X$x2)
	phi = 8
	d$add_all_subject_responses(rbeta(n, mu * phi, (1 - mu) * phi))
	d
}

test_that("InferencePropBetaRegr spec hooks read the generate_mod() wrapper by exact field name", {
	inf = InferencePropBetaRegr$new(beta_spec_design(), verbose = FALSE)
	priv = inf$.__enclos_env__$private
	spec = priv$get_likelihood_test_spec()
	expect_false(is.null(spec))
	wrapper = spec$full_fit
	# The trap: no `information` element, but a name it is a prefix of.
	expect_null(wrapper[["information"]])
	expect_true("information_invertible" %in% names(wrapper))

	p = length(wrapper$b) + 1L
	info = spec$information(wrapper)
	expect_true(is.matrix(info) && is.numeric(info))
	expect_identical(dim(info), c(p, p))
	expect_equal(unname(info), unname(as.matrix(wrapper$fisher_information)))
	expect_equal(unname(info), unname(spec$fisher_information(wrapper)))

	# A fresh generate_mod() wrapper behaves the same way.
	gm = priv$generate_mod(estimate_only = FALSE)
	expect_true("information_invertible" %in% names(gm))
	expect_equal(unname(spec$information(gm)), unname(as.matrix(gm$fisher_information)))

	expect_equal(spec$extract_start(wrapper), c(as.numeric(wrapper$b), log(as.numeric(wrapper$phi))))
	expect_equal(spec$neg_loglik(wrapper), as.numeric(wrapper$neg_loglik))
})
