library(testthat)
library(EDI)

make_all_param_boot_fixed_design <- function(response_type, variant = "default", seed = 20260817L, n = 96L){
	set.seed(seed)
	x1 <- rnorm(n)
	x2 <- rnorm(n)
	w <- rep(c(1, 0), length.out = n)
	des <- DesignFixedBernoulli$new(n = n, response_type = response_type, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = x1, x2 = x2))
	des$overwrite_all_subject_assignments(w)

	y <- switch(
		response_type,
		continuous = 0.45 * w + 0.30 * x1 - 0.20 * x2 + rnorm(n, sd = 0.85),
		count = {
			mu <- exp(0.35 + 0.25 * w + 0.20 * x1 - 0.10 * x2)
			positive <- pmax(1L, rnbinom(n, mu = mu, size = 2.5))
			ifelse(rbinom(n, 1L, plogis(0.35 + 0.20 * w - 0.15 * x1)) == 1L, positive, 0L)
		},
		incidence = rbinom(n, 1L, plogis(-0.35 + 0.55 * w + 0.25 * x1 - 0.15 * x2)),
		ordinal = {
			eta <- 0.40 * w + 0.25 * x1 - 0.15 * x2
			cuts <- cbind(plogis(-1.05 - eta), plogis(-0.05 - eta), plogis(0.95 - eta))
			u <- runif(n)
			ifelse(u <= cuts[, 1L], 1L, ifelse(u <= cuts[, 2L], 2L, ifelse(u <= cuts[, 3L], 3L, 4L)))
		},
		proportion = {
			mu <- plogis(-0.25 + 0.40 * w + 0.25 * x1 - 0.15 * x2)
			interior <- rbeta(n, pmax(1.5, 10 * mu), pmax(1.5, 10 * (1 - mu)))
			if (identical(variant, "zero_one")) {
				boundary <- seq_len(n) %% 12L
				interior[boundary == 0L] <- 0
				interior[boundary == 1L] <- 1
			}
			interior
		},
		survival = rexp(n, rate = exp(-0.20 + 0.20 * w + 0.15 * x1 - 0.10 * x2)),
		stop("Unsupported response type: ", response_type, call. = FALSE)
	)
	des$add_all_subject_responses(y)
	des
}

make_all_param_boot_kk_design <- function(response_type, seed = 20260818L, n = 72L){
	set.seed(seed)
	x1 <- rnorm(n)
	x2 <- rnorm(n)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = response_type, verbose = FALSE)
	for (i in seq_len(n)) {
		w_i <- des$add_one_subject_to_experiment_and_assign(data.frame(x1 = x1[i], x2 = x2[i]))
		y_i <- switch(
			response_type,
			continuous = 0.45 * w_i + 0.30 * x1[i] - 0.20 * x2[i] + rnorm(1L, sd = 0.85),
			count = {
				mu_i <- exp(0.35 + 0.25 * w_i + 0.20 * x1[i] - 0.10 * x2[i])
				if (rbinom(1L, 1L, 0.70) == 1L) pmax(1L, rpois(1L, mu_i)) else 0L
			},
			incidence = rbinom(1L, 1L, plogis(-0.30 + 0.55 * w_i + 0.25 * x1[i] - 0.15 * x2[i])),
			ordinal = {
				eta_i <- 0.40 * w_i + 0.25 * x1[i] - 0.15 * x2[i]
				cuts <- plogis(c(-1.05, -0.05, 0.95) - eta_i)
				u <- runif(1L)
				if (u <= cuts[1L]) 1L else if (u <= cuts[2L]) 2L else if (u <= cuts[3L]) 3L else 4L
			},
			proportion = {
				mu_i <- plogis(-0.25 + 0.40 * w_i + 0.25 * x1[i] - 0.15 * x2[i])
				rbeta(1L, pmax(1.5, 10 * mu_i), pmax(1.5, 10 * (1 - mu_i)))
			},
			survival = rexp(1L, rate = exp(-0.20 + 0.20 * w_i + 0.15 * x1[i] - 0.10 * x2[i])),
			stop("Unsupported response type: ", response_type, call. = FALSE)
		)
		des$add_one_subject_response(i, y_i)
	}
	des
}

all_param_boot_case <- function(response_type, kk = FALSE, variant = "default", constructor_args = list()){
	list(
		make_design = if (kk) {
			function(seed) make_all_param_boot_kk_design(response_type, seed = seed)
		} else {
			function(seed) make_all_param_boot_fixed_design(response_type, variant = variant, seed = seed)
		},
		constructor_args = constructor_args
	)
}

all_param_boot_smoke_cases <- list(
	InferenceContinKKGLMM = all_param_boot_case("continuous", kk = TRUE, constructor_args = list(model_formula = ~ x1 + x2, use_rcpp = TRUE, verbose = FALSE)),
	InferenceContinKKOLSOneLik = all_param_boot_case("continuous", kk = TRUE, constructor_args = list(model_formula = ~ x1 + x2, verbose = FALSE)),
	InferenceContinLin = all_param_boot_case("continuous", constructor_args = list(model_formula = ~ x1 + x2, verbose = FALSE)),
	InferenceContinOLS = all_param_boot_case("continuous", constructor_args = list(model_formula = ~ x1 + x2, verbose = FALSE)),
	InferenceCountHurdleNegBin = all_param_boot_case("count", constructor_args = list(model_formula = ~ x1 + x2, verbose = FALSE)),
	InferenceCountHurdlePoisson = all_param_boot_case("count", constructor_args = list(model_formula = ~ x1 + x2, use_rcpp = TRUE, verbose = FALSE)),
	InferenceCountKKCondPoissonOneLik = all_param_boot_case("count", kk = TRUE, constructor_args = list(model_formula = ~ x1 + x2, verbose = FALSE)),
	InferenceCountKKGLMM = all_param_boot_case("count", kk = TRUE, constructor_args = list(model_formula = ~ x1 + x2, use_rcpp = TRUE, verbose = FALSE)),
	InferenceCountKKHurdlePoissonOneLik = all_param_boot_case("count", kk = TRUE, constructor_args = list(model_formula = ~ x1 + x2, use_rcpp = TRUE, verbose = FALSE)),
	InferenceCountNegBin = all_param_boot_case("count", constructor_args = list(model_formula = ~ x1 + x2, verbose = FALSE)),
	InferenceCountPoisson = all_param_boot_case("count", constructor_args = list(model_formula = ~ x1 + x2, verbose = FALSE)),
	InferenceCountZeroInflatedNegBin = all_param_boot_case("count", constructor_args = list(model_formula = ~ x1 + x2, use_rcpp = TRUE, verbose = FALSE)),
	InferenceCountZeroInflatedPoisson = all_param_boot_case("count", constructor_args = list(model_formula = ~ x1 + x2, use_rcpp = TRUE, verbose = FALSE)),
	InferenceIncidBinomialIdentityRiskDiff = all_param_boot_case("incidence", constructor_args = list(model_formula = ~ x1 + x2, verbose = FALSE)),
	InferenceIncidKKCondLogitOneLik = all_param_boot_case("incidence", kk = TRUE, constructor_args = list(model_formula = ~ x1 + x2, verbose = FALSE)),
	InferenceIncidKKModifiedPoisson = all_param_boot_case("incidence", kk = TRUE, constructor_args = list(model_formula = ~ x1 + x2, verbose = FALSE)),
	InferenceIncidLogBinomial = all_param_boot_case("incidence", constructor_args = list(model_formula = ~ x1 + x2, verbose = FALSE)),
	InferenceIncidLogRegr = all_param_boot_case("incidence", constructor_args = list(model_formula = ~ x1 + x2, verbose = FALSE)),
	InferenceIncidProbitRegr = all_param_boot_case("incidence", constructor_args = list(model_formula = ~ x1 + x2, verbose = FALSE)),
	InferenceOrdinalAdjCatLogitRegr = all_param_boot_case("ordinal", constructor_args = list(model_formula = ~ x1 + x2, verbose = FALSE)),
	InferenceOrdinalCauchitRegr = all_param_boot_case("ordinal", constructor_args = list(model_formula = ~ x1 + x2, verbose = FALSE)),
	InferenceOrdinalCloglogRegr = all_param_boot_case("ordinal", constructor_args = list(model_formula = ~ x1 + x2, verbose = FALSE)),
	InferenceOrdinalContRatioRegr = all_param_boot_case("ordinal", constructor_args = list(model_formula = ~ x1 + x2, verbose = FALSE)),
	InferenceOrdinalKKGLMM = all_param_boot_case("ordinal", kk = TRUE, constructor_args = list(model_formula = ~ x1 + x2, use_rcpp = TRUE, verbose = FALSE)),
	InferenceOrdinalOrderedProbitRegr = all_param_boot_case("ordinal", constructor_args = list(model_formula = ~ x1 + x2, verbose = FALSE)),
	InferenceOrdinalPropOddsRegr = all_param_boot_case("ordinal", constructor_args = list(model_formula = ~ x1 + x2, verbose = FALSE)),
	InferenceOrdinalStereotypeLogitRegr = all_param_boot_case("ordinal", constructor_args = list(model_formula = ~ x1 + x2, verbose = FALSE)),
	InferencePropBetaRegr = all_param_boot_case("proportion", constructor_args = list(model_formula = ~ x1 + x2, verbose = FALSE)),
	InferencePropKKGLMM = all_param_boot_case("proportion", kk = TRUE, constructor_args = list(model_formula = ~ x1 + x2, verbose = FALSE)),
	InferencePropZeroOneInflatedBetaRegr = all_param_boot_case("proportion", variant = "zero_one", constructor_args = list(model_formula = ~ x1 + x2, verbose = FALSE)),
	InferenceSurvivalDepCensTransformRegr = all_param_boot_case("survival", constructor_args = list(model_formula = ~ x1 + x2, verbose = FALSE)),
	InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik = all_param_boot_case("survival", kk = TRUE, constructor_args = list(model_formula = ~ x1 + x2, verbose = FALSE)),
	InferenceSurvivalKKLWACoxPHOneLik = all_param_boot_case("survival", kk = TRUE, constructor_args = list(model_formula = ~ x1 + x2, verbose = FALSE)),
	InferenceSurvivalKKStratCoxPHOneLik = all_param_boot_case("survival", kk = TRUE, constructor_args = list(model_formula = ~ x1 + x2, verbose = FALSE)),
	InferenceSurvivalGLMMWeibullFrailtyNormalOneLik = all_param_boot_case("survival", kk = TRUE, constructor_args = list(model_formula = ~ x1 + x2, use_rcpp = TRUE, verbose = FALSE)),
	InferenceSurvivalWeibullRegr = all_param_boot_case("survival", constructor_args = list(model_formula = ~ x1 + x2, verbose = FALSE))
)

test_that("every concrete parametric-likelihood-bootstrap class has a finite smoke case", {
	registry <- EDI:::inference_class_registry_as_list()
	capable <- sort(names(Filter(function(metadata) {
		!isTRUE(metadata$abstract) &&
			"parametric_likelihood_bootstrap" %in% EDI:::get_effective_capabilities(metadata$name)
	}, registry)))
	expect_identical(sort(names(all_param_boot_smoke_cases)), capable)
})

test_that("legacy runtime opt-outs do not advertise parametric likelihood bootstrap", {
	legacy_opt_outs <- names(EDI:::EDI_INFERENCE_LEGACY_EXCLUDED_CAPABILITIES)
	# InferenceIncidKKGCompRiskDiff/RiskRatio removed 2026-08-18: migrated to
	# define_inference_class() composing IncidenceKKGComputation (tier
	# "none"), so they no longer accidentally inherit
	# parametric_likelihood_bootstrap at all -- the transitional exclusion
	# entry is no longer needed (per this table's own removal instruction).
	expect_setequal(
		legacy_opt_outs,
		c(
			"InferenceIncidKKCondLogitGLMMIVWC",
			"InferenceIncidKKCondLogitGLMMOneLik",
			"InferenceIncidModifiedPoisson"
		)
	)
	for (class_name in legacy_opt_outs) {
		expect_false(
			"parametric_likelihood_bootstrap" %in% EDI:::get_effective_capabilities(class_name),
			info = class_name
		)
	}
})

for (case_index in seq_along(all_param_boot_smoke_cases)) {
	class_name <- names(all_param_boot_smoke_cases)[case_index]
	case <- all_param_boot_smoke_cases[[case_index]]
	test_that(paste(class_name, "returns a finite parametric-bootstrap LR p-value"), {
		des <- case$make_design(20260817L + case_index)
		generator <- getExportedValue("EDI", class_name)
		inf <- do.call(generator$new, c(list(des), case$constructor_args))
		priv <- inf$.__enclos_env__$private
		supports_param_boot <- isTRUE(priv$supports_lik_ratio_param_bootstrap())
		expect_true(supports_param_boot, info = class_name)
		if (!supports_param_boot) return(invisible(NULL))

		inf$set_seed(20260917L + case_index)
		inf$num_cores <- 1L
		p_boot <- inf$compute_lik_ratio_bootstrap_two_sided_pval(
			delta = 0,
			B = 2L,
			show_progress = FALSE,
			min_number_usable_samples = 1L,
			max_attempts_per_replicate = 3L
		)
		diagnostics <- inf$get_last_param_bootstrap_diagnostics()

		expect_true(is.finite(p_boot), info = class_name)
		expect_true(p_boot >= 0, info = class_name)
		expect_true(p_boot <= 1, info = class_name)
		expect_true(is.list(diagnostics), info = class_name)
		expect_equal(diagnostics$B, 2L, info = class_name)
		expect_true(diagnostics$n_success >= 1L, info = class_name)
	})
}
