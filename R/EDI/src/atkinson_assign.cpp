#ifdef EDI_CORE_ONLY
#include "_helper_functions_core.h"
#else
#include "_helper_functions.h"
#include <RcppEigen.h>
#endif
#include "RNG.h"
#include <cmath>
#include <cstdint>
#include <limits>

#ifndef EDI_CORE_ONLY
using namespace Rcpp;
#endif

namespace {

// Portable core (EDI_CORE_ONLY-safe): identical logic to
// atkinson_assign_weight_cpp below, but takes an already-constructed
// edi_rng::RRng by reference instead of drawing from R's RNG internally.
// This is called live, once per incoming subject during sequential
// enrollment, so there is no batch dimension to parallelize -- each call
// depends on the design accumulated from every prior subject.
int atkinson_assign_weight_internal(
	const Eigen::VectorXd& w_prev,
	const Eigen::MatrixXd& X_prev,
	const Eigen::VectorXd& xt_prev,
	int t,
	edi_rng::RRng& rng
) {
	int rows = static_cast<int>(w_prev.size());
	int p = static_cast<int>(X_prev.cols());
	int cols = p + 2;
	if (rows == 0 || cols < 2) {
		return (rng.unif_rand() < 0.5) ? 1 : 0;
	}

	Eigen::MatrixXd XprevWT(rows, cols);
	XprevWT.col(0) = w_prev;
	XprevWT.col(1).setOnes();
	XprevWT.rightCols(p) = X_prev;

	Eigen::MatrixXd XwtXw = XprevWT.transpose() * XprevWT;
	Eigen::FullPivLU<Eigen::MatrixXd> lu(XwtXw);
	if (!lu.isInvertible()) {
		return (rng.unif_rand() < 0.5) ? 1 : 0;
	}

	Eigen::MatrixXd M = static_cast<double>(t - 1) * lu.inverse();
	Eigen::VectorXd row_segment = M.row(0).segment(1, p + 1);

	Eigen::VectorXd xt(p + 1);
	xt(0) = 1.0;
	xt.tail(p) = xt_prev;

	double A = row_segment.dot(xt);
	if (A == 0 || !std::isfinite(A)) {
		return (rng.unif_rand() < 0.5) ? 1 : 0;
	}

	double val = M(0, 0) / A + 1.0;
	double s_over_A_plus_one_sq = val * val;
	double prob = s_over_A_plus_one_sq / (s_over_A_plus_one_sq + 1.0);
	prob = std::max(0.0, std::min(1.0, prob));
	return (rng.unif_rand() < prob) ? 1 : 0;
}

} // namespace

#ifndef EDI_CORE_ONLY
//' @note Seeded from one R::unif_rand() draw into edi_rng::RRng (RNG.h), a
//'   portable re-implementation of R's own Mersenne-Twister generator -- a
//'   given seed therefore produces identical draws in R and in any future
//'   binding (e.g. Python) using the same core and the same seed.
// [[Rcpp::export]]
double atkinson_assign_weight_cpp(
	const NumericVector& w_prev,
	const NumericMatrix& X_prev,
	const NumericVector& xt_prev,
	int rank_prev,
	int t
) {
	Eigen::VectorXd w_e = as<Eigen::VectorXd>(w_prev);
	Eigen::MatrixXd X_e = as<Eigen::MatrixXd>(X_prev);
	Eigen::VectorXd xt_e = as<Eigen::VectorXd>(xt_prev);

	std::uint32_t seed = edi_rng::seed_from_unif01(R::unif_rand());
	edi_rng::RRng rng(seed);
	return static_cast<double>(atkinson_assign_weight_internal(w_e, X_e, xt_e, t, rng));
}
#endif // EDI_CORE_ONLY
