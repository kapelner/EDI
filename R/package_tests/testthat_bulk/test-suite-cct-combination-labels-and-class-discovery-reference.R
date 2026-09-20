library(testthat)
library(EDI)

# inference_suite.R helpers without direct tests: cct_combine_pvalues_full() (Cauchy combination,
# Liu & Xie 2020) against its closed form and properties, cov_model_display() (letter keys for
# covariate formulas), design_class_short_label(), and discover_applicable_inference_classes()
# with its three *_for_design wrappers, checked against the design's own public listing and the
# registry's compatibility rules.

Z <- function(x) get(x, envir = asNamespace("EDI"))

test_that("Cauchy combination: statistic is the weighted sum of tan((0.5 - p) * pi), p-value 0.5 - atan(stat) / pi", {
	f <- Z("cct_combine_pvalues_full")
	p <- c(0.01, 0.2, 0.7)
	out <- f(p)
	stat <- mean(tan((0.5 - p) * pi))
	expect_equal(out$stat, stat, tolerance = 1e-12)
	expect_equal(out$pval, 0.5 - atan(stat) / pi, tolerance = 1e-12)
	expect_equal(out$pval, pcauchy(stat, lower.tail = FALSE), tolerance = 1e-12)         # standard Cauchy tail
	w <- c(3, 1, 1)
	ow <- f(p, w)
	expect_equal(ow$stat, sum(w / sum(w) * tan((0.5 - p) * pi)), tolerance = 1e-12)
	expect_equal(f(p, w * 7)$pval, ow$pval, tolerance = 1e-12)                            # weights are normalised
})

test_that("Cauchy combination properties: single p-value is returned unchanged; p = 0.5 is neutral; small p-values dominate; bounded in (0, 1)", {
	f <- Z("cct_combine_pvalues_full")
	for (p in c(0.001, 0.3, 0.9)) expect_equal(f(p)$pval, p, tolerance = 1e-10)
	expect_equal(f(c(0.5, 0.5, 0.5))$pval, 0.5, tolerance = 1e-12)
	expect_equal(f(c(0.5, 0.5, 0.5))$stat, 0, tolerance = 1e-12)
	expect_lt(f(c(1e-8, 0.9, 0.9))$pval, 1e-7)                                              # one tiny p-value drives the result
	expect_lt(f(c(0.01, 0.02, 0.03))$pval, 0.05)
	expect_gt(f(c(0.6, 0.7, 0.8))$pval, 0.5)
	for (pv in list(c(0.2, 0.4), c(1e-12, 1e-12), c(0.999, 0.9999))) {
		r <- f(pv)$pval; expect_true(r > 0 && r < 1)
	}
	expect_lt(f(c(0.01, 0.4))$pval, f(c(0.05, 0.4))$pval)                                    # monotone in each p-value
})

test_that("covariate-model display: sentinels and NA pass through, distinct formulas get letters in order of first use", {
	f <- Z("cov_model_display")
	out <- f(list("~x", "~1", "~x+z", NA, "~x", "~."))
	expect_equal(out$disp, c("(A)", "~1", "(B)", "", "(A)", "~."))
	expect_equal(out$key, c("~x" = "A", "~x+z" = "B"))
	none <- f(list("~1", "~."))
	expect_equal(none$disp, c("~1", "~.")); expect_length(none$key, 0L)
	expect_equal(f(list())$disp, character(0))
	many <- f(as.list(paste0("~x", 1:3)))
	expect_equal(many$disp, c("(A)", "(B)", "(C)")); expect_equal(unname(many$key), c("A", "B", "C"))
})

test_that("design short labels: '<algorithm> Seq (one by one)' / '<algorithm> Fixed', with a wordified fallback", {
	f <- Z("design_class_short_label")
	expect_equal(f("DesignSeqOneByOneKK14"), "KK14 Seq (one by one)")
	expect_equal(f("DesignSeqOneByOneBernoulli"), "Bernoulli Seq (one by one)")
	expect_equal(f("DesignFixediBCRD"), "iBCRD Fixed")
	expect_equal(f("DesignFixedOptimalBlocks"), "OptimalBlocks Fixed")
	expect_equal(f("DesignFixedBlockedCluster"), "BlockedCluster Fixed")
	expect_equal(f("Bernoulli"), Z("inference_class_wordify")("Bernoulli"))             # neither prefix: wordified name
	expect_equal(vapply(c("DesignFixedA", "DesignFixedB"), f, character(1), USE.NAMES = FALSE), c("A Fixed", "B Fixed"))
})

disc_design <- function(kind = "ibcrd", n = 30L) {
	set.seed(1)
	des <- if (kind == "bern") DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE) else
		DesignFixediBCRD$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n))); des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(n)); des
}

test_that("class discovery is sorted, agrees with the design's public listing, and the wrappers return its three parts", {
	des <- disc_design()
	r <- Z("discover_applicable_inference_classes")(des)
	expect_named(r, c("applicable", "unavailable_due_to_missing_packages", "incompatible_due_to_design_structure"))
	expect_identical(r$applicable, sort(r$applicable))
	expect_identical(r$applicable, des$applicable_inference_class_names())
	expect_identical(Z("applicable_inference_class_names_for_design")(des), r$applicable)
	expect_identical(Z("unavailable_inference_classes_due_to_missing_packages_for_design")(des), r$unavailable_due_to_missing_packages)
	expect_identical(Z("incompatible_inference_classes_due_to_design_structure_for_design")(des), r$incompatible_due_to_design_structure)
	expect_false(anyDuplicated(r$applicable) > 0)
	reg <- Z("inference_class_registry_as_list")()
	expect_true(all(vapply(r$applicable, function(nm) isTRUE(reg[[nm]]$exported) && !isTRUE(reg[[nm]]$abstract), logical(1))))
	expect_true("InferenceAllSimpleAverageDiff" %in% r$applicable)
	expect_false(any(grepl("Abstract", r$applicable)))
})

test_that("a design that does not fit a class puts it in the incompatible list with a reason, not in the applicable one", {
	bern <- disc_design("bern")
	r <- Z("discover_applicable_inference_classes")(bern)
	# Exact Fisher needs iBCRD / blocking / matching; a Bernoulli design is refused.
	expect_true("InferenceIncidExactFisher" %in% names(Z("discover_applicable_inference_classes")({
		set.seed(1); d <- DesignFixedBernoulli$new(n = 30L, response_type = "incidence", verbose = FALSE)
		d$add_all_subjects_to_experiment(data.frame(x = rnorm(30))); d$assign_w_to_all_subjects(); d$add_all_subject_responses(rbinom(30, 1, 0.5)); d
	})$incompatible_due_to_design_structure))
	for (nm in names(r$incompatible_due_to_design_structure)) {
		expect_false(nm %in% r$applicable, info = nm)
		expect_true(is.character(r$incompatible_due_to_design_structure[[nm]]) && nzchar(r$incompatible_due_to_design_structure[[nm]]), info = nm)
	}
	expect_identical(names(r$incompatible_due_to_design_structure), sort(names(r$incompatible_due_to_design_structure)))
	# Missing optional packages move a class from applicable to unavailable (simulated by stubbing the probe).
	orig <- Z("missing_required_packages_for_inference_class")
	ns <- asNamespace("EDI")
	unlockBinding("missing_required_packages_for_inference_class", ns)
	assign("missing_required_packages_for_inference_class", function(nm) if (nm == "InferenceContinLin") "fakepkg" else character(), envir = ns)
	on.exit({ assign("missing_required_packages_for_inference_class", orig, envir = ns); lockBinding("missing_required_packages_for_inference_class", ns) }, add = TRUE)
	r2 <- Z("discover_applicable_inference_classes")(disc_design())
	expect_false("InferenceContinLin" %in% r2$applicable)
	expect_equal(r2$unavailable_due_to_missing_packages$InferenceContinLin, "fakepkg")
})
