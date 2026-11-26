library(testthat)
library(EDI)

# Found while working on v1.1.0-TODO-174: the likelihood-test spec hooks of the
# zero-augmented Poisson classes read optional fit fields with `$`, which partially
# matches list names. generate_mod()'s wrapper list carries `information_invertible` but
# no `information`, so `fit$information` returned TRUE and information() handed
# boundary_information() a 1 x 1 TRUE instead of the Fisher information. The hooks now
# look fields up by exact name.

zas_design = local({
	cache = NULL
	function() {
		if (!is.null(cache)) return(cache)
		set.seed(20261126)
		n = 120L
		X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
		y = rpois(n, exp(0.5 + 0.4 * X$x1))
		y[sample.int(n, 25L)] = 0L
		d = DesignFixedBernoulli$new(n = n, response_type = "count", verbose = FALSE)
		d$add_all_subjects_to_experiment(X)
		d$assign_w_to_all_subjects()
		d$add_all_subject_responses(y)
		cache <<- d
		d
	}
})

for (cn in c("InferenceCountHurdlePoisson", "InferenceCountZeroInflatedPoisson")) {
	test_that(paste(cn, "spec hooks read the generate_mod() wrapper by exact field name"), {
		inf = suppressWarnings(get(cn, envir = asNamespace("EDI"))$new(zas_design(), verbose = FALSE))
		priv = inf$.__enclos_env__$private
		spec = priv$get_likelihood_test_spec()
		expect_false(is.null(spec), info = cn)
		wrapper = priv$generate_mod(estimate_only = FALSE)
		# The trap: no `information` element, but a name it is a prefix of.
		expect_null(wrapper[["information"]], info = cn)
		expect_true("information_invertible" %in% names(wrapper), info = cn)

		p = length(wrapper$params)
		info = spec$information(wrapper)
		expect_true(is.matrix(info) && is.numeric(info), info = cn)
		expect_identical(dim(info), c(p, p), info = cn)
		expect_equal(unname(info), unname(as.matrix(wrapper$fisher_information)), info = cn)
		# Same answer as on the kernel fit the spec carries.
		expect_equal(unname(info), unname(spec$information(spec$full_fit)), info = cn)

		expect_equal(spec$extract_start(wrapper), as.numeric(wrapper$params), info = cn)
		nll = spec$neg_loglik(wrapper)
		expect_length(nll, 1L)
		expect_equal(nll, as.numeric(spec$neg_loglik(spec$full_fit)), info = cn)
	})
}
