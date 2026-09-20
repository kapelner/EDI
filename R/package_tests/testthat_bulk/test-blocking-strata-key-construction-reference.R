library(testthat)
library(EDI)

# DesignFixedBlocking's stratum-key construction (the BlockingStructure
# component's private get_strata_keys(), with its local col_to_str /
# append_key / has_equal_block_sizes / choose_column_keys helpers) and the free
# function largest_divisor_at_most() that picks the default block target.
# None had a direct test reference. References rebuild the keys from the raw
# covariates with base R (quantile + cut, paste).

blocking_design <- function(X, ..., n = nrow(X)) {
	des <- DesignFixedBlocking$new(n = n, response_type = "continuous", verbose = FALSE, ...)
	des$add_all_subjects_to_experiment(X)
	des
}

keys_of <- function(des) des$.__enclos_env__$private$get_strata_keys()

test_that("largest_divisor_at_most returns the biggest divisor not exceeding the target (1 if none)", {
	f <- EDI:::largest_divisor_at_most
	expect_equal(f(24L, 4L), 4L)
	expect_equal(f(30L, 4L), 3L)
	expect_equal(f(30L, 5L), 5L)
	expect_equal(f(25L, 4L), 1L)
	expect_equal(f(7L, 3L), 1L)
	expect_equal(f(12L, 100L), 12L)
	expect_equal(f(12L, 1L), 1L)
})

test_that("categorical strata columns become their string values, joined with '|' across columns", {
	X <- data.frame(g = rep(c("a", "b"), each = 6), h = rep(c("u", "v", "w"), times = 4))
	one <- keys_of(blocking_design(X, strata_cols = "g"))
	expect_equal(one, as.character(X$g))
	two <- keys_of(blocking_design(X, strata_cols = c("g", "h"), B_target = NULL, equal_block_sizes = TRUE))
	expect_equal(two, paste(X$g, X$h, sep = "|"))
	# Default strata columns are every raw covariate, in order.
	expect_equal(keys_of(blocking_design(X, B_target = NULL)), paste(X$g, X$h, sep = "|"))
	# With the default block target (largest divisor of n at most sqrt(n) = 3), a
	# column whose addition would exceed the target is skipped.
	expect_equal(keys_of(blocking_design(X, strata_cols = c("g", "h"))), as.character(X$g))
})

test_that("missing categorical values become the literal key 'NA'", {
	X <- data.frame(g = rep(c("a", "b"), each = 6), h = rep(c("u", "v", "w"), times = 4), stringsAsFactors = FALSE)
	d <- blocking_design(X, strata_cols = "g", missingness_method = "drop_column", equal_block_sizes = FALSE)
	priv <- d$.__enclos_env__$private
	priv$Xraw$g[c(1, 7)] <- NA
	keys <- priv$get_strata_keys()
	expect_equal(keys[c(1, 7)], c("NA", "NA"))
	expect_equal(keys[-c(1, 7)], as.character(priv$Xraw$g[-c(1, 7)]))
})

test_that("numeric strata columns are cut at quantile breaks into the preferred number of bins", {
	set.seed(2)
	n <- 24L
	X <- data.frame(g = rep(c("a", "b"), each = n / 2), z = rnorm(n))
	d <- blocking_design(X, strata_cols = c("g", "z"), preferred_num_bins_for_continuous_covariate = 2,
		equal_block_sizes = FALSE, B_target = NULL)
	priv <- d$.__enclos_env__$private
	priv$B_target <- NULL
	breaks <- unique(quantile(X$z, probs = seq(0, 1, length.out = 3), na.rm = TRUE))
	ref <- paste(X$g, as.character(cut(X$z, breaks = breaks, include.lowest = TRUE)), sep = "|")
	expect_equal(priv$get_strata_keys(), ref)
	expect_equal(length(unique(priv$get_strata_keys())), 4L)

	# A constant numeric column cannot be cut: its raw value is the key.
	Xc <- data.frame(g = rep(c("a", "b"), each = 4), k = 7)
	kc <- keys_of(blocking_design(Xc, strata_cols = c("g", "k")))
	expect_equal(kc, paste(Xc$g, "7", sep = "|"))
})

test_that("equal_block_sizes = TRUE rejects unbalanced strata; FALSE accepts them", {
	X <- data.frame(g = c(rep("a", 6), rep("b", 2)))
	expect_error(keys_of(blocking_design(X, strata_cols = "g", equal_block_sizes = TRUE)),
		"equal_block_sizes = TRUE but the strata produced unequal block sizes \\(2, 6\\)")
	expect_equal(keys_of(blocking_design(X, strata_cols = "g", equal_block_sizes = FALSE)), as.character(X$g))
})

test_that("exact_num_blocks searches numeric bin counts to hit B_target, and fails loudly otherwise", {
	X <- data.frame(g = rep(c("a", "b"), each = 12), z = rep(1:12, 2))
	d <- blocking_design(X, strata_cols = c("g", "z"), B_target = 6, exact_num_blocks = TRUE, equal_block_sizes = TRUE)
	keys <- keys_of(d)
	expect_equal(length(unique(keys)), 6L)
	expect_true(all(table(keys) == 4L))
	# Blocks are (g, z-tercile) cells.
	tercile <- cut(X$z, breaks = unique(quantile(X$z, seq(0, 1, length.out = 4))), include.lowest = TRUE)
	expect_equal(as.integer(factor(keys)), as.integer(factor(paste(X$g, tercile))))

	expect_error(keys_of(blocking_design(data.frame(g = rep(c("a", "b"), each = 6)), strata_cols = "g",
		B_target = 5, exact_num_blocks = TRUE, equal_block_sizes = FALSE)), "produced 2 blocks instead of the requested 5")

	unreachable <- data.frame(g = rep(c("a", "b"), each = 12), z = rnorm(24))
	set.seed(3)
	expect_error(keys_of(blocking_design(unreachable, strata_cols = c("g", "z"), B_target = 6,
		exact_num_blocks = TRUE, equal_block_sizes = TRUE)), "instead of the requested 6")
})

test_that("exact_num_blocks without a target and an empty design are handled", {
	X <- data.frame(g = rep(c("a", "b"), each = 4))
	d <- blocking_design(X, strata_cols = "g", exact_num_blocks = FALSE)
	priv <- d$.__enclos_env__$private
	priv$exact_num_blocks <- TRUE
	priv$B_target <- NULL
	expect_error(priv$get_strata_keys(), "exact_num_blocks requires B_target")

	empty <- DesignFixedBlocking$new(n = 8L, response_type = "continuous", verbose = FALSE)
	expect_equal(empty$.__enclos_env__$private$get_strata_keys(), character(0))
})
