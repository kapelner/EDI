#include "_helper_functions.h"
#include <RcppEigen.h>
#include <vector>

#ifdef _OPENMP
#include <omp.h>
#endif

// [[Rcpp::depends(RcppEigen)]]
// [[Rcpp::plugins(openmp)]]

using namespace Rcpp;

// [[Rcpp::export]]
NumericVector compute_ols_distr_parallel_cpp(const Eigen::Map<Eigen::MatrixXd>& X, SEXP y, const Eigen::Map<Eigen::MatrixXi>& w_mat, double delta, int num_cores) {
	NumericVector y_r_coerced(y); Eigen::Map<const Eigen::VectorXd> y_vec_coerced(y_r_coerced.begin(), y_r_coerced.size());


        

        

        

        int nsim = w_mat.cols();
        int n = y_vec_coerced.size();
        int p_covars = X.cols();
        int p_full = p_covars + 2; // Intercept + w + covars

        if (X.rows() != n) {
                stop("compute_ols_distr_parallel_cpp: X rows must match length(y_vec_coerced).");
        }
        if (w_mat.rows() != n) {
                stop("compute_ols_distr_parallel_cpp: w_mat rows must match length(y_vec_coerced).");
        }
        if (nsim <= 0) {
                return NumericVector(0);
        }
        if (num_cores < 1) {
                num_cores = 1;
        }

        std::vector<double> results_vec(nsim);

        const double* y_ptr = y_vec_coerced.data();
        const int* w_ptr = w_mat.data();
        double* res_ptr = results_vec.data();
        const bool use_parallel = should_parallelize_replicates(nsim, n, num_cores);

#ifdef _OPENMP
        if (use_parallel) omp_set_num_threads(num_cores);
#endif

        // MEMOIZATION
        double sum_1 = (double)n;
        Eigen::VectorXd Xt_1 = X.colwise().sum();
        Eigen::MatrixXd XtX_c = X.transpose() * X;

#pragma omp parallel for schedule(static) if(use_parallel)
        for (int b = 0; b < nsim; ++b) {
                const int* w_col = w_ptr + (size_t)b * n;

                Eigen::VectorXd w_d(n);
                Eigen::VectorXd y_sim(n);
                double sum_w = 0;
                double sum_y = 0;
                double sum_wy = 0;

#pragma omp simd reduction(+:sum_w,sum_y,sum_wy)
                for (int i = 0; i < n; ++i) {
                        double w_val = (double)w_col[i];
                        w_d[i] = w_val;
                        sum_w += w_val;
                        double y_val = y_ptr[i] + (w_col[i] == 1 ? delta : 0.0);
                        y_sim[i] = y_val;
                        sum_y += y_val;
                        sum_wy += w_val * y_val;
                }

                Eigen::VectorXd Xt_w = X.transpose() * w_d;

                        Eigen::MatrixXd XtX(p_full, p_full);
                        XtX.setZero();
                        XtX(0, 0) = sum_1;
                        XtX(0, 1) = sum_w;
                        XtX.row(0).tail(p_covars) = Xt_1.transpose();

                XtX(1, 0) = sum_w;
                XtX(1, 1) = sum_w;
                XtX.row(1).tail(p_covars) = Xt_w.transpose();

                XtX.col(0).tail(p_covars) = Xt_1;
                XtX.col(1).tail(p_covars) = Xt_w;
                XtX.bottomRightCorner(p_covars, p_covars) = XtX_c;

                Eigen::VectorXd Xty(p_full);
                Xty[0] = sum_y;
                Xty[1] = sum_wy;
                Xty.tail(p_covars) = X.transpose() * y_sim;

                Eigen::ColPivHouseholderQR<Eigen::MatrixXd> qr(XtX);
                Eigen::VectorXd beta = qr.solve(Xty);
                res_ptr[b] = beta.allFinite() && beta.size() > 1 ? beta[1] : NA_REAL;
        }

        return wrap(results_vec);
}

// Bootstrap OLS: for each column of indices_mat (0-based row indices, -1 = NA bootstrap),
// resample y/w/X and return the OLS treatment coefficient.
// [[Rcpp::export]]
NumericVector compute_ols_bootstrap_parallel_cpp(const Eigen::Map<Eigen::MatrixXd>& X, SEXP y, SEXP w, const Eigen::Map<Eigen::MatrixXi>& indices_mat, int num_cores) {
	IntegerVector w_r_coerced(w); Eigen::Map<const Eigen::VectorXi> w_vec_coerced(w_r_coerced.begin(), w_r_coerced.size());
	NumericVector y_r_coerced(y); Eigen::Map<const Eigen::VectorXd> y_vec_coerced(y_r_coerced.begin(), y_r_coerced.size());


        

        

        

        

        int B = indices_mat.cols();
        int n_boot = indices_mat.rows(); // bootstrap sample size (= n for simple bootstrap)
        int p_covars = X.cols();
        int p_full = p_covars + 2; // intercept + w_vec_coerced + covars

        if (X.rows() != y_vec_coerced.size()) {
                stop("compute_ols_bootstrap_parallel_cpp: X rows must match length(y_vec_coerced).");
        }
        if (w_vec_coerced.size() != y_vec_coerced.size()) {
                stop("compute_ols_bootstrap_parallel_cpp: w_vec_coerced length must match length(y_vec_coerced).");
        }
        if (indices_mat.rows() <= 0 || B <= 0) {
                return NumericVector(0);
        }
        if (num_cores < 1) {
                num_cores = 1;
        }

        std::vector<double> results_vec(B, NA_REAL);

        const double* y_ptr = y_vec_coerced.data();
        const int* w_ptr = w_vec_coerced.data();
        const int* idx_ptr = indices_mat.data();
        const bool use_parallel = should_parallelize_replicates(B, n_boot, num_cores);

#ifdef _OPENMP
        if (use_parallel) omp_set_num_threads(num_cores);
#endif

#pragma omp parallel for schedule(static) if(use_parallel)
        for (int b = 0; b < B; ++b) {
                const int* idx_col = idx_ptr + (size_t)b * n_boot;
                if (idx_col[0] < 0) { results_vec[b] = NA_REAL; continue; }

                Eigen::VectorXd y_b(n_boot);
                Eigen::VectorXd w_b(n_boot);
                Eigen::MatrixXd X_b(n_boot, p_covars);

                double sum_1 = (double)n_boot;
                double sum_w = 0.0, sum_y = 0.0, sum_wy = 0.0;

                for (int i = 0; i < n_boot; ++i) {
                        int idx = idx_col[i];
                        y_b[i] = y_ptr[idx];
                        double wv = (double)w_ptr[idx];
                        w_b[i] = wv;
                        sum_w += wv;
                        sum_y += y_b[i];
                        sum_wy += wv * y_b[i];
                        X_b.row(i) = X.row(idx);
                }

                Eigen::VectorXd Xt_1 = X_b.colwise().sum();
                Eigen::VectorXd Xt_w = X_b.transpose() * w_b;
                Eigen::MatrixXd XtX_c = X_b.transpose() * X_b;

                Eigen::MatrixXd XtX(p_full, p_full);
                XtX.setZero();
                XtX(0, 0) = sum_1;
                XtX(0, 1) = sum_w;
                XtX.row(0).tail(p_covars) = Xt_1.transpose();

                XtX(1, 0) = sum_w;
                XtX(1, 1) = sum_w;
                XtX.row(1).tail(p_covars) = Xt_w.transpose();

                XtX.col(0).tail(p_covars) = Xt_1;
                XtX.col(1).tail(p_covars) = Xt_w;
                XtX.bottomRightCorner(p_covars, p_covars) = XtX_c;

                Eigen::VectorXd Xty(p_full);
                Xty[0] = sum_y;
                Xty[1] = sum_wy;
                Xty.tail(p_covars) = X_b.transpose() * y_b;

                Eigen::ColPivHouseholderQR<Eigen::MatrixXd> qr(XtX);
                Eigen::VectorXd beta = qr.solve(Xty);
                results_vec[b] = beta.allFinite() && beta.size() > 1 ? beta[1] : NA_REAL;
        }

        return wrap(results_vec);
}
