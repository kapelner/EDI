library(testthat)
library(EDI)

# docs-claims audit, finding docs-claims-d70b0515c (InferenceRandCustom): a C++ source string may take
# (NumericVector y, IntegerVector w, IntegerVector dead) and is then called with the event indicator;
# non-finite draws are dropped whatever na.rm is. (Compiles one tiny standalone Rcpp function, as
# test-inference-rand-custom.R does; nothing in EDI is rebuilt.)

make_surv_custom_design <- function(n = 24L, seed = 7L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$overwrite_all_subject_assignments(rep(c(0, 1), n / 2))
	t <- rexp(n, 1); cens <- rbinom(n, 1, 0.3) == 1
	ys <- ifelse(cens, NA_real_, t)
	des$add_all_subject_responses(ys = ys, y_Ls = ifelse(cens, t, NA_real_), y_Rs = ifelse(cens, Inf, NA_real_))
	des
}

dead_stat_src <- "
double dead_weighted_diff(NumericVector y, IntegerVector w, IntegerVector dead) {
	double st = 0, sc = 0; int nt = 0, nc = 0;
	for (int i = 0; i < y.size(); i++) {
		double v = y[i] * dead[i];
		if (w[i] == 1) { st += v; nt++; } else { sc += v; nc++; }
	}
	return st / nt - sc / nc;
}
"
dead_stat_r <- function(y, w, dead) mean((y * dead)[w == 1]) - mean((y * dead)[w == 0])

test_that("a 3-argument (y, w, dead) C++ source string gets the event indicator and matches the R statistic", {
	skip_if_not_installed("Rcpp")
	des <- make_surv_custom_design()
	inf_r <- InferenceRandCustom$new(des, custom_randomization_statistic_function = dead_stat_r, verbose = FALSE)
	dat <- inf_r$get_analysis_data()
	expect_true(any(dat$dead == 0))
	inf_cpp <- InferenceRandCustom$new(des, custom_randomization_statistic_cpp = dead_stat_src, verbose = FALSE)
	est <- inf_cpp$compute_estimate()
	expect_equal(est, inf_r$compute_estimate(), tolerance = 1e-12)
	# The statistic depends on dead (it differs from the same statistic with dead = 1).
	expect_false(isTRUE(all.equal(est, dead_stat_r(dat$y, dat$w, rep(1, length(dat$y))))))
	set.seed(3)
	perms <- list(w_mat = replicate(49, sample(des$get_w())))
	p_r <- inf_r$compute_rand_two_sided_pval(r = 49, permutations = perms, show_progress = FALSE)
	p_cpp <- inf_cpp$compute_rand_two_sided_pval(r = 49, permutations = perms, show_progress = FALSE)
	expect_true(is.finite(p_cpp))
	expect_equal(p_cpp, p_r, tolerance = 1e-12)
})

test_that("non-finite draws are dropped whether na.rm is TRUE or FALSE", {
	set.seed(11)
	n <- 20L
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$overwrite_all_subject_assignments(rep(c(0, 1), each = n / 2))
	des$add_all_subject_responses(rnorm(n) + rep(c(0, 1), each = n / 2))
	w_obs <- des$get_w()
	# NA whenever subject 1 is treated (about half the permutations; never on the observed data).
	stat <- function(y, w, dead) if (w[1] == 1) NA_real_ else mean(y[w == 1]) - mean(y[w == 0])
	inf <- InferenceRandCustom$new(des, custom_randomization_statistic_function = stat, verbose = FALSE)
	expect_true(is.finite(inf$compute_estimate()))
	set.seed(5)
	perms <- list(w_mat = replicate(49, sample(w_obs)))
	expect_gt(sum(perms$w_mat[1, ] == 1), 5L)
	p_true <- inf$compute_rand_two_sided_pval(r = 49, permutations = perms, na.rm = TRUE, show_progress = FALSE)
	p_false <- inf$compute_rand_two_sided_pval(r = 49, permutations = perms, na.rm = FALSE, show_progress = FALSE)
	expect_true(is.finite(p_true))
	expect_identical(p_false, p_true)
})
