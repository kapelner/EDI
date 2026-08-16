#ifndef EDI_USER_COMPILED_FNS_H
#define EDI_USER_COMPILED_FNS_H

// The package-wide calling conventions for user-supplied compiled C++
// functions, entering via RcppXPtrUtils::cppXPtr() externalptrs (or C++
// source strings compiled through the same mechanism). One header for every
// feature that accepts user C++ -- currently DesignFixedOptimal's
// custom_objective (design_fixed_optimal.md TODO-7) and the custom
// randomization statistic's XPtr form (set_custom_randomization_statistic_cpp;
// its legacy source-string form predates this convention and keeps its
// Rcpp-typed, R-callable signature) -- so the pointer handling stays uniform:
// same validation (normalize_user_cpp_fn() in helper_user_compiled_fn.R),
// same deref pattern (the eval shims in user_compiled_fn_shims.cpp), same
// Eigen-only signatures.
//
// EDI_CORE_ONLY: see result_map.h for the convention. Signatures use only
// Eigen types (never SEXP/Rcpp), so both branches differ only in which
// header supplies them.
#ifdef EDI_CORE_ONLY
#include <Eigen/Dense>
#else
#include <RcppEigen.h>
#endif

// DesignFixedOptimal custom objective: f(model matrix X, candidate 0/1
// allocation w) -> criterion value to MINIMIZE.
typedef double (*edi_design_objective_fn)(const Eigen::MatrixXd& X, const Eigen::VectorXd& w);

// Custom randomization statistic (XPtr form): f(y, w) -> scalar statistic,
// or the 3-argument form with the survival dead indicator.
typedef double (*edi_rand_stat_fn)(const Eigen::VectorXd& y, const Eigen::VectorXd& w);
typedef double (*edi_rand_stat_dead_fn)(const Eigen::VectorXd& y, const Eigen::VectorXd& w, const Eigen::VectorXd& dead);

#endif
