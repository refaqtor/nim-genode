#
# Copyright (C) 2018 Genode Labs GmbH
#
# This file is part of the Genode OS framework, which is distributed
# under the terms of the GNU Affero General Public License version 3.
#

##
## This module provides utilities for instrumenting the Nim runtime.
##

import std/streams, std/locks
import ../genode, ./reports

when not defined(nimTypeNames):
  {.error: "pass -d:nimTypeNames for heap reports".}

var
  reportLock: Lock
  reporter {.guard: reportLock.}: ReportClient

proc submitHeapReport*(env: GenodeEnv) =
  ## Submits a "heap_dump" report of the size of heaps
  ## and name, count, and size of types on heaps.
  ## Requires **-d:nimTypeNames** to be passed
  ## during compilation.
  withLock reportLock:
    if reporter.isNil:
      reporter = env.newReportClient("heap_dump")
    reporter.submit do (str: Stream):
      str.writeLine("<heap>")
      for x in dumpHeapInstances():
        str.writeLine("\t<type name=\"", x.name,
          "\" count=\"", x.count, "\" sizes=\"", x.sizes, "\"/>")
      str.writeLine("</heap>")
