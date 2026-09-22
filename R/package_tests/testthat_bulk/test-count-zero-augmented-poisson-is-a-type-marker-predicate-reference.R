library(testthat)
library(EDI)

# inference_count_zero_augmented_poisson_abstract.R's InferenceCountZeroAugmentedPoissonAbstract
# declares a private is_a_count_zero_augmented_poisson() type-marker predicate (always TRUE),
# with zero callers anywhere in the source (confirmed via repo-wide grep) -- same purely
# declarative-contract pattern as the is_a_glmm_family/is_a_kk_*_glmm/is_a_kk_ordinal_clmm
# markers covered separately, and had zero test references despite both concrete leaf classes
# (InferenceCountHurdlePoisson, InferenceCountZeroInflatedPoisson) being otherwise well-tested
# via their public behavior. Not to be confused with fast_zero_one_inflated_beta_cpp (a
# different model family, zero-one-inflated BETA regression, avoided elsewhere this session for
# an intermittent crash) -- this is the zero-augmented-count (hurdle/zero-inflated Poisson)
# family, unrelated machinery.

make_hurdle_fixture = function(cls_name, seed = 1L, n = 30L) {
	set.seed(seed)
	des = DesignSeqOneByOneBernoulli$new(n = n, response_type = "count", verbose = FALSE)
	X = data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) {
		w_i = des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
		mu_i = exp(0.5 + 0.5 * w_i)
		y_i = if (stats::runif(1) > 0.3) stats::rpois(1, mu_i) else 0L
		des$add_one_subject_response(i, y_i)
	}
	get(cls_name, envir = asNamespace("EDI"))$new(des, verbose = FALSE)
}

test_that("InferenceCountHurdlePoisson's is_a_count_zero_augmented_poisson() exists, is callable, and returns TRUE", {
	inf = make_hurdle_fixture("InferenceCountHurdlePoisson", seed = 1L)
	priv = inf$.__enclos_env__$private
	expect_true(is.function(priv$is_a_count_zero_augmented_poisson))
	expect_identical(priv$is_a_count_zero_augmented_poisson(), TRUE)
})

test_that("InferenceCountZeroInflatedPoisson's is_a_count_zero_augmented_poisson() exists, is callable, and returns TRUE", {
	inf = make_hurdle_fixture("InferenceCountZeroInflatedPoisson", seed = 2L)
	priv = inf$.__enclos_env__$private
	expect_true(is.function(priv$is_a_count_zero_augmented_poisson))
	expect_identical(priv$is_a_count_zero_augmented_poisson(), TRUE)
})
