#
# Copyright (C) 2018 Genode Labs GmbH
#
# This file is part of the Genode OS framework, which is distributed
# under the terms of the GNU Affero General Public License version 3.
#

##
## This module provides a client of Genode
## **Terminal** services.
##
## For more information on the **Terminal** service please
## refer to section 4.5.3 of the `Genode Foundations
## <http://genode.org/documentation/genode-foundations-18-05.pdf>`_
## manual.
##

import std/unicode
import ../genode, ./signals

const terminalH = "<terminal_session/connection.h>"

type
  ConnectionBase {.
    importcpp: "Terminal::Connection", header: terminalH.} = object
  Connection = Constructible[ConnectionBase]

  TerminalClient* = ref TerminalClientObj
  TerminalClientObj = object
    conn: Connection
    readAvailSigh, sizeChangedSigh: SignalDispatcher

  CppSize {.
    importcpp: "Terminal::Session::Size", header: terminalH.} = object

  TerminalSize* = object
    columns*, lines*: int

proc columns(ts: CppSize): int {.importcpp.}
proc lines(ts: CppSize): int {.importcpp.}

proc construct(c: Connection; env: GenodeEnv; label: cstring) {.
  importcpp: "#.construct(*#, @)", tags: [RpcEffect].}

proc size(c: Connection): CppSize {.tags: [RpcEffect],
  importcpp: "#->size()".}

proc avail(c: Connection): int {.tags: [RpcEffect],
  importcpp: "#->avail()".}

proc read(c: Connection; buf: pointer; bufLen: int): int {.tags: [RpcEffect],
  importcpp: "#->read(@)".}

proc write(c: Connection; buf: pointer; bufLen: int): int {.tags: [RpcEffect],
  importcpp: "#->read(@)".}

proc read_avail_sigh(c: Connection; cap: SignalContextCapability) {.tags: [RpcEffect],
  importcpp: "#->read_avail_sigh(#)".}

proc size_changed_sigh(c: Connection; cap: SignalContextCapability) {.tags: [RpcEffect],
  importcpp: "#->size_changed_sigh(#)".}

proc newTerminalClient*(env: GenodeEnv; label = ""): TerminalClient=
  ## Open a new **Terminal** session.
  new result
  result.conn.construct(env, label)

proc size*(tc: TerminalClient): TerminalSize  =
  ## Return the number of character available for reading.
  let size = tc.conn.size()
  TerminalSize(columns: size.columns(), lines: size.lines())

proc avail*(tc: TerminalClient): int  =
  ## Return the number of character available for reading.
  tc.conn.avail()

proc read*(tc: TerminalClient; buffer: pointer; bufLen: int): int  =
  ## Read any available data from the terminal.
  tc.conn.read(buffer, bufLen)

proc readAll*(tc: TerminalClient): string  =
  ## Read all available data from the terminal.
  result = newString(tc.avail)
  if result.len > 0:
    let n = tc.read(result[0].addr, result.len)
    result.setLen(n)

proc write*(tc: TerminalClient; buffer: pointer; bufLen: int): int  =
  ## Write data from the terminal. This procedure must be expected
  ## to perform a short write, or to be blocked arbitrarily by the server.
  tc.conn.write(buffer, bufLen)

proc write*(tc: TerminalClient; s: string): int  =
  ## Write a string to the terminal.
  var s = s
  tc.write(s[0].addr, s.len)

proc readAvailSigh*(tc: TerminalClient; cap: SignalContextCapability) =
  ## Install a signal handler to be informed
  ## about ready-to-read characters.
  tc.conn.read_avail_sigh(cap)

proc sizeChangedSigh*(tc: TerminalClient; cap: SignalContextCapability) =
  ## Install a signal handler to be notified on terminal-size changes.
  tc.conn.size_changed_sigh(cap)
