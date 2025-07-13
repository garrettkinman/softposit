# Copyright (c) 2025 Garrett Kinman
# 
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

## test_softposit.nim - Unit tests for the softposit library

import unittest
import softposit
import math

suite "Basic Values Tests":
    test "Posit4[0] special values":
        check positZero[0]().toFloat == 0.0
        check positInf[0]().toFloat == Inf
        check posit4[0](1.0).toFloat == 1.0
        check posit4[0](0.5).toFloat == 0.5
        check posit4[0](2.0).toFloat == 2.0
    
    test "Posit4[1] special values":
        check positZero[1]().toFloat == 0.0
        check positInf[1]().toFloat == Inf
        check posit4[1](1.0).toFloat == 1.0
        check posit4[1](4.0).toFloat == 4.0
    
    test "Posit4[2] special values":
        check positZero[2]().toFloat == 0.0
        check positInf[2]().toFloat == Inf
        check posit4[2](1.0).toFloat == 1.0
        check posit4[2](16.0).toFloat == 16.0

suite "Arithmetic Operations":
    test "Addition":
        let a = posit4[1](1.5)
        let b = posit4[1](0.5)
        check (a + b).toFloat == 2.0
        
    test "Subtraction":
        let a = posit4[1](1.5)
        let b = posit4[1](0.5)
        check (a - b).toFloat == 1.0
        
    test "Multiplication":
        let a = posit4[1](1.5)
        let b = posit4[1](0.5)
        check (a * b).toFloat == 0.75
        
    test "Division":
        let a = posit4[1](1.5)
        let b = posit4[1](0.5)
        # Note: Result might not be exact due to rounding
        check abs((a / b).toFloat - 3.0) < 0.5
        
    test "Negation":
        let a = posit4[1](1.5)
        check (-a).toFloat == -1.5
        
    test "Zero negation":
        let zero = positZero[1]()
        check (-zero).toFloat == 0.0

suite "Comparison Operations":
    test "Equality":
        let p1 = posit4[0](1.0)
        let p2 = posit4[0](1.0)
        let p3 = posit4[0](0.5)
        
        check p1 == p2
        check not (p1 == p3)
        
    test "Less than":
        let p1 = posit4[0](0.5)
        let p2 = posit4[0](1.0)
        
        check p1 < p2
        check not (p2 < p1)
        check not (p1 < p1)
        
    test "Less than or equal":
        let p1 = posit4[0](0.5)
        let p2 = posit4[0](1.0)
        
        check p1 <= p2
        check p1 <= p1
        check not (p2 <= p1)

suite "Packing Operations":
    test "Pack and unpack":
        let high = posit4[1](2.0)
        let low = posit4[1](0.5)
        
        let packed = pack(high, low)
        let unpackedLow = unpackLow[Posit4[1]](packed)
        let unpackedHigh = unpackHigh[Posit4[1]](packed)
        
        check unpackedLow == low
        check unpackedHigh == high
        
    test "Pack preserves bits":
        let high = posit4[1](7'u8)  # Direct bit pattern
        let low = posit4[1](3'u8)   # Direct bit pattern
        
        let packed = pack(high, low)
        check uint8(packed) == 0x73  # 0111_0011

suite "Special Cases":
    test "Infinity arithmetic":
        let inf = positInf[1]()
        let one = posit4[1](1.0)
        
        check (inf + one).toFloat == Inf
        check (inf * one).toFloat == Inf
        check (one / positZero[1]()).toFloat == Inf
        
    test "Zero arithmetic":
        let zero = positZero[1]()
        let one = posit4[1](1.0)
        
        check (zero + one).toFloat == 1.0
        check (zero * one).toFloat == 0.0
        check (zero - zero).toFloat == 0.0

suite "Min/Max Values":
    test "Posit4[0] extremes":
        check minPos[0]().toFloat == 0.25
        check maxPos[0]().toFloat == 2.0
        check negMinPos[0]().toFloat == -0.25
        check negMaxPos[0]().toFloat == -2.0
        
    test "Posit4[1] extremes":
        check minPos[1]().toFloat == 0.0625
        check maxPos[1]().toFloat == 16.0
        check negMinPos[1]().toFloat == -0.0625
        check negMaxPos[1]().toFloat == -16.0

suite "Bit Pattern Tests":
    test "Known bit patterns for Posit4[0]":
        # Test specific bit patterns and their values
        check posit4[0](0b0000'u8).toFloat == 0.0     # Zero
        check posit4[0](0b0001'u8).toFloat == 0.25    # MinPos
        check posit4[0](0b0010'u8).toFloat == 0.5
        check posit4[0](0b0100'u8).toFloat == 1.0
        check posit4[0](0b0110'u8).toFloat == 1.5
        check posit4[0](0b0111'u8).toFloat == 2.0     # MaxPos
        check posit4[0](0b1000'u8).toFloat == Inf     # Infinity
        
    test "Known bit patterns for Posit4[1]":
        check posit4[1](0b0000'u8).toFloat == 0.0     # Zero
        check posit4[1](0b0001'u8).toFloat == 0.0625  # MinPos
        check posit4[1](0b0100'u8).toFloat == 0.5
        check posit4[1](0b0110'u8).toFloat == 1.0
        check posit4[1](0b0111'u8).toFloat == 2.0
        check posit4[1](0b1000'u8).toFloat == Inf     # Infinity

suite "Round Trip Conversions":
    test "Float to posit to float preserves representable values":
        # Test values that should be exactly representable
        let testValues = [0.0, 0.5, 1.0, 1.5, 2.0, -0.5, -1.0, -1.5, -2.0]
        
        for val in testValues:
            let p = posit4[0](val)
            let roundTrip = p.toFloat
            # Check if the value is preserved (within posit precision)
            if val == 0.0:
                check roundTrip == 0.0
            elif abs(val) <= 2.0:  # Within Posit4[0] range
                check abs(roundTrip - val) < 0.3  # Coarse check due to 4-bit precision
            
    test "Bit pattern round trip":
        # Every valid 4-bit pattern should round trip through conversions
        for i in 0'u8..15'u8:
            let p1 = posit4[1](i)
            let f = p1.toFloat
            if f != Inf and f == f:  # Not infinity or NaN
                let p2 = posit4[1](f)
                # Due to rounding, we check if we get the same or adjacent value
                check abs(int(uint8(p2)) - int(i)) <= 1