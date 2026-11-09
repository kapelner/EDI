# Shared core of the published monthly calibration study (release_v1_2_0.md
# TODO-36; workflow .github/workflows/calibration-study.yml). Builds on
# calibration_fast_tier_common.R (response models, task runner, null values) and
# changes three things:
#
#   * p = 5 covariates: x1-x3 ~ N(0, 1) and x4, x5 two-level factors (levels
#     "0"/"1", P = 0.5). The linear predictor CAL_STUDY_COEF * (x1 + x2 + x3 + x4 + x5)
#     has variance 1, i.e. it explains about half the variance of the continuous
#     outcome. Formulas stay `~ 1` (w only) and `~ .` (w + all covariates).
#   * 21 designs (CAL_STUDY_DESIGNS), every exported one except the cluster and
#     factorial designs, plus Bernoulli at prob_T = 0.2.
#   * potential outcomes. y(0) and y(1) are drawn from the same random numbers
#     BEFORE treatment is assigned; the design then reveals y(w). Sequential
#     designs that use earlier responses (KK21) get each response right after its
#     assignment, and every design in a replicate sees the same subjects and
#     outcomes (common random numbers across designs and effect sizes).
#
# Under effect = 0, y(0) = y(1), so the sharp null holds on every design and every
# estimand sits at the class's null value, as in the fast tier.
#
# The pre-push calibration check keeps the fast tier's p = 2 data and seeds.

script_dir_study <- if (exists("script_dir")) script_dir else dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L])))
source(file.path(script_dir_study, "calibration_fast_tier_common.R"))

CAL_STUDY_P <- 5L
CAL_STUDY_COEF <- 1 / sqrt(3 + 2 * 0.25)

# Tier-1 procedures (release_v1_2_0.md TODO-36 table). `rand` is p-value only
# here; its CI is tier 2. lik_ratio_bartlett_approx is tier 2: measured
# 2026-11-09 it is 60-90% of a tier-1 replicate (18 of 32 s continuous, 77 of
# 84 s incidence, n = 50), not analytic-cheap.
CAL_STUDY_TIER1_METHODS <- c("wald", "score", "lik_ratio", "gradient", "exact", "rand")
CAL_STUDY_TIER1_PVAL_ONLY <- "rand"

# Design label -> constructor extras. A label "<Design>@prob_T=<p>" runs <Design>
# at prob_T = p (cal_plan_entry()).
CAL_STUDY_STRATA <- c("x4", "x5")
CAL_STUDY_DESIGNS <- c(
	"DesignFixedBernoulli", "DesignFixedBernoulli@prob_T=0.2", "DesignFixediBCRD", "DesignFixedBlocking",
	"DesignFixedRerandomization", "DesignFixedMatchingGreedyPairSwitching", "DesignFixedOptimal",
	"DesignFixedBinaryMatch", "DesignFixedGreedy", "DesignFixedGreedyDOptimal", "DesignFixedOptimalBlocks",
	"DesignSeqOneByOneBernoulli", "DesignSeqOneByOneiBCRD", "DesignSeqOneByOneEfron", "DesignSeqOneByOneAtkinson",
	"DesignSeqOneByOnePocockSimon", "DesignSeqOneByOneRandomBlockSize", "DesignSeqOneByOneSPBR",
	"DesignSeqOneByOneUrn", "DesignSeqOneByOneKK14", "DesignSeqOneByOneKK21", "DesignSeqOneByOneKK21stepwise"
)

cal_study_design_extras <- function(design_name) {
	switch(design_name,
		DesignFixedBlocking = list(strata_cols = CAL_STUDY_STRATA, equal_block_sizes = FALSE),
		DesignSeqOneByOnePocockSimon = , DesignSeqOneByOneRandomBlockSize = , DesignSeqOneByOneSPBR =
			list(strata_cols = CAL_STUDY_STRATA),
		list()
	)
}

# The n a design actually runs at: pair-switching needs n divisible by 4 (50 -> 52).
cal_study_effective_n <- function(design_label, n) {
	if (identical(cal_plan_entry(design_label)$design, "DesignFixedMatchingGreedyPairSwitching") && n %% 4L != 0L)
		n + (4L - n %% 4L) else as.integer(n)
}

cal_study_gen_X <- function(n) {
	data.frame(x1 = stats::rnorm(n), x2 = stats::rnorm(n), x3 = stats::rnorm(n),
		x4 = factor(stats::rbinom(n, 1L, 0.5), levels = 0:1), x5 = factor(stats::rbinom(n, 1L, 0.5), levels = 0:1))
}

cal_study_base_eta <- function(X) {
	CAL_STUDY_COEF * (X$x1 + X$x2 + X$x3 + (as.integer(X$x4) - 1L) + (as.integer(X$x5) - 1L))
}

# Effects: local alternatives beta_T = ncp * se_sqrt_n / (slope * sqrt(n)), with
# se_sqrt_n = SD of the baseline class's estimate x sqrt(n) under the null and
# slope = d(estimand) / d(effect) for that class (count: mu = exp(0.5 + 0.6 eta),
# so the log rate ratio moves 0.6 per unit effect). ncp 1.12 / 1.96 / 2.80 give a
# two-sided 5% z-test about 20 / 50 / 80% power. calibration_study_effects.csv
# holds se_sqrt_n per response type (calibrate_study_effects.R).
CAL_STUDY_EFFECT_NCP <- c(null = 0, power20 = 1.12, power50 = 1.96, power80 = 2.80)

cal_study_effects_table <- function() {
	utils::read.csv(file.path(script_dir_study, "calibration_study_effects.csv"), stringsAsFactors = FALSE)
}

cal_study_effect <- function(response_type, n, effect_label, effects = cal_study_effects_table()) {
	ncp <- CAL_STUDY_EFFECT_NCP[[effect_label]]
	if (ncp == 0) return(0)
	row <- effects[effects$response_type == response_type, ]
	if (nrow(row) != 1L) stop("no effect calibration for response type ", response_type)
	ncp * row$se_sqrt_n / (row$slope * sqrt(n))
}

# Potential outcomes: two draws of cal_gen_y() from the same RNG state, one with
# everyone untreated and one with everyone treated. Returns list(y0, y1), each in
# cal_gen_y()'s shape (ys, plus y_Ls / y_Rs for survival).
cal_study_potential_outcomes <- function(response_type, X, effect, dgp = "default") {
	n <- nrow(X)
	eta <- cal_study_base_eta(X)
	if (!exists(".Random.seed", envir = globalenv())) stats::runif(1L)
	state <- get(".Random.seed", envir = globalenv())
	y0 <- cal_gen_y(response_type, X, rep(0L, n), effect, dgp = dgp, base_eta = eta)
	assign(".Random.seed", state, envir = globalenv())
	y1 <- cal_gen_y(response_type, X, rep(1L, n), effect, dgp = dgp, base_eta = eta)
	list(y0 = y0, y1 = y1)
}

cal_study_pick <- function(a, b, take_b) {
	if (is.factor(a)) {
		v <- ifelse(take_b, as.integer(b), as.integer(a))
		return(factor(levels(a)[v], levels = levels(a), ordered = is.ordered(a)))
	}
	ifelse(take_b, b, a)
}

# Builds and runs one design on (X, potential outcomes): fixed designs assign
# everyone, then get y(w); sequential designs get each subject's y(w_t) right after
# its assignment.
cal_study_run_design <- function(design_label, response_type, X, po) {
	entry <- cal_plan_entry(design_label)
	n <- nrow(X)
	gen <- get(entry$design, envir = asNamespace("EDI"))
	args <- c(list(n = n, response_type = response_type), cal_study_design_extras(entry$design))
	if (!isTRUE(entry$prob_T == 0.5)) args$prob_T <- entry$prob_T
	des <- do.call(gen$new, args)
	fields <- names(po$y0)
	if (inherits(des, "DesignSeqOneByOne")) {
		for (t in seq_len(n)) {
			w_t <- des$add_one_subject_to_experiment_and_assign(X[t, , drop = FALSE])
			resp <- lapply(fields, function(f) cal_study_pick(po$y0[[f]][t], po$y1[[f]][t], w_t == 1L))
			names(resp) <- fields
			EDI:::add_bounded_response_to_design(des, t,
				list(y = resp$ys %||% NA, y_L = resp$y_Ls %||% NA, y_R = resp$y_Rs %||% NA))
		}
	} else {
		des$add_all_subjects_to_experiment(X)
		des$assign_w_to_all_subjects()
		w <- des$get_w()
		resp <- lapply(fields, function(f) cal_study_pick(po$y0[[f]], po$y1[[f]], w == 1L))
		names(resp) <- fields
		do.call(des$add_all_subject_responses, resp)
	}
	des
}

cal_study_rt_index <- function(response_type) match(response_type, CAL_RESPONSE_TYPES)

# Seed for a replicate's subjects and potential outcomes: depends on (response
# type, n, rep) only, so every design and every effect size of a replicate share
# them. Unique for n < 20000 and rep < 10000.
cal_study_seed <- function(response_type, n, rep) {
	as.integer(cal_study_rt_index(response_type) * 2e8 + n * 1e4 + rep)
}

# One replicate of one (response type, design, n, effect) unit. `classes`: the
# classes to run (cal_study_classes()). Returns rows in cal_run_tasks()' shape plus
# the unit's columns.
cal_study_run_rep <- function(response_type, design_label, n_nominal, effect_label, rep, classes,
		methods = CAL_STUDY_TIER1_METHODS, pval_only = CAL_STUDY_TIER1_PVAL_ONLY, effects = cal_study_effects_table()) {
	n <- cal_study_effective_n(design_label, n_nominal)
	effect <- cal_study_effect(response_type, n_nominal, effect_label, effects)
	dgps <- cal_class_dgp(classes)
	tab <- NULL
	for (dgp in unique(dgps)) {
		set.seed(cal_study_seed(response_type, n, rep))
		X <- cal_study_gen_X(n)
		po <- cal_study_potential_outcomes(response_type, X, cal_dgp_effect(effect, dgp), dgp = dgp)
		des <- cal_study_run_design(design_label, response_type, X, po)
		tab <- rbind(tab, cal_run_tasks(des, classes[dgps == dgp], methods = methods, pval_only = pval_only))
	}
	if (is.null(tab)) return(NULL)
	entry <- cal_plan_entry(design_label)
	tab$response_type <- response_type
	tab$design <- entry$design
	tab$prob_T <- entry$prob_T
	tab$n <- n
	tab$n_nominal <- as.integer(n_nominal)
	tab$p <- CAL_STUDY_P
	tab$rep <- rep
	tab$effect_label <- effect_label
	tab$effect <- effect
	tab
}

# Classes applicable to a design for one response type, from the installed
# package's registry, on a throwaway replicate of that design.
cal_study_classes <- function(response_type, design_label, n_nominal) {
	n <- cal_study_effective_n(design_label, n_nominal)
	set.seed(1L)
	X <- cal_study_gen_X(n)
	des <- cal_study_run_design(design_label, response_type, X, cal_study_potential_outcomes(response_type, X, 0))
	sort(EDI:::applicable_inference_class_names_for_design(des))
}
