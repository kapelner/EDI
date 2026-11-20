# v1.0.6-TODO-177: a sequential design with a non-NULL seed derives subject t's
# assignment draw from (seed, t) and runs it with the session's RNG state saved and
# restored. So the allocation depends only on the seed and the subjects' data: RNG
# use between assignments does not change it, a trial saved mid-way continues
# exactly after readRDS(), and the caller's own random stream is untouched.
# seed = NULL keeps drawing from the session's stream.

seq_rng_classes = c("DesignSeqOneByOneBernoulli", "DesignSeqOneByOneEfron", "DesignSeqOneByOneAtkinson",
	"DesignSeqOneByOnePocockSimon", "DesignSeqOneByOneUrn", "DesignSeqOneByOneiBCRD",
	"DesignSeqOneByOneSPBR", "DesignSeqOneByOneRandomBlockSize", "DesignSeqOneByOneKK14",
	"DesignSeqOneByOneKK21", "DesignSeqOneByOneKK21stepwise")

seq_rng_n = 30L
seq_rng_data = local({
	old = if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) get(".Random.seed", envir = .GlobalEnv) else NULL
	set.seed(99)
	X = data.frame(x1 = rnorm(seq_rng_n), x2 = rnorm(seq_rng_n), s = factor(sample(c("a", "b"), seq_rng_n, TRUE)))
	y = X$x1 + rnorm(seq_rng_n)
	if (is.null(old)) rm(".Random.seed", envir = .GlobalEnv) else assign(".Random.seed", old, envir = .GlobalEnv)
	list(X = X, y = y)
})

seq_rng_make = function(cls, seed = 123L) {
	args = list(n = seq_rng_n, response_type = "continuous", seed = seed, verbose = FALSE)
	if (cls %in% c("DesignSeqOneByOnePocockSimon", "DesignSeqOneByOneSPBR", "DesignSeqOneByOneRandomBlockSize")) {
		args$strata_cols = "s"
	}
	do.call(get(cls, envir = asNamespace("EDI"))$new, args)
}

# Enroll every subject (recording each response right away, so the KK21 designs
# reach their outcome-weighted phase). `between` runs before each assignment;
# `save_at` round-trips the design through saveRDS()/readRDS() after that subject.
seq_rng_run = function(cls, seed = 123L, between = function(t) NULL, save_at = NULL) {
	des = seq_rng_make(cls, seed)
	for (t in seq_len(seq_rng_n)) {
		between(t)
		des$add_one_subject_to_experiment_and_assign(seq_rng_data$X[t, , drop = FALSE])
		des$add_one_subject_response(t, seq_rng_data$y[t])
		if (!is.null(save_at) && t == save_at) {
			f = tempfile(fileext = ".rds")
			saveRDS(des, f)
			rm(des)
			des = readRDS(f)
			unlink(f)
		}
	}
	des
}

test_that("seeded sequential allocations ignore RNG use between assignments", {
	for (cls in seq_rng_classes) {
		set.seed(1)
		w_plain = seq_rng_run(cls)$get_w()
		set.seed(2)
		w_noisy = seq_rng_run(cls, between = function(t) runif(t %% 4 + 1))$get_w()
		expect_identical(w_noisy, w_plain, info = cls)
		expect_true(all(w_plain %in% c(0, 1)), info = cls)
	}
})

test_that("a seeded sequential trial saved mid-way continues exactly after readRDS()", {
	for (cls in seq_rng_classes) {
		w_uninterrupted = seq_rng_run(cls)$get_w()
		w_resumed = seq_rng_run(cls, save_at = 13L, between = function(t) if (t == 14L) { set.seed(4242); runif(7) })$get_w()
		expect_identical(w_resumed, w_uninterrupted, info = cls)
	}
})

test_that("seeded construction and assignment leave the caller's random stream untouched", {
	for (cls in seq_rng_classes) {
		set.seed(5)
		u_without = runif(4)
		set.seed(5)
		u_with = c(runif(2), { seq_rng_run(cls); runif(2) })
		expect_identical(u_with, u_without, info = cls)
	}
	# With no .Random.seed in the session, the seeded draw restores its absence.
	# (Checked on the wrapper itself: Rcpp's RNG scope in the covariate kernels that
	# add_one_subject() calls creates .Random.seed without drawing from it.)
	old = if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) get(".Random.seed", envir = .GlobalEnv) else NULL
	on.exit(if (!is.null(old)) assign(".Random.seed", old, envir = .GlobalEnv), add = TRUE)
	des = seq_rng_make("DesignSeqOneByOneEfron")
	if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) rm(".Random.seed", envir = .GlobalEnv)
	u = des$.__enclos_env__$private$with_derived_seed(1L, runif(1))
	expect_false(exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE))
	expect_identical(des$.__enclos_env__$private$with_derived_seed(1L, runif(1)), u)
})

test_that("different seeds give different seeded sequential allocations", {
	expect_false(identical(seq_rng_run("DesignSeqOneByOneBernoulli", seed = 1L)$get_w(),
		seq_rng_run("DesignSeqOneByOneBernoulli", seed = 2L)$get_w()))
})

test_that("seeded sequential redraws repeat and leave the caller's stream untouched", {
	for (cls in c("DesignSeqOneByOneEfron", "DesignSeqOneByOneKK14", "DesignSeqOneByOneKK21stepwise")) {
		des = seq_rng_run(cls)
		set.seed(8)
		r1 = des$draw_ws_according_to_design(3L)
		u1 = runif(1)
		set.seed(8)
		runif(9)
		r2 = des$draw_ws_according_to_design(3L)
		set.seed(8)
		expect_identical(u1, runif(1), info = cls)
		expect_identical(r2, r1, info = cls)
		expect_equal(dim(r1), c(seq_rng_n, 3L), info = cls)
	}
})

test_that("seed = NULL sequential designs keep drawing from the session's stream", {
	for (cls in c("DesignSeqOneByOneBernoulli", "DesignSeqOneByOneEfron", "DesignSeqOneByOneKK14")) {
		set.seed(11)
		w_a = seq_rng_run(cls, seed = NULL)$get_w()
		set.seed(11)
		w_b = seq_rng_run(cls, seed = NULL)$get_w()
		expect_identical(w_b, w_a, info = cls)
		# The session stream advances: an unseeded run moves it.
		set.seed(11)
		u_untouched = runif(1)
		set.seed(11)
		seq_rng_run(cls, seed = NULL)
		expect_false(identical(runif(1), u_untouched), info = cls)
	}
})
