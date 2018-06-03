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
##   import genode/reports, xmltree
##   let
##     report = newReportClient("status")
##     str = report.newStream()
##     xml = <>some_xml_content(some_attr="some text")
##   str.writeLine(xml)
##   report.submit()
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

proc construct(c: Connection; env: GenodeEnv; label: cstring, bufferSize: csize) {.
  importcpp: "#.construct(*#, @)", tags: [RpcEffect].}

proc dataspace(c: Connection): DataspaceCapability {.tags: [RpcEffect],
  importcpp: "#->dataspace()".}

proc submit(c: Connection, n: csize) {.tags: [RpcEffect],
  importcpp: "#->submit(#)".}

proc newReportClient*(env: GenodeEnv; label: string, bufferSize = 4096): ReportClient=
  ## Open a new *Report* session.
  new result
  result.conn.construct(env, label, bufferSize)
  result.streams = env.rm.newDataspaceStreamFactory()
  let ds = result.conn.dataspace
  result.streams.replace ds
  result.bufferSize = ds.size

proc newStream*(r: ReportClient): DataspaceStream =
  ## Open new a stream over the Report dataspace.
  r.streams.newStream

proc submit*(r: ReportClient; size = 0) =
  ## Submit a report
  assert(size < r.bufferSize)
  var size = size
  r.conn.submit(if size < 1: r.bufferSize else: size)

proc submit*(r: ReportClient; s: string) =
  ## Submit a report
  assert(s.len < r.bufferSize)
  let ds = r.newStream()
  ds.write(s)
  close ds
  r.conn.submit(s.len)

proc close*(r: ReportClient) =
  ## Close a Report connection.
  r.bufferSize = 0
  close r.streams
  destruct r.conn
