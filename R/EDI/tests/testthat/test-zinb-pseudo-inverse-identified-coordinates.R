library(testthat)
library(EDI)

# PROPOSED companion to cpp patch 07 (ZINB pseudo-inverse, TODO-4 ZINB note) together with
# companion B07-zinb-safe-vcov-subblock.patch. Copy to R/EDI/tests/testthat/ after the patched
# kernel is built. The kernel tag emitted by patch 07 is covariance_type ==
# "pseudo_inverse_identified_coordinates"; the probe skips (or, with EDI_REQUIRE_CPP_PATCHES=true,
# fails) when it is absent. NOT executed against a patched build by the author: the numerical
# expectations (count block equals pscl; duplicated zero-inflation columns are NaN) follow the
# patch text and are the first thing to check when the patch is built.

skip_unless_patched = function(applied, msg) {
	if (isTRUE(applied)) return(invisible(TRUE))
	if (identical(Sys.getenv("EDI_REQUIRE_CPP_PATCHES"), "true")) testthat::fail(msg) else testthat::skip(msg)
}

zinb_dup_zi_fixture = function(n = 150L, seed = 7L) {
	set.seed(seed)
	w = rep(c(0, 1), length.out = n); x = rnorm(n)
	y = rnbinom(n, mu = exp(0.5 + 0.3 * w + 0.2 * x), size = 2)
	y[runif(n) < plogis(-1 + 0.3 * w)] = 0
	list(w = w, x = x, y = as.numeric(y))
}

test_that("duplicated zero-inflation column: count + dispersion SEs equal pscl, duplicated zi coordinates are NaN", {
	skip_on_cran()
	skip_if_not_installed("pscl")
	d = zinb_dup_zi_fixture()
	X = cbind(1, d$w, d$x)
	Xzi_dup = cbind(1, d$w, d$w)                       # exactly collinear zero-inflation columns
	fit = suppressWarnings(EDI:::fast_zinb_cpp(X, Xzi_dup, d$y, estimate_only = FALSE))
	skip_unless_patched(!is.null(fit$covariance_type) && identical(fit$covariance_type, "pseudo_inverse_identified_coordinates"),
		"ZINB pseudo-inverse patch (07) not applied")
	expect_false(fit$information_invertible)
	V = fit$vcov
	p = ncol(X); pz = ncol(Xzi_dup)
	count = seq_len(p); theta = p + pz + 1L; zi_dup = p + c(2L, 3L)
	expect_true(all(is.finite(V[c(count, theta), c(count, theta)])))
	expect_true(all(is.nan(V[zi_dup, ])))
	ref = suppressWarnings(pscl::zeroinfl(y ~ w + x | w, data = data.frame(y = d$y, w = d$w, x = d$x), dist = "negbin"))
	se_ref = summary(ref)$coefficients$count[seq_len(p), 2]
	expect_equal(sqrt(diag(V)[count]), unname(se_ref), tolerance = 0.05)
})

test_that("duplicated COUNT column keeps NaN rows for the aliased pair and the class SE stays non-estimable", {
	skip_on_cran()
	d = zinb_dup_zi_fixture()
	X = cbind(1, d$w, d$x, d$x)
	fit = suppressWarnings(EDI:::fast_zinb_cpp(X, cbind(1, d$w), d$y, estimate_only = FALSE))
	skip_unless_patched(identical(fit$covariance_type, "pseudo_inverse_identified_coordinates"),
		"ZINB pseudo-inverse patch (07) not applied")
	expect_false(fit$information_invertible)
	expect_true(all(is.nan(fit$vcov[3:4, ])))
	expect_true(all(is.nan(fit$vcov[, 3:4])))
})

test_that("safe_zero_augmented_vcov_se() is unchanged for kernels that emit no covariance_type tag", {
	set.seed(1)
	n = 40L
	des = DesignFixedBernoulli$new(n = n, response_type = "count", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(row.names = seq_len(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(as.integer(rpois(n, 2)))
	inf = InferenceCountZeroInflatedNegBin$new(des, verbose = FALSE)
	priv = inf$.__enclos_env__$private
	skip_if(!grepl("pseudo_inverse_identified_coordinates", paste(deparse(priv$safe_zero_augmented_vcov_se), collapse = " ")),
		"companion B07 (R sub-block change) is not applied")
	# a fully NaN vcov without the tag must still give NA (bit-identical legacy behavior)
	fit = list(vcov = matrix(NaN, 5, 5), params = rep(0, 5), coefficients = list(cond = c(0, 0)))
	expect_true(is.na(priv$safe_zero_augmented_vcov_se(fit, 2L)))
	# a tagged pseudo-inverse with a finite count(+theta) block and NaN zero-inflation rows gives a finite SE
	V = diag(5); V[3:4, ] = NaN; V[, 3:4] = NaN; V[2, 2] = 0.04
	fit_tag = list(vcov = V, params = c(0.3, 0.2, 0, 0, 0.5), coefficients = list(cond = c(0.3, 0.2)),
		covariance_type = "pseudo_inverse_identified_coordinates")
	expect_equal(priv$safe_zero_augmented_vcov_se(fit_tag, 2L), 0.2, tolerance = 1e-12)
})
