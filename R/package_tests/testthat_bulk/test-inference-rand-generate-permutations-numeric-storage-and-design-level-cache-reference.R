library(testthat)
library(EDI)

# InferenceAllRand private generate_permutations(r): draws r assignment vectors from a duplicate of the design, stores
# them as a numeric n x r matrix inside list(w_mat, m_mat = NULL), and caches per (r, design signature) on the DESIGN's
# private env so every inference object on that design shares them; the numeric storage is what keeps the cache-key
# signature of the permutation matrix informative (see the collision characterisation for integer matrices).

mk <- function(seed = 1L, n = 24L) {
	set.seed(seed)
	d <- DesignFixedBernoulli$new(response_type = "continuous", n = n, seed = seed, verbose = FALSE)
	d$add_all_subjects_to_experiment(data.frame(x = rnorm(n))); d$assign_w_to_all_subjects(); d$add_all_subject_responses(rnorm(n))
	list(des = d, inf = InferenceContinOLS$new(d, verbose = FALSE), n = n)
}
f <- mk()
pr <- function(x, r) x$inf$.__enclos_env__$private$generate_permutations(r)

test_that("shape, storage mode, and assignment values", {
	perms <- pr(f, 40L)
	expect_named(perms, c("w_mat", "m_mat"))
	expect_null(perms$m_mat)
	expect_identical(dim(perms$w_mat), c(f$n, 40L))
	expect_identical(storage.mode(perms$w_mat), "double")
	expect_true(all(perms$w_mat %in% c(0, 1)))
})

test_that("second call with the same r returns the cached object unchanged (no redraw)", {
	set.seed(1); a <- pr(f, 30L); set.seed(999); b <- pr(f, 30L)
	expect_identical(a, b)
	expect_true(any(a$w_mat != pr(f, 31L)$w_mat[, 1:30]))            # a different r is a separate draw
})

test_that("the cache lives on the design: other inference objects on the same design see the same permutations; another design does not", {
	other_inf <- InferenceContinOLS$new(f$des, verbose = FALSE)
	expect_identical(pr(f, 17L), other_inf$.__enclos_env__$private$generate_permutations(17L))
	g <- mk(seed = 2L)
	expect_false(identical(pr(f, 17L)$w_mat, pr(g, 17L)$w_mat))
	expect_true(any(grepl("^17\\|", names(f$des$.__enclos_env__$private$permutations_cache))))
})

test_that("invalid r is rejected by the count assertion", {
	expect_error(pr(f, 0L)); expect_error(pr(f, -3)); expect_error(pr(f, 2.5))
})

test_that("Bernoulli(0.5) permutations have an overall mean near one half", {
	perms <- pr(mk(seed = 5L, n = 60L), 400L)
	expect_lt(abs(mean(perms$w_mat) - 0.5), 0.03)
})
