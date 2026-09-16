# Security Policy

EDI is a statistics package — an R package (`R/EDI/`) and a Python package
(`python/`, `edi_kernels`) sharing one C++ kernel tree (`R/EDI/src/`). It
does no networking, stores no credentials, and processes only data the
caller passes in. The realistic security surface is therefore **memory
safety in the C++ kernels** (out-of-bounds access, use-after-free,
uninitialized reads reachable from user-supplied design matrices or
responses) and **supply chain** (what the published R and PyPI artifacts
actually contain).

## Supported versions

| Version | Supported |
|---|---|
| 1.0.x (current) | Yes |
| < 1.0 | No — pre-release |

Fixes ship in the next patch release of both packages; `edi_kernels`
tracks the R package's version (see `python/CHANGELOG.md`).

## Reporting a vulnerability

**Please do not open a public issue for a security problem.** Use GitHub's
private vulnerability reporting for this repository:
<https://github.com/kapelner/EDI/security/advisories/new>. If that is
unavailable to you, email the maintainer at the address in
`R/EDI/DESCRIPTION` with "EDI security" in the subject.

Include: the affected package and version, a minimal reproducer (a design
matrix / response vector that triggers the fault is ideal), and what you
observed (crash, sanitizer report, wrong result). A report with a valgrind
or ASAN/UBSAN trace is directly actionable — both are already part of CI
(`R-CMD-check.yaml`'s `R-devel (ASAN/UBSAN)` and `R-devel (valgrind)` jobs)
and the devcontainer ships both tools.

You can expect an acknowledgement within a week and, for a confirmed
memory-safety bug, a fix and a coordinated disclosure in the release notes.

## What is and isn't in scope

In scope: crashes or memory errors in `R/EDI/src/` or `python/cpp/`
reachable through the public API; a published wheel/tarball that does not
match the tagged source; a dependency pin that pulls a known-vulnerable
version.

Not in scope: statistical incorrectness (wrong coverage, biased estimate)
— that is a bug, and a serious one, but not a security issue; report it via
the normal [bug report](.github/ISSUE_TEMPLATE/bug_report.yml) so it gets
the response-type / design / inference triage it needs. Also out of scope:
resource exhaustion from deliberately enormous inputs (`n`, `B`, `r`), which
the API does not attempt to bound.

## Verifying what you installed

PyPI releases are published via Trusted Publishing (OIDC) from
`.github/workflows/build-wheels.yml` with digital attestations; R releases
are tagged `v<version>` in this repository and mirrored on
[R-universe](https://kapelner.r-universe.dev/EDI). Build from the tag if
you need to verify an artifact.
