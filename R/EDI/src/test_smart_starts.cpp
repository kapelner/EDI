#include <RcppEigen.h>
#include "_helper_functions.h"

// [[Rcpp::depends(RcppEigen)]]

using namespace Rcpp;

// [[Rcpp::export]]
NumericVector test_ols_smart_cold_start_beta_cpp(const Eigen::Map<Eigen::MatrixXd>& X, SEXP y) {
	NumericVector y_r_coerced(y); Eigen::Map<const Eigen::VectorXd> y_vec_coerced(y_r_coerced.begin(), y_r_coerced.size());


	

	return wrap(ols_smart_cold_start_beta(X, y_vec_coerced));
}

// [[Rcpp::export]]
NumericVector test_ols_smart_cold_start_beta_on_log1p_cpp(const Eigen::Map<Eigen::MatrixXd>& X, SEXP y) {
	NumericVector y_r_coerced(y); Eigen::Map<const Eigen::VectorXd> y_vec_coerced(y_r_coerced.begin(), y_r_coerced.size());


	

	return wrap(ols_smart_cold_start_beta_on_log1p(X, y_vec_coerced));
}

// [[Rcpp::export]]
NumericVector test_finalize_warm_start_beta_cpp( const Eigen::Map<Eigen::VectorXd>& smart_cold_start,
		const Eigen::Map<Eigen::VectorXd>& legacy_start,
		bool use_smart = true,
		Nullable<IntegerVector> fixed_idx = R_NilValue,
		Nullable<NumericVector> fixed_values = R_NilValue) {

	

	FixedParamSpec fixed_spec = make_fixed_param_spec(legacy_start.size(), fixed_idx, fixed_values);
	return wrap(finalize_warm_start_beta(smart_cold_start, legacy_start, fixed_spec, use_smart));
}

// [[Rcpp::export]]
List test_weibull_aft_start_cpp(const Eigen::Map<Eigen::MatrixXd>& X, SEXP y, SEXP dead) {
	NumericVector dead_r_coerced(dead); Eigen::Map<const Eigen::VectorXd> dead_vec_coerced(dead_r_coerced.begin(), dead_r_coerced.size());
	NumericVector y_r_coerced(y); Eigen::Map<const Eigen::VectorXd> y_vec_coerced(y_r_coerced.begin(), y_r_coerced.size());


	

	
	WeibullStart warm_start_params = weibull_aft_start(X, y_vec_coerced, dead_vec_coerced);
	return List::create(
		_["beta"] = wrap(warm_start_params.beta),
		_["log_sigma"] = warm_start_params.log_sigma,
		_["params"] = wrap(weibull_start_to_params(warm_start_params))
	);
}

// [[Rcpp::export]]
List test_ordinal_start_cpp(const Eigen::Map<Eigen::MatrixXd>& X, SEXP y, std::string link = "logit") {
	NumericVector y_r_coerced(y); Eigen::Map<const Eigen::VectorXd> y_vec_coerced(y_r_coerced.begin(), y_r_coerced.size());


	

	edi_ordinal::Link ordinal_link = edi_ordinal::Link::Logit;
	if (link == "probit") ordinal_link = edi_ordinal::Link::Probit;
	else if (link == "cloglog") ordinal_link = edi_ordinal::Link::Cloglog;
	else if (link == "cauchit") ordinal_link = edi_ordinal::Link::Cauchit;
	OrdinalStart warm_start_params = ordinal_smart_cold_start(X, y_vec_coerced, ordinal_link);
	return List::create(
		_["alpha"] = wrap(warm_start_params.alpha),
		_["beta"] = wrap(warm_start_params.beta),
		_["params"] = wrap(ordinal_start_to_params(warm_start_params))
	);
}
