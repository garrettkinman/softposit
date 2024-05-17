# Copyright (c) 2024 Garrett Kinman
# 
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

import unittest
import softposit

let
    a: Posit8 = (0.0).Posit8
    b: Posit8 = (1.0).Posit8
    c: Posit8 = (-1.0).Posit8

test "addition":
  check a + a == a
  check a + b == b
  check b + c == a

test "subtraction":
  check a - a == a
  check a - b == c
  check b - b == a
  check c - c == a

test "multiplication":
  check a * a == a
  check a * b == a
  check b * b == b
  check b * c == c
  check c * c == b
  check a * c == a