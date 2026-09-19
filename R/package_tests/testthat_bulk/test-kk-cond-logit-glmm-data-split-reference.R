library(testthat)
library(EDI)

# InferenceAbstractKKCondLogitGLMM's private prepare_clogit_plus_glmm_data():
# splits a KK design into discordant pairs (conditional-logit part) and
# concordant pairs (+ reservoir when combine_reservoir_into_glmm() is TRUE) for
# the random-intercept GLMM part. It had no direct test reference; the golden
# tests only compare end-to-end outputs. The reference split is rebuilt from
# scratch from the design's match vector, treatment and responses.

kk_split_fixture <- function(y_fun, seed = 31L, n = 70L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "incidence", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n), x2 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	y <- y_fun(w, X)
	des$add_all_subject_responses(y)
	list(des = des, X = X, w = w, y = y, n = n)
}

ordinary_y <- function(w, X) rbinom(length(w), 1, plogis(-0.3 + 0.9 * w + 0.4 * X$x1))

make_split_priv <- function(cls, f) {
	get(cls)$new(f$des, verbose = FALSE)$.__enclos_env__$private
}

ref_split <- function(priv, f, combine_reservoir) {
	m <- priv$m
	m[is.na(m)] <- 0L
	pair_ids <- sort(unique(m[m > 0]))
	yT <- vapply(pair_ids, function(p) f$y[m == p & f$w == 1], numeric(1))
	yC <- vapply(pair_ids, function(p) f$y[m == p & f$w == 0], numeric(1))
	xdiff <- t(vapply(pair_ids, function(p) {
		as.numeric(unlist(f$X[m == p & f$w == 1, ])) - as.numeric(unlist(f$X[m == p & f$w == 0, ]))
	}, numeric(ncol(f$X))))
	disc <- which(abs(yT - yC) == 1)
	conc_pairs <- pair_ids[setdiff(seq_along(pair_ids), disc)]
	rows_conc_pair <- which(m %in% conc_pairs)
	rows_res <- which(m == 0L)
	rows <- if (combine_reservoir) c(rows_conc_pair, rows_res) else rows_conc_pair
	group <- m[rows]
	group[m[rows] == 0L] <- max(m) + seq_len(sum(m[rows] == 0L))
	list(
		y_disc = (yT[disc] - yC[disc] + 1) / 2,
		x_disc = xdiff[disc, , drop = FALSE],
		rows = rows,
		group = group
	)
}

test_that("both leaves split discordant/concordant units exactly as an independent reference", {
	f <- kk_split_fixture(ordinary_y)
	for (cls in c("InferenceIncidKKCondLogitGLMMIVWC", "InferenceIncidKKCondLogitGLMMOneLik")) {
		priv <- make_split_priv(cls, f)
		combine <- priv$combine_reservoir_into_glmm()
		d <- priv$prepare_clogit_plus_glmm_data()
		ref <- ref_split(priv, f, combine)

		expect_equal(combine, identical(cls, "InferenceIncidKKCondLogitGLMMOneLik"), info = cls)
		expect_equal(d$y_disc, ref$y_disc, info = cls)
		expect_equal(unname(d$X_disc[, 1]), rep(1, length(ref$y_disc)), info = cls)
		expect_equal(unname(d$X_disc[, -1, drop = FALSE]), unname(ref$x_disc), tolerance = 1e-10, info = cls)
		expect_equal(colnames(d$X_disc)[1], "treatment", info = cls)

		expect_equal(d$y_conc, as.numeric(f$y[ref$rows]), info = cls)
		expect_equal(unname(d$X_conc[, "treatment"]), as.numeric(f$w[ref$rows]), info = cls)
		expect_equal(unname(d$X_conc[, "x1"]), f$X$x1[ref$rows], tolerance = 1e-12, info = cls)
		expect_equal(unname(d$X_conc[, "(Intercept)"]), rep(1, length(ref$rows)), info = cls)
		expect_equal(d$group_conc, as.integer(ref$group), info = cls)
		expect_true(d$has_discordant && d$has_concordant, info = cls)
	}
})

test_that("reservoir rows join the GLMM part only for the OneLik leaf, each as its own singleton group", {
	f <- kk_split_fixture(ordinary_y)
	ivwc <- make_split_priv("InferenceIncidKKCondLogitGLMMIVWC", f)$prepare_clogit_plus_glmm_data()
	onel <- make_split_priv("InferenceIncidKKCondLogitGLMMOneLik", f)$prepare_clogit_plus_glmm_data()
	n_res <- sum(is.na(make_split_priv("InferenceIncidKKCondLogitGLMMIVWC", f)$m) | make_split_priv("InferenceIncidKKCondLogitGLMMIVWC", f)$m == 0L)
	expect_gt(n_res, 0L)
	expect_equal(nrow(onel$X_conc) - nrow(ivwc$X_conc), n_res)
	res_groups <- tail(onel$group_conc, n_res)
	expect_equal(length(unique(res_groups)), n_res)
	expect_false(any(res_groups %in% ivwc$group_conc))
})

test_that("no discordant pairs gives an empty conditional-logit block", {
	f <- kk_split_fixture(function(w, X) rep(1L, length(w)))
	d <- make_split_priv("InferenceIncidKKCondLogitGLMMIVWC", f)$prepare_clogit_plus_glmm_data()
	expect_false(d$has_discordant)
	expect_equal(dim(d$X_disc), c(0L, 3L))
	expect_length(d$y_disc, 0L)
	expect_true(d$has_concordant)
})

test_that("all-discordant pairs give an empty GLMM block when the reservoir is not combined", {
	f <- kk_split_fixture(function(w, X) as.integer(w == 1))
	d <- make_split_priv("InferenceIncidKKCondLogitGLMMIVWC", f)$prepare_clogit_plus_glmm_data()
	expect_true(d$has_discordant)
	expect_false(d$has_concordant)
	expect_equal(dim(d$X_conc), c(0L, 4L))
	expect_length(d$y_conc, 0L)
	expect_true(all(d$y_disc == 1))
	# With the reservoir combined the GLMM block still receives the reservoir rows.
	d2 <- make_split_priv("InferenceIncidKKCondLogitGLMMOneLik", f)$prepare_clogit_plus_glmm_data()
	expect_true(d2$has_concordant)
	expect_gt(nrow(d2$X_conc), 0L)
})

test_that("log_sum_exp/log1pexp match naive references", {
	f <- kk_split_fixture(ordinary_y)
	priv <- make_split_priv("InferenceIncidKKCondLogitGLMMIVWC", f)
	x <- c(-3, 0.5, 2, 10)
	expect_equal(priv$log_sum_exp(x), log(sum(exp(x))), tolerance = 1e-12)
	expect_equal(priv$log_sum_exp(c(1000, 1000)), 1000 + log(2), tolerance = 1e-12)
	expect_equal(priv$log_sum_exp(c(-Inf, -Inf)), -Inf)
	z <- c(-40, -1, 0, 1, 40, 800)
	expect_equal(priv$log1pexp(z[1:5]), log1p(exp(z[1:5])), tolerance = 1e-12)
	expect_equal(priv$log1pexp(800), 800)
})
