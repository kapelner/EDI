library(testthat)
library(EDI)

# BlockingStructure component (design_blocking_abstract.R) on a DesignFixediBCRD with manually supplied block ids:
# add_all_subject_matched_pair_ids / get_block_ids, is_blocking_design, is_complete_blocking_design, assert_equal_block_sizes,
# summarize_blocks (numeric mean/sd, categorical percentages, missing-block warning), inject_cmh_se_w_mat / get_cmh_se_w_mat,
# assert_blocking_design. References: hand-computed block summaries.

n <- 12L
set.seed(1)
X <- data.frame(a = rnorm(n), g = factor(rep(c("u", "v", "w"), 4)), chr = rep(c("p", "q"), 6), stringsAsFactors = FALSE)
mk <- function() {
	d <- DesignFixediBCRD$new(response_type = "continuous", n = n, seed = 1L, verbose = FALSE)
	d$add_all_subjects_to_experiment(X); d$assign_w_to_all_subjects(); d$add_all_subject_responses(rnorm(n))
	d
}
m3 <- rep(1:3, each = 4)

test_that("supplied block ids round-trip as integers and make the design a complete blocking design", {
	d <- mk()
	expect_true(d$is_blocking_design())
	expect_identical(d$add_all_subject_matched_pair_ids(m3), d)                                  # invisible self
	expect_identical(d$get_block_ids(), m3)
	expect_true(d$is_complete_blocking_design())
	expect_true(d$assert_equal_block_sizes())
})

test_that("id validation: positive integerish, right length", {
	d <- mk()
	expect_error(d$add_all_subject_matched_pair_ids(c(0, rep(1, n - 1L))))
	expect_error(d$add_all_subject_matched_pair_ids(1:3))
	expect_error(d$add_all_subject_matched_pair_ids(c(NA, rep(1L, n - 1L))))
	expect_error(d$add_all_subject_matched_pair_ids(rep(1.5, n)))
})

test_that("unequal block sizes are rejected by assert_equal_block_sizes; the size check is skipped when asserts are off", {
	d <- mk(); d$add_all_subject_matched_pair_ids(c(1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 2))
	expect_error(d$assert_equal_block_sizes(), "All blocks must have the same number of subjects")
	withr::local_options(edi.run_asserts = FALSE)
	expect_true(d$assert_equal_block_sizes())
})

test_that("a single block passes the equal-size check; zero block ids make the blocking incomplete", {
	d <- mk(); d$add_all_subject_matched_pair_ids(rep(1L, n)); expect_true(d$assert_equal_block_sizes())
	unlockBinding("get_block_ids", d)
	d$get_block_ids <- function() c(0L, rep(1L, n - 1L))
	expect_false(d$is_complete_blocking_design())
	d$get_block_ids <- function() integer(0); expect_false(d$is_complete_blocking_design())
})

test_that("block summaries: numeric columns mean/sd, categorical columns percentages, one data.table per block id", {
	d <- mk(); d$add_all_subject_matched_pair_ids(m3)
	s <- d$summarize_blocks()
	expect_identical(names(s), c("1", "2", "3"))
	b1 <- s[["1"]]; idx <- which(m3 == 1)
	expect_equal(b1[variable == "a"]$mean_or_pct, mean(X$a[idx]), tolerance = 1e-12); expect_equal(b1[variable == "a"]$sd, sd(X$a[idx]), tolerance = 1e-12)
	expect_true(is.na(b1[variable == "a"]$level))
	g <- b1[variable == "g"]; ref <- prop.table(table(X$g[idx])) * 100
	expect_identical(g$level, names(ref)); expect_equal(g$mean_or_pct, as.numeric(ref)); expect_true(all(is.na(g$sd)))
	ch <- s[["2"]][variable == "chr"]; refc <- prop.table(table(X$chr[which(m3 == 2)])) * 100
	expect_identical(ch$level, names(refc)); expect_equal(ch$mean_or_pct, as.numeric(refc))
	expect_identical(names(d$summarize_blocks(2L)), "2")
	expect_equal(sum(s[["3"]][variable == "g"]$mean_or_pct), 100)
})

test_that("summarising an unknown block warns and omits it; all-NA columns within a block", {
	d <- mk(); d$add_all_subject_matched_pair_ids(m3)
	expect_warning(r <- d$summarize_blocks(c(1L, 9L)), "Block ID 9 not found in the design")
	expect_identical(names(r), "1")
	# an all-NA CHARACTER column within a block reports a single N/A row ...
	X2 <- X; X2$chr[m3 == 1] <- NA
	e <- DesignFixediBCRD$new(response_type = "continuous", n = n, seed = 1L, verbose = FALSE)
	e$add_all_subjects_to_experiment(X2); e$assign_w_to_all_subjects(); e$add_all_subject_responses(rnorm(n)); e$add_all_subject_matched_pair_ids(m3)
	na_row <- e$summarize_blocks(1L)[["1"]][variable == "chr"]
	expect_identical(na_row$level, "N/A"); expect_true(is.na(na_row$mean_or_pct))
	# ... whereas an all-NA FACTOR keeps its levels with undefined (0/0) percentages (observed quirk)
	X3 <- X; X3$g[m3 == 1] <- NA
	f3 <- DesignFixediBCRD$new(response_type = "continuous", n = n, seed = 1L, verbose = FALSE)
	f3$add_all_subjects_to_experiment(X3); f3$assign_w_to_all_subjects(); f3$add_all_subject_responses(rnorm(n)); f3$add_all_subject_matched_pair_ids(m3)
	fr <- f3$summarize_blocks(1L)[["1"]][variable == "g"]
	expect_identical(fr$level, c("u", "v", "w")); expect_true(all(is.na(fr$mean_or_pct)))
})

test_that("CMH SE assignment matrix injection and retrieval", {
	d <- mk(); expect_null(d$get_cmh_se_w_mat())
	w <- matrix(as.integer(sample(0:1, n * 5, TRUE)), n)
	expect_identical(d$inject_cmh_se_w_mat(w), d); expect_identical(d$get_cmh_se_w_mat(), w)
})

test_that("assert_blocking_design passes for a blocking design; designs without the component do not expose it", {
	d <- mk(); expect_silent(d$assert_blocking_design())
	b <- DesignFixedBernoulli$new(response_type = "continuous", n = n, seed = 1L, verbose = FALSE)
	expect_false(is.function(b$assert_blocking_design))
})
