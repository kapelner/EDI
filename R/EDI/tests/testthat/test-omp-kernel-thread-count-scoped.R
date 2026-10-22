library(testthat)
library(EDI)

omp_kernel_source_dir = function() {
	candidates = c(
		file.path("R", "EDI", "src"),
		file.path("..", "..", "src"),
		file.path("..", "src"),
		"src"
	)
	hit = candidates[dir.exists(candidates)]
	if (!length(hit)) return(NA_character_)
	hit[[1L]]
}

test_that("OpenMP kernels scope thread counts instead of changing global state", {
	dir = omp_kernel_source_dir()
	skip_if(is.na(dir), "native source tree is unavailable")

	cpp_files = list.files(dir, pattern = "\\.cpp$", full.names = TRUE)
	active_setters = vapply(cpp_files, function(path) {
		lines = sub("//.*$", "", readLines(path, warn = FALSE))
		any(grepl("omp_set_num_threads\\s*\\(", lines, perl = TRUE))
	}, logical(1L))
	expect_identical(basename(cpp_files[active_setters]), "omp_control.cpp")

	threaded_files = c(
		"binary_match_search.cpp", "fast_adjacent_category_logit.cpp",
		"fast_bai_parallel.cpp", "fast_coxph_regression.cpp",
		"fast_jonckheere_terpstra.cpp", "fast_kk_wilcox_parallel.cpp",
		"fast_logrank.cpp", "fast_robust_regression.cpp",
		"fast_stereotype_logit.cpp", "fast_survival_stats.cpp",
		"fast_weibull_regression.cpp", "fast_wilcox_hl.cpp",
		"kk_compound_distr_parallel.cpp",
		"ols_distr_parallel.cpp", "rand_bootstrap_mean_diff_parallel.cpp",
		"rand_bootstrap_ols_parallel.cpp", "ridit_distr_parallel.cpp",
		"simple_mean_diff_parallel.cpp"
	)
	for (name in threaded_files) {
		lines = readLines(file.path(dir, name), warn = FALSE)
		regions = grep("^\\s*#pragma omp parallel", lines, value = TRUE)
		expect_true(length(regions) > 0L, info = name)
		expect_true(all(grepl(
			"num_threads\\(EDI_KERNEL_NUM_THREADS\\(num_cores\\)\\)", regions, perl = TRUE
		)), info = name)
	}
})

test_that("a binary-match kernel call preserves the configured OpenMP maximum", {
	get_max = EDI:::get_omp_max_threads_cpp
	set_threads = EDI:::set_package_threads
	old_max = get_max()
	target_threads = if (identical(EDI:::edi_env$last_set_threads, 2L)) 3L else 2L
	set_threads(target_threads)
	current_max = get_max()
	on.exit(set_threads(old_max), add = TRUE)
	skip_if(current_max < 2L, "OpenMP runtime exposes fewer than two threads")

	pairs = matrix(c(1L, 2L, 3L, 4L), nrow = 2L, ncol = 2L)
	EDI:::draw_binary_match_assignments_cpp(pairs, n = 4L, r = 64L, num_cores = 1L)
	expect_identical(get_max(), current_max)
})

test_that("the OpenMP probe observes the configured package team size without timing", {
	ns = asNamespace("EDI")
	if (!exists("probe_omp_team_size_cpp", envir = ns, inherits = FALSE) ||
			!exists("_EDI_probe_omp_team_size_cpp", envir = ns, inherits = FALSE)) {
		skip("requires the rebuilt native library with the thread-team probe")
	}
	probe = EDI:::probe_omp_team_size_cpp
	get_max = EDI:::get_omp_max_threads_cpp
	set_threads = EDI:::set_package_threads
	old_max = get_max()
	on.exit(set_threads(old_max), add = TRUE)
	# EDI intentionally defaults its package-wide OpenMP limit to one. Configure
	# a multi-thread team before deciding whether this runtime supports OpenMP.
	target_threads = 2L
	set_threads(target_threads)
	skip_if(get_max() < target_threads, "OpenMP runtime cannot configure multiple threads")
	# Pass a deliberately different argument: the R build's policy must use the
	# configured package OpenMP count, not the inference worker count.
	observed = probe(1L)
	expect_identical(observed, target_threads)
	expect_identical(get_max(), target_threads)
})
