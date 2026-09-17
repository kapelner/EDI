#include <RcppEigen.h>
#include <cmath>
#include "bisection_ci_search.h"

// [[Rcpp::depends(RcppEigen)]]

using namespace Rcpp;

//' Bisection loop for computing confidence interval bounds by inverting randomization tests
//'
//' This function implements the bisection algorithm to find CI bounds by inverting
//' the randomization test. It repeatedly calls the p-value computation function
//' until convergence.
//'
//' @param pval_fn R function that computes two-sided p-value given delta
//' @param r Number of randomization iterations
//' @param l Initial lower bound
//' @param u Initial upper bound
//' @param pval_th P-value threshold (typically alpha/2 for two-sided CI)
//' @param tol Tolerance for convergence (in p-value space)
//' @param transform_responses String: "none", "log", or "logit"
//' @param lower Logical: TRUE for lower CI bound, FALSE for upper
//'
//' @return The CI bound value
//' @keywords internal
//'
// [[Rcpp::export]]
double bisection_ci_loop_cpp(
	Function pval_fn,
	int r,
	double l,
	double u,
	double pval_th,
	double tol,
	std::string transform_responses,
	bool lower
) {
	auto pvalue = [&](double delta) {
		return as<double>(pval_fn(r, delta, transform_responses));
	};
	return edi::bisection_ci_search(pvalue, l, u, pval_th, tol, lower);
}
