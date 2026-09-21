library(testthat)
library(EDI)

# InferenceExtLikelihoodTestMemoization on a real InferenceAsympLik host with a synthetic likelihood-test spec: make_warm_fit_null_wrapper
# (warm-start argument passing / state storage) and get_memoized_likelihood_test_eval (per-(type, delta) entry, lazily computed
# components, invalid marking, memoisation so each spec function runs once per delta). Counters record spec calls.

mk <- function() {
	set.seed(1); n <- 30L
	d <- DesignFixedBernoulli$new(response_type = "continuous", n = n, seed = 1L, verbose = FALSE)
	d$add_all_subjects_to_experiment(data.frame(x = rnorm(n))); d$assign_w_to_all_subjects(); d$add_all_subject_responses(rnorm(n))
	inf <- InferenceContinOLS$new(d, verbose = FALSE)
	list(inf = inf, p = inf$.__enclos_env__$private)
}
counter <- new.env(); reset <- function() { counter$fit_null <- 0L; counter$score <- 0L; counter$negll <- 0L; counter$starts <- list() }
reset()
make_spec <- function(accepts_start = TRUE, j = 2L, bad_delta = NULL) {
	fit_null <- if (accepts_start) function(delta, start = NULL) {
		counter$fit_null <- counter$fit_null + 1L; counter$starts[[length(counter$starts) + 1L]] <- list(start)
		if (!is.null(bad_delta) && isTRUE(all.equal(delta, bad_delta))) return(NULL)
		list(params = c(1, delta + 0.5, 3))
	} else function(delta) { counter$fit_null <- counter$fit_null + 1L; list(params = c(1, delta + 0.5, 3)) }
	list(j = j, fit_null = fit_null,
		score = function(fit) { counter$score <- counter$score + 1L; c(0.1, 0.2, 0.3) },
		neg_loglik = function(fit) { counter$negll <- counter$negll + 1L; sum(fit$params) },
		full_fit = list(params = c(1, 2, 3)))
}

test_that("eval entry computes only the requested components and memoises them per (testing type, delta)", {
	reset(); h <- mk(); spec <- make_spec()
	e1 <- h$p$get_memoized_likelihood_test_eval(0.5, "score", spec = spec, include_score = TRUE)
	expect_identical(e1$testing_type, "score"); expect_equal(e1$delta, 0.5); expect_identical(e1$j, 2L)
	expect_false(e1$invalid); expect_equal(e1$null_params, c(1, 1, 3)); expect_equal(e1$score, c(0.1, 0.2, 0.3))
	expect_null(e1$information); expect_null(e1$full_negloglik); expect_null(e1$null_negloglik)
	expect_identical(attr(e1$null_fit, "edi_likelihood_test_delta"), 0.5); expect_identical(attr(e1$null_fit, "edi_likelihood_test_testing_type"), "score")
	e2 <- h$p$get_memoized_likelihood_test_eval(0.5, "score", spec = spec, include_score = TRUE)
	expect_identical(counter$fit_null, 1L); expect_identical(counter$score, 1L)                # no recomputation
	e3 <- h$p$get_memoized_likelihood_test_eval(0.5, "score", spec = spec, include_score = TRUE, include_full_negloglik = TRUE, include_null_negloglik = TRUE)
	expect_equal(e3$full_negloglik, 6); expect_equal(e3$null_negloglik, 5)          # sum(1, 1, 3)
	expect_identical(counter$fit_null, 1L); expect_identical(counter$negll, 2L)
})

test_that("a different delta or testing type is a separate entry with its own null fit", {
	reset(); h <- mk(); spec <- make_spec()
	h$p$get_memoized_likelihood_test_eval(0.5, "score", spec = spec)
	h$p$get_memoized_likelihood_test_eval(0.7, "score", spec = spec)
	h$p$get_memoized_likelihood_test_eval(0.5, "gradient", spec = spec)
	expect_identical(counter$fit_null, 3L)
})

test_that("include_null_fit = FALSE skips the null fit entirely", {
	reset(); h <- mk(); spec <- make_spec()
	e <- h$p$get_memoized_likelihood_test_eval(0.5, "lik_ratio", spec = spec, include_null_fit = FALSE, include_full_negloglik = TRUE)
	expect_identical(counter$fit_null, 0L); expect_null(e$null_fit); expect_equal(e$full_negloglik, 6)
})

test_that("invalid entries: bad j index, failed null fit, or a fit whose parameter j is not finite", {
	reset(); h <- mk()
	e <- h$p$get_memoized_likelihood_test_eval(0, "score", spec = make_spec(j = 0L)); expect_true(e$invalid)
	e2 <- h$p$get_memoized_likelihood_test_eval(0.3, "score", spec = make_spec(bad_delta = 0.3)); expect_true(e2$invalid)
	e3 <- h$p$get_memoized_likelihood_test_eval(0.1, "score", spec = make_spec(j = 9L)); expect_true(e3$invalid)          # params shorter than j
	sp <- make_spec(); sp$fit_null <- function(delta, start = NULL) list(params = c(1, NA, 3))
	expect_true(h$p$get_memoized_likelihood_test_eval(0.2, "score", spec = sp)$invalid)
	expect_null(e2$null_fit)
})

test_that("failing spec callbacks yield NULL / NA components instead of errors", {
	h <- mk(); sp <- make_spec()
	sp$score <- function(fit) stop("score failed"); sp$neg_loglik <- function(fit) stop("no negll")
	e <- h$p$get_memoized_likelihood_test_eval(0.5, "score", spec = sp, include_score = TRUE, include_full_negloglik = TRUE, include_null_negloglik = TRUE)
	expect_null(e$score); expect_true(is.na(e$full_negloglik)); expect_true(is.na(e$null_negloglik))
	sp2 <- make_spec(); sp2$fit_null <- function(delta, start = NULL) stop("fit failed")
	expect_true(h$p$get_memoized_likelihood_test_eval(0.9, "score", spec = sp2)$invalid)
})

test_that("a missing specification is an error naming the class", {
	h <- mk(); unlockBinding("get_likelihood_test_spec", h$p); h$p$get_likelihood_test_spec <- function() NULL
	expect_error(h$p$get_memoized_likelihood_test_eval(0, "score"), "InferenceContinOLS does not expose a likelihood-test specification")
})

test_that("warm fit wrapper: start passed only when the spec's fit_null accepts it and warm starts are enabled; state stored per key", {
	reset(); h <- mk(); spec <- make_spec()
	h$p$null_fit_warm_start_enabled <- TRUE
	w <- h$p$make_warm_fit_null_wrapper(spec, "keyA")
	w(0.1); w(0.2)
	expect_null(counter$starts[[1]][[1]]); expect_equal(counter$starts[[2]][[1]], c(1, 0.6, 3))            # second call starts from the first fit's params
	h$p$null_fit_warm_start_enabled <- FALSE; reset()
	w2 <- h$p$make_warm_fit_null_wrapper(spec, "keyB"); w2(0.1); w2(0.2)
	expect_null(counter$starts[[1]][[1]]); expect_null(counter$starts[[2]][[1]])
	reset(); h$p$null_fit_warm_start_enabled <- TRUE
	w3 <- h$p$make_warm_fit_null_wrapper(make_spec(accepts_start = FALSE), "keyC")
	expect_equal(w3(0.4)$params, c(1, 0.9, 3)); expect_identical(counter$fit_null, 1L)
})
