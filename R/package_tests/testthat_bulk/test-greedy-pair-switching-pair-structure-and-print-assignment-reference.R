library(testthat)
library(EDI)

# DesignFixedMatchingGreedyPairSwitching$ensure_pair_structure_computed() (binary match
# structure -> match-id vector m, cached, skipped without covariates; the matching-structure
# hook delegates to it) checked against a brute-force minimum-Mahalanobis perfect matching,
# plus DesignSeqOneByOne$print_current_subject_assignment().

mk <- function(n = 8L, seed = 4L, X = NULL) {
	set.seed(seed)
	if (is.null(X)) X <- data.frame(x1 = rnorm(n), x2 = rnorm(n))
	des <- DesignFixedMatchingGreedyPairSwitching$new(response_type = "continuous", n = n, seed = 1L, verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	list(des = des, p = des$.__enclos_env__$private, n = n)
}
perfect_matchings <- function(v) {
	if (length(v) == 0L) return(list(list()))
	a <- v[1]; out <- list()
	for (b in v[-1]) for (r in perfect_matchings(setdiff(v[-1], b))) out[[length(out) + 1L]] <- c(list(c(a, b)), r)
	out
}
key <- function(pairs) paste(sort(vapply(pairs, function(x) paste(sort(x), collapse = "-"), "")), collapse = ",")

test_that("match ids label each pair 1..n/2, every subject exactly once, and follow the pair rows", {
	f <- mk()
	expect_null(f$p$bms)
	f$p$ensure_pair_structure_computed()
	m <- f$p$m
	expect_type(m, "integer")
	expect_length(m, f$n)
	expect_equal(sort(unique(m)), 1:(f$n / 2))
	expect_true(all(table(m) == 2L))
	pairs <- f$p$bms$indicies_pairs
	for (k in seq_len(nrow(pairs))) expect_equal(unname(m[pairs[k, ]]), c(k, k))
})

test_that("the pairs are the minimum total Mahalanobis-distance perfect matching (brute force)", {
	f <- mk()
	f$p$ensure_pair_structure_computed()
	Xm <- as.matrix(f$p$X[seq_len(f$n), , drop = FALSE])
	Si <- solve(cov(Xm))
	D <- outer(seq_len(f$n), seq_len(f$n), Vectorize(function(i, j) { d <- Xm[i, ] - Xm[j, ]; drop(t(d) %*% Si %*% d) }))
	ms <- perfect_matchings(seq_len(f$n))
	total <- vapply(ms, function(m) sum(vapply(m, function(pr) D[pr[1], pr[2]], 0)), 0)
	best <- ms[[which.min(total)]]
	got <- lapply(seq_len(nrow(f$p$bms$indicies_pairs)), function(i) f$p$bms$indicies_pairs[i, ])
	expect_equal(key(got), key(best))
})

test_that("the structure is cached and the matching-structure hook delegates to it", {
	f <- mk()
	f$p$ensure_matching_structure_computed()
	m1 <- f$p$m
	bms1 <- f$p$bms
	expect_false(is.null(bms1))
	f$p$ensure_pair_structure_computed()
	expect_identical(f$p$m, m1)
	expect_identical(f$p$bms, bms1)
})

test_that("with no usable covariates no structure is built", {
	f <- mk(X = data.frame(x = rep(1, 8)))
	unlockBinding("covariate_impute_if_necessary_and_then_create_model_matrix", f$p)
	f$p$covariate_impute_if_necessary_and_then_create_model_matrix <- function() { f$p$X <- matrix(numeric(0), 8, 0); invisible(NULL) }
	expect_null(f$p$ensure_pair_structure_computed())
	expect_null(f$p$bms)
})

test_that("print_current_subject_assignment reports the current subject, arm and design class", {
	des <- DesignSeqOneByOneBernoulli$new(response_type = "continuous", n = 4L, verbose = FALSE)
	des$add_one_subject_to_experiment_and_assign(data.frame(x = 1))
	priv <- des$.__enclos_env__$private
	priv$w[priv$t] <- 1
	expect_output(des$print_current_subject_assignment(), "Subject number 1 is assigned to TREATMENT via design DesignSeqOneByOneBernoulli")
	priv$w[priv$t] <- 0
	expect_output(des$print_current_subject_assignment(), "assigned to CONTROL via design DesignSeqOneByOneBernoulli")
})
