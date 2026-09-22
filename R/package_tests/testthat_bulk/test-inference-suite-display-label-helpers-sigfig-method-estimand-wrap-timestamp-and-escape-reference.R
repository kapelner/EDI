library(testthat)
library(EDI)

# Pure display helpers of the inference-suite render layer, checked against hand-derived expectations from their documented rules:
# run_all_inference_fmt_completed_secs (s / min s), run_all_inference_sigfig (n significant figures, fixed / scientific / tiny -> e-notation, NA, 0),
# method_short_label (sentinel abbreviations, NA passthrough, unknown names unchanged), estimand_short_label (RR / HL / quantile special cases, word
# abbreviations, "diff" -> Delta), run_all_inference_wrap_cell_2lines (forced splits, paren split, balanced halves with floor, truncation, long single token),
# run_all_inference_pretty_timestamp (formatted or returned unchanged) and htmltools_escape_or_identity (&, <, > escaping order).

ns <- asNamespace("EDI"); G <- function(nm) get(nm, envir = ns)
D <- "Δ"

test_that("fmt_completed_secs: whole seconds below a minute, 'Nmin Ss' from a minute, rounds, clamps negatives to 0s", {
	f <- G("run_all_inference_fmt_completed_secs")
	expect_identical(f(0), "0s"); expect_identical(f(59.4), "59s"); expect_identical(f(60), "1min 0s"); expect_identical(f(125), "2min 5s")
	expect_identical(f(3599.6), "60min 0s"); expect_identical(f(-5), "0s")
})

test_that("sigfig: n significant figures in fixed notation, e-notation when more than 6 decimals would be needed or when requested, NA and zero specials", {
	f <- G("run_all_inference_sigfig")
	expect_identical(f(c(123.456, 0.012345, 5, -0.5), n = 2L), c("120", "0.012", "5.0", "-0.50"))
	expect_identical(f(c(123.456, 0.012345), n = 3L), c("123", "0.0123"))
	expect_identical(f(c(NA, 0)), c("NA", "0.0"))
	expect_identical(f(c(NA, 0), scientific = TRUE), c("NA", "0e+00"))
	expect_identical(f(1234.5, n = 2L, scientific = TRUE), "1.2e+03")
	expect_identical(f(1.5e-9, n = 2L), "1.5e-09")                                 # would need > 6 decimals -> scientific
	expect_length(f(numeric(0)), 0L)
	expect_identical(f(0.5, n = 1L), "0.5")
})

test_that("method_short_label maps the sentinel names, keeps NA and unknown names", {
	f <- G("method_short_label")
	expect_identical(f(c("rand_bootstrap", "lik_ratio_bartlett_exact", "lik_ratio_bartlett_approx", "bayes_boot", "bootstrap", "param_boot", "param_boot_direct")),
		c("rand boot", "LR Bartlett", "LR ≈Bartlett", "bayes boot", "boot", "param boot", "param boot"))
	expect_identical(f(c("asymp", NA)), c("asymp", NA_character_))
})

test_that("estimand_short_label: special whole-string cases, word abbreviations and 'diff' -> Delta", {
	f <- G("estimand_short_label")
	expect_identical(f("RR"), "risk ratio"); expect_identical(f("hodges_lehmann_shift"), "HL shift")
	expect_identical(f("quantile_regression_effect"), "median effect")
	expect_identical(f("quantile_regression_effect", tau = 0.5), "median effect")
	expect_identical(f("quantile_regression_effect", tau = 0.9), "quantile (90%ile)")
	expect_identical(f("mean_difference"), paste("mean", D))
	expect_identical(f("median_difference"), paste("median", D))
	expect_identical(f("log_odds_ratio"), "logodds")
	expect_identical(f("log_odds_ratio_partial_proportional"), "logodds partial prop")
	expect_identical(f("log_odds_ratio_continuation_ratio"), "logodds cont ratio")
	expect_identical(f("restricted_mean_survival_time_difference"), paste("restr mean survival time", D))
	expect_identical(f("stochastic_superiority_conditional"), "stoch super cond")
	expect_identical(f("probit_effect"), "probit")
	expect_identical(f("adjacent_category_log_odds_ratio"), "adj cat logodds")
	expect_identical(f("logit_effect_proportion_mean_conditional"), "logit effect")
	expect_identical(f(NA_character_), NA_character_)
	expect_identical(f(c("RR", "quantile_regression_effect"), tau = c(NA, 0.25)), c("risk ratio", "quantile (25%ile)"))
})

test_that("wrap_cell_2lines: forced splits, short cells, paren split, balanced halves (floor), truncation and long single tokens", {
	f <- G("run_all_inference_wrap_cell_2lines")
	expect_identical(f("LR Bartlett", 20L), c("LR", "Bartlett"))
	expect_identical(f("LR ≈Bartlett", 20L), c("LR", "≈Bartlett"))
	expect_identical(f("Kaplan-Meier", 20L), c("Kaplan-", "Meier"))
	expect_identical(f(paste("Kaplan-Meier", D), 20L), c("Kaplan-", paste("Meier", D)))
	expect_identical(f("cov mod", 20L), c("cov", "mod"))
	expect_identical(f("KK CLMM Cauchit", 20L), c("KK CLMM", "Cauchit"))
	expect_identical(f("Cauchit Regr", 20L), c("Cauchit", "Regr"))
	expect_identical(f(NA_character_, 20L), c("NA", ""))
	expect_identical(f("short", 20L), c("short", ""))
	expect_identical(f("bayes boot (%ile)", 12L), c("bayes boot", "(%ile)"))
	expect_identical(f(paste("Mean", D, "Pooled Var"), 10L), c(paste("Mean", D), "Pooled Var"))
	expect_identical(f(paste("Mean", D, "Pooled Var"), 8L), c(paste("Mean", D), "Pooled V"))         # second line truncated to the width
	expect_identical(f(paste("Miettinen Risk", D), 6L), c("Miettinen", paste("Risk", D)) |> (\(v) c(v[1], substr(v[2], 1L, 6L)))())
	expect_identical(f("a b c d e", 3L), c("a b", "c d"))                               # 5 words: floor(5 / 2) = 2 words first, second line truncated to width 3
	# REGRESSION (fixed 2026-09-22): a single token longer than the width is documented as "hard-wrapped at width"; it used to call strwrap(), which never
	# breaks inside a word, so line 1 kept the whole token (overflowing the column) and line 2 stayed empty. Now breaks at the character boundary, with a
	# trailing hyphen marking the break when there's room for one.
	expect_identical(f("abcdefghijklmnop", 5L), c("abcd-", "efghi"))
	expect_identical(nchar(f("abcdefghijklmnop", 5L)), c(5L, 5L))
	expect_identical(f("abcdefghijklmnop", 1L), c("a", "b"))                          # width 1: no room for a hyphen marker
})

test_that("pretty_timestamp formats a %Y%m%d_%H%M%S stamp and returns anything unparseable unchanged; htmltools_escape_or_identity escapes & < >", {
	p <- G("run_all_inference_pretty_timestamp")
	out <- p("20260921_143005")
	expect_match(out, "^September 21, 2026 14:30:05")
	expect_identical(p("not-a-timestamp"), "not-a-timestamp")
	e <- G("htmltools_escape_or_identity")
	expect_identical(e("a & b < c > d"), "a &amp; b &lt; c &gt; d")
	expect_identical(e("&lt;"), "&amp;lt;")                                            # ampersands are escaped first, exactly once per pass
	expect_identical(e("plain"), "plain"); expect_identical(e(c("<x>", "y")), c("&lt;x&gt;", "y"))
})
