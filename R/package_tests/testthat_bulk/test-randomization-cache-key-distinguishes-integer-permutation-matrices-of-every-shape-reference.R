library(testthat)
library(EDI)

# Regression for a fixed bug: stable_signature() used to hash only ~258 strided serialised bytes, so for certain
# (n, r) shapes two independent 0/1 INTEGER permutation matrices (even the all-zero and all-one matrices) shared one
# randomization-distribution cache key, and a cached distribution could be reused for the wrong permutations. It now
# hashes the full serialization (xxhash64), so every distinct permutation set gets its own key regardless of shape.

mk <- function() {
	set.seed(1); n <- 20L
	d <- DesignFixedBernoulli$new(response_type = "continuous", n = n, seed = 1L, verbose = FALSE)
	d$add_all_subjects_to_experiment(data.frame(x = rnorm(n))); d$assign_w_to_all_subjects(); d$add_all_subject_responses(rnorm(n))
	InferenceContinOLS$new(d, verbose = FALSE)$.__enclos_env__$private
}
p <- mk()
key_for <- function(w) p$build_randomization_distribution_cache_key(ncol(w), 0, "none", list(w_mat = w, m_mat = NULL))
perm <- function(n, r) { m <- matrix(sample(0:1, n * r, TRUE), n); storage.mode(m) <- "integer"; m }
shapes <- rbind(c(20, 500), c(30, 500), c(30, 2000), c(50, 100), c(100, 100), c(200, 2000), c(500, 500),
                c(20, 100), c(20, 1000), c(50, 500), c(100, 500), c(200, 500), c(500, 100))

test_that("independent random integer permutation sets always get different cache keys, whatever the shape", {
	set.seed(10)
	for (i in seq_len(nrow(shapes))) {
		n <- shapes[i, 1]; r <- shapes[i, 2]
		expect_false(identical(key_for(perm(n, r)), key_for(perm(n, r))), info = paste(n, "x", r))
	}
})

test_that("all-zero, all-one and complement matrices are separated on every shape; equal matrices share a key", {
	set.seed(13)
	for (i in seq_len(nrow(shapes))) {
		n <- shapes[i, 1]; r <- shapes[i, 2]; z <- matrix(0L, n, r); o <- matrix(1L, n, r)
		expect_false(identical(key_for(z), key_for(o)), info = paste(n, "x", r))
		a <- perm(n, r)
		expect_false(identical(key_for(a), key_for(1L - a)), info = paste(n, "x", r))
		expect_identical(key_for(a), key_for(a + 0L), info = paste(n, "x", r))
	}
})

test_that("a single flipped entry anywhere in a large permutation matrix changes the key", {
	set.seed(14); a <- perm(200, 2000)
	for (k in c(1L, 777L, 50000L, 399999L, length(a))) { b <- a; b[k] <- 1L - b[k]; expect_false(identical(key_for(a), key_for(b)), info = as.character(k)) }
})

test_that("a double-typed permutation pair is distinguished too", {
	set.seed(12)
	a <- matrix(as.numeric(sample(0:1, 300 * 100, TRUE)), 300); b <- matrix(as.numeric(sample(0:1, 300 * 100, TRUE)), 300)
	expect_false(identical(key_for(a), key_for(b)))
})
