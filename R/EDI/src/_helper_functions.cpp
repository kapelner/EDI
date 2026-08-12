#include "_helper_functions.h"

#ifndef EDI_CORE_ONLY
using namespace Rcpp;


//typedef Eigen::Map<Eigen::MatrixXd> MapMat;
//typedef Eigen::Map<Eigen::VectorXd> MapVec;

// [[Rcpp::export]]
Eigen::MatrixXd eigen_Xt_times_X_cpp( const Eigen::Map<Eigen::MatrixXd>& X) {

	
	return X.transpose() * X;
}

// [[Rcpp::export]]
double eigen_compute_single_entry_on_diagonal_of_inverse_matrix_cpp( const Eigen::Map<Eigen::MatrixXd>& M,
		int j) {

	
    return compute_diagonal_inverse_entry(M, j);
}

// [[Rcpp::export]]
Eigen::MatrixXd eigen_Xt_times_diag_w_times_X_cpp(const Eigen::Map<Eigen::MatrixXd>& X, SEXP w) {
	NumericVector w_r_coerced(w); Eigen::Map<const Eigen::VectorXd> w_vec_coerced(w_r_coerced.begin(), w_r_coerced.size());


	

	
	return weighted_crossprod(X, w_vec_coerced);
}

// [[Rcpp::export]]
Rcpp::List likelihood_ratio_test_from_negloglik_cpp(double unrestricted_neg_loglik,
                                                    double null_neg_loglik,
                                                    int df = 1) {
	return likelihood_ratio_test_from_negloglik(unrestricted_neg_loglik, null_neg_loglik, df);
}

// [[Rcpp::export]]
Rcpp::List score_test_from_score_information_cpp( const Eigen::Map<Eigen::VectorXd>& score,
		const Eigen::Map<Eigen::MatrixXd>& information,
		int tested_idx) {

	

	
	return score_test_from_score_information(score, information, tested_idx);
}

// [[Rcpp::export]]
Rcpp::List gradient_test_from_restricted_score_cpp( const Eigen::Map<Eigen::VectorXd>& score,
		double unrestricted_estimate,
		double null_value,
		int tested_idx) {

	
	return gradient_test_from_restricted_score(score, unrestricted_estimate, null_value, tested_idx);
}

// [[Rcpp::export]]
double mean_cpp( const Eigen::Map<Eigen::VectorXd>& x) {

	
	if (x.size() == 0) {
	return NA_REAL;
	}
	return x.mean();
}

// [[Rcpp::export]]
double var_cpp( const Eigen::Map<Eigen::VectorXd>& x) {

	
	if (x.size() <= 1) {
	return NA_REAL;
	}
	return (x.array() - x.mean()).square().sum() / (x.size() - 1);
}
#endif // EDI_CORE_ONLY
