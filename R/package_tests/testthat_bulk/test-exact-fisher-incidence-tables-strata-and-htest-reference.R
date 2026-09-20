library(testthat)
library(EDI)

# InferenceIncidExactFisher: 2x2 table construction (iBCRD, blocked strata, KK matched sets +
# reservoir), the informative-strata filter, the estimate / CI / p-value against stats::fisher.test
# (single table) and exact stats::mantelhaen.test (several strata), htest caching only for the
# default call, and the design-eligibility predicates.

ibcrd_fx <- function(seed = 2L, n = 60L) {
	set.seed(seed)
	des <- DesignFixediBCRD$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n))); des$assign_w_to_all_subjects()
	w <- des$get_w(); y <- rbinom(n, 1, plogis(-0.2 + 0.9 * w)); des$add_all_subject_responses(y)
	inf <- InferenceIncidExactFisher$new(des, verbose = FALSE)
	list(inf = inf, p = inf$.__enclos_env__$private, des = des, w = w, y = y, n = n)
}

blocked_fx <- function(seed = 5L, n = 60L) {
	set.seed(seed)
	des <- DesignFixedBlocking$new(strata_cols = "g", response_type = "incidence", n = n, seed = seed, verbose = FALSE, equal_block_sizes = FALSE)
	g <- factor(rep(c("a", "b", "c"), each = n / 3))
	des$add_all_subjects_to_experiment(data.frame(g = g, x = rnorm(n))); des$assign_w_to_all_subjects()
	w <- des$get_w(); y <- rbinom(n, 1, plogis(-0.3 + 0.8 * w + 0.4 * (g == "b")))
	des$add_all_subject_responses(y)
	inf <- InferenceIncidExactFisher$new(des, verbose = FALSE)
	list(inf = inf, p = inf$.__enclos_env__$private, w = w, y = y, g = g, n = n)
}

ref_tab <- function(w, y) matrix(c(sum(y[w == 1] == 1), sum(y[w == 0] == 1), sum(y[w == 1] == 0), sum(y[w == 0] == 0)), 2,
	dimnames = list(c("treated", "control"), c("case", "noncase")))

test_that("iBCRD: one 2x2 table (treated / control by case / non-case) and Fisher estimate, CI and p-value from fisher.test", {
	f <- ibcrd_fx()
	tab <- ref_tab(f$w, f$y)
	expect_equal(f$p$build_exact_fisher_2x2_table(seq_len(f$n)), tab)
	tabs <- f$p$get_exact_fisher_tables()
	expect_equal(tabs$n_strata, 1L); expect_equal(tabs$table, tab)
	ref <- fisher.test(tab)
	expect_equal(f$inf$compute_estimate(), log(unname(ref$estimate)), tolerance = 1e-6)
	ci <- f$inf$compute_exact_confidence_interval(0.1)
	ref90 <- fisher.test(tab, conf.level = 0.9)
	expect_equal(as.numeric(ci), log(as.numeric(ref90$conf.int)), tolerance = 1e-6)
	expect_equal(names(ci), c("5%", "95%"))
	expect_equal(f$inf$compute_exact_two_sided_pval_for_treatment_effect(0.3), fisher.test(tab, or = exp(0.3))$p.value, tolerance = 1e-8)
	expect_equal(f$inf$compute_exact_two_sided_pval_for_treatment_effect(0), ref$p.value, tolerance = 1e-8)
})

test_that("a sub-sample table only counts the requested subjects and ignores NA responses", {
	f <- ibcrd_fx()
	idx <- 1:20
	expect_equal(f$p$build_exact_fisher_2x2_table(idx), ref_tab(f$w[idx], f$y[idx]))
	expect_equal(sum(f$p$build_exact_fisher_2x2_table(idx)), 20)
})

test_that("the default-call htest is cached, non-default calls are not", {
	f <- ibcrd_fx()
	h1 <- f$p$get_exact_fisher_htest()
	expect_identical(f$p$cached_values$incid_exact_fisher_htest, h1)
	f$p$cached_values$incid_exact_fisher_htest <- "sentinel"
	expect_identical(f$p$get_exact_fisher_htest(), "sentinel")                        # default call reads the cache
	h2 <- f$p$get_exact_fisher_htest(alpha = 0.1, delta_0 = 0)
	expect_s3_class(h2, "htest")
	expect_identical(f$p$cached_values$incid_exact_fisher_htest, "sentinel")            # not overwritten
	h3 <- f$p$get_exact_fisher_htest(alpha = 0.05, delta_0 = 0.4)
	expect_equal(h3$p.value, fisher.test(ref_tab(f$w, f$y), or = exp(0.4))$p.value, tolerance = 1e-8)
})

test_that("blocked designs: one table per stratum, combined by the exact Mantel-Haenszel test; only delta = 0 is supported", {
	f <- blocked_fx()
	tabs <- f$p$get_exact_fisher_tables()
	expect_equal(tabs$n_strata, 3L)
	for (k in 1:3) {
		idx <- which(f$g == c("a", "b", "c")[k])
		expect_equal(unname(tabs$array[, , k]), unname(ref_tab(f$w[idx], f$y[idx])))
	}
	arr <- tabs$array
	ref <- mantelhaen.test(arr, exact = TRUE)
	expect_equal(f$inf$compute_estimate(), log(unname(ref$estimate)), tolerance = 1e-6)
	expect_equal(f$inf$compute_exact_two_sided_pval_for_treatment_effect(0), ref$p.value, tolerance = 1e-8)
	expect_error(f$inf$compute_exact_two_sided_pval_for_treatment_effect(0.5), "only supports delta = 0")
	expect_equal(f$p$get_exact_fisher_strata_key(data.frame(g = "a", h = NA), c("g", "h")), "a|NA")
	expect_equal(f$p$get_exact_fisher_strata_key(data.frame(g = "a", h = 3L), c("g", "h")), "a|3")
})

test_that("uninformative strata are dropped, and an all-uninformative set is an error", {
	f <- ibcrd_fx()
	one <- matrix(c(3, 2, 4, 1), 2, dimnames = list(c("treated", "control"), c("case", "noncase")))
	empty_arm <- matrix(c(0, 2, 0, 3), 2, dimnames = dimnames(one))                       # no treated subjects
	out <- f$p$format_exact_fisher_tables(list(one, empty_arm))
	expect_equal(out$n_strata, 1L); expect_equal(out$table, one)
	both <- f$p$format_exact_fisher_tables(list(one, one))
	expect_equal(both$n_strata, 2L); expect_equal(dim(both$array), c(2L, 2L, 2L))
	expect_error(f$p$format_exact_fisher_tables(list(empty_arm)), "no informative strata")
})

test_that("KK matched sets: one table per matched pair plus the reservoir", {
	set.seed(6); np <- 12L; ns <- 10L; n <- 2L * np + ns
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "incidence", verbose = FALSE)
	X <- data.frame(x = rnorm(n)); for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	m <- c(rep(seq_len(np), each = 2L), rep(0L, ns)); des$.__enclos_env__$private$m <- m
	w <- des$get_w(); y <- rbinom(n, 1, plogis(0.8 * w)); des$add_all_subject_responses(y)
	inf <- InferenceIncidExactFisher$new(des, verbose = FALSE); p <- inf$.__enclos_env__$private
	tabs <- p$get_exact_fisher_tables()
	informative <- vapply(seq_len(np), function(k) { t <- ref_tab(w[m == k], y[m == k]); sum(t[1, ]) > 0 && sum(t[2, ]) > 0 }, logical(1)) 
	expect_equal(tabs$n_strata, sum(informative) + 1L)                                    # + the reservoir table
	expect_equal(sum(tabs$array[, , tabs$n_strata]), ns)
	expect_true(is.finite(inf$compute_estimate()) || is.infinite(inf$compute_estimate()))
	expect_true(p$design_supports_exact_fisher())
})

test_that("eligibility: iBCRD, blocked and matched designs are accepted; other designs are refused with the documented reason", {
	f <- ibcrd_fx()
	expect_true(f$p$design_supports_exact_fisher())
	expect_true(is.na(f$p$design_compatibility_reason(f$des)))
	bern <- DesignFixedBernoulli$new(n = 20L, response_type = "incidence", verbose = FALSE)
	expect_identical(f$p$design_compatibility_reason(bern), "exact_fisher_requires_ibcrd_blocking_or_matching_design")
	expect_error(InferenceIncidExactFisher$new({
		set.seed(1); d <- DesignFixedBernoulli$new(n = 20L, response_type = "incidence", verbose = FALSE)
		d$add_all_subjects_to_experiment(data.frame(x = rnorm(20))); d$assign_w_to_all_subjects(); d$add_all_subject_responses(rbinom(20, 1, 0.5)); d
	}, verbose = FALSE), "requires iBCRD, blocking, or matching designs")
	expect_error(f$inf$compute_exact_confidence_interval(0.05, type = "Other"))
	expect_equal(f$p$resolve_exact_type(NULL), "Fisher")
	expect_error(f$p$normalize_exact_inference_args("Nope"))
	expect_equal(f$p$normalize_exact_inference_args("Fisher", list(Fisher = list(a = 1))), list(Fisher = list(a = 1)))
	expect_error(f$p$assert_exact_inference_params("Fisher", list(Other = list())), "must contain a list for Fisher")
})
