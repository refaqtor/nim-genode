#
# Copyright (C) 2018 Genode Labs GmbH
#
# This file is part of the Genode OS framework, which is distributed
# under the terms of the GNU Affero General Public License version 3.
#


##
## This module provides a client of Genode
## *Report* services.
##
## For more information on the *Report* service please
## refer to section 4.5.2 of the `Genode Foundations
## <http://genode.org/documentation/genode-foundations-17-05.pdf>`_
## manual.
##
##
## .. code-block:: nim
##   import std/streams
##   import genode/reports, xmltree
##   let
##     report = newReportClient("status")
##     report.submit do (str: Stream):
##       let xml = <>some_xml_content(some_attr="some text")
##       str.writeLine(xml)
##

import ../genode, streams

const ReportH = "<report_session/connection.h>"

type
  ConnectionBase {.
    importcpp: "Report::Connection", header: ReportH.} = object
  Connection = Constructible[ConnectionBase]

  ReportClient* = ref ReportClientObj
  ReportClientObj = object
    conn: Connection
    streams: DataspaceStreamFactory
    bufferSize: int

proc newReportClient*(env: GenodeEnv; label: string; bufferSize = 4096): ReportClient=
  ## Open a new *Report* session.
  proc construct(c: Connection; env: GenodeEnv; label: cstring, bufferSize: csize) {.
    importcpp: "#.construct(*#, @)", tags: [RpcEffect].}
  proc dataspace(c: Connection): DataspaceCapability {.tags: [RpcEffect],
    importcpp: "#->dataspace()".}
  new result
  result.conn.construct(env, label, bufferSize)
  let ds = result.conn.dataspace
  result.streams = env.rm.newDataspaceStreamFactory(ds)
  result.bufferSize = ds.size

proc newStream*(r: ReportClient): Stream =
  ## Return a new stream over the *Report* dataspace.
  r.streams.newStream()

proc submit*(r: ReportClient; len: int) =
  ## Inform the serve of new content in the report dataspace of
  ## *len* length.
  proc submit(c: Connection, n: csize) {.tags: [RpcEffect],
    importcpp: "#->submit(#)".}
  r.conn.submit(len)

proc submit*(r: ReportClient; cb: proc(s: Stream)) =
  ## Submit a report.
  let ds = r.streams.newStream()
  clear ds
  cb ds
  r.submit(getPosition ds)
  close ds

proc close*(r: ReportClient) =
  ## Close a Report connection.
  r.bufferSize = 0
  close r.streams
  destruct r.conn
