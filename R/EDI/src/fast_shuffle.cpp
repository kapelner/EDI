#include <RcppEigen.h>
#include "RNG.h"
#include <random>
using namespace Rcpp;
using namespace Eigen;

// [[Rcpp::export]]
NumericVector shuffle_cpp(SEXP w) {
	NumericVector w_r_coerced(w); Eigen::Map<Eigen::VectorXd> w_vec_coerced(w_r_coerced.begin(), w_r_coerced.size());

        edi_rng::RRng rng(edi_rng::seed_from_unif01(R::unif_rand()));
        std::shuffle(w_vec_coerced.data(), w_vec_coerced.data() + w_vec_coerced.size(), rng);
        return wrap(w_vec_coerced);
}

