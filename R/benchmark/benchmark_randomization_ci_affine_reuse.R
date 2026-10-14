#!/usr/bin/env Rscript

# Randomization-CI affine-reuse benchmark. This source-loads EDI with
# compile = FALSE and compares the shipped affine cache with the general
# refit-at-each-delta path on identical data and permutation matrices.

pkgload::load_all("R/EDI", compile = FALSE, quiet = TRUE)

quick = identical(Sys.getenv("EDI_BENCHMARK_QUICK"), "1")
ns = if (quick) 100L else c(100L, 500L, 1000L)
rs = if (quick) 201L else c(201L, 1001L, 2001L)
# Use an even number of measured pairs so each implementation runs first the
# same number of times. The quick mode stays small but exercises both orders.
repetitions = if (quick) 2L else 4L

make_design = function(n, seed){
	set.seed(seed)
	x = data.frame(x1 = rnorm(n), x2 = rnorm(n))
	des = DesignFixedBernoulli$new(n = n, response_type = "continuous", seed = seed, verbose = FALSE)
	des$add_all_subjects_to_experiment(x)
	des$assign_w_to_all_subjects()
	w = des$get_w()
	des$add_all_subject_responses(0.5 * w + 0.2 * x$x1 - 0.1 * x$x2 + rnorm(n))
	des
}

elapsed = function(expr){
	unname(system.time(force(expr))[["elapsed"]])
}

make_inference = function(cls, des, perms, affine){
	inf = cls$new(des, model_formula = ~., verbose = FALSE)
	inf$num_cores = 1L
	p = inf$.__enclos_env__$private
	unlockBinding("generate_permutations", p)
	p$generate_permutations = function(r) perms
	if (!affine) {
		unlockBinding("supports_additive_delta_shift", p)
		p$supports_additive_delta_shift = function(...) FALSE
	}
	inf
}

rows = list()
row_id = 0L
for (class_name in c("InferenceAllSimpleAverageDiff", "InferenceContinOLS")) {
	cls = get(class_name, envir = asNamespace("EDI"))
	for (n in ns) for (r in rs) {
		des = make_design(n, 6800L + n + r)
		probe = cls$new(des, model_formula = ~., verbose = FALSE)
		probe$num_cores = 1L
		perms = probe$.__enclos_env__$private$generate_permutations(r)
		times_fast = times_slow = numeric(repetitions)
		args = list(alpha = 0.1, r = r, pval_epsilon = 0.01, show_progress = FALSE,
			ci_search_control = list(mc_enable = FALSE, high_precision_confirm = FALSE, seed = "none"))

		# Warm each path on a fresh inference object before collecting timings.
		# Both use the same design and fixed permutation matrix as the measured
		# pairs; the warm-up itself is not part of either timing.
		for (affine in c(TRUE, FALSE)) {
			warm = make_inference(cls, des, perms, affine)
			invisible(do.call(warm$compute_rand_confidence_interval, args))
		}

		for (rep in seq_len(repetitions)) {
			order = if (rep %% 2L == 1L) c("affine", "general") else c("general", "affine")
			for (path in order) {
				affine = identical(path, "affine")
				inf = make_inference(cls, des, perms, affine)
				elapsed_call = elapsed(do.call(inf$compute_rand_confidence_interval, args))
				if (affine) times_fast[rep] = elapsed_call else times_slow[rep] = elapsed_call
			}
		}
		row_id = row_id + 1L
		rows[[row_id]] = data.frame(
			class = class_name, n = n, r = r,
			affine_seconds = median(times_fast), general_seconds = median(times_slow),
			speedup = median(times_slow) / median(times_fast)
		)
		print(rows[[row_id]], row.names = FALSE)
	}
}

results = do.call(rbind, rows)
write.csv(results, row.names = FALSE)
