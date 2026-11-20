# Dismissed audit decisions

The scheduled audits (`.github/workflows/audit-*.yml`) list each open decision under "Decisions for you"
with an id such as `rd-d` plus 8 hex digits, and each open mechanical finding under "Mechanical findings"
with an id such as `rd-m` plus 8 hex digits (since 2026-11-19). They keep listing it, run after run, until a
run no longer finds it, an open release TODO cites the id, or the id is listed here. Add one line per
dismissed item, with the reason, so the next reader knows why it was let go:

- `<audit>-d<hex>` or `<audit>-m<hex>`: reason (date)


- `rd-d8e94a804`: the CMH roxygen already says `se_est_num_vectors` defaults to `5000L`, matching `initialize()`
  (`R/EDI/R/inference_incidence_cmh.R`); only the generated Rd was stale, and it is regenerated now (2026-11-18)
- `rd-d6816296a`: the adjacent-category `with_var` text for `ssq_b_1` already matches the code, which reads the
  first beta at free index `n_alpha` (`R/EDI/src/fast_adjacent_category_logit.cpp:525`) (2026-11-18)
- `rd-d537f2cc5`: the continuation-ratio `warm_start_beta` really is the full `c(alpha, beta)` vector; the C++
  requires length `n_alpha + p` (`R/EDI/src/fast_continuation_ratio_regression.cpp:172-173`) (2026-11-18)
- `code-duplication-df63f231e`: the divergence it flags (`InferenceCountZeroInflatedPoisson` / `...NegBin` not
  accepting `smart_cold_start_default`, unlike the hurdle sibling) is fixed by v1.0.6-TODO-153 (2026-11-19)
- `readme-drift-ma357a968`: the `cluster-warning` chunk in `vignettes/articles/cluster-and-factorial-experiments.Rmd`
  warns on purpose and is marked `strict_expect_warning = TRUE`, which `scripts/render_articles_strict.R` honours;
  `readme_drift_run.R` does not read that flag, so this is a false positive (owner, 2026-11-20)
