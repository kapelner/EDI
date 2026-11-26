#ifndef EDI_SURVIVAL_RAND_BOOTSTRAP_RCPP_H
#define EDI_SURVIVAL_RAND_BOOTSTRAP_RCPP_H

#include "_helper_functions.h"

template <typename FitDraw>
inline Rcpp::NumericVector survival_rand_bootstrap(
    const Rcpp::NumericVector& y0, const Rcpp::IntegerVector& dead,
    const Rcpp::NumericMatrix& Xc, const Rcpp::IntegerMatrix& i_mat,
    const Rcpp::IntegerMatrix& w_mat, double delta,
    Rcpp::Nullable<Rcpp::NumericMatrix> noise_mat, int num_cores,
    int treatment_column, int work_size, FitDraw fit_draw) {
    const int n = i_mat.nrow();
    const int nsim = i_mat.ncol();
    const int n_full = y0.size();
    const int p_cov = Xc.ncol();
    const int p = treatment_column + 1 + p_cov;
    const double* y0_ptr = y0.begin();
    const int* dead_ptr = dead.begin();
    const double* xc_ptr = p_cov > 0 ? Xc.begin() : nullptr;
    const int* i_ptr = i_mat.begin();
    const int* w_ptr = w_mat.begin();
    const double mult = delta != 0.0 ? std::exp(delta) : 1.0;
    std::vector<double> results(nsim, NA_REAL);

    Rcpp::NumericMatrix noise;
    if (noise_mat.isNotNull()) noise = Rcpp::NumericMatrix(noise_mat);
    // A non-null but empty matrix represents no smoothing.
    const double* noise_ptr = noise.size() > 0 ? noise.begin() : nullptr;

#pragma omp parallel if(EDI_KERNEL_NUM_THREADS(num_cores) > 1) num_threads(EDI_KERNEL_NUM_THREADS(num_cores))
    {
        Eigen::VectorXd y_b(n), dead_b(n), work(work_size);
        Eigen::MatrixXd X_b(n, p);

#pragma omp for schedule(dynamic)
        for (int b = 0; b < nsim; ++b) {
            const std::size_t offset = static_cast<std::size_t>(b) * n;
            const int* indices = i_ptr + offset;
            const int* assignments = w_ptr + offset;
            int n_t = 0, n_c = 0;
            for (int i = 0; i < n; ++i) {
                const int row = indices[i] - 1;
                const int wt = assignments[i] == 1 ? 1 : 0;
                if (treatment_column == 1) X_b(i, 0) = 1.0;
                X_b(i, treatment_column) = static_cast<double>(wt);
                for (int j = 0; j < p_cov; ++j) {
                    X_b(i, treatment_column + 1 + j) = xc_ptr[static_cast<std::size_t>(j) * n_full + row];
                }
                double yv = y0_ptr[row];
                if (noise_ptr) yv += noise_ptr[offset + i];
                y_b(i) = wt && mult != 1.0 ? yv * mult : yv;
                dead_b(i) = static_cast<double>(dead_ptr[row]);
                n_t += wt;
                n_c += 1 - wt;
            }
            if (n_t >= 2 && n_c >= 2) results[b] = fit_draw(X_b, y_b, dead_b, work);
        }
    }
    return Rcpp::wrap(results);
}

#endif
