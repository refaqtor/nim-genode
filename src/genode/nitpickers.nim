#
# Copyright (C) 2018 Genode Labs GmbH
#
# This file is part of the Genode OS framework, which is distributed
# under the terms of the GNU Affero General Public License version 3.
#

##
## This module provides a client of the Genode
## *Nitpicker* GUI services.
##
## For more information on the *Nitpicker* service please
## refer to section 4.5.6 of the `Genode Foundations
## <http://genode.org/documentation/genode-foundations-18-05.pdf>`_
## manual.
##

import ../genode, ./inputs, ./signals

const NitpickerH = "<nitpicker_session/connection.h>"

type
  ConnectionBase {.
    importcpp: "Nitpicker::Connection", header: NitpickerH.} = object
  Connection = Constructible[ConnectionBase]

  NitpickerClientObj = object
    conn: Connection
  NitpickerClient* = ref NitpickerClientObj
    ## Client of Nitpicker service.

  NitpickerConnectionObj {.importcpp: "Nitpicker::Connection".} = object
  NitpickerConnectionPtr* = ptr NitpickerConnectionObj
    ## Raw pointer to Nitpicker C++ class.

  Mode* {.importcpp: "Framebuffer::Mode", header: NitpickerH.} = object

  ViewHandle* {.
    importcpp: "Nitpicker::Session::View_handle", header: NitpickerH.} = object

proc construct(conn: Connection; env: GenodeEnv; label: cstring) {.
  importcpp: "#.construct(*#, #)".}

proc cpp(conn: Connection): NitpickerConnectionPtr {.
  importcpp: "&(*#)".}

proc newNitpickerClient*(env: GenodeEnv; label = ""): NitpickerClient =
  new result
  result.conn.construct(env, label)

proc close*(np: NitpickerClient) =
  destruct np.conn

proc cpp*(np: NitpickerClient): NitpickerConnectionPtr =
  np.conn.cpp

proc width*(m: Mode): int {.importcpp.}
proc height*(m: Mode): int {.importcpp.}

proc mode(conn: Connection): Mode {.
  importcpp: "#->mode()".}

proc mode*(np: NitpickerClient): Mode = mode np.conn
  ## Return physical screen mode.

proc mode_sigh(conn: Connection; cap: SignalContextCapability) {.
  importcpp: "#->mode_sigh(#)".}

proc modeSigh*(np: NitpickerClient; cap: SignalContextCapability) =
  ## Register signal handler to be notified about mode changes.
  np.conn.modeSigh cap

proc inputCap(conn: Connection): inputs.SessionCapability {.
  importcpp: "*(#->input())".}

proc inputCap*(np: NitpickerClient): inputs.SessionCapability =
  ## Return capability to the Input sub-session.
  np.conn.inputCap()

proc create_view*(np: NitpickerClient): ViewHandle {.
  importcpp: "#->create_view()".}
proc create_view*(np: NitpickerClient; vh: ViewHandle): ViewHandle {.
  importcpp: "#->create_view(@)".}
