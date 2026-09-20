library(testthat)
library(EDI)

# globals.R dispatch machinery: edi_bootstrap_dispatch_policy() resolution order (design
# override > class override > default, tolower, vector input, BCa -> percentile fallback
# when block-wise jackknife is unsupported), edi_parallel_dispatch_policy() (forced-serial
# rules, override hook), get_num_cores() precedence, and an audit that every shipped
# class-override pattern still matches at least one real inference class.

Z <- function(x) get(x, envir = asNamespace("EDI"))
env <- Z("edi_env")

with_config <- function(field, value, code) {
	old <- env[[field]]; on.exit(env[[field]] <- old, add = TRUE)
	env[[field]] <- value
	force(code)
}

test_that("bootstrap policy: default type, class overrides, lower-casing and vector input", {
	f <- Z("edi_bootstrap_dispatch_policy")
	expect_equal(Z("get_bootstrap_dispatch_policy")()$default_type, "bca")
	expect_equal(f("InferenceSomethingUnlisted"), "bca")
	expect_equal(f("InferenceContinLin"), "percentile")
	expect_equal(f("InferenceCountPoisson"), "percentile")
	expect_equal(f(c("Whatever", "InferenceContinLin")), "percentile")             # any element may match
	expect_equal(f("InferenceContinLinExtra"), "bca")                              # anchored patterns
	cfg <- list(default_type = "BCA", inference_class_overrides = c("^Foo$" = "Percentile", "^Foo" = "basic"))
	with_config("bootstrap_dispatch_policy_config", cfg, {
		expect_equal(f("Foo"), "percentile")                                       # first matching pattern wins, value lower-cased
		expect_equal(f("FooBar"), "basic")
		expect_equal(f("Zed"), "bca")                                              # default lower-cased too
	})
	with_config("bootstrap_dispatch_policy_config", list(inference_class_overrides = NULL), expect_equal(f("Any"), "bca"))
})

test_that("bootstrap policy: design-class overrides beat class overrides, and only apply to matching design classes", {
	f <- Z("edi_bootstrap_dispatch_policy")
	des <- structure(list(), class = c("DesignFixedBlockedCluster", "Design"))
	obj <- list(.__enclos_env__ = list(private = list(des_obj = des)))
	cfg <- list(default_type = "bca",
		inference_class_overrides = c("^InferenceX$" = "basic"),
		design_class_overrides = list(DesignFixedBlockedCluster = c("^InferenceX$" = "percentile", "^InferenceY$" = "basic")))
	# `is()` is S4-aware; register the fake design class chain so is() recognises it.
	with_config("bootstrap_dispatch_policy_config", cfg, {
		expect_equal(f("InferenceX", obj), "percentile")                           # design override first
		expect_equal(f("InferenceY", obj), "basic")
		expect_equal(f("InferenceX"), "basic")                                     # no object: design overrides skipped
		other <- list(.__enclos_env__ = list(private = list(des_obj = structure(list(), class = "DesignFixedBernoulli"))))
		expect_equal(f("InferenceX", other), "basic")
		expect_equal(f("InferenceZ", obj), "bca")
	})
})

test_that("bootstrap policy: a BCa choice degrades to percentile when block-wise jackknife is unsupported", {
	f <- Z("edi_bootstrap_dispatch_policy")
	mk <- function(unsupported) list(.__enclos_env__ = list(private = list(
		des_obj = NULL, jackknife_block_size_gt_one_unsupported = function(unit) unsupported)))
	expect_equal(f("InferenceUnlisted", mk(TRUE)), "percentile")
	expect_equal(f("InferenceUnlisted", mk(FALSE)), "bca")
	err <- list(.__enclos_env__ = list(private = list(jackknife_block_size_gt_one_unsupported = function(unit) stop("boom"))))
	expect_equal(f("InferenceUnlisted", err), "bca")                              # a failing probe never changes the type
	expect_equal(f("InferenceContinLin", mk(TRUE)), "percentile")               # explicit non-BCa types are untouched
	with_config("bootstrap_dispatch_policy_config", list(default_type = "basic"), expect_equal(f("Zed", mk(TRUE)), "basic"))
})

test_that("parallel policy: forced-serial rules per operation, response type and class pattern; override hook wins", {
	f <- Z("edi_parallel_dispatch_policy")
	r <- f("InferenceIncidLogRegr", "incidence", "bootstrap")
	expect_true(r$force_serial); expect_match(r$reason, "bootstrap is forced serial"); expect_equal(r$operation, "bootstrap")
	r2 <- f("InferenceIncidLogRegr", "incidence", "rand_ci")
	expect_true(r2$force_serial); expect_match(r2$reason, "randomization confidence intervals are forced serial")
	ok <- f("InferenceCountPoisson", "count", "bootstrap")
	expect_false(ok$force_serial); expect_null(ok$reason)
	expect_true(f("InferenceSurvivalCoxPHRegr", "survival", "bootstrap")$force_serial)
	expect_false(f("InferenceSurvivalKKCoxOneLik", "survival", "bootstrap")$force_serial)
	expect_false(f("InferenceCountPoisson", "count", "unknown_operation")$force_serial)
	expect_true(f("Custom", "incidence", "rand_ci")$force_serial)                # response type alone forces serial
	with_config("parallel_dispatch_policy_override", function(cls, rt, op) list(force_serial = TRUE, tag = paste(cls, rt, op)), {
		expect_equal(f("A", "count", "bootstrap")$tag, "A count bootstrap")
	})
})

test_that("core count precedence: explicit override, then fork cluster, then mirai cores, then 1", {
	saved <- list(o = env$num_cores_override, f = env$global_fork_cluster, m = env$global_mirai_num_cores)
	on.exit({ env$num_cores_override <- saved$o; env$global_fork_cluster <- saved$f; env$global_mirai_num_cores <- saved$m }, add = TRUE)
	env$num_cores_override <- NULL; env$global_fork_cluster <- NULL; env$global_mirai_num_cores <- NULL
	g <- Z("get_num_cores")
	expect_equal(g(), 1L)
	env$global_mirai_num_cores <- 6L
	expect_equal(g(), 6L)
	expect_equal(Z("get_global_mirai_cores")(), 6L)
	env$global_fork_cluster <- list(1, 2, 3)                                     # length() is all that is read
	expect_equal(g(), 3L)
	expect_equal(length(Z("get_global_fork_cluster")()), 3L)
	env$num_cores_override <- 2L
	expect_equal(g(), 2L)
})

test_that("audit: every shipped class-override pattern of the bootstrap / optimizer / cold-start policies matches a real inference class", {
	ns <- asNamespace("EDI")
	classes <- ls(ns, pattern = "^Inference")
	classes <- classes[vapply(classes, function(x) inherits(get(x, ns), "R6ClassGenerator"), logical(1))]
	expect_gt(length(classes), 50L)
	for (nm in c("get_bootstrap_dispatch_policy", "get_optimization_dispatch_policy", "get_cold_start_dispatch_policy")) {
		pats <- names(get(nm, ns)()$inference_class_overrides)
		expect_gt(length(pats), 0L)
		dead <- pats[!vapply(pats, function(p) any(grepl(p, classes, perl = TRUE)), logical(1))]
		expect_identical(dead, character(0), info = nm)
		expect_false(anyDuplicated(pats) > 0L, info = nm)
	}
	par <- Z("get_parallel_dispatch_policy")()
	for (op in names(par)) {
		pats <- par[[op]]$serial_inference_class_patterns
		dead <- pats[!vapply(pats, function(p) any(grepl(p, classes, perl = TRUE)), logical(1))]
		expect_identical(dead, character(0), info = op)
	}
})
