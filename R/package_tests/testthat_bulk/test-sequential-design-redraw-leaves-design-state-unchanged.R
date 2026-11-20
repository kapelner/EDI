# v1.0.6-TODO-42: draw_ws_according_to_design() on a live sequential design must leave
# every piece of design state exactly as it was: the realized w, urn/block/match
# bookkeeping, per-subject caches. The generic DesignSeqOneByOne replay (used by the
# Urn design and by custom sequential designs) rebuilt private$w subject by subject
# and left the last replayed vector in place of the subjects' real assignments, so
# InferenceIncidCMH's SE path (which redraws from the design) silently changed the
# allocation every later inference saw.
# v1.0.6-TODO-183: mid-trial redraws are consistent: every sequential design returns one
# row per enrolled subject (t, not the planned n), Pocock-Simon no longer errors before
# the last subject arrives, and the generic replay advances private$t so a custom
# assignment_rule() that reads t sees the subject being replayed.

redraw_classes = c("DesignSeqOneByOneBernoulli", "DesignSeqOneByOneEfron", "DesignSeqOneByOneAtkinson",
	"DesignSeqOneByOnePocockSimon", "DesignSeqOneByOneUrn", "DesignSeqOneByOneiBCRD",
	"DesignSeqOneByOneSPBR", "DesignSeqOneByOneRandomBlockSize", "DesignSeqOneByOneKK14",
	"DesignSeqOneByOneKK21", "DesignSeqOneByOneKK21stepwise")

redraw_n = 30L
redraw_data = local({
	old = if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) get(".Random.seed", envir = .GlobalEnv) else NULL
	set.seed(4242)
	X = data.frame(x1 = rnorm(redraw_n), x2 = rnorm(redraw_n), s = factor(sample(c("a", "b"), redraw_n, TRUE)))
	y = X$x1 + rnorm(redraw_n)
	y_bin = as.numeric(X$x1 + rnorm(redraw_n) > 0)
	if (is.null(old)) rm(".Random.seed", envir = .GlobalEnv) else assign(".Random.seed", old, envir = .GlobalEnv)
	list(X = X, y = y, y_bin = y_bin)
})

redraw_make = function(cls, seed = NULL, response_type = "continuous") {
	args = list(n = redraw_n, response_type = response_type, seed = seed, verbose = FALSE)
	if (cls %in% c("DesignSeqOneByOnePocockSimon", "DesignSeqOneByOneSPBR", "DesignSeqOneByOneRandomBlockSize")) {
		args$strata_cols = "s"
	}
	do.call(get(cls, envir = asNamespace("EDI"))$new, args)
}

redraw_enroll = function(des, ts, y) {
	for (t in ts) {
		des$add_one_subject_to_experiment_and_assign(redraw_data$X[t, , drop = FALSE])
		des$add_one_subject_response(t, y[t])
	}
	invisible(des)
}

# Every non-function, non-environment private field of the design.
redraw_state = function(des) {
	pe = des$.__enclos_env__$private
	nm = ls(pe, all.names = TRUE)
	keep = !vapply(nm, function(k) is.function(pe[[k]]) || is.environment(pe[[k]]), logical(1))
	mget(nm[keep], envir = pe)
}

expect_same_state = function(before, after, info) {
	expect_setequal(names(after), names(before))
	changed = names(before)[!vapply(names(before), function(k) identical(before[[k]], after[[k]]), logical(1))]
	expect_identical(changed, character(0), info = info)
}

test_that("redraws leave a completed sequential design's state unchanged", {
	for (cls in redraw_classes) for (seed in list(NULL, 11L)) {
		info = paste(cls, "seed =", format(seed))
		set.seed(1)
		des = redraw_enroll(redraw_make(cls, seed), seq_len(redraw_n), redraw_data$y)
		w0 = des$get_w()
		inf0 = InferenceAllSimpleMeanDiffPooledVar$new(des, verbose = FALSE)
		est0 = inf0$compute_estimate()
		se0 = inf0$compute_asymp_confidence_interval()
		# Snapshot after the first inference: it fills the design's lazy model-matrix
		# cache (X, Ximp), which is not something a redraw should be blamed for.
		before = redraw_state(des)

		w_mat = des$draw_ws_according_to_design(3L)
		w_mat2 = des$draw_ws_according_to_design(2L)
		expect_equal(dim(w_mat), c(redraw_n, 3L), info = info)
		expect_true(all(w_mat %in% c(0, 1)) && all(w_mat2 %in% c(0, 1)), info = info)

		expect_identical(des$get_w(), w0, info = info)
		expect_same_state(before, redraw_state(des), info)
		inf1 = InferenceAllSimpleMeanDiffPooledVar$new(des, verbose = FALSE)
		expect_identical(inf1$compute_estimate(), est0, info = info)
		expect_identical(inf1$compute_asymp_confidence_interval(), se0, info = info)
	}
})

test_that("a redraw mid-trial does not change the rest of a seeded sequential trial", {
	t_mid = 20L
	# Pocock-Simon included since v1.0.6-TODO-183 (its redraw used to read all n
	# preallocated rows and error on the unfilled ones).
	for (cls in redraw_classes) {
		set.seed(1)
		des = redraw_enroll(redraw_make(cls, 11L), seq_len(t_mid), redraw_data$y)
		set.seed(1)
		twin = redraw_enroll(redraw_make(cls, 11L), seq_len(t_mid), redraw_data$y)
		before = redraw_state(des)
		des$draw_ws_according_to_design(2L)
		expect_same_state(before, redraw_state(des), cls)
		redraw_enroll(des, (t_mid + 1L) : redraw_n, redraw_data$y)
		redraw_enroll(twin, (t_mid + 1L) : redraw_n, redraw_data$y)
		expect_identical(des$get_w(), twin$get_w(), info = cls)
	}
})

test_that("InferenceIncidCMH's SE path leaves the sequential design and later inference unchanged", {
	cmh_checked = character(0)
	for (cls in redraw_classes) {
		set.seed(1)
		des = redraw_enroll(redraw_make(cls, response_type = "incidence"), seq_len(redraw_n), redraw_data$y_bin)
		# CMH refuses the sequential blocking/matching designs (unequal block sizes).
		cmh_ok = tryCatch({ InferenceIncidCMH$new(des, verbose = FALSE); TRUE },
			error = function(e) if (grepl("equal block sizes", conditionMessage(e), fixed = TRUE)) FALSE else stop(e))
		if (!cmh_ok) next
		cmh_checked = c(cmh_checked, cls)
		w0 = des$get_w()
		est0 = InferenceIncidCMH$new(des, se_est_num_vectors = 50L, verbose = FALSE)$compute_estimate()
		before = redraw_state(des)

		cmh = InferenceIncidCMH$new(des, se_est_num_vectors = 50L, verbose = FALSE)
		# The realized allocation need not be exactly balanced; the SE path then warns.
		suppressWarnings(cmh$compute_asymp_two_sided_pval())

		expect_identical(des$get_w(), w0, info = cls)
		expect_same_state(before, redraw_state(des), cls)
		expect_identical(InferenceIncidCMH$new(des, se_est_num_vectors = 50L, verbose = FALSE)$compute_estimate(), est0, info = cls)
	}
	expect_true("DesignSeqOneByOneUrn" %in% cmh_checked)
})

test_that("every sequential design redraws one row per enrolled subject, mid-trial and complete", {
	t_mid = 20L
	for (cls in redraw_classes) for (seed in list(NULL, 11L)) {
		info = paste(cls, "seed =", format(seed))
		set.seed(1)
		des = redraw_enroll(redraw_make(cls, seed), seq_len(t_mid), redraw_data$y)
		w_mid = des$draw_ws_according_to_design(3L)
		expect_equal(dim(w_mid), c(t_mid, 3L), info = info)
		expect_true(all(w_mid %in% c(0, 1)), info = info)
		redraw_enroll(des, (t_mid + 1L) : redraw_n, redraw_data$y)
		expect_equal(dim(des$draw_ws_according_to_design(2L)), c(redraw_n, 2L), info = info)
	}
})

test_that("the generic replay shows assign_wt() the subject being replayed and restores t", {
	CustomSeqParity = R6::R6Class("CustomSeqParity",
		inherit = get("DesignCustomSequential", envir = asNamespace("EDI")),
		public = list(
			# Treat even-numbered subjects and subjects with positive x1: reads both t
			# and subject t's covariate row.
			assignment_rule = function() as.numeric(private$t %% 2 == 0 || private$Xraw$x1[private$t] > 0)
		)
	)
	t_mid = 12L
	des = CustomSeqParity$new(n = redraw_n, response_type = "continuous", verbose = FALSE)
	redraw_enroll(des, seq_len(t_mid), redraw_data$y)
	expected = as.numeric(seq_len(t_mid) %% 2 == 0 | redraw_data$X$x1[seq_len(t_mid)] > 0)
	expect_identical(des$get_w()[seq_len(t_mid)], expected)
	before = redraw_state(des)
	w_mat = suppressWarnings(des$draw_ws_according_to_design(2L))
	expect_equal(unname(w_mat), cbind(expected, expected, deparse.level = 0))
	expect_same_state(before, redraw_state(des), "custom sequential")
	expect_identical(des$get_t(), t_mid)
})
