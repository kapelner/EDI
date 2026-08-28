# add_all_subject_responses_seq() lives in the package namespace so the local
# machine tuner can reuse it. Keep the same forwarding wrapper as the regular
# testthat suite so this runner does not depend on pkgload attaching internals.
add_all_subject_responses_seq = function(...) {
	EDI:::add_all_subject_responses_seq(...)
}
