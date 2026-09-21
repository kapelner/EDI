library(testthat)
library(EDI)

# Characterisation of a suspected bug: build_randomization_distribution_cache_key() embeds stable_signature() of the
# permutation list, and stable_signature() only samples ~258 serialised bytes at a fixed stride. For 0/1 INTEGER
# permutation matrices the payload bytes that carry information are 4-byte aligned; when the stride (a function of the
# object's serialised size only) never lands on the low byte, the signature ignores the matrix values entirely. Hence for
# certain (n, r) shapes two independent random permutation sets share one cache key (identical r / delta / transform), and a
# cached randomization distribution could be reused for the wrong permutations. Which shapes are blind depends only on the
# shape, so the table below is deterministic.

mk <- function() {
	set.seed(1); n <- 20L
	d <- DesignFixedBernoulli$new(response_type = "continuous", n = n, seed = 1L, verbose = FALSE)
	d$add_all_subjects_to_experiment(data.frame(x = rnorm(n))); d$assign_w_to_all_subjects(); d$add_all_subject_responses(rnorm(n))
	InferenceContinOLS$new(d, verbose = FALSE)$.__enclos_env__$private
}
p <- mk()
key_for <- function(w) p$build_randomization_distribution_cache_key(ncol(w), 0, "none", list(w_mat = w, m_mat = NULL))
perm <- function(n, r) { m <- matrix(sample(0:1, n * r, TRUE), n); storage.mode(m) <- "integer"; m }
blind <- rbind(c(20, 500), c(30, 500), c(30, 2000), c(50, 100), c(100, 100), c(200, 2000), c(500, 500))
seen <- rbind(c(20, 100), c(20, 1000), c(50, 500), c(100, 500), c(200, 500), c(500, 100))

test_that("blind shapes: two independent random integer permutation sets get identical cache keys", {
	set.seed(10)
	for (i in seq_len(nrow(blind))) {
		n <- blind[i, 1]; r <- blind[i, 2]
		expect_identical(key_for(perm(n, r)), key_for(perm(n, r)), info = paste(n, "x", r))
	}
})

test_that("blindness depends on the serialised size only: even the all-zero and all-one matrices collide there", {
	for (i in seq_len(nrow(blind))) {
		n <- blind[i, 1]; r <- blind[i, 2]; z <- matrix(0L, n, r); o <- matrix(1L, n, r)
		expect_identical(key_for(z), key_for(o), info = paste(n, "x", r))
	}
})

test_that("other shapes are distinguished (so the collision is shape-dependent, not universal)", {
	set.seed(11)
	for (i in seq_len(nrow(seen))) {
		n <- seen[i, 1]; r <- seen[i, 2]
		expect_false(identical(key_for(perm(n, r)), key_for(perm(n, r))), info = paste(n, "x", r))
	}
})

test_that("a double-typed 300 x 100 permutation pair is distinguished (one observed shape; doubles carry information in more sampled bytes)", {
	set.seed(12)
	a <- matrix(as.numeric(sample(0:1, 300 * 100, TRUE)), 300); b <- matrix(as.numeric(sample(0:1, 300 * 100, TRUE)), 300)
	expect_false(identical(key_for(a), key_for(b)))
})
