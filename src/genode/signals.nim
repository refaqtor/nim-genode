#
# Copyright (C) 2018 Genode Labs GmbH
#
# This file is part of the Genode OS framework, which is distributed
# under the terms of the GNU Affero General Public License version 3.
#

when not defined(genode) or defined(nimdoc):
  {.error: "Genode only module".}

import ../genode

from strutils import rsplit
const signalsPath = currentSourcePath.rsplit("/", 1)[0]
{.passC: "-I" & signalsPath.}

const SignalsH = signalsPath & "/signals.h"

type
  HandlerProc = proc () {.closure, gcsafe.}

  SignalDispatcherBase {.
    importcpp: "Nim::SignalDispatcher",
    header: SignalsH, pure.} = object

  SignalDispatcherCpp = Constructible[SignalDispatcherBase]

  SignalDispatcherObj = object
    cpp: SignalDispatcherCpp
    cb: HandlerProc
      ## Signal handling procedure called during dispatch.

  SignalHandler* = ref SignalDispatcherObj
    ## Nim object enclosing a Genode signal handler.

{.deprecated: [SignalDispatcher: SignalHandler].}

proc construct(cpp: SignalDispatcherCpp; ep: Entrypoint; sh: SignalHandler) {.importcpp.}

proc cap(cpp: SignalDispatcherCpp): SignalContextCapability {.
  importcpp: "#->cap()".}

proc newSignalHandler*(ep: Entrypoint; cb: HandlerProc; label = "unspecified"): SignalHandler =
  ## Create a new signal handler. A label is recommended for
  ## debugging purposes. A signal handler will not be garbage
  ## collected until after it has been dissolved.
  assert(not cb.isNil)
  result = SignalHandler(cb: cb)
  result.cpp.construct(ep, result)
  GCref result
  assert(not result.cb.isNil)

proc dissolve*(sig: SignalHandler) =
  ## Dissolve signal dispatcher from entrypoint.
  destruct sig.cpp
  GCunref sig

proc cap*(sig: SignalHandler): SignalContextCapability =
  ## Signal context capability. Can be delegated to external components.
  assert(not sig.cb.isNil)
  sig.cpp.cap

proc nimHandleSignal(p: pointer) {.exportc.} =
  ## C symbol invoked by entrypoint during signal dispatch.
  let dispatch = cast[SignalDispatcher](p)
  doAssert(not dispatch.cb.isNil)
  dispatch.cb()
