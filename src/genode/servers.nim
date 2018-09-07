#
# Copyright (C) 2018 Genode Labs GmbH
#
# This file is part of the Genode OS framework, which is distributed
# under the terms of the GNU Affero General Public License version 3.
#

# TODO: Provide sesion creation and destruction examples.

import ../genode, ./roms, ./parents

import parseutils, strutils, strtabs, streams,
  parsexml, xmlparser, xmltree

const LabelSep* = " ->"
  ## Pattern used to seperate session label elements.

proc lastLabelElement*(label: TaintedString): string =
  ## Return the last element in a session label.
  let i = label.rFind LabelSep
  if unlikely(i == -1):
    label
  else:
    label[i+1+LabelSep.len..label.high]

iterator elements*(label: TaintedString): string =
  ## Iterate the elements of a session label from left to right.
  var
    buf = ""
    pos = 0
  while pos < label.len:
    let n = parseuntil(label, buf, LabelSep, pos)
    if n == 0: break
    yield buf.strip
    pos.inc(n + LabelSep.len+1)

proc lookupPolicy*(policies: seq[XmlNode]; label: TaintedString): XmlNode =
  ## Return a policy matching a given label or return nil.
  # TODO: use less GC intensive parsing.
  var resultScore: int
  for p in policies.items:
    if p.tag == "default-policy" and result.isNil:
      # this is now the fallthrough policy
      result = p
    else:
      let attrs = p.attrs
      if attrs.contains "label":
        if attrs["label"] == label:
          # return the first policy with a label match
          return p
      else:
        let
          prefix = attrs.getOrDefault "prefix"
          suffix = attrs.getOrDefault "suffix"
        if label.startsWith(prefix) and label.endsWith(suffix):
          # match the label against prefix and suffic (empty strings match)
          let score = prefix.len*2 + suffix.len
            # a prefix match is more significant that a suffix match
          if score > resultScore:
            # this is now the best match this far
            resultScore = score
            result = p

proc parseArgString*(args: TaintedString; key: string; default = ""): string =
  ## Extract a keyed value from session request arguments.
  result = default
  var off = args.find key
  if off != -1:
    off.inc key.len
    if args[off] == '=' and args[off+1] == '"':
      off.inc 2
      off.inc parseuntil(args, result, '"', off)
      if args[off] != '"':
        result = default

proc parseArgInt*(args: TaintedString; key: string; default = -1): BiggestInt =
  ## Extract an integral argument from session request arguments.
  result = default
  var off = args.find key
  if off != -1:
    off.inc key.len
    if args[off] == '=':
      inc off
      off.inc parseBiggestInt(args, result, off)
      if off < args.len:
        case args[off]
        of ',':
          discard
        of 'K':
          result = result shl 10
        of 'M':
          result = result shl 20       
        of 'G':
          result = result shl 30
        of 'P':
          result = result shl 40
        else:
          result = -1

type
  SessionRequestsParser = object
    rom: RomClient
    xp: XmlParser

proc initSessionRequestsParser*(rom: RomClient): SessionRequestsParser =
  ## Initialize a parser of the Genode "session_requests" ROM.
  SessionRequestsParser(rom: rom)

proc argString*(args, key: string; default = ""): string =
 ## Parse an string from the current session arguments.
 if args != "":
   parseArgString(args, key, default)
 else:
   default

proc argInt*(args, key: string; default = -1): BiggestInt =
 ## Parse an integer from the current session arguments.
 if args != "":
   parseArgInt(args, key, default)
 else:
   default

proc next(srp: var SessionRequestsParser) {.inline.} =
  next srp.xp

proc skipRest(srp: var SessionRequestsParser) =
  var depth = 1
  while depth > 0:
    case srp.xp.kind
    of xmlElementStart, xmlElementOpen: inc depth
    of xmlElementEnd, xmlElementClose: dec depth
    of xmlEof: break
    of xmlError: raise newException(ValueError, srp.xp.errorMsg)
    else: discard
    next srp

iterator create*(srp: var SessionRequestsParser; service: string): tuple[id: ServerId, label, args: TaintedString] =
  ## Iterate over session creation requests.
  var serviceName = ""
  let str = srp.rom.newStream
  open srp.xp, str, "session_requests"
  next srp
  block requestsLoop:
    while true:
      case srp.xp.kind:
      of xmlElementOpen:
        if srp.xp.elementName == "create":
          next srp
          block createLoop:
            var result: tuple[id: ServerId; label, args: TaintedString]
            while srp.xp.kind == xmlAttribute:
              case srp.xp.attrKey:
              of "id":
                result.id = srp.xp.attrValue.parseInt.ServerId
              of "service":
                serviceName = srp.xp.attrValue
              of "label":
                result.label = srp.xp.attrValue
              next srp
            while srp.xp.kind != xmlElementClose: # skip until ``>``
              next srp
            next srp
            if srp.xp.kind == xmlElementStart and srp.xp.elementName == "args":
              result.args = ""
              next srp
              while srp.xp.kind != xmlElementEnd:
                if srp.xp.kind == xmlCharData:
                  result.args.add srp.xp.charData
                next srp
              next srp
            skipRest srp
            if serviceName == service:
              yield result
        else:
          next srp
      of xmlEof:
        break requestsLoop
      of xmlError:
        raise newException(ValueError, srp.xp.errorMsg)
      else: next srp # skip other events
  close srp.xp

iterator close*(srp: var SessionRequestsParser): ServerId =
  ## Iterate over session close requests.
  let str = srp.rom.newStream
  open srp.xp, str, "session_requests"
  next srp
  block requestsLoop:
    while true:
      case srp.xp.kind:
      of xmlElementOpen:
        case srp.xp.elementName:
        of "close":
          var id: ServerId
          next srp
          while srp.xp.kind == xmlAttribute:
            if srp.xp.attrKey == "id":
              id = srp.xp.attrValue.parseInt.ServerId
              next srp
              break
            next srp
          skipRest srp
          yield id
        else:
          next srp
      of xmlEof:
        break requestsLoop
      of xmlError:
        raise newException(ValueError, srp.xp.errorMsg)
      else: next srp # skip other events
  close srp.xp
