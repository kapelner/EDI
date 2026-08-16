#ifdef EDI_CORE_ONLY
#include <Eigen/Dense>
#include <stdexcept>
#else
#include <RcppEigen.h>
#endif
#include "RNG.h"
#include "r_seed_draw.h"
#include <algorithm>
#include <vector>
#include <array>
#include <cstdint>
#include <limits>

#ifndef EDI_CORE_ONLY
using namespace Rcpp;
#endif

namespace {

// Portable core (EDI_CORE_ONLY-safe): identical logic to pocock_simon_assign_cpp
// below, but takes an already-constructed edi_rng::RRng by reference instead
// of drawing from R's RNG internally. NOTE: Pocock-Simon minimization is an
// inherently sequential adaptive design -- each subject's assignment depends
// on the running covariate-level counts left behind by every prior subject
// -- so there is no batch/replicate dimension here to parallelize, unlike
// generate_permutations.cpp's *_internal cores.
int pocock_simon_assign_internal(
	const Eigen::Ref<const Eigen::MatrixXd>& counts,
	const Eigen::Ref<const Eigen::VectorXi>& subject_levels_idx,
	const Eigen::Ref<const Eigen::VectorXd>& weights,
	double p_best, double prob_T, edi_rng::RRng& rng) {
	int num_trts = static_cast<int>(counts.cols()); // Should be 2 (Control=0, Treatment=1)
	int num_covs = static_cast<int>(subject_levels_idx.size());

	std::vector<double> G(static_cast<std::size_t>(num_trts), 0.0);

	for (int k = 0; k < num_trts; ++k) {
		double G_k = 0.0;
		for (int j = 0; j < num_covs; ++j) {
			int row_idx = subject_levels_idx[j] - 1; // 1-based to 0-based

			// Calculate imbalance for covariate j if assigned to treatment k
			// We use the variance of counts across treatments as the measure d_ik
			std::vector<double> counts_after(static_cast<std::size_t>(num_trts));
			double sum = 0.0;
			for (int t = 0; t < num_trts; ++t) {
				counts_after[static_cast<std::size_t>(t)] = counts(row_idx, t) + (t == k ? 1 : 0);
				sum += counts_after[static_cast<std::size_t>(t)];
			}

			double mean = sum / num_trts;
			double var = 0.0;
			for (int t = 0; t < num_trts; ++t) {
				var += (counts_after[static_cast<std::size_t>(t)] - mean) * (counts_after[static_cast<std::size_t>(t)] - mean);
			}
			var /= (num_trts - 1);

			G_k += weights[j] * var;
		}
		G[static_cast<std::size_t>(k)] = G_k;
	}

	int best_trt = 0;
	if (G[1] < G[0]) {
		best_trt = 1;
	} else if (G[0] < G[1]) {
		best_trt = 0;
	} else {
		// Tie: use prob_T
		return (rng.unif_rand() < prob_T) ? 1 : 0;
	}

	// Assign best treatment with probability p_best
	if (rng.unif_rand() < p_best) {
		return best_trt;
	} else {
		return 1 - best_trt;
	}
}

// Portable core (EDI_CORE_ONLY-safe): identical logic to
// pocock_simon_redraw_w_cpp below, but takes an already-constructed
// edi_rng::RRng by reference instead of drawing from R's RNG internally.
// Unlike its siblings above, the Rcpp wrapper below seeds this RRng from
// R's actual live .Random.seed state (continuing R's real stream) rather
// than from one drawn value, so this core's output is bit-identical to
// what calling R's own unif_rand() directly, in a loop, would have
// produced -- verified against an independent pure-R reference
// implementation in test-pocock-simon-redraw-buffers.R. Also sequential
// over subjects by design (each depends on the running counts), so there
// is no batch dimension to parallelize.
Eigen::VectorXi pocock_simon_redraw_w_internal(
	const Eigen::Ref<const Eigen::MatrixXi>& x_levels_matrix, int num_levels_total,
	const Eigen::Ref<const Eigen::VectorXd>& weights, double p_best, double prob_T, edi_rng::RRng& rng) {
	int n = static_cast<int>(x_levels_matrix.rows());
	int num_covs = static_cast<int>(x_levels_matrix.cols());
	if (num_levels_total <= 0) throw std::invalid_argument("num_levels_total must be positive");
	if (weights.size() != num_covs) throw std::invalid_argument("weights length must match the number of covariates");

	std::vector<int> level_rows(static_cast<std::size_t>(n) * static_cast<std::size_t>(num_covs));
	for (int i = 0; i < n; ++i) {
		for (int j = 0; j < num_covs; ++j) {
			const int row_idx = x_levels_matrix(i, j) - 1;
			if (row_idx < 0 || row_idx >= num_levels_total) {
				throw std::invalid_argument("x_levels_matrix contains a level index outside 1..num_levels_total");
			}
			level_rows[static_cast<std::size_t>(i) * static_cast<std::size_t>(num_covs) + static_cast<std::size_t>(j)] = row_idx;
		}
	}

	Eigen::VectorXi w(n);
	int* w_ptr = w.data();
	const double* weights_ptr = weights.data();
	std::vector<int> counts(static_cast<std::size_t>(num_levels_total) * 2, 0);

	for (int i = 0; i < n; ++i) {
		const int* subject_levels = level_rows.data() + static_cast<std::size_t>(i) * static_cast<std::size_t>(num_covs);
		double G[2] = {0.0, 0.0};
		for (int k = 0; k < 2; ++k) {
			double G_k = 0.0;
			for (int j = 0; j < num_covs; ++j) {
				const int row_idx = subject_levels[j];
				const double c0 = counts[static_cast<std::size_t>(row_idx) * 2] + (k == 0 ? 1 : 0);
				const double c1 = counts[static_cast<std::size_t>(row_idx) * 2 + 1] + (k == 1 ? 1 : 0);
				const double mean = (c0 + c1) / 2.0;
				const double variance = (c0 - mean) * (c0 - mean) + (c1 - mean) * (c1 - mean);
				G_k += weights_ptr[j] * variance;
			}
			G[k] = G_k;
		}

		int assigned_w;
		if (G[0] == G[1]) {
			assigned_w = (rng.unif_rand() < prob_T) ? 1 : 0;
		} else {
			const int best_treatment = (G[1] < G[0]) ? 1 : 0;
			assigned_w = (rng.unif_rand() < p_best) ? best_treatment : 1 - best_treatment;
		}
		w_ptr[i] = assigned_w;

		// Update counts
		for (int j = 0; j < num_covs; ++j) {
			counts[static_cast<std::size_t>(subject_levels[j]) * 2 + static_cast<std::size_t>(assigned_w)]++;
		}
	}

	return w;
}

} // namespace

#ifndef EDI_CORE_ONLY
namespace {

// Reads R's live .Random.seed directly (creating it first via a harmless
// GetRNGstate()/PutRNGstate() pair if it doesn't exist yet), validates it's
// the Mersenne-Twister + Inversion kind this package always uses, and
// constructs an edi_rng::RRng continuing from that exact state.
edi_rng::RRng rrng_from_live_r_state() {
	Rcpp::Environment global = Rcpp::Environment::global_env();
	if (!global.exists(".Random.seed")) {
		GetRNGstate();
		PutRNGstate();
	}
	IntegerVector rs = global.get(".Random.seed");
	if (rs.size() != 626) stop("pocock_simon_redraw_w_cpp: unexpected .Random.seed length (RNGkind changed?)");
	int kind_code = rs[0];
	int rng_kind = kind_code % 100;
	int n01_kind = (kind_code / 100) % 100;
	if (rng_kind != 3 || n01_kind != 4) {
		stop("pocock_simon_redraw_w_cpp: requires RNGkind (\"Mersenne-Twister\", \"Inversion\")");
	}
	std::array<edi_rng::Int32, 624> mt;
	for (int i = 0; i < 624; ++i) mt[static_cast<std::size_t>(i)] = static_cast<edi_rng::Int32>(rs[2 + i]);
	return edi_rng::RRng(static_cast<std::int32_t>(rs[1]), mt);
}

// Writes an edi_rng::RRng's current state back to R's live .Random.seed, so
// R's own stream continues correctly for whatever runs after this call. See
// RNG.h's header comment for why the trailing GetRNGstate() is required
// (Rcpp's implicit RNGScope would otherwise silently overwrite this write
// with stale internal state when the exported function returns).
void write_rrng_state_to_r(const edi_rng::RRng& rng) {
	Rcpp::Environment global = Rcpp::Environment::global_env();
	IntegerVector rs = global.get(".Random.seed");
	rs[1] = static_cast<int>(rng.mti());
	const auto& st = rng.state();
	for (int i = 0; i < 624; ++i) rs[2 + i] = static_cast<int>(st[static_cast<std::size_t>(i)]);
	global.assign(".Random.seed", rs);
	GetRNGstate();
}
} // namespace

//' Pocock-Simon Covariate-Adaptive Minimization: Assignment Decision (C++)
//'
//' Decides the next subject's treatment assignment under Pocock and Simon's
//' (1975) covariate-adaptive minimization algorithm, without modifying any
//' state (see \code{\link{pocock_simon_assign_and_update_cpp}} for the
//' state-updating wrapper actually used by the stepwise design). \code{counts}
//' stacks, for every level of every stratification covariate, the number of
//' previously-assigned subjects at that level currently in each treatment arm
//' (one row per covariate level, one column per arm — the design supports
//' exactly 2 arms). The subject to be assigned belongs to one level per
//' covariate, given by \code{subject_levels_idx} (1-indexed rows into
//' \code{counts}).
//'
//' For each candidate arm \eqn{k \in \{0,1\}}, a marginal imbalance score is
//' computed as the weighted sum, over the subject's covariates \eqn{j}, of the
//' \strong{variance across arms} of the level's counts \emph{if} the subject
//' were assigned to arm \eqn{k}:
//' \deqn{G_k = \sum_j w_j \, \mathrm{Var}_t\big(n_{j,t} + \mathbb{1}\{t=k\}\big),}
//' where \eqn{n_{j,t}} is the current count for the subject's level of
//' covariate \eqn{j} in arm \eqn{t}, and the variance is taken over the (here,
//' 2) arms with the usual \eqn{n-1} divisor — so \eqn{G_k} is smallest for the
//' arm that would leave covariate margins most balanced. The arm with the
//' smaller \eqn{G_k} (\code{best_trt}) is then assigned with a biased-coin
//' probability \code{p_best} (and the other arm with probability
//' \code{1 - p_best}); if \eqn{G_0 = G_1} exactly (perfect tie), the assignment
//' is instead a single Bernoulli(\code{prob_T}) draw for arm 1. Setting
//' \code{p_best = 1} recovers Taves' deterministic minimization; \code{p_best}
//' strictly between 0.5 and 1 (Pocock and Simon's recommendation, e.g. 0.75-0.85)
//' retains most of minimization's balancing power while preserving some
//' unpredictability of the next assignment.
//'
//' @param counts A numeric matrix, one row per stratification-covariate level
//'   (across all covariates, stacked) and one column per treatment arm (2
//'   columns), of counts of subjects previously assigned to that level/arm
//'   combination.
//' @param subject_levels_idx An integer vector (1-indexed, length = number of
//'   stratification covariates) giving, for the subject being assigned, which
//'   row of \code{counts} each covariate's current level corresponds to.
//' @param weights A numeric vector, parallel to \code{subject_levels_idx}, of
//'   the relative weight \eqn{w_j} placed on each covariate's imbalance in the
//'   combined score \eqn{G_k}.
//' @param p_best The probability of assigning the arm that minimizes \eqn{G_k}
//'   (the biased coin); \code{1} is deterministic minimization, values near
//'   \code{0.5} approach simple randomization.
//' @param prob_T The Bernoulli probability used to break an exact tie in
//'   \eqn{G_0 = G_1} (assigns arm 1 with this probability); typically \code{0.5}.
//'
//' @return The assigned treatment arm, \code{0} or \code{1}.
//' @note Seeded from one R::unif_rand() draw into edi_rng::RRng (RNG.h), a
//'   portable re-implementation of R's own Mersenne-Twister generator -- a
//'   given seed therefore produces identical draws in R and in any future
//'   binding (e.g. Python) using the same core and the same seed, even
//'   though this call does not continue R's own live session stream bit-
//'   for-bit (see pocock_simon_redraw_w_cpp for the one function in this
//'   file where that distinction matters and is handled).
//' @references Pocock, S. J. and Simon, R. (1975). "Sequential Treatment
//'   Assignment with Balancing for Prognostic Factors in the Controlled
//'   Clinical Trial." \emph{Biometrics}, 31(1), 103-115.
//' @seealso \code{\link{pocock_simon_assign_and_update_cpp}} for the
//'   assign-and-mutate-\code{counts} wrapper; \code{\link{pocock_simon_redraw_w_cpp}}
//'   for the batch re-derivation of a whole assignment sequence from scratch.
//' @export
//' @keywords internal
// [[Rcpp::export]]
int pocock_simon_assign_cpp(const Eigen::Map<Eigen::MatrixXd>& counts, const Eigen::Map<Eigen::VectorXi>& subject_levels_idx, const Eigen::Map<Eigen::VectorXd>& weights, double p_best, double prob_T) {
	edi_rng::RRng rng(edi_rng::draw_seed_from_r());
	return pocock_simon_assign_internal(counts, subject_levels_idx, weights, p_best, prob_T, rng);
}

//' Pocock-Simon Covariate-Adaptive Minimization: Assign and Update Counts (C++)
//'
//' The stateful wrapper around \code{\link{pocock_simon_assign_cpp}} actually
//' used to drive a one-subject-at-a-time Pocock-Simon minimization design: it
//' computes the next assignment using the identical imbalance-score/biased-coin
//' logic documented on \code{\link{pocock_simon_assign_cpp}} (see that page for
//' the full model), then \strong{mutates \code{counts} in place}, incrementing,
//' for every covariate in \code{subject_levels_idx}, the count of the assigned
//' arm at that covariate's level — so the running covariate-by-arm counts stay
//' correct for the next subject's assignment.
//'
//' @param counts A numeric matrix, one row per stratification-covariate level
//'   and one column per treatment arm (2 columns); modified in place to record
//'   the new assignment.
//' @param subject_levels_idx An integer vector (1-indexed) giving, for the
//'   subject being assigned, which row of \code{counts} each covariate's
//'   current level corresponds to.
//' @param weights A numeric vector, parallel to \code{subject_levels_idx}, of
//'   the relative weight placed on each covariate's imbalance.
//' @param p_best The probability of assigning the arm that minimizes the
//'   combined imbalance score (the biased coin).
//' @param prob_T The Bernoulli probability used to break an exact imbalance tie.
//'
//' @return The assigned treatment arm, \code{0} or \code{1}. As a side effect,
//'   \code{counts} is incremented at row \code{subject_levels_idx[j]}, column
//'   \code{w} (the returned assignment) for every covariate \code{j}.
//' @note Reproducibility notes: see \code{\link{pocock_simon_assign_cpp}}.
//' @references Pocock, S. J. and Simon, R. (1975). "Sequential Treatment
//'   Assignment with Balancing for Prognostic Factors in the Controlled
//'   Clinical Trial." \emph{Biometrics}, 31(1), 103-115.
//' @seealso \code{\link{pocock_simon_assign_cpp}} for the underlying
//'   non-mutating decision logic and the full imbalance-score model.
//' @export
//' @keywords internal
// [[Rcpp::export]]
int pocock_simon_assign_and_update_cpp(NumericMatrix counts, IntegerVector subject_levels_idx, NumericVector weights, double p_best, double prob_T) {
	Eigen::Map<Eigen::MatrixXd> counts_map(counts.begin(), counts.nrow(), counts.ncol());
	Eigen::Map<const Eigen::VectorXi> idx_map(subject_levels_idx.begin(), subject_levels_idx.size());
	Eigen::Map<const Eigen::VectorXd> weights_map(weights.begin(), weights.size());

	edi_rng::RRng rng(edi_rng::draw_seed_from_r());
	int w = pocock_simon_assign_internal(counts_map, idx_map, weights_map, p_best, prob_T, rng);

	// Update counts in place
	for (int j = 0; j < subject_levels_idx.size(); ++j) {
		int row_idx = subject_levels_idx[j] - 1;
		counts(row_idx, w)++;
	}

	return w;
}

//' Pocock-Simon Covariate-Adaptive Minimization: Batch Redraw of a Whole
//' Assignment Sequence (C++)
//'
//' Replays the same Pocock-Simon minimization decision logic as
//' \code{\link{pocock_simon_assign_cpp}} (see that page for the imbalance-score
//' and biased-coin model) over an entire sequence of \code{n} subjects in one
//' call, starting from empty covariate-by-arm counts (all zero) and updating
//' them internally after each subject, rather than being called once per
//' subject with externally-maintained \code{counts}. This is used to
//' \strong{re-derive} (\dQuote{redraw}) a full sequence of assignments in a
//' single vectorized pass — e.g. for simulation, or for reconstructing what a
//' one-at-a-time run would have produced — while consuming R's uniform random
//' stream in exactly the same order a subject-by-subject loop calling
//' \code{\link{pocock_simon_assign_cpp}} would have.
//'
//' @param x_levels_matrix An integer matrix with one row per subject and one
//'   column per stratification covariate; entry \code{(i, j)} is the 1-indexed
//'   level (row of the internal counts table) of covariate \code{j} for subject
//'   \code{i}.
//' @param num_levels_total The total number of distinct covariate levels across
//'   all covariates (i.e. the number of rows the internal counts table has).
//' @param weights A numeric vector, one per covariate column of
//'   \code{x_levels_matrix}, of the relative weight placed on each covariate's
//'   imbalance in the combined score.
//' @param p_best The probability of assigning the arm that minimizes the
//'   combined imbalance score (the biased coin).
//' @param prob_T The Bernoulli probability used to break an exact imbalance tie.
//'
//' @return An integer vector of length \code{n}, the treatment arm (\code{0} or
//'   \code{1}) assigned to each subject in row order of \code{x_levels_matrix}.
//' @note Continues R's actual live .Random.seed stream via edi_rng::RRng
//'   (RNG.h) rather than seeding independently -- output is bit-identical
//'   to what calling R's own unif_rand() directly, in this same loop, would
//'   have produced (verified against a pure-R reference implementation in
//'   test-pocock-simon-redraw-buffers.R). Requires RNGkind
//'   ("Mersenne-Twister", "Inversion"), R's default.
//' @export
//' @keywords internal
// [[Rcpp::export]]
Eigen::VectorXi pocock_simon_redraw_w_cpp(const Eigen::Map<Eigen::MatrixXi>& x_levels_matrix, int num_levels_total, const Eigen::Map<Eigen::VectorXd>& weights, double p_best, double prob_T) {
	edi_rng::RRng rng = rrng_from_live_r_state();
	Eigen::VectorXi result;
	try {
		result = pocock_simon_redraw_w_internal(x_levels_matrix, num_levels_total, weights, p_best, prob_T, rng);
	} catch (const std::invalid_argument& e) {
		stop(e.what());
	}
	write_rrng_state_to_r(rng);
	return result;
}
#endif // EDI_CORE_ONLY
