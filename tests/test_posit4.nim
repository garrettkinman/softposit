# Copyright (c) 2025 Garrett Kinman
# 
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

## test_softposit.nim - Unit tests for the softposit library

import unittest
import softposit

const refTables: array[3, array[16, float64]] = [
    [0.0, 0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 4.0,
        0.0, -4.0, -2.0, -1.5, -1.0, -0.75, -0.5, -0.25],
    [0.0, 1.0/16, 0.25, 0.5, 1.0, 2.0, 4.0, 16.0,
        0.0, -16.0, -4.0, -2.0, -1.0, -0.5, -0.25, -1.0/16],
    [0.0, 1.0/256, 1.0/16, 1.0/8, 1.0, 2.0, 16.0, 256.0,
        0.0, -256.0, -16.0, -2.0, -1.0, -0.125, -1.0/16, -1.0/256],
]

# ─────────────────────────────────────────────────────────────────────────────

suite "decode (toFloat)":

    test "Posit<4,0> matches spec table":
        for i in 0..15:
            let p = Posit4[0](uint8(i))
            if i == 8:
                check p.isNaR
            else:
                check abs(p.toFloat - refTables[0][i]) < 1e-12

    test "Posit<4,1> matches spec table":
        for i in 0..15:
            let p = Posit4[1](uint8(i))
            if i == 8:
                check p.isNaR
            else:
                check abs(p.toFloat - refTables[1][i]) < 1e-12

    test "Posit<4,2> matches spec table":
        for i in 0..15:
            let p = Posit4[2](uint8(i))
            if i == 8:
                check p.isNaR
            else:
                check abs(p.toFloat - refTables[2][i]) < 1e-12

# ─────────────────────────────────────────────────────────────────────────────

suite "negation":

    test "2's-complement bit patterns":
        for i in 1..15:
            if i == 8: continue
            let p        = Posit4[1](uint8(i))
            let expected = uint8(((not uint8(i)) + 1) and 0xF)
            check uint8(-p) == expected

    test "zero and NaR are fixed points":
        check uint8(-Posit4[1](0'u8)) == 0
        check uint8(-Posit4[1](8'u8)) == 8

    test "double negation identity":
        for i in 0..15:
            let p = Posit4[0](uint8(i))
            check uint8(-(-p)) == uint8(p)

# ─────────────────────────────────────────────────────────────────────────────

suite "reciprocal":

    test "recip(1) == 1":
        check recip(Posit4[1].fromFloat(1.0)).toFloat == 1.0

    test "recip(NaR) == NaR":
        check recip(Posit4[1](8'u8)).isNaR

    test "recip(0) == NaR":
        check recip(Posit4[1](0'u8)).isNaR

    test "recip(recip(x)) == x for all non-special values":
        for i in 1..15:
            if i == 8: continue
            let p = Posit4[1](uint8(i))
            check uint8(recip(recip(p))) == uint8(p)

# ─────────────────────────────────────────────────────────────────────────────

suite "multiplication":

    test "exact products (powers of 2)":
        let cases = [(2.0, 2.0, 4.0), (4.0, 4.0, 16.0), (0.25, 4.0, 1.0),
                    (-2.0, 2.0, -4.0), (-1.0/16, 16.0, -1.0), (0.5, 0.5, 0.25)]
        for (a, b, want) in cases:
            check abs((Posit4[1].fromFloat(a) * Posit4[1].fromFloat(b)).toFloat - want) < 1e-12

    test "x * 0 == 0 for all non-NaR":
        for i in 0..15:
            let p = Posit4[1](uint8(i))
            if not p.isNaR:
                check (p * Posit4[1](0'u8)).isZero

    test "x * NaR == NaR for all x":
        for i in 0..15:
            check (Posit4[1](uint8(i)) * Posit4[1](8'u8)).isNaR

# ─────────────────────────────────────────────────────────────────────────────

suite "addition":

    test "exact sums":
        let cases = [(1.0, 1.0, 2.0), (2.0, 2.0, 4.0), (0.5, 0.5, 1.0),
                    (-1.0, 1.0, 0.0), (-2.0, -2.0, -4.0), (0.25, 0.25, 0.5)]
        for (a, b, want) in cases:
            check abs((Posit4[0].fromFloat(a) + Posit4[0].fromFloat(b)).toFloat - want) < 1e-12

    test "x + (-x) == 0 for all non-NaR":
        for i in 0..15:
            let p = Posit4[1](uint8(i))
            if not p.isNaR:
                check (p + (-p)).isZero

# ─────────────────────────────────────────────────────────────────────────────

suite "division":

    test "exact quotients":
        let cases = [(4.0, 2.0, 2.0), (1.0, 4.0, 0.25),
                    (16.0, 4.0, 4.0), (-2.0, 2.0, -1.0)]
        for (a, b, want) in cases:
            check abs((Posit4[1].fromFloat(a) / Posit4[1].fromFloat(b)).toFloat - want) < 1e-12

    test "x / 0 == NaR for all x":
        for i in 0..15:
            check (Posit4[1](uint8(i)) / Posit4[1](0'u8)).isNaR

# ─────────────────────────────────────────────────────────────────────────────

suite "cross-es conversion":

    test "Posit4[1] → Posit4[2] preserves representable values":
        check Posit4[1].fromFloat(2.0).to(Posit4[2]).toFloat == 2.0
        check Posit4[1].fromFloat(16.0).to(Posit4[2]).toFloat == 16.0

    test "Posit4[1] → Posit4[0] preserves representable values":
        check Posit4[1].fromFloat(2.0).to(Posit4[0]).toFloat == 2.0
        check Posit4[1].fromFloat(1.0).to(Posit4[0]).toFloat == 1.0

# ─────────────────────────────────────────────────────────────────────────────

suite "quire / MAC":

    test "exact accumulation before rounding":
        # dot([2, 4, 0.5], [2, 0.5, 2]) = 4 + 2 + 1 = 7
        var q: Quire4[1]
        for (a, b) in [(2.0, 2.0), (4.0, 0.5), (0.5, 2.0)]:
            q += (Posit4[1].fromFloat(a), Posit4[1].fromFloat(b))
        check abs(q.val - 7.0) < 1e-12

    test "toPosit result is not NaR":
        var q: Quire4[1]
        q += (Posit4[1].fromFloat(2.0), Posit4[1].fromFloat(2.0))
        check not q.toPosit.isNaR

    test "clear resets accumulator":
        var q: Quire4[1]
        q += (Posit4[1].fromFloat(4.0), Posit4[1].fromFloat(4.0))
        q.clear()
        check q.val == 0.0

# ─────────────────────────────────────────────────────────────────────────────

suite "fromFloat round-trips":

    test "every Posit<4,2> value survives toFloat → fromFloat":
        for i in 0..15:
            if i == 8: continue
            let p = Posit4[2](uint8(i))
            check uint8(Posit4[2].fromFloat(p.toFloat)) == uint8(p)