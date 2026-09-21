library(testthat)
library(EDI)

# DesignFixedCustom / DesignCustomSequential (design_custom_extensions.R): validation of user-supplied assignment draws and rules.
# Fixed: draw_ws_raw(r) accepts an n x r 0/1 matrix (data.frames are coerced), rejects wrong dimensions, non-0/1 values and r < 1, and
# skips those checks when asserts are off. Sequential: assign_wt() returns the rule's scalar as numeric, rejects non-0/1 values.
# Both bases are abstract and refuse direct instantiation.

Fixed <- getFromNamespace("DesignFixedCustom", "EDI")
Seq <- getFromNamespace("DesignCustomSequential", "EDI")
FixedSub <- R6::R6Class("TmpFixedSub", inherit = Fixed, public = list(mode = "ok",
	draw_assignments = function(r = 1) {
		n <- self$get_n()
		switch(self$mode,
			ok = matrix(rep(c(1, 0), length.out = n), n, r),
			df = as.data.frame(matrix(rep(c(1, 0), length.out = n), n, r)),
			wrongdim = matrix(1, n + 1, r), wrongcols = matrix(1, n, r + 1L), bad01 = matrix(2, n, r), neg = matrix(-1, n, r),
			stop("draw failed"))
	}))
SeqSub <- R6::R6Class("TmpSeqSub", inherit = Seq, public = list(value = 1, calls = 0L,
	assignment_rule = function() { self$calls <- self$calls + 1L; self$value }))
mkf <- function(mode = "ok") { d <- FixedSub$new(n = 6L, response_type = "continuous", verbose = FALSE); d$mode <- mode; d$add_all_subjects_to_experiment(data.frame(x = 1:6)); d }

test_that("both custom bases are abstract", {
	expect_error(Fixed$new(n = 6L, response_type = "continuous", verbose = FALSE), "abstract Design base class")
	expect_error(Seq$new(n = 6L, response_type = "continuous", verbose = FALSE), "abstract Design base class")
	# a concrete subclass that forgets to implement the hook fails with the documented message
	NoRule <- R6::R6Class("TmpNoRule", inherit = Seq)
	expect_error(NoRule$new(n = 6L, response_type = "continuous", verbose = FALSE)$assignment_rule(), "must implement public\\$assignment_rule")
	NoDraw <- R6::R6Class("TmpNoDraw", inherit = Fixed)
	expect_error(NoDraw$new(n = 6L, response_type = "continuous", verbose = FALSE)$draw_assignments(1), "must implement public\\$draw_assignments")
})

test_that("fixed custom design: valid draws flow through assign_w_to_all_subjects and draw_ws_raw returns an n x r matrix", {
	d <- mkf(); d$assign_w_to_all_subjects()
	expect_identical(as.numeric(d$get_w()), rep(c(1, 0), 3))
	p <- d$.__enclos_env__$private
	expect_identical(dim(p$draw_ws_raw(4L)), c(6L, 4L)); expect_identical(dim(p$draw_ws_raw()), c(6L, 100L))
	d$mode <- "df"; m <- p$draw_ws_raw(3L); expect_true(is.matrix(m)); expect_identical(dim(m), c(6L, 3L))
})

test_that("fixed custom design rejects malformed draws with specific messages", {
	d <- mkf(); p <- d$.__enclos_env__$private
	d$mode <- "wrongdim"; expect_error(p$draw_ws_raw(2L), "must return an n x r assignment matrix")
	d$mode <- "wrongcols"; expect_error(p$draw_ws_raw(2L), "must return an n x r assignment matrix")
	d$mode <- "bad01"; expect_error(p$draw_ws_raw(2L), "must return only 0/1 assignments")
	d$mode <- "neg"; expect_error(p$draw_ws_raw(2L), "must return only 0/1 assignments")
	d$mode <- "fail"; expect_error(p$draw_ws_raw(2L), "draw failed")
	d$mode <- "ok"; expect_error(p$draw_ws_raw(0L)); expect_error(p$draw_ws_raw(-2)); expect_error(p$draw_ws_raw(1.5))
})

test_that("with asserts off the shape / value checks are skipped (the matrix is returned as supplied)", {
	d <- mkf("bad01"); p <- d$.__enclos_env__$private
	withr::local_options(edi.run_asserts = FALSE)
	expect_identical(dim(p$draw_ws_raw(2L)), c(6L, 2L)); expect_true(all(p$draw_ws_raw(2L) == 2))
})

test_that("sequential custom design: rule result is returned as numeric 0/1 and called once per subject", {
	d <- SeqSub$new(n = 4L, response_type = "continuous", verbose = FALSE)
	w1 <- d$add_one_subject_to_experiment_and_assign(data.frame(x = 1)); expect_identical(w1, 1)
	d$value <- 0L; w2 <- d$add_one_subject_to_experiment_and_assign(data.frame(x = 2)); expect_identical(w2, 0); expect_type(w2, "double")
	expect_identical(d$calls, 2L)
	expect_identical(d$assign_wt(), 0)                                                # entry point standalone
})

test_that("sequential custom design rejects non-binary rule values (asserts on) and passes them when off", {
	d <- SeqSub$new(n = 4L, response_type = "continuous", verbose = FALSE)
	for (bad in list(2, -1, 0.5, NA_real_, "a")) { d$value <- bad; expect_error(d$assign_wt(), info = format(bad)) }
	d$value <- 2
	withr::local_options(edi.run_asserts = FALSE)
	expect_identical(d$assign_wt(), 2)
})
