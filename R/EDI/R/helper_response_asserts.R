# Response-type assertion helpers shared across inference classes.

assertResponseType = function(response_type, needed_response_type){
	if (!(response_type %in% needed_response_type)){
		stop("This type of inference is only available for ", paste(needed_response_type, collapse = "/"), " responses.")
	}
}

assertNoCensoring = function(any_censoring){
	if (any_censoring){
		stop("This type of inference is only available for uncensored responses.")
	}
}

