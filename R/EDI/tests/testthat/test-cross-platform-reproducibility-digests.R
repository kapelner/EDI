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
# NOT_CRAN is "true". Keep this file fast (well under 10 seconds).
#
# To regenerate the fixture after an announced change to seed-pinned draws
# (needs a NEWS line), run this file with EDI_REPRO_WRITE_FIXTURE=true.

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
# The stratified designs need a factor column; the other cases keep repro_X so
# their digests stay comparable with earlier fixtures.
repro_X_strata = cbind(repro_X, s = factor(rep(1:2, length.out = repro_n)))

# name -> list(packages, build, X, sequential), where build() returns a fresh
# design. X defaults to repro_X. sequential = TRUE drives the design through
# add_one_subject_to_experiment_and_assign() instead of
# add_all_subjects_to_experiment(). These cover the classes with OpenMP draw
# kernels, a serial control, and every class whose draws moved from
# std::shuffle / <random> to the portable Fisher-Yates shuffle
# (release_v1_0_5.md TODO-91): iBCRD, blocking, SPBR and random block sizes.
repro_design_cases = list(
	DesignFixedBernoulli = list(packages = character(), build = function()
		DesignFixedBernoulli$new(n = repro_n, response_type = "continuous")),
	DesignFixedRerandomization = list(packages = character(), build = function()
		DesignFixedRerandomization$new(n = repro_n, response_type = "continuous")),
	DesignFixedGreedy = list(packages = character(), build = function()
		DesignFixedGreedy$new(n = repro_n, response_type = "continuous")),
	DesignFixedGreedyDOptimal = list(packages = character(), build = function()
		DesignFixedGreedyDOptimal$new(n = repro_n, response_type = "continuous")),
	DesignFixedMatchingGreedyPairSwitching = list(packages = "nbpMatching", build = function()
		DesignFixedMatchingGreedyPairSwitching$new(n = repro_n, response_type = "continuous")),
	DesignFixedBinaryMatch = list(packages = "nbpMatching", build = function()
		DesignFixedBinaryMatch$new(n = repro_n, response_type = "continuous")),
	DesignFixediBCRD = list(packages = character(), build = function()
		DesignFixediBCRD$new(n = repro_n, response_type = "continuous")),
	DesignFixedBlocking = list(packages = character(), X = repro_X_strata, build = function()
		DesignFixedBlocking$new(n = repro_n, response_type = "continuous", strata_cols = "s")),
	DesignSeqOneByOneiBCRD = list(packages = character(), sequential = TRUE, build = function()
		DesignSeqOneByOneiBCRD$new(n = repro_n, response_type = "continuous")),
	DesignSeqOneByOneSPBR = list(packages = character(), X = repro_X_strata, sequential = TRUE, build = function()
		DesignSeqOneByOneSPBR$new(n = repro_n, response_type = "continuous", strata_cols = "s")),
	DesignSeqOneByOneRandomBlockSize = list(packages = character(), sequential = TRUE, build = function()
		DesignSeqOneByOneRandomBlockSize$new(n = repro_n, response_type = "continuous"))
)

repro_digest_rows = function() {
	old_cores = EDI:::get_num_cores()
	on.exit(EDI:::set_package_threads(old_cores), add = TRUE)
	rows = list()
	for (name in names(repro_design_cases)) {
		case = repro_design_cases[[name]]
		if (length(case$packages) && !all(vapply(case$packages, requireNamespace, logical(1), quietly = TRUE))) next
		for (threads in repro_thread_counts()) {
			EDI:::set_package_threads(threads)
			# Read the OpenMP team size before the draw: some kernels reset it.
			obtained = EDI:::get_omp_max_threads_cpp()
			des = case$build()
			X = if (is.null(case$X)) repro_X else case$X
			digests = list()
			if (isTRUE(case$sequential)) {
				set.seed(20261013L)
				for (i in seq_len(nrow(X))) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
				digests$w_seq_md5 = repro_md5(des$get_w())
			} else {
				des$add_all_subjects_to_experiment(X)
			}
			set.seed(20261013L)
			digests$w_md5 = repro_md5(des$draw_ws_according_to_design(repro_r))
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
	rows
}

repro_float_rows = function() {
	old_seed = if (exists(".Random.seed", envir = globalenv())) get(".Random.seed", envir = globalenv()) else NULL
	on.exit(if (!is.null(old_seed)) assign(".Random.seed", old_seed, envir = globalenv()), add = TRUE)
	set.seed(11L)
	des = DesignFixedBernoulli$new(n = repro_n, response_type = "continuous")
	des$add_all_subjects_to_experiment(repro_X)
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(repro_X$x1 + 0.5 * des$get_w() + rnorm(repro_n))
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
	fixture_path = test_path("fixtures", "cross_platform_digests.csv")
	if (identical(Sys.getenv("EDI_REPRO_WRITE_FIXTURE"), "true")) {
		dir.create(dirname(fixture_path), recursive = TRUE, showWarnings = FALSE)
		fixture = unique(design_rows[design_rows$threads == 1L, c("name", "quantity", "value_chr")])
		utils::write.csv(fixture, fixture_path, row.names = FALSE)
		skip("fixture regenerated (EDI_REPRO_WRITE_FIXTURE=true); rerun without it to check")
	}
	skip_if_not(file.exists(fixture_path), "no committed cross-platform fixture yet")
	fixture = utils::read.csv(fixture_path, stringsAsFactors = FALSE)
	fixture$key = paste(fixture$name, fixture$quantity, sep = "$")
	for (key in unique(design_rows$key)) {
		expected = fixture$value_chr[fixture$key == key]
		expect_identical(length(expected), 1L, info = paste(key, "has no row in the committed fixture"))
		if (length(expected) == 1L) {
			got = unique(design_rows$value_chr[design_rows$key == key])
			expect_identical(got, expected, info = paste(key, "draw differs from the committed fixture"))
		}
	}
})
