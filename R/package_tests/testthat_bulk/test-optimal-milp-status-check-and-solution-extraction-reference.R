library(testthat)
library(EDI)

# optimal_milp_check_status() (accepts "optimal"/"success", errors otherwise with the
# solver status in the message) and optimal_milp_extract_w() (rebuilds the length-n
# 0/1 vector from ompr's sparse solution, rounding solver noise). Driven with mocked
# ompr accessors, then against a real tiny MILP solved by ompr for an end-to-end check.

ns <- function(x) get(x, envir = asNamespace("EDI"))

test_that("optimal and success statuses pass and are returned", {
	chk <- ns("optimal_milp_check_status")
	skip_if_not_installed("ompr")
	local_mocked_bindings(solver_status = function(result) result, .package = "ompr")
	expect_equal(chk("optimal", "quadratic"), "optimal")
	expect_equal(chk("success", "quadratic"), "success")
})

test_that("any other status stops with the model label and the solver status", {
	chk <- ns("optimal_milp_check_status")
	skip_if_not_installed("ompr")
	local_mocked_bindings(solver_status = function(result) result, .package = "ompr")
	expect_error(chk("infeasible", "abs_sum_diff (l1)"),
		"The abs_sum_diff \\(l1\\) MILP solve did not reach optimality \\(solver status: 'infeasible'\\)")
	expect_error(chk("error", "x"), "solver status: 'error'")
})

test_that("extraction places rounded solution values at their indices and leaves the rest zero", {
	ext <- ns("optimal_milp_extract_w")
	skip_if_not_installed("ompr")
	local_mocked_bindings(get_solution = function(result, ...) data.frame(variable = "w", i = c(2L, 5L, 6L), value = c(0.9999999, 1e-9, 1)),
		.package = "ompr")
	expect_equal(ext(NULL, 6L), c(0, 1, 0, 0, 0, 1))
	local_mocked_bindings(get_solution = function(result, ...) data.frame(variable = character(0), i = integer(0), value = numeric(0)),
		.package = "ompr")
	expect_equal(ext(NULL, 4L), rep(0, 4))
})

test_that("end to end: a real solve returns a status accepted by the check and a 0/1 vector with n_T ones", {
	skip_if(!all(vapply(c("ompr", "ompr.roi", "ROI.plugin.glpk"), requireNamespace, logical(1), quietly = TRUE)))
	set.seed(2)
	n <- 8L
	Q <- crossprod(matrix(rnorm(n * 3), 3, n))
	res <- ns("milp_solve_quadratic")(Q, 4L)
	expect_true(res$status %in% c("optimal", "success"))
	expect_length(res$w, n)
	expect_true(all(res$w %in% c(0, 1)))
	expect_equal(sum(res$w), 4)
	brute <- min(apply(utils::combn(n, 4), 2, function(ix) { w <- numeric(n); w[ix] <- 1; drop(t(w) %*% ((Q + t(Q)) / 2) %*% w) }))
	expect_equal(res$objective_value, brute, tolerance = 1e-6)
})
