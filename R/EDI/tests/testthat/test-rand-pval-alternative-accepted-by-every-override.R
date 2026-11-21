library(testthat)
library(EDI)

# v1.0.6-TODO-328: InferenceRand$compute_rand_two_sided_pval() takes
# `alternative` ("two.sided" / "greater" / "less"), but the overrides in the
# KK GEE mixin, InferenceIncidKKCondLogitOneLik, InferenceSurvivalWeibullRegr
# and InferenceSurvivalDepCensTransformRegr did not, so
# compute_rand_two_sided_pval(alternative = "greater") stopped with "unused
# argument" on those classes. This file checks the formal on every exported
# class and calls each fixed override with every alternative.

rand_alt_fixtures = local({
	cache = NULL
	function() {
		if (!is.null(cache)) return(cache)
		set.seed(328)
		n = 30L
		X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
		ys = list(
			continuous = rnorm(n), incidence = rbinom(n, 1, 0.5), proportion = runif(n, 0.05, 0.95),
			count = c(rep(0L, 8L), rpois(n - 8L, 3)), survival = rexp(n) + 0.1, ordinal = sample(1:4, n, TRUE)
		)
		mk = function(gen, rt) {
			d = gen$new(n = n, response_type = rt, verbose = FALSE)
			d$add_all_subjects_to_experiment(X)
			d$assign_w_to_all_subjects()
			d$add_all_subject_responses(ys[[rt]])
			d
		}
		out = list()
		for (rt in names(ys)) {
			out[[paste0("bern_", rt)]] = mk(DesignFixedBernoulli, rt)
			out[[paste0("match_", rt)]] = suppressWarnings(mk(DesignFixedBinaryMatch, rt))
		}
		cache <<- out
		out
	}
})

rand_alt_build = function(cn, fixture_names = names(rand_alt_fixtures())) {
	gen = get(cn, envir = asNamespace("EDI"))
	for (fn in fixture_names) {
		inf = tryCatch(suppressWarnings(suppressMessages(gen$new(rand_alt_fixtures()[[fn]], verbose = FALSE))),
			error = function(e) NULL)
		if (!is.null(inf)) return(inf)
	}
	NULL
}

rand_alt_inference_classes = function() {
	exps = sort(grep("^Inference", getNamespaceExports("EDI"), value = TRUE))
	exps = setdiff(exps, c("InferenceSuite", "InferenceRandCustom"))
	Filter(function(cn) inherits(get(cn, envir = asNamespace("EDI")), "R6ClassGenerator"), exps)
}

test_that("every exported class's compute_rand_two_sided_pval() has an `alternative` formal", {
	n_checked = 0L
	for (cn in rand_alt_inference_classes()) {
		inf = rand_alt_build(cn)
		if (is.null(inf)) next
		f = inf$compute_rand_two_sided_pval
		if (!is.function(f)) next
		n_checked = n_checked + 1L
		expect_true("alternative" %in% names(formals(f)), info = cn)
		expect_identical(eval(formals(f)$alternative), "two.sided", info = cn)
	}
	expect_gt(n_checked, 60L)
})

# The base method's definition: with B finite reference statistics,
# two.sided = min(1, max(2/B, 2 min(P(T0 >= t), P(T0 <= t)))),
# greater = max(1/B, P(T0 >= t)), less = max(1/B, P(T0 <= t)); so on the same
# draws two.sided = min(1, 2 min(greater, less)) and greater + less >= 1.
rand_alt_overrides = list(
	InferencePropKKGEE = "match_proportion",
	InferenceCountPoissonKKGEE = "match_count",
	InferenceOrdinalKKGEE = "match_ordinal",
	InferenceIncidKKCondLogitOneLik = "match_incidence",
	InferenceSurvivalWeibullRegr = "bern_survival"
)

for (cn in names(rand_alt_overrides)) {
	local({
		cn = cn
		test_that(paste0(cn, ": compute_rand_two_sided_pval() honors `alternative`"), {
			inf = rand_alt_build(cn, rand_alt_overrides[[cn]])
			if (is.null(inf)) skip(paste(cn, "cannot be built here (a Suggests package may be missing)"))
			p = vapply(c("two.sided", "greater", "less"), function(alt) {
				set.seed(1)
				suppressWarnings(inf$compute_rand_two_sided_pval(r = 99, show_progress = FALSE, alternative = alt))
			}, numeric(1))
			expect_true(all(is.finite(p)), info = paste(names(p), p, collapse = "; "))
			expect_true(all(p > 0 & p <= 1))
			expect_lte(p[["two.sided"]], 2 * min(p[["greater"]], p[["less"]]) + 1e-12)
			expect_equal(p[["two.sided"]], min(1, 2 * min(p[["greater"]], p[["less"]])), tolerance = 1e-12)
			expect_gte(p[["greater"]] + p[["less"]], 1 - 1e-12)
			# the default is unchanged by the new formal
			set.seed(1)
			expect_identical(suppressWarnings(inf$compute_rand_two_sided_pval(r = 99, show_progress = FALSE)), p[["two.sided"]])
			expect_error(inf$compute_rand_two_sided_pval(r = 99, show_progress = FALSE, alternative = "sideways"))
		})
	})
}

# The KK GEE override refuses incidence randomization unless the design is a
# rerandomization design, which InferenceIncidKKGEE (KK designs only) never
# has; the call must reach that refusal, not fail on the argument list.
test_that("InferenceIncidKKGEE: compute_rand_two_sided_pval() accepts `alternative`", {
	inf = rand_alt_build("InferenceIncidKKGEE", "match_incidence")
	if (is.null(inf)) skip("InferenceIncidKKGEE cannot be built here")
	for (alt in c("two.sided", "greater", "less")) {
		expect_error(inf$compute_rand_two_sided_pval(r = 99, show_progress = FALSE, alternative = alt),
			"not supported for incidence", info = alt)
	}
	expect_error(inf$compute_rand_two_sided_pval(alternative = "sideways"), "should be one of")
})

test_that("InferenceSurvivalDepCensTransformRegr: compute_rand_two_sided_pval() accepts `alternative` and stays unsupported", {
	inf = rand_alt_build("InferenceSurvivalDepCensTransformRegr", "bern_survival")
	expect_false(is.null(inf))
	for (alt in c("two.sided", "greater", "less")) {
		expect_identical(suppressWarnings(inf$compute_rand_two_sided_pval(r = 99, show_progress = FALSE, alternative = alt)), NA_real_)
	}
	expect_error(inf$compute_rand_two_sided_pval(alternative = "sideways"))
})
