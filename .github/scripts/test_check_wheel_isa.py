#!/usr/bin/env python3
"""Tests for check_wheel_isa.py's instruction classifier (v1.0.6-TODO-284). Synthetic objdump
lines only: no objdump, no wheel, no network. Stdlib only."""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import check_wheel_isa as cwi  # noqa: E402


class ClassifyTest(unittest.TestCase):
    def test_avx512(self):
        for line in ["  1a2b:\tvaddpd %zmm1,%zmm2,%zmm3",
                     "  1a2b:\tkmovw %k1,%eax",
                     "  1a2b:\tvmovapd %xmm17,%xmm0",
                     "  1a2b:\tvmovupd %ymm31,(%rax)",
                     "  1a2b:\tvaddpd (%rax){1to8},%zmm0,%zmm0"]:
            self.assertEqual(cwi.classify(line), "avx512", line)

    def test_avx_avx2_fma_bmi(self):
        for line in ["  1a2b:\tvzeroupper",
                     "  1a2b:\tvmovsd %xmm0,(%rax)",
                     "  1a2b:\tvfmadd231pd %ymm1,%ymm2,%ymm3",
                     "  1a2b:\tshlx %rax,%rbx,%rcx"]:
            self.assertEqual(cwi.classify(line), "avx", line)

    def test_baseline(self):
        for line in ["  1a2b:\tmovsd %xmm0,(%rax)",
                     "  1a2b:\taddpd %xmm15,%xmm1",
                     "  1a2b:\tmov %rsp,%rbp",
                     "  1a2b:\tverw (%rax)",
                     "0000000000001a2b <vzeroupper_like_symbol>:",
                     "Disassembly of section .text:"]:
            self.assertIsNone(cwi.classify(line), line)

    def test_scan_counts(self):
        r = cwi.scan_lines(["  1:\tvaddpd %zmm1,%zmm2,%zmm3", "  2:\tvzeroupper",
                            "  3:\tmovsd %xmm0,%xmm1"])
        self.assertEqual(r["counts"], {"avx512": 1, "avx": 1})


if __name__ == "__main__":
    unittest.main()
