library(testthat)
library(EDI)

# get_r6_init_fn(r6gen): walks an R6 GENERATOR's own inheritance chain (get_inherit()) upward, returning the nearest defined initialize() method (the
# generator's own if it has one, else the first ancestor's), NULL if no class in the chain defines one. add_bounded_response_to_design(des, t, bounds):
# converts an NA field of a dead_to_response_bounds()-shaped list to a real NULL before forwarding to add_one_subject_response(t, y, y_L, y_R), so an exact
# observation (y set, y_L/y_R NA) and a right-censored one (y NA, y_L/y_R set) each populate only their own fields on the design.

ns <- asNamespace("EDI")
init_fn <- get("get_r6_init_fn", envir = ns)
add_resp <- get("add_bounded_response_to_design", envir = ns)

test_that("get_r6_init_fn returns the generator's own initialize() when it defines one", {
	expect_identical(init_fn(InferenceContinOLS), InferenceContinOLS$public_methods$initialize)
	expect_identical(init_fn(DesignFixedBernoulli), DesignFixedBernoulli$public_methods$initialize)
})

test_that("get_r6_init_fn walks up to the nearest ancestor that defines initialize() when the leaf/mid classes don't", {
	Base <- R6::R6Class("EDITestBase", public = list(initialize = function(x) invisible(x)))
	Mid <- R6::R6Class("EDITestMid", inherit = Base)
	Leaf <- R6::R6Class("EDITestLeaf", inherit = Mid)
	expect_identical(init_fn(Leaf), Base$public_methods$initialize)
	expect_identical(init_fn(Mid), Base$public_methods$initialize)
	Override <- R6::R6Class("EDITestOverride", inherit = Base, public = list(initialize = function(y) invisible(y)))
	expect_identical(init_fn(Override), Override$public_methods$initialize)
	expect_false(identical(init_fn(Override), Base$public_methods$initialize))
})

test_that("get_r6_init_fn returns NULL when no class in the chain defines initialize()", {
	NoInit <- R6::R6Class("EDITestNoInit")
	expect_null(init_fn(NoInit))
	ChainNoInit <- R6::R6Class("EDITestChainNoInit", inherit = NoInit)
	expect_null(init_fn(ChainNoInit))
})

test_that("add_bounded_response_to_design populates only y for an exact (dead = 1) observation", {
	set.seed(1); n <- 3L
	d <- DesignSeqOneByOneBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	for (i in seq_len(n)) d$add_one_subject_to_experiment_and_assign(data.frame(x = rnorm(1)))
	add_resp(d, 1L, list(y = 5, y_L = NA_real_, y_R = NA_real_))
	expect_equal(d$get_y(), c(5, NA, NA))
})

test_that("add_bounded_response_to_design populates only y_L / y_R for a right-censored (dead = 0) observation", {
	set.seed(2); n <- 3L
	d <- DesignSeqOneByOneBernoulli$new(n = n, response_type = "survival", verbose = FALSE)
	for (i in seq_len(n)) d$add_one_subject_to_experiment_and_assign(data.frame(x = rnorm(1)))
	add_resp(d, 1L, list(y = NA_real_, y_L = 4, y_R = Inf))
	p <- d$.__enclos_env__$private
	expect_true(is.na(d$get_y()[1]))
	expect_equal(p$y_L[1], 4); expect_equal(p$y_R[1], Inf)
	expect_true(is.na(p$y_L[2]) && is.na(p$y_R[2]))
})

test_that("add_bounded_response_to_design round-trips dead_to_response_bounds()'s own output for both cases", {
	bounds_fn <- get("dead_to_response_bounds", envir = ns)
	set.seed(3); n <- 4L
	d <- DesignSeqOneByOneBernoulli$new(n = n, response_type = "survival", verbose = FALSE)
	for (i in seq_len(n)) d$add_one_subject_to_experiment_and_assign(data.frame(x = rnorm(1)))
	y <- c(3, 6); dead <- c(1, 0)
	b <- bounds_fn(y, dead)
	for (i in 1:2) add_resp(d, i, list(y = b$y[i], y_L = b$y_L[i], y_R = b$y_R[i]))
	p <- d$.__enclos_env__$private
	expect_equal(d$get_y()[1], 3); expect_true(is.na(p$y_L[1]) && is.na(p$y_R[1]))
	expect_true(is.na(d$get_y()[2])); expect_equal(p$y_L[2], 6); expect_equal(p$y_R[2], Inf)
})
