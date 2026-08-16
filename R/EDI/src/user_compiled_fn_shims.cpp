// Eval shims for user-supplied compiled C++ functions (user_compiled_fns.h):
// the single place XPtrs are dereferenced from R. R code (auto temperature
// calibration, the custom-randomization-statistic loop, tests) calls these;
// hot C++ loops (the annealing kernel) deref the same typedefs directly.

#include <RcppEigen.h>
#include "user_compiled_fns.h"
// [[Rcpp::depends(RcppEigen)]]

// [[Rcpp::export]]
double eval_custom_design_objective_cpp(SEXP xptr, const Eigen::Map<Eigen::MatrixXd> X, const Eigen::Map<Eigen::VectorXd> w) {
	Rcpp::XPtr<edi_design_objective_fn> xp(xptr);
	return (*xp)(X, w);
}

// [[Rcpp::export]]
double eval_custom_rand_stat_xptr_cpp(SEXP xptr, const Eigen::Map<Eigen::VectorXd> y, const Eigen::Map<Eigen::VectorXd> w) {
	Rcpp::XPtr<edi_rand_stat_fn> xp(xptr);
	return (*xp)(y, w);
}

// [[Rcpp::export]]
double eval_custom_rand_stat_dead_xptr_cpp(SEXP xptr, const Eigen::Map<Eigen::VectorXd> y, const Eigen::Map<Eigen::VectorXd> w, const Eigen::Map<Eigen::VectorXd> dead) {
	Rcpp::XPtr<edi_rand_stat_dead_fn> xp(xptr);
	return (*xp)(y, w, dead);
}
