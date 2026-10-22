# TODO-120: one default B (501) for every dependent-censoring bootstrap CI method.
src_pub = function() EDI:::SurvivalDepCensTransformSource$public
boot_methods = c("compute_bootstrap_confidence_interval", "compute_bootstrap_confidence_interval_basic",
	"compute_bootstrap_confidence_interval_bca", "compute_bootstrap_confidence_interval_studentized")

test_that("all dep-cens bootstrap CI methods share the default B of the inherited p-value method", {
	pval_B = formals(EDI:::InferenceNonParamBootstrap$public_methods$compute_bootstrap_two_sided_pval)$B
	expect_identical(pval_B, 501)
	for (m in boot_methods) expect_identical(formals(src_pub()[[m]])$B, pval_B, info = m)
	expect_identical(formals(EDI:::SurvivalDepCensTransformSource$private$dep_cens_percentile_bootstrap_ci)$B, pval_B)
})

test_that("explicit and default B are forwarded unchanged by the wrapper methods", {
	seen = new.env(); seen$B = list()
	good = c(a = -1, b = 1)
	private = list(
		dep_cens_validate_bootstrap_ci = function(ci, alpha) ci,
		nonparam_boot_compute_bootstrap_confidence_interval = function(alpha, B, ...) { seen$B[[length(seen$B) + 1L]] = B; good },
		dep_cens_percentile_bootstrap_ci = function(alpha, B, ...) { seen$B[[length(seen$B) + 1L]] = B; good }
	)
	self = list()
	self$compute_bootstrap_confidence_interval = function(...) {
		f = src_pub()$compute_bootstrap_confidence_interval
		environment(f) = list2env(list(self = self, private = private), parent = environment(src_pub))
		f(...)
	}
	self$compute_bootstrap_confidence_interval_basic = function(...) {
		f = src_pub()$compute_bootstrap_confidence_interval_basic
		environment(f) = list2env(list(self = self, private = private), parent = globalenv())
		f(...)
	}
	for (m in boot_methods) {
		f = src_pub()[[m]]
		environment(f) = list2env(list(self = self, private = private), parent = globalenv())
		seen$B = list(); f(); expect_equal(unlist(seen$B), 501, info = m)
		seen$B = list(); f(B = 77); expect_equal(unlist(seen$B), 77, info = m)
	}
})
