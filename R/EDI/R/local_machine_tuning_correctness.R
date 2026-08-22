#' Correctness gate for accepted deviations (TODO-8)
#'
#' A candidate setting winning the timing race is necessary but not
#' sufficient: \code{local_machine_optimization.md}'s stated invariant is
#' "bit-identical estimates and CIs under every setting the tuner is
#' allowed to flip" (within solver tolerance). This file re-fits every
#' accepted deviation once under \emph{both} settings on identical
#' synthetic data and compares outputs; any disagreement discards the
#' deviation and \code{warning()}s about it loudly, per the plan text.
#'
#' What is compared differs by axis, because what varies with the setting
#' differs:
#' \itemize{
#' \item \strong{Cold start / optimizer algorithm} change the fit path
#'   itself, so the comparable, deterministic quantity is the point
#'   estimate (\code{compute_estimate()}).
#' \item \strong{Warm start} only affects resampling replicates, not a
#'   fresh fit's point estimate -- so this axis instead re-runs the actual
#'   resampling \emph{operation} (the same generic call the axis times)
#'   under both settings, with the RNG reset to the identical seed
#'   immediately before each call, and compares every numeric value the
#'   call returns (a CI's bounds, a jackknife estimate, ...).
#' \item \strong{Parallel core count} changes which RNG stream a forked
#'   worker uses, so a resampling operation's CI is expected to differ
#'   (and comparing it would produce false "disagreements" that are really
#'   just independent Monte Carlo draws) -- but the point estimate itself
#'   does not depend on core count, so that is what is compared, exactly
#'   as for cold start/optimizer.
#' }
#' An output that cannot be extracted as finite numeric values (an error,
#' a non-numeric return) is treated as \strong{unverifiable}, not as
#' agreement -- unverifiable deviations are discarded exactly like
#' disagreeing ones, since "we could not check" is not evidence of safety.
#'
#' @keywords internal
#' @noRd
NULL

#' @keywords internal
#' @noRd
EDI_TUNING_CORRECTNESS_DEFAULT_TOLERANCE = 1e-6

#' Extract a fitted `Inference` object's point estimate as a finite numeric
#' scalar, or `NA_real_` on any failure
#'
#' @keywords internal
#' @noRd
edi_tuning_safe_point_estimate = function(inf) {
	val = tryCatch(as.numeric(inf$compute_estimate(estimate_only = TRUE)), error = function(e) NA_real_)
	if (length(val) == 0L || !is.finite(val[[1]])) return(NA_real_)
	val[[1]]
}

#' Extract every finite numeric value out of an arbitrary resampling-method
#' return value (a CI vector/list, a scalar estimate, ...), or `numeric(0)`
#' on any failure
#'
#' @keywords internal
#' @noRd
edi_tuning_safe_numeric_values = function(x) {
	val = tryCatch(as.numeric(unlist(x, use.names = FALSE)), error = function(e) numeric(0))
	val[is.finite(val)]
}

#' Do two numeric vectors agree within tolerance, elementwise, after
#' sorting?
#'
#' Sorted so a CI returned as \code{c(upper, lower)} on one side and
#' \code{c(lower, upper)} on the other still compares correctly. Requires
#' equal, nonzero length -- an empty or length-mismatched comparison is
#' unverifiable, not an agreement, and returns \code{FALSE}.
#'
#' @param tol Combined relative+absolute tolerance: agree iff
#'   \code{abs(a - b) <= tol * pmax(1, abs(a), abs(b))} for every paired
#'   element.
#' @keywords internal
#' @noRd
edi_tuning_values_agree = function(a, b, tol = EDI_TUNING_CORRECTNESS_DEFAULT_TOLERANCE) {
	if (length(a) == 0L || length(b) == 0L || length(a) != length(b)) return(FALSE)
	a = sort(a); b = sort(b)
	all(abs(a - b) <= tol * pmax(1, abs(a), abs(b)))
}

#' Verify one cold-start deviation: do point estimates agree under `from`
#' and `to`?
#'
#' @param dev One element of \code{edi_tuning_tune_cold_start()}'s return
#'   value.
#' @return \code{list(agree, value_from, value_to)}.
#' @keywords internal
#' @noRd
edi_tuning_verify_cold_start_deviation = function(dev, tol = EDI_TUNING_CORRECTNESS_DEFAULT_TOLERANCE) {
	seed = edi_tuning_default_seed(dev$class, dev$n)
	a = edi_tuning_safe_point_estimate(edi_tuning_cold_start_run_setting(dev$class, dev$response_type, dev$n, dev$from, seed))
	b = edi_tuning_safe_point_estimate(edi_tuning_cold_start_run_setting(dev$class, dev$response_type, dev$n, dev$to, seed))
	list(agree = edi_tuning_values_agree(a, b, tol), value_from = a, value_to = b)
}

#' Verify one optimizer-algorithm deviation: do point estimates agree
#' under `from` and `to`?
#'
#' @inheritParams edi_tuning_verify_cold_start_deviation
#' @keywords internal
#' @noRd
edi_tuning_verify_optimizer_deviation = function(dev, tol = EDI_TUNING_CORRECTNESS_DEFAULT_TOLERANCE) {
	seed = edi_tuning_default_seed(dev$class, dev$n)
	a = edi_tuning_safe_point_estimate(edi_tuning_construct_under_optimizer(dev$class, dev$response_type, dev$n, dev$from, seed))
	b = edi_tuning_safe_point_estimate(edi_tuning_construct_under_optimizer(dev$class, dev$response_type, dev$n, dev$to, seed))
	list(agree = edi_tuning_values_agree(a, b, tol), value_from = a, value_to = b)
}

#' Verify one warm-start deviation: does the resampling operation's output
#' agree under `from` and `to`, with the RNG reset to the same seed
#' immediately before each call?
#'
#' @param operation The warm-start operation this deviation belongs to.
#' @inheritParams edi_tuning_verify_cold_start_deviation
#' @keywords internal
#' @noRd
edi_tuning_verify_warm_start_deviation = function(dev, operation, tol = EDI_TUNING_CORRECTNESS_DEFAULT_TOLERANCE) {
	seed = edi_tuning_default_seed(dev$class, dev$n)
	run_once = function(setting) {
		inference_migration_with_seed(seed, edi_tuning_warm_start_run_setting(dev$class, dev$response_type, dev$n, setting, seed, operation))
	}
	a = edi_tuning_safe_numeric_values(tryCatch(run_once(dev$from), error = function(e) NULL))
	b = edi_tuning_safe_numeric_values(tryCatch(run_once(dev$to), error = function(e) NULL))
	list(agree = edi_tuning_values_agree(a, b, tol), value_from = a, value_to = b)
}

#' Verify one parallel-crossover deviation: does the point estimate agree
#' under serial and `num_cores`?
#'
#' Deliberately does \strong{not} compare the resampling operation's CI --
#' a forked worker uses a different RNG stream than the serial path, so
#' its CI is expected to differ even when everything is working correctly;
#' comparing it would manufacture false disagreements. The point estimate
#' is core-count-independent and is the actual invariant this axis needs
#' to hold.
#'
#' @inheritParams edi_tuning_verify_cold_start_deviation
#' @keywords internal
#' @noRd
edi_tuning_verify_parallel_deviation = function(dev, tol = EDI_TUNING_CORRECTNESS_DEFAULT_TOLERANCE) {
	seed = edi_tuning_default_seed(dev$class, dev$crossover_n)
	des_a = edi_tuning_synthetic_experiment(dev$response_type, n = dev$crossover_n, seed = seed)
	des_b = edi_tuning_synthetic_experiment(dev$response_type, n = dev$crossover_n, seed = seed)
	generator = get(dev$class, envir = asNamespace("EDI"), inherits = FALSE)
	a = edi_tuning_safe_point_estimate(generator$new(des_a))
	b = edi_tuning_safe_point_estimate(generator$new(des_b))
	list(agree = edi_tuning_values_agree(a, b, tol), value_from = a, value_to = b)
}

#' Run the correctness gate over one axis's raw deviations, discarding and
#' `warning()`-ing about any that fail to verify
#'
#' @param deviations A list of raw deviations (one axis's worth).
#' @param verify_fn \code{function(dev) -> list(agree, value_from,
#'   value_to)} -- one of the \code{edi_tuning_verify_*_deviation}
#'   functions above (partially applied with \code{operation}/\code{tol}
#'   as needed).
#' @param axis_label Character, used only in the warning text (e.g.
#'   \code{"cold start"}, \code{"warm start (jackknife)"}).
#' @return \code{list(kept, discarded)}: \code{kept} is the subset of
#'   \code{deviations} that verified; \code{discarded} is a list of
#'   \code{c(dev, verification)} for everything that did not, each with a
#'   `warning()` already emitted.
#' @keywords internal
#' @noRd
edi_tuning_apply_correctness_gate = function(deviations, verify_fn, axis_label) {
	# Real verify_fn's have a trailing `tol` argument with a default (`function(dev,
	# tol = ...)`), so only the first formal is required -- assert callability with a
	# single argument, not an exact formal count.
	checkmate::assertFunction(verify_fn)
	checkmate::assertString(axis_label)
	kept = list()
	discarded = list()
	for (dev in deviations) {
		verification = tryCatch(
			verify_fn(dev),
			error = function(e) list(agree = FALSE, value_from = NA_real_, value_to = NA_real_, error = conditionMessage(e))
		)
		if (isTRUE(verification$agree)) {
			kept[[length(kept) + 1L]] = dev
		} else {
			discarded[[length(discarded) + 1L]] = utils::modifyList(dev, verification)
			warning(sprintf(
				"tune_EDI_for_this_machine(): correctness gate discarded a %s deviation for %s (n=%s): values did not agree under both settings (from=%s -> %s, to=%s -> %s). Keeping the shipped default.",
				axis_label, dev$class %||% "?", dev$n %||% dev$crossover_n %||% NA,
				format(dev$from %||% NA), format(verification$value_from %||% NA),
				format(dev$to %||% NA), format(verification$value_to %||% NA)
			), call. = FALSE, immediate. = TRUE)
		}
	}
	list(kept = kept, discarded = discarded)
}
