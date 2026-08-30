#!/usr/bin/env Rscript
#
# Randomization-CI workload used by benchmark_randomization_ci_build_modes.sh:
# a sequential KK14 design on 100 airquality rows with an ordinal response,
# then an ordinal partial-proportional-odds (or ordered-probit) regression's
# randomization CI at num_cores = 3. Timed end-to-end, `reps` times.
#
# Environment (all optional except EDI_LIB):
#   EDI_LIB              library the EDI build under test is installed in
#   EDI_LABEL            label printed in the output (default: portable)
#   EDI_NUM_CORES        cores passed to set_num_cores() (default: 3)
#   EDI_R                randomization vectors per test (default: 201)
#   EDI_REPS             timed repetitions (default: 3)
#   EDI_FORCE_MIRAI      "true" to force the mirai backend
#   EDI_INFERENCE_CLASS  InferenceOrdinalPartialProportionalOddsRegr (default)
#                        or InferenceOrdinalOrderedProbitRegr
#   EDI_NONPARALLEL      comma-separated covariate names given non-parallel
#                        (threshold-varying) slopes in the PPO model

lib_dir = Sys.getenv("EDI_LIB", unset = "")
if (identical(lib_dir, "")) {
    stop("EDI_LIB must point to the installed package library.")
}
label = Sys.getenv("EDI_LABEL", unset = "portable")
num_cores = as.integer(Sys.getenv("EDI_NUM_CORES", unset = "3"))
r = as.integer(Sys.getenv("EDI_R", unset = "201"))
reps = as.integer(Sys.getenv("EDI_REPS", unset = "3"))
force_mirai = identical(tolower(Sys.getenv("EDI_FORCE_MIRAI", unset = "false")), "true")
inference_class = Sys.getenv("EDI_INFERENCE_CLASS", unset = "InferenceOrdinalPartialProportionalOddsRegr")
nonparallel = strsplit(Sys.getenv("EDI_NONPARALLEL", unset = ""), ",", fixed = TRUE)[[1]]
nonparallel = nonparallel[nonparallel != ""]

.libPaths(c(lib_dir, .libPaths()))
suppressPackageStartupMessages(library(EDI, lib.loc = lib_dir))

beta_T = 0.2
SD_NOISE = 0.1
max_n = 100L

X_design = na.omit(as.data.frame(airquality))
X_design = X_design[seq_len(max_n), c("Ozone", "Solar.R", "Wind", "Temp")]
y_base = cut(
    X_design$Temp,
    breaks = quantile(X_design$Temp, probs = seq(0, 1, length.out = 6), na.rm = TRUE),
    include.lowest = TRUE,
    labels = FALSE
)
y_base[is.na(y_base)] = 1L

stable_seed = function(...) {
    as.integer(sum(utf8ToInt(paste(..., collapse = "|"))) %% 2147483647L)
}

make_des_obj = function(seed_key) {
    set.seed(stable_seed("ordinal_ppo_build_benchmark", seed_key))
    des_obj = DesignSeqOneByOneKK14$new(response_type = "ordinal", n = nrow(X_design))
    for (t in seq_len(nrow(X_design))) {
        w_t = des_obj$add_one_subject_to_experiment_and_assign(X_design[t, , drop = FALSE])
        y_t = pmax(1L, as.integer(y_base[t] + (if (w_t == 1) beta_T else 0) + rnorm(1, 0, SD_NOISE)))
        des_obj$add_one_subject_response(t, y_t)
    }
    des_obj
}

set_num_cores(num_cores, force_mirai = force_mirai)
on.exit(unset_num_cores(), add = TRUE)

timings = numeric(reps)
cat(sprintf(
    "Benchmark: %s | class=%s | num_cores=%d | force_mirai=%s | r=%d | reps=%d\n",
    label, inference_class, num_cores, force_mirai, r, reps
))

for (i in seq_len(reps)) {
    des_obj = make_des_obj(paste(label, i, num_cores, r, sep = "|"))
    inf_obj = switch(
        inference_class,
        InferenceOrdinalPartialProportionalOddsRegr = InferenceOrdinalPartialProportionalOddsRegr$new(
            des_obj,
            nonparallel = nonparallel,
            verbose = FALSE
        ),
        InferenceOrdinalOrderedProbitRegr = InferenceOrdinalOrderedProbitRegr$new(
            des_obj,
            verbose = FALSE
        ),
        stop("Unsupported inference class: ", inference_class)
    )
    gc(FALSE)
    t0 = proc.time()[["elapsed"]]
    ci = inf_obj$compute_confidence_interval_rand(
        alpha = 0.05,
        r = r,
        pval_epsilon = 0.05,
        show_progress = FALSE
    )
    timings[i] = round(proc.time()[["elapsed"]] - t0, 3)
    cat(sprintf(
        "rep %d: %.3fs CI=[%.4f, %.4f]\n",
        i, timings[i], ci[1], ci[2]
    ))
}

cat(sprintf("median: %.3fs\n", median(timings)))
