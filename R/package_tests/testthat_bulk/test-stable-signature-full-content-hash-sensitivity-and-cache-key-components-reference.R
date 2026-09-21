library(testthat)
library(EDI)

# stable_signature(obj) = "<serialized byte count>:<xxhash64 of the full serialization>" (memoisation key). Every change
# to the object -- including a single element of a large 0/1 integer matrix, which the former strided-subsample version
# missed -- alters it; build_randomization_distribution_cache_key() adds r / delta / transform components around it.

mk <- function() {
	set.seed(1); n <- 20L
	d <- DesignFixedBernoulli$new(response_type = "continuous", n = n, seed = 1L, verbose = FALSE)
	d$add_all_subjects_to_experiment(data.frame(x = rnorm(n))); d$assign_w_to_all_subjects(); d$add_all_subject_responses(rnorm(n))
	InferenceContinOLS$new(d, verbose = FALSE)$.__enclos_env__$private
}
p <- mk(); S <- p$stable_signature

test_that("signature format is length:hash, deterministic, and '0:0' is never returned for a non-empty serialisation", {
	sig <- S(1:10)
	expect_match(sig, "^[0-9]+:[0-9a-f]+$")
	expect_identical(S(1:10), sig)
	expect_identical(strsplit(sig, ":")[[1]][1], as.character(length(serialize(1:10, NULL, xdr = FALSE))))
	expect_false(identical(S(NULL), "0:0"))
})

test_that("small objects: any element change, type change, or reorder alters the signature", {
	base <- c(1, 2, 3, 4, 5)
	expect_false(identical(S(base), S(c(1, 2, 3, 4, 6))))
	expect_false(identical(S(base), S(rev(base))))
	expect_false(identical(S(1:5), S(as.numeric(1:5))))
	expect_false(identical(S(list(a = 1)), S(list(b = 1))))
	expect_false(identical(S("a"), S("b")))
})

test_that("large matrices: independent draws, complements and single-element edits are all distinguished; equal content matches", {
	set.seed(2)
	a <- matrix(rnorm(2000 * 50), 2000); b <- matrix(rnorm(2000 * 50), 2000)
	expect_false(identical(S(a), S(b))); expect_identical(S(a), S(a + 0))
	set.seed(3)
	ia <- matrix(sample(0:1, 2000 * 50, TRUE), 2000); ib <- matrix(sample(0:1, 2000 * 50, TRUE), 2000)
	expect_false(identical(S(ia), S(ib)))
	expect_false(identical(S(ia), S(1L - ia)))
	expect_false(identical(S(ia), S(matrix(0L, 2000, 50))))
	for (k in c(3L, 777L, 5000L, 20000L, 50000L, 99999L)) {
		b2 <- a; b2[k] <- b2[k] + 1; expect_false(identical(S(a), S(b2)), info = as.character(k))
		i2 <- ia; i2[k] <- 1L - i2[k]; expect_false(identical(S(ia), S(i2)), info = as.character(k))
	}
})

test_that("cache key combines r, delta (17 significant digits), transform and the permutation signature", {
	perm <- list(w_mat = matrix(sample(0:1, 40, TRUE), 10), m_mat = NULL)
	key <- function(r = 10, delta = 0, tr = "none", permutations = perm) p$build_randomization_distribution_cache_key(r, delta, tr, permutations)
	k0 <- key()
	parts <- strsplit(k0, "|", fixed = TRUE)[[1]]
	expect_identical(parts[1], "10"); expect_identical(parts[3], "none"); expect_identical(parts[4], S(perm))
	expect_false(identical(k0, key(r = 11))); expect_false(identical(k0, key(delta = 0.1))); expect_false(identical(k0, key(tr = "log")))
	perm2 <- perm; perm2$w_mat[1, 1] <- 1L - perm2$w_mat[1, 1]
	expect_false(identical(k0, key(permutations = perm2)))
	expect_identical(k0, key())
	expect_false(identical(key(delta = 0.1), key(delta = 0.1 + 1e-12)))
})
