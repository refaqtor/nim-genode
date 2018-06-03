#
# Copyright (C) 2018 Genode Labs GmbH
#
# This file is part of the Genode OS framework, which is distributed
# under the terms of the GNU Affero General Public License version 3.
#

const InputH = "<input/event.h>"

include keycodes

proc key_name(c: KeyCode): cstring {.
  importcpp: "Input::key_name(#)", header: InputH.}
proc `$`*(c: KeyCode): string = $key_name(c)

proc lookupKey*(s: string): KeyCode =
  result = KEY_UNKNOWN.KeyCode
  for k in 0..<KEY_MAX.KeyCode:
    if $(k.KeyCode) == s:
      result = k.KeyCode
      break

from strutils import rsplit
const eventsPath = currentSourcePath.rsplit("/", 1)[0]
{.passC: "-I" & eventsPath.}

const EventsH = eventsPath & "/inputevents.h"

type
  Event* {.importcpp: "Input::Event", header: InputH.} = object
  Kind* {.importcpp: "Input::Event::Type", header: InputH, pure.} = enum
    INVALID, PRESS, RELEASE, REL_MOTION, ABS_MOTION, WHEEL,
    FOCUS_ENTER, FOCUS_LEAVE, HOVER_LEAVE, TOUCH, TOUCH_RELEASE
  
  Wheel {.importcpp: "Input::Event::Wheel".} = object
  Absolute_motion {.importcpp: "Input::Event::Absolute_motion".} = object
  Relative_motion {.importcpp: "Input::Event::Relative_motion".} = object

proc kind*(ev: Event): Kind {.importcpp: "#._type".}

proc pressed*(ev: Event; key: KeyCode): bool {.
  importcpp: "#.key_press(@)".}

proc released*(ev: Event; key: KeyCode): bool {.
  importcpp: "#.key_release(@)".}

proc press(ev: Event; key: KeyCode): bool {.importcpp.}

proc code(ev: Event): KeyCode {.importcpp.}
proc ax(ev: Event): cint {.importcpp.}
proc ay(ev: Event): cint {.importcpp.}
proc rx(ev: Event): cint {.importcpp.}
proc ry(ev: Event): cint {.importcpp.}

proc wheel_x(ev: Event): int {.importcpp: "#._attr.wheel.x".}
proc wheel_y(ev: Event): int {.importcpp: "#._attr.wheel.y".}

proc wheel*(ev: Event): tuple[x: int; y: int] =
  assert(ev.kind == Kind.WHEEL)
  (ev.wheel_x, ev.wheel_y)

proc press_key(ev: Event): Keycode {.importcpp: "#._attr.press.key".}

proc key*(ev: Event): Keycode =
  assert(ev.kind in [Kind.PRESS, Kind.RELEASE])
  ev.press_key
