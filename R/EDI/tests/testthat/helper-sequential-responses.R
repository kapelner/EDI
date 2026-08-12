add_all_subject_responses_seq = function(des, ys, deads = NULL){
	if (is.null(deads)){
		deads = rep(1, length(ys))
	}
	for (i in seq_along(ys)){
		if (isTRUE(deads[i] == 1)) {
			des$add_one_subject_response(i, y = ys[i])
		} else {
			des$add_one_subject_response(i, y_L = ys[i], y_R = Inf)
		}
	}
}
