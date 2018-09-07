#
# Copyright (C) 2018 Genode Labs GmbH
#
# This file is part of the Genode OS framework, which is distributed
# under the terms of the GNU Affero General Public License version 3.
#

##
## This module provides a client of Genode
## Read-only memory (ROM) services.
##
## For more information on the *ROM* service please
## refer to section 4.5.1 of the `Genode Foundations
## <http://genode.org/documentation/genode-foundations-17-05.pdf>`_
## manual.
##
##
## .. code-block:: nim
##   # Create a ROM client
##   proc example(env: GenodeEnv) =
##   let
##     configRom = env.newRomClient("config")
##     configStr = newStream(configRom)
##     xml = parseXml(configStr)
##    echo xml
##
## .. code-block:: nim
##   # Create a ROM handler
##   proc example(env: GenodeEnv) =
##     proc dumpRom(rom: RomClient) =
##       echo readAll(rom.newStream)
##     let rom = env.newRomHandler("foo", dumpRom)
##

import ../genode, ./signals

import streams

const RomH = "<rom_session/connection.h>"

type
  ConnectionBase {.
    importcpp: "Genode::Rom_connection", header: RomH.} = object
  Connection = Constructible[ConnectionBase]

  RomClient* = ref RomClientObj
  RomClientObj = object
    conn: Connection
    streams: DataspaceStreamFactory

proc construct(c: Connection; env: GenodeEnv; label: cstring) {.
  importcpp: "#.construct(*#, @)", tags: [RpcEffect].}

proc dataspace(c: Connection): DataspaceCapability {.tags: [RpcEffect],
  importcpp: "#->dataspace()".}
  ## Return the current dataspace capability from the ROM server.

proc update(c: Connection): bool {.tags: [RpcEffect],
  importcpp: "#->update()".}

proc sigh(c: Connection; cap: SignalContextCapability) {.tags: [RpcEffect],
  importcpp: "#->sigh(#)".}

proc newRomClient*(env: GenodeEnv; label: string): RomClient =
  ## Open a new ROM connection to ``label``.
  new result
  result.conn.construct(env, label)
  result.streams = env.rm.newDataspaceStreamFactory()
  result.streams.replace result.conn.dataspace()
  GC_ref result

proc close*(r: RomClient) =
  ## Close a connection to a ROM server.
  ## This revokes the dataspace issued by the server
  ## and invalidates any dataspace streams.
  close r.streams
  destruct r.conn
  GC_unref r

proc update*(r: RomClient) =
  ## Update the content the of current and future ROM streams.
  if not r.conn.update():
    r.streams.replace(r.conn.dataspace)

proc sigh*(r: RomClient; cap: SignalContextCapability) =
  ## Register a capability to a signal handler at the ROM server.
  r.conn.sigh cap

proc newStream*(r: RomClient): DataspaceStream = r.streams.newStream
  ## Open new a stream over the current ROM dataspace.

type
  HandlerProc* = proc (rom: RomClient) {.closure, gcsafe.}
  RomHandler* = ref object
     rom: RomClient
     sig: SignalDispatcher
     cb: HandlerProc

proc newRomHandler*(env: GenodeEnv; label: string; cb: HandlerProc): RomHandler =
  ## Create a new ROM handler for ``label`` that calls ``cb`` with a ROM client
  ## as signals are received. The ``close`` procedure must be used explicitly
  ## to allow ``RomHandler`` to be freed.
  let rh = RomHandler(
    rom: env.newRomClient(label),
    cb: cb)
  proc wrappedCb =
     rh.cb(rh.rom)
    # wrap callback in procedure to update and produce a stream
  rh.sig = env.ep.newSignalHandler(wrappedCb)
  rh.rom.sigh(rh.sig.cap)
    # register signal handler
  rh

proc process*(rh: RomHandler) =
  ## Immediatly process the handler callback.
  rh.cb(rh.rom)
  
proc newStream*(rh: RomHandler): DataspaceStream =
  ## Return a stream with ROM content.
  rh.rom.newStream

proc close*(rh: RomHandler) =
  ## Close and dissolve ROM handler.
  close rh.rom
  dissolve rh.sig

import std/xmlparser, xmltree
  # TODO: write a simple XML parser without allocation
proc xml*(rom: RomClient): XmlNode =
  ## Parse ROM into an XML tree.
  let s = rom.newStream
  result = s.parseXml
  close s
