#!/usr/bin/env python3
"""Fail if an edi_kernels x86-64 extension uses instructions above the portable baseline.

ds-python-kernels-44358267779-f1 (v1.0.6-TODO-205): a wheel built with -march=native on an AVX-512
GitHub runner died with SIGILL on `import edi_kernels` on an AVX2-only runner. Released wheels are
built portable (no -march; the compiler's x86-64 baseline), so their extension must contain no
AVX-512 and, by default, no AVX/AVX2/FMA/BMI either. The PyPI 1.0.2 cp312 manylinux wheel has
0 zmm and 0 ymm instructions, so this strict default matches what already ships.

Usage:
    check_wheel_isa.py [--allow-avx2] PATH [PATH ...]

Each PATH is a .whl (its edi_kernels/_core*.so / .pyd members are checked; bundled libraries under
*.libs/ such as OpenBLAS pick their kernels at run time and are skipped) or a shared object.
Non-x86-64 files (aarch64, arm64, armv7) are skipped. Needs binutils' objdump. Exit 0 = clean,
1 = a forbidden instruction was found, 2 = usage error or nothing was checked.
"""
from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path

# AT&T syntax, as objdump prints by default.
# AVX-512: zmm registers, opmask registers, EVEX-only xmm16-31/ymm16-31, embedded broadcast.
AVX512_RE = re.compile(r"%zmm\d|%k[0-7]\b|%[xy]mm(1[6-9]|2\d|3[01])\b|\{1to\d+\}")
# AVX/AVX2/FMA (x86-64-v3): any ymm register or a VEX-encoded mnemonic (v-prefix, minus VMX ops).
VMX_OPS = {"verr", "verw", "vmcall", "vmclear", "vmfunc", "vmlaunch", "vmptrld", "vmptrst",
           "vmread", "vmresume", "vmwrite", "vmxoff", "vmxon", "vmrun", "vmload", "vmsave",
           "vmmcall"}
BMI_OPS = {"andn", "bextr", "blsi", "blsmsk", "blsr", "bzhi", "mulx", "pdep", "pext", "rorx",
           "sarx", "shlx", "shrx"}
INSN_RE = re.compile(r"^\s*[0-9a-f]+:\s+([a-z][a-z0-9.]*)")  # objdump --no-show-raw-insn


def classify(line: str) -> str | None:
    """Return 'avx512', 'avx' or None for one objdump -d line."""
    if AVX512_RE.search(line):
        return "avx512"
    m = INSN_RE.match(line)
    if not m:
        return None
    op = m.group(1)
    if "%ymm" in line or op in BMI_OPS or (op.startswith("v") and op not in VMX_OPS):
        return "avx"
    return None


def scan_lines(lines) -> dict:
    counts = {"avx512": 0, "avx": 0}
    first = {}
    for line in lines:
        kind = classify(line)
        if kind:
            counts[kind] += 1
            first.setdefault(kind, line.strip())
    return {"counts": counts, "first": first}


def is_x86_64(path: Path) -> bool:
    head = path.read_bytes()[:64]
    if head[:4] == b"\x7fELF":
        return head[4] == 2 and int.from_bytes(head[18:20], "little") == 62  # EM_X86_64
    if head[:2] == b"MZ":  # Windows PE: let objdump decide; only amd64 wheels are built
        return True
    return False  # Mach-O and anything else: not checked here


def disassemble(path: Path) -> dict:
    proc = subprocess.Popen(["objdump", "-d", "--no-show-raw-insn", str(path)],
                            stdout=subprocess.PIPE, text=True, errors="replace")
    assert proc.stdout is not None
    result = scan_lines(proc.stdout)
    if proc.wait() != 0:
        raise RuntimeError(f"objdump failed on {path}")
    return result


def targets(path: Path, tmp: Path):
    if path.suffix == ".whl":
        with zipfile.ZipFile(path) as z:
            for name in z.namelist():
                parts = name.split("/")
                if (len(parts) == 2 and parts[0] == "edi_kernels"
                        and parts[1].startswith("_core") and parts[1].endswith((".so", ".pyd"))):
                    out = tmp / path.stem / parts[1]
                    out.parent.mkdir(parents=True, exist_ok=True)
                    out.write_bytes(z.read(name))
                    yield f"{path.name}:{name}", out
    else:
        yield str(path), path


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--allow-avx2", action="store_true",
                    help="permit AVX/AVX2/FMA/BMI (x86-64-v3); AVX-512 is always rejected")
    ap.add_argument("paths", nargs="+", type=Path)
    args = ap.parse_args(argv)
    if shutil.which("objdump") is None:
        print("check_wheel_isa: objdump not found (install binutils)", file=sys.stderr)
        return 2
    forbidden = ["avx512"] if args.allow_avx2 else ["avx512", "avx"]
    checked = bad = 0
    with tempfile.TemporaryDirectory() as td:
        for p in args.paths:
            for label, so in targets(p, Path(td)):
                if not is_x86_64(so):
                    print(f"skip (not x86-64): {label}")
                    continue
                r = disassemble(so)
                checked += 1
                c = r["counts"]
                hits = [k for k in forbidden if c[k]]
                status = "FAIL" if hits else "ok"
                print(f"{status}: {label}: AVX-512 lines={c['avx512']}, AVX/AVX2/FMA/BMI lines={c['avx']}")
                for k in hits:
                    print(f"    first {k}: {r['first'][k]}")
                bad += bool(hits)
    if checked == 0:
        print("check_wheel_isa: no x86-64 edi_kernels extension found in the given paths",
              file=sys.stderr)
        return 2
    if bad:
        print("check_wheel_isa: the extension targets a newer CPU than the portable baseline; "
              "was it built with -march=native (EDI_PY_PORTABLE=OFF / EDI_PORTABLE=0)?",
              file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
