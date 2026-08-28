# add_all_subject_responses_seq() lives in the package namespace so the local
# machine tuner can reuse it. Installed-package tests do not attach unexported
# namespace functions, so keep this test-local forwarding wrapper for callers
# that historically used the helper by its bare name.
add_all_subject_responses_seq = function(...) {
	EDI:::add_all_subject_responses_seq(...)
}
