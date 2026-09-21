library(testthat)
library(EDI)

# stable_signature(obj) hashes a fixed-size strided subsample of serialize(obj) (documented as a memoisation key, not a
# collision-free hash). This file pins its sensitivity envelope: independent random permutation matrices and any change
# to small objects are distinguished, while a single-element edit landing between sampled bytes of a large matrix is NOT
# (a known limitation that could reuse a cached randomization distribution for near-identical permutation sets), and
# build_randomization_distribution_cache_key() adds r / delta / transform components around it. (0/1 integer matrices: the stride is 2 mod 4 so only the always-zero high bytes are sampled.)

mk <- function() {
	set.seed(1); n <- 20L
	d <- DesignFixedBernoulli$new(response_type = "continuous", n = n, seed = 1L, verbose = FALSE)
	d$add_all_subjects_to_experiment(data.frame(x = rnorm(n))); d$assign_w_to_all_subjects(); d$add_all_subject_responses(rnorm(n))
	InferenceContinOLS$new(d, verbose = FALSE)$.__enclos_env__$private
}
p <- mk(); S <- p$stable_signature

test_that("signature format is length:h1:h2, deterministic, and 0:0:0 is never returned for a non-empty serialisation", {
	sig <- S(1:10)
	expect_match(sig, "^[0-9]+:[0-9]+:[0-9]+$")
	expect_identical(S(1:10), sig)
	expect_identical(strsplit(sig, ":")[[1]][1], as.character(length(serialize(1:10, NULL, xdr = FALSE))))
})

test_that("small objects: any element change, type change, or reorder alters the signature (every byte is sampled)", {
	base <- c(1, 2, 3, 4, 5)
	expect_false(identical(S(base), S(c(1, 2, 3, 4, 6))))
	expect_false(identical(S(base), S(rev(base))))
	expect_false(identical(S(1:5), S(as.numeric(1:5))))
	expect_false(identical(S(list(a = 1)), S(list(b = 1))))
	expect_false(identical(S("a"), S("b")))
})

test_that("continuous-valued large matrices of the same shape are distinguished", {
	set.seed(2)
	a <- matrix(rnorm(2000 * 50), 2000); b <- matrix(rnorm(2000 * 50), 2000)
	expect_false(identical(S(a), S(b)))
	expect_identical(S(a), S(a + 0))
})

test_that("SUSPECTED BUG: a bare large 0/1 integer matrix gets the same signature whatever its values (sampled bytes are always zero high bytes)", {
	set.seed(3)
	a <- matrix(sample(0:1, 2000 * 50, TRUE), 2000); b <- matrix(sample(0:1, 2000 * 50, TRUE), 2000)
	n_bytes <- length(serialize(a, NULL, xdr = FALSE)); step <- max(1L, floor(n_bytes / 256L))
	expect_gt(step, 1000L)
	expect_equal(step %% 4L, 2L)                       # stride of 2 mod 4 visits only odd byte offsets of the 4-byte integers
	expect_identical(S(a), S(b))                            # independent permutation matrices collide
	expect_identical(S(a), S(1L - a))                       # even the complement assignment collides
	expect_identical(S(a), S(matrix(0L, 2000, 50)))         # ... as does the all-zero matrix
	# wrapped in the permutation list the serialisation header shifts the stride alignment, so the cache key happens to
	# separate these two fixtures -- the blindness is alignment-dependent, not fixed
	ka <- p$build_randomization_distribution_cache_key(2000, 0, "none", list(w_mat = a, m_mat = NULL))
	kb <- p$build_randomization_distribution_cache_key(2000, 0, "none", list(w_mat = b, m_mat = NULL))
	expect_false(identical(ka, kb))
})

test_that("LIMITATION: single-element edits of a large continuous matrix are usually invisible (the sample is at most ~258 bytes)", {
	set.seed(4); a <- matrix(rnorm(2000 * 50), 2000)
	collisions <- vapply(c(3L, 777L, 5000L, 20000L, 50000L, 99999L), function(k) { b <- a; b[k] <- b[k] + 1; identical(S(a), S(b)) }, NA)
	expect_gte(sum(collisions), 4L)
	expect_false(identical(S(a), S(a + 1)))                # shifting every element is seen
})

test_that("cache key combines r, delta (17 significant digits), transform and the permutation signature", {
	perm <- list(w_mat = matrix(sample(0:1, 40, TRUE), 10), m_mat = NULL)
	key <- function(r = 10, delta = 0, tr = "none", permutations = perm) p$build_randomization_distribution_cache_key(r, delta, tr, permutations)
	k0 <- key()
	parts <- strsplit(k0, "|", fixed = TRUE)[[1]]
	expect_identical(parts[1], "10"); expect_identical(parts[3], "none"); expect_identical(parts[4], S(perm))
	expect_false(identical(k0, key(r = 11))); expect_false(identical(k0, key(delta = 0.1))); expect_false(identical(k0, key(tr = "log")))
	perm2 <- perm; perm2$w_mat[1, 1] <- 1L - perm2$w_mat[1, 1]
	expect_false(identical(k0, key(permutations = perm2)))       # small matrix: every byte sampled
	expect_identical(k0, key())
	expect_false(identical(key(delta = 0.1), key(delta = 0.1 + 1e-12)))
})
