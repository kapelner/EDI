library(testthat)
library(EDI)

# get_covariate_names() (colnames(X), falling back to x1..xp when unnamed) is copy-pasted
# identically across five gcomp/marginal-incidence source files (inference_incidence_KK_marginal_
# abstract.R, inference_incidence_KK_gcomp_abstract.R, inference_incidence_gcomp_abstract.R,
# inference_ordinal_gcomp.R, inference_proportion_gcomp.R). Only the KK-marginal-incidence copy
# had a direct test (test-kk-marginal-incid-cluster-id-cache-and-covariate-names-reference.R); the
# inference_incidence_KK_gcomp_abstract.R copy is only ever mentioned in a comment (test-incid-kk-
# gcomp-migration-golden.R), never called directly, and this non-KK inference_incidence_gcomp_
# abstract.R copy (backing InferenceIncidGCompRiskDiff/RiskRatio) had zero references anywhere --
# existing coverage on these classes never stubs private$get_X() to exercise the unnamed-column
# fallback branch. (inference_ordinal_gcomp.R's InferenceOrdinalGCompMeanDiff and inference_
# proportion_gcomp.R are both left alone here: the former is the exact class implicated in the
# active reused-worker-cache bug investigation, and the latter is on this session's closed list.)

make_gcomp_covariate_names_fixture <- function(cls_name, seed = 1L, n = 20L) {
	set.seed(seed)
	X <- data.frame(x1 = rnorm(n), x2 = runif(n))
	des <- DesignFixedBernoulli$new(response_type = "incidence", n = n, seed = 1L, verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	des$add_all_subject_responses(rbinom(n, 1, plogis(-0.3 + 0.8 * w)))
	inf <- get(cls_name, envir = asNamespace("EDI"))$new(des, verbose = FALSE)
	list(inf = inf, priv = inf$.__enclos_env__$private)
}

for (cls in c("InferenceIncidGCompRiskDiff", "InferenceIncidGCompRiskRatio")) {
	local({
		cls_name <- cls
		test_that(paste0(cls_name, "$get_covariate_names() returns the design matrix's own colnames"), {
			f <- make_gcomp_covariate_names_fixture(cls_name)
			expect_equal(f$priv$get_covariate_names(), c("x1", "x2"))
		})

		test_that(paste0(cls_name, "$get_covariate_names() falls back to x1..xp when the design matrix has no colnames"), {
			f <- make_gcomp_covariate_names_fixture(cls_name)
			unlockBinding("get_X", f$priv)
			f$priv$get_X <- function() matrix(0, nrow = 5, ncol = 3)
			expect_equal(f$priv$get_covariate_names(), c("x1", "x2", "x3"))
			f$priv$get_X <- function() matrix(0, nrow = 5, ncol = 2, dimnames = list(NULL, c("a", "b")))
			expect_equal(f$priv$get_covariate_names(), c("a", "b"))
		})
	})
}
