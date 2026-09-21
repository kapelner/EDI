library(testthat)
library(EDI)
skip_if_not_installed("RcppXPtrUtils")

# eval_custom_rand_stat_xptr_cpp(xptr, y, w) and eval_custom_rand_stat_dead_xptr_cpp(xptr, y, w, dead): thin shims
# that dereference a user-compiled function pointer. Reference: the same statistic computed in R. Real tiny
# cppXPtr() functions (RcppEigen) are compiled once; nothing in EDI is rebuilt.

E <- asNamespace("EDI")
S <- get("eval_custom_rand_stat_xptr_cpp", E); SD <- get("eval_custom_rand_stat_dead_xptr_cpp", E)
hdr <- "#include <RcppEigen.h>"

diff_means <- RcppXPtrUtils::cppXPtr(
	"double f(const Eigen::VectorXd& y, const Eigen::VectorXd& w){
		return (w.array()*y.array()).sum()/w.sum() - ((1-w.array())*y.array()).sum()/(1-w.array()).sum(); }",
	depends = "RcppEigen", includes = hdr)
event_rate_diff <- RcppXPtrUtils::cppXPtr(
	"double f(const Eigen::VectorXd& y, const Eigen::VectorXd& w, const Eigen::VectorXd& dead){
		return (w.array()*dead.array()).sum()/w.sum() - ((1-w.array())*dead.array()).sum()/(1-w.array()).sum(); }",
	depends = "RcppEigen", includes = hdr)
sum_y <- RcppXPtrUtils::cppXPtr(
	"double f(const Eigen::VectorXd& y, const Eigen::VectorXd& w){ return y.sum() * 1000.0 + w.sum(); }",
	depends = "RcppEigen", includes = hdr)

test_that("the (y, w) shim evaluates the user function on the supplied vectors (matches the R statistic)", {
	set.seed(1)
	for (i in 1:10) {
		n <- 20; y <- rnorm(n); w <- sample(0:1, n, TRUE); w[1:2] <- c(0, 1)
		expect_equal(S(diff_means, y, as.numeric(w)), mean(y[w == 1]) - mean(y[w == 0]), tolerance = 1e-12)
	}
	expect_equal(S(diff_means, c(1, 2, 3, 4), c(1, 0, 1, 0)), -1)
})

test_that("argument order is (y, w): a function using both distinguishes them", {
	expect_equal(S(sum_y, c(1, 2, 3), c(1, 0, 1)), 6 * 1000 + 2)
	expect_equal(S(sum_y, c(1, 0, 1), c(1, 2, 3)), 2 * 1000 + 6)
})

test_that("the (y, w, dead) shim passes the third vector through", {
	y <- c(5, 6, 7, 8); w <- c(1, 1, 0, 0); dead <- c(1, 0, 1, 1)
	expect_equal(SD(event_rate_diff, y, w, dead), mean(dead[w == 1]) - mean(dead[w == 0]))
	expect_equal(SD(event_rate_diff, y, w, dead), 0.5 - 1)
	expect_equal(SD(event_rate_diff, y, w, 1 - dead), 0.5)
})

test_that("inputs are not modified and repeated evaluation is deterministic", {
	y <- c(1.5, 2.5, 3.5, 4.5); w <- c(1, 0, 0, 1); y0 <- y; w0 <- w
	a <- S(diff_means, y, w); b <- S(diff_means, y, w)
	expect_identical(a, b); expect_identical(y, y0); expect_identical(w, w0)
})

test_that("degenerate arm gives the user function's own NaN (no shim-level guarding)", {
	expect_true(is.nan(S(diff_means, c(1, 2), c(1, 1))))
})

test_that("non-pointer inputs error instead of crashing", {
	expect_error(S("not a pointer", c(1, 2), c(1, 0)))
	expect_error(SD(NULL, c(1, 2), c(1, 0), c(1, 1)))
})
