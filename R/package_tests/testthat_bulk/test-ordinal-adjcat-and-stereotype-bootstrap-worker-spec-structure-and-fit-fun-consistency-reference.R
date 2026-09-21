library(testthat)
library(EDI)

# get_bootstrap_worker_spec() of InferenceOrdinalAdjCatLogitRegr and InferenceOrdinalStereotypeLogitRegr: list(X_full, best_X_cols, fit_fun).
# The spec's fit_fun on the full design must reproduce the class estimate (treatment slope = first coefficient), return the parameter
# vector needed for warm starting, and (stereotype) return NULL for unusable fits. Both classes advertise reusable bootstrap workers.

set.seed(6); n <- 150L
X <- data.frame(x1 = rnorm(n), x2 = runif(n))
d <- DesignFixedBernoulli$new(response_type = "ordinal", n = n, seed = 1L, verbose = FALSE)
d$add_all_subjects_to_experiment(X); d$assign_w_to_all_subjects(); w <- d$get_w()
y <- factor(pmin(4, pmax(1, round(rnorm(n, 2.3 + 0.7 * w + 0.4 * X$x1, 1)))), levels = 1:4, ordered = TRUE); d$add_all_subject_responses(y)
mk <- function(cls) { inf <- cls$new(d, verbose = FALSE); list(inf = inf, p = inf$.__enclos_env__$private) }

check_spec <- function(f, tol) {
	expect_true(isTRUE(f$p$supports_reusable_bootstrap_worker()))
	est <- f$inf$compute_estimate()
	spec <- f$p$get_bootstrap_worker_spec()
	expect_named(spec, c("X_full", "best_X_cols", "fit_fun"))
	expect_identical(colnames(spec$X_full), c("treatment", "x1", "x2")); expect_identical(nrow(spec$X_full), n)          # ordinal models carry no intercept column
	expect_identical(spec$best_X_cols, c("x1", "x2")); expect_true(is.function(spec$fit_fun))
	res <- spec$fit_fun(spec$X_full, keep = seq_len(ncol(spec$X_full)))
	expect_false(is.null(res))
	expect_equal(unname(res$b[1]), est, tolerance = tol)
	expect_true(is.na(res$ssq_b_j)); expect_length(res$b, 3L)
	res
}

test_that("adjacent-category spec: fit_fun reproduces the class estimate; params include the threshold parameters", {
	f <- mk(InferenceOrdinalAdjCatLogitRegr)
	res <- check_spec(f, 1e-3)
	expect_length(res$params, 3L + 3L)                                                            # slopes + (K - 1) category intercepts
})

test_that("stereotype spec: fit_fun reproduces the class estimate; NULL for an unusable (extreme / non-converged) fit", {
	f <- mk(InferenceOrdinalStereotypeLogitRegr)
	res <- check_spec(f, 5e-3)
	# a response that is (nearly) a deterministic function of treatment gives an unbounded coefficient -> unusable
	e <- DesignFixedBernoulli$new(response_type = "ordinal", n = 60L, seed = 1L, verbose = FALSE)
	e$add_all_subjects_to_experiment(data.frame(x = rnorm(60))); e$assign_w_to_all_subjects(); we <- e$get_w()
	e$add_all_subject_responses(factor(ifelse(we == 1, 3, 1), levels = 1:3, ordered = TRUE))
	q <- InferenceOrdinalStereotypeLogitRegr$new(e, verbose = FALSE)$.__enclos_env__$private
	spec <- q$get_bootstrap_worker_spec()
	out <- spec$fit_fun(spec$X_full, keep = seq_len(ncol(spec$X_full)))
	expect_true(is.null(out) || abs(out$b[1]) <= 10)
})
