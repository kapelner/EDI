# Language Bindings Beyond Python

Date: 2026-08-27

Status: feasibility and implementation plan; effort estimates are planning
ranges, not measured delivery times.

> **Depends on:** the completed standalone-core work in
> `../finished_features/sexp_removal_rcppeigen_conversion_spec.md` and the
> existing Python package in
> `../finished_features/python_bindings_package_spec.md`. (Global ordering:
> see `_master.md`.)

## Executive recommendation

Additional bindings are feasible, but EDI should **not** create nine new
handwritten C++ boundary layers modelled directly on pybind11. That would turn
every kernel addition, validation fix, result-field change, BLAS issue, and
binary release into a nine-language synchronization problem.

The maintainable architecture is:

1. keep `R/EDI/src` as the single mathematical implementation;
2. introduce one small, versioned, exception-safe **C ABI** over the
   `EDI_CORE_ONLY` kernels;
3. describe the public kernel surface once in a machine-readable manifest;
4. generate each language's low-level declarations, documentation skeleton,
   and conformance cases from that manifest; and
5. handwrite only the thin, idiomatic array/result/error layer for each
   ecosystem.

There are two useful orders. **Demand order** estimates how many people would
actually use EDI; **delivery order** also accounts for cost, CI access, and
shared infrastructure. They should not be conflated. By expected users, the
package-level order is:

1. MATLAB;
2. JVM (mostly Java, then Kotlin and Scala) and Stata, with overlapping
   uncertainty ranges;
3. .NET (overwhelmingly C#, with small F#/Visual Basic tails);
4. Julia;
5. server-side JavaScript/TypeScript;
6. Rust and Go;
7. Ruby, PHP, and Perl.

The C ABI remains first in delivery order because it enables nearly every
binding, even though few end users will consume the C SDK directly. The
detailed estimates and assumptions are in “Demand model and user-count
priority” below.

This plan recommends the following delivery order:

| Priority | Binding | Recommendation |
|---|---|---|
| Foundation | C ABI / C SDK | **Build first.** It is infrastructure for every other binding and is useful directly from C, C++, Fortran, and many scientific systems. |
| Tier 1 | Julia | **Build first after the C ABI as the lowest-cost scientific proof.** Strong fit for numerical and statistical computing and direct `@ccall` support, although its likely audience is smaller than MATLAB/JVM/Stata. |
| Tier 1 | JVM package: Java + Kotlin + Scala | **Build one package, not three.** One of the two largest expected non-Python audiences because of reach in health, finance, experimentation, and production data systems. |
| Tier 1 | .NET package: C# + F# + Visual Basic | **Build one package, not three.** Particularly relevant to clinical, government, finance, and enterprise Windows environments. |
| Tier 1 | MATLAB | **Highest estimated user demand; build as soon as licensed CI and a maintainer are available.** Serious engineering, biostatistics, signal-processing, and academic demand; proprietary tooling raises maintenance. |
| Tier 1 | Stata | **Build a focused estimation-command layer after the C ABI.** Expected demand is comparable to JVM despite a much smaller total population because applied econometrics, epidemiology, policy, and social-science inference are central workloads. |
| Tier 2 | JavaScript / TypeScript for Node.js | **Build for server-side Node only at first.** Use Node-API; browser support is a separate WebAssembly project. |
| Tier 2 | Rust | **Build a safe crate over the C ABI.** Technically clean and maintainable, but user demand for applied inference is smaller than Julia/JVM/.NET/MATLAB/Stata. |
| Tier 2 | Go | **Build only with demonstrated service-side demand.** Straightforward through cgo, but native-library distribution and cross-compilation are costly. |
| Tier 3 | Ruby | **Community-supported pilot.** Feasible through FFI or a native extension, but statistical demand is limited. |
| Tier 3 | PHP | **Do not promise first-party binaries initially.** FFI is deployment-policy-sensitive and statistical inference is not a central PHP workload. |
| Tier 3 | Perl | **Community-supported only.** XS/FFI is feasible, but expected new demand is too small for first-party release engineering. |

Two additional languages are recommended beyond the user's original list:
**Julia** and **MATLAB**. One domain product is also recommended: **Stata**.
These are higher priorities than Ruby, Perl, or PHP because their users
regularly perform numerical modelling or formal statistical inference. Also
include Kotlin/Scala and F#/Visual Basic in the JVM/.NET deliverables at
negligible native-layer cost; do not publish separate native binaries for
them.

## Scope: kernels, not a rewrite of the R package

There are two very different meanings of “EDI bindings”:

### Level K: standalone numerical kernels

This is the scope of the current Python package and the scope recommended for
the first multi-language program. It includes model fitting, covariance and
standard-error calculations, confidence-interval/test utilities, survival
statistics, and result diagnostics exposed by the native kernels.

This level is feasible. `python/CMakeLists.txt:8-15,171-223` already compiles
the same `R/EDI/src` sources under `EDI_CORE_ONLY`, without R or Rcpp, and
`python/cpp/bindings_module.cpp:20-32` exposes the response-family modules.
The current Python stub lists roughly sixty public kernel functions
(`python/src/edi_kernels/_core.pyi:1-10`).

### Level W: full EDI workflows and object model

This would reproduce the R6 design classes, mutable experiment state,
randomization, response ingestion, inference-class registry, lazy components,
reporting, and R-specific extension conventions in each language.

This level is **not maintainable as independent native bindings**. If it is
ever required, expose one language-neutral workflow/session protocol from the
R implementation or move the orchestration contract into a standalone core.
Possible transports are an in-process opaque-handle C API, a local process
with Arrow/JSON-RPC, or a service API. Choosing among them is a separate 2.0.0
architecture decision. No language in this plan may market kernel coverage as
full parity with the R package.

## Current architectural assets and gaps

### Assets already present

- `R/EDI/src` is the source of truth; the Python package does not copy live
  kernel sources (`python/CMakeLists.txt:8-15`).
- `EDI_CORE_ONLY` replaces Rcpp/R-specific branches with Eigen, CBLAS, and
  standalone math (`python/CMakeLists.txt:171-176`).
- The standalone build already resolves C++20, Eigen, LBFGSpp, OpenMP, and
  BLAS portability (`python/CMakeLists.txt:43-176,254-318`).
- Kernel families are already grouped into fast-math, GLMM, continuous,
  binary, count, proportion, ordinal, incidence, and survival binding units
  (`python/cpp/bindings_module.cpp:10-31`).
- `edi::ResultMap` is a portable result container. The Python-specific
  conversion is isolated in `python/cpp/result_map_pybind.h:4-31`.
- `R/scripts/check_core_no_rcpp.py` statically enforces the R-free core
  boundary.

### Gaps that must be closed once, centrally

- The exported interface is C++, so names, exceptions, STL types, Eigen
  types, and compiler ABI are not a durable cross-language contract.
- Argument lists and documentation are handwritten in the pybind11 files and
  again in `_core.pyi`; they are not generated from one schema.
- `ResultMap` is convenient inside C++ but is not an ABI-stable result type.
- Ownership, allocation, string lifetime, thread-local errors, missing
  values, index bases, matrix order, and integer width have no language-neutral
  specification.
- The Python extension compiles kernel sources into its own module. Repeating
  that for every language would multiply binary size, build logic, and BLAS /
  OpenMP collision risk.
- Packaging support must cover Windows x86-64, macOS x86-64/arm64, and Linux
  x86-64/aarch64 before “supported” means more than source-buildable.

## Target architecture

### 1. A narrow, versioned C ABI

Create `native/` (final name subject to repository convention) with:

- `include/edi/edi.h`: C99-compatible declarations only;
- `src/edi_c_api.cpp`: `extern "C"` adapters that catch every C++ exception;
- `edi_api_version()` and compile/runtime version compatibility checks;
- fixed-width integers, `size_t` dimensions, `double` numeric arrays, and
  explicit column/row strides;
- opaque handles only where a result cannot be returned into caller-owned
  buffers safely;
- `edi_status` return values plus `edi_last_error()` with thread-local storage;
- explicit `edi_free()` for all EDI-owned allocations;
- no STL, Eigen, exceptions, compiler-specific enums, callbacks, or global
  mutable configuration in the ABI; and
- symbol visibility controls plus an exported-symbol allowlist.

Prefer a two-call result protocol: first query required output sizes and field
metadata, then fill caller-owned buffers. For heterogeneous results, use a
versioned tagged field view:

```c
typedef enum edi_value_kind {
    EDI_VALUE_NULL = 0,
    EDI_VALUE_F64 = 1,
    EDI_VALUE_I64 = 2,
    EDI_VALUE_BOOL = 3,
    EDI_VALUE_STRING = 4,
    EDI_VALUE_F64_VECTOR = 5,
    EDI_VALUE_I64_VECTOR = 6,
    EDI_VALUE_F64_MATRIX = 7
} edi_value_kind;
```

The detailed struct must specify alignment, constness, dimensions, strides,
and ownership. Never expose the memory layout of `edi::ResultMap` itself.

### 2. One API manifest

Add a checked-in manifest such as `native/api/edi_kernels.yaml` containing,
for every public function:

- stable API name and numeric ID;
- family and availability version;
- arguments, scalar types, shapes, constraints, optional/default values, and
  whether an array may be mutated;
- 0/1-based index semantics and matrix-order semantics;
- return fields, their types/shapes, and conditions under which they exist;
- error conditions and convergence/status fields;
- documentation source; and
- canonical conformance fixtures and tolerances.

Generate the C declaration/adapters where practical, language declarations,
API inventories, and test vectors from this manifest. Keep statistical
implementation and nontrivial language ergonomics handwritten.

The generator must have a `--check` mode that fails on drift without compiling.
A newly exposed kernel is incomplete until its manifest record and generated
surfaces are updated.

### 3. Shared native artifacts

Publish `libedi_core` once per supported target and reuse it from bindings.
The artifact contains the standalone kernels plus the C ABI, with one BLAS and
one OpenMP policy. Each language package either:

- bundles the matching library and verifies its checksum/version; or
- for ecosystems that strongly prefer source builds, builds the same CMake
  target from the vendored release source.

Do not load the Python `_core` extension from another language and do not make
Python a runtime dependency. It is a useful parity oracle, not an ABI.

### 4. Conformance before idioms

Every language runs the same serialized fixtures covering:

- one successful call per kernel;
- defaults and every optional-argument branch;
- invalid dimensions, invalid categories, missing/non-finite values, and
  unsupported options;
- result field names, shapes, convergence status, and error categories;
- deterministic parity with C++, R, and Python at declared tolerances; and
- repeated calls, concurrent calls, allocation failure paths, and cleanup.

Language-specific tests then cover idiomatic arrays, exceptions/errors,
documentation examples, package installation, and library discovery.

## Demand model and user-count priority

### What is being estimated

No registry exposes the number of humans who would use an unbuilt EDI binding,
and raw package downloads are heavily inflated by CI, mirrors, dependency
resolution, and repeated installations. Absolute global-user claims would
therefore be false precision.

For planning, define an **annual active consumer** as one person or team that
uses the binding for real analysis or a deployed workload at least quarterly.
Estimate the mature year-3 audience under these assumptions:

- the binding covers the same Level-K kernels as Python;
- installation, documentation, examples, and supported binaries are equally
  good across ecosystems;
- EDI receives ordinary registry/search/conference visibility, not a major
  commercial marketing campaign;
- the binding has one responsive maintainer; and
- the Python package has **10,000 annual active consumers** at the same point.

The last assumption is a scale anchor, not a claim about current Python use.
If measured Python active use is 1,000, divide every count below by ten; if it
is 50,000, multiply by five. Until privacy-respecting telemetry, opt-in user
surveys, citations, or defensible registry analytics exist, the relative
ranges are more trustworthy than the displayed absolute counts.

The estimates combine four deliberately separate judgments:

1. total ecosystem reach;
2. the share of users who routinely need formal statistical inference;
3. how differentiated EDI's kernels are from native alternatives; and
4. installation and institutional-adoption friction.

General developer popularity is only the first factor. For scale, the 2025
Stack Overflow survey reports broad use of JavaScript (66%), TypeScript
(43.6%), Java (29.4%), C# (27.8%), PHP (18.9%), Go (16.4%), Rust (14.8%),
Kotlin (10.8%), and Ruby (6.4%). Those figures do **not** imply comparable EDI
demand: most web development does not fit GLMMs, survival models, or
randomization-confidence procedures. Conversely, MathWorks reports five
million MATLAB users, while Stata describes a much narrower population of
quantitative researchers across many disciplines; both populations have much
higher inference propensity. Julia reports over 100 million cumulative
downloads and more than 12,000 registered packages, but downloads are not
unique users.

### Ranked package audiences

Ranges below are deliberately wide and overlapping. Rank is by the midpoint,
but adjacent rows with overlapping ranges should be treated as ties until EDI
has pilot data.

| Demand rank | Package / ecosystem | Estimated year-3 annual active consumers per 10,000 Python consumers | Relative to Python | Confidence | Why |
|---:|---|---:|---:|---|---|
| 1 | MATLAB | **2,000–6,000** | 20–60% | Medium | Five-million-user installed base claimed by MathWorks; modelling is a core workload; native package installation and licenses reduce conversion. |
| 2 | Stata | **1,200–4,000** | 12–40% | Low-medium | Smaller total population, but exceptionally high inference concentration and good fit for EDI's nonstandard estimators. No reliable public active-user count. |
| 3 | JVM: Java + Kotlin + Scala | **1,500–3,500** | 15–35% | Medium | Very large production/enterprise reach; only a small share needs embedded inference, but that small share is still substantial. |
| 4 | .NET: C# + F# + Visual Basic | **1,000–3,000** | 10–30% | Medium | Large enterprise, health, finance, government, and Windows reach; lower interactive-statistics concentration than MATLAB/Stata. |
| 5 | Julia | **700–2,500** | 7–25% | Medium | Smaller language population but very high numerical/scientific fit, low calling friction, and strong likelihood that users try a novel kernel package. |
| 6 | Node.js JavaScript/TypeScript | **300–1,200** | 3–12% | Low-medium | Enormous language population but low inference propensity; strongest use case is backend experimentation/analytics services. |
| 7 | Rust | **120–600** | 1.2–6% | Low | Growing systems audience and good native-library fit, but applied statistical inference is uncommon. |
| 8 | Go | **100–500** | 1–5% | Low | Large service ecosystem, offset by low inference propensity and cgo deployment friction. |
| 9 | Ruby | **30–180** | 0.3–1.8% | Low | Some analytics/business applications, but a small modern inference audience and native-gem burden. |
| 10 | PHP | **20–120** | 0.2–1.2% | Low | Large web population but very low statistical-inference propensity; FFI is often restricted in production. |
| 11 | Perl | **10–70** | 0.1–0.7% | Low | Technically capable scientific/legacy users, but a very small likely new-package audience. |

The JVM and .NET rows are package counts, not sums of independently acquired
language audiences. Expected language shares within those packages are:

- JVM: **Java 70–85%**, Kotlin **10–20%**, Scala **5–15%**;
- .NET: **C# 85–95%**, F# **3–10%**, Visual Basic **2–8%**.

Thus separate Kotlin, Scala, F#, or Visual Basic native packages would not
create proportionate new audiences; one shared package with idiomatic examples
captures almost all of their demand.

For a language-by-language view of the same model (still anchored to 10,000
annual active Python consumers), the approximate order is:

| Approximate rank | Language/product | Estimated annual active consumers | Packaging note |
|---:|---|---:|---|
| 1 | MATLAB | **2,000–6,000** | MATLAB package/interface |
| 2 | Stata | **1,200–4,000** | Domain product rather than a general-purpose language binding |
| 3 | Java | **1,100–3,000** | Primary audience for the shared JVM package |
| 4 | C# | **850–2,800** | Primary audience for the shared .NET package |
| 5 | Julia | **700–2,500** | Standalone Julia package |
| 6 | JavaScript/TypeScript (Node) | **300–1,200** | One Node package; TypeScript is declarations/ergonomics, not another native artifact |
| 7 | Kotlin | **150–700** | Shared JVM package |
| 8–10 | Rust | **120–600** | Standalone Rust crates |
| 8–10 | Go | **100–500** | Standalone cgo package |
| 8–10 | Scala | **75–500** | Shared JVM package |
| 11 | F# | **30–250** | Shared .NET package |
| 12 | Visual Basic | **20–200** | Shared .NET package; examples may be sufficient |
| 13 | Ruby | **30–180** | Community FFI gem |
| 14 | PHP | **20–120** | Community FFI wrapper |
| 15 | Perl | **10–70** | Community FFI module |

Do not sum this language table: Kotlin/Scala users may also identify as Java,
F#/Visual Basic users consume the C#-authored assembly, and JavaScript and
TypeScript heavily overlap. The package-level table is the correct input to
staffing and revenue/adoption decisions.

### Other candidates, ranked on the same scale

These are not recommended first-wave products, but their possible audiences
should not be confused with technical feasibility:

| Candidate | Estimated year-3 annual active consumers per 10,000 Python consumers | Demand interpretation |
|---|---:|---|
| SAS integration | **500–2,500** | Potentially large regulated clinical/enterprise audience, but only if an integration acceptable to locked-down SAS installations is designed and licensed test access exists. |
| SPSS integration | **200–900** | Meaningful social-science/education population, but extension/distribution friction and weaker differentiation than Stata. |
| Browser WebAssembly | **100–700** | Could enable education, demos, and private client-side analysis; this is a separate product whose download size and numerical runtime may suppress use. |
| C/C++ SDK direct users | **150–700** | Small direct audience; strategically essential because many more users arrive indirectly through bindings. Do not judge it by direct consumers. |
| Fortran module | **40–250** | Small but inference-heavy legacy scientific audience; cheap once the C ABI exists. |
| Wolfram Language | **30–200** | Technically plausible research niche, below MATLAB/Julia priority. |
| Swift | **20–150** | Only compelling for on-device/Apple analysis; otherwise little inference demand. |

### Decisions implied by estimated users

1. **Seek MATLAB CI/maintainer access immediately.** It has the largest
   plausible audience; its later delivery position is caused by proprietary
   infrastructure, not weak demand.
2. **Treat Stata as Tier 1, not an optional curiosity.** A focused set of
   differentiated estimators may outperform a mechanically complete JVM or
   .NET binding in actual analyst adoption.
3. **Ship JVM and .NET as ecosystem packages.** Java and C# do the acquisition;
   Kotlin/Scala/F#/Visual Basic support is cheap retention and accessibility.
4. **Use Julia as the first engineering proof after C.** It ranks fifth by
   expected users but likely first by users gained per implementation week.
5. **Require pilot evidence before Node/Rust/Go.** Their broad developer
   populations otherwise create a misleading demand signal.
6. **Do not fund first-party Ruby/PHP/Perl binary matrices from expected users
   alone.** Provide the binding-author kit and accept community ownership.
7. **Re-estimate after each release.** Replace priors with active-user surveys,
   opt-in registry/download de-duplication, issue activity, dependent packages,
   citations, and named institutional deployments.

## Feasibility and maintainability by binding

Estimates assume Level K coverage, the C ABI and manifest already exist, about
sixty kernels, three desktop operating systems, and first-party binary
packages. “Initial” includes wrapper, docs, conformance tests, and baseline
packaging. “Annual” is steady-state maintainer effort after stabilization,
excluding major ABI changes. One engineer-week means one focused maintainer
week; calendar time may be longer because release systems and proprietary CI
are intermittent.

| Binding | Mechanism | Feasibility | Initial effort | Annual maintenance | Demand / value | Main risk |
|---|---|---:|---:|---:|---|---|
| C ABI / SDK | C99 shared library | High | 8–14 weeks | 3–6 weeks | Foundational; also unlocks C++, Fortran, Julia, MATLAB, Stata, and most FFIs | Designing an ABI that survives result/schema evolution |
| Julia | `@ccall` plus an artifact-backed Julia package | High | 3–5 weeks | 1–2 weeks | Very high fit for numerical/statistical researchers | Julia artifact matrix and column-major zero-copy details |
| Java | JDK Foreign Function and Memory API, with a compatibility decision for older JDKs | High | 5–8 weeks | 2–4 weeks | High production and institutional reach | JDK baseline, native extraction, off-heap lifetimes |
| Kotlin / Scala | Idiomatic façade over the same JAR/native artifacts | High | +1–2 weeks each | <1 week each | Useful in JVM data platforms | API ergonomics, not native engineering |
| C# | .NET `LibraryImport`/P/Invoke and `SafeHandle` | High | 4–7 weeks | 2–3 weeks | High enterprise, clinical, finance, and Windows reach | RID-native packaging and BLAS/OpenMP DLL discovery |
| Visual Basic | Thin .NET façade or examples over the C# assembly | High | +0.5–1 week | Negligible | Legacy institutional users | Creating a needless duplicate package |
| F# | Thin functional façade over the same .NET assembly | High | +1–2 weeks | <1 week | Quantitative finance and research niches | Keeping façade aligned with C# API |
| JavaScript / TypeScript (Node) | Node-API addon with TypeScript declarations | High | 5–8 weeks | 2–4 weeks | Medium; experimentation and analytics services | Event-loop blocking, native prebuild matrix, number/int semantics |
| JavaScript (browser) | WebAssembly/Emscripten | Medium-low | 10–18 weeks | 4–8 weeks | Potential education/private-client compute | BLAS, OpenMP/threads, binary size, memory copying, browser isolation |
| Rust | `-sys` crate generated from C plus safe wrapper crate | High | 4–7 weeks | 1–3 weeks | Medium-low current inference demand, high systems value | Sound ownership/lifetime design and bundled-native policy |
| Go | cgo package over C ABI | High locally; medium for distribution | 4–7 weeks | 2–4 weeks | Medium-low; useful in services | Cross-compilation and the `CGO_ENABLED` native toolchain requirement |
| MATLAB | Published C/C++ library interface or MEX gateway | High technically | 5–9 weeks | 3–6 weeks | High in engineering, imaging, signal processing, and academia | Licensed CI, MATLAB release compatibility, platform binaries |
| Stata | C plugin + ado command layer, or Java plugin reusing the JVM binding | Medium-high | 6–10 weeks for a focused subset | 3–6 weeks | High concentration of serious inference users | Stata result-posting conventions, licensed CI, per-platform plugins |
| Ruby | FFI gem first; C extension only if needed | High technically | 3–5 weeks | 1–2 weeks | Low | Native gem packaging outweighing likely use |
| PHP | FFI wrapper; Zend extension only with proven demand | Medium | 2–4 weeks for FFI | 1–2 weeks | Low for statistical inference | FFI may be disabled/restricted in production; request-process lifecycle |
| Perl | FFI::Platypus first; XS only if necessary | High technically | 3–5 weeks | 1–2 weeks | Very low new demand | Small maintainer/user pool and CPAN platform coverage |

The table is deliberately less optimistic than “the FFI call works.” Shipping
and maintaining native binaries, numerical dependencies, parity tests,
documentation, and security fixes are most of the work.

### Aggregate maintainability

If all requested languages plus the recommended Julia/MATLAB/Stata bindings
are first-party and fully binary-supported, budget approximately **18–32
engineer-weeks per year** after the shared C ABI exists. The likely release
matrix exceeds 100 package/runtime/OS/architecture cells before version
combinations are counted.

A tiered ownership model reduces this to roughly **10–18 engineer-weeks per
year**:

- first-party: C ABI, Python, Julia, Java/JVM, .NET, MATLAB, and Stata, with
  MATLAB/Stata conditioned on licensed CI and named maintainers;
- first-party only after usage evidence: Node, Rust, and Go;
- community-supported: Ruby, PHP, and Perl.

The largest maintainability multiplier is not the language count but the
number of separately authored API descriptions. Generation and shared
fixtures are therefore release gates, not optional cleanup.

## Where serious statistical inference demand is concentrated

### Highest-value additions

1. **MATLAB**: common in engineering, biomedical imaging, signal processing,
   and quantitative research. It officially supports shared C/C++ libraries
   and MEX interfaces. The business case is strong if licensed CI and a
   maintainer are available.
2. **Stata**: smaller general-programming audience, but a large fraction of
   users perform econometric, epidemiological, public-policy, and social-
   science inference. EDI's unusual estimators may be more differentiated
   here than in a general-purpose ecosystem. Start with commands for kernels
   that fill obvious Stata gaps; do not mechanically expose all sixty.
3. **JVM and .NET**: inference increasingly runs inside production data
   systems, clinical platforms, fraud/risk services, experimentation
   platforms, and regulated enterprise applications. These bindings provide
   deployment reach even when interactive statisticians prefer R/Python.
4. **Julia**: the cleanest new scientific-computing binding. Its native C
   interface can call a C-exported shared library directly, and its array
   model is naturally compatible with dense numerical kernels. Its expected
   audience is smaller, but its users-per-engineering-week return may be the
   best of all additions.

### Useful but demand-gated

- **Node.js/TypeScript** is valuable for experimentation services and analyst
  tools. Native synchronous calls must run off the event loop for expensive
  fits. Browser JavaScript is a different product and should wait.
- **Rust and Go** are valuable for embedding inference in reliable services
  and data infrastructure. They are strategically useful, but neither is a
  primary language for applied statisticians today.
- **Ruby, PHP, and Perl** can all call a C library. Technical possibility is
  not sufficient justification for permanent first-party binary release
  obligations.

### Other candidates

- **Fortran**: support through the C ABI and a small `ISO_C_BINDING` module;
  low incremental cost, useful for legacy scientific codes. Generate this
  module as an SDK example rather than run a separate product initially.
- **SAS**: serious use in regulated clinical and enterprise statistics, but
  integration, licensing, CI access, and distribution are proprietary and
  product-specific. Prefer a file/service bridge proof of concept only after
  a named user supplies requirements and test access.
- **SPSS**: similar logic to SAS; support only with a concrete institutional
  sponsor.
- **Wolfram Language**: LibraryLink is technically viable, but expected EDI
  demand is below Julia/MATLAB/Stata.
- **Swift**: easy to place over the C ABI and attractive on Apple platforms,
  but not a serious inference priority unless EDI targets on-device analysis.

## Language-specific design decisions

### Python: migrate the existing package onto the C ABI

Once the C ABI exists, Python should probably consume it too. The target
architecture is:

```text
R/EDI/src C++ kernels
          ↓
     libedi_core C ABI
          ↓
  generated Python wrapper
          ↓
     public edi_kernels API
```

A Python-level `ctypes` or CFFI wrapper can pass contiguous NumPy buffers
directly to `libedi_core`, translate C-ABI status codes into Python exceptions,
and construct the existing result dictionaries. The public `edi_kernels`
function names, defaults, and return dictionaries should remain unchanged;
this is an internal backend migration, not a Python API redesign.

This would replace much of the current duplicated surface, measured
2026-08-27:

- **4,317 lines** of handwritten `python/cpp/bindings_*.cpp`, including the
  small module-registration file;
- **36 lines** of pybind-specific result conversion in
  `python/cpp/result_map_pybind.h`; and
- **1,618 lines** of Python type stubs in
  `python/src/edi_kernels/_core.pyi`.

Not all **5,971 lines** disappear. Python still needs documentation, idiomatic
validation, result objects/dictionaries, and type information. The API
manifest can, however, generate low-level declarations, defaults, result
schemas, type-stub signatures, documentation skeletons, and repetitive glue.

Main benefits:

- one native contract for every language;
- Python no longer needs separate mathematical binding logic;
- kernel additions flow through the manifest into Python automatically;
- no pybind11 or Python development headers in the final pure-Python-wrapper
  design;
- potentially one platform wheel per OS/architecture rather than separate
  CPython 3.9–3.13 wheels;
- the same `libedi_core` binary can be tested independently of Python; and
- public `edi_kernels` names and return dictionaries remain unchanged.

Performance should remain effectively unchanged for model-fitting calls.
NumPy arrays can be passed without copying when they have the required
`float64` or integer dtype, dimensions, alignment, and contiguous layout. The
FFI call overhead is insignificant compared with fitting a regression or
GLMM, but this must be measured rather than assumed for the smallest utility
kernels. Scalar math functions should remain vectorized across the ABI rather
than making millions of individual foreign-function calls.

Important caveats:

- Python still needs a thin ergonomic layer for NumPy validation, optional
  arguments, exceptions, dictionaries, type hints, and documentation.
- The C ABI must support caller-owned output buffers or carefully managed
  result handles.
- Wheels still need to bundle and locate the correct native library and its
  BLAS/OpenMP dependencies.
- Noncontiguous, unaligned, or incorrectly typed arrays may require explicit
  copies; wrappers must never silently reinterpret incompatible memory.
- The migration must not delete pybind11 immediately.
- The claimed wheel-matrix reduction must be verified with the selected
  backend and wheel tags; bundling a platform-specific shared library still
  requires separate OS/architecture artifacts.

Migrate incrementally:

1. Implement the C ABI and shared conformance fixtures.
2. Generate Python low-level declarations from the API manifest.
3. Add an internal C-ABI Python backend while keeping the public API
   unchanged.
4. Run every existing Python test against both the pybind11 and C-ABI
   backends, including omitted/default arguments and invalid inputs.
5. Benchmark array conversion, call overhead, result construction, and
   end-to-end model fitting.
6. Verify wheels and source installations on every supported platform from
   the actual built artifacts.
7. Make the C-ABI backend the default while retaining a documented fallback
   for one release cycle.
8. Remove pybind11 only after the compatibility window closes with numerical,
   API, performance, packaging, and dependency-resolution parity established.

A smaller intermediate option is to retain a tiny pybind11 module that calls
the C ABI. That removes kernel-specific C++ duplication but retains pybind11,
Python development headers, and the CPython extension build matrix. A pure
Python `ctypes` or CFFI layer provides the larger maintenance reduction and is
the preferred endpoint if its performance and packaging gates pass.

### Julia

- Use direct `@ccall`; do not add a C++ wrapper dependency.
- Ship native artifacts through the Julia artifact system and present
  matrices as column-major strided buffers.
- Return a typed `FitResult` with stable common fields and an `extras` map for
  family-specific fields.
- Permit zero-copy inputs when element type, stride, and ownership are safe;
  copy explicitly otherwise.

### JVM: Java, Kotlin, and Scala

- Prefer the finalized Foreign Function and Memory API on a modern JDK.
  Record a decision gate for users pinned to older Java: either support JNI as
  a second low-level bridge or set a modern minimum JDK.
- Publish one JAR plus platform-classified native artifacts. Kotlin and Scala
  consume it; neither gets another native implementation.
- Use `AutoCloseable`/arenas for native lifetime and typed result records.
- Test native access flags, classloader extraction, and simultaneous versions
  in application servers.

### .NET: C#, F#, and Visual Basic

- Generate `[LibraryImport]` declarations and wrap native handles with
  `SafeHandle`.
- Publish one NuGet package with runtime identifiers and one canonical C# API.
- F# may add a small option/result-oriented façade. Visual Basic should have
  examples and discoverable overloads, not a duplicate native package.
- Test Windows DLL search, macOS/Linux shared-library resolution, trimming,
  and Native AOT constraints.

### Node.js and browser JavaScript

- Use stable Node-API rather than direct V8 APIs.
- Publish TypeScript declarations generated from the manifest.
- Provide synchronous methods only for genuinely small kernels; expose
  asynchronous worker-thread variants for fits that can block.
- Never silently coerce 64-bit indices through JavaScript `number` when they
  exceed the exact integer range.
- Treat WebAssembly as a separate feasibility spike. It needs its own BLAS,
  threading, memory, download-size, and numerical-equivalence evaluation.

### Rust

- Generate an unsafe `edi-kernels-sys` crate from the C header, not the C++
  headers; C++ exception and template boundaries are unsuitable.
- Handwrite the safe `edi-kernels` crate with slices, shape validation,
  `Result`, RAII, and owned result types.
- Decide whether published crates bundle native artifacts or require a system
  library; support both only if CI tests both.

### Go

- Use cgo against the C ABI and expose ordinary slices plus explicit matrix
  dimensions/order.
- Document that pure-Go, `CGO_ENABLED=0`, and easy cross-compilation are not
  supported by the native package.
- Benchmark call/copy overhead, but expect fitting time to dominate for the
  substantive models.

### MATLAB

- Prototype both the published shared-library interface and a single MEX
  dispatcher. Choose based on release support, array copying, error quality,
  and packaging—not microbenchmark alone.
- Use MATLAB-native structs/tables and standard estimation-result conventions.
- Maintain an explicit supported-release window; do not claim every historical
  MATLAB version.

### Stata

- Prefer a focused ado/Mata command surface that reads Stata variables,
  invokes the shared core, and posts `e(b)`, `e(V)`, sample markers,
  convergence details, and standard metadata as a normal estimation command.
- Compare a C plugin with a Java plugin that reuses the JVM work. The C plugin
  minimizes layers; the Java route may simplify cross-platform development
  because Stata exposes a Java integration API.
- Start with EDI models that are absent or weak in Stata, not OLS/logistic
  regression merely because they are easy demos.

### Ruby, PHP, and Perl

- Begin with libffi-style wrappers (Ruby FFI, PHP FFI, Perl FFI::Platypus)
  and source-only/community releases.
- Move to CRuby C extensions, Zend extensions, or Perl XS only when profiling
  or deployment constraints prove FFI insufficient.
- Keep one function/result convention across all three; their small expected
  user bases cannot justify custom object hierarchies.

## Proposed implementation

### Phase 0: product and compatibility decisions

- [ ] **TODO-1: Confirm Level K as the supported scope.** Record explicitly
  that the first program binds standalone kernels, not the full R6 workflow.
- [ ] **TODO-2: Inventory and freeze the v1 kernel surface.** Reconcile R,
  Python bindings, `_core.pyi`, documentation, defaults, and result fields;
  classify experimental kernels before they enter the ABI.
- [ ] **TODO-3: Choose the first-party tier and establish the demand
  baseline.** Recommended: C, Python, Julia, JVM, .NET, MATLAB, and Stata,
  with the last two conditional on maintainer/licensed-test access. Record
  measured Python active-use proxies so the demand table can be rescaled.
  Mark Node/Rust/Go demand-gated and Ruby/PHP/Perl community-supported.
- [ ] **TODO-4: Set platform policy.** Minimum recommended first-party matrix:
  Windows x86-64, macOS x86-64/arm64, Linux x86-64/aarch64. Record runtime
  minimums and an end-of-life policy for each package ecosystem.
- [ ] **TODO-5: Decide GPL distribution wording.** Confirm that every package
  clearly communicates the core's GPL-3.0-only license and that registry
  metadata/source offers are consistent.

Acceptance gate: scope, ownership tier, supported targets, and package names
are written down before the ABI becomes public.

### Phase 1: build the shared C ABI and manifest

- [ ] **TODO-6: Design `edi.h`.** Specify types, calling convention, symbol
  visibility, status taxonomy, thread-local error retrieval, dimensions,
  strides, missing values, index bases, ownership, allocation, and versioning.
- [ ] **TODO-7: Implement one vertical slice.** Use OLS, logistic regression,
  one GLMM, one ordinal model, one survival model, and one heterogeneous
  utility result to exercise every important type/shape/error pattern.
- [ ] **TODO-8: Create the API manifest and generator.** Generate declarations,
  documentation skeletons, inventories, and conformance fixture drivers. Add
  a no-compile drift check.
- [ ] **TODO-9: Complete C adapters for the frozen surface.** Catch all C++
  exceptions, validate before constructing Eigen views, and make cleanup safe
  after partial failure.
- [ ] **TODO-10: Build `libedi_core` once.** Extract reusable CMake targets
  from the Python-specific build while preserving `EDI_CORE_ONLY`, dependency
  pinning, portable/native profiles, unity builds, BLAS, and OpenMP behavior.
- [ ] **TODO-11: Add ABI governance.** Use semantic API/ABI versions, an
  exported-symbol allowlist, ABI comparison tooling, deprecation windows, and
  a policy that v1 structs grow only through size/version fields or new types.
- [ ] **TODO-12: Publish the C SDK.** Include headers, CMake/pkg-config
  metadata, checksums/SBOM, source archive, examples, and platform artifacts.

Acceptance gate: a plain C program can run the vertical slice and the full
surface on every supported target; sanitizers and invalid-input tests find no
leaks, exception escapes, or ownership ambiguity.

### Phase 2: prove generation and parity in two contrasting ecosystems

- [ ] **TODO-12a: Migrate Python through a dual-backend compatibility
  window.** Generate the C-ABI declarations and type stubs, implement the
  NumPy/result/error layer, run the complete existing suite against both
  backends, publish and install-test real artifacts, make C ABI the default,
  and remove pybind11 only after one successful compatibility release.
- [ ] **TODO-13: Implement Julia.** Use it to validate direct C calls,
  column-major arrays, artifacts, and scientific-language ergonomics.
- [ ] **TODO-14: Implement .NET.** Use it to validate generated declarations,
  managed lifetimes, Windows packaging, and multi-language reuse by C#, F#,
  and Visual Basic.
- [ ] **TODO-15: Run shared conformance fixtures.** Require parity against C,
  R, and Python on all function families, not only the vertical slice.
- [ ] **TODO-16: Measure maintenance automation.** Simulate adding one kernel
  and one result field. If more than the manifest, core adapter, idiomatic
  wrapper, and tests require manual edits, fix the architecture before adding
  more languages.

Acceptance gate: one scientific language and one managed enterprise runtime
ship from the same native artifacts without duplicated mathematical glue.

### Phase 3: high-value ecosystem expansion

- [ ] **TODO-17: Implement the JVM package.** Resolve modern FFM versus legacy
  JNI support and include Kotlin/Scala smoke examples.
- [ ] **TODO-18: Implement MATLAB or Stata first.** Choose the one with a
  committed maintainer, licensed CI, and concrete users. Validate native
  statistical result conventions, not only function calls.
- [ ] **TODO-19: Implement the second domain package only after adoption
  review.** Require evidence from downloads, issues, citations, named pilots,
  or contributors before accepting its recurring CI/release cost.
- [ ] **TODO-20: Add cross-runtime coexistence tests.** Exercise EDI alongside
  common BLAS/OpenMP consumers in Java, .NET, MATLAB/Stata, Julia, R, and
  Python processes to find runtime collisions and oversubscription.

### Phase 4: demand-gated systems and service bindings

- [ ] **TODO-21: Implement Node.js/TypeScript.** Use Node-API and worker-thread
  async calls; keep browser/WebAssembly out of this task.
- [ ] **TODO-22: Implement Rust.** Publish separate raw and safe crates, audit
  all `unsafe` code, and test ownership under sanitizers/Miri where applicable.
- [ ] **TODO-23: Implement Go.** Make cgo and cross-compilation constraints
  prominent; test container deployment and cancellation semantics.
- [ ] **TODO-24: Reassess WebAssembly.** Proceed only if a named browser or
  edge-compute use case justifies the separate numerical runtime.

Each TODO in this phase is individually gated by a maintainer plus evidence of
demand. “The C ABI makes it possible” is not sufficient.

### Phase 5: community bindings

- [ ] **TODO-25: Publish a binding-author kit.** Provide the C header, manifest,
  generated declarations where available, fixtures, package naming rules,
  logo/license guidance, and a compatibility badge based on conformance.
- [ ] **TODO-26: Pilot Ruby FFI.** Promote it to first-party only after a
  maintainer and adoption threshold are met.
- [ ] **TODO-27: Pilot PHP FFI.** Document `ffi.enable` restrictions and do not
  recommend per-request library loading.
- [ ] **TODO-28: Pilot Perl FFI.** Prefer FFI::Platypus; use XS only for a
  demonstrated limitation.
- [ ] **TODO-29: Generate Fortran `ISO_C_BINDING` examples.** Keep them in the
  C SDK unless a Fortran community requests a registry package.

## Release and CI policy

### Required release lanes

For every first-party binding:

- build or consume the same tagged `libedi_core` artifacts;
- install into a clean environment from the actual registry artifact, not the
  checkout;
- run the common conformance suite and language-specific smoke tests;
- inspect dynamic dependencies and ensure BLAS/OpenMP libraries resolve;
- test an invalid-input corpus and repeated allocation/free cycles;
- generate an SBOM and checksums and sign artifacts where the registry
  supports it; and
- publish all language packages from one coordinated core release manifest.

Nightly/scheduled lanes cover the full runtime-version matrix, sanitizers,
valgrind-like leak checks, and coexistence with common numerical packages.
Pull requests may use a smaller representative matrix if release lanes remain
complete.

### Version compatibility

- Core patch releases may fix implementation bugs without changing the ABI.
- Additive functions/result fields require a core minor version and wrapper
  feature detection.
- ABI-breaking changes require a core major version and parallel-installable
  library name if practical.
- A wrapper records the minimum and maximum ABI it understands and fails with
  a clear version error before any kernel call.
- Package versions need not be numerically identical across registries, but
  metadata must identify the exact core source revision and ABI version.

## Risks and non-goals

### Principal risks

1. **Surface drift:** handwritten declarations silently acquire different
   defaults, index bases, or result fields. Mitigation: manifest generation and
   shared fixtures.
2. **Native dependency collisions:** a host process already loads another
   BLAS/OpenMP runtime. Mitigation: dependency inspection, conservative thread
   ownership, coexistence tests, and documented overrides.
3. **Binary matrix explosion:** runtime and OS versions multiply. Mitigation:
   shared core artifacts, explicit support windows, and community tiers.
4. **Unsafe boundary failures:** malformed shapes or escaping exceptions crash
   the host runtime. Mitigation: validate in C adapters, catch everything,
   fuzz the ABI, and test cleanup.
5. **False parity claims:** exposing kernels is described as exposing EDI.
   Mitigation: name packages `edi_kernels` consistently and document Level K
   versus Level W.
6. **Low-adoption maintenance:** packages exist but nobody can review issues
   in the language. Mitigation: maintainer and adoption gates.
7. **Statistical-semantic mismatch:** language conventions for categorical
   variables, missing values, contrasts, survival inputs, or reported
   covariance differ. Mitigation: accept explicit numeric design matrices at
   the low level; add formula/data-frame façades only with ecosystem experts.

### Non-goals

- Reimplementing estimators in each language.
- Making the Python extension a universal bridge.
- Promising formula parsers or data-frame semantics in v1 of every binding.
- Supporting browser JavaScript as a side effect of supporting Node.js.
- Claiming the complete R package is available when only kernels are bound.
- Publishing an unmaintained package merely to maximize the language count.

## Definition of done

The multi-language program is complete when:

- [ ] one documented, versioned C ABI covers the frozen standalone kernel
  surface and exposes no C++ ABI details;
- [ ] the manifest is the authoritative public surface and drift checks pass;
- [ ] C, R, Python, Julia, JVM, and .NET pass common numerical/error fixtures
  on the supported platform matrix;
- [ ] selected MATLAB/Stata deliverables pass their native estimation-result
  conventions and licensed CI;
- [ ] every first-party package installs from its actual registry artifact in
  a clean environment;
- [ ] ABI, ownership, threading, BLAS/OpenMP, security, versioning, and support
  windows are documented;
- [ ] adding one ordinary kernel requires no handwritten declaration or
  fixture duplication across languages; and
- [ ] community bindings are clearly labelled and cannot block core releases.

## Recommended delivery order and rough total effort

1. Phase 0 decisions: **1–2 engineer-weeks**.
2. C ABI, manifest, shared build, and SDK: **10–18 engineer-weeks**.
3. Julia plus one managed-runtime proof: **7–13 engineer-weeks**. Demand
   favours JVM; .NET may be chosen if its Windows packaging better exercises
   the ABI risks.
4. The second of JVM/.NET: **4–7 engineer-weeks** after generator reuse.
5. MATLAB and focused Stata work as soon as licensed CI/maintainers are
   available: **11–19 engineer-weeks total**.
6. Node, Rust, and Go if demanded: **13–22 engineer-weeks total**.
7. Ruby, PHP, Perl, and Fortran community kit/pilots: **7–12
   engineer-weeks**, preferably external/community-owned.

Recommended first meaningful release: C SDK + Julia + one managed ecosystem,
approximately **18–33 engineer-weeks** including foundation and release
engineering. Demand favours JVM as that managed ecosystem; .NET remains a
valid architecture-first choice. A
responsible first-party release of every language discussed here is roughly
**50–84 engineer-weeks initially**, followed by the annual burden estimated
above. This is why tiering is part of feasibility, not project-management
decoration.

## References

Primary documentation used for interface feasibility:

- Stack Overflow, [2025 Developer Survey: technology](https://survey.stackoverflow.co/2025/technology)
  (broad language-use proxy; not a statistical-inference-user count).
- MathWorks, [2026 company factsheet](https://www.mathworks.com/content/dam/mathworks/fact-sheet/2026-company-factsheet-8-5x11-8282v27.pdf)
  (reports five million MATLAB users worldwide).
- Julia project, [Julia language homepage](https://www.julialang.org/)
  (reports cumulative downloads and registered-package count; neither is
  treated as unique active users).
- StataCorp, [Who uses Stata?](https://www.stata.com/why-use-stata/who-uses-stata/)
  (discipline/inference-fit evidence; Stata does not provide a public active-
  user count used here).
- Julia, [C Interface](https://docs.julialang.org/en/v1/base/c/).
- Oracle, [Foreign Function and Memory API](https://docs.oracle.com/en/java/javase/22/core/foreign-function-and-memory-api.html).
- Microsoft, [Platform Invoke](https://learn.microsoft.com/en-us/dotnet/standard/native-interop/pinvoke)
  and [native interoperability best practices](https://learn.microsoft.com/en-us/dotnet/standard/native-interop/best-practices).
- Node.js, [Node-API](https://nodejs.org/api/n-api.html).
- Go, [cgo command documentation](https://pkg.go.dev/cmd/cgo).
- Rust, [`bindgen` user guide](https://rust-lang.github.io/rust-bindgen/).
- Ruby, [Extending Ruby with C](https://ruby-doc.org/3.2/extension_rdoc.html).
- Perl, [XS language reference](https://perldoc.perl.org/perlxs).
- PHP, [Foreign Function Interface](https://www.php.net/manual/en/book.ffi.php).
- MathWorks, [C++ with MATLAB](https://www.mathworks.com/help/matlab/cpp-language.html)
  and [Call C/C++ from MATLAB](https://www.mathworks.com/help/matlab/call-cpp-library-functions.html).
- StataCorp, [Creating and using Stata plugins](https://www.stata.com/plugins/index.html)
  and [Java integration and Java plugins](https://www.stata.com/java/).
