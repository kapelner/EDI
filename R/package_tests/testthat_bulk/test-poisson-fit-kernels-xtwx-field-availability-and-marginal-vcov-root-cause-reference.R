library(testthat)
library(EDI)

# Root-cause characterisation of the suspected InferenceCountPoisson marginal-SE gap (see the marginal-estimand test): generate_mod() stores
# vcov = solve(fit$XtWX), but the full-inference kernel fast_poisson_regression_with_var_cpp() returns NO `XtWX` element (it exposes
# fisher_information / observed_information / hessian instead), whereas fast_poisson_regression_cpp() does return XtWX. The stored vcov is
# therefore NULL on the full-fit path and the delta-method SE is unavailable. These tests pin the field sets and the consequence so a fix
# (using fisher_information) shows up as an intentional failure here.

set.seed(1); n <- 60L
X <- cbind(1, rbinom(n, 1, 0.5), rnorm(n)); y <- rpois(n, exp(0.2 + 0.3 * X[, 2]))
K <- function(nm) get(nm, envir = asNamespace("EDI"))

test_that("estimate-only style kernel exposes XtWX; the with-var kernel does not but exposes information matrices", {
	a <- K("fast_poisson_regression_cpp")(X, y)
	expect_true("XtWX" %in% names(a)); expect_true(all(c("b", "mu", "fisher_information") %in% names(a)))
	v <- K("fast_poisson_regression_with_var_cpp")(X, y, j = 2L)
	expect_false("XtWX" %in% names(v))
	expect_true(all(c("b", "mu", "ssq_b_j", "fisher_information", "observed_information", "hessian") %in% names(v)))
})

test_that("the information matrices that are returned are usable covariance bases (inverse Fisher information matches glm's vcov)", {
	ref <- glm(y ~ X[, -1], family = poisson)
	v <- K("fast_poisson_regression_with_var_cpp")(X, y, j = 2L)
	expect_equal(unname(solve(v$fisher_information)), unname(vcov(ref)), tolerance = 1e-4)
	expect_equal(v$ssq_b_j, unname(vcov(ref)[2, 2]), tolerance = 1e-4)
	a <- K("fast_poisson_regression_cpp")(X, y)
	expect_equal(unname(solve(a$XtWX)), unname(vcov(ref)), tolerance = 1e-4)
})

test_that("consequence: on the default full-fit path the class caches a fit without vcov, so the marginal-estimand SE is unavailable", {
	set.seed(3); nn <- 120L
	d <- DesignFixedBernoulli$new(response_type = "count", n = nn, seed = 1L, verbose = FALSE)
	d$add_all_subjects_to_experiment(data.frame(x1 = rnorm(nn), x2 = runif(nn))); d$assign_w_to_all_subjects()
	d$add_all_subject_responses(rpois(nn, exp(0.2 + 0.4 * d$get_w())))
	inf <- InferenceCountPoisson$new(d, verbose = FALSE); inf$set_estimand("marginal_mean_diff"); inf$compute_estimate()
	p <- inf$.__enclos_env__$private
	expect_null(p$cached_mod$vcov)
	expect_true(is.na(p$get_standard_error())); expect_true(isTRUE(inf$is_nonestimable("se")))
})
