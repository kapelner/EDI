library(testthat)
library(EDI)

# Design getters with a mixed exact / right / interval-censored survival response, an ordinal factor response, and
# covariates with missingness: get_y / get_y_L / get_y_R / get_y_original, get_effective_time / get_effective_dead,
# get_response_type(_original), get_ordinal_levels / get_original_ordinal_levels, get_missingness_method,
# get_X_raw vs get_X_imp (imputed value + *_is_missing indicator). References: the input vectors and their definitions.

set.seed(1); n <- 12L
X <- data.frame(x1 = c(rnorm(n - 2L), NA, NA), x2 = rnorm(n))
y <- c(rexp(8) + 1, rep(NA, 4)); yL <- c(rep(NA, 8), 1, 2, 3, 4); yR <- c(rep(NA, 8), Inf, 5, Inf, 6)
mk_surv <- function() {
	d <- DesignFixedBernoulli$new(response_type = "survival", n = n, seed = 1L, verbose = FALSE)
	d$add_all_subjects_to_experiment(X); d$assign_w_to_all_subjects()
	d$add_all_subject_responses(ys = y, y_Ls = yL, y_Rs = yR)
	d
}
des <- mk_surv()

test_that("censored-response getters return the stored y / y_L / y_R with NA for the absent bound", {
	expect_equal(des$get_y(), y); expect_equal(des$get_y_L(), yL); expect_equal(des$get_y_R(), yR)
	expect_equal(des$get_y_original(), y)
	expect_identical(sum(is.na(des$get_y())), 4L)
	expect_true(all(is.na(des$get_y_L()[1:8])) && all(is.na(des$get_y_R()[1:8])))
	expect_true(all(is.infinite(des$get_y_R()[c(9, 11)])))
})

test_that("effective time is y where recorded else the lower bound; effective event indicator is 1 exactly for exact responses", {
	expect_equal(des$get_effective_time(), ifelse(is.na(y), yL, y))
	expect_identical(des$get_effective_dead(), as.integer(!is.na(y)))
	expect_type(des$get_effective_dead(), "integer")
	expect_identical(des$get_effective_dead(), c(rep(1L, 8), rep(0L, 4)))
})

test_that("response type, original response type and missingness method are reported", {
	expect_identical(des$get_response_type(), "survival"); expect_identical(des$get_response_type_original(), "survival")
	expect_identical(des$get_missingness_method(), "impute")
	expect_equal(des$get_prob_T(), 0.5)
})

test_that("raw covariates keep NA; imputed covariates are complete, unchanged where observed, and flagged by an *_is_missing column", {
	raw <- as.data.frame(des$get_X_raw()); imp <- as.data.frame(des$get_X_imp())
	expect_true(anyNA(raw$x1)); expect_equal(raw$x1, X$x1); expect_equal(raw$x2, X$x2)
	expect_false(anyNA(imp))
	expect_equal(imp$x1[1:10], X$x1[1:10]); expect_equal(imp$x2, X$x2)
	expect_true("x1_is_missing" %in% names(imp))
	expect_equal(as.integer(imp$x1_is_missing), c(rep(0L, 10), 1L, 1L))
	expect_true(all(is.finite(imp$x1[11:12])))
	expect_gte(imp$x1[11], min(X$x1, na.rm = TRUE)); expect_lte(imp$x1[11], max(X$x1, na.rm = TRUE))
})

test_that("ordinal response: integer codes in y, level labels preserved, original type kept", {
	set.seed(2)
	o <- DesignFixedBernoulli$new(response_type = "ordinal", n = n, seed = 1L, verbose = FALSE)
	o$add_all_subjects_to_experiment(data.frame(x = rnorm(n))); o$assign_w_to_all_subjects()
	resp <- factor(sample(c("lo", "mid", "hi"), n, TRUE), levels = c("lo", "mid", "hi"), ordered = TRUE)
	o$add_all_subject_responses(resp)
	expect_identical(o$get_ordinal_levels(), c("lo", "mid", "hi")); expect_identical(o$get_original_ordinal_levels(), c("lo", "mid", "hi"))
	expect_identical(as.integer(o$get_y()), as.integer(resp)); expect_identical(as.integer(o$get_y_original()), as.integer(resp))
	expect_identical(o$get_response_type(), "ordinal"); expect_identical(o$get_response_type_original(), "ordinal")
})

test_that("non-censored response types report all-exact effective times and events", {
	set.seed(3)
	c1 <- DesignFixedBernoulli$new(response_type = "continuous", n = n, seed = 1L, verbose = FALSE)
	c1$add_all_subjects_to_experiment(data.frame(x = rnorm(n))); c1$assign_w_to_all_subjects()
	yy <- rnorm(n); c1$add_all_subject_responses(yy)
	expect_equal(c1$get_effective_time(), yy); expect_identical(c1$get_effective_dead(), rep(1L, n))
	expect_true(all(is.na(c1$get_y_L())) || length(c1$get_y_L()) == 0L)
})
