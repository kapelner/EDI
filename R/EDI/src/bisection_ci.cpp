#include <RcppEigen.h>
#include <cmath>
#include "bisection_ci_search.h"

// [[Rcpp::depends(RcppEigen)]]

using namespace Rcpp;

//' Sequential computation of both CI bounds (called from R-level parallelism)
//'
//' This function is kept for backwards compatibility but the outer parallelism
//' (running lower/upper bounds simultaneously) is now handled at the R level via
//' parallel::mclapply, which is safe. Calling R functions from OpenMP threads is
//' undefined behaviour in R and caused process crashes.
//'
//' @param pval_fn R function: pval_fn(nsim, delta, transform_responses, num_cores)
//' @param r Number of randomization iterations
//' @param l_lower Initial lower bound for lower CI bound search
//' @param u_lower Initial upper bound for lower CI bound search (typically the estimate)
//' @param l_upper Initial lower bound for upper CI bound search (typically the estimate)
//' @param u_upper Initial upper bound for upper CI bound search
//' @param pval_th P-value threshold (typically alpha/2 for two-sided CI)
//' @param tol Tolerance for convergence (in p-value space)
//' @param transform_responses String: "none", "log", or "logit"
//' @param num_cores Passed through to pval_fn for inner parallelism
//'
//' @return Numeric vector of length 2: [lower_bound, upper_bound]
//' @keywords internal
//'
// [[Rcpp::export]]
NumericVector bisection_ci_parallel_cpp(
	Function pval_fn,
	int r,
	double l_lower,
	double u_lower,
	double l_upper,
	double u_upper,
	double pval_th,
	double tol,
	std::string transform_responses,
	int num_cores = 1
) {
	auto pvalue = [&](double delta) {
		return as<double>(pval_fn(r, delta, transform_responses, num_cores));
	};
	NumericVector bounds(2);
	bounds[0] = edi::bisection_ci_search(pvalue, l_lower, u_lower, pval_th, tol, true);
	bounds[1] = edi::bisection_ci_search(pvalue, l_upper, u_upper, pval_th, tol, false);
	return bounds;
}


//' Single-threaded helper for computing one CI bound
//'
//' @keywords internal
// [[Rcpp::export]]
double bisection_ci_single_bound_cpp(
	Function pval_fn,
	int r,
	double l,
	double u,
	double pval_th,
	double tol,
	std::string transform_responses,
	bool lower,
	int num_cores = 1
) {
	auto pvalue = [&](double delta) {
		return as<double>(pval_fn(r, delta, transform_responses, num_cores));
	};
	return edi::bisection_ci_search(pvalue, l, u, pval_th, tol, lower);
}
