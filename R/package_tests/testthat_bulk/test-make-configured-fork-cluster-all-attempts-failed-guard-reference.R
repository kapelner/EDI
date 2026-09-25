library(testthat)
library(EDI)

# globals.R's make_configured_fork_cluster() (companion to the mirai_has_been_used guard already
# closed in test-make-configured-fork-cluster-mirai-used-guard-reference.R) falls through three
# cluster-creation attempts -- plain parallel::makeForkCluster(), makeForkCluster() on each of 20
# candidate ports, and finally parallel::makeCluster() -- before giving up: "Could not create fork
# cluster after trying <n> ports<: last error message>." A codebase-wide grep confirmed this exact
# message had zero test references anywhere. Reached by mocking BOTH parallel::makeForkCluster()
# and parallel::makeCluster() (via with_mocked_bindings, .package = "parallel") to always fail, so
# no real fork cluster or PSOCK cluster is ever actually created.

test_that("make_configured_fork_cluster() raises the documented all-attempts-failed message, naming the port count and last error, when every cluster-creation attempt fails", {
	res <- with_mocked_bindings(
		makeForkCluster = function(...) stop("fork disabled for test"),
		makeCluster = function(...) stop("cluster disabled for test"),
		.package = "parallel",
		tryCatch(EDI:::make_configured_fork_cluster(1L), error = function(e) conditionMessage(e))
	)
	expect_match(res, "^Could not create fork cluster after trying 20 ports: cluster disabled for test$")
})
