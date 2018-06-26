#
# Copyright (C) 2018 Genode Labs GmbH
#
# This file is part of the Genode OS framework, which is distributed
# under the terms of the GNU Affero General Public License version 3.
#

when not defined(genode) or defined(nimdoc):
  {.error: "Genode only module".}

type
  RpcEffect* = object of RootEffect
    ## Effect describing a synchronous client-side RPC.

  RegionMapObj {.
    importcpp: "Genode::Region_map",
    header: "<region_map/region_map.h>",
    final, pure.} = object
  RegionMap* = ptr RegionMapObj
    ## Opaque Region map object.

  EntrypointObj {.
    importcpp: "Genode::Entrypoint",
    header: "<base/entrypoint.h>",
    final, pure.} = object
  Entrypoint* = ptr EntrypointObj
    ## Opaque Entrypoint object.

  PdSessionObj {.
    importcpp: "Genode::Pd_session",
    header: "<region_map/region_map.h>",
    final, pure.} = object
  PdSession* = ptr PdSessionObj
    ## Opaque Protection Domain session object.

proc rm*(env: GenodeEnv): RegionMap {.
  importcpp: "&#->rm()".}

proc ep*(env: GenodeEnv): Entrypoint {.
  importcpp: "&#->ep()".}

proc pd*(env: GenodeEnv): PdSession {.
  importcpp: "&#->pd()".}

#
# C++ utilities
#

type Constructible* {.
  importcpp: "Genode::Constructible",
  header: "<util/reconstructible.h>", final, pure.} [T] = object

proc construct*[T](x: Constructible[T]) {.importcpp.}
  ## Construct a constructible C++ object.

proc destruct*[T](x: Constructible[T]) {.importcpp.}
  ## Destruct a constructible C++ object.

#
# Sessions
#

type SessionCapability* {.
  importcpp: "Genode::Session_capability",
  header: "<session/capability.h>", final, pure.} = object
  ## Capability to a session.

#
# Signals
#

type SignalContextCapability* {.
  importcpp: "Genode::Signal_context_capability",
  header: "<base/signal.h>", final, pure.} = object
  ## Capability to an asynchronous signal context.

#
# Dataspaces
#

import std/streams

type
  DataspaceCapability* {.
    importcpp: "Genode::Dataspace_capability", header: "dataspace/capability.h".} = object

proc isValid*(cap: DataspaceCapability): bool {.
  importcpp: "#.valid()", tags: [RpcEffect].}

proc size*(cap: DataspaceCapability): int {.
  importcpp: "Genode::Dataspace_client(@).size()", header: "dataspace/client.h",
  tags: [RpcEffect].}

proc allocDataspace*(pd: PdSession; size: int): DataspaceCapability {.
   importcpp: "#->alloc(#)", tags: [RpcEffect].}

proc freeDataspace*(pd: PdSession; cap: DataspaceCapability) {.
   importcpp: "#->free(#)", tags: [RpcEffect].}

proc attach*(rm: RegionMap; cap: DataspaceCapability): ByteAddress {.
   importcpp: "#->attach(@)", tags: [RpcEffect].}

proc detach*(rm: RegionMap; p: ByteAddress) {.
  importcpp: "#->detach(@)", tags: [RpcEffect].}

type
  DataspaceStreamObj = object of StreamObj
    ds: DataspaceStreamFactory
    pos: int
  DataspaceStream* = ref DataspaceStreamObj
    ## A stream that provides safe access to dataspace content

  DataspaceStreamFactory* = ref object
    ## Object for managing streams over a dataspace.
    ## If this object is freed before ``close`` is called it will
    ## continue to consume address space.
    rm: RegionMap
    data: ptr array[0, byte]
    size: int
      # actually its just a bit of RM metadata

proc size*(s: DataspaceStream): int =
  ## Return size of underlying dataspace.
  ## The result will always be page aligned.
  if not s.ds.isNil: result = s.ds.size

proc dsClose(s: Stream) =
  var s = DataspaceStream(s)
  s.ds = DataspaceStreamFactory()

proc dsAtEnd(s: Stream): bool =
  var s = DataspaceStream(s)
  assert(not s.ds.isNil, "stream is closed")
  s.pos >= s.ds.size

proc dsSetPosition(s: Stream, pos: int) =
  var s = DataspaceStream(s)
  assert(not s.ds.isNil, "stream is closed")
  s.pos = clamp(pos, 0, s.ds.size)

proc dsGetPosition(s: Stream): int =
  var s = DataspaceStream(s)
  assert(not s.ds.isNil, "stream is closed")
  clamp(s.pos, 0, s.size)

{.push boundChecks: off.}

proc clear*(s: DataspaceStream) =
  ## Zeros the contents of the dataspace.
  if not s.ds.isNil:
    zeroMem(s.ds.data[0].addr, s.ds.size)

proc dsPeekData(s: Stream, buffer: pointer, bufLen: int): int =
  var s = DataspaceStream(s)
  assert(not s.ds.isNil, "stream is closed")
  result = clamp(bufLen, 0, s.ds.size - s.pos)
  if result > 0:
    copyMem(buffer, s.ds.data[s.pos].addr, result)

proc dsReadData(s: Stream, buffer: pointer, bufLen: int): int =
  var s = DataspaceStream(s)
  assert(not s.ds.isNil, "stream is closed")
  result = clamp(bufLen, 0, s.ds.size - s.pos)
  if result > 0:
    copyMem(buffer, s.ds.data[s.pos].addr, result)
    inc(s.pos, result)

proc dsWriteData(s: Stream, buffer: pointer, bufLen: int) =
  var s = DataspaceStream(s)
  assert(not s.ds.isNil, "stream is closed")
  let count = clamp(bufLen, 0, s.ds.size - s.pos)
  copyMem(s.ds.data[s.pos].addr, buffer, count)
  inc(s.pos, count)

{.pop.}

proc dsFlush(s: Stream) = discard

proc newDataspaceStreamFactory*(rm: RegionMap): DataspaceStreamFactory =
  ## Initialize a new dataspace stream factory.
  DataspaceStreamFactory(rm: rm)

proc close*(f: DataspaceStreamFactory) =
  ## Close a dataspace and invalidate its streams.
  f.rm.detach cast[ByteAddress](f.data)
  f.data = nil
  f.size = 0

proc replace*(f: DataspaceStreamFactory; cap: DataspaceCapability) =
  ## Replace the underlying dataspace of present and future streams
  ## produced by this factory.
  if f.data != nil:
    close f
  if cap.isValid:
    f.data = cast[ptr array[0,byte]](f.rm.attach cap)
    f.size = cap.size

proc newStream*(f: DataspaceStreamFactory): DataspaceStream =
  ## Open a new stream over a dataspace.
  ## If the dataspace is updated at the factory then all currently
  ## issued streams will be updated as well.
  result = DataspaceStream(
    closeImpl: dsClose,
    atEndImpl: dsAtEnd,
    setPositionImpl: dsSetPosition,
    getPositionImpl: dsGetPosition,
    readDataImpl: dsReadData,
    peekDataImpl: dsPeekData,
    writeDataImpl: dsWriteData,
    flushImpl: dsFlush,
    ds: f)
