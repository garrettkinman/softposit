<!--
 Copyright (c) 2024 Garrett Kinman
 
 This software is released under the MIT License.
 https://opensource.org/licenses/MIT
-->

# softposit

A pure Nim implementation of posit arithmetic. Posit numbers are an alternative to IEEE 754 floating-point numbers. Posits utilize regime bits that allow for higher precision around one while also allowing for a wide dynamic range of representable numbers. Posits are more numerically stable and, for many practical applications, allow for similar precision with fewer bits compared to IEEE 754 floating-point numbers. For further information see [posithub.org](https://posithub.org/).