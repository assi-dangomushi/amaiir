## Copyright (C) 2021 Amanogawa Audio Labo
##
## This program is free software; you can redistribute it and/or modify it under
## the terms of the GNU General Public License as published by the Free Software
## Foundation; either version 3 of the License, or (at your option) any later
## version.
##
## This program is distributed in the hope that it will be useful, but WITHOUT
## ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
## FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
## details.
##
## You should have received a copy of the GNU General Public License along with
## this program; if not, see <http://www.gnu.org/licenses/>.


# biquad.nim version 0.2


import math

type
  Coef = enum
    b0, b1, b2, a0, a1, a2
  CoefBiquad = array[Coef, float64]

proc biquadLowpass(f: float64, q: float64, fs: float64 = 96000): CoefBiquad =
  var c: CoefBiquad
  let
    om = 2 * PI * f / fs 
    al = sin(om) / (2 * q)
    co = cos(om)
    a = 1 + al
  c[a0] = 1.0 
  c[a1] = (-2 * co) / a
  c[a2] = (1 - al) / a
  c[b0] = (1 - co) / 2 / a
  c[b1] = (1 - co) / a
  c[b2] = (1 - co) / 2 / a
  return c

proc biquadHighpass(f: float64, q: float64, fs: float64 = 96000): CoefBiquad =
  var c: CoefBiquad
  let
    om = 2 * PI * f / fs
    al = sin(om) / (2 * q)
    a = 1 + al
  c[a0] = 1.0
  c[a1] = (-2 * cos(om)) / a
  c[a2] = (1 - al) / a
  c[b0] = (1 + cos(om)) / 2 / a
  c[b1] = -(1 + cos(om)) / a
  c[b2] = (1 + cos(om)) / 2 / a
  return c

proc biquadLowshelf(f: float64, q: float64, gain: float64, fs: float64 = 96000): CoefBiquad =
  var c: CoefBiquad
  let
    om = 2 * PI * f / fs
    A = pow(10.0,  gain / 40)
    beta = sqrt(A) / q
    co = cos(om)
    so = sin(om)
    a = (A + 1) + (A - 1) * co + beta * so
  c[a0] = 1.0
  c[a1] = -2 * ((A - 1) + (A + 1) * co) / a
  c[a2] = ((A + 1) + (A - 1) * co - beta * so) / a
  c[b0] = A * ((A + 1) - (A - 1) * co + beta * so) / a
  c[b1] = 2 * A * ((A - 1) - (A + 1) * co) / a
  c[b2] = A * ((A + 1) - (A - 1) * co - beta * so) / a
  return c

proc biquadHighShelf(f: float64, q: float64, gain: float64, fs: float64 = 96000): CoefBiquad =
  var c: CoefBiquad
  let
    om = 2 * PI * f / fs
    A = pow(10.0, gain / 40)
    beta = sqrt(A) / q
    co = cos(om)
    so = sin(om)
    a = (A + 1) - (A - 1) * co + beta * so
  c[a0] = 1.0
  c[a1] = 2*((A - 1) - (A + 1) * co) / a
  c[a2] = ((A + 1) - (A - 1) * co - beta * so) / a
  c[b0] = A * ((A + 1) + (A - 1) * co + beta * so) / a
  c[b1] = -2 * A * ((A - 1) + (A + 1) * co) / a
  c[b2] = A * ((A + 1) + (A - 1) * co - beta * so) / a
  return c

proc biquadPeaking(f: float64, q: float64, gain: float64, fs: float64 = 96000): CoefBiquad =
  var c: CoefBiquad
  let
    om = 2 * PI * f / fs
    al = sin(om) / (2 * q)
    A = pow(10.0, gain / 40)
    co = cos(om)
    a = 1 + al / A
  c[a0] = 1.0
  c[a1] = -2 * co / a
  c[a2] = (1 - al / A) / a
  c[b0] = (1 + al * A) / a
  c[b1] = -2 * co / a
  c[b2] = (1 - al * A) / a
  return c

proc biquad(c: CoefBiquad) : proc(y: float64): float64 =
  var z1, z2: float64 = 0
  if c[a0] != 1.0:
    var e: ref OSError
    new(e)
    e.msg = "iir coef a0 must be 1.0"
    raise e
  return proc  (x: float64): float64 =
     var z0 = x - z1*c[a1] - z2*c[a2] + 1e-50
     result = z0*c[b0] + z1*c[b1] + z2*c[b2]
     z2 = z1
     z1 = z0

proc lr4Lowpass*(f: float64, fs: float64 = 96000): proc(y: float64): float64 =
  let 
    c = biquadLowpass(f = f, q = 1 / sqrt(2.0), fs = fs)
    f1 = biquad(c)
    f2 = biquad(c)
  proc f3(y: float64): float64 =
    y.f1.f2
  return f3

proc lr4Highpass*(f: float64, fs: float64 = 96000): proc(y: float64): float64 =
  let 
    c = biquadHighpass(f = f, q = 1 / sqrt(2.0), fs = fs)
    f1 = biquad(c)
    f2 = biquad(c)
  proc f3(y: float64): float64 =
    y.f1.f2
  return f3

proc bqLowpass*(f: float64, q: float ,fs: float64 = 96000): proc(y: float64): float64 =
  let
    c = biquadLowpass(f = f, q = q, fs = fs)
  return biquad(c)

proc bqHighpass*(f: float64, q: float ,fs: float64 = 96000): proc(y: float64): float64 =
  let
    c = biquadHighpass(f = f, q = q, fs = fs)
  return biquad(c)

proc bqLowshelf*(f: float64, q: float , gain: float64, fs: float64 = 96000): proc(y: float64): float64 =
  let
    c = biquadLowshelf(f = f, q = q, gain = gain, fs = fs)
  return biquad(c)

proc bqHighshelf*(f: float64, q: float , gain: float64, fs: float64 = 96000): proc(y: float64): float64 =
  let
    c = biquadHighshelf(f = f, q = q, gain = gain, fs = fs)
  return biquad(c)

proc bqPeaking*(f: float64, q: float , gain: float64, fs: float64 = 96000): proc(y: float64): float64 =
  let
    c = biquadPeaking(f = f, q = q, gain = gain, fs = fs)
  return biquad(c)


