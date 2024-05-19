# Copyright (c) 2024 Garrett Kinman
# 
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

const
    EXP_MASK_P8*: uint8 = 0x03
    EXP_MASK_P16*: uint16 = 0x0003
    EXP_MASK_P32*: uint32 = 0x00000003

    EXP_BITS_P8*: uint8 = 2
    EXP_BITS_P16*: uint16 = 2
    EXP_BITS_P32*: uint32 = 2

    EXP_MASK_F32*: uint32 = 0x7F800000
    EXP_MASK_F64*: uint64 = 0x7FF0000000000000.uint64

    SIGNIFICAND_BITS_F32*: uint32 = 23
    SIGNIFICAND_BITS_F64*: uint64 = 52

    EXP_BIAS_F32*: int32 = 127
    EXP_BIAS_F64*: int64 = 1023

    SIGN_MASK_F32*: uint32 = cast[uint32](0x80000000)
    SIGN_MASK_F64*: uint64 = cast[uint64](0x8000000000000000)