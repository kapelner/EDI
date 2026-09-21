library(testthat)
library(EDI)

# InferenceAllSimpleWilcox private helpers: hl_point_estimate(y, w, row_weights) (unweighted = median of treated-minus-
# control pairwise differences; weighted = first sorted difference whose cumulative pair-weight reaches 1/2, NA when an
# arm has no positive-weight finite rows), compute_fast_randomization_distr(y, permutations, delta, ...) (HL of y + delta*w
# for each permuted assignment column, i.e. y is the control-outcome vector), compute_fast_bootstrap_distr (NULL) and
# get_degrees_of_freedom (NA). References: base R outer / median / cumsum.

mk <- function(n = 30L, seed = 1L) {
	set.seed(seed)
	d <- DesignFixedBernoulli$new(response_type = "continuous", n = n, seed = 1L, verbose = FALSE)
	d$add_all_subjects_to_experiment(data.frame(x = rnorm(n))); d$assign_w_to_all_subjects()
	w <- d$get_w(); y <- rnorm(n) + w; d$add_all_subject_responses(y)
	inf <- InferenceAllSimpleWilcox$new(d, verbose = FALSE)
	list(inf = inf, p = inf$.__enclos_env__$private, y = y, w = w, n = n)
}
f <- mk()
hl <- function(y, w) median(outer(y[w == 1], y[w == 0], "-"))
whl <- function(y, w, rw) {
	it <- which(w == 1 & is.finite(y) & is.finite(rw) & rw > 0); ic <- which(w == 0 & is.finite(y) & is.finite(rw) & rw > 0)
	if (!length(it) || !length(ic)) return(NA_real_)
	dd <- as.numeric(outer(y[it], y[ic], "-")); ww <- as.numeric(outer(rw[it], rw[ic], "*"))
	o <- order(dd); dd <- dd[o]; ww <- ww[o]
	dd[which(cumsum(ww) / sum(ww) >= 0.5)[1]]
}

test_that("unweighted HL point estimate equals the median pairwise difference and the class estimate", {
	expect_equal(f$p$hl_point_estimate(f$y, f$w), hl(f$y, f$w), tolerance = 1e-12)
	expect_equal(f$inf$compute_estimate(), hl(f$y, f$w), tolerance = 1e-12)
})

test_that("weighted HL equals the cumulative-weight quantile definition on random weights", {
	set.seed(4)
	for (i in 1:15) {
		rw <- runif(f$n, 0.2, 3)
		expect_equal(f$p$hl_point_estimate(f$y, f$w, rw), whl(f$y, f$w, rw), tolerance = 1e-12, info = i)
	}
})

test_that("weights that are zero or non-finite exclude rows; an arm with no usable rows gives NA", {
	rw <- rep(1, f$n); rw[c(2, 5, 9)] <- 0; rw[7] <- NA
	expect_equal(f$p$hl_point_estimate(f$y, f$w, rw), whl(f$y, f$w, rw), tolerance = 1e-12)
	expect_true(is.na(f$p$hl_point_estimate(f$y, f$w, ifelse(f$w == 1, 0, 1))))
	expect_true(is.na(f$p$hl_point_estimate(f$y, f$w, ifelse(f$w == 0, 0, 1))))
	y2 <- f$y; y2[f$w == 1] <- NA
	expect_true(is.na(f$p$hl_point_estimate(y2, f$w, rep(1, f$n))))
})

test_that("weighted HL is invariant to a common rescaling of the weights and to row order", {
	set.seed(5); rw <- runif(f$n, 0.3, 2)
	base <- f$p$hl_point_estimate(f$y, f$w, rw)
	expect_equal(f$p$hl_point_estimate(f$y, f$w, 7 * rw), base, tolerance = 1e-12)
	o <- sample(f$n); expect_equal(f$p$hl_point_estimate(f$y[o], f$w[o], rw[o]), base, tolerance = 1e-12)
})

test_that("fast randomization distribution: one HL per permuted column, with delta shifting the treated outcomes", {
	set.seed(3); W <- replicate(8, sample(rep(0:1, f$n / 2)))
	d0 <- f$p$compute_fast_randomization_distr(f$y, list(w_mat = W), 0, FALSE)
	expect_equal(as.numeric(d0), apply(W, 2, function(w) hl(f$y, w)), tolerance = 1e-12)
	d1 <- f$p$compute_fast_randomization_distr(f$y, list(w_mat = W), 0.5, FALSE)
	expect_equal(as.numeric(d1), apply(W, 2, function(w) hl(f$y + 0.5 * w, w)), tolerance = 1e-12)
	expect_length(d1, ncol(W))
	# a permutation identical to the observed assignment reproduces the observed estimate
	expect_equal(as.numeric(f$p$compute_fast_randomization_distr(f$y, list(w_mat = cbind(as.integer(f$w))), 0, FALSE)), f$inf$compute_estimate(), tolerance = 1e-12)
})

test_that("no fast bootstrap distribution is offered and degrees of freedom are NA", {
	expect_null(f$p$compute_fast_bootstrap_distr(10L))
	expect_true(is.na(f$p$get_degrees_of_freedom()))
})
