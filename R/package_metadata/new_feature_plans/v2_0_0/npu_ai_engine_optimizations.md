# NPU / AI-Engine Optimizations for On-Device Prediction

**Status:** proposed, measurement-gated, and prediction-only  
**Primary targets:** Apple Neural Engine (ANE), Intel NPU, AMD Ryzen AI NPU,
and Qualcomm Hexagon/HTP  
**Scope:** low-precision matrix multiplication used for batched forward
prediction; no model fitting, optimizer, Hessian, covariance, or hypothesis-test
offload

## Decision: keep this as a separate cross-vendor plan

This should not be folded into `arm_hardware.md` or `intel_hardware.md`.
Those plans optimize native CPU execution and dense numerical kernels while
preserving the package's usual floating-point contract. NPU execution is a
different feature:

- it spans ARM and x86 hosts;
- it is reached through graph runtimes and device drivers, not compiler ISA
  flags or CBLAS;
- it normally uses FP16, BF16, INT8, or another quantized representation;
- graph compilation, input conversion, device dispatch, and caching are part of
  its cost; and
- it is suitable for repeated forward prediction, not statistical training or
  exact inference.

The plan should reuse the hardware fingerprint, build metadata, benchmark
discipline, thread controls, and tuning persistence proposed by
`arm_hardware.md`, `intel_hardware.md`, and `memory_side_improvements.md`.
This document owns NPU graph construction, precision policy, provider discovery,
dispatch, caching, and prediction-specific validation.

## Executive summary

NPUs can execute large low-precision matrix products efficiently and at low
power, but the current EDI opportunities are narrower than the phrase “AI
engine” suggests. EDI has no public `predict()` implementation in its indexed R
code today. Its closest production candidates are the counterfactual
g-computation paths in `gcomp_speedups.cpp` and
`fast_ordinal_regression.cpp`. Those paths currently calculate one coefficient
vector at a time, such as

```text
eta = X[n x p] * beta[p]
```

which is GEMV, not a substantial GEMM. On typical EDI problems with a handful
of predictors, NPU setup, FP64-to-low-precision conversion, graph dispatch, and
result transfer will usually make this slower than Eigen or BLAS.

The prerequisite is therefore an honest batched prediction representation:

```text
Eta[n x q] = X[n x p] * Beta[p x q]
```

where `q` represents coefficient draws, fitted models, counterfactual scenarios,
outcome heads, or repeated prediction requests. EDI should offload only when
`n`, `p`, and `q` provide enough arithmetic to amortize fixed costs, the graph
and buffers are reusable, and a calibrated precision contract passes.

Expected outcomes, including all conversion and dispatch costs:

- Current one-vector g-computation with small `p`: **0.3–1.0x**; normally do not
  dispatch.
- Large repeated prediction with a cached graph and weights: **1.5–6x** over a
  tuned multicore CPU prediction path in favorable shapes.
- Batched `X * Beta` with `q >= 32` and sufficiently large `n,p`: **1.2–5x** for
  the prediction stage; **1.05–3x** end to end when prediction is dominant.
- Full statistical post-fit methods that also compute sandwich covariance or a
  Hessian: usually **1.0–1.3x** end to end, even when their prediction fragment
  is faster.
- Default-size EDI simulations (`p` is commonly small): **approximately 1x**;
  NPU use is not justified without deliberately batched large prediction work.

These are engineering priors, not product-TOPS claims. The ship decision must
use measured end-to-end latency, throughput, energy when available, and
statistical error against the FP64 CPU reference.

## Terminology: AI inference is not EDI statistical inference

Vendor documentation uses “inference” to mean forward evaluation of a trained
model. EDI uses “inference” for estimators, standard errors, confidence
intervals, randomization tests, and related statistical procedures. This plan
uses **prediction** for the NPU operation to avoid conflating the two.

NPU output must not silently enter coefficient estimation, Hessian evaluation,
sandwich covariance, confidence intervals, p-values, resampling refits, or
randomization-test decisions. A future statistically validated approximate
method may opt in explicitly, but it is not part of the automatic default.

## Current EDI opportunity audit

### Candidate 1: logistic and fractional-logit g-computation

`EDI/src/gcomp_speedups.cpp:96-125` and `:150-158` compute counterfactual point
estimates from a single `X_fit * coef_hat`, remove the observed treatment term,
apply treated/control shifts, transform through the logistic link, and average.
This is the cleanest semantic starting point because it is already a prediction
stage separated from fitting.

The current call is a poor NPU shape: `Beta` has one column and EDI often uses
small `p`. The useful extension is a new batched internal operation that accepts
one or more of:

- many prediction batches against the same frozen coefficients;
- many coefficient vectors from an already-computed uncertainty ensemble;
- more than two counterfactual scenarios;
- multiple fitted models sharing the same design matrix; or
- a two-head model whose linear predictors can be emitted together.

Do not manufacture a large `q` by delaying unrelated user calls or changing
observable execution order. Batch only work already available together.

Estimated gain:

- existing single point estimate: **0.3–1.0x**, so automatic dispatch should
  reject it;
- cached, batched prediction stage: **1.3–5x**;
- point-estimate workflow when that stage is at least 70% of time: **1.2–3x**.

### Candidate 2: ordinal counterfactual predictions

`EDI/src/gcomp_speedups.cpp:545-583` computes `X_fit * coef_hat`, then evaluates
threshold-specific logistic probabilities. The fuller post-fit path in
`EDI/src/fast_ordinal_regression.cpp:527-678` additionally builds a Hessian,
inverts it, and computes numerical gradients.

Only batched linear predictors are NPU candidates. Threshold transforms and
reductions may remain on the CPU unless the selected graph provider supports
them without creating costly device/host boundaries. Hessian formation,
factorization, covariance, and finite-difference work stay in FP64 CPU code.

Estimated gain:

- batched ordinal forward-prediction fragment: **1.2–4x**;
- current full post-fit function: **1.0–1.4x**, because non-prediction work
  remains;
- repeated deployment prediction with fixed thresholds and coefficients:
  **1.5–5x** for large batches.

### Candidate 3: zero-augmented and multi-component prediction

EDI's zero-augmented Poisson, ZINB, hurdle, and zero/one-inflated beta families
already have separate predictor matrices or parameter components, as documented
through their native entry points and `RcppExports.R`. A future prediction API
can concatenate compatible coefficient heads and evaluate them as a matrix
product rather than issuing small independent GEMVs.

This is attractive when the same large row batch requires count/mean,
zero/hurdle, or boundary-category predictions together. It is not permission to
move fitting likelihoods or iterative updates to low precision.

Estimated gain:

- two- or three-head large-batch prediction stage: **1.3–4x**;
- end-to-end exported prediction call: **1.1–3x**, depending on preprocessing,
  link functions, and output materialization.

### Candidate 4: a new deployment-oriented prediction interface

There is no indexed `predict()` call in `EDI/R` at the time of this audit. The
strongest long-term NPU use case is therefore a deliberately designed API for
repeated on-device prediction from an already-fitted EDI model, rather than
injecting an accelerator into training internals.

The API should support:

- an immutable prediction plan containing column order, transforms,
  coefficients, thresholds, link, precision policy, and reference outputs;
- batches of new rows with fixed or bucketed static shapes;
- multiple heads and counterfactual scenarios;
- graph/session warm-up and reuse;
- explicit CPU, NPU-preferred, and NPU-required modes; and
- diagnostics stating which graph nodes and device actually executed.

For a cached plan serving repeated large batches, **1.5–6x** end-to-end CPU
speedup is plausible. For interactive batches of tens or hundreds of rows with
small `p`, expect **0.2–1.1x** and retain the CPU path.

### Candidate 5: large batched simulation forward generation

`SimulationFramework` supports a linear conditional-expectation model `X beta`
and many repetitions (`EDI/R/simulations_framework.R:292-4284`). The framework
currently parallelizes complete simulation work and fits statistical models;
those fits normally dominate. A future generator could batch only the forward
linear-predictor stage across already-planned repetitions or parameter settings.

This is lower priority because it is not deployment prediction, typical `p` is
small, RNG/replication order must remain exact, and CPU fitting follows each
generated outcome.

Estimated gain:

- deliberately large batched DGP linear-predictor stage: **1.2–3x**;
- complete simulation run: **1.0–1.4x** in the unusual case where generation is
  material; otherwise approximately **1x**.

## Explicit non-candidates

Do not target the following under this plan:

- GLM, ordinal, survival, mixed-model, or robust-regression training loops;
- score, likelihood, gradient, Hessian, Cholesky/LDLT/LU, or convergence checks;
- sandwich covariance and cluster-meat calculations in
  `gcomp_speedups.cpp:175-288,384-502` and
  `robust_post_fit_speedups.cpp:71-387`;
- bootstrap or randomization refits in
  `inference_all_abstract_rand_bootstrap.R:201-361,639-691`;
- distance matrices, optimal-design search, assignment, matching, or tree work;
- small `X * beta` calls merely because an NPU is present; or
- user-defined callbacks whose semantics cannot be represented and validated as
  a fixed prediction graph.

NPUs are not a general replacement for BLAS, Apple Accelerate, Intel AMX, ARM
SIMD/SVE, a GPU, or bandwidth/NUMA optimization.

## Backend architecture

### Common abstraction

Introduce a narrow internal interface, provisionally `edi_lowp_predict_backend`,
with these operations:

```text
enumerate_devices()
query_capabilities(device)
compile_or_load(plan, static_shape, precision)
run(session, input_batch)
profile(session)
close(session)
```

The public statistical classes must not include provider headers. They submit a
provider-neutral `edi_prediction_plan` containing only supported operations:
MatMul/Gemm, optional bias/add, an allowed link/threshold transform, and a
reduction. Every plan also retains an FP64 CPU reference implementation.

Prefer an optional dynamically loaded companion/backend over making ONNX
Runtime or vendor SDKs mandatory dependencies of the base R package. A base
installation must build, load, and produce identical default results without
any NPU runtime.

### Common runtime versus direct vendor adapters

Use ONNX Runtime's execution-provider model as the first cross-vendor prototype:

- CoreML Execution Provider for Apple hardware;
- OpenVINO Execution Provider for Intel NPU;
- Vitis AI Execution Provider for AMD Ryzen AI; and
- QNN Execution Provider with the HTP backend for Qualcomm.

This is an architectural preference, not an assumption that one binary exposes
all providers on all platforms. Provider availability, licensing, packaging,
driver installation, supported operators, and static-shape requirements differ.

Evaluate a direct Objective-C++ Core ML adapter if it materially reduces macOS
package size/startup time or provides better compute-plan diagnostics. Do not
maintain four unrelated graph builders unless the common runtime fails a
measured requirement.

### Two graph modes

1. **Frozen-model deployment graph.** Coefficients are constants. Compile once,
   cache, and run many `X` batches. This matches NPU compilers best and is the
   primary target.
2. **Dynamic coefficient-batch graph.** Both `X` and `Beta` are inputs, enabling
   `X * Beta`. Adopt only on providers that keep MatMul on the NPU and beat CPU
   end to end; some NPU compilers strongly prefer constant weights.

Never recompile a frozen graph for a one-shot EDI point estimate and call the
compilation time “outside” the benchmark.

## Implementation plan

### Phase 0: characterize real shapes and time fractions

- [ ] **TODO-1: Instrument prediction shapes.** Record `n`, `p`, output/head
  count `q`, counterfactual count, dtype, bytes converted, reuse count, and time
  in matrix multiply, links, reductions, covariance, R allocation, and copying.
- [ ] **TODO-2: Add a no-offload shape report.** Run representative g-computation,
  ordinal, zero-augmented, and simulation workflows and report how often a true
  GEMM-shaped batch exists. Do not redesign code based on peak-device specs.
- [ ] **TODO-3: Define CPU baselines.** Compare current Eigen, optimized BLAS,
  the ARM dense adapter where applicable, and Intel AMX/oneDNN where applicable.
  An NPU must beat the best available CPU path, not an intentionally scalar one.
- [ ] **TODO-4: Establish fixed overhead.** Measure provider discovery, graph
  creation/compilation, cache hit/miss, quantization, tensor packing, dispatch,
  synchronization, and result conversion separately.

Acceptance gate: at least one real or approved future API produces a reusable
batch for which prediction is a material fraction of end-to-end time. Otherwise
retain the document and stop implementation.

### Phase 1: build-time capability detection and portable stubs

- [ ] **TODO-5: Add `configure`/`configure.win` probes.** Compile and link the
  selected ONNX Runtime C/C++ API and any optional direct Core ML adapter. Probe
  headers, symbols, ABI/version APIs, required Objective-C++ support, framework
  links, and provider-registration entry points; do not infer support from CPU
  family or OS version strings.
- [ ] **TODO-6: Generate value-style feature macros.** Examples:
  `EDI_HAVE_ONNXRUNTIME`, `EDI_HAVE_ORT_COREML_EP`,
  `EDI_HAVE_ORT_OPENVINO_EP`, `EDI_HAVE_ORT_VITISAI_EP`,
  `EDI_HAVE_ORT_QNN_EP`, and `EDI_HAVE_COREML_DIRECT`, each defined as `0` or
  `1`. A compiled provider is not proof that a device or driver is available.
- [ ] **TODO-7: Handle cross compilation.** Compile-and-link probes may run, but
  configure must never execute a target binary. Accept documented provider
  locations and `--with-edi-npu-*`/`--without-edi-npu-*` overrides. Runtime
  enumeration remains authoritative on the target device.
- [ ] **TODO-8: Provide a complete stub backend.** Missing runtimes, SDKs,
  frameworks, drivers, or provider libraries produce `not_compiled` or
  `unavailable` diagnostics and use CPU prediction. They must not cause package
  configuration, loading, or ordinary model fitting to fail.
- [ ] **TODO-9: Keep dependencies optional and redistributable.** Audit runtime
  licenses, binary size, CRAN policies, macOS signing/notarization, Windows DLL
  discovery, Android packaging, and provider-version compatibility before
  distributing any backend binary.

### Phase 2: runtime device and provider detection

- [ ] **TODO-10: Enumerate providers and physical devices.** Query the runtime,
  driver, device identifier/generation, supported dtypes, static/dynamic shapes,
  maximum tensor sizes, operator assignment, memory mode, and power/performance
  controls when exposed. A provider name alone does not prove NPU execution.
- [ ] **TODO-11: Verify graph placement.** Compile a tiny untimed probe graph and
  use provider profiling/assignment information to confirm MatMul is assigned to
  the requested device. Do not time it during package load. If placement cannot
  be proven, mark the provider `unverified` and require benchmark evidence before
  automatic use.
- [ ] **TODO-12: Distinguish preference from guarantee.** Apple Core ML may
  select among CPU, GPU, and ANE; ONNX Runtime providers may partition unsupported
  nodes to CPU. Diagnostics must report requested and observed/assigned devices.
  A strict mode disables CPU fallback when the provider offers that control.
- [ ] **TODO-13: Extend the hardware fingerprint.** Include provider/runtime and
  driver versions, OS, NPU identity, supported precision, graph format/opset,
  static shape, power mode, and compiled model/cache format. Invalidate tuning
  and compiled artifacts when compatibility-relevant fields change.
- [ ] **TODO-14: Add `EDI:::npu_diagnostics()`.** Report compiled backends,
  load failures, detected devices, provider options, tested graph placement,
  cache state, last dispatch decision, conversions, and fallback reason without
  changing device state.

### Phase 3: prediction-plan and batching layer

- [ ] **TODO-15: Implement `edi_prediction_plan`.** Store feature schema,
  preprocessing, coefficient/threshold tensors, counterfactual substitutions,
  output heads, links, reductions, static-shape buckets, precision policy, and a
  stable content hash. Validate dimensions and non-finite values before dispatch.
- [ ] **TODO-16: Add the frozen-model graph first.** Prototype logistic and
  fractional-logit counterfactual prediction with fixed coefficients. Reuse the
  compiled session and device buffers across calls.
- [ ] **TODO-17: Add explicit batch formation.** Pack rows contiguously and use
  provider-specific static batch buckets. Pad only with a mask whose outputs are
  excluded exactly. Include packing/padding cost in every result.
- [ ] **TODO-18: Prototype dynamic `X * Beta`.** Use actual coefficient/scenario
  matrices already available together. Verify full MatMul assignment and reject
  providers that fall back to CPU or recompile per `Beta` value.
- [ ] **TODO-19: Add ordinal and multi-head graphs.** Only after the logistic
  prototype ships or proves viable. Prefer keeping MatMul, link, and reduction in
  one device subgraph; otherwise measure each device/host boundary.
- [ ] **TODO-20: Create a deployment prediction API.** Expose plan creation,
  warm-up, batched prediction, diagnostics, teardown, and serialization without
  changing existing statistical APIs. Make approximate precision explicit in
  the returned metadata.

### Phase 4: precision and statistical validation

- [ ] **TODO-21: Support FP16 first, then calibrated INT8.** FP16 is the least
  disruptive common prototype. Add INT8 only with representative calibration
  data and provider-specific support. Treat BF16, INT16, or mixed precision as
  separately validated modes, not aliases.
- [ ] **TODO-22: Define feature and coefficient scaling.** Standardize or
  quantize per tensor/channel as supported, preserve intercept handling, bound
  accumulation error, and record saturation/clipping counts. Heavy-tailed and
  rare indicator columns require dedicated fixtures.
- [ ] **TODO-23: Accumulate summaries accurately.** Convert prediction outputs
  to at least FP32 and compute final means, contrasts, and other statistical
  reductions in FP64 on CPU unless a validated provider graph demonstrably
  preserves the required error bound.
- [ ] **TODO-24: Validate at the estimand level.** Test maximum and percentile
  error in linear predictors/probabilities, class/rank changes where relevant,
  counterfactual mean and contrast error, subgroup error, and behavior near link
  saturation. Aggregate agreement can hide harmful per-row error.
- [ ] **TODO-25: Define two contracts.** `validated` requires a saved
  model-and-shape-specific error certificate against FP64 reference data;
  `experimental` exposes raw low-precision behavior and is never automatic.
  Failure, drift, or out-of-calibration inputs route `auto` to CPU.
- [ ] **TODO-26: Preserve statistical defaults.** Existing EDI estimates,
  standard errors, intervals, p-values, and seeded simulations remain FP64 CPU
  by default. No tolerance-based result silently replaces an exact documented
  path.

### Phase 5: caching, dispatch, and tuning

- [ ] **TODO-27: Cache compiled graphs safely.** Key by plan hash, provider,
  runtime/driver, device, precision, opset/format, and static shape. Use the R
  user cache rather than the installed package. Make writes atomic, size-bound,
  inspectable, and removable. Never deserialize an incompatible artifact.
- [ ] **TODO-28: Add deterministic controls.** Proposed settings:
  `EDI_NPU=auto|off|prefer|require`,
  `EDI_NPU_BACKEND=auto|coreml|openvino|vitisai|qnn`,
  `EDI_NPU_PRECISION=validated|fp16|int8`, and
  `EDI_NPU_CPU_FALLBACK=allow|error`. Explicit impossible requests error; `auto`
  records a reason and falls back.
- [ ] **TODO-29: Tune by operation and shape bucket.** Compare CPU and each
  eligible provider after warm-up, with conversions and synchronization included.
  Save latency, throughput, energy if measurable, and validation result. Do not
  benchmark unexpectedly inside an ordinary prediction call.
- [ ] **TODO-30: Coordinate concurrency.** One process should own or broker an
  NPU session unless the provider proves safe concurrent execution. Avoid one
  graph compilation per fork/mirai worker, CPU oversubscription during provider
  fallback, and concurrent benchmarks competing for the same device.
- [ ] **TODO-31: Add circuit breakers.** After a provider error, device reset,
  timeout, validation failure, or repeated CPU partitioning, disable that tuned
  route for the process and fall back. `require` reports a structured error.

## Automatic selection algorithm

At first eligible prediction use:

1. Read compiled capability macros. If no backend was compiled, use CPU.
2. Dynamically load only the selected optional backend and enumerate providers
   and physical devices. Do not infer an NPU from the CPU marketing name.
3. Match the requested backend/precision policy. A missing explicit request
   errors; `auto` continues to CPU.
4. Build the provider-neutral prediction plan and determine whether coefficients
   are frozen or dynamic.
5. Query whether every required operation, dtype, and static-shape bucket can be
   assigned. Prefer a complete NPU subgraph; reject transfer-heavy partitions.
6. Check `n,p,q`, bytes moved, graph/session reuse count, cache state, and saved
   break-even thresholds.
7. For a `validated` route, confirm that the calibration/error certificate
   matches the plan hash, device/provider version, precision, and input-domain
   checks.
8. Load or compile the graph. A cache miss is eligible automatically only when
   predicted future reuse amortizes compilation; otherwise choose CPU.
9. Run a warmed, reusable session and record actual provider assignment when the
   runtime exposes it.
10. On any unsupported operation, compilation error, timeout, non-finite output,
    validation failure, or device loss, fall back under `auto` and record why.
11. Return predictions with backend, precision, approximation status, and
    validation metadata available through diagnostics.

Conservative automatic rejection rules:

```text
q == 1 and p is small
one-shot graph or session
uncached compilation cannot be amortized
FP64/statistical-exact result required
dynamic shape unsupported and padding dominates
provider assigns MatMul to CPU
host/device conversion or transfer dominates
input outside validated calibration domain
NPU already saturated by another process
```

## Vendor-specific notes

### Apple ANE / Core ML

Core ML can allow CPU, GPU, and Neural Engine execution, and Apple exposes
compute-unit preferences rather than a promise that every operation runs on the
ANE. Use static prediction plans, keep the model loaded, use batch prediction,
and inspect Core ML compute plans/Instruments during validation. Compare the
CoreML ONNX Runtime provider with a direct Core ML adapter. FP16 is the initial
precision candidate; do not assume lower-bit weight storage means the same
activation/accumulation behavior.

### Intel NPU / OpenVINO

Use the OpenVINO NPU device or its ONNX Runtime execution provider. Query the
installed plugin and driver, supported operations, static-shape limitations,
and actual inference precision. Cache compiled models using supported runtime
mechanisms, but invalidate across incompatible driver/runtime changes. Benchmark
NPU against OpenVINO CPU and the package's best native CPU path.

### AMD Ryzen AI NPU

Use ONNX Runtime with the Vitis AI Execution Provider when installed. Verify the
reported NPU subgraph/operator assignment and cache compiled EP context. Current
platform generations and software releases differ in batch, operator, and
quantization support, so runtime capability queries and per-device tuning are
mandatory; never encode a universal Ryzen AI threshold.

### Qualcomm Hexagon / HTP

Use the ONNX Runtime QNN Execution Provider with the HTP backend. Its HTP path
requires a quantized graph for relevant operations, commonly static shapes, and
provider/SDK-specific libraries. Require representative calibration, verify
that MatMul and graph I/O quantize/dequantize as intended, cache QNN context
binaries when compatible, and handle subsystem reset by recreating the session
or falling back.

## Benchmark plan

### Required devices

At least one supported generation from each backend before calling that backend
shipped:

- Apple M-series Mac with ANE, plus the same machine's CPU/Core ML CPU baselines;
- Intel Core Ultra system with a supported NPU driver;
- AMD Ryzen AI system with the matching Vitis AI runtime;
- Qualcomm Snapdragon Windows ARM64 or Android device with QNN HTP; and
- CPU-only hosts on macOS, Linux, and Windows to test stubs and fallback.

Report exact device, memory, OS, power mode, runtime/provider/driver versions,
thermal state, graph precision, static shape, and operator placement.

### Shape grid

Measure representative and deliberately favorable shapes:

```text
n: 32, 256, 2,048, 16,384, 131,072
p: 5, 16, 64, 256, 1,024
q/heads/scenarios: 1, 2, 8, 32, 128, 512
precision: FP64 CPU, FP32 CPU, FP16, calibrated INT8 where supported
reuse count: 1, 2, 10, 100, 1,000
cache: cold compile, warm import, warm session
```

Do not omit `p=5` and `q=1`; they represent why most current EDI calls should
not use an NPU.

### Workloads

1. Raw frozen-weight MatMul and dynamic `X * Beta` microbenchmarks.
2. Logistic/fractional-logit counterfactual point prediction.
3. Ordinal expected-outcome prediction with several category counts.
4. Two-head zero-augmented/hurdle prediction.
5. Repeated batches through the proposed deployment prediction API.
6. Full g-computation post-fit, to expose the non-offloaded covariance fraction.
7. Large simulation DGP generation followed by the unchanged full simulation.
8. Inputs with heavy tails, rare binaries, large coefficients, saturated links,
   missing/non-finite values, and out-of-calibration ranges.

### Measurements

For every comparison record:

- cold start, first inference, warmed latency, steady-state throughput, and tail
  latency;
- graph compilation/import, quantization, packing, transfer, device execution,
  synchronization, link/reduction, and R object allocation separately;
- peak and steady memory, compiled-cache size, CPU utilization, and device
  utilization/assignment;
- joules per prediction or system energy where reliable counters exist;
- maximum/median/99th-percentile predictor and probability error;
- counterfactual means/contrasts, subgroup error, and decision/rank changes; and
- full workflow speedup, not only device-kernel speedup.

Use warm-ups, randomized implementation order, enough repetitions for confidence
intervals, fixed inputs, and paired outputs. Report both latency and throughput;
an NPU may improve one while hurting the other.

## Speedup estimates and break-even model

### A-priori ranges

| EDI area | Required shape/reuse | Prediction-stage gain | End-to-end gain | Recommendation |
|---|---|---:|---:|---|
| Current small logistic g-comp | `q=1`, small `p` | 0.3–1.0x | 0.5–1.0x | CPU |
| Batched logistic/fractional g-comp | large `n`, `q>=32`, cached | 1.3–5x | 1.2–3x | Prototype first |
| Current ordinal post-fit | one beta plus Hessian/covariance | 1.1–3x fragment | 1.0–1.4x | Low priority |
| Repeated ordinal prediction | large cached batches | 1.5–5x | 1.3–4x | Good future target |
| Zero-augmented/multi-head prediction | 2–3 heads, large `n` | 1.3–4x | 1.1–3x | Prototype after logistic |
| Deployment prediction API | fixed weights, 10–1,000 reuses | 2–10x MatMul | 1.5–6x | Best target |
| Batched simulation linear predictor | large `n,p,reps` | 1.2–3x | 1.0–1.4x | Optional |
| Training/resampling refits | precision-sensitive iterative work | not in scope | approximately 1x | Never auto-dispatch |

The upper ranges assume a graph/session cache hit, low-precision tensors already
packed or reused, a real GEMM rather than GEMV, complete or nearly complete NPU
placement, and prediction dominating total time. A one-shot graph compilation
can be tens to thousands of times more expensive than a small `X * beta` call.

### Break-even equation

For reuse count `r`, choose NPU only if measured or conservatively predicted:

```text
T_compile/r + T_quantize + T_pack + T_transfer_in
+ T_npu + T_transfer_out + T_sync + T_cpu_tail
< T_best_cpu
```

All terms must use the actual plan and shape bucket. Peak TOPS is absent from
this decision because it does not measure graph compilation, supported
operators, transfers, occupancy, or precision error.

### Amdahl-law interpretation

If prediction is fraction `f` of the workflow and is accelerated by factor `s`,
the maximum workflow speedup is

```text
1 / ((1 - f) + f / s)
```

Examples:

- `f=0.20`, `s=5`: **1.19x** overall;
- `f=0.50`, `s=5`: **1.67x** overall;
- `f=0.80`, `s=5`: **2.78x** overall.

This is why a 5x prediction fragment may produce almost no gain in a full
post-fit method dominated by Hessian and covariance work.

## Acceptance and stopping rules

Ship an automatic NPU route only when all are true:

1. the operation is forward prediction, not fitting or statistical inference;
2. the provider and physical NPU are detected and required nodes are assigned;
3. compile, cache, conversion, transfer, synchronization, and CPU-tail costs are
   included;
4. a real adjacent range of shapes gains at least 20% end to end or a deployed
   repeated-prediction workload gains at least 1.5x;
5. the validated precision contract passes on representative, adversarial, and
   out-of-domain fixtures;
6. automatic CPU fallback is deterministic and observable;
7. cold-start latency and cache size are acceptable for the intended reuse;
8. default EDI statistical results and seeded behavior are unchanged; and
9. CPU-only installations retain full functionality.

Stop, retain as experimental, or restrict to explicit opt-in when:

- no natural `q>1` batch exists;
- coefficients change often enough to trigger graph recompilation;
- the provider executes MatMul or significant graph segments on CPU;
- quantization/calibration error changes a documented result materially;
- fixed-shape padding, R copies, or transfers consume the gain;
- the best CPU path wins consistently;
- runtime packaging or licensing is unsuitable; or
- supported hardware cannot be tested in CI/release qualification.

## Risks and non-goals

- No claim that every marketed “AI PC” exposes a usable NPU runtime.
- No compile flag can enable ANE, Intel/AMD NPU, or Hexagon directly.
- No mandatory ONNX Runtime or vendor SDK in the base package.
- No silent FP64-to-FP16/INT8 conversion in existing APIs.
- No NPU training, optimizer, Hessian, factorization, covariance, bootstrap
  refit, or randomization-test implementation.
- No dynamic downloading of models, runtimes, or drivers from ordinary package
  calls.
- No assumption that provider registration means NPU placement.
- No benchmark that excludes compilation, conversion, padding, transfer, or
  synchronization from end-to-end numbers.
- No hard-coded vendor TOPS comparison or one threshold shared across devices.
- No promise of bitwise equality from low-precision prediction.
- No cache artifact reuse across an unverified runtime/driver/device change.
- No per-worker session storm in fork, mirai, or other parallel workflows.

## Definition of done

The feature is complete when:

1. repository shape profiling identifies a genuine batched prediction target;
2. build-time probes and portable stubs work on CPU-only and cross-compiled
   installations;
3. runtime diagnostics distinguish compiled provider, loaded provider, detected
   NPU, graph placement, selected route, and fallback reason;
4. an immutable prediction plan and cached-session lifecycle are implemented;
5. logistic/fractional-logit frozen-weight batching passes correctness and
   end-to-end performance gates;
6. at least Apple plus two ONNX provider families have reproducible hardware
   reports before describing the abstraction as cross-vendor;
7. FP16 and every enabled quantized mode have model/shape-specific validation;
8. tuning persists only against a complete compatibility fingerprint;
9. existing training and statistical inference defaults remain unchanged; and
10. documentation gives measured useful/losing shape regions rather than a
    blanket “NPU enabled” claim.

## Recommended order

TODO-1–4 (measure real shapes and overhead) → TODO-15–18 (prove a provider-neutral
batched logistic plan on CPU/reference plus one NPU) → TODO-21–26 (precision
contract) → TODO-5–14 (production build/runtime detection) → TODO-27–31
(caching, tuning, and failure handling) → TODO-19–20 (additional graphs and
deployment API).

The first prototype should use a frozen logistic/fractional-logit prediction
graph, large static row batches, FP16, a warmed session, and a CPU FP64
reference. The first negative control must be current-style `p=5`, `q=1` so the
dispatcher proves it can decline inappropriate hardware.

## References

Repository evidence:

- `EDI/src/gcomp_speedups.cpp:96-125,150-158,175-288,384-502,545-583`
- `EDI/src/fast_ordinal_regression.cpp:527-678`
- `EDI/src/robust_post_fit_speedups.cpp:71-387`
- `EDI/R/inference_all_abstract_rand_bootstrap.R:201-361,639-691`
- `EDI/R/simulations_framework.R:292-4284`
- `arm_hardware.md:167-435`
- `intel_hardware.md:238-368`
- `memory_side_improvements.md:218-474`

Primary runtime/vendor documentation:

- [Apple Core ML compute units](https://developer.apple.com/documentation/coreml/mlcomputeunits)
- [Apple Core ML](https://developer.apple.com/documentation/coreml/)
- [Apple Core ML batch provider](https://developer.apple.com/documentation/coreml/mlbatchprovider/)
- [ONNX Runtime execution providers](https://onnxruntime.ai/docs/execution-providers/)
- [ONNX Runtime CoreML Execution Provider](https://onnxruntime.ai/docs/execution-providers/CoreML-ExecutionProvider.html)
- [OpenVINO NPU device](https://docs.openvino.ai/2025/openvino-workflow/running-inference/inference-devices-and-modes/npu-device.html)
- [ONNX Runtime OpenVINO Execution Provider](https://onnxruntime.ai/docs/execution-providers/OpenVINO-ExecutionProvider.html)
- [AMD Ryzen AI model compilation and deployment](https://ryzenai.docs.amd.com/en/latest/modelrun.html)
- [ONNX Runtime QNN Execution Provider](https://onnxruntime.ai/docs/execution-providers/QNN-ExecutionProvider.html)
- [ONNX Runtime quantization](https://onnxruntime.ai/docs/performance/model-optimizations/quantization.html)
