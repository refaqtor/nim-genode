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
  stream: Stream

proc newMenuView*(env: GenodeEnv; bufferSize = 4096): MenuView =
  new result
  result.report = env.newReportClient("dialog", bufferSize)
  result.stream = result.report.newStream

proc submit*(mv: MenuView) =
  ## Exposed for ``update`` template, not recommended to be used directly.
  mv.report.submit(mv.stream.getPosition)

proc clear*(mv: MenuView) =
  ## Clear the menu view.
  mv.stream.setPosition 0
  mv.stream.writeLine("""<dialog/>""")
  submit mv

template dialog*(mv: MenuView; body: untyped) =
  mv.stream.setPosition 0
  mv.stream.writeLine("""<dialog>""")
  body
  mv.stream.writeLine("""</dialog>""")
  submit mv

template frame*(mv: MenuView; name: string; body: untyped) =
  mv.stream.writeLine("<frame name=\"", name, "\">")
  body
  mv.stream.writeLine("""</frame>""")

template hbox*(mv: MenuView; name: string; body: untyped) =
  mv.stream.writeLine("<hbox name=\"", name, "\">")
  body
  mv.stream.writeLine("""</hbox>""")

template vbox*(mv: MenuView; name: string; body: untyped) =
  mv.stream.writeLine("<vbox name=\"", name, "\">")
  body
  mv.stream.writeLine("""</vbox>""")

template button*(mv: MenuView; name: string; body: untyped) =
  mv.stream.writeLine("<button name=\"", name, "\">")
  body
  mv.stream.writeLine("""</button>""")

proc label*(mv: MenuView; name, text: string) =
  mv.stream.writeLine("<label name=\"", name, "\" text=\"", text, "\"/>")

template float*(mv: MenuView; body: untyped) =
  mv.stream.writeLine("""<float>""")
  body
  mv.stream.writeLine("""</float>""")
