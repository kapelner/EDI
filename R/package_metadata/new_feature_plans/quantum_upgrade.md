# Potential Quantum Computing Targets

> **Depends on:** gated decision (TODO-1 below); `../finished_features/design_fixed_optimal.md`
> (the `DesignFixedOptimal` solver stack — MILP + annealing — is the one place in the
> package whose problem is *natively* a quantum-hardware input); shares the
> "optional external backend / dispatch policy" question with `gpu_optimizations.md`
> (TODO-7 there) and should reuse whatever answer that plan records. (Global ordering:
> see `_master.md`, Phase 6.)

Date: 2026-08-22 (§I.7 hardware-detection/fallback spec and TODO-9..12 added 2026-08-23; **amended the same day, user decision: no Python / `reticulate` anywhere — every backend is reached from R directly (REST) or via vendored open-source C++**; earlier mentions of `reticulate`/`dimod`/`neal` in I.1/I.4/I.5/I.6 are superseded by §I.7 and carry an "amended" note)

Release line: **v1.1.0** — `../future_release_plans/release_v1_1_0.md → TODO-9b` (Part I items TODO-2..6 and TODO-9..12; gated on TODO-1, Phase 0 step 9b there). TODOs are ticked here.

## Scope

This report lists every place in EDI where a known quantum algorithm maps onto the
computation the package actually does, ranks them by how plausible a speedup is, and
proposes a minimal, optional integration path. It is a scoping document, not a
commitment: as of this writing there is no fault-tolerant quantum computer, and the only
quantum hardware that runs problems at EDI-relevant sizes today is **quantum annealers /
Ising machines** for QUBO (quadratic unconstrained binary optimization). Everything that
needs a coherent oracle over a superposition of allocations or bootstrap replicates
(Grover, amplitude estimation, HHL) is a fault-tolerant-era item and is recorded here so
the mapping is not rediscovered later, not because it can ship.

The honest headline is the same one `gpu_optimizations.md` reached for GPUs, only more
so: **the individual model fits are not the target.** EDI's fits are small-`p`,
moderate-`n` likelihood optimizations where a C++ L-BFGS/Newton/IRLS call takes
microseconds to milliseconds. No quantum algorithm helps those. What *does* map cleanly
onto quantum primitives is

1. the **binary-allocation search problems** in the design layer — `w ∈ {0,1}^n`,
   `Σ w = n_T`, minimize a quadratic/L1/ratio imbalance objective — which are QUBOs
   with a cardinality constraint, and
2. the **Monte Carlo replicate loops** in the inference layer — randomization
   distributions, bootstrap distributions, simulation-study power/coverage estimates —
   which are exactly the amplitude-estimation setting (quadratic speedup in `1/ε`).

Three standing caveats apply to every candidate below and are not repeated per item:

- **Data loading / QRAM.** Every "exponential speedup" claim in the quantum linear
  algebra literature assumes the input is already a quantum state. EDI's inputs are
  dense `n × p` matrices in R memory; loading them costs `O(np)`, which is the entire
  classical cost of most kernels here.
- **Readout.** HHL-style algorithms return `|β⟩`, not `β`. Extracting `p` coefficients
  to `1e-8` costs `O(p/ε²)` measurements, which erases the speedup for EDI's `p ≤ 100`.
- **Dequantization** (Tang 2019 and successors). Low-rank quantum linear-algebra
  speedups have classical sample-based analogues; EDI's matrices are low-rank only
  trivially (`p ≪ n`), which is exactly the regime classical methods already handle.

So: the realistic deliverable is an **optional QUBO export + external-sampler hook for
`DesignFixedOptimal`** (and, second, `DesignFixedOptimalBlocks` with block size > 2),
benchmarked honestly against the existing GLPK MILP and C++ simulated annealing. The
rest of this file is the map.

**Layout (2026-08-22, user request).** The report is split into two parts. **Part I**
lists what can run on hardware that exists today (quantum annealers / Ising machines
for QUBO, plus commercially available QRNGs). **Part II** lists what cannot, and for
every such upgrade states the qubits it would need — logical (error-corrected) qubits
as the primary figure, with the physical-qubit multiplier and circuit-depth caveat
stated once in its conventions section — so the next reader can judge, against
whatever hardware roadmap is current when they read this, how far off each item is.

# Part I — What is possible with current hardware

Current hardware, for this purpose, means: **quantum annealers** (D-Wave Advantage /
Advantage2 and their hybrid solvers) and the classical Ising-machine family that
takes the same QUBO input; **gate-model NISQ devices** (~100–1,000 noisy physical
qubits) only as a research comparison point for QAOA on the same QUBOs; and
commercial **QRNG** devices. None of these run Grover/amplitude-estimation/HHL-style
algorithms at any useful size — everything that needs those is in Part II.

**Hardware naming convention (Part I).** Every item below names the exact device
class, the access path, and the size limit that binds for that item. Figures are as of
this writing (2026-08) and should be re-checked against vendor documentation before any
benchmark; the *structure* of the requirement (dense `n`-clique embedding, hybrid
decomposition, all-to-all gate connectivity, etc.) is what matters and is stable.

## I.1 Tier A — Binary allocation search (QUBO / Ising; runnable on today's annealers)

### A1. `DesignFixedOptimal` single-allocation solver — the primary target

Relevant code:

- `EDI/R/helper_optimal_annealing.R:117-176` — `optimal_solve_auto()`, the dispatcher:
  `kind ∈ {"quadratic", "l1", "ratio", "custom"}`; exact `ompr`/ROI MILP when
  `n ≤ linearization_max_n`, C++ simulated annealing otherwise.
- `EDI/R/helper_optimal_milp_solvers.R:1-30` — `milp_solve_quadratic()` (product
  linearization `y_ij = w_i w_j`), `milp_solve_l1()`, `milp_solve_A_dinkelbach()`; the
  GLPK cliff documented at lines 24-30: `n = 15 → 0.4s, n = 20 → 3.5s, n = 25 → 311s`,
  hence `EDI_OPTIMAL_DEFAULT_LINEARIZATION_MAX_N = 20L`.
- `EDI/src/design_optimal_annealing_search.cpp:132` — `annealing_design_search_cpp()`:
  Metropolis single-exchange neighborhood, geometric cooling, `n_chains` BCRD-started
  chains, certificate `"annealing_converged"` (never `"global"`).
- `EDI/R/design_fixed_optimal.R` — the R6 class that owns `solver`, `roi_solver`,
  `linearization_max_n`, and the certificate field.

Why this is the one genuine quantum target in the package:

- The `"quadratic"` objective `min_w w'Qw` subject to `Σ w = n_T`, `w ∈ {0,1}^n`
  (`mahal_dist`, and the D-optimal `w'Pw`) **is already a QUBO** once the cardinality
  constraint is folded in as a penalty: `w'Qw + λ (1'w − n_T)²`. No reformulation
  beyond choosing `λ`; `Q` is dense `n × n`, which is the input format of every annealer
  SDK (`dimod.BinaryQuadraticModel`, Fujitsu DA, Toshiba SBM, Qiskit `QuadraticProgram`).
- The package's own solver stack hits an exact-solve wall at `n ≈ 20-25` and falls back
  to heuristic annealing with a downgraded certificate. That gap — "certified optimum
  is out of reach, all we have is annealing" — is precisely what quantum annealing and
  QAOA are marketed for. It is the honest comparison point: **quantum annealer samples
  vs. our own C++ simulated annealing samples**, both heuristic, judged on objective
  value achieved per unit wall-clock and per dollar.
- The `"ratio"` (A-optimal) objective is handled by Dinkelbach iteration
  (`milp_solve_A_dinkelbach()`, `helper_optimal_milp_solvers.R:175-207`), i.e. a
  sequence of quadratic subproblems `min w'Hw + 1 − q (n_T − w'Pw)` — each one a QUBO
  with the same penalty. The Dinkelbach outer loop stays classical.
- The `"l1"` objective `min Σ_j |(A w)_j|` is **not** directly a QUBO (absolute value
  of a linear form). Options: (i) square it (`Σ_j (A w)_j²` = quadratic, a *different*
  objective, so not a drop-in), or (ii) slack-variable linearization with binary-expanded
  slacks, which multiplies qubit count by the bit-width. Treat L1 as out of scope for a
  first pass; its MILP is already fast (it is linear, no product terms).
- `"custom"` objectives (`custom_objective_xptr`, user compiled C++) are not expressible
  as QUBOs at all. Out of scope.

Hardware reality check (sizes matter here). Qubit requirement: **`n` binary variables,
fully connected** (dense `Q`), so the binding figure is the largest clique the device
embeds, not its raw qubit count:

- D-Wave Advantage (Pegasus, ~5,000 qubits, degree 15) embeds a fully connected `n`-node
  problem only up to `n ≈ 180`; Zephyr/Advantage2 raises this somewhat. EDI's dense `Q`
  means every pair is coupled, so the embedding cost is the binding constraint, not the
  raw qubit count. Above that, D-Wave's hybrid CQM/BQM solvers decompose classically
  — i.e. they are a classical decomposition heuristic with QPU subcalls, and should be
  benchmarked as such.
- Gate-model QAOA (Qiskit, PennyLane, Braket) at depth `p` small on ~100-qubit noisy
  devices does not currently beat classical SA on dense QUBOs; it is a research
  comparison, not a production path. Record it, do not build for it.
- Queue latency and cost: a single QPU call is seconds of wall-clock end to end and is
  billed per QPU-access-second. `annealing_design_search_cpp()` with the defaults
  (`n_chains = 4`, `max_iter = 20000`) runs in milliseconds at `n = 100`. **Expect no
  wall-clock win at any `n` EDI users actually run** (tens to low hundreds of subjects).
  The only defensible claim to test is *solution quality at fixed wall-clock* on hard,
  frustrated `Q` instances, and "the annealing certificate can carry a second opinion."

Concrete integration (what the code change actually is — small):

- Add `solver = "qubo"` to `optimal_solve_auto()` / `DesignFixedOptimal`, alongside
  `"ompr"` and `"annealing"`. Inside, a new non-exported `qubo_build_quadratic(Q, n_T,
  lambda = NULL)` returns the penalized `n × n` upper-triangular matrix plus the
  calibrated `λ` (a safe default: `λ > max_i Σ_j |Q_ij|`, which makes any
  cardinality-violating state strictly worse than the best feasible one; document the
  bound, lock it by brute-force enumeration at `n ≤ 12` exactly as
  `tests/testthat/test-design-optimal-milp-solvers.R` does for the MILP).
- The *sampling* is delegated to a user-supplied R function `qubo_sampler = function(Q_pen)
  -> integer matrix of candidate w's` (same shape contract as the annealing kernel's
  per-chain bests). EDI never depends on a quantum SDK; the vignette shows the
  ~~`reticulate` → `dimod`/`dwave-system` (and `neal` / `dwave-samplers` simulated
  annealing as the no-hardware stand-in)~~ — *amended 2026-08-23:* a pure-R REST
  client for D-Wave's Solver API plus vendored C++ clique embedding; no Python
  (§I.7) — wiring. This mirrors how `roi_solver = "gurobi"`
  is documented but not imported (`design_fixed_optimal_blocks.R:46-104`).
- Post-process exactly as the annealing path does: recompute each returned candidate's
  objective from scratch, drop infeasible (`Σ w ≠ n_T`) samples — or repair them by the
  cheapest single flip — and return the argmin with certificate `"qubo_sampled"`.
- Dispatch policy: never automatic. `"qubo"` is opt-in only; `"auto"` keeps its current
  MILP-then-annealing behavior. (Same stance as the GPU plan: optional backend, CPU path
  is the default and the fallback.)

**Hardware required (A1).**

- *Primary — quantum annealer, direct QPU:* **D-Wave Advantage** (Pegasus P16
  topology, ~5,000 qubits, qubit degree 15) or **D-Wave Advantage2** (Zephyr
  topology, ~4,400 qubits, degree 20; generally available 2025). Accessed only through
  **D-Wave Leap** (cloud; `dwave-ocean-sdk`: `dimod`, `dwave-system`'s `DWaveSampler` /
  `DWaveCliqueSampler`, `minorminer` for embedding) — Amazon Braket dropped D-Wave
  devices in 2022, so Leap is the sole access path. The binding limit is the **largest
  fully-connected clique the device embeds**: ≈ 177 variables on Advantage (each
  logical variable becomes a chain of ~17 physical qubits), somewhat more on Advantage2
  (verify the current `DWaveCliqueSampler` clique size). So direct-QPU A1 covers
  `n ≲ 170` subjects on Advantage. Two device-specific caveats that matter for EDI's
  dense `Q`: (i) coupler precision is limited (`J` programmed in `[−1, 1]` with roughly
  two significant digits of effective precision after ICE/analog noise), and the
  cardinality penalty `λ(1'w − n_T)²` *adds* `λ` to every coupler, which compresses the
  dynamic range of `Q` itself — expect quantization of small `Q_ij` differences;
  (ii) chain breaks on 17-qubit chains at strong penalties; chain strength must be
  tuned per instance.
- *Larger `n` — hybrid solvers:* **D-Wave Leap Hybrid BQM / CQM solvers**
  (`LeapHybridSampler`, `LeapHybridCQMSampler`), classical cloud decomposition with QPU
  sub-calls, up to ~10⁶ variables. The CQM solver takes `Σ w = n_T` as an explicit
  constraint (no penalty, no dynamic-range loss), which makes it the better A1 target
  above the clique limit. These must be benchmarked as classical-with-QPU-assist, not
  as "quantum."
- *Research comparison only — gate-model QAOA:* dense `Q` wants all-to-all
  connectivity, so the relevant devices are the **trapped-ion** machines:
  **Quantinuum H2** (56 qubits, all-to-all) / **Helios** (98 qubits, 2025) via
  Azure Quantum or Quantinuum directly, and **IonQ Forte / Tempo** (36+ algorithmic
  qubits, all-to-all) via Amazon Braket or Azure Quantum. Superconducting devices —
  **IBM Heron** (133–156 qubits, heavy-hex, via Qiskit Runtime), **Rigetti Ankaa-3**
  (84 qubits, via Braket) — need SWAP routing for a dense `Q` and lose coherence
  before the QAOA circuit at useful depth finishes. Practical ceiling: `n ≲ 50`
  subjects, depth-1–2 QAOA, no expectation of beating classical SA. Neutral-atom
  analog devices (**QuEra Aquila**, 256 atoms, via Braket; **Pasqal**) natively solve
  unit-disk maximum-independent-set, not dense QUBO, and are not suitable.
- *Software on the EDI side (amended 2026-08-23):* **no Python.** An R-native client
  for the D-Wave Solver API (REST; `httr2` + `jsonlite`, both Suggests), an R
  serializer for dimod's documented BQM/CQM file formats (hybrid-solver uploads), and
  the clique-embedding routine from `minorminer` (`busclique`, Apache-2.0 C++)
  vendored into `src/` with attribution in `inst/COPYRIGHTS`. The Ocean SDK is used as
  the *specification* of these three pieces, never imported. Details in §I.7.

### A2. Greedy D-/A-optimal and pair-switch *distributions* of local optima

Relevant code:

- `EDI/src/optimal_design_search.cpp:132` (`d_optimal_search_cpp`), `:175`
  (`a_optimal_search_cpp`), both routed through `greedy_pairwise_swap_engine.h`.
- `EDI/src/design_fixed_greedy.cpp:49` (`greedy_design_search_cpp`, incl. the
  pair-constrained mode used by `design_fixed_matching_greedy_pair_switching.R:194`).
- `EDI/R/design_fixed_greedy.R`, `design_fixed_greedy_d_optimal.R`.

Why it is tempting: these kernels produce `r` independent local optima (one per
BCRD start) and that *distribution* of allocations is the reference distribution for
randomization inference. A quantum annealer returns a *sample* of low-energy states per
call — a natural replacement for "run greedy from `r` random starts."

Why it is **not** a drop-in and should stay second-wave:

- Randomization inference requires the observed allocation and the reference draws to
  come from the *same* distribution. Replacing greedy-local-optima draws with annealer
  draws changes the design's allocation distribution; it is a new design class, not a
  backend swap (and it would have to be a new `DesignFixed*` class with its own
  `generate_permutations_*` equivalent, so the null distribution is drawn the same way).
- The greedy engine already has algorithmic pruning (sorted-scan bounds, the
  `prune_threshold()` logic at `optimal_design_search.cpp:1-60`) that makes each
  local search cheap; the perf audit (`performance_profiling_and_upgrades.md:142`) calls it "a
  data-access and algorithmic-structure problem," not an arithmetic one.
- Annealer samples are not i.i.d. and their distribution depends on chain strength,
  annealing schedule, and device calibration — poor properties for something whose job
  is to be a well-defined randomization distribution.

Recommendation: do not pursue until A1 has produced a benchmark. If pursued, it is a
*new design class* (`DesignFixedQuboSampled` or similar), not a change to the greedy
classes. **Expanded (2026-08-22) into
`../new_research_ideas/quantum_greedy_design.md`**, which frames the class as the
Gibbs (maximum-entropy) design `π_β(w) ∝ exp(−β f(w))` over balanced allocations,
explains why a better optimizer should be used to *sample the low-imbalance region*
rather than to reach the optimum, and why pairwise switching survives as the sampler's
move set and the "nearly random" metric.

**Hardware required (A2).** Identical to A1's direct-QPU path — **D-Wave
Advantage / Advantage2 via Leap**, `n ≲ 170` (clique limit) — because A2 needs the
device to act as a *sampler*, which the hybrid solvers do not expose (they return a
best solution, not a distribution). It additionally needs: many reads per call
(`num_reads` up to 10⁴ on a single anneal program), control of the anneal schedule
(`annealing_time`, pause/quench, and **reverse annealing** from a supplied state — all
available on Advantage-class QPUs), and an *estimate* of the device's effective inverse
temperature for the instance (Raymond et al. 2016 / Benedetti et al. 2016 methods),
since the Gibbs `β` is not a programmable parameter. The fair-sampling bias of
transverse-field annealers is the open question; see
`../new_research_ideas/quantum_greedy_design.md` §5. No gate-model device is relevant
here (QAOA does not produce a controlled Boltzmann sample at any accessible depth).

### A3. `DesignFixedOptimalBlocks` (block size `k > 2`) and `DesignFixedBinaryMatch`

Relevant code:

- `EDI/R/design_fixed_optimal_blocks.R:25-60` — `method ∈ {"greedy" (blockTools),
  "ompr" (GLPK MILP, "globally optimal but scaling as …")}`; distance kernels in
  `EDI/src/optimal_blocks_distance.cpp:152-228`.
- `EDI/R/helper_matching.R:38` and `design_fixed_binary_match.R:24-26` —
  `nbpMatching::nonbimatch()` minimum-weight non-bipartite perfect matching.
- `EDI/src/pair_dist_helpers.cpp:56` — `compute_pair_distance_matrix_cpp()`.

Assessment:

- **Pairs (`k = 2`) — no quantum candidate.** Minimum-weight perfect matching is
  polynomial (Edmonds' blossom, `O(n³)`); `nbpMatching` solves EDI-sized instances
  instantly. Nothing to gain, and a QUBO formulation would be strictly worse.
- **Blocks `k ≥ 3`** — minimum-within-block-distance `k`-partitioning is NP-hard and
  has a standard QUBO encoding (`x_{i,b} = 1` if unit `i` in block `b`; one-hot
  penalties per unit, cardinality penalty per block). Qubit requirement is `n × (n/k)` binary variables, densely coupled, so
  `n = 60, k = 3` already needs 1,200 logical binaries with dense coupling — beyond
  direct embedding, hybrid-solver territory. The existing GLPK MILP hits the same wall
  the `DesignFixedOptimal` MILP does. This is a legitimate second QUBO target, after A1,
  reusing the same `qubo_sampler` hook.

**Hardware required (A3).** The `n × (n/k)` one-hot encoding exceeds the
direct-QPU clique limit almost immediately (`n = 24, k = 3` → 192 densely coupled
binaries > Advantage's ≈ 177), so A3 is a **Leap Hybrid CQM solver** item
(`LeapHybridCQMSampler`, which takes the per-unit one-hot and per-block cardinality
constraints natively) or, equivalently, any classical Ising machine / MILP backend. A
direct Advantage-class QPU is usable only as a toy at `n ≲ 20`. No gate-model device
applies.

## I.2 Quantum-inspired classical solvers (what is actually usable today)

Because the A1 hook is just "hand me a QUBO, give me back candidate `w`'s," the same
entry point serves the classical Ising-machine family, which is where any practical win
at `n` in the hundreds would come from: simulated bifurcation (Toshiba SBM), Fujitsu
Digital Annealer, D-Wave's `neal`/`dwave-samplers` simulated annealing and `tabu`
samplers, and parallel-tempering QUBO solvers. If A1's benchmark shows any of these beat
`annealing_design_search_cpp()` on objective-at-fixed-time, the right follow-up is
a better *classical* kernel (e.g. parallel tempering or SBM in C++ under the existing
OpenMP scaffolding), not hardware.

**Hardware required (I.2).** None beyond a CPU/GPU — that is the point. Concretely:
open-source samplers `neal` / `dwave-samplers` (simulated annealing, tabu, steepest
descent), `openjij`, and parallel-tempering implementations run on any machine and
plug into the same `qubo_sampler` hook; **Toshiba SQBM+** (simulated bifurcation) is
sold as software for GPUs via AWS Marketplace / Azure; **Fujitsu Digital Annealer** and
**NEC Vector Annealing** are cloud services on proprietary CMOS/vector hardware (up to
~10⁵ bits, dense coupling, no embedding step); **Hitachi CMOS annealing** similarly.
All accept the same dense-`Q` input A1 produces.

## I.3 Tier D — QRNG as a randomness source — possible today, not a speedup, and rejected

`EDI/src/fast_shuffle.cpp`, `fast_sample_int.cpp:102-109`,
`exchangeable_resampling_draws.cpp`, `generate_permutations.cpp`, and the per-thread
`edi_rng::RRng` seeding everywhere. Hardware QRNGs are commercially available today (so this belongs in Part I), but a QRNG (or any hardware entropy source) would
break `set.seed()` reproducibility, which the package guarantees independent of thread
count (see the seeding comments in `design_optimal_annealing_search.cpp:26-30` and
`optimal_design_search.cpp:20-23`). **Do not.**

**Hardware required (I.3).** Commercial QRNG products: **ID Quantique Quantis**
(PCIe/USB cards and appliances), **Quantinuum Quantum Origin** (cloud service;
certified randomness seeded from an H-series QPU), the free **ANU QRNG** web API, and
the QRNG chips shipping in some consumer devices. All are available today; none is
wanted here for the reproducibility reason above.

## I.4 Suggested integration design (Part I items)

- **No hard dependency.** Nothing quantum enters `Imports`. `Suggests` gains only
  `httr2` (HTTP) — `jsonlite` is already there — and ~~`reticulate`~~ nothing Python
  (amended 2026-08-23). The hook is a plain R function argument.
- **Python side (amended 2026-08-23): none.** `python/src/edi_kernels` is untouched and
  no Python runtime is detected, initialised, or required; the open-source vendor
  SDKs (Ocean, openjij, Braket/Azure/Qiskit clients) are *not* used — their REST
  protocols and file formats are reimplemented in R, and the one non-trivial
  algorithmic piece (dense-clique minor embedding) is vendored as C++. If a
  `qubo_build_quadratic` helper is ever wanted on the Python side it is ~20 lines of
  numpy, not a kernel.
- **Certificates.** `"global"` (MILP) > `"annealing_converged"` > `"qubo_sampled"`. The
  annealer path never claims optimality. Store sampler metadata (backend name, number
  of reads, chain-break fraction if reported) in the result list for provenance.
- **Tests without hardware.** CI uses a deterministic classical sampler (the package's
  own `annealing_design_search_cpp()` under a fixed seed as the second opinion, plus a
  trivial in-R exhaustive sampler at `n ≤ 12`; ~~`neal` via `reticulate`~~ amended
  2026-08-23) and HTTP-mocked Solver-API fixtures (§I.7.4) so the
  QUBO construction, penalty calibration, feasibility repair, and certificate plumbing
  are locked; the hardware path is vignette-only.
- **Dispatch.** Opt-in only. Same posture as `gpu_optimizations.md`: the CPU path is the
  default, and "auto" never silently routes to an external sampler.

## I.5 Benchmarking plan (A1)

Compare, at `p = 5` with `mahal_dist` (`"quadratic"`) and the A-optimal `"ratio"`:

| `n` | GLPK MILP (`ompr`) | C++ SA (`annealing_design_search_cpp`) | classical Ising-service sampler (SQBM+ / Fujitsu DA via REST; ~~`neal`~~) | D-Wave hybrid BQM | D-Wave QPU direct |
|---:|---|---|---|---|---|
| 15 | exact, 0.4 s | — | — | — | — |
| 20 | exact, 3.5 s | objective gap vs. exact | gap | gap, latency, $ | gap, embedding ok |
| 50 | (infeasible) | reference | gap / time | gap, latency, $ | gap, embedding ok |
| 100 | — | reference | gap / time | gap, latency, $ | embedding marginal |
| 200 | — | reference | gap / time | gap, latency, $ | not embeddable |

Report per cell: best objective, wall-clock including queue/transfer, monetary cost,
and fraction of returned samples that were feasible (`Σ w = n_T`) before repair. Use
`set.seed()`-reproducible `X` fixtures from `local_machine_tuning_synthetic_fixtures.R`
so the table is re-runnable. Success criterion for going beyond a vignette: a QUBO
backend must beat the C++ SA on objective at *equal wall-clock* on at least the
`n ≥ 50` rows; anything less stays a documented curiosity.

## I.6 Hardware required — Part I summary

| item | what runs | exact hardware | access path | binding limit |
|---|---|---|---|---|
| A1 `DesignFixedOptimal` QUBO, direct QPU | one allocation, heuristic certificate | D-Wave Advantage (Pegasus, ~5k qubits) / Advantage2 (Zephyr, ~4.4k) | D-Wave Leap Solver API (REST) from R; clique embedding via vendored `minorminer` `busclique` C++ — no Python (amended 2026-08-23) | dense clique embedding ≈ 177 variables (Advantage) → `n ≲ 170`; coupler precision + penalty dynamic range |
| A1, larger `n` | same | Leap Hybrid BQM / CQM solvers (classical decomposition + QPU sub-calls) | D-Wave Leap | ~10⁶ variables; benchmark as classical-with-QPU-assist |
| A1, gate-model QAOA (research only — **no R adapter planned**; no R circuit builder exists, and the item has no expected win) | same | Quantinuum H2 (56) / Helios (98), IonQ Forte/Tempo (all-to-all ions); IBM Heron, Rigetti Ankaa-3 (need SWAP routing) | Azure Quantum, Amazon Braket, Qiskit Runtime | `n ≲ 50`, depth 1–2; no expected win |
| A2 annealer-sampled allocation distributions | a *distribution* of allocations | D-Wave Advantage / Advantage2 direct QPU with `num_reads`, anneal-schedule and reverse-anneal control | D-Wave Leap | same clique limit; `β_eff` must be estimated; fair-sampling bias open |
| A3 `DesignFixedOptimalBlocks` `k ≥ 3` | one blocking | Leap Hybrid CQM solver (native one-hot / cardinality constraints); direct QPU only for `n ≲ 20` | D-Wave Leap | `n·(n/k)` densely coupled binaries |
| I.2 quantum-inspired classical solvers | same QUBOs as A1/A3 | any CPU: EDI's own C++ SA (`annealing_design_search_cpp`, and a parallel-tempering/SBM kernel if TODO-5 motivates one) — ~~`neal`/`openjij`~~ not used (amended 2026-08-23); Toshiba SQBM+ (GPU software), Fujitsu Digital Annealer, NEC Vector Annealing, Hitachi CMOS annealing (cloud) | in-package / AWS Marketplace / vendor cloud, all via REST from R | none that binds at EDI sizes |
| I.3 QRNG | randomness source | ID Quantique Quantis, Quantinuum Quantum Origin, ANU QRNG API | local device / cloud API | n/a — rejected for reproducibility |

Not applicable to any Part I item: neutral-atom analog machines (QuEra Aquila, Pasqal)
— native problem class is unit-disk MIS, not dense QUBO; photonic boson samplers;
research-only superconducting devices without cloud access (e.g. Google Willow).

## I.7 Hardware by implementable proposal — detection and classical fallback, pure R (added 2026-08-23, user request; amended the same day: no Python)

I.6 says which hardware each Part I item *uses*; this section fixes, per proposal, how the package **detects** that hardware/backend at run time and what it **falls back to** when it is absent, unreachable, too small, or too slow — and, per the 2026-08-23 decision, does so **without Python or `reticulate`**: every backend is reached from R directly over its documented REST API, and the one algorithmic component that has no R implementation (dense-clique minor embedding for the direct QPU) is vendored from Apache-2.0 C++ into `src/`. Nothing here changes the posture in I.4: the classical path (`ompr`/ROI MILP for `n ≤ linearization_max_n`, else `annealing_design_search_cpp()`) stays the default, and no external backend is ever selected silently.

### I.7.0 What "directly from R" means, component by component

| component | open-source reference (license) | how EDI uses it | size / effort |
|---|---|---|---|
| D-Wave Solver API (SAPI) client — list solvers, upload/submit problems, poll/cancel, answer decoding | `dwave-cloud-client` (Apache-2.0) as the *specification*; SAPI REST is vendor-documented | **reimplemented in R** with `httr2` + `jsonlite` (Suggests): `GET {endpoint}/solvers/remote/`, `POST {endpoint}/problems/`, `GET {endpoint}/problems/{id}/`, multipart upload for hybrid problems; token from `DWAVE_API_TOKEN` or the Ocean config file (`~/.config/dwave/dwave.conf`, INI — parsed with base R, so users who already ran `dwave config create` work unchanged) | a few hundred lines of R |
| dimod BQM / CQM file formats (what the Leap **hybrid** solvers accept as upload) | `dimod` `BinaryQuadraticModel.to_file()` / `ConstrainedQuadraticModel.to_file()` (Apache-2.0), format documented in dimod | **R serializer** writing the documented header + binary blocks (`raw` vectors); round-trip fixtures checked in (§I.7.4) | ~200 lines of R; CQM only if A3 proceeds |
| dense-clique minor embedding on Pegasus / Zephyr working graphs (what the **direct QPU** needs; hybrid solvers do not) | `minorminer` `busclique` (Apache-2.0, C++ header-heavy) | **vendored C++** under `src/` in its own unity-build group, attribution in `inst/COPYRIGHTS` and `Authors@R` (`cph` D-Wave Systems Inc.); compiled once like every other kernel; general `find_embedding` is *not* vendored (dense `Q` is always a clique) | a few thousand lines of C++; the only non-trivial piece |
| chain strength + unembedding | `dwave-system` `uniform_torque_compensation`, majority-vote unembed (Apache-2.0) | **reimplemented** (a formula and a vote) in R/C++ | trivial |
| Leap hybrid BQM / CQM solvers | SAPI-documented problem types | same R client; no embedding | covered above |
| Cloud Ising services: Toshiba SQBM+, Fujitsu Digital Annealer, NEC Vector Annealing | proprietary services with vendor-documented REST APIs (their Python clients are **not** open source and are not needed) | R REST adapters (`httr2`), endpoint + API key from env vars | ~100 lines each; implement only those a user actually asks for |
| local classical sampler | — | EDI's own `annealing_design_search_cpp()` (terminal fallback); a parallel-tempering / SBM kernel in EDI C++ if TODO-5 motivates it. `neal`/`openjij` are not used. | already exists |
| gate-model QAOA (Braket / Azure / Qiskit) | open clients exist, but no R circuit builder | **no adapter** — dropped from the implementable set; Part I keeps it as a research note only | — |

Licensing: EDI is GPL-3; Apache-2.0 code may be included in a GPL-3 work (one-way compatible) with the Apache NOTICE/attribution preserved — same mechanism as the package's existing `inst/COPYRIGHTS`.

### I.7.1 Proposal → hardware → detection → fallback

| (I) proposal | hardware actually used (from I.6) | detected how (offline-first; `probe = TRUE` adds one HTTPS call) | fallback when absent / unusable |
|---|---|---|---|
| **A1 direct QPU** — one allocation, `n ≲ 170` dense | D-Wave Advantage / Advantage2 via Leap SAPI; embedding computed locally (vendored `busclique`) | (1) `requireNamespace("httr2")`; (2) credentials *configured*: `DWAVE_API_TOKEN` env var **or** `dwave.conf` present (also honours `DWAVE_CONFIG_FILE`, `DWAVE_API_ENDPOINT`, `DWAVE_API_SOLVER`) — presence only, no call; (3) `probe = TRUE`: `GET /solvers/remote/` → QPU solvers with `properties` (topology type/shape, active qubits, couplers); EDI then runs `busclique` on that working graph to get `largest_clique_size` — the binding `n` limit for dense `Q` (cached per solver for the session) | `n > largest_clique_size`, embedding failure, or penalty dynamic range exceeded → **A1 hybrid** if configured, else **cloud Ising service** if configured, else **classical SA** (`annealing_design_search_cpp`, certificate `"annealing_converged"`). Not configured → same chain skipping the QPU. Always a `warning()` naming requested backend, backend used, reason; never silent. |
| **A1 hybrid** — larger `n` | Leap Hybrid BQM (`hybrid_binary_quadratic_model_version*`) | same (1)–(2); `probe = TRUE`: hybrid solvers listed with `maximum_number_of_variables`; upload is the R BQM serializer | unavailable → cloud Ising → classical SA; also subject to the time/cost guard. |
| **A1 gate-model QAOA** | — | not detected | **not implemented** (no R adapter); naming it errors with a pointer to this section. |
| **A2** annealer-sampled allocation *distribution* | D-Wave direct QPU with `num_reads`, schedule, reverse-anneal control | as A1 direct QPU plus a check that the solver's `properties` expose `annealing_time_range` / reverse-anneal support | **no** classical equivalent yields the same distribution; if unavailable the design class must **refuse** (error, not fallback). (A2 is not scheduled; the rule is fixed here.) |
| **A3** `DesignFixedOptimalBlocks`, `k ≥ 3` | Leap Hybrid CQM (`hybrid_constrained_quadratic_model_version*`); direct QPU only `n ≲ 20` | as A1 hybrid; `probe = TRUE` confirms a CQM solver is listed; upload is the R CQM serializer | → classical: existing blocks solver (MILP small `n`, SA otherwise), warning. |
| **I.2** quantum-inspired classical / Ising services | EDI C++ SA (local, always present); SQBM+ / Fujitsu DA / NEC VA (cloud, REST) | local: always available, no detection; cloud: `SQBM_ENDPOINT`+`SQBM_API_KEY`, `FUJITSU_DA_ENDPOINT`+`FUJITSU_DA_API_KEY`, `NEC_VA_ENDPOINT`+`NEC_VA_API_KEY` — configured-only unless probed (`GET` status endpoint) | cloud missing → classical SA (warning). These are the fallback targets for everything above. |
| **I.3** QRNG | IDQ Quantis, Quantinuum Quantum Origin, ANU API | not detected — rejected (reproducibility) | n/a |

### I.7.2 Detection helper (spec)

One exported helper, mirroring the style of the existing `roi_solver` wiring guides in `design_fixed_optimal.R`/`design_fixed_optimal_blocks.R`:

```r
detect_qubo_backends(probe = FALSE, cache = TRUE, timeout = 10)
#> data.frame: backend, kind, installed, configured, reachable, capability, reason, detected_via
```

- `backend` ∈ `{"dwave_qpu", "dwave_hybrid_bqm", "dwave_hybrid_cqm", "sqbm", "fujitsu_da", "nec_va", "classical_sa"}`; `kind` ∈ `{"qpu", "hybrid", "cloud_classical", "local_classical"}`. (No Python-backed rows; no gate-model rows.)
- `installed`: `requireNamespace("httr2", quietly = TRUE)` for every remote backend (`jsonlite` is already a Suggests); `TRUE` unconditionally for `classical_sa`. The vendored embedding code is compiled into `EDI.so`, so `dwave_qpu` has no extra install condition.
- `configured`: credential/config presence by env var or config-file existence only (table above; the D-Wave INI is parsed with base R). No network.
- `reachable` / `capability`: `NA` unless `probe = TRUE`, in which case exactly one metadata request per *configured* remote backend with `timeout` seconds (`GET /solvers/remote/` for D-Wave, the status endpoint for the Ising services). `capability` carries the number the dispatcher needs: `largest_clique_size` (QPU — computed locally by `busclique` on the returned working graph), `maximum_number_of_variables` (hybrid / Ising services).
- `reason`: human-readable — `"httr2 not installed"`, `"DWAVE_API_TOKEN unset and no dwave.conf"`, `"solver offline"`, `"n = 240 > largest_clique_size = 177"`, …
- `cache = TRUE`: memoised per session (`options(EDI.qubo_backends_cache = …)`); probe results carry a timestamp and a 10-minute TTL. A `print()` method renders the table like `sessionInfo()` does for BLAS.
- **Injectable for tests**: `options(EDI.qubo_backends_override = <data.frame>)` replaces detection wholesale so CI can assert every fallback branch with no network and no token; the HTTP layer is additionally mockable (§I.7.4). Precedent: the `EDI_*` env-var switches already used by the class registries.

### I.7.3 Dispatch and fallback policy (spec)

New argument on `optimal_solve_auto()` / `DesignFixedOptimal$solver_args` (and `DesignFixedOptimalBlocks` for A3):

```r
qubo_backend = c("none", "auto", "dwave_qpu", "dwave_hybrid", "sqbm", "fujitsu_da", "nec_va", "custom")
```

- **Precedence**: explicit argument > `getOption("EDI.qubo_backend")` > `Sys.getenv("EDI_QUBO_BACKEND")` > `"none"`.
- **`"none"` (default)** — exactly today's behaviour (MILP → SA); no detection, no HTTP, no embedding code executed, results bit-for-bit identical to 1.0.0 (the release's additive rule).
- **`"auto"`** (opt-in) — the first backend that is installed, configured, and capable for this `n`: `dwave_qpu` (if `n ≤ largest_clique_size`) → `dwave_hybrid` → cloud Ising services in the order configured → **classical SA**. Every hop emits one `warning()` (`"qubo_backend = 'auto': dwave_qpu not usable (n = 240 > largest_clique_size = 177); using dwave_hybrid"`).
- **Named backend** — use it or fall back to classical SA **with a warning**; never substitute a *different* external backend for a named one (a user who asked for the QPU must not be billed for the hybrid solver). `"custom"` = the `qubo_sampler` R-function hook from A1 (user-supplied adapter, e.g. their own REST call; no detection).
- **Guards** (each → next hop with a stated reason): size (`n` vs `capability`); embedding failure or chain-strength / coupler-precision range exceeded; `max_qpu_time_s` and `max_cost_usd` options (conservative defaults; refuse *before* submitting if the estimate exceeds them); per-request HTTP timeout and poll deadline; any adapter exception.
- **Result provenance**: `certificate ∈ {"global", "annealing_converged", "qubo_sampled"}` plus `backend_requested`, `backend_used`, `fallback_reason` (`NA` if none), `solver_id`, `num_reads`, `chain_strength`, `chain_break_fraction`, `qpu_access_time`, `cost_estimate`. A fit that fell back to classical SA is labelled `"annealing_converged"` with `backend_used = "classical_sa"` — indistinguishable in *result* from a `qubo_backend = "none"` fit under the same seed, distinguishable in *provenance*.
- **Non-goals**: `tune_EDI_for_this_machine()` never benchmarks or selects remote backends (cost, network, non-reproducibility) — at most it records `detect_qubo_backends()` output. Shares the backend-registry shape and the "CPU default, never auto-route" rule with `gpu_optimizations.md → TODO-7`; whichever lands first sets the convention.

### I.7.4 Test plan for detection, serialization, embedding, and fallback (hardware-free)

- `detect_qubo_backends()` unit tests: `httr2` absent (`testthat::local_mocked_bindings(requireNamespace = …)`), configured-by-env vs configured-by-INI vs unconfigured (`withr::local_envvar`, temp `HOME`), `probe = FALSE` leaves `reachable = NA`; `probe = TRUE` against **mocked HTTP** (`httptest2`/`webfakes`, Suggests) with checked-in SAPI response fixtures (solver list with a small synthetic Pegasus working graph; problem submit/poll/answer sequences, including an "offline" and a "timeout" fixture).
- BQM/CQM serializer: byte-exact round-trip against fixture files generated once by dimod (fixtures checked in with the dimod version and a one-line provenance note; no Python in the test run).
- Vendored `busclique`: clique embedding found on the synthetic Pegasus/Zephyr fixture graphs, `largest_clique_size` matches the value recorded from minorminer for those fixtures, chains are disjoint and cover every variable, majority-vote unembedding recovers planted solutions.
- Dispatcher tests through `EDI.qubo_backends_override` and the HTTP mocks: every fallback row of I.7.1 exercised — warning text, `backend_used`, `fallback_reason`, and `w` equal to the `qubo_backend = "none"` result under the same seed when the last hop is classical SA; A2's refuse-don't-fallback rule; the named-backend-never-substitutes rule; the cost/time guards refusing before submission.
- Integration tests (never in CI): D-Wave hybrid and QPU only under `DWAVE_API_TOKEN` **and** `EDI_RUN_PAID_BACKEND_TESTS=true`; Ising services likewise under their keys.
- `n ≤ 12` exhaustive sampler (I.4) remains the deterministic stand-in for the QUBO-construction tests themselves.

# Part II — What is not possible with current hardware (and how many qubits each needs)

## II.0 How the qubit counts below are computed

Conventions used for every estimate in this part:

- `n` subjects, `p` covariates, `b` = fixed-point word width inside the coherent
  oracle (`b = 32` is enough for rank sums and counts; `b = 53` for parity with the
  package's double-precision kernels), `ε` = target additive accuracy of the estimated
  probability/amplitude, `k` = number of optimizer iterations when the oracle is a
  model refit.
- **Logical qubits** are the primary figure: error-corrected qubits on which the
  circuit actually runs. Counts are register sizes only (index/superposition register
  + accumulators + comparator + amplitude-estimation ancilla); they exclude the
  additional workspace that any concrete compilation adds (typically ×1.5–3).
- **Physical qubits** ≈ logical × 10³ under a surface code at ~10⁻³ physical error
  rate for the circuit depths involved (the standard Fowler-et-al.-style estimate);
  × ~10² if the more efficient qLDPC codes announced in the 2024–2025 roadmaps
  deliver. State one multiplier, not a per-item guess.
- **Depth matters as much as width.** Amplitude estimation's `O(1/ε)` Grover
  iterations are *sequential*; each contains one coherent evaluation of the oracle.
  So the circuit depth is `O(1/ε) × oracle depth`, and the oracle depth is `O(n)` for
  a linear statistic, `O(n²)` for a quadratic form, and `O(k · n · p²)`-ish for a
  Newton refit. A machine with enough qubits but not enough coherent depth still cannot
  run these.
- Amplitude-estimation ancilla: textbook QAE needs a phase register of
  `⌈log₂(1/ε)⌉ + 2` qubits (~9 at `ε = 0.01`); iterative / maximum-likelihood QAE
  (Suzuki et al. 2020; Grinko et al. 2021) needs one. Counts below use **one**.
- Uniform superposition over balanced allocations (`n choose n_T` strings of fixed
  weight) is a Dicke state: preparable on the `n` index qubits alone with `O(n · n_T)`
  gates and no extra qubits (Bärtschi & Eidenbenz 2019). Bootstrap index vectors need
  `n · ⌈log₂ n⌉` qubits (one `⌈log₂ n⌉`-bit index per draw); Bayesian-bootstrap
  Dirichlet weights need `n · b`.
- "Today" for comparison: the largest announced gate-model systems are ~10³ noisy
  physical qubits with, at most, tens of logical qubits demonstrated in 2025; no
  machine runs thousands of sequential logical-gate layers. Every line item below is
  therefore out of reach by at least two orders of magnitude in logical qubit count
  *and* in depth.

## II.1 `DesignFixedRerandomization` acceptance–rejection via amplitude amplification (was A4)

Relevant code:

- `EDI/src/rerandomization_helpers.cpp:179` — `rerandomization_search_cpp()`: draw
  balanced allocations, keep those with `M(w) ≤ cutoff`, error if `max_draws` is
  exhausted before `r` are accepted; R class `design_fixed_rerandomization.R` (two
  modes: `obj_val_cutoff` fixed threshold, `prop_acceptable` top-quantile).

Mapping: this is textbook rejection sampling with acceptance probability `p_a`, classical
cost `O(r / p_a)`. Amplitude amplification (Brassard–Høyer–Mosca–Tapp 2002) turns that
into `O(r / √p_a)` — exactly the regime where tight cutoffs currently make the search
error out. But the oracle must evaluate `M(w)` (a Mahalanobis/abs-sum-diff form over
`X`) *coherently* on a superposition of allocations, and the "balanced" constraint must
be prepared as a uniform superposition over `n choose n/2` states. Fault-tolerant only.
Record, do not build. (A classical fix — sampling from the acceptance region directly
via the top-quantile mode, which already exists — is the real answer today.)

**Qubits needed.** Index register `n` (Dicke state over balanced allocations) +
`M(w)` evaluation: `p` accumulators of `b` bits, a square/abs and sum accumulator, and
a comparator against `cutoff` — about `(p + 3) · b` — + 1 amplification ancilla:

| `n`, `p` | logical qubits (`b = 32`) | physical (×10³) | Grover iterations |
|---|---:|---:|---|
| 100, 5 | ≈ 100 + 256 ≈ **360** | ≈ 3.6 × 10⁵ | `O(1/√p_accept)` per accepted draw, each of depth `O(n p)` |
| 500, 10 | ≈ 500 + 416 ≈ **920** | ≈ 9 × 10⁵ | same |
| 1000, 20 | ≈ 1000 + 736 ≈ **1,750** | ≈ 1.8 × 10⁶ | same |

Compare: the classical search is `O(r / p_accept)` trivially parallel draws at
`O(np)` each — the quantum version is only interesting when `p_accept` is tiny, the
regime where the current code errors out on `max_draws`.

## II.2 Tier B — Monte Carlo replicate loops (quantum amplitude estimation)

**Revised 2026-08-22 after review** — the first draft filed this tier as a footnote. That
was too dismissive. The speedup here is real and provable; what is missing is hardware,
not an algorithm. This section now says exactly where it bites and what it needs.

### The mapping (and why it is stronger for EDI than for generic Monte Carlo)

Every item in this tier estimates `θ = E_ω[f(ω)]` over a *known, explicitly
samplable* distribution of replicates — uniform over a permutation group, uniform over
bootstrap index multisets, Dirichlet weights for the Bayesian bootstrap — to additive
accuracy `ε`. Classically that is `r = O(1/ε²)` replicates. Quantum amplitude estimation
(Brassard–Høyer–Mosca–Tapp 2002; Montanaro 2015, "Quantum speedup of Monte Carlo
methods") gets the same `ε` in `O(1/ε)` coherent evaluations of `f`, a strict quadratic
speedup in sample complexity with no structural assumption on `f` beyond being
computable.

Three things make the randomization/bootstrap case unusually clean for QAE:

1. **The sampling distribution is trivially preparable.** A uniform superposition over
   permutations of a fixed `w` (or over `n^n` bootstrap index vectors, or over
   `n choose n_T` balanced allocations) is a standard state-preparation circuit — no
   QRAM, no amplitude encoding of data. The "data loading" caveat from the Scope section
   does **not** apply to the replicate distribution, only to `y`/`X`, which enter the
   oracle as classical constants.
2. **The p-value is literally an amplitude.** `p = P_w(|T(w)| ≥ |T_obs|)` is the
   probability of an indicator; QAE estimates it directly. No quantile, no density.
3. **For the linear-in-`w` statistics the oracle is a tiny arithmetic circuit.** The
   statistics EDI actually resamples split sharply:
   - *Cheap coherent oracle* (`T(w) = Σ_i c_i w_i` for fixed classical `c` given
     `y`, `δ`): the simple mean difference (`simple_mean_diff_parallel.cpp:15`,
     `rand_bootstrap_mean_diff_parallel.cpp:54`), Wilcoxon with `delta == 0`
     (pre-ranked fast path, `fast_wilcox_parallel.cpp:61`), ridit
     (`ridit_distr_parallel.cpp:102`), the KK compound statistic
     (`kk_compound_distr_parallel.cpp:15`) and, via Frisch–Waugh–Lovell, the OLS
     treatment coefficient with fixed covariates (`ols_distr_parallel.cpp:15`:
     `β_T(w) = w̃'y / w̃'w̃` with `w̃ = (I − H_X) w` — a quadratic form in `w`, still a
     small reversible circuit). Oracle cost `O(n)` gates, `O(n + log(1/ε))` qubits.
   - *Expensive coherent oracle* (the replicate is an iterative optimizer): every
     `fast_*_regression` refit under resampling, the GLMM/frailty engines, the Cox
     partial likelihood (`fast_coxph_regression.cpp:1140`), robust regression
     (`fast_robust_regression.cpp:413`), and the R-callback loops
     (`base_bootstrap_loop.cpp:12`, `kk_bootstrap_loop.cpp:22`). These *can* be made
     reversible (any classical computation can) but at a gate count of the whole
     Newton/L-BFGS run per oracle call; the `O(1/ε)` query count still wins
     asymptotically, but the constants are enormous and the circuit depth is far
     beyond any near-term error-corrected budget.

### Where the quadratic speedup actually matters (precision regime)

At EDI's defaults the win is modest: `r = 501` gives `SE(p̂) ≈ 0.01` near `α = 0.05`;
QAE reaches that in ~100 oracle calls. The speedup becomes decisive exactly where
classical resampling becomes painful:

- **Small p-values.** Resolving `p ≈ 10⁻⁴` to 10% relative accuracy needs
  `r ≈ 10⁶` permutations classically and `~10³` QAE queries. Multiple-testing
  corrections in `InferenceSuite` / many-endpoint runs push users into this regime.
- **CI inversion by bisection** — `compute_ci_by_inverting_the_randomization_test_iteratively()`
  (`inference_all_abstract_rand_ci.R:473-520`), `invert_rand_bootstrap_test_bisection()`
  (`inference_all_abstract_rand_bootstrap_ci.R:426-477`), and the native
  `bisection_ci_loop_cpp` / `bisection_ci_parallel_cpp` / `bisection_ci_single_bound_cpp`
  (`bisection_ci_loop.cpp:26`, `bisection_ci.cpp:29,99`). Each bisection step is a full
  `r`-draw p-value at a candidate `δ`, and the stopping rule `pval_span <= tol` needs
  `p(δ)` resolved to `tol` *near* `α/2`, so the per-step `r` must scale like `1/tol²`.
  Total classical cost is `O(log(range/tol) · 1/tol²)`; with QAE per step it is
  `O(log(range/tol) · 1/tol)`. The bisection logic itself stays classical and unchanged
  — QAE is a drop-in for `evaluate_pval(δ)` / `pval_fn(δ)`. (There is no additional
  win from Grover over a `δ` grid: `√G` loses to bisection's `log G` because `p(δ)` is
  monotone.) This is the single best fault-tolerant-era target in the inference layer,
  because it compounds the per-evaluation speedup across every bisection step *and*
  across both bounds.
- **Bootstrap quantiles / percentile CIs** — a bootstrap quantile is a binary search
  over amplitudes `P_b(θ̂_b ≤ q)`, each of which QAE estimates in `O(1/ε)`; same
  compounding structure as the bisection CI.

Note also the shift statistic is `T(w; δ)` with `y_sim = y ∓ δ w`
(`simple_mean_diff_parallel.cpp:46`, `ols_distr_parallel.cpp`), so across bisection
steps only a classical constant in the oracle changes — the state-preparation and
the amplitude-estimation circuit are reused verbatim.

### Why it is still not buildable now

- The oracle must be evaluated *coherently* on a superposition of `w`, which means a
  reversible arithmetic circuit on `n` index qubits plus ancillas, run `O(1/ε)` times
  in series (QAE's iterations are sequential, not parallel), so circuit depth is
  `O(n/ε)` at minimum. For `n = 500, ε = 0.01` that is ~10⁵ sequential
  logical-gate layers — fault-tolerant territory. Publicly announced roadmaps put
  useful logical-qubit counts (hundreds to thousands) and that depth at the end of this
  decade at the earliest; nothing that exists today (noisy ~100–1000 physical qubits,
  first few logical qubits) runs this at any `n` EDI cares about.
- It trades an embarrassingly parallel classical loop (already OpenMP / fork-cluster
  parallel across `r`) for a *sequential* quantum one; the fair classical baseline is
  `r` replicates on `C` cores, i.e. the quantum advantage is `√r / C` in wall-clock, not
  `√r`. With `C = 32` cores and `r = 10⁴`, that is ~3×, not 100×. The speedup is clear
  only once `1/ε²` dwarfs the core count — the small-`p` / tight-`tol` regime above.
- No NISQ shortcut exists here: there is no variational or annealing analogue of
  amplitude estimation that preserves the `1/ε` scaling, and the entire value is that
  scaling.

### What to do about it now (cheap, non-hardware)

The one action that costs almost nothing and preserves the option: keep the
linear-in-`w` statistics factored as "classical constant vector `c(y, δ)` + generic
`Σ c_i w_i` over replicates," which the parallel kernels already essentially do. That
factoring is what makes the oracle a small circuit later, and it is also what the GPU
plan wants. No new code is proposed for this tier in this plan; it is a design
constraint on future refactors of the resampling kernels, not a feature.

### B1. Randomization p-values and distributions — entry points

- `EDI/R/inference_all_abstract_rand.R:131` —
  `approximate_randomization_distribution_beta_hat_T()`; `:364` —
  `compute_rand_two_sided_pval()`; the CI variants in
  `inference_all_abstract_rand_ci.R` (bisection inversion, `:473`),
  `inference_all_abstract_quantile_rand_ci.R`,
  `inference_all_abstract_rand_bootstrap*.R` (bisection inversion, `_ci.R:426`).
- Native kernels: `EDI/src/randomization_loop.cpp:12`, `ols_distr_parallel.cpp:15`
  (`compute_ols_distr_parallel_cpp`), `fast_wilcox_parallel.cpp:61,134`,
  `fast_kk_wilcox_parallel.cpp`, `ridit_distr_parallel.cpp:102`,
  `kk_compound_distr_parallel.cpp:15`, `rand_bootstrap_ols_parallel.cpp:22`,
  `rand_bootstrap_mean_diff_parallel.cpp:54,133`, `simple_mean_diff_parallel.cpp:15`,
  `fast_coxph_regression.cpp:1140`, `fast_robust_regression.cpp:413`;
  bisection drivers `bisection_ci.cpp:29,99`, `bisection_ci_loop.cpp:26`.
- Reference-draw generators: `EDI/src/generate_permutations.cpp:442-530`
  (`generate_permutations_{matching,bernoulli,ibcrd,blocking,efron,atkinson,
  pocock_simon,cluster,spbr}_cpp`). Each of these is a classical description of the
  design's allocation distribution; the corresponding uniform-superposition state
  preparation is easy for Bernoulli/IBCRD/blocking/cluster/matching (product and
  fixed-weight states) and harder for the adaptive sequential designs (Efron,
  Atkinson, Pocock–Simon), whose allocation distribution is defined by a sequential
  process and would itself have to be run coherently.

The `delta == 0` pre-ranked Wilcoxon path (`fast_wilcox_parallel.cpp:61`) that the GPU
plan singled out is also the simplest conceivable QAE oracle (a rank-weighted sum over a
superposition of `w`) — if anyone ever wants a toy demonstration on a simulator, that is
the one.

**Qubits needed (B1).**

| oracle | logical qubits | `n = 100` | `n = 500` | `n = 1000` | depth per Grover iteration |
|---|---|---:|---:|---:|---|
| linear statistic `Σ c_i w_i` (mean diff, Wilcoxon `δ = 0`, ridit, KK compound) | `n + 2b + 1` | ≈ 165 (`b=32`) / 207 (`b=53`) | ≈ 565 / 607 | ≈ 1,065 / 1,107 | `O(n)` |
| OLS treatment coefficient via FWL (`w̃'y / w̃'w̃`, quadratic form + division) | `n + 4b + 1` | ≈ 230 / 313 | ≈ 630 / 713 | ≈ 1,130 / 1,213 | `O(n²)` |
| iterative refit per replicate (Cox, robust, GLM/GLMM, R-callback loops): `n` + `(p² + 2p) · b` Newton state × `O(log k)` pebbling + `n · b` linear predictor | `n + n·b + (p²+2p)·b·O(log k)` | ≈ 10⁴ (`p=10, b=53, k=20`) | ≈ 3–6 × 10⁴ | ≈ 6–10 × 10⁴ | `O(k · n · p²)` |

Multiply by 10³ for physical qubits. Sequential Grover iterations: `≈ 1/ε`, i.e.
~100 at `ε = 0.01`, ~10⁴ at `ε = 10⁻⁴` (the small-`p` regime where the speedup is
worth having). The bisection CI drivers (`bisection_ci*.cpp`,
`invert_rand_bootstrap_test_bisection()`, `compute_ci_by_inverting_the_randomization_test_iteratively()`)
need exactly the first two rows, once per bisection step, with only the classical
constant `c(y, δ)` changing between steps — no additional qubits.

### B2. Bootstrap distributions — entry points

- `EDI/src/base_bootstrap_loop.cpp:12`, `kk_bootstrap_loop.cpp:22` (R-callback loops —
  not even GPU-able as written, see the GPU plan; the estimator must be lifted into
  native code before the oracle question even arises), `ols_distr_parallel.cpp:112`
  (`compute_ols_bootstrap_parallel_cpp`), `kk_compound_distr_parallel.cpp:119`,
  `ridit_distr_parallel.cpp:167,234`,
  `sample_bootstrap_distr_weighted_distances.cpp:64`, `bootstrap_indices.cpp`,
  `bootstrap_match_indices.cpp`, `exchangeable_resampling_draws.cpp:233`.
- R: `inference_all_abstract_non_param_boot.R:188` (m-out-of-n), `_param_boot.R`,
  `_bayesian_bootstrap.R`, `_jackknife.R`, `helper_bootstrap_ci.R`.
- Same split as B1: bootstrap-of-a-linear-statistic (mean difference, OLS with FWL)
  has a cheap oracle; bootstrap-of-a-refit does not. The bootstrap *sampling* itself
  (drawing indices) is never the cost and gains nothing; the speedup is entirely in
  the number of replicates needed for a given `ε`.

**Qubits needed (B2).** The replicate register is the difference from B1: bootstrap
index vectors cost `n · ⌈log₂ n⌉` instead of `n`.

| variant | replicate register | + statistic oracle | `n = 100` | `n = 500` | `n = 1000` |
|---|---|---|---:|---:|---:|
| nonparametric bootstrap of a linear statistic | `n · ⌈log₂ n⌉` | `+ 2b + 1` | ≈ 770 | ≈ 4,570 | ≈ 10,070 |
| m-out-of-n bootstrap of a linear statistic | `m · ⌈log₂ n⌉` | `+ 2b + 1` | `7m + 65` (e.g. `m = 50`: ≈ 415) | `9m + 65` | `10m + 65` |
| Bayesian bootstrap (Dirichlet weights, `b` bits each) of a linear statistic | `n · b` | `+ 2b + 1` | ≈ 3,300 (`b=32`) | ≈ 16,100 | ≈ 32,100 |
| bootstrap of an iterative refit | `n · ⌈log₂ n⌉` | `+ ~10⁴–10⁵` (refit row of B1) | ≈ 10⁴ | ≈ 4–7 × 10⁴ | ≈ 7–11 × 10⁴ |

Physical ≈ ×10³. The Bayesian bootstrap and the refit rows are in "nobody will ever
build this for a statistics package" territory; the first row is the only one worth
carrying in the summary table.

### B3. Simulation framework (power / coverage / bias)

- `EDI/R/simulations_framework.R` — the Monte Carlo replication engine (fork /
  `mirai` rep-level parallelism around lines 1251-1628); `simulation_framework_report.R`.
- A rejection rate or coverage probability is a Bernoulli mean — the cleanest QAE
  instance in the package — but each replicate is an entire design + inference run.
  Fault-tolerant era; no action.

**Qubits needed (B3).** One coherent replicate = DGP noise register (`n · b`) +
allocation register (`n`, or the sequential design run coherently) + the full refit
oracle (B1 refit row) + the inference statistic, all uncomputed cleanly: **≥ 10⁵
logical, ≥ 10⁸ physical**, with depth dominated by the refit. Not meaningfully
estimable beyond "far larger than anything in B1/B2"; the classical fork-cluster
parallelism the framework already has is the right tool indefinitely.

### B4. Gauss–Hermite quadrature in the GLMM/frailty engines — **not** a candidate (qubits: n/a)

`EDI/src/_glmm_engine.h:32-41` (`gauss_hermite_rule`), `:168-242` (node sweep);
`fast_logistic_glmm.cpp`, `fast_poisson_glmm.cpp`, `fast_ordinal_clmm.cpp`,
`fast_weibull_frailty.cpp`. Quantum numerical integration is QAE over the integrand,
but these are 1-D integrals with a handful of nodes; the cost is the per-group likelihood
sweep, not the quadrature. Listed only so it is not re-proposed.

## II.3 Tier C — Dense linear algebra (HHL / quantum linear systems) — not worth pursuing on any hardware

- OLS: `EDI/src/fast_ols.cpp:41-56` (`LDLT` with `ColPivHouseholderQR` fallback),
  `qr_reduce_design_matrix.cpp:7,42`, `fast_matrix_rank.cpp:7`.
- Newton/IRLS steps in every likelihood kernel (`fast_logistic_regression.cpp:176`
  IRLS path; L-BFGS/Newton in 30+ `fast_*` files, e.g. `fast_survival_models_optim.cpp:574`).
- Distance matrices: `pair_dist_helpers.cpp:56`, `optimal_blocks_distance.cpp:152-228`,
  `compute_mahal_distances.cpp:10`, `compute_weighted_distances.cpp`.

`p` is tens, the systems are dense and tiny, the result must be read out in full, and
the input has to be loaded from R memory — every one of the three standing caveats
bites. Swap-test distance estimation likewise needs amplitude-encoded rows. **No.**
Listed to close the question.

**Qubits needed.** This is the one item whose qubit count is *small* and still
useless: HHL on the `p × p` normal equations needs `⌈log₂ p⌉` qubits for the state
vector, a phase-estimation register of `O(log(κ/ε))` (~20–30 for condition number
`κ ≤ 10⁴`, `ε = 10⁻⁶`), and a few ancillas — **≈ 40–60 logical qubits** at any `p ≤
1,000`. The obstacles are elsewhere: (i) loading `X'X` or `X` requires a QRAM of
`p²` or `np` cells with `O(log)` coherent access, which does not exist at any scale;
(ii) reading out all `p` coefficients of `β` to tolerance `ε` costs `O(p/ε²)` repeated
runs, erasing the speedup; (iii) at EDI's `p` (tens) the classical LDLT solve
(`fast_ols.cpp:41`) is already sub-microsecond. Listed to close the question, not
because the qubit budget is the barrier.

## II.4 Tier E — Exact tests and one-by-one sequential designs — no quantum algorithm applies (qubits: n/a)

- `zhang_exact_speedups.cpp:95-111`, `inference_indicidence_exact_fisher.R`,
  `inference_incidence_exact_binomial.R`, `miettinen_nurminen_speedups.cpp`,
  `newcombe_speedups.cpp`, `cmh_speedups.cpp` — 2×2-table enumeration is polynomial
  and already microseconds.
- `design_seq_one_by_one_*` (`atkinson_assign.cpp:76`, `pocock_simon_assign.cpp:259`,
  KK14/KK21 Mahalanobis nearest-match, `kk21_stepwise_survival.cpp:99`) — one `O(np)`
  decision per arriving subject. Nothing to amplify.

No known quantum algorithm improves on these (polynomial enumeration of 2×2 tables;
one `O(np)` decision per arriving subject). Qubit requirement is not applicable
because there is nothing to run.

## II.5 Summary — logical qubits per Part II upgrade

Representative sizes; physical ≈ ×10³ (surface code) or ×10² (optimistic qLDPC).
"Depth" is sequential Grover iterations × oracle depth.

| upgrade | what it speeds up | logical qubits, `n = 100` | `n = 500` | `n = 1000` | depth | verdict |
|---|---|---:|---:|---:|---|---|
| II.1 rerandomization amplitude amplification (`p = 5`) | `DesignFixedRerandomization` search, `O(1/p_a)` → `O(1/√p_a)` | ≈ 360 | ≈ 920 | ≈ 1,750 (`p=20`) | `O(np/√p_a)` | fault-tolerant era |
| II.2/B1 randomization p-value, linear statistic | `compute_rand_two_sided_pval()`, bisection CI steps; `O(1/ε²)` → `O(1/ε)` | ≈ 165 | ≈ 565 | ≈ 1,065 | `O(n/ε)` | fault-tolerant era; the best-defined target |
| II.2/B1 randomization p-value, OLS via FWL | same, OLS treatment coefficient | ≈ 230 | ≈ 630 | ≈ 1,130 | `O(n²/ε)` | fault-tolerant era |
| II.2/B1 randomization p-value, iterative refit | Cox / robust / GLM(M) randomization tests | ≈ 10⁴ | ≈ 3–6 × 10⁴ | ≈ 6–10 × 10⁴ | `O(k n p²/ε)` | impractical even then |
| II.2/B2 nonparametric bootstrap, linear statistic | bootstrap CIs / quantiles | ≈ 770 | ≈ 4,570 | ≈ 10,070 | `O(n/ε)` | fault-tolerant era |
| II.2/B2 Bayesian bootstrap, linear statistic | `inference_all_abstract_bayesian_bootstrap.R` | ≈ 3,300 | ≈ 16,100 | ≈ 32,100 | `O(n/ε)` | impractical |
| II.2/B2 bootstrap of an iterative refit | all bootstrap-of-refit loops | ≈ 10⁴ | ≈ 4–7 × 10⁴ | ≈ 7–11 × 10⁴ | `O(k n p²/ε)` | impractical |
| II.2/B3 simulation framework replicate | power / coverage | ≥ 10⁵ | ≥ 10⁵ | ≥ 10⁵ | refit-dominated | never |
| II.3 HHL for OLS / Newton steps | `fast_ols.cpp`, IRLS/Newton solves | ≈ 40–60 (+ QRAM of `np` cells) | same | same | `O(κ log(1/ε))` + readout `O(p/ε²)` | not a win at any qubit count |
| II.4 exact tests, sequential designs | — | n/a | n/a | n/a | — | no algorithm |

For calibration: the cheapest useful row (B1 linear, `n = 100`, `ε = 0.01`) is
~165 logical ≈ 1.6 × 10⁵ physical qubits running ~100 sequential Grover iterations of
depth `O(n)` — i.e. a few ×10⁴ sequential logical-gate layers — versus, on the
classical side, 501 trivially parallel `O(n)` loops that finish in microseconds.

## Bottom Line

One real candidate: `DesignFixedOptimal`'s quadratic (and Dinkelbach-ratio) objective is
already a QUBO, the package already falls back to heuristic annealing above `n ≈ 20`,
and the integration is a small opt-in sampler hook plus a penalty-calibrated QUBO
builder. A second, harder one: `DesignFixedOptimalBlocks` with `k ≥ 3`. The inference
layer (randomization p-values, bisection CI inversion, bootstraps, simulation power) has
a genuine, provable quadratic speedup via amplitude estimation — decisive in the small-`p`
/ tight-`tol` regime where classical resampling scales as `1/ε²`, and with a cheap
coherent oracle for every linear-in-`w` statistic the package resamples — but it
requires a fault-tolerant machine running sequential circuits of depth `O(n/ε)`, which
nothing existing or announced provides; the only present-day action is to keep the
resampling kernels factored as "classical constant vector + `Σ c_i w_i` over
replicates." Part II's qubit table (II.5) puts the cheapest useful inference-layer
item at ~165 logical (~10⁵ physical) qubits at `n = 100` and the bootstrap/refit
variants at 10³–10⁵ logical. Linear algebra, RNG, exact tests, and sequential designs
are not candidates on any hardware. The most likely *practical* outcome of doing A1 is
a better classical Ising-style kernel, not a quantum one — which is still a fine
outcome.

## Implementation TODOs

- [ ] TODO-1: **Make a decision about whether to implement this at all — ask the user.**
  Options: (a) vignette + hook only, (b) nothing, (c) full A1 + A3. Do not start the
  items below until the decision is recorded here. (Joins the Phase 0 decision batch;
  `gpu_optimizations.md → TODO-7`'s backend/dispatch answer should be read first.)
- [ ] TODO-2: `qubo_build_quadratic(Q, n_T, lambda)` + penalty bound + feasibility repair
  in `helper_optimal_*`; brute-force exactness test at `n ≤ 12` mirroring
  `test-design-optimal-milp-solvers.R`; Dinkelbach wrapper reuse for `"ratio"`.
- [ ] TODO-3: `solver = "qubo"` / `qubo_sampler` hook on `optimal_solve_auto()` and
  `DesignFixedOptimal`; certificate `"qubo_sampled"`; provenance fields; roxygen section
  mirroring the Gurobi/CPLEX install guide style in `design_fixed_optimal_blocks.R`.
- [ ] TODO-4: vignette (amended 2026-08-23 — **R only, no `reticulate`**): QUBO
  construction with `qubo_build_quadratic()`, `detect_qubo_backends()` output,
  `qubo_backend = "none"` vs `"auto"` vs a named backend, the fallback warnings, and a
  D-Wave hybrid + direct-QPU example run once with a token and checked in as static
  output; CI stays hardware-free.
- [ ] TODO-5: Run the benchmarking table above; record results in this file; decide
  whether a classical Ising-style kernel (parallel tempering / SBM) is the real
  follow-up.
- [ ] TODO-6: Only if TODO-5 is positive: `DesignFixedOptimalBlocks` `k ≥ 3` QUBO
  encoding through the same hook (A3).
- [ ] TODO-7: Tier A2 (annealer-sampled allocation *distribution* as a new design
  class, Part I) and Tier C / II.1 / II.3 (Part II) — explicitly **not scheduled**;
  revisit A2 when a materially larger fully-connected annealer exists, and the Part II
  items against the qubit table in II.5.
- [ ] TODO-9: **`detect_qubo_backends()`** (I.7.2; pure R): exported helper + backend
  registry (id, kind, credential env vars / D-Wave INI config file, probe request,
  capability field); offline-first, `probe = TRUE` opt-in with timeout, session cache
  with TTL, `print()` method, `EDI.qubo_backends_override` injection for tests;
  roxygen "Wiring up D-Wave Leap / SQBM+ / Fujitsu DA / NEC VA" guides in the style
  of the Gurobi/CPLEX guides in `design_fixed_optimal.R`. `httr2` (+ `httptest2` or
  `webfakes` for tests) added to Suggests. Depends on TODO-2/3; gated on TODO-1 =
  (a) or (c).
- [ ] TODO-10: **Dispatch + classical fallback policy** (I.7.3): `qubo_backend`
  argument on `optimal_solve_auto()` / `DesignFixedOptimal` (and
  `DesignFixedOptimalBlocks` for A3), precedence arg > option > env > `"none"`, the
  `"auto"` chain (QPU → hybrid → cloud Ising → classical SA), named-backend-or-
  classical rule, A2 refuse-don't-fallback rule, size / embedding / time / cost
  guards, one `warning()` per hop, provenance fields. Default `"none"` must be
  bit-for-bit today's MILP → SA behaviour (release additive rule).
- [ ] TODO-11: **R-native backend adapters behind one internal interface**
  `qubo_submit(backend, Q_pen, num_reads, ...) -> list(w_matrix, metadata)`
  (I.7.0): **Stage 1 (no embedding needed):** R SAPI client (`httr2`/`jsonlite`) —
  solver listing, problem submit/poll/cancel, answer decoding — and the R BQM
  serializer for **Leap hybrid BQM**; REST adapters for the cloud Ising services a
  user asks for (SQBM+ / Fujitsu DA / NEC VA), each ~100 lines. **Stage 2 (direct
  QPU):** vendor `minorminer` `busclique` (Apache-2.0 C++) into `src/` in its own
  unity-build group with `inst/COPYRIGHTS` + `Authors@R` `cph` attribution;
  `largest_clique_size` on the live working graph; chain strength
  (uniform-torque-compensation formula) and majority-vote unembedding; SAPI QPU
  problem format (`qubo` on physical qubits/couplers). Stage 2 proceeds only after
  Stage 1's TODO-5 numbers show the QPU column is worth the vendoring. The CQM
  serializer is part of TODO-6 (A3). No gate-model adapter.
- [ ] TODO-12: **Hardware-free tests** (I.7.4): detection unit tests (env/INI/absent
  `httr2`); HTTP-mocked SAPI fixtures (solver list with synthetic Pegasus/Zephyr
  working graphs, submit/poll/answer, offline, timeout); byte-exact BQM/CQM
  serializer round-trips against checked-in dimod-generated fixtures (no Python at
  test time); `busclique` embedding tests on the fixture graphs; dispatcher tests
  through `EDI.qubo_backends_override` + mocks covering every fallback row of
  I.7.1 (warning text, provenance, result-equality with `qubo_backend = "none"`
  when the last hop is classical SA); paid integration tests only under
  `DWAVE_API_TOKEN` / service keys **and** `EDI_RUN_PAID_BACKEND_TESTS=true`
  (never CI).
- [ ] TODO-8: Tier B / II.2 (QAE for randomization p-values, bisection CI inversion, and
  bootstrap quantiles; qubit budgets in II.5) — **not buildable now, but a standing design constraint**: any
  future refactor of the linear-statistic resampling kernels (mean difference,
  Wilcoxon `delta == 0`, ridit, KK compound, OLS-via-FWL) and of the bisection drivers
  must keep the "classical `c(y, δ)` + generic `Σ c_i w_i` over replicates" factoring
  and the `evaluate_pval(δ)` / `pval_fn(δ)` seam, so a QAE oracle can later be dropped
  in without touching the CI logic. Revisit for real when error-corrected hardware
  offers on the order of `n` logical qubits and `O(n/ε)` sequential depth; re-read this
  file's date before acting on any of it.
