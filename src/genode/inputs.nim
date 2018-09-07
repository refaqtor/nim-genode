#
# Copyright (C) 2018 Genode Labs GmbH
#
# This file is part of the Genode OS framework, which is distributed
# under the terms of the GNU Affero General Public License version 3.
#

##
## This module provides a client of Genode
## **Input** services.
##
## For more information on the **Input** service please
## refer to section 4.5.4 of the `Genode Foundations
## <http://genode.org/documentation/genode-foundations-18-05.pdf>`_
## manual.
##
## Processing events from a **Nitpicker** **Input** client
## -------------------------------------------------------
##
## .. code-block:: nim
##
##   componentConstructHook = proc (env: GenodeEnv) =
##     ## Instantiate clients from global construct hook
##
##     let
##       nitClient = env.newNitpickerClient("input-handler")
##         ## Connect to Nitpicker server
##       input = env.newInputClient(nitClient.inputCap)
##         ## Create client using a capability from the Nitpicker session
##
##     proc processInput() =
##       ## Procedure to be executed by signal handler
##       for ev in input.events:
##         ## Iterate over queued events
##         ev.onWheel do (x, y: int):
##           scroll(y)
##         ev.onPress do (k: Keycode; u: Rune):
##           if k == KEY_ESC:
##             escape()
##
##     let inputDispatcher = env.ep.newSignalDispatcher(processInput, "input")
##     input.sigh(inputDispatcher.cap)
##       ## Install signal handler at input server
##

import std/unicode
import ../genode, ./signals

include ./keycodes

proc toKeyCode*(s: string): KeyCode =
  ## Convert the string representation of a key code to
  ## its enum value.
  result = KEY_UNKNOWN.KeyCode
  for k in Keycode:
    if $(k) == s:
      result = k
      break

from strutils import rsplit
const
  inputsPath = currentSourcePath.rsplit("/", 1)[0]
  inputsH = inputsPath & "/genode_inputs.h"

const
  eventH = "input/event.h"

type
  Event* {.importcpp: "Input::Event", header: inputsH.} = object
    ## Object representing an input event.

  EventKind {.importcpp: "Input::Binding::Event_type", pure.} = enum
    INVALID, PRESS, RELEASE, REL_MOTION, ABS_MOTION, WHEEL,
    FOCUS_ENTER, FOCUS_LEAVE, HOVER_LEAVE, TOUCH, TOUCH_RELEASE
    ## Each Input event is of a single kind.

  Wheel {.importcpp: "Inputs::Event::Wheel".} = object
  Absolute_motion {.importcpp: "Inputs::Event::Absolute_motion".} = object
  Relative_motion {.importcpp: "Inputs::Event::Relative_motion".} = object

proc kind(ev: Event): EventKind {.importcpp: "Input::Binding::type(#)".}

proc press_key(ev: Event): Keycode {.importcpp: "Input::Binding::attr(#).press.key".}
proc press_rune(ev: Event): uint32 {.importcpp: "Input::Binding::attr(#).press.codepoint.value".}

proc rel_motion_x(ev: Event): cint {.importcpp: "Input::Binding::attr(#).rel_motion.x".}
proc rel_motion_y(ev: Event): cint {.importcpp: "Input::Binding::attr(#).rel_motion.y".}

proc abs_motion_x(ev: Event): cint {.importcpp: "Input::Binding::attr(#).abs_motion.x".}
proc abs_motion_y(ev: Event): cint {.importcpp: "Input::Binding::attr(#).abs_motion.y".}

proc wheel_x(ev: Event): cint {.importcpp: "Input::Binding::attr(#).wheel.x".}
proc wheel_y(ev: Event): cint {.importcpp: "Input::Binding::attr(#).wheel.y".}

proc touch_id(ev: Event): cint {.importcpp: "Input::Binding::attr(#).touch.id".}
proc touch_x(ev: Event): cint {.importcpp: "Input::Binding::attr(#).touch.x".}
proc touch_y(ev: Event): cint {.importcpp: "Input::Binding::attr(#).touch.y".}

proc pressed*(ev: Event; key: KeyCode): bool {.
  importcpp: "#.key_press(@)".}
  ## Test if an key is pressed.

proc released*(ev: Event; key: KeyCode): bool {.
  importcpp: "#.key_release(@)".}
  ## Test if an key is released.

proc onPress*(ev: Event; cb: proc(key: Keycode; rune: Rune)) =
  ## Handle a press event.
  if ev.kind == EventKind.PRESS:
    cb(ev.press_key, ev.press_rune.Rune)

proc onRepeat*(ev: Event; cb: proc(rune: Rune)) =
  ## Handle a repeat event.
  if ev.kind == EventKind.PRESS and ev.press_key == KEY_UNKNOWN:
    cb(ev.press_rune.Rune)

proc onRelease*(ev: Event; cb: proc(key: Keycode)) =
  ## Handle a release event.
  if ev.kind == EventKind.RELEASE:
    cb(ev.press_key)

proc onRelativeMotion*(ev: Event; cb: proc(x, y: int)) =
  ## Handle a relative motion event.
  if ev.kind == EventKind.REL_MOTION:
    cb(ev.rel_motion_x, ev.rel_motion_y)

proc onAbsoluteMotion*(ev: Event; cb: proc(x, y: int)) =
  ## Handle an absolute motion event.
  if ev.kind == EventKind.ABS_MOTION:
    cb(ev.abs_motion_x, ev.abs_motion_y)

proc onWheel*(ev: Event; cb: proc(x, y: int)) =
  ## Handle a wheel event; values are relative.
  if ev.kind == EventKind.WHEEL:
    cb(ev.wheel_x, ev.wheel_y)

proc onTouch*(ev: Event; cb: proc(id, x, y: int)) =
  ## Handle a touch event
  if ev.kind == EventKind.TOUCH:
    cb(ev.touch_id, ev.touch_x, ev.touch_y)

proc onTouchRelease*(ev: Event; cb: proc(id: int)) =
  ## Handle a touch release.
  if ev.kind == EventKind.TOUCH_RELEASE:
    cb(ev.touch_id)

type
  InputSessionCapability* {.
    importcpp: "Input::Session_capability",
    header: "<input_session/capability.h>", final, pure.} = object
    ## Typed capability for an **Input** session.

  CppClientObj {.
    importcpp: "Input::Session_client",
    header: "<input_session/client.h>".} = object
  InputSessionClientPtr* = ptr CppClientObj

  InputClientObj = object of RootObj
    cpp: InputSessionClientPtr

  InputClient* = ref InputClientObj
    ## Client of **Input** service.

  CppConnectionObj {.
    importcpp: "Input::Connection", header: "<input_session/connection.h>".} = object
  CppConnection = Constructible[CppConnectionObj]
  InputClientConnectionObj = object of InputClientObj
    conn: CppConnection

  InputClientConnection* = ref InputClientConnectionObj

  EventBuffer {.unchecked.} = array[0, Event]
    ## Type to represent dataspace containing Events.

proc construct(cpp: CppConnection; env: GenodeEnv) {.
  importcpp: "#.construct(*#)".}

proc newInputClient*(session: InputSessionClientPtr): InputClient =
  ## Create a new **Input** client from a pointer to an existing **Input** session.
  InputClient(cpp: session)

proc newInputClient*(env: GenodeEnv): InputClientConnection =
  new result
  result.conn.construct(env)
  proc client(cpp: CppConnection): InputSessionClientPtr {.
    importcpp: "((Input::Session_client*)&(*#))".}
  result.cpp = result.conn.client
  GC_ref(result)
  ## Create a new **Input** client connection.
  ## Must be closed before it can be freed.

proc close*(input: InputClientConnection) {.tags: [RpcEffect].} =
  GC_unref(input)

proc sigh(input: InputSessionClientPtr; cap: SignalContextCapability) {.tags: [RpcEffect],
  importcpp: "#->sigh(@)".}

proc sigh*(input: InputClient; cap: SignalContextCapability) =
  input.cpp.sigh(cap)
  ## Install a signal handler at the **Input** server.

iterator events*(input: InputClient): Event =
  ## Flush and iterate over a client event queue.
  proc event_buffer(input: InputSessionClientPtr): ptr EventBuffer {.
    importcpp: "Input::Binding::event_buffer(*#)".}
  proc flush(input: InputSessionClientPtr): int {.tags: [RpcEffect],
    importcpp: "#->flush()".}
  let
    buf = input.cpp.eventBuffer
    n = flush input.cpp
  for i in 0..<n:
    yield buf[i]
