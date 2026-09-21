library(testthat)
library(EDI)

# DesignSeqOneByOneKK21$assign_wt() after burn-in, with compute_weights stubbed so only x1 carries weight:
# the distance to a reservoir subject is then monotone in |x1 difference|. Independent invariants checked at every
# post-burn-in step: a match partners with the reservoir member nearest in x1, is assigned the opposite arm, and
# gets max(previous ids) + 1; a non-match joins the reservoir (m = 0). Also: the stored weights are the normalised stub.

run <- function(seed, n = 90L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK21$new(n = n, response_type = "continuous", verbose = FALSE)
	p <- des$.__enclos_env__$private
	unlockBinding("compute_weights", p)
	p$compute_weights <- function(all_subject_data) {
		v <- numeric(ncol(all_subject_data$X_all_with_y_scaled)); v[1L] <- 3; v
	}
	x1 <- numeric(n); events <- list()
	for (i in seq_len(n)) {
		x1[i] <- rnorm(1)
		m_before <- p$m[seq_len(i - 1L)]
		w <- des$add_one_subject_to_experiment_and_assign(data.frame(x1 = x1[i], x2 = rnorm(1)))
		des$add_one_subject_response(i, x1[i] + w + rnorm(1))
		it <- des$get_iteration_weights()
		if (length(it) >= i && !is.null(it[[i]])) {
			events[[length(events) + 1L]] <- list(i = i, m_before = m_before, m_i = p$m[i], w_i = p$w[i], w_all = p$w,
				max_before = max(c(m_before, 0), na.rm = TRUE))
		}
	}
	list(des = des, p = p, x1 = x1, events = events)
}

test_that("matches pick the x1-nearest reservoir subject, take the opposite arm and a fresh id; others join the reservoir", {
	n_match <- 0L; n_res <- 0L
	for (seed in 1:4) {
		r <- run(seed)
		expect_gt(length(r$events), 20L)
		for (e in r$events) {
			res <- which(e$m_before == 0)
			if (e$m_i > 0) {
				n_match <- n_match + 1L
				expect_equal(e$m_i, e$max_before + 1)
				partner <- setdiff(which(r$p$m == e$m_i), e$i)
				expect_length(partner, 1L)
				expect_true(partner %in% res)
				expect_equal(partner, res[which.min(abs(r$x1[res] - r$x1[e$i]))])
				expect_equal(e$w_i, 1 - e$w_all[partner])
			} else {
				n_res <- n_res + 1L
				expect_equal(e$m_i, 0)
			}
		}
	}
	expect_gt(n_match, 5L); expect_gt(n_res, 5L)
})

test_that("stored weights are the normalised stub and only x1 has weight", {
	r <- run(5L)
	v <- r$des$get_covariate_weights()
	expect_equal(unname(v[1]), 1)
	expect_equal(sum(v), 1)
	expect_true(all(v[-1] == 0))
})
