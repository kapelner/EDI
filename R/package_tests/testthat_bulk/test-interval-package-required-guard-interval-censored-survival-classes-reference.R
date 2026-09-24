library(testthat)
library(EDI)

# assert_interval_installed(caller) (helper_package_checks.R) guards every left-/interval-
# censored survival code path that dispatches through interval::icfit()/interval::ictest()
# (InferenceSurvivalKMDiff, InferenceSurvivalGehanWilcox, InferenceSurvivalRestrictedMeanDiff,
# InferenceSurvivalLogRank -- all four call sites confirmed by grep). Distinct from the
# ordinary check_package_installed() guard family closed earlier this session, this one adds
# Bioconductor-specific install instructions (interval depends on Icens, which
# install.packages() alone cannot resolve). A codebase-wide grep confirmed the exact message
# had zero test references anywhere, even though the general-censoring code paths that call it
# are otherwise well exercised. Exercised via the same with_mocked_bindings(check_package_
# installed = ..., .package = "EDI") technique already established in this suite's other
# package-required guard tests, on the same interval-censored fixture used by the sibling file
# test-km-diff-general-censoring-bayesian-bootstrap-and-log-rank-convenience-method-rejected-
# reference.R (which covers KMDiff's OTHER two general-censoring guards, not this one).

ic_fx <- function(seed = 3006L, n = 60L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	yL <- runif(n, 0, 3); yR <- yL + runif(n, 0.5, 3)
	des$add_all_subject_responses(ys = rep(NA_real_, n), y_Ls = yL, y_Rs = yR)
	des
}

test_that("InferenceSurvivalKMDiff under general censoring refuses with the Bioconductor-aware 'interval' package guard when the package is unavailable", {
	des <- ic_fx()
	inf <- InferenceSurvivalKMDiff$new(des, verbose = FALSE)
	expect_true(inf$.__enclos_env__$private$has_general_censoring)

	with_mocked_bindings(
		check_package_installed = function(pkg) FALSE,
		.package = "EDI",
		{
			expect_error(
				inf$compute_estimate(),
				"Package 'interval' is required for InferenceSurvivalKMDiff. It depends on Bioconductor's 'Icens' package",
				fixed = TRUE
			)
		}
	)
})
