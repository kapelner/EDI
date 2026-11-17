library(testthat)
library(EDI)

# Cross-platform reproducibility digests (cross_platform_reproducibility.md,
# TODO-4; release_v1_1_0.md TODO-48).
#
# For each design class below, draw r allocations from a fixed seed at several
# OpenMP thread counts and reduce each w matrix to an md5 digest (quantity
# "w_md5"). Sequential designs are first driven through their one-at-a-time
# assignment path under the same seed, and that allocation is digested too
# (quantity "w_seq_md5"), since the two paths run different kernels. Three
# checks use these digests:
#   1. Within this run: the digest must not depend on the thread count.
#   2. Against the committed fixture (fixtures/cross_platform_digests.csv), when
#      present: integer draws must match it exactly on every platform. This is
#      the only cross-platform check that CRAN and r-universe can run, since
#      they never see the other platforms' output.
#   3. Across CI legs: when EDI_REPRO_DIGEST_DIR is set (R-CMD-check.yaml does
#      this on every matrix leg), the rows are written there, uploaded as an
#      artifact, and compared across all legs by the repro-compare job
#      (.github/scripts/compare_repro_digests.R).
#
# Floating-point values (estimate, CI, p-value) are recorded for the cross-leg
# comparison, which checks them within a tolerance. They are deliberately not
# checked against the fixture here: CRAN's alternative-BLAS and no-long-double
# check flavours would turn last-bit differences into CRAN failures.
#
# CRAN policy allows at most 2 cores, so thread counts above 2 run only when
# NOT_CRAN is "true". Keep this file fast: about 7 s at 1 and 2 threads (CRAN) and
# 12 s at 1, 2 and 4 threads on the 2026-11 workstation; DesignFixedMatchingGreedyPairSwitching
# and the nonparametric bootstrap are the slowest cases.
#
# Besides the design draws, each resampling method in the inference registry
# (permutation, bootstrap, randomization bootstrap, Bayesian bootstrap,
# jackknife, parametric bootstrap) is digested from its seed-pinned draw
# distribution (kind "resampling_draw"). A meta-test fails when the fixture
# lacks a row for a design class or resampling method in the registries.
#
# To add rows for a new class or method, run this file with
# EDI_REPRO_WRITE_FIXTURE=true. Changing or dropping a committed digest is an
# announced change to seed-pinned draws: it needs a NEWS line and
# EDI_REPRO_OVERWRITE_FIXTURE=true as well, or the write refuses.
# EDI_REPRO_FIXTURE_PATH points the test at another fixture file.
#
# v1.0.6-TODO-45 (2026-11-17): both DesignSeqOneByOneKK14 rows (w_md5 and
# w_seq_md5) were regenerated this way. KK14's match test now uses the
# published T^2 = 1/2 d'S^-1 d (it was twice as strict), so the seeded KK14
# allocation forms more pairs and its digests changed. No other row changed;
# KK21's rows are unaffected because this case reveals responses, so KK21 is
# past its KK14 fallback by the time it starts matching.

repro_thread_counts = function() {
	available = parallel::detectCores(logical = TRUE)
	if (is.na(available)) available = 1L
	counts = 1L
	if (available >= 2L) counts = c(counts, 2L)
	if (available >= 4L && identical(Sys.getenv("NOT_CRAN"), "true")) counts = c(counts, 4L)
	counts
}

repro_leg_name = function() {
	leg = Sys.getenv("EDI_REPRO_LEG")
	if (nzchar(leg)) leg else paste(R.version$platform, "local", sep = "-")
}

repro_md5 = function(w) {
	f = tempfile(fileext = ".txt")
	on.exit(unlink(f), add = TRUE)
	# writeBin, not writeLines: a text-mode file gets CRLF line endings on Windows,
	# which changes the md5 of an otherwise identical allocation.
	writeBin(charToRaw(paste0(paste(as.integer(w), collapse = ""), "\n")), f)
	unname(tools::md5sum(f))
}

repro_n = 40L
repro_r = 25L
repro_X = local({
	old_seed = if (exists(".Random.seed", envir = globalenv())) get(".Random.seed", envir = globalenv()) else NULL
	on.exit(if (!is.null(old_seed)) assign(".Random.seed", old_seed, envir = globalenv()), add = TRUE)
	set.seed(7L)
	data.frame(x1 = rnorm(repro_n), x2 = rnorm(repro_n), x3 = rnorm(repro_n))
})
# The deterministic response revealed to the designs whose allocation reads
# responses (KK21). It must not be an exact covariate: with y = x1, KK21's
# covariate-weight regressions fit perfectly, the weights become a ratio of
# rounding noise, and every platform drew different w (R-CMD-check 2026-11-16:
# four legs, four digests; a 1e-13 relative nudge to y also changed the draw).
# This y leaves real residual variance, so the weights are well conditioned.
repro_response = repro_X$x1 + 0.3 * repro_X$x2 + 0.5 * sin(seq_len(repro_n))
# The stratified designs need a factor column; the other cases keep repro_X so
# their digests stay comparable with earlier fixtures.
repro_X_strata = cbind(repro_X, s = factor(rep(1:2, length.out = repro_n)))
# Cluster designs: 10 clusters of 4, nested within 2 blocks of 20.
repro_X_cluster = cbind(repro_X,
	s = factor(rep(1:2, each = repro_n / 2L)),
	cl = factor(rep(seq_len(repro_n / 4L), each = 4L)))

# name -> list(build, X, sequential, responses, r), where build() returns a
# fresh design. Packages come from the design registry's required_packages, so
# a case skips (rather than errors) when a Suggests package is missing. X
# defaults to repro_X and r to repro_r. sequential = TRUE drives the design
# through add_one_subject_to_experiment_and_assign() instead of
# add_all_subjects_to_experiment(); responses = TRUE also reveals a
# deterministic response (repro_response) after each assignment, for the designs whose
# allocation reads responses (KK21). The meta-test below requires one case per
# concrete, seed-reproducible design class in the registry (every class except
# the observational "none" family, which has no assignment mechanism to draw).
repro_design_cases = list(
	DesignFixedBernoulli = list(build = function()
		DesignFixedBernoulli$new(n = repro_n, response_type = "continuous")),
	DesignFixedRerandomization = list(build = function()
		DesignFixedRerandomization$new(n = repro_n, response_type = "continuous", obj_val_cutoff = Inf)),
	DesignFixedGreedy = list(build = function()
		DesignFixedGreedy$new(n = repro_n, response_type = "continuous")),
	DesignFixedGreedyDOptimal = list(build = function()
		DesignFixedGreedyDOptimal$new(n = repro_n, response_type = "continuous")),
	DesignFixedMatchingGreedyPairSwitching = list(build = function()
		DesignFixedMatchingGreedyPairSwitching$new(n = repro_n, response_type = "continuous")),
	DesignFixedBinaryMatch = list(build = function()
		DesignFixedBinaryMatch$new(n = repro_n, response_type = "continuous")),
	DesignFixediBCRD = list(build = function()
		DesignFixediBCRD$new(n = repro_n, response_type = "continuous")),
	DesignFixedBlocking = list(X = repro_X_strata, build = function()
		DesignFixedBlocking$new(n = repro_n, response_type = "continuous", strata_cols = "s")),
	DesignFixedCluster = list(X = repro_X_cluster, build = function()
		DesignFixedCluster$new(n = repro_n, response_type = "continuous", cluster_col = "cl")),
	DesignFixedBlockedCluster = list(X = repro_X_cluster, build = function()
		DesignFixedBlockedCluster$new(n = repro_n, response_type = "continuous", strata_cols = "s", cluster_col = "cl")),
	DesignFixedFactorial = list(build = function()
		DesignFixedFactorial$new(factors = list(treatment = 2), n = repro_n, response_type = "continuous")),
	# One optimal allocation (r > 1 is refused); the annealing solver it uses at
	# this n is seeded from R's RNG, so the single draw is seed-pinned.
	DesignFixedOptimal = list(r = 1L, build = function()
		DesignFixedOptimal$new(n = repro_n, response_type = "continuous")),
	DesignFixedOptimalBlocks = list(build = function()
		DesignFixedOptimalBlocks$new(n = repro_n, response_type = "continuous")),
	DesignSeqOneByOneAtkinson = list(sequential = TRUE, build = function()
		DesignSeqOneByOneAtkinson$new(n = repro_n, response_type = "continuous")),
	DesignSeqOneByOneBernoulli = list(sequential = TRUE, build = function()
		DesignSeqOneByOneBernoulli$new(n = repro_n, response_type = "continuous")),
	DesignSeqOneByOneEfron = list(sequential = TRUE, build = function()
		DesignSeqOneByOneEfron$new(n = repro_n, response_type = "continuous")),
	DesignSeqOneByOneiBCRD = list(sequential = TRUE, build = function()
		DesignSeqOneByOneiBCRD$new(n = repro_n, response_type = "continuous")),
	DesignSeqOneByOneKK14 = list(sequential = TRUE, build = function()
		DesignSeqOneByOneKK14$new(n = repro_n, response_type = "continuous")),
	DesignSeqOneByOneKK21 = list(sequential = TRUE, responses = TRUE, build = function()
		DesignSeqOneByOneKK21$new(n = repro_n, response_type = "continuous")),
	DesignSeqOneByOneKK21stepwise = list(sequential = TRUE, responses = TRUE, build = function()
		DesignSeqOneByOneKK21stepwise$new(n = repro_n, response_type = "continuous")),
	DesignSeqOneByOnePocockSimon = list(X = repro_X_strata, sequential = TRUE, build = function()
		DesignSeqOneByOnePocockSimon$new(n = repro_n, response_type = "continuous", strata_cols = "s")),
	DesignSeqOneByOneRandomBlockSize = list(sequential = TRUE, build = function()
		DesignSeqOneByOneRandomBlockSize$new(n = repro_n, response_type = "continuous")),
	DesignSeqOneByOneSPBR = list(X = repro_X_strata, sequential = TRUE, build = function()
		DesignSeqOneByOneSPBR$new(n = repro_n, response_type = "continuous", strata_cols = "s")),
	DesignSeqOneByOneUrn = list(sequential = TRUE, build = function()
		DesignSeqOneByOneUrn$new(n = repro_n, response_type = "continuous"))
)

# Resampling methods: capability name in the inference registry -> the class
# that runs it and a function returning its seed-pinned draw distribution. The
# distributions are doubles, so they are digested after formatting to 8
# significant digits (repro_num_md5): a last-bit platform difference only
# changes the digest if a value sits on a rounding boundary. The meta-test below
# requires one case per resampling capability in the registry (every capability
# naming randomization, a bootstrap, the jackknife or subsampling, except the
# *_ci inversions, which reuse their test's draws).
repro_resampling_cases = list(
	randomization_test = list(class = "InferenceAllSimpleAverageDiff", run = function(inf)
		inf$approximate_randomization_distribution_beta_hat_T(r = 99L, show_progress = FALSE)),
	nonparametric_bootstrap = list(class = "InferenceAllSimpleAverageDiff", run = function(inf)
		inf$approximate_bootstrap_distribution_beta_hat_T(B = 99L, show_progress = FALSE)),
	randomization_bootstrap = list(class = "InferenceAllSimpleAverageDiff", run = function(inf)
		inf$approximate_rand_bootstrap_distribution_beta_hat_T(B = 99L, show_progress = FALSE)),
	bayesian_bootstrap = list(class = "InferenceAllSimpleAverageDiff", run = function(inf)
		inf$approximate_bayesian_bootstrap_distribution_beta_hat_T(B = 99L, show_progress = FALSE)),
	jackknife = list(class = "InferenceAllSimpleAverageDiff", run = function(inf)
		inf$approximate_jackknife_distribution_beta_hat_T()),
	parametric_likelihood_bootstrap = list(class = "InferenceContinOLS", run = function(inf)
		inf$compute_param_bootstrap_estimate(B = 49L))
)

repro_num_md5 = function(x) {
	f = tempfile(fileext = ".txt")
	on.exit(unlink(f), add = TRUE)
	writeBin(charToRaw(paste0(paste(sprintf("%.7e", as.numeric(x)), collapse = ","), "\n")), f)
	unname(tools::md5sum(f))
}

# Data shared by the resampling and float rows: a Bernoulli allocation with a
# continuous response, fixed by seed 11.
repro_inference_design = function() {
	old_seed = if (exists(".Random.seed", envir = globalenv())) get(".Random.seed", envir = globalenv()) else NULL
	on.exit(if (!is.null(old_seed)) assign(".Random.seed", old_seed, envir = globalenv()), add = TRUE)
	set.seed(11L)
	des = DesignFixedBernoulli$new(n = repro_n, response_type = "continuous")
	des$add_all_subjects_to_experiment(repro_X)
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(repro_X$x1 + 0.5 * des$get_w() + rnorm(repro_n))
	des
}

repro_digest_rows = function() {
	old_cores = EDI:::get_num_cores()
	on.exit(EDI:::set_package_threads(old_cores), add = TRUE)
	rows = list()
	for (name in names(repro_design_cases)) {
		case = repro_design_cases[[name]]
		packages = EDI:::get_design_class_metadata(name)$required_packages
		if (length(packages) && !all(vapply(packages, requireNamespace, logical(1), quietly = TRUE))) next
		for (threads in repro_thread_counts()) {
			EDI:::set_package_threads(threads)
			# Read the OpenMP team size before the draw: some kernels reset it.
			obtained = EDI:::get_omp_max_threads_cpp()
			des = case$build()
			X = if (is.null(case$X)) repro_X else case$X
			digests = list()
			if (isTRUE(case$sequential)) {
				set.seed(20261013L)
				for (i in seq_len(nrow(X))) {
					des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
					if (isTRUE(case$responses)) des$add_one_subject_response(i, repro_response[i])
				}
				digests$w_seq_md5 = repro_md5(des$get_w())
			} else {
				des$add_all_subjects_to_experiment(X)
			}
			set.seed(20261013L)
			r = if (is.null(case$r)) repro_r else case$r
			digests$w_md5 = repro_md5(suppressMessages(des$draw_ws_according_to_design(r)))
			for (quantity in names(digests)) {
				rows[[length(rows) + 1L]] = data.frame(
					kind = "design_draw", name = name, threads = threads,
					threads_obtained = obtained, quantity = quantity,
					value_chr = digests[[quantity]], value_num = NA_real_,
					stringsAsFactors = FALSE
				)
			}
		}
	}
	des = repro_inference_design()
	for (name in names(repro_resampling_cases)) {
		case = repro_resampling_cases[[name]]
		for (threads in repro_thread_counts()) {
			EDI:::set_package_threads(threads)
			obtained = EDI:::get_omp_max_threads_cpp()
			inf = get(case$class, envir = asNamespace("EDI"))$new(des)
			inf$set_seed(99L)
			rows[[length(rows) + 1L]] = data.frame(
				kind = "resampling_draw", name = name, threads = threads,
				threads_obtained = obtained, quantity = paste0(case$class, "_md5"),
				value_chr = repro_num_md5(case$run(inf)), value_num = NA_real_,
				stringsAsFactors = FALSE
			)
		}
	}
	rows
}

repro_float_rows = function() {
	des = repro_inference_design()
	inf = InferenceAllSimpleAverageDiff$new(des)
	inf$set_seed(99L)
	ci = inf$compute_wald_confidence_interval()
	values = c(
		estimate = inf$compute_estimate(),
		wald_ci_lower = ci[[1]],
		wald_ci_upper = ci[[2]],
		rand_pval = inf$compute_rand_two_sided_pval(r = 199L, show_progress = FALSE)
	)
	lapply(names(values), function(q) data.frame(
		kind = "inference_float", name = "InferenceAllSimpleAverageDiff", threads = 1L,
		threads_obtained = NA_integer_, quantity = q,
		value_chr = NA_character_, value_num = unname(values[[q]]),
		stringsAsFactors = FALSE
	))
}

repro_fixture_path = function() {
	override = Sys.getenv("EDI_REPRO_FIXTURE_PATH")
	if (nzchar(override)) override else test_path("fixtures", "cross_platform_digests.csv")
}

repro_read_fixture = function(path) {
	fixture = utils::read.csv(path, stringsAsFactors = FALSE, colClasses = "character")
	if (is.null(fixture$kind)) fixture$kind = "design_draw"
	fixture$key = paste(fixture$name, fixture$quantity, sep = "$")
	fixture
}

# Writes the fixture, refusing to change or drop an existing row unless
# allow_changes is TRUE (EDI_REPRO_OVERWRITE_FIXTURE=true). Adding rows for a
# new class or method needs only EDI_REPRO_WRITE_FIXTURE=true; changing a
# committed digest is an announced change to seed-pinned draws (NEWS line), so
# it needs the second flag too. Returns the changed/dropped keys invisibly.
repro_write_fixture = function(fixture, path, allow_changes = FALSE) {
	fixture = fixture[order(fixture$kind, fixture$name, fixture$quantity), c("kind", "name", "quantity", "value_chr"), drop = FALSE]
	rownames(fixture) = NULL
	changed = character()
	if (file.exists(path)) {
		old = repro_read_fixture(path)
		new_key = paste(fixture$name, fixture$quantity, sep = "$")
		new_value = stats::setNames(fixture$value_chr, new_key)
		changed = old$key[!(old$key %in% new_key) | new_value[old$key] != old$value_chr]
		changed = changed[!is.na(changed)]
		if (length(changed) && !isTRUE(allow_changes)) {
			stop(sprintf(paste0(
				"Refusing to overwrite %s: %d committed digest(s) would change or disappear (%s). ",
				"If the change to seed-pinned draws is intended, add a NEWS line and rerun with ",
				"EDI_REPRO_OVERWRITE_FIXTURE=true as well."),
				path, length(changed), paste(changed, collapse = ", ")), call. = FALSE)
		}
	}
	dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
	utils::write.csv(fixture, path, row.names = FALSE)
	invisible(changed)
}

# Every concrete design class that is marked seed-reproducible and has an
# assignment mechanism (the observational "none" family has none to draw).
repro_required_design_classes = function() {
	registry = EDI:::design_class_registry_as_list()
	sort(names(Filter(function(m) !isTRUE(m$abstract) && isTRUE(m$seed_reproducible_draw) &&
		!identical(m$randomization_family, "none"), registry)))
}

# Every resampling capability any registered inference class advertises.
repro_required_resampling_methods = function() {
	registry = EDI:::inference_class_registry_as_list()
	caps = unique(unlist(lapply(names(registry), function(n)
		tryCatch(EDI:::get_effective_capabilities(n), error = function(e) character()))))
	sort(grep("_ci$", grep("randomization|bootstrap|jackknife|subsampling|permutation", caps, value = TRUE),
		value = TRUE, invert = TRUE))
}

test_that("seed-pinned design draws are identical across thread counts, legs and the committed fixture", {
	design_rows = do.call(rbind, repro_digest_rows())
	skip_if(is.null(design_rows), "no design case could run (missing Suggests)")
	float_rows = do.call(rbind, repro_float_rows())
	all_rows = rbind(design_rows, float_rows)
	all_rows$leg = repro_leg_name()
	all_rows$edi_version = as.character(utils::packageVersion("EDI"))
	all_rows$edi_portable = as.character(EDI:::edi_build_info_cpp()$env_edi_portable)

	out_dir = Sys.getenv("EDI_REPRO_DIGEST_DIR")
	if (nzchar(out_dir)) {
		dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
		# write.csv keeps only 15 significant digits; keep all 17 for the float comparison.
		to_write = all_rows
		to_write$value_num = ifelse(is.na(to_write$value_num), NA_character_, sprintf("%.17g", to_write$value_num))
		utils::write.csv(to_write, file.path(out_dir, paste0(gsub("[^A-Za-z0-9._-]", "_", repro_leg_name()), ".csv")),
			row.names = FALSE)
	}

	# Legs that are meant to have OpenMP (e.g. the macOS libomp leg) set
	# EDI_EXPECT_OPENMP=true, so a toolchain change that silently drops OpenMP
	# fails here instead of turning the thread-count check into a no-op.
	if (identical(Sys.getenv("EDI_EXPECT_OPENMP"), "true")) {
		multi = design_rows[design_rows$threads > 1L, , drop = FALSE]
		expect_true(nrow(multi) > 0L, info = "EDI_EXPECT_OPENMP=true but no thread count above 1 was tried")
		expect_true(all(multi$threads_obtained == multi$threads),
			info = "EDI_EXPECT_OPENMP=true but the OpenMP team size did not follow set_package_threads()")
	}

	# Check 1: thread-count invariance within this run.
	design_rows$key = paste(design_rows$name, design_rows$quantity, sep = "$")
	for (key in unique(design_rows$key)) {
		digests = design_rows$value_chr[design_rows$key == key]
		expect_identical(length(unique(digests)), 1L, info = paste(key, "digest changes with the thread count"))
	}

	# Check 2: integer draws match the committed fixture.
	fixture_path = repro_fixture_path()
	if (identical(Sys.getenv("EDI_REPRO_WRITE_FIXTURE"), "true")) {
		fixture = unique(design_rows[design_rows$threads == 1L, c("kind", "name", "quantity", "value_chr")])
		repro_write_fixture(fixture, fixture_path,
			allow_changes = identical(Sys.getenv("EDI_REPRO_OVERWRITE_FIXTURE"), "true"))
		skip("fixture regenerated (EDI_REPRO_WRITE_FIXTURE=true); rerun without it to check")
	}
	skip_if_not(file.exists(fixture_path), "no committed cross-platform fixture yet")
	fixture = repro_read_fixture(fixture_path)
	for (key in unique(design_rows$key)) {
		expected = fixture$value_chr[fixture$key == key]
		expect_identical(length(expected), 1L, info = paste(key, "has no row in the committed fixture"))
		if (length(expected) == 1L) {
			got = unique(design_rows$value_chr[design_rows$key == key])
			expect_identical(got, expected, info = paste(key, "draw differs from the committed fixture"))
		}
	}
})

test_that("the fixture has a row for every design class and resampling method in the registries", {
	# A new design class or resampling capability fails here until it has a case
	# above and the fixture is regenerated with EDI_REPRO_WRITE_FIXTURE=true.
	fixture_path = repro_fixture_path()
	expect_true(file.exists(fixture_path), info = "the committed cross-platform fixture is missing")
	skip_if_not(file.exists(fixture_path))
	fixture = repro_read_fixture(fixture_path)

	designs = repro_required_design_classes()
	expect_true(length(designs) > 0L)
	expect_identical(setdiff(designs, names(repro_design_cases)), character(),
		info = "design class(es) with no case in repro_design_cases")
	expect_identical(setdiff(designs, fixture$name[fixture$kind == "design_draw" & fixture$quantity == "w_md5"]),
		character(), info = "design class(es) with no w_md5 row in the fixture")
	seq_cases = names(Filter(function(case) isTRUE(case$sequential), repro_design_cases))
	expect_identical(setdiff(seq_cases, fixture$name[fixture$quantity == "w_seq_md5"]), character(),
		info = "sequential design(s) with no w_seq_md5 row in the fixture")

	methods = repro_required_resampling_methods()
	expect_true(length(methods) > 0L)
	expect_identical(setdiff(methods, names(repro_resampling_cases)), character(),
		info = "resampling capability(ies) with no case in repro_resampling_cases")
	expect_identical(setdiff(methods, fixture$name[fixture$kind == "resampling_draw"]), character(),
		info = "resampling capability(ies) with no row in the fixture")
})

test_that("fixture regeneration refuses to change a committed digest without the overwrite flag", {
	path = tempfile(fileext = ".csv")
	on.exit(unlink(path), add = TRUE)
	base = data.frame(kind = "design_draw", name = c("A", "B"), quantity = "w_md5",
		value_chr = c("aaaa", "bbbb"), stringsAsFactors = FALSE)
	# No file yet: written.
	repro_write_fixture(base, path)
	expect_identical(repro_read_fixture(path)$value_chr, c("aaaa", "bbbb"))
	# Unchanged rows plus a new one: written without the overwrite flag.
	added = rbind(base, data.frame(kind = "design_draw", name = "C", quantity = "w_md5",
		value_chr = "cccc", stringsAsFactors = FALSE))
	expect_identical(repro_write_fixture(added, path), character())
	expect_identical(repro_read_fixture(path)$name, c("A", "B", "C"))
	# A changed digest or a dropped row: refused, and the file is left as it was.
	changed = added
	changed$value_chr[2] = "XXXX"
	expect_error(repro_write_fixture(changed, path), "Refusing to overwrite.*B\\$w_md5")
	expect_error(repro_write_fixture(added[-3, ], path), "Refusing to overwrite.*C\\$w_md5")
	expect_identical(repro_read_fixture(path)$value_chr, c("aaaa", "bbbb", "cccc"))
	# With the overwrite flag: written, and the changed keys are reported.
	expect_identical(repro_write_fixture(changed, path, allow_changes = TRUE), "B$w_md5")
	expect_identical(repro_read_fixture(path)$value_chr, c("aaaa", "XXXX", "cccc"))
})
