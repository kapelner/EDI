#include <RcppEigen.h>
#include <random>
#include <chrono>
using namespace Rcpp;
using namespace Eigen;

// [[Rcpp::export]]
NumericVector shuffle_cpp(SEXP w) {
	NumericVector w_r_coerced(w); Eigen::Map<Eigen::VectorXd> w_vec_coerced(w_r_coerced.begin(), w_r_coerced.size());

        unsigned seed = std::chrono::system_clock::now().time_since_epoch().count();
        std::shuffle(w_vec_coerced.data(), w_vec_coerced.data() + w_vec_coerced.size(), std::default_random_engine(seed));
        return wrap(w_vec_coerced);
}

