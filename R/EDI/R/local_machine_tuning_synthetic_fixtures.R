#' Synthetic-data fixture generators for benchmarking and golden tests
#'
#' These build a small, deterministic, complete (fully-responded) experiment
#' per response type. They were originally test-only helpers
#' (`tests/testthat/helper-inference-migration-harness.R`); moved into the
#' package so `local_machine_optimization.md`'s benchmark tuner (TODO-3) can
#' reuse the exact same synthetic-data recipe the migration golden tests use,
#' instead of maintaining a second, driftable copy. The migration golden
#' tests now call these package internals directly.
#'
#' @keywords internal
#' @noRd
add_all_subject_responses_seq = function(des, ys, deads = NULL){
	if (is.null(deads)){
		deads = rep(1, length(ys))
	}
	for (i in seq_along(ys)){
		if (isTRUE(deads[i] == 1)) {
			des$add_one_subject_response(i, y = ys[i])
		} else {
			des$add_one_subject_response(i, y_L = ys[i], y_R = Inf)
		}
	}
}

#' @keywords internal
#' @noRd
inference_migration_with_seed = function(seed, expr) {
	old_seed = if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
		get(".Random.seed", envir = .GlobalEnv)
	} else {
		NULL
	}
	on.exit({
		if (!is.null(old_seed)) {
			assign(".Random.seed", old_seed, envir = .GlobalEnv)
		} else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
			rm(".Random.seed", envir = .GlobalEnv)
		}
	}, add = TRUE)
	set.seed(seed)
	force(expr)
}

#' @keywords internal
#' @noRd
inference_migration_add_subjects = function(des, x) {
	for (i in seq_len(nrow(x))) {
		des$add_one_subject_to_experiment_and_assign(x[i, , drop = FALSE])
	}
	des
}

#' Build a small, complete, deterministic synthetic experiment for a response type
#'
#' @param response_type One of `"continuous"`, `"incidence"`, `"count"`,
#'   `"proportion"`, `"ordinal"`, `"survival"`.
#' @param n Number of subjects.
#' @param seed RNG seed (restored on exit; does not leak into caller state).
#' @return A completed `DesignSeqOneByOneBernoulli` with every subject
#'   assigned and responded.
#' @keywords internal
#' @noRd
inference_migration_complete_design = function(response_type, n = 12L, seed = 20260728L) {
	inference_migration_with_seed(seed, {
		x = data.frame(
			x = seq(-1.1, 1.1, length.out = n),
			z = rep(c(0L, 1L, 1L, 0L), length.out = n)
		)
		des = DesignSeqOneByOneBernoulli$new(
			n = n,
			response_type = response_type,
			verbose = FALSE
		)
		inference_migration_add_subjects(des, x)

		w01 = as.integer(des$.__enclos_env__$private$w == 1L)
		linpred = -0.2 + 0.55 * w01 + 0.25 * x$x - 0.15 * x$z
		if (identical(response_type, "continuous")) {
			y = 0.4 + 0.8 * w01 + 0.35 * x$x - 0.2 * x$z + seq(-0.3, 0.3, length.out = n)
			add_all_subject_responses_seq(des, y)
		} else if (identical(response_type, "incidence")) {
			y = as.integer(stats::plogis(linpred) > stats::quantile(stats::plogis(linpred), 0.45))
			add_all_subject_responses_seq(des, y)
		} else if (identical(response_type, "count")) {
			y = as.integer(pmax(0L, round(exp(0.6 + 0.35 * w01 + 0.2 * x$x))))
			add_all_subject_responses_seq(des, y)
		} else if (identical(response_type, "proportion")) {
			y = pmin(0.95, pmax(0.05, stats::plogis(linpred)))
			add_all_subject_responses_seq(des, y)
		} else if (identical(response_type, "ordinal")) {
			score = linpred + seq(-0.4, 0.4, length.out = n)
			y = as.integer(cut(score, breaks = c(-Inf, -0.15, 0.25, 0.65, Inf), labels = FALSE))
			add_all_subject_responses_seq(des, y)
		} else if (identical(response_type, "survival")) {
			y_lat = exp(1.2 - 0.25 * w01 + 0.1 * x$x)
			cens = exp(1.35 + 0.05 * x$z)
			add_all_subject_responses_seq(des, pmin(y_lat, cens), deads = as.integer(y_lat <= cens))
		} else {
			stop(sprintf("No migration golden fixture for response type `%s`.", response_type), call. = FALSE)
		}
		des
	})
}
