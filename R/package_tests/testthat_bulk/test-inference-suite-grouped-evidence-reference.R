library(testthat)
library(EDI)

suite_grouped_evidence_fixture <- function() {
  data.frame(inference_class = c("a", "b", "c", "d", "e", "f", "g"),
             status = c("ok", "ok", "ok", "ok", "error", "ok", "ok"),
             estimand = c("mean", "mean", "odds", NA, "odds", "mean", "odds"),
             pval = c(0.03, 0.2, 0.4, 0.01, 0.005, NA, Inf))
}

test_that("grouped combined evidence gives equal total weight to each estimand", {
  tab <- suite_grouped_evidence_fixture()
  weights <- EDI:::run_all_inference_compute_combined_evidence_weights(tab, "estimand_grouped")
  expect_equal(weights[1:3], c(0.25, 0.25, 0.5))
  expect_true(all(is.na(weights[4:7])))
  combined <- EDI:::run_all_inference_combine_pvalues(tab$pval, weights)
  stat <- sum(c(0.25, 0.25, 0.5) * qcauchy(1 - tab$pval[1:3]))
  expect_equal(combined$stat, stat, tolerance = 1e-12)
  expect_equal(combined$pval, pcauchy(stat, lower.tail = FALSE), tolerance = 1e-12)
  expect_equal(combined$n_used, 3)
  # Duplicating every method in one group leaves its total evidence unchanged.
  duplicated <- rbind(tab, tab[1:2, ])
  weights2 <- EDI:::run_all_inference_compute_combined_evidence_weights(duplicated, "estimand_grouped")
  combined2 <- EDI:::run_all_inference_combine_pvalues(duplicated$pval, weights2)
  expect_equal(combined2$pval, combined$pval)
  expect_equal(combined2$stat, combined$stat)
  expect_equal(combined2$n_used, 5)
})

test_that("estimand selection and custom weights exclude unavailable evidence", {
  tab <- suite_grouped_evidence_fixture()
  selected <- EDI:::run_all_inference_compute_combined_evidence_weights(tab, "estimand_grouped", estimands = "mean")
  expect_equal(selected[1:2], c(0.5, 0.5))
  expect_true(all(is.na(selected[3:7])))
  equal <- EDI:::run_all_inference_compute_combined_evidence_weights(tab, "equal")
  expect_equal(equal[1:4], rep(0.25, 4))
  custom <- EDI:::run_all_inference_compute_combined_evidence_weights(tab, "custom", custom_weights = c(a = 2, c = 3))
  expect_equal(custom[1:4], c(2, 0, 3, 0))
  expect_true(all(is.na(custom[5:7])))
  all_unknown <- tab
  all_unknown$estimand <- NA_character_
  expect_true(all(is.na(EDI:::run_all_inference_compute_combined_evidence_weights(all_unknown, "estimand_grouped"))))
  expect_true(all(is.na(EDI:::run_all_inference_compute_combined_evidence_weights(tab, "equal", estimands = "absent"))))
  expect_error(EDI:::run_all_inference_compute_combined_evidence_weights(tab, "unknown"), "unknown weighting")
})

test_that("Cauchy evidence clamps endpoint p-values and filters nonfinite pairs", {
  pvals <- c(0, 1, 0.1, NA, NaN, Inf, 0.3)
  weights <- c(1, 3, 2, 10, 10, 10, NA)
  fit <- EDI:::run_all_inference_combine_pvalues(pvals, weights, pval_eps = 0.01)
  stat <- sum(c(1, 3, 2) / 6 * qcauchy(1 - c(0.01, 0.99, 0.1)))
  expect_equal(fit$stat, stat, tolerance = 1e-12)
  expect_equal(fit$pval, pcauchy(stat, lower.tail = FALSE), tolerance = 1e-12)
  expect_equal(fit$n_used, 3)
  expect_equal(EDI:::run_all_inference_combine_pvalues(pvals, 8 * weights, pval_eps = 0.01), fit)
  singleton <- EDI:::run_all_inference_combine_pvalues(c(0.1, 0.2), c(1, NA))
  expect_equal(singleton$n_used, 1)
  expect_true(is.na(singleton$pval))
  expect_true(is.na(singleton$stat))
})
