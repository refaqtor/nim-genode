#
# Copyright (C) 2018 Genode Labs GmbH
#
# This file is part of the Genode OS framework, which is distributed
# under the terms of the GNU Affero General Public License version 3.
#


##
## This module provides the means to use the
## Genode **menu_view** GUI framework.
##

import ../genode, ./reports
import streams

type MenuView* = ref object
  report: ReportClient
  stream: DataspaceStream

proc newMenuView*(env: GenodeEnv): MenuView =
  const bufferSize = 4096
  new result
  result.report = env.newReportClient("dialog", bufferSize)
  result.stream = result.report.newStream

proc submit*(mv: MenuView) =
  ## Exposed for ``update`` template, do not use
  mv.report.submit(mv.stream.getPosition)

template dialog*(mv: MenuView; body: untyped) =
  mv.stream.setPosition 0
  mv.stream.writeLine("<dialog>")
  body
  mv.stream.writeLine("</dialog>")
  submit mv

template frame*(mv: MenuView; body: untyped) =
  mv.stream.writeLine("<frame>")
  body
  mv.stream.writeLine("</frame>")

template vbox*(mv: MenuView; body: untyped) =
  mv.stream.writeLine("<vbox>")
  body
  mv.stream.writeLine("</vbox>")

template button*(mv: MenuView; name: string; body: untyped) =
  mv.stream.writeLine("<button text=\"", name, "\"/>")
  body
  mv.stream.writeLine("</button>")

proc label*(mv: MenuView; text: string) =
  mv.stream.writeLine("<label text=\"", text, "\"/>")
