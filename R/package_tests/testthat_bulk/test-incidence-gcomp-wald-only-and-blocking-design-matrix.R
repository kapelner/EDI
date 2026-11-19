library(testthat)
library(EDI)

# docs-claims audit:
#   docs-claims-d6bc838fa InferenceIncidGCompRiskDiff and
#   docs-claims-df0598ae7 InferenceIncidGCompRiskRatio:
#   - likelihood_tier "none": no likelihood-ratio or score tests, Wald still available;
#   - on a blocking design no block fixed effects are added to the working
#     model, while randomization and jackknife inference are block-aware.

gcomp_classes <- list(RD = InferenceIncidGCompRiskDiff, RR = InferenceIncidGCompRiskRatio)

test_that("gcomp RD / RR: likelihood_tier 'none', Wald-only testing types, no LR / score methods", {
	set.seed(3); n <- 30L
	des <- DesignFixedBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rbinom(n, 1, 0.4))
	for (nm in names(gcomp_classes)) {
		cls <- gcomp_classes[[nm]]
		expect_identical(get_inference_class_metadata(cls$classname)$likelihood_tier, "none", info = nm)
		inf <- cls$new(des, verbose = FALSE)
		expect_identical(inf$get_supported_testing_types(), "wald", info = nm)
		expect_length(grep("lik_ratio|score|gradient", names(inf), value = TRUE), 0L)
		expect_true(is.finite(inf$compute_asymp_two_sided_pval()), info = nm)
	}
})

test_that("gcomp RD / RR on DesignFixedBlocking(m = ...): no block columns in the design matrix; randomization and jackknife are block-aware", {
	set.seed(5); n <- 24L
	blocks <- rep(1:4, each = 6)
	des <- DesignFixedBlocking$new(n = n, response_type = "incidence", m = blocks, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n), x2 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rbinom(n, 1, 0.5))
	expect_identical(as.integer(des$get_block_ids()), blocks)
	# the design's randomization draws keep each block's treated count
	set.seed(1)
	W <- des$draw_ws_according_to_design(5L)
	tab_obs <- tapply(des$get_w(), blocks, sum)
	for (j in seq_len(ncol(W))) expect_identical(tapply(W[, j], blocks, sum), tab_obs)
	for (nm in names(gcomp_classes)) {
		inf <- gcomp_classes[[nm]]$new(des, verbose = FALSE)
		p <- inf$.__enclos_env__$private
		expect_identical(colnames(p$build_design_matrix()), c("(Intercept)", "treatment", "x1", "x2"), info = nm)
		# the jackknife deletes within blocks (stratified), not plain observations
		expect_identical(p$resolve_jackknife_unit("auto"), "observation_within_block", info = nm)
		expect_true(all(is.finite(inf$compute_jackknife_wald_confidence_interval())), info = nm)
	}
})
