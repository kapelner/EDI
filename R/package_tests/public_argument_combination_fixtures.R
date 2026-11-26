#!/usr/bin/env Rscript

`%||%` = function(x, y) if (is.null(x)) y else x

high_priority_fixture_methods = c(
	"compute_asymp_two_sided_pval",
	"compute_asymp_confidence_interval",
	"compute_bootstrap_two_sided_pval",
	"compute_bootstrap_confidence_interval",
	"compute_bayesian_bootstrap_two_sided_pval",
	"compute_bayesian_bootstrap_confidence_interval",
	"compute_rand_two_sided_pval",
	"compute_rand_confidence_interval"
)

response_fixture_families = c(
	"continuous",
	"incidence",
	"proportion",
	"count",
	"survival",
	"ordinal"
)

fixture_tier_rank = c(smoke = 1L, ci = 2L, nightly = 3L, release = 4L)

load_edi_for_fixtures = function() {
	if (!requireNamespace("EDI", quietly = TRUE)) {
		stop("The EDI package must be installed or loadable before building public argument fixtures.", call. = FALSE)
	}
	invisible(TRUE)
}

edi_export = function(name) {
	load_edi_for_fixtures()
	getExportedValue("EDI", name)
}

make_fixture_covariates = function(n = 8L) {
	stopifnot(n >= 4L)
	data.frame(
		x1 = seq(-1, 1, length.out = n),
		x2 = rep(c(0, 1), length.out = n),
		stratum = factor(rep(c("low", "high"), each = ceiling(n / 2))[seq_len(n)]),
		cluster_id = factor(rep(seq_len(ceiling(n / 2)), each = 2L)[seq_len(n)]),
		stringsAsFactors = FALSE
	)
}

make_fixture_response = function(response_type, n = 8L, censored = FALSE) {
	y = switch(
		response_type,
		continuous = seq_len(n) / n,
		incidence = rep(c(0, 1), length.out = n),
		proportion = seq(0.2, 0.8, length.out = n),
		count = rep(0:3, length.out = n),
		survival = seq_len(n) + 0.5,
		ordinal = rep(1:3, length.out = n),
		stop("Unknown response_type: ", response_type, call. = FALSE)
	)
	dead = if (identical(response_type, "survival") && isTRUE(censored)) {
		rep(c(1, 0, 1, 1), length.out = n)
	} else {
		rep(1, n)
	}
	list(y = y, dead = dead)
}

deterministic_assignment = function(n, design_type) {
	if (design_type %in% c("clustered", "blocked_cluster")) {
		return(rep(c(0, 1), each = 2L, length.out = n))
	}
	rep(c(0, 1), length.out = n)
}

public_argument_fixture_specs = function() {
	response_specs = lapply(c("continuous", "incidence", "proportion", "count", "survival", "ordinal"), function(response_type) {
		list(
			fixture_id = paste("fixed_bernoulli", response_type, "smoke", sep = "_"),
			response_type = response_type,
			design_type = "fixed",
			class_name = "DesignFixedBernoulli",
			n = 8L,
			tier = "smoke"
		)
	})
	names(response_specs) = vapply(response_specs, function(x) x$fixture_id, character(1))
	extra_specs = list(
		survival_censored_smoke = list(
			fixture_id = "fixed_bernoulli_survival_censored_smoke",
			response_type = "survival",
			design_type = "fixed",
			class_name = "DesignFixedBernoulli",
			n = 8L,
			tier = "smoke",
			has_censoring = TRUE
		),
		sequential_bernoulli_continuous_smoke = list(
			fixture_id = "sequential_bernoulli_continuous_smoke",
			response_type = "continuous",
			design_type = "sequential",
			class_name = "DesignSeqOneByOneBernoulli",
			n = 8L,
			tier = "smoke"
		),
		fixed_blocking_continuous_smoke = list(
			fixture_id = "fixed_blocking_continuous_smoke",
			response_type = "continuous",
			design_type = "stratified",
			class_name = "DesignFixedBlocking",
			n = 8L,
			tier = "smoke",
			strata_cols = "stratum",
			B_target = 2L
		),
		fixed_cluster_continuous_smoke = list(
			fixture_id = "fixed_cluster_continuous_smoke",
			response_type = "continuous",
			design_type = "clustered",
			class_name = "DesignFixedCluster",
			n = 8L,
			tier = "smoke",
			cluster_col = "cluster_id"
		),
		fixed_blocked_cluster_continuous_smoke = list(
			fixture_id = "fixed_blocked_cluster_continuous_smoke",
			response_type = "continuous",
			design_type = "blocked_cluster",
			class_name = "DesignFixedBlockedCluster",
			n = 8L,
			tier = "smoke",
			strata_cols = "stratum",
			cluster_col = "cluster_id"
		),
		fixed_binary_match_continuous_smoke = list(
			fixture_id = "fixed_binary_match_continuous_smoke",
			response_type = "continuous",
			design_type = "matched",
			class_name = "DesignFixedBinaryMatch",
			n = 8L,
			tier = "smoke",
			m = rep(seq_len(4L), each = 2L)
		),
		fixed_greedy_continuous_smoke = list(
			fixture_id = "fixed_greedy_continuous_smoke",
			response_type = "continuous",
			design_type = "search",
			class_name = "DesignFixedGreedy",
			n = 8L,
			tier = "smoke",
			n_iter = 1L
		),
		# DesignFixedFactorial's own fixture: a design method can only run on a design of its
		# own class (construct_r6_receiver), and the two-arm factorial (one two-level factor,
		# the only combination count the class accepts) cannot be built from a Bernoulli one.
		fixed_factorial_continuous_smoke = list(
			fixture_id = "fixed_factorial_continuous_smoke",
			response_type = "continuous",
			design_type = "factorial",
			class_name = "DesignFixedFactorial",
			n = 8L,
			tier = "smoke",
			factors = list(treatment = 2)
		)
	)
	specs = c(response_specs, extra_specs)
	names(specs) = vapply(specs, function(spec) spec$fixture_id, character(1))
	specs
}

construct_public_design = function(spec, covariates) {
	constructor = edi_export(spec$class_name)
	common = list(
		response_type = spec$response_type,
		n = spec$n,
		seed = 20260809L,
		design_formula = ~ x1 + x2 + stratum
	)
	if (identical(spec$class_name, "DesignFixedBlocking")) {
		return(do.call(constructor$new, c(list(
			strata_cols = spec$strata_cols,
			B_target = spec$B_target %||% 2L,
			equal_block_sizes = TRUE
		), common)))
	}
	if (identical(spec$class_name, "DesignFixedCluster")) {
		return(do.call(constructor$new, c(list(cluster_col = spec$cluster_col), common)))
	}
	if (identical(spec$class_name, "DesignFixedBlockedCluster")) {
		return(do.call(constructor$new, c(list(strata_cols = spec$strata_cols, cluster_col = spec$cluster_col), common)))
	}
	if (identical(spec$class_name, "DesignFixedBinaryMatch")) {
		return(do.call(constructor$new, c(list(m = spec$m), common)))
	}
	if (identical(spec$class_name, "DesignFixedGreedy")) {
		return(do.call(constructor$new, c(list(n_iter = spec$n_iter %||% 1L), common)))
	}
	if (identical(spec$class_name, "DesignFixedFactorial")) {
		return(do.call(constructor$new, c(list(factors = spec$factors %||% list(treatment = 2)), common)))
	}
	do.call(constructor$new, common)
}

populate_public_design = function(design, spec, covariates, response) {
	if (identical(spec$design_type, "sequential")) {
		for (i in seq_len(spec$n)) {
			design$add_one_subject_to_experiment_and_assign(covariates[i, , drop = FALSE])
			if (isTRUE(response$dead[i] == 1)) {
				design$add_one_subject_response(i, y = response$y[i])
			} else {
				design$add_one_subject_response(i, y_L = response$y[i], y_R = Inf)
			}
		}
		return(invisible(design))
	}
	design$add_all_subjects_to_experiment(covariates)
	design$assign_w_to_all_subjects(w_precomputed = deterministic_assignment(spec$n, spec$design_type))
	is_dead = response$dead == 1
	design$add_all_subject_responses(
		ys = ifelse(is_dead, response$y, NA_real_),
		y_Ls = ifelse(is_dead, NA_real_, response$y),
		y_Rs = ifelse(is_dead, NA_real_, Inf)
	)
	invisible(design)
}

fixture_metadata = function(spec, covariates, design) {
	has_strata = !is.null(spec$strata_cols)
	has_cluster = !is.null(spec$cluster_col)
	has_matching = identical(spec$design_type, "matched")
	has_censoring = isTRUE(spec$has_censoring)
	list(
		fixture_id = spec$fixture_id,
		response_type = spec$response_type,
		design_type = spec$design_type,
		class_name = spec$class_name,
		n = spec$n,
		p = ncol(covariates),
		has_strata = has_strata,
		has_cluster = has_cluster,
		has_matching = has_matching,
		has_censoring = has_censoring,
		supports_jackknife = !has_cluster && spec$n >= 4L,
		supports_randomization = TRUE,
		supports_censoring = identical(spec$response_type, "survival"),
		has_finite_standard_errors = spec$n >= 4L,
		documented_nonestimable_behavior = FALSE,
		optional_backend_available = TRUE,
		capture_progress_output = FALSE,
		legal_response_transforms = legal_response_transforms(spec$response_type),
		available_columns = names(covariates),
		factor_columns = names(covariates)[vapply(covariates, is.factor, logical(1))],
		cluster_columns = if (has_cluster) spec$cluster_col else "cluster_id",
		strata_cols = spec$strata_cols %||% character(),
		cluster_col = spec$cluster_col %||% character(),
		strata_cols_must_be_factor = TRUE,
		allows_strata_cluster_overlap = FALSE,
		strata_level_count = length(unique(covariates$stratum)),
		n_exchangeable_units = if (has_cluster) length(unique(covariates[[spec$cluster_col]])) else spec$n,
		tier = spec$tier,
		compatible_method_families = high_priority_fixture_methods,
		notes = if (identical(spec$response_type, "ordinal")) "Ordinal fixture uses integer-coded ordered categories accepted by the public response API." else ""
	)
}

legal_response_transforms = function(response_type) {
	switch(
		response_type,
		continuous = c("identity", "rank", "scale"),
		incidence = c("identity", "risk"),
		proportion = c("identity", "logit"),
		count = c("identity", "log1p"),
		survival = c("identity", "log"),
		ordinal = c("identity", "rank"),
		"identity"
	)
}

build_public_argument_fixture = function(spec) {
	load_edi_for_fixtures()
	covariates = make_fixture_covariates(spec$n)
	response = make_fixture_response(spec$response_type, spec$n, censored = isTRUE(spec$has_censoring))
	design = construct_public_design(spec, covariates)
	populate_public_design(design, spec, covariates, response)
	fixture = list(
		fixture_id = spec$fixture_id,
		design = design,
		data = covariates,
		response = response$y,
		dead = response$dead,
		w = design$get_w(),
		metadata = fixture_metadata(spec, covariates, design)
	)
	validate_public_argument_fixture(fixture)
	fixture
}

build_public_argument_fixtures = function(tier = "smoke", fixture_ids = NULL) {
	specs = public_argument_fixture_specs()
	if (!is.null(fixture_ids) && any(is_data_shape_fixture_id(fixture_ids))) {
		# Data-shape fixtures (v1.0.7-TODO-41) are built from their ids, never by tier.
		shape_ids = fixture_ids[is_data_shape_fixture_id(fixture_ids)]
		rest = setdiff(fixture_ids, shape_ids)
		out = build_data_shape_fixtures(shape_ids)
		if (length(rest)) out = c(build_public_argument_fixtures(tier = tier, fixture_ids = rest), out)
		return(out)
	}
	if (!is.null(fixture_ids)) {
		missing = setdiff(fixture_ids, names(specs))
		if (length(missing)) stop("Unknown fixture_ids: ", paste(missing, collapse = ", "), call. = FALSE)
		specs = specs[fixture_ids]
	}
	max_rank = fixture_tier_rank[[tier]]
	if (is.null(max_rank) || is.na(max_rank)) stop("Unknown tier: ", tier, call. = FALSE)
	specs = specs[vapply(specs, function(spec) fixture_tier_rank[[spec$tier]] <= max_rank, logical(1))]
	fixtures = lapply(specs, build_public_argument_fixture)
	names(fixtures) = vapply(fixtures, function(fixture) fixture$fixture_id, character(1))
	fixtures
}

validate_public_argument_fixture = function(fixture) {
	required_top = c("fixture_id", "design", "data", "response", "dead", "w", "metadata")
	missing_top = setdiff(required_top, names(fixture))
	if (length(missing_top)) stop("Fixture missing fields: ", paste(missing_top, collapse = ", "), call. = FALSE)
	meta = fixture$metadata
	required_meta = c(
		"fixture_id", "response_type", "design_type", "n", "p", "has_strata", "has_cluster",
		"has_matching", "has_censoring", "supports_jackknife", "supports_randomization",
		"available_columns", "tier"
	)
	missing_meta = setdiff(required_meta, names(meta))
	if (length(missing_meta)) stop("Fixture metadata missing fields: ", paste(missing_meta, collapse = ", "), call. = FALSE)
	if (!identical(fixture$fixture_id, meta$fixture_id)) stop("Fixture ID mismatch.", call. = FALSE)
	if (!identical(fixture$design$get_response_type(), meta$response_type)) stop("Response type mismatch.", call. = FALSE)
	if (!identical(as.integer(fixture$design$get_n()), as.integer(meta$n))) stop("n mismatch.", call. = FALSE)
	if (!identical(as.integer(fixture$design$get_t()), as.integer(meta$n))) stop("Fixture subjects were not fully added.", call. = FALSE)
	if (length(fixture$response) != meta$n) stop("Response length mismatch.", call. = FALSE)
	if (length(fixture$dead) != meta$n) stop("Censoring vector length mismatch.", call. = FALSE)
	if (length(fixture$w) != meta$n || any(!fixture$w %in% c(0, 1))) stop("Treatment assignment is not a legal binary vector.", call. = FALSE)
	if (!all(meta$available_columns %in% names(fixture$data))) stop("Metadata available_columns are not present in data.", call. = FALSE)
	if (isTRUE(meta$has_censoring) && !isTRUE(fixture$design$any_censoring())) stop("Censoring metadata mismatch.", call. = FALSE)
	invisible(TRUE)
}

fixture_inventory = function(fixtures) {
	rows = lapply(fixtures, function(fixture) {
		meta = fixture$metadata
		data.frame(
			fixture_id = meta$fixture_id,
			response_type = meta$response_type,
			design_type = meta$design_type,
			class_name = meta$class_name,
			n = meta$n,
			p = meta$p,
			has_strata = meta$has_strata,
			has_cluster = meta$has_cluster,
			has_matching = meta$has_matching,
			has_censoring = meta$has_censoring,
			supports_jackknife = meta$supports_jackknife,
			supports_randomization = meta$supports_randomization,
			available_columns = paste(meta$available_columns, collapse = ";"),
			tier = meta$tier,
			stringsAsFactors = FALSE
		)
	})
	out = do.call(rbind, rows)
	row.names(out) = NULL
	out
}

# ---------------------------------------------------------------------------------------------
# Data-shape axes (v1.0.7-TODO-41).
#
# The registry-driven cases above vary argument values; their axes come from checkmate contracts,
# which only see argument types. The canonical fixtures are all n = 8, fixed n, equal blocks and
# clusters, complete covariates, right censoring at most and no real treatment effect, so a bug that
# needs one of those settings (v1.0.6-TODO-36 / v1.0.7-TODO-37 / v1.0.6-TODO-38 / v1.0.6-TODO-39 / v1.0.6-TODO-40 / v1.0.6-TODO-49 / v1.0.6-TODO-50) never runs. These axes vary the
# data instead. Cells are drawn pairwise (generate_public_argument_data_shape_cases() in
# generate_public_argument_combinations.R), not full factorial, and each cell's fixture is built on
# demand from its id, so a fixture that cannot even be built (e.g. KK21 with n = NULL,
# v1.0.6-TODO-38) is recorded as that cell's error instead of aborting the run.
# ---------------------------------------------------------------------------------------------

data_shape_fixture_prefix = "data_shape__"

data_shape_fixture_n = 40L

# Design label -> class and design_type (the design_type vocabulary of the canonical fixtures).
data_shape_designs = list(
	fixed_bernoulli = list(class_name = "DesignFixedBernoulli", design_type = "fixed", sequential = FALSE, grouped = FALSE),
	fixed_blocking = list(class_name = "DesignFixedBlocking", design_type = "stratified", sequential = FALSE, grouped = TRUE),
	fixed_cluster = list(class_name = "DesignFixedCluster", design_type = "clustered", sequential = FALSE, grouped = TRUE),
	fixed_blocked_cluster = list(class_name = "DesignFixedBlockedCluster", design_type = "blocked_cluster", sequential = FALSE, grouped = TRUE),
	seq_bernoulli = list(class_name = "DesignSeqOneByOneBernoulli", design_type = "sequential", sequential = TRUE, grouped = FALSE),
	seq_kk21 = list(class_name = "DesignSeqOneByOneKK21", design_type = "sequential", sequential = TRUE, grouped = FALSE)
)

# The fixture-level axes, in id order. Values are short tokens: they are joined into the fixture id.
data_shape_fixture_axes = function() {
	list(
		design = names(data_shape_designs),
		response_type = response_fixture_families,
		# fixed: n given up front. null_mid: n = NULL, 40 enrolled, the first 30 have responses (an
		# interim look). null_end: n = NULL, every enrolled subject has a response.
		sample_size = c("fixed", "null_mid", "null_end"),
		group_sizes = c("equal", "unequal"),
		censoring = c("none", "right", "interval"),
		missing_covariate = c("no", "yes"),
		# strong: a shift large enough that 0 is far outside the bootstrap distribution.
		effect = c("null", "strong")
	)
}

data_shape_fixture_id = function(cell) {
	axes = names(data_shape_fixture_axes())
	paste0(data_shape_fixture_prefix, paste(vapply(axes, function(a) as.character(cell[[a]]), character(1)), collapse = "__"))
}

is_data_shape_fixture_id = function(fixture_id) startsWith(as.character(fixture_id), data_shape_fixture_prefix)

parse_data_shape_fixture_id = function(fixture_id) {
	axes = names(data_shape_fixture_axes())
	parts = strsplit(sub(paste0("^", data_shape_fixture_prefix), "", fixture_id), "__", fixed = TRUE)[[1L]]
	if (length(parts) != length(axes)) stop("Malformed data-shape fixture id: ", fixture_id, call. = FALSE)
	cell = stats::setNames(as.list(parts), axes)
	for (a in axes) {
		if (!cell[[a]] %in% data_shape_fixture_axes()[[a]]) stop("Unknown value '", cell[[a]], "' for data-shape axis ", a, call. = FALSE)
	}
	cell
}

# Subject layout for one cell. Equal: two strata of 20 and ten clusters of 4. Unequal: strata of 17
# and 23, clusters of 2 to 6 subjects, each cluster inside one stratum (so blocked-cluster designs see
# blocks with different subject counts, v1.0.6-TODO-36).
make_data_shape_covariates = function(cell, n = data_shape_fixture_n) {
	cluster_sizes = if (identical(cell$group_sizes, "unequal")) c(2L, 3L, 4L, 5L, 3L, 3L, 4L, 5L, 6L, 5L) else rep(4L, 10L)
	stopifnot(sum(cluster_sizes) == n)
	cluster_id = rep(seq_along(cluster_sizes), times = cluster_sizes)
	n_low = sum(cluster_sizes[1:5])
	x1 = stats::qnorm(seq(0.5, n - 0.5) / n)[c(seq(1L, n, by = 2L), seq(2L, n, by = 2L))]
	if (identical(cell$missing_covariate, "yes")) x1[c(3L, 11L)] = NA_real_
	data.frame(
		x1 = x1,
		x2 = rep(c(0, 1), length.out = n),
		stratum = factor(ifelse(seq_len(n) <= n_low, "low", "high"), levels = c("low", "high")),
		cluster_id = factor(cluster_id),
		stringsAsFactors = FALSE
	)
}

# Noise is drawn once per cell (seeded), before the design assigns anyone, so the response is a
# deterministic function of (noise, w): y = f(noise, w).
make_data_shape_noise = function(n = data_shape_fixture_n, seed = 20261118L) {
	old = if (exists(".Random.seed", envir = globalenv())) get(".Random.seed", envir = globalenv()) else NULL
	on.exit(if (is.null(old)) rm(".Random.seed", envir = globalenv()) else assign(".Random.seed", old, envir = globalenv()))
	set.seed(seed)
	list(e = stats::rnorm(n), u = stats::runif(n), u_cens = stats::runif(n))
}

# One subject's response. Returns list(y, y_L, y_R): an exact value in y, or a censoring interval.
data_shape_response_one = function(cell, i, w_i, x1_i, noise) {
	strong = identical(cell$effect, "strong")
	x = if (is.na(x1_i)) 0 else x1_i
	e = noise$e[i]
	u = noise$u[i]
	exact = function(y) list(y = y, y_L = NA_real_, y_R = NA_real_)
	switch(cell$response_type,
		continuous = exact(0.5 * x + e + if (strong) 3 * w_i else 0),
		incidence = exact(as.numeric(u < if (strong) (if (w_i == 1) 0.9 else 0.1) else 0.5)),
		proportion = exact(stats::plogis(0.5 * e + if (strong) 2 * (2 * w_i - 1) else 0)),
		count = exact(stats::qpois(u, if (strong) (if (w_i == 1) 8 else 1) else 2)),
		ordinal = {
			latent = e + if (strong) 3 * w_i else 0
			exact(1 + (latent > -0.7) + (latent > 0) + (latent > 0.7))
		},
		survival = {
			t_event = -log(u) * 10 * exp(0.2 * x + if (strong) 2.5 * w_i else 0)
			if (identical(cell$censoring, "right")) {
				t_cens = 5 + 40 * noise$u_cens[i]
				if (t_event <= t_cens) exact(t_event) else list(y = NA_real_, y_L = t_cens, y_R = Inf)
			} else if (identical(cell$censoring, "interval")) {
				# Visit-schedule data as in the v1.0.6-TODO-49 repro: the event is known only to lie
				# between two visits three time units apart.
				left = floor(t_event / 3) * 3
				list(y = NA_real_, y_L = left, y_R = left + 3)
			} else {
				exact(t_event)
			}
		},
		stop("Unknown response_type: ", cell$response_type, call. = FALSE)
	)
}

construct_data_shape_design = function(cell, n_arg) {
	info = data_shape_designs[[cell$design]]
	constructor = edi_export(info$class_name)
	common = list(response_type = cell$response_type, n = n_arg, seed = 20260809L, design_formula = ~ x1 + x2 + stratum)
	extra = switch(cell$design,
		# equal_block_sizes = FALSE is the documented way to block unequal strata.
		fixed_blocking = list(strata_cols = "stratum", equal_block_sizes = !identical(cell$group_sizes, "unequal")),
		fixed_cluster = list(cluster_col = "cluster_id"),
		fixed_blocked_cluster = list(strata_cols = "stratum", cluster_col = "cluster_id"),
		list()
	)
	do.call(constructor$new, c(extra, common))
}

# Builds one data-shape fixture from its id. Anything EDI refuses while the design is built,
# assigned or fed responses propagates as an error; the runner records it as the cell's outcome.
build_data_shape_fixture = function(fixture_id) {
	load_edi_for_fixtures()
	cell = parse_data_shape_fixture_id(fixture_id)
	info = data_shape_designs[[cell$design]]
	n = data_shape_fixture_n
	covariates = make_data_shape_covariates(cell, n)
	if (isTRUE(info$sequential)) {
		# Alternate the strata in arrival order. Arriving sorted (all "low" first) trips a separate
		# bug: a design_formula naming a covariate that is still constant among the subjects so far
		# fails with "object 'stratum' not found" in KK21 (found by this matrix, 2026-11-18).
		half = n %/% 2L
		covariates = covariates[c(rbind(seq_len(half), half + seq_len(half))), , drop = FALSE]
		row.names(covariates) = NULL
	}
	noise = make_data_shape_noise(n)
	n_null = cell$sample_size %in% c("null_mid", "null_end")
	n_responded = if (identical(cell$sample_size, "null_mid")) 30L else n
	design = construct_data_shape_design(cell, if (n_null) NULL else n)
	responses = vector("list", n)
	if (isTRUE(info$sequential)) {
		for (i in seq_len(n)) {
			design$add_one_subject_to_experiment_and_assign(covariates[i, , drop = FALSE])
		}
		w = as.numeric(design$get_w())
		# With n = NULL the responses arrive in reverse enrollment order, which exercises
		# out-of-order responses (v1.0.6-TODO-40); the stored data are the same either way.
		for (i in if (n_null) rev(seq_len(n_responded)) else seq_len(n_responded)) {
			r = data_shape_response_one(cell, i, w[i], covariates$x1[i], noise)
			responses[[i]] = r
			if (!is.na(r$y)) design$add_one_subject_response(i, y = r$y) else design$add_one_subject_response(i, y_L = r$y_L, y_R = r$y_R)
		}
	} else {
		design$add_all_subjects_to_experiment(covariates)
		design$assign_w_to_all_subjects()
		w = as.numeric(design$get_w())
		responses = lapply(seq_len(n), function(i) data_shape_response_one(cell, i, w[i], covariates$x1[i], noise))
		design$add_all_subject_responses(
			ys = vapply(responses, function(r) r$y, numeric(1)),
			y_Ls = vapply(responses, function(r) r$y_L, numeric(1)),
			y_Rs = vapply(responses, function(r) r$y_R, numeric(1))
		)
	}
	has_y = !vapply(responses, is.null, logical(1))
	y_obs = vapply(responses, function(r) if (is.null(r)) NA_real_ else if (!is.na(r$y)) r$y else r$y_L, numeric(1))
	dead = vapply(responses, function(r) if (is.null(r)) NA_real_ else as.numeric(!is.na(r$y)), numeric(1))
	list(
		fixture_id = fixture_id,
		design = design,
		data = covariates,
		response = y_obs,
		dead = dead,
		w = w,
		metadata = list(
			fixture_id = fixture_id,
			response_type = cell$response_type,
			design_type = info$design_type,
			class_name = info$class_name,
			n = if (n_null) NA_integer_ else n,
			n_enrolled = n,
			n_responded = sum(has_y),
			p = ncol(covariates),
			has_strata = cell$design %in% c("fixed_blocking", "fixed_blocked_cluster"),
			has_cluster = cell$design %in% c("fixed_cluster", "fixed_blocked_cluster"),
			has_matching = identical(cell$design, "seq_kk21"),
			has_censoring = !identical(cell$censoring, "none"),
			censoring = cell$censoring,
			effect = cell$effect,
			data_shape = cell,
			available_columns = names(covariates),
			tier = "nightly"
		)
	)
}

# A fixture that failed to build: the runner turns build_error into the error outcome of every case
# on it.
failed_data_shape_fixture = function(fixture_id, message) {
	list(fixture_id = fixture_id, build_error = message, metadata = list(fixture_id = fixture_id))
}

build_data_shape_fixtures = function(fixture_ids) {
	fixtures = lapply(fixture_ids, function(id) {
		tryCatch(
			suppressWarnings(suppressMessages(build_data_shape_fixture(id))),
			error = function(e) failed_data_shape_fixture(id, conditionMessage(e))
		)
	})
	names(fixtures) = fixture_ids
	fixtures
}
