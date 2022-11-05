//
//  Voices.swift
//  EspeakNg
//
//  Created by Yury Popov on 28.10.2022.
//

import Foundation
import libespeak_ng

struct _Voice: Hashable, Equatable, Codable {
  struct Language: Hashable, Equatable, Codable {
    let priority: UInt8
    let lang: String
  }

  let name: String
  let identifier: String
  let languages: [Language]
  let gender: UInt8
  let age: UInt8
}

fileprivate extension Array where Element == _Voice.Language {
  init(espeak bytes: UnsafePointer<CChar>) {
    self.init()
    var lang = bytes
    while lang.pointee != 0 {
      let idx = UInt8(bitPattern: lang.pointee)
      let name = String(cString: lang.advanced(by: 1))
      self.append(.init(priority: idx, lang: name))
      lang = lang.advanced(by: 1 + name.count)
    }
  }
}

fileprivate func _formatName(_ name: String) -> String {
  var formatted = ""
  var prevSpace = true
  var prevNumber = false
  for c in name {
    if c.isNumber {
      if !prevNumber {
        formatted.append(" ")
      }
      formatted.append(c)
    } else if c.isUppercase {
      if !prevSpace { formatted.append(" ") }
      formatted.append(c)
    } else if c.isWhitespace || c == "_" {
      formatted.append(" ")
    } else {
      formatted.append(prevSpace ? c.uppercased() : c.lowercased())
    }
    prevNumber = c.isNumber
    prevSpace = c.isWhitespace || c == "_" || c == "-" || c == "("
  }
  return formatted
}

func espeakVoiceList() -> (langs: [_Voice], voices: [_Voice]) {
  var sel = espeak_VOICE()
  var voices = espeak_ListVoices(&sel)
  var list = [_Voice]()
  while let v = voices?.pointee?.pointee {
    voices = voices?.advanced(by: 1)
    if String(cString: v.identifier).hasPrefix("mb/") { continue }
    list.append(_Voice(
      name: _formatName(String(cString: v.name)),
      identifier: String(cString: v.identifier).replacingOccurrences(of: "!v/", with: ""),
      languages: .init(espeak: v.languages),
      gender: v.gender,
      age: v.age
    ))
  }
  return (
    list.filter({ !$0.languages.contains(where: { $0.lang == "variant" }) })
      .sorted(by: { $0.name.lexicographicallyPrecedes($1.name) }),
    list.filter({ $0.languages.contains(where: { $0.lang == "variant" }) })
      .sorted(by: { $0.name.lexicographicallyPrecedes($1.name) })
  )
}
