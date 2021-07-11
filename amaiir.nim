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

# amaiir.nim version 0.2

import  math, os, strutils, parsecfg, biquad

const N = 1024
type
  Ch8 = enum
    Lf, Rf, Lb, Rb, Cf, Lfe, Ls, Rs
  Ch2 = enum
    Lch,  Rch

######################
# Read config file 
######################

let
  vargs = commandLineParams()
if vargs.len != 1:
  stderr.writeLine("Usage : " & getAppFilename() & " cfgfilename")
  quit(1)
let
  cfgFilename = vargs[0]
  cfg = loadConfig(cfgFilename)
  fs = cfg.getSectionValue("", "fs").parseFloat
  
stderr.writeLine("fs = " & $fs)

########################
# make Eq from section
########################

proc mkeq(section: string): proc(y: float64): float64 =
  let
    eqType = cfg.getSectionValue(section, "type")
    f = cfg.getSectionValue(section, "f")
    q = cfg.getSectionValue(section, "q")
    gain = cfg.getSectionValue(section, "gain")

  stderr.writeLine("+++ " & section & " +++")
  stderr.writeLine(eqType)
  stderr.writeLine("f = " & f)
  stderr.writeLine("q = " & q)
  stderr.writeLine("gain = " & gain)

  var func1: proc(y: float64): float64
  case eqType
  of "lowshelf":
    func1 = bqLowshelf(f = f.parseFloat, q = q.parseFloat, gain = gain.parseFloat, fs = fs)
  of "highshelf":
    func1 = bqHighshelf(f = f.parseFloat, q = q.parseFloat, gain = gain.parseFloat, fs = fs)
  of "peaking":
    func1 = bqPeaking(f = f.parseFloat, q = q.parseFloat, gain = gain.parseFloat, fs = fs)
  of "lowpass":
    func1 = bqLowpass(f = f.parseFloat, q = q.parseFloat, fs = fs)
  of "highpass":
    func1 = bqHighpass(f = f.parseFloat, q = q.parseFloat, fs = fs)
  else:
    stderr.writeLine("eqType is Bad")
  return func1

##################################
# ch config from section
##################################

proc chFilter(section: string): proc(y: float64): float64 =
  let 
    mute = cfg.getSectionValue(section, "mute")
    gain1 = cfg.getSectionValue(section, "gain")
    polarity = cfg.getSectionValue(section, "polarity")
  var
    gain = pow(10.0, gain1.parseFloat / 20).float64
  if polarity == "I":
    gain = gain * -1

  stderr.writeLine("####### " & section & " ###############################")
  stderr.writeLine("mute = " & mute)
  stderr.writeLine("gain = " & gain1)
  stderr.writeLine("delay = " & cfg.getSectionValue(section, "delay"))
  stderr.writeLine("input = " & cfg.getSectionValue(section, "input"))
  stderr.writeLine("polarity = " & polarity)
  stderr.writeLine("lowcut_enable = " & cfg.getSectionValue(section & ".lowcut", "enable"))
  stderr.writeLine("lowcut_f = " & cfg.getSectionValue(section & ".lowcut", "f"))
  stderr.writeLine("highcut_enable = " & cfg.getSectionValue(section & ".highcut", "enable"))
  stderr.writeLine("highcut_enable = " & cfg.getSectionValue(section & ".highcut", "f"))
  # if mute ON , return 0
  if mute == "ON":
    return proc(y: float64): float64 = return 0.0
  if mute != "OFF":
    stderr.writeLine("mute is [ON | OFF]")
    quit(1)
  var fA: array[6, (proc(y: float64): float64)]
  var i: int = 0 
  if cfg.getSectionValue(section & ".lowcut", "enable") == "Y":
    fA[i] = lr4Highpass(cfg.getSectionValue(section & ".lowcut", "f").parseFloat)
    i = i + 1
  if cfg.getSectionValue(section & ".highcut", "enable") == "Y":
    fA[i] = lr4Lowpass(cfg.getSectionValue(section & ".highcut", "f").parseFloat)
    i = i + 1
  if cfg.getSectionValue(section & ".eq.1", "enable") == "Y":
    fA[i] = mkeq(section & ".eq.1")
    i = i + 1
  if cfg.getSectionValue(section & ".eq.2", "enable") == "Y":
    fA[i] = mkeq(section & ".eq.2")
    i = i + 1
  if cfg.getSectionValue(section & ".eq.3", "enable") == "Y":
    fA[i] = mkeq(section & ".eq.3")
    i = i + 1
  if cfg.getSectionValue(section & ".eq.4", "enable") == "Y":
    fA[i] = mkeq(section & ".eq.4")
    i = i + 1
  case i
  of 0:
    return proc(x: float64): float64 = return x * gain
  of 1:
    return proc(x: float64): float64 = return fA[0](x) * gain
  of 2:
    return proc(x: float64): float64 = return fA[1](fA[0](x)) * gain
  of 3:
    return proc(x: float64): float64 = return fA[2](fA[1](fA[0](x))) * gain
  of 4:
    return proc(x: float64): float64 = return fA[3](fA[2](fA[1](fA[0](x)))) * gain
  of 5:
    return proc(x: float64): float64 = return fA[4](fA[3](fA[2](fA[1](fA[0](x))))) * gain
  of 6:
    return proc(x: float64): float64 = return fA[5](fA[4](fA[3](fA[2](fA[1](fA[0](x)))))) * gain
  else:
    quit(1)

#############
# make Delay
#############

proc delayI32(i: int): proc (x: int32): int32 =
  if i == 0:
    return proc(x: int32): int32 = return x
  var d = newSeq[int32](i)
  var head: int
  proc f(x: int32): int32 =
    result = d[head]
    d[head] = x
    head = (head + 1) mod i   
  return f

let
  lfdelay = delayI32(cfg.getSectionValue("lf", "delay").parseInt)
  rfdelay = delayI32(cfg.getSectionValue("rf", "delay").parseInt)
  lbdelay = delayI32(cfg.getSectionValue("lb", "delay").parseInt)
  rbdelay = delayI32(cfg.getSectionValue("rb", "delay").parseInt)
  lsdelay = delayI32(cfg.getSectionValue("ls", "delay").parseInt)
  rsdelay = delayI32(cfg.getSectionValue("rs", "delay").parseInt)
  cfdelay = delayI32(cfg.getSectionValue("cf", "delay").parseInt)
  lfedelay = delayI32(cfg.getSectionValue("lfe", "delay").parseInt)

#################
# config input ch
#################

proc ich(section: string): int =
  let s = cfg.getSectionValue(section, "input")
  case s
  of "L":
    return 0
  of "R":
    return 1
  of "SUM":
    return 2
  else:
    quit(1)

let
  lfin = ich("lf")
  rfin = ich("rf")
  lbin = ich("lb")
  rbin = ich("rb")
  lsin = ich("ls")
  rsin = ich("rs")
  cfin = ich("cf")
  lfein = ich("lfe")

############################################
# config Eq
############################################

# make filter
let
  ltotal = chFilter("ltotal")
  rtotal = chFilter("rtotal")
  lf = chFilter("lf")
  rf = chFilter("rf")
  lb = chFilter("lb")
  rb = chFilter("rb")
  ls = chFilter("ls")
  rs = chFilter("rs")
  cf = chFilter("cf")
  lfe = chFilter("lfe")

####################
# avoid nasal demons
####################

let
  highInt32 = high(int32).float64
  lowInt32 = low(int32).float64

proc i32(x: float64): int32 =
  if x >= highInt32:
    return high(int32).int32
  if x <= lowInt32:
    return low(int32).int32
  return x.int32
  
#################
# Reserve Buffer 
#################

var
  inBuf: array[N, array[Ch2, int32]]
  outBuf: array[N, array[Ch8, int32]]
let
  inPointer: pointer = inBuf.addr
  outPointer: pointer = outBuf.addr

################
# main  process
################

proc chdev() =
  var m: array[3, float64]
  for i in 0..<N:
    m[0] = inBuf[i][Lch].float64.ltotal
    m[1] = inBuf[i][Rch].float64.rtotal
    m[2] = (inBuf[i][Lch].float64 + inBuf[i][Rch].float64) / 2
    outBuf[i][Lf] = m[lfin].lf.i32.lfdelay
    outBuf[i][Rf] = m[rfin].rf.i32.rfdelay
    outBuf[i][Lb] = m[lbin].lb.i32.lbdelay
    outBuf[i][Rb] = m[rbin].rb.i32.rbdelay
    outBuf[i][Ls] = m[lsin].ls.i32.lsdelay
    outBuf[i][Rs] = m[rsin].rs.i32.rsdelay
    outBuf[i][Cf] = m[cfin].cf.i32.cfdelay
    outBuf[i][Lfe] = m[lfein].lfe.i32.lfedelay

##############
# main loop
##############

var r: int
while stdin.endOfFile.not:
  r = stdin.readBuffer(inPointer, N * 2 * sizeof(int32))
  chdev()
  r = stdout.writeBuffer(outPointer, r * 4)  

