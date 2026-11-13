# Shared core of the published monthly calibration study (release_v1_2_0.md
# TODO-36; workflow .github/workflows/calibration-study.yml). Builds on
# calibration_fast_tier_common.R (response models, task runner, null values) and
# changes three things:
#
#   * p = 5 covariates: x1-x3 ~ N(0, 1) and x4, x5 two-level factors (levels
#     "0"/"1", P = 0.5). The linear predictor CAL_STUDY_COEF * (x1 + x2 + x3 + x4 + x5)
#     has variance 1, i.e. it explains about half the variance of the continuous
#     outcome. Formulas stay `~ 1` (w only) and `~ .` (w + all covariates).
#   * the designs of cal_study_designs(): every exported concrete one except the cluster and
#     factorial designs (CAL_STUDY_EXCLUDED_DESIGNS), plus every one that supports unequal
#     allocation also at prob_T = 0.2.
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

# read.csv() calls in this file go through read_csv_fast(): fread-backed, same
# result as read.csv (R/package_tests/read_csv_fast.R), loaded from the checkout.
if (!exists("read_csv_fast", mode = "function")) local({
	script = sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
	for (d in c(getwd(), if (!is.na(script)) dirname(script))) {
		top = tryCatch(suppressWarnings(system2("git", c("-C", shQuote(d), "rev-parse", "--show-toplevel"), stdout = TRUE, stderr = FALSE)), error = function(e) character())
		helper = if (length(top)) file.path(top[1], "R", "package_tests", "read_csv_fast.R") else ""
		if (nzchar(helper) && file.exists(helper)) { sys.source(helper, envir = parent.env(environment())); break }
	}
	if (!exists("read_csv_fast", mode = "function")) stop("read_csv_fast.R not found: run from inside the EDI git checkout.", call. = FALSE)
})

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

# The study's designs are DISCOVERED from the installed EDI (v1.0.5 TODO-203 Amendments B and C), not listed:
# cal_study_designs() = every exported, concrete `Design*` R6 generator minus CAL_STUDY_EXCLUDED_DESIGNS, plus a
# `<Design>@prob_T=CAL_STUDY_UNEQUAL_PROB_T` label for every kept design whose registry capability
# `supports_unequal_allocation` is TRUE (the others run at prob_T = 0.5 only). A new design therefore enters the
# study by being exported; one that cannot run on the study's data fails the roster job loudly (the smoke check)
# until it gets cal_study_design_extras() or an exclusion here.
CAL_STUDY_UNEQUAL_PROB_T <- 0.2
CAL_STUDY_EXCLUDED_DESIGNS <- c(
	DesignFixedCluster = "needs cluster ids, which the study's data do not have",
	DesignFixedBlockedCluster = "needs cluster ids, which the study's data do not have",
	DesignFixedFactorial = "more than one treatment factor; the study has a single binary treatment"
)

# Display / run order of the KNOWN designs (sorting only, never membership): Fixed before Seq, then this order; a
# discovered design not listed here follows the known ones of its family, alphabetically.
CAL_STUDY_DESIGN_ORDER <- c(
	"DesignFixedBernoulli", "DesignFixediBCRD", "DesignFixedBlocking", "DesignFixedRerandomization",
	"DesignFixedMatchingGreedyPairSwitching", "DesignFixedOptimal", "DesignFixedBinaryMatch", "DesignFixedGreedy",
	"DesignFixedGreedyDOptimal", "DesignFixedOptimalBlocks",
	"DesignSeqOneByOneBernoulli", "DesignSeqOneByOneiBCRD", "DesignSeqOneByOneEfron", "DesignSeqOneByOneAtkinson",
	"DesignSeqOneByOnePocockSimon", "DesignSeqOneByOneRandomBlockSize", "DesignSeqOneByOneSPBR",
	"DesignSeqOneByOneUrn", "DesignSeqOneByOneKK14", "DesignSeqOneByOneKK21", "DesignSeqOneByOneKK21stepwise"
)

# Rank of design labels for sorting: the base design's position under (family Fixed < Seq < other, known before new,
# CAL_STUDY_DESIGN_ORDER, then alphabetical); the @prob_T variants of a design share its rank (the label breaks ties).
cal_study_design_rank <- function(labels) {
	base <- sub("@.*$", "", labels)
	ub <- unique(base)
	family <- ifelse(startsWith(ub, "DesignFixed"), 0L, ifelse(startsWith(ub, "DesignSeqOneByOne"), 1L, 2L))
	known <- match(ub, CAL_STUDY_DESIGN_ORDER)
	ub <- ub[order(family, is.na(known), known, ub)]
	match(base, ub)
}

# Whether the design class `design_name` supports unequal allocation: the package's own
# design_supports_unequal_allocation(), which takes a class NAME (or an instance) and errors on anything else.
# Shim for pre-fix builds (the installed EDI v1.0.4 and any build from an older sha), whose function answers TRUE for
# any string: if it says TRUE for a design known to refuse (Efron), read the registry directly. Remove the fallback
# once the fixed function is released.
cal_study_supports_unequal <- function(design_name) {
	ns <- asNamespace("EDI")
	f <- get("design_supports_unequal_allocation", envir = ns)
	if (isTRUE(f("DesignSeqOneByOneEfron"))) {
		reg <- get("EDI_DESIGN_CLASS_REGISTRY", envir = ns)
		return(exists(design_name, envir = reg, inherits = FALSE) &&
			isTRUE(get(design_name, envir = reg, inherits = FALSE)$supports_unequal_allocation))
	}
	isTRUE(f(design_name))
}

# The design names kept for the study. `exports` / `resolve` / `is_abstract` / `supports_unequal` are injectable for tests.
cal_study_design_names <- function(exports = getNamespaceExports("EDI"),
		resolve = function(n) get0(n, envir = asNamespace("EDI"), inherits = FALSE),
		is_abstract = function(n) {
			f <- get0("is_design_class_abstract", envir = asNamespace("EDI"), inherits = FALSE)
			is.function(f) && isTRUE(f(n))
		}) {
	nm <- sort(unique(grep("^Design", exports, value = TRUE)))
	ok <- vapply(nm, function(n) inherits(resolve(n), "R6ClassGenerator") && !is_abstract(n), logical(1L))
	setdiff(nm[ok], names(CAL_STUDY_EXCLUDED_DESIGNS))
}

# The study's design labels, in run order (cal_study_design_rank()). Amendment C: the @prob_T label of every capable design.
cal_study_designs <- function(exports = getNamespaceExports("EDI"), resolve = function(n) get0(n, envir = asNamespace("EDI"), inherits = FALSE),
		supports_unequal = cal_study_supports_unequal, prob_T = CAL_STUDY_UNEQUAL_PROB_T, ...) {
	nm <- cal_study_design_names(exports, resolve, ...)
	cap <- nm[vapply(nm, supports_unequal, logical(1L))]
	labels <- c(nm, if (length(cap)) paste0(cap, "@prob_T=", prob_T))
	labels[order(cal_study_design_rank(labels), labels)]
}

# One-replicate smoke check that every label can be built and assigned on the study's data (continuous response, n = 50).
# Stops naming each design that cannot, so a new design never enters the study (or silently drops out of it) unnoticed.
cal_study_smoke_check_designs <- function(labels, response_type = "continuous", n_nominal = 50L) {
	bad <- character()
	for (lab in labels) {
		err <- tryCatch({ suppressWarnings(suppressMessages(cal_study_throwaway_design(response_type, lab, n_nominal))); NULL },
			error = function(e) conditionMessage(e))
		if (!is.null(err)) bad <- c(bad, sprintf("%s (%s)", lab, substr(gsub("\\s+", " ", err), 1L, 200L)))
	}
	if (length(bad)) stop("Calibration CI bug: cannot build and assign on the study's data: ", paste(bad, collapse = "; "),
		". Add cal_study_design_extras() for the design or an entry in CAL_STUDY_EXCLUDED_DESIGNS (with a reason).", call. = FALSE)
	invisible(TRUE)
}

# Smallest block that holds a whole number of treated subjects at allocation p (5 at p = 0.2).
cal_study_block_unit <- function(prob_T) {
	for (k in seq_len(1000L)) if (abs(k * prob_T - round(k * prob_T)) < 1e-9) return(k)
	stop("no block size up to 1000 gives a whole number of treated subjects at prob_T = ", prob_T)
}

# Constructor extras of a design: strata and block settings. At prob_T != 0.5 the block designs need block sizes
# that are whole multiples of the allocation (their defaults 4 / 4,6,8 are for 1:1), so they get multiples of the
# smallest such block; every other design is built with its defaults. A discovered design with no case here is
# built with defaults (cal_study_smoke_check_designs() fails the roster job if that does not work).
cal_study_design_extras <- function(design_name, prob_T = 0.5) {
	unit <- if (isTRUE(prob_T == 0.5)) NULL else cal_study_block_unit(prob_T)
	switch(design_name,
		DesignFixedBlocking = list(strata_cols = CAL_STUDY_STRATA, equal_block_sizes = FALSE),
		DesignSeqOneByOnePocockSimon = list(strata_cols = CAL_STUDY_STRATA),
		DesignSeqOneByOneRandomBlockSize = c(list(strata_cols = CAL_STUDY_STRATA), if (!is.null(unit)) list(block_sizes = unit * c(1, 2, 3))),
		DesignSeqOneByOneSPBR = c(list(strata_cols = CAL_STUDY_STRATA), if (!is.null(unit)) list(block_size = unit)),
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
	read_csv_fast(file.path(script_dir_study, "calibration_study_effects.csv"), stringsAsFactors = FALSE)
}

# True values of each class's own estimand at the power effects
# (calibrate_study_truths.R); NULL when the file is absent.
cal_study_truths_table <- function() {
	f <- file.path(script_dir_study, "calibration_study_truths.csv")
	if (!file.exists(f)) return(NULL)
	read_csv_fast(f, stringsAsFactors = FALSE, colClasses = c(formula = "character"))
}

# estimand_true for rows of one replicate: the null value under the null (every
# class's estimand is then known), else the truth table's value for (response
# type, n_nominal, effect, prob_T, class, formula), NA where it has none.
cal_study_estimand_true <- function(tab, response_type, n_nominal, effect_label, prob_T, truths) {
	if (identical(effect_label, "null")) return(tab$null_value)
	if (is.null(truths)) return(rep(NA_real_, nrow(tab)))
	# A truth counts only when at least 75% of its large-sample fits were finite: a
	# class that mostly fails at large n gets none rather than one from a lucky fit.
	t <- truths[truths$response_type == response_type & truths$n_nominal == n_nominal &
		truths$effect_label == effect_label & abs(truths$prob_T - prob_T) < 1e-9 &
		is.finite(truths$estimand_true) & truths$k_ok >= 0.75 * truths$k, ]
	unname(setNames(t$estimand_true, paste(t$inf_class, t$formula, sep = "\r"))[
		paste(tab$inference_class, tab$formula, sep = "\r")])
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
	args <- c(list(n = n, response_type = response_type), cal_study_design_extras(entry$design, entry$prob_T))
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
# them. Screening replicates are 1..9999; confirmation replicates (the gate's
# second stage, CAL_STUDY_CONFIRM_REP0 + 1 on) are 10001..19999. n * 1e4 + rep is
# then unique as long as the study's n values differ by at least 2 (they are 50,
# 52, 200, 1000): n = 50's confirmation range 510001..519999 ends below n = 52's
# 520001.
CAL_STUDY_CONFIRM_REP0 <- 10000L
cal_study_seed <- function(response_type, n, rep) {
	if (rep < 1L || rep >= 2L * CAL_STUDY_CONFIRM_REP0) stop("cal_study_seed: rep must be in 1..19999")
	as.integer(cal_study_rt_index(response_type) * 2e8 + n * 1e4 + rep)
}
cal_study_stage <- function(rep) if (rep > CAL_STUDY_CONFIRM_REP0) "confirm" else "screen"

# One replicate of one (response type, design, n, effect) unit. `classes`: the
# classes to run (cal_study_classes()). Returns rows in cal_run_tasks()' shape, with
# inference_class / method / estimate / ci_a / ci_b renamed inf_class / inf_procedure /
# beta_T_hat / ci_beta_T_a / ci_beta_T_b, plus the unit's columns (beta_T is the true
# treatment effect, 0 under the null; estimand_true the true value of the class's
# own estimand, which coverage and bias are measured against).
cal_study_run_rep <- function(response_type, design_label, n_nominal, effect_label, rep, classes,
		methods = CAL_STUDY_TIER1_METHODS, pval_only = CAL_STUDY_TIER1_PVAL_ONLY, effects = cal_study_effects_table(),
		truths = cal_study_truths_table()) {
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
	tab$beta_T <- effect
	tab$stage <- cal_study_stage(rep)
	tab$estimand_true <- cal_study_estimand_true(tab, response_type, as.integer(n_nominal), effect_label, entry$prob_T, truths)
	# The study's column names (user decision 2026-11-09); the fast tier keeps
	# cal_run_tasks()' own names.
	names(tab)[names(tab) == "inference_class"] <- "inf_class"
	names(tab)[names(tab) == "method"] <- "inf_procedure"
	names(tab)[names(tab) == "estimate"] <- "beta_T_hat"
	names(tab)[names(tab) == "ci_a"] <- "ci_beta_T_a"
	names(tab)[names(tab) == "ci_b"] <- "ci_beta_T_b"
	tab
}

# A throwaway replicate of a design (seed 1, null potential outcomes) at n_nominal: what the class set and
# the task list are read from.
cal_study_throwaway_design <- function(response_type, design_label, n_nominal) {
	n <- cal_study_effective_n(design_label, n_nominal)
	set.seed(1L)
	X <- cal_study_gen_X(n)
	cal_study_run_design(design_label, response_type, X, cal_study_potential_outcomes(response_type, X, 0))
}

# Classes applicable to a design for one response type, from the installed
# package's registry, on a throwaway replicate of that design.
cal_study_classes <- function(response_type, design_label, n_nominal) {
	sort(EDI:::applicable_inference_class_names_for_design(cal_study_throwaway_design(response_type, design_label, n_nominal)))
}
