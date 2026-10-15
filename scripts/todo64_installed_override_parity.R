# Compile-free probe for TODO-64's not-yet-covered fast-distribution overrides.
# Run against the currently installed package with:
#   Rscript scripts/todo64_installed_override_parity.R
library(EDI)

set.seed(64001)

make_fixed <- function(type = "continuous", n = 24L) {
	d <- DesignFixediBCRD$new(n = n, response_type = type, verbose = FALSE)
	d$add_all_subjects_to_experiment(data.frame(x = seq_len(n) / n))
	d$assign_w_to_all_subjects()
	w <- d$get_w()
	y <- if (type == "count") {
		rpois(n, exp(0.3 * w))
	} else if (type == "proportion") {
		pmin(0.99, pmax(0.01, plogis(-0.2 + 0.7 * w + rnorm(n, 0, 0.4))))
	} else {
		0.5 * w + rnorm(n)
	}
	d$add_all_subject_responses(y)
	d
}

make_kk <- function(type = "continuous", n = 24L) {
	d <- DesignSeqOneByOneKK14$new(n = n, response_type = type, verbose = FALSE)
	for (i in seq_len(n)) d$add_one_subject_to_experiment_and_assign(data.frame(x = i / n))
	y <- if (type == "count") {
		rpois(n, 2)
	} else if (type == "proportion") {
		pmin(0.99, pmax(0.01, plogis(rnorm(n))))
	} else {
		rnorm(n)
	}
	d$add_all_subject_responses(y)
	d
}

cases <- list(
	SimpleAverage = list(InferenceAllSimpleAverageDiff, make_fixed()),
	Bai14 = list(InferenceBaiAdjustedTKK14, make_kk()),
	Bai21 = list(InferenceBaiAdjustedTKK21, make_kk()),
	ContinRobust = list(InferenceContinRobustRegr, make_fixed()),
	PropQuantile = list(InferencePropQuantileRegr, make_fixed("proportion")),
	KKOLSIVWC = list(InferenceContinKKOLSIVWC, make_kk()),
	KKRobustIVWC = list(InferenceContinKKRobustRegrIVWC, make_kk()),
	CountKKHurdleIVWC = list(InferenceCountKKHurdlePoissonIVWC, make_kk("count")),
	KKRobustOneLik = list(InferenceContinKKRobustRegrOneLik, make_kk()),
	KKQuantileOneLik = list(InferenceContinKKQuantileRegrOneLik, make_kk()),
	ContinQuantile = list(InferenceContinQuantileRegr, make_fixed()),
	ContinLin = list(InferenceContinLin, make_fixed())
)

results <- lapply(names(cases), function(name) {
	class_and_design <- cases[[name]]
	inf <- class_and_design[[1]]$new(class_and_design[[2]], verbose = FALSE)
	inf$num_cores <- 1L
	p <- inf$.__enclos_env__$private
	perms <- p$generate_permutations(4L)
	fast <- p$compute_fast_randomization_distr(p$y, perms, 0.2, "none")
	worker <- p$compute_fast_randomization_distr_via_reused_worker(p$y, perms, 0.2, "none")
	data.frame(
		class = name,
		draws = length(fast),
		finite = sum(is.finite(fast)),
		parity = isTRUE(all.equal(fast, worker, tolerance = 1e-10)),
		stringsAsFactors = FALSE
	)
})

# InferenceRandCustom has a callback fast path rather than a native kernel.
d <- DesignFixedBernoulli$new(n = 20L, response_type = "continuous", verbose = FALSE)
d$add_all_subjects_to_experiment(data.frame(x = seq_len(20L)))
d$overwrite_all_subject_assignments(rep(c(0, 1), each = 10L))
d$add_all_subject_responses(c(seq_len(10L), seq_len(10L) + 2))
welch <- function(y, w, dead) {
	y_t <- y[w == 1]
	y_c <- y[w == 0]
	(mean(y_t) - mean(y_c)) / sqrt(var(y_t) / length(y_t) + var(y_c) / length(y_c))
}
inf <- InferenceRandCustom$new(d, custom_randomization_statistic_function = welch, verbose = FALSE)
p <- inf$.__enclos_env__$private
w_mat <- replicate(5L, sample(d$get_w()))
perms <- list(w_mat = w_mat)
fast <- p$compute_fast_randomization_distr(p$y, perms, 0.25, "none")
worker <- p$compute_fast_randomization_distr_via_reused_worker(p$y, perms, 0.25, "none")
results[[length(results) + 1L]] <- data.frame(
	class = "RandCustom",
	draws = length(fast),
	finite = sum(is.finite(fast)),
	parity = isTRUE(all.equal(fast, worker, tolerance = 1e-10)),
	stringsAsFactors = FALSE
)

result_table <- do.call(rbind, results)
print(result_table, row.names = FALSE)
stopifnot(all(result_table$draws == c(rep(4L, 12L), 5L)))
stopifnot(all(result_table$parity))
stopifnot(sum(result_table$finite == 0L) == 1L)
stopifnot(result_table$finite[result_table$class == "KKOLSIVWC"] == 0L)
