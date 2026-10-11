#include <Rcpp.h>
#include "RNG.h"
#include <algorithm>
#include <vector>
#include <string>
#include <map>

using namespace Rcpp;

// [[Rcpp::export]]
NumericVector spbr_redraw_w_cpp(SEXP strata_keys_sexp, SEXP block_size_sexp, SEXP prob_T_sexp) {
    CharacterVector strata_keys = as<CharacterVector>(strata_keys_sexp);
    int block_size = as<int>(block_size_sexp);
    double prob_T = as<double>(prob_T_sexp);

    int n = strata_keys.size();
    NumericVector w(n);
    std::map<std::string, std::vector<double>> strata_blocks;

    int n_T_per_block = (int)std::round((double)block_size * prob_T);
    int n_C_per_block = block_size - n_T_per_block;

    edi_rng::RRng g(edi_rng::seed_from_unif01(R::unif_rand()));

    for (int i = 0; i < n; ++i) {
        std::string key = as<std::string>(strata_keys[i]);
        
        if (strata_blocks[key].empty()) {
            std::vector<double> new_block;
            new_block.reserve(block_size);
            for (int j = 0; j < n_T_per_block; ++j) new_block.push_back(1.0);
            for (int j = 0; j < n_C_per_block; ++j) new_block.push_back(0.0);
            
            edi_rng::fisher_yates_shuffle(new_block.begin(), new_block.end(), g);
            strata_blocks[key] = new_block;
        }
        
        w[i] = strata_blocks[key].back();
        strata_blocks[key].pop_back();
    }
    
    return w;
}

// [[Rcpp::export]]
IntegerVector stratified_bootstrap_indices_cpp(SEXP strata_keys_sexp) {
    edi_rng::RRng gen(edi_rng::seed_from_unif01(R::unif_rand()));
    const int n = Rf_xlength(strata_keys_sexp);
    IntegerVector indices(n);
    int current_idx = 0;

    if (TYPEOF(strata_keys_sexp) == INTSXP) {
        IntegerVector strata_ids(strata_keys_sexp);
        std::map<int, std::vector<int>> strata_map;
        for (int i = 0; i < n; ++i) strata_map[strata_ids[i]].push_back(i + 1);
        for (auto const& [id, members] : strata_map) {
            const int m = members.size();
            for (int j = 0; j < m; ++j) indices[current_idx++] = members[static_cast<int>(edi_rng::bounded_rand(gen, static_cast<std::uint32_t>(m)))];
        }
    } else {
        CharacterVector strata_keys = as<CharacterVector>(strata_keys_sexp);
        std::map<std::string, std::vector<int>> strata_map;
        for (int i = 0; i < n; ++i) {
            std::string key = as<std::string>(strata_keys[i]);
            strata_map[key].push_back(i + 1);
        }
        for (auto const& [key, members] : strata_map) {
            const int m = members.size();
            for (int j = 0; j < m; ++j) indices[current_idx++] = members[static_cast<int>(edi_rng::bounded_rand(gen, static_cast<std::uint32_t>(m)))];
        }
    }

    edi_rng::fisher_yates_shuffle(indices.begin(), indices.end(), gen);
    return indices;
}
