#
# Copyright (C) 2018 Genode Labs GmbH
#
# This file is part of the Genode OS framework, which is distributed
# under the terms of the GNU Affero General Public License version 3.
#

import ../genode

type
  ParentObj {.
    importcpp: "Genode::Parent",
    header: "<parent/parent.h>",
    final, pure.} = object
  Parent* = ptr ParentObj
    ## Opaque Parent object.

  ServerId* = distinct int
    ## Server-side session identifier shared between
    ## parent and child components.

  ClientId* = distinct int
    ## Client-side session identifier shared between
    ## parent and child components.

{.deprecated: [SessionId: ServerId].}

proc `==`*(x, y: ServerId): bool {.borrow.}
proc `==`*(x, y: ClientId): bool {.borrow.}
proc `$`*(id: ServerId): string {.borrow.}
proc `$`*(id: ClientId): string {.borrow.}

proc parent*(env: GenodeEnv): Parent {.
  importcpp: "(&#->parent())".}
  ## Parent accessor of Genode environment.

proc session*(env: GenodeEnv; service: cstring; id: ClientId; args: cstring): SessionCapability {.
  importcpp: "#->session(#, Genode::Parent::Client::Id{#}, Genode::Parent::Session_args(#), Genode::Affinity())",
  tags: [RpcEffect].}
  ## Open a session at the parent and return its identifier and capability.

proc close*(p: Parent; id: ClientId) {.
  importcpp: "#->close(Genode::Parent::Client::Id{#})", tags: [RpcEffect].}
  ## Close a session by session identifier.

proc sessionResponseDeny*(p: Parent; id: ServerId) {.
  importcpp: "#->session_response(Genode::Parent::Server::Id{#}, Genode::Parent::SERVICE_DENIED)",
  tags: [RpcEffect].}

proc sessionResponseClose*(p: Parent; id: ServerId) {.
  importcpp: "#->session_response(Genode::Parent::Server::Id{#}, Genode::Parent::SESSION_CLOSED)",
  tags: [RpcEffect].}

proc deliverSession*(p: Parent; id: ServerId; cap: untyped) {.
  importcpp: "#->deliver_session_cap(Genode::Parent::Server::Id{#}, #)",
  tags: [RpcEffect].}

proc announce*(p: Parent; service: cstring) {.importcpp.}
  ## Announce a service to the parent.
