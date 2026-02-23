# Copyright (c) 2024 Garrett Kinman
# 
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

import std/math

# ─────────────────────────────────────────────────────────────────────────────
# Base types
# ─────────────────────────────────────────────────────────────────────────────

type
    Posit4*[es: static int] = distinct uint8
        ## A 4-bit posit with `es` exponent bits (es ∈ {0, 1, 2}).
        ## bits == 0 → zero; bits == 8 → NaR (projective infinity).

    FloatLUT  = array[16, float64]
    UnaryLUT  = array[16, uint8]
    BinaryLUT = array[256, uint8]

# ─────────────────────────────────────────────────────────────────────────────
# Float tables — copied verbatim from the spec
# ─────────────────────────────────────────────────────────────────────────────
# Index 8 is NaR; stored as 0.0 sentinel, handled via isNaR checks.

const
    kNaR = 8'u8

    kFloatTables: array[3, FloatLUT] = [
        # Posit<4,0>  useed=2   minpos=1/4   maxpos=4
        [0.0,   1.0/4,   1.0/2,   3.0/4,
        1.0,   3.0/2,   2.0,     4.0,
        0.0,                          # index 8 = NaR sentinel
        -4.0,  -2.0,    -3.0/2,  -1.0,
        -3.0/4, -1.0/2,  -1.0/4],

        # Posit<4,1>  useed=4   minpos=1/16  maxpos=16
        [0.0,    1.0/16,  1.0/4,   1.0/2,
        1.0,    2.0,     4.0,     16.0,
        0.0,                           # index 8 = NaR sentinel
        -16.0,  -4.0,    -2.0,    -1.0,
        -1.0/2,  -1.0/4,  -1.0/16],

        # Posit<4,2>  useed=16  minpos=1/256 maxpos=256
        [0.0,    1.0/256, 1.0/16,  1.0/8,
        1.0,    2.0,     16.0,    256.0,
        0.0,                           # index 8 = NaR sentinel
        -256.0, -16.0,   -2.0,    -1.0,
        -1.0/8,  -1.0/16, -1.0/256],
    ]

# ─────────────────────────────────────────────────────────────────────────────
# Compile-time helper — nearest representable value search
# ─────────────────────────────────────────────────────────────────────────────

func nearest(v: float64; es: int): uint8 {.compileTime.} =
    if v == 0.0 or v == -0.0: return 0'u8
    var best = 0'u8
    var bestDist = 1e300
    for i in 0'u8 ..< 16'u8:
        if i == kNaR: continue
        let d = abs(kFloatTables[es][i] - v)
        if d < bestDist:
            bestDist = d
            best = i
    best

# ─────────────────────────────────────────────────────────────────────────────
# LUT builders
# ─────────────────────────────────────────────────────────────────────────────

func makeNegLUT(es: int): UnaryLUT {.compileTime.} =
    ## Exact 2's-complement negation; NaR and 0 are fixed points.
    for i in 0..15:
        result[i] =
            if i == 0 or i == 8: uint8(i)
            else: ((not uint8(i)) + 1'u8) and 0xF'u8

func makeAbsLUT(es: int): UnaryLUT {.compileTime.} =
    let neg = makeNegLUT(es)
    for i in 0..15:
        result[i] = if i > 8: neg[i] else: uint8(i)

func makeRecipLUT(es: int): UnaryLUT {.compileTime.} =
    for i in 0..15:
        result[i] =
            if i == 0 or i == 8: kNaR
            else: nearest(1.0 / kFloatTables[es][i], es)

func makeSqrtLUT(es: int): UnaryLUT {.compileTime.} =
    for i in 0..15:
        result[i] =
            if i == 8 or i > 8: kNaR       # NaR or negative → NaR
            elif i == 0: 0'u8
            else: nearest(sqrt(kFloatTables[es][i]), es)

func makeAddLUT(es: int): BinaryLUT {.compileTime.} =
    for a in 0..15:
        for b in 0..15:
            result[a * 16 + b] =
                if a == 8 or b == 8: kNaR
                else: nearest(kFloatTables[es][a] + kFloatTables[es][b], es)

func makeSubLUT(es: int): BinaryLUT {.compileTime.} =
    let neg = makeNegLUT(es)
    let add = makeAddLUT(es)
    for a in 0..15:
        for b in 0..15:
            result[a * 16 + b] = add[a * 16 + int(neg[b])]

func makeMulLUT(es: int): BinaryLUT {.compileTime.} =
    for a in 0..15:
        for b in 0..15:
            result[a * 16 + b] =
                if a == 8 or b == 8: kNaR
                else: nearest(kFloatTables[es][a] * kFloatTables[es][b], es)

func makeDivLUT(es: int): BinaryLUT {.compileTime.} =
    for a in 0..15:
        for b in 0..15:
            result[a * 16 + b] =
                if a == 8 or b == 8: kNaR
                elif b == 0:          kNaR
                else: nearest(kFloatTables[es][a] / kFloatTables[es][b], es)

# ─────────────────────────────────────────────────────────────────────────────
# Baked constants — one set per es value, all computed at compile time
# ─────────────────────────────────────────────────────────────────────────────

const
    kNeg   = [makeNegLUT(0),   makeNegLUT(1),   makeNegLUT(2)]
    kAbs   = [makeAbsLUT(0),   makeAbsLUT(1),   makeAbsLUT(2)]
    kRecip = [makeRecipLUT(0), makeRecipLUT(1), makeRecipLUT(2)]
    kSqrt  = [makeSqrtLUT(0),  makeSqrtLUT(1),  makeSqrtLUT(2)]
    kAdd   = [makeAddLUT(0),   makeAddLUT(1),   makeAddLUT(2)]
    kSub   = [makeSubLUT(0),   makeSubLUT(1),   makeSubLUT(2)]
    kMul   = [makeMulLUT(0),   makeMulLUT(1),   makeMulLUT(2)]
    kDiv   = [makeDivLUT(0),   makeDivLUT(1),   makeDivLUT(2)]

# ─────────────────────────────────────────────────────────────────────────────
# Predicates
# ─────────────────────────────────────────────────────────────────────────────

func isZero*[es](p: Posit4[es]): bool {.inline.} = uint8(p) == 0'u8
func isNaR* [es](p: Posit4[es]): bool {.inline.} = uint8(p) == kNaR
func isPositive*[es](p: Posit4[es]): bool {.inline.} =
    let b = uint8(p); b != 0 and b != kNaR and (b shr 3) == 0
func isNegative*[es](p: Posit4[es]): bool {.inline.} =
    uint8(p) != kNaR and (uint8(p) shr 3) == 1

# ─────────────────────────────────────────────────────────────────────────────
# Conversion
# ─────────────────────────────────────────────────────────────────────────────

func toFloat*[es](p: Posit4[es]): float64 {.inline.} =
    if p.isNaR: Inf else: kFloatTables[es][uint8(p)]

func toFloat32*[es](p: Posit4[es]): float32 {.inline.} = float32(p.toFloat)

func fromFloat*[es](_: typedesc[Posit4[es]]; v: float64): Posit4[es] {.inline.} =
    if v != v or v >= 1e300 or v <= -1e300: return Posit4[es](kNaR)
    if v == 0.0 or v == -0.0: return Posit4[es](0'u8)
    var best = 0'u8
    var bestDist = 1e300
    for i in 0'u8 ..< 16'u8:
        if i == kNaR: continue
        let d = abs(kFloatTables[es][i] - v)
        if d < bestDist:
            bestDist = d
            best = i
    Posit4[es](best)

func to*[esA, esB](p: Posit4[esA]; _: typedesc[Posit4[esB]]): Posit4[esB] {.inline.} =
    Posit4[esB].fromFloat(p.toFloat)

func bits*[es](p: Posit4[es]): uint8 {.inline.} = uint8(p)

# ─────────────────────────────────────────────────────────────────────────────
# Arithmetic — all O(1) table lookups
# ─────────────────────────────────────────────────────────────────────────────

func `-`*[es](p: Posit4[es]): Posit4[es] {.inline.} =
    Posit4[es](kNeg[es][uint8(p)])

func abs*[es](p: Posit4[es]): Posit4[es] {.inline.} =
    Posit4[es](kAbs[es][uint8(p)])

func recip*[es](p: Posit4[es]): Posit4[es] {.inline.} =
    Posit4[es](kRecip[es][uint8(p)])

func sqrt*[es](p: Posit4[es]): Posit4[es] {.inline.} =
    Posit4[es](kSqrt[es][uint8(p)])

func `+`*[es](a, b: Posit4[es]): Posit4[es] {.inline.} =
    Posit4[es](kAdd[es][int(uint8(a)) * 16 + int(uint8(b))])

func `-`*[es](a, b: Posit4[es]): Posit4[es] {.inline.} =
    Posit4[es](kSub[es][int(uint8(a)) * 16 + int(uint8(b))])

func `*`*[es](a, b: Posit4[es]): Posit4[es] {.inline.} =
    Posit4[es](kMul[es][int(uint8(a)) * 16 + int(uint8(b))])

func `/`*[es](a, b: Posit4[es]): Posit4[es] {.inline.} =
    Posit4[es](kDiv[es][int(uint8(a)) * 16 + int(uint8(b))])

func `+=`*[es](a: var Posit4[es]; b: Posit4[es]) {.inline.} = a = a + b
func `-=`*[es](a: var Posit4[es]; b: Posit4[es]) {.inline.} = a = a - b
func `*=`*[es](a: var Posit4[es]; b: Posit4[es]) {.inline.} = a = a * b
func `/=`*[es](a: var Posit4[es]; b: Posit4[es]) {.inline.} = a = a / b

# ─────────────────────────────────────────────────────────────────────────────
# Comparison  (NaR is unordered, like IEEE NaN)
# ─────────────────────────────────────────────────────────────────────────────

func `==`*[es](a, b: Posit4[es]): bool {.inline.} =
    not a.isNaR and not b.isNaR and uint8(a) == uint8(b)

func `<`*[es](a, b: Posit4[es]): bool {.inline.} =
    not a.isNaR and not b.isNaR and a.toFloat < b.toFloat

func `<=`*[es](a, b: Posit4[es]): bool {.inline.} =
    not a.isNaR and not b.isNaR and a.toFloat <= b.toFloat

# ─────────────────────────────────────────────────────────────────────────────
# Quire — exact float64 accumulator for fused MAC operations
# ─────────────────────────────────────────────────────────────────────────────
# All Posit4 products fit exactly in float64 (max |product| = 256^2 = 65536).

type Quire4*[es: static int] = object
    val*: float64

func `+=`*[es](q: var Quire4[es]; args: tuple[a, b: Posit4[es]]) {.inline.} =
    q.val += args.a.toFloat * args.b.toFloat

func toPosit*[es](q: Quire4[es]): Posit4[es] {.inline.} =
    Posit4[es].fromFloat(q.val)

func clear*[es](q: var Quire4[es]) {.inline.} = q.val = 0.0

# ─────────────────────────────────────────────────────────────────────────────
# Display
# ─────────────────────────────────────────────────────────────────────────────

func `$`*[es](p: Posit4[es]): string =
    var s = ""
    let b = uint8(p)
    for i in countdown(3, 0):
        s.add(if ((b shr i) and 1) == 1: '1' else: '0')
    if p.isNaR: s & "[4," & $es & "]=NaR"
    else:        s & "[4," & $es & "]=" & $p.toFloat