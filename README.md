<!--
 Copyright (c) 2024 Garrett Kinman
 
 This software is released under the MIT License.
 https://opensource.org/licenses/MIT
-->

# softposit

A pure Nim implementation of posit arithmetic.

Posit numbers are an alternative to IEEE 754 floating-point, designed to offer higher precision near ±1, a wide dynamic range, and better numerical stability — often matching or exceeding IEEE 754 precision with fewer bits. Unlike IEEE floats, posits use *regime* bits to encode scale, eliminating the need for infinities, NaNs, and subnormals (replaced by a single **NaR** — Not a Real — value). For more background, see [posithub.org](https://posithub.org/).

---

## Features

- **`Posit4[es]`** — a 4-bit posit type parameterized by the number of exponent bits (`es ∈ {0, 1, 2}`)
- **All arithmetic via O(1) compile-time LUTs** — addition, subtraction, multiplication, division, negation, absolute value, reciprocal, and square root are pure table lookups with zero runtime branching
- **`Quire4[es]`** — an exact float64 accumulator for fused multiply-accumulate (MAC) operations, enabling dot products without intermediate rounding
- **Conversion** — to/from `float64`, to/from `float32`, and cross-`es` posit casting
- **Predicates** — `isZero`, `isNaR`, `isPositive`, `isNegative`
- **Comparison operators** — `==`, `<`, `<=` with correct NaR-unordered semantics (mirroring IEEE NaN behaviour)
- **Compound assignment** — `+=`, `-=`, `*=`, `/=`
- **`$` display** — prints the raw 4-bit pattern alongside the decoded value, e.g. `0110[4,1]=4.0`

---

## Type overview

| Type | Bits | `es` | useed | minpos | maxpos |
|------|------|------|-------|--------|--------|
| `Posit4[0]` | 4 | 0 | 2 | 1/4 | 4 |
| `Posit4[1]` | 4 | 1 | 4 | 1/16 | 16 |
| `Posit4[2]` | 4 | 2 | 16 | 1/256 | 256 |

---

## Usage

```nim
import softposit

# Construction
let a = Posit4[1].fromFloat(1.5)
let b = Posit4[1].fromFloat(2.0)

# Arithmetic
let c = a + b          # nearest representable sum
let d = a * b
let e = recip(a)       # 1/a
let f = sqrt(b)

# Conversion
echo a.toFloat         # float64
echo a.toFloat32       # float32
echo a                 # "0101[4,1]=1.5"

# Predicates
echo a.isZero          # false
echo a.isNaR           # false
echo a.isPositive      # true

# Cross-es cast
let g = a.to(Posit4[2])

# Fused multiply-accumulate via Quire
var q: Quire4[1]
q += (a, b)            # q.val += a * b  (exact, no rounding)
q += (c, d)
let result = q.toPosit # round once at the end
q.clear
```

---

## Design notes

All lookup tables (`kAdd`, `kMul`, `kSub`, `kDiv`, `kNeg`, `kAbs`, `kRecip`, `kSqrt`) are built entirely at **compile time** using Nim's `{.compileTime.}` functions and baked into the binary as constant arrays. At runtime every operation is a single array index — there are no branches, no floating-point computations, and no dynamic allocation.

The Quire accumulator stores products exactly in `float64` (the maximum product magnitude for `Posit4` is 256² = 65 536, well within float64's 53-bit mantissa), deferring rounding to a single final `toPosit` call.

---

## License

MIT — see [LICENSE](https://opensource.org/licenses/MIT).