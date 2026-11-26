library(testthat)
library(EDI)

# v1.0.6-TODO-177 (docs-scenarios sequential-designs F3): KK14 / KK21 / KK21stepwise accepted
# lambda and t_0_pct outside [0, 1] (and NA). KK14 then failed a third of the way into the trial with
# "NaNs produced" from qf(), KK21 with "'probs' outside [0,1]", and t_0_pct = 1.5 never matched.

kk_classes = c("DesignSeqOneByOneKK14", "DesignSeqOneByOneKK21", "DesignSeqOneByOneKK21stepwise")

test_that("bad lambda and t_0_pct values error at $new() on every KK class", {
	for (cls in kk_classes) {
		for (bad in list(-1, -1e-9, 1 + 1e-9, 1.5, 2, NA_real_, c(0.1, 0.2), "0.1")) {
			expect_error(get(cls)$new(response_type = "continuous", n = 30, lambda = bad, verbose = FALSE),
				"lambda must be", info = paste(cls, format(bad)))
		}
		for (bad in list(-0.2, 1.5, NA_real_, c(0.1, 0.2))) {
			expect_error(get(cls)$new(response_type = "continuous", n = 30, t_0_pct = bad, verbose = FALSE),
				"t_0_pct must be", info = paste(cls, format(bad)))
		}
	}
})

test_that("valid lambda and t_0_pct values still construct and run, and the defaults are unchanged", {
	set.seed(5)
	n = 30L
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
	run = function(cls, ...) {
		d = get(cls)$new(response_type = "continuous", n = n, seed = 9, verbose = FALSE, ...)
		vapply(seq_len(n), function(i) as.numeric(d$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])), numeric(1))
	}
	for (cls in kk_classes) {
		expect_identical(run(cls), run(cls, lambda = 0.1, t_0_pct = 0.35), info = cls)
		expect_length(run(cls, lambda = 0.5, t_0_pct = 0), n)
		expect_length(run(cls, lambda = 0.01, t_0_pct = 1), n)
		# the endpoints are legal: lambda = 0 never matches, lambda = 1 matches whenever it can
		expect_length(run(cls, lambda = 0), n)
		expect_length(run(cls, lambda = 1), n)
	}
})
