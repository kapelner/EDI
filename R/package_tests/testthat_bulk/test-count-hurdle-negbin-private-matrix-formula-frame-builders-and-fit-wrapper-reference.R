library(testthat)
library(EDI)

# InferenceCountHurdleNegBin private builders: build_component_matrix(formula, selected_colnames, treatment_name),
# build_formula_from_matrix(X, response), build_hurdle_frame(X_cond, X_hurdle) and try_hurdle_negbin_fit(...) (validated
# fit wrapper, success paths), plus hurdle_description().
# References: hand-built matrices and formulas; the fit's treatment coefficient equals the class estimate.

set.seed(1); n <- 60L
X <- data.frame(x1 = rnorm(n), `x 2` = runif(n), check.names = FALSE)
d <- DesignFixedBernoulli$new(response_type = "count", n = n, seed = 1L, verbose = FALSE)
d$add_all_subjects_to_experiment(X); d$assign_w_to_all_subjects()
w <- d$get_w(); y <- rnbinom(n, mu = exp(0.5 + 0.4 * w + 0.3 * X$x1), size = 2); d$add_all_subject_responses(y)
inf <- InferenceCountHurdleNegBin$new(d, verbose = FALSE); p <- inf$.__enclos_env__$private
est <- inf$compute_estimate()

test_that("component matrix is [1, w, covariates] with the treatment column named as requested", {
	Xc <- p$build_component_matrix(~ .)
	expect_identical(dim(Xc), c(n, 4L))
	expect_identical(colnames(Xc)[1:3], c("(Intercept)", "treatment", "x1"))
	expect_equal(unname(Xc[, 1]), rep(1, n)); expect_equal(unname(Xc[, 2]), as.numeric(w))
	expect_equal(unname(Xc[, 3]), X$x1); expect_equal(unname(Xc[, 4]), X$`x 2`)
	Xt <- p$build_component_matrix(~ ., treatment_name = "arm")
	expect_identical(colnames(Xt)[2], "arm")
})

test_that("selected_colnames subsets the covariates (unknown names ignored); none selected gives intercept + treatment only", {
	sub <- p$build_component_matrix(~ ., selected_colnames = "x1")
	expect_identical(colnames(sub), c("(Intercept)", "treatment", "x1"))
	expect_equal(unname(sub[, 3]), X$x1)
	expect_identical(colnames(p$build_component_matrix(~ ., selected_colnames = c("x1", "nope"))), c("(Intercept)", "treatment", "x1"))
	expect_identical(colnames(p$build_component_matrix(~ ., selected_colnames = "nope")), c("(Intercept)", "treatment"))
	base <- p$build_component_matrix(~ ., selected_colnames = character(0))
	expect_identical(colnames(base), c("(Intercept)", "treatment")); expect_equal(unname(base[, 2]), as.numeric(w))
})

test_that("formula builder drops the intercept column name and joins the rest; response can be omitted", {
	Xc <- p$build_component_matrix(~ .)
	f <- p$build_formula_from_matrix(Xc)
	expect_s3_class(f, "formula"); expect_identical(all.vars(f)[1], "y")
	expect_identical(attr(terms(f), "term.labels"), c("treatment", "x1", "`x 2`"))
	expect_identical(deparse(p$build_formula_from_matrix(cbind("(Intercept)" = rep(1, 3)))), "y ~ 1")
	expect_identical(deparse(p$build_formula_from_matrix(Xc, response = "z"))[1], "z ~ treatment + x1 + `x 2`")
	g <- p$build_formula_from_matrix(Xc, response = NULL)
	expect_identical(length(g), 2L)                                                     # one-sided
	expect_identical(attr(terms(g), "term.labels"), c("treatment", "x1", "`x 2`"))
})

test_that("hurdle frame holds y, w, and the covariates of both components with syntactic names (no duplicates)", {
	Xc <- p$build_component_matrix(~ .)
	fr <- p$build_hurdle_frame(Xc, Xc)
	expect_identical(nrow(fr), n)
	expect_identical(names(fr)[1:2], c("y", "w")); expect_equal(fr$y, as.numeric(y)); expect_equal(fr$w, as.numeric(w))
	expect_identical(names(fr), make.names(names(fr), unique = TRUE))
	expect_identical(sum(names(fr) == "x1"), 1L)                                       # shared covariate appears once
	Xh <- Xc[, c(1, 2, 4), drop = FALSE]                                               # hurdle-only covariate is appended
	fr2 <- p$build_hurdle_frame(Xc[, 1:3], Xh)
	expect_identical(ncol(fr2), 4L)
	only_int <- p$build_hurdle_frame(Xc[, 1:2], Xc[, 1:2]); expect_identical(names(only_int), c("y", "w"))
})

test_that("description and fit wrapper: successful full and estimate-only fits return validated lists", {
	expect_identical(p$hurdle_description(), "Hurdle Negative Binomial")
	Xc <- p$build_component_matrix(~ .)
	full <- p$try_hurdle_negbin_fit(Xc, Xc, 2L, estimate_only = FALSE)
	expect_named(full, c("mod", "b", "ssq", "j", "X", "X_hurdle"))
	expect_length(full$b, ncol(Xc)); expect_true(all(is.finite(full$b)))
	expect_equal(full$b[2], est, tolerance = 1e-5)
	expect_true(is.finite(full$ssq) && full$ssq > 0); expect_identical(full$j, 2L)
	only <- p$try_hurdle_negbin_fit(Xc, Xc, 2L, estimate_only = TRUE)
	expect_true(is.na(only$ssq)); expect_equal(only$b[2], est, tolerance = 1e-5)
})
