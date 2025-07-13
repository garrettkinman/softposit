# Copyright (c) 2024 Garrett Kinman
# 
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

# import softposit / [arithmetics, comparisons, constants, conversions, print, types]
# export arithmetics, comparisons, constants, conversions, print, types

## softposit.nim - A 4-bit posit implementation for Nim
## Supports posit<4,0>, posit<4,1>, and posit<4,2>

import math

type
    Posit4*[es: static[int]] = distinct uint8
    PackedPosit4*[T] = distinct uint8

const
    # TODO: are these needed?
    nbits = 4
    npat = 16  # 2^4

# Useed values for different es
template useed(es: static[int]): untyped =
    when es == 0: 2
    elif es == 1: 4
    elif es == 2: 16
    elif es == 3: 64
    elif es == 4: 256
    else: {.error: "Unsupported es value".}

# Special values
template positZero*[es: static[int]](): Posit4[es] = Posit4[es](0)
template positInf*[es: static[int]](): Posit4[es] = Posit4[es](8)  # 1000 in binary

func isZero*[es: static[int]](p: Posit4[es]): bool =
    uint8(p) == 0  # 0000 in binary

func isInf*[es: static[int]](p: Posit4[es]): bool =
    uint8(p) == 8  # 1000 in binary

# Conversion from posit to float
func toFloat*[es: static[int]](p: Posit4[es]): float =
    let bits = uint8(p)
    
    # Special cases
    if bits == 0:
        return 0.0
    if bits == 8:  # 1000 in binary = ±∞
        return Inf
        
    # Extract sign and convert to 2's complement if negative
    let sign = (bits shr 3) and 1
    var pbits = if sign == 1: uint8(16 - bits) else: bits
    
    # Find regime bits by counting identical bits after sign
    var regime = 0
    let bit2 = (pbits shr 2) and 1
    if bit2 == 1:
        # Count 1s
        var mask = 0b0100'u8
        var shift = 2
        while shift > 0 and ((pbits and mask) != 0):
            regime += 1
            mask = mask shr 1
            shift -= 1
    else:
        # Count 0s  
        var mask = 0b0100'u8
        var shift = 2
        while shift > 0 and ((pbits and mask) == 0):
            regime -= 1
            mask = mask shr 1
            shift -= 1
        regime -= 1  # Adjust for negative regime
    
    # Calculate how many bits are left for exponent and fraction
    let regimeBits = abs(regime) + 1
    let bitsLeft = 3 - regimeBits  # 3 bits after sign bit
    
    # Extract exponent bits
    var exponent = 0
    var expBits = min(es, bitsLeft)
    if expBits > 0:
        let startBit = 3 - regimeBits - 1
        var expMask = 0'u8
        for i in 0..<expBits:
            expMask = expMask or (1'u8 shl (startBit - i))
        exponent = int((pbits and expMask) shr (startBit - expBits + 1))
    
    # Extract fraction bits
    var fraction = 1.0  # Hidden bit
    let fracBits = max(0, bitsLeft - es)
    if fracBits > 0:
        let fracStart = 3 - regimeBits - es - 1
        var fracValue = 0'u8
        for i in 0..<fracBits:
            if fracStart - i >= 0:
                fracValue = (fracValue shl 1) or ((pbits shr (fracStart - i)) and 1)
        fraction += float(fracValue) / float(1 shl fracBits)
    
    # Calculate final value
    let useedVal = useed(es)
    var value = fraction * pow(float(useedVal), float(regime)) * pow(2.0, float(exponent))
    
    if sign == 1:
        value = -value
        
    return value

# Conversion from float to posit
func fromFloat*[es: static[int]](x: float): Posit4[es] =
    # Special cases
    if x == 0.0:
        return positZero[es]()
    if x.classify == fcInf or x.classify == fcNegInf or x.isNaN:
        return positInf[es]()
        
    var value = abs(x)
    let sign = if x < 0: 1 else: 0
    
    # Scale by powers of useed
    var regime = 0
    let useedVal = float(useed(es))
    
    if value >= 1.0:
        while value >= useedVal:
            value /= useedVal
            regime += 1
    else:
        while value < 1.0:
            value *= useedVal
            regime -= 1
        
    # Scale by powers of 2 for exponent
    var exponent = 0
    let maxExp = (1 shl es) - 1
    
    while exponent < maxExp and value >= 2.0:
        value /= 2.0
        exponent += 1
        
    # Extract fraction (value is now in [1, 2))
    let fraction = value - 1.0
    
    # Build posit bit pattern
    var pbits = 0'u8
    var bitPos = 2  # Start after sign bit
    
    # Encode regime
    if regime >= 0:
        # Positive regime: string of 1s followed by 0
        for i in 0..min(regime, 2):
            if bitPos >= 0:
                pbits = pbits or (1'u8 shl bitPos)
                bitPos -= 1
        if bitPos >= 0 and regime < 3:
            bitPos -= 1  # Terminating 0
    else:
        # Negative regime: string of 0s followed by 1
        for i in 0..<min(-regime, 3):
            if bitPos >= 0:
                bitPos -= 1  # 0 bit
        if bitPos >= 0:
            pbits = pbits or (1'u8 shl bitPos)
            bitPos -= 1
        
    # Encode exponent
    var expBits = min(es, bitPos + 1)
    if expBits > 0:
        for i in 0..<expBits:
            if bitPos >= 0:
                if (exponent and (1 shl (expBits - 1 - i))) != 0:
                    pbits = pbits or (1'u8 shl bitPos)
                bitPos -= 1
            
    # Encode fraction
    var fracBits = bitPos + 1
    if fracBits > 0:
        let fracInt = int(fraction * float(1 shl fracBits) + 0.5)  # Round to nearest
        for i in 0..<fracBits:
            if bitPos >= 0:
                if (fracInt and (1 shl (fracBits - 1 - i))) != 0:
                    pbits = pbits or (1'u8 shl bitPos)
                bitPos -= 1
            
    # Apply sign
    if sign == 1:
        pbits = uint8(16 - pbits)  # 2's complement negation
        
    return Posit4[es](pbits and 0x0F)  # Mask to 4 bits

# Arithmetic operations
func `+`*[es: static[int]](a, b: Posit4[es]): Posit4[es] =
    # TODO: do actual posit addition
    # For now, we just convert to float and back
    fromFloat[es](a.toFloat + b.toFloat)

func `-`*[es: static[int]](a, b: Posit4[es]): Posit4[es] =
    # TODO: do actual posit subtraction
    # For now, we just convert to float and back
    fromFloat[es](a.toFloat - b.toFloat)

func `*`*[es: static[int]](a, b: Posit4[es]): Posit4[es] =
    # TODO: do actual posit multiplication
    # For now, we just convert to float and back
    fromFloat[es](a.toFloat * b.toFloat)

func `/`*[es: static[int]](a, b: Posit4[es]): Posit4[es] =
    # TODO: do actual posit division
    # For now, we just convert to float and back
    fromFloat[es](a.toFloat / b.toFloat)

func `-`*[es: static[int]](a: Posit4[es]): Posit4[es] =
    # Unary negation using 2's complement
    let bits = uint8(a)
    if bits == 0:
        return Posit4[es](0)
    else:
        return Posit4[es](16 - bits)

# Comparison operations
func `==`*[es: static[int]](a, b: Posit4[es]): bool =
    uint8(a) == uint8(b)

func `<`*[es: static[int]](a, b: Posit4[es]): bool =
    # Posits can be compared as signed integers
    let aBits = int8(if uint8(a) >= 8: int(uint8(a)) - 16 else: int(uint8(a)))
    let bBits = int8(if uint8(b) >= 8: int(uint8(b)) - 16 else: int(uint8(b)))
    return aBits < bBits

func `<=`*[es: static[int]](a, b: Posit4[es]): bool =
    a < b or a == b

# Packing operations
func pack*[es: static[int]](high, low: Posit4[es]): PackedPosit4[Posit4[es]] =
    PackedPosit4[Posit4[es]]((uint8(high) shl 4) or (uint8(low) and 0x0F))

func unpackLow*[T](packed: PackedPosit4[T]): T =
    T(uint8(packed) and 0x0F)

func unpackHigh*[T](packed: PackedPosit4[T]): T =
    T(uint8(packed) shr 4)

# String representation
proc `$`*[es: static[int]](p: Posit4[es]): string =
    let bits = uint8(p)
    var bitStr = ""
    for i in countdown(3, 0):
        bitStr &= $(int((bits shr i) and 1))
    return "Posit4[" & $es & "](" & bitStr & " = " & $p.toFloat & ")"

# Convenience constructors
func posit4*[es: static[int]](x: float): Posit4[es] =
    fromFloat[es](x)

func posit4*[es: static[int]](bits: uint8): Posit4[es] =
    Posit4[es](bits and 0x0F)

# Export common values
# TODO: variants for posit8, posit16, posit32
template maxPos*[es: static[int]](): Posit4[es] = Posit4[es](7)  # 0111
template minPos*[es: static[int]](): Posit4[es] = Posit4[es](1)  # 0001
template negMaxPos*[es: static[int]](): Posit4[es] = Posit4[es](9)  # 1001
template negMinPos*[es: static[int]](): Posit4[es] = Posit4[es](15) # 1111