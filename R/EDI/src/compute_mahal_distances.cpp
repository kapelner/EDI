#include <RcppEigen.h>
using namespace Rcpp;

// [[Rcpp::depends(RcppEigen)]]
// xt_prev: fixed vector
// X_prev: full data matrix
// reservoir_indices: indices (1-based from R)
// S_xs_inv: inverse covariance matrix
// [[Rcpp::export]]
Eigen::VectorXd compute_proportional_mahal_distances_cpp( const Eigen::Map<Eigen::VectorXd>& xt_prev,
	const Eigen::Map<Eigen::MatrixXd>& X_prev,
	const Eigen::Map<Eigen::VectorXi>& reservoir_indices,
	const Eigen::Map<Eigen::MatrixXd>& S_xs_inv)
{
	const int n_R = reservoir_indices.size();
	const int p   = xt_prev.size();

	// Build D column-wise to match R/Eigen's column-major matrix layout.
	Eigen::MatrixXd D(n_R, p);
	for (int j = 0; j < p; ++j) {
		const double xtj = xt_prev[j];
		double* D_col = D.col(j).data();
		const double* X_col = X_prev.col(j).data();
#pragma omp simd
		for (int r = 0; r < n_R; ++r) {
			D_col[r] = xtj - X_col[reservoir_indices[r] - 1];
		}
	}

	// All quadratic forms d'*S_inv*d in one batched Eigen call:
	//   (D * S_inv) elementwise-product D, summed per row
	return (D * S_xs_inv).cwiseProduct(D).rowwise().sum();
}
