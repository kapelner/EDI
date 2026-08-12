#include <RcppEigen.h>
using namespace Rcpp;

// [[Rcpp::depends(RcppEigen)]]

List compute_zhang_match_data_cpp(const NumericMatrix& X,
                                  const NumericVector& y,
                                  const IntegerVector& w,
                                  const IntegerVector& m_vec);

// [[Rcpp::export]]
List match_diffs_cpp(const Eigen::Map<Eigen::MatrixXd>& X, SEXP y, SEXP w, SEXP m_vec, int m) {
	IntegerVector m_vec_r_coerced(m_vec); Eigen::Map<const Eigen::VectorXi> m_vec_vec_coerced(m_vec_r_coerced.begin(), m_vec_r_coerced.size());
	IntegerVector w_r_coerced(w); Eigen::Map<const Eigen::VectorXi> w_vec_coerced(w_r_coerced.begin(), w_r_coerced.size());
	NumericVector y_r_coerced(y); Eigen::Map<const Eigen::VectorXd> y_vec_coerced(y_r_coerced.begin(), y_r_coerced.size());


        

        

        

        

        List match_data = compute_zhang_match_data_cpp(
                wrap(X),
                wrap(y_vec_coerced),
                wrap(w_vec_coerced),
                wrap(m_vec_vec_coerced)
        );

        return List::create(
        _["yTs_matched"] =              match_data["yTs_matched"],
        _["yCs_matched"] =              match_data["yCs_matched"],
        _["X_matched_diffs"] =  match_data["X_matched_diffs"]
        );
}

