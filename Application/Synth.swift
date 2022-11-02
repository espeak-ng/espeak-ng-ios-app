//
//  Synth.swift
//  EspeakNg
//
//  Created by Yury Popov on 28.10.2022.
//

import Foundation
import libespeak_ng

extension Bundle {
  var appIdentifier: String? {
    return bundleIdentifier?
      .components(separatedBy: ".")
      .reversed()
      .trimmingPrefix(["synth-ext"])
      .reversed()
      .joined(separator: ".")
  }
}

extension UserDefaults {
  static var appGroup: Self? {
    let groupName = "group.\(Bundle.main.appIdentifier!)"
    return Self.init(suiteName: groupName)
  }
}

class SynthHolder {
  var samples: [Int16] = []
  var events: [espeak_EVENT] = []
}

fileprivate func synthCallback(samples: UnsafeMutablePointer<Int16>?, num_samples: Int32, events: UnsafeMutablePointer<espeak_EVENT>?) -> Int32 {
  let holder = events?.pointee.user_data.assumingMemoryBound(to: SynthHolder.self).pointee
  let buf = UnsafeBufferPointer(start: samples, count: Int(num_samples))
  holder?.samples.append(contentsOf: buf)
//  print(" - samples: count=\(num_samples) max=\(buf.reduce(0, { max($0, abs($1)) }))")
  var evt = events
  while let e = evt?.pointee, e.type != espeakEVENT_LIST_TERMINATED {
    holder?.events.append(e)
    evt = evt?.advanced(by: 1)
//    switch e.type {
//    case espeakEVENT_SAMPLERATE: print(" - samplerate: \(e.id.number)")
//    case espeakEVENT_SENTENCE: print(" - sentence: \(e.id.number) (smp=\(e.sample))")
//    case espeakEVENT_WORD: print(" - word: \(e.id.number) (smp=\(e.sample))")
//    case espeakEVENT_PHONEME: print(" - phoneme: '\(withUnsafeBytes(of: e.id.string, { String(cString: $0.bindMemory(to: CChar.self).baseAddress!) }))' (smp=\(e.sample))")
//    case espeakEVENT_END: print(" - end: (smp=\(e.sample))")
//    default: print(" - event: \(e.type)")
//    }
  }
  return 0
}

struct _Voice {
  let name: String
  let identifier: String
  let languages: [(UInt8, String)]
  let gender: UInt8
  let age: UInt8
}

extension _Voice: Codable {
  private enum Key: String, CodingKey { case name, identifier, languages, gender, age }
  private enum LangKey: String, CodingKey { case priority, lang }
  func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: Key.self)
    try c.encode(name, forKey: .name)
    try c.encode(identifier, forKey: .identifier)
    try c.encode(gender, forKey: .gender)
    try c.encode(age, forKey: .age)
    var l = c.nestedUnkeyedContainer(forKey: .languages)
    try languages.forEach { x in
      var c = l.nestedContainer(keyedBy: LangKey.self)
      try c.encode(x.0, forKey: .priority)
      try c.encode(x.1, forKey: .lang)
    }
  }
  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: Key.self)
    name = try c.decode(String.self, forKey: .name)
    identifier = try c.decode(String.self, forKey: .identifier)
    gender = try c.decode(UInt8.self, forKey: .gender)
    age = try c.decode(UInt8.self, forKey: .age)
    var list = [(UInt8, String)]()
    var l = try c.nestedUnkeyedContainer(forKey: .languages)
    while !l.isAtEnd {
      let x = try l.nestedContainer(keyedBy: LangKey.self)
      list.append((
        try x.decode(UInt8.self, forKey: .priority),
        try x.decode(String.self, forKey: .lang)
      ))
    }
    languages = list
  }
}

func setupSynth() throws {
  guard let root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.\(Bundle.main.appIdentifier!)") else {
    throw NSError(domain: EspeakErrorDomain, code: Int(ENS_NOT_SUPPORTED.rawValue))
  }
  if Bundle.main.bundleIdentifier == Bundle.main.appIdentifier {
    try EspeakLib.ensureBundleInstalled(inRoot: root)
  }
  espeak_ng_InitializePath(root.path)
  var res: espeak_ng_STATUS
  res = espeak_ng_Initialize(nil)
  guard res == ENS_OK else { throw NSError(domain: EspeakErrorDomain, code: Int(res.rawValue)) }
  res = espeak_ng_InitializeOutput(ENOUTPUT_MODE_SYNCHRONOUS, 0, nil)
  guard res == ENS_OK else { throw NSError(domain: EspeakErrorDomain, code: Int(res.rawValue)) }
  res = espeak_ng_SetVoiceByName(ESPEAKNG_DEFAULT_VOICE)
  guard res == ENS_OK else { throw NSError(domain: EspeakErrorDomain, code: Int(res.rawValue)) }
  let groupData = UserDefaults.appGroup
  groupData?.synchronize()
  for k in [espeakRATE, espeakVOLUME, espeakPITCH, espeakWORDGAP] {
    if let val = (groupData?.object(forKey: "espk.\(k.rawValue)")).flatMap({ ($0 as? NSNumber)?.intValue }) {
      res = espeak_ng_SetParameter(k, Int32(val), 0)
      guard res == ENS_OK else { throw NSError(domain: EspeakErrorDomain, code: Int(res.rawValue)) }
    }
  }
  espeak_ng_SetPhonemeEvents(1, 0)
  espeak_SetSynthCallback(synthCallback)
}

fileprivate func _decodeLangs(_ langs: UnsafePointer<CChar>) -> [(UInt8, String)] {
  var list = [(UInt8, String)]()
  var lang = langs
  while lang.pointee != 0 {
    let idx = UInt8(bitPattern: lang.pointee)
    let name = String(cString: lang.advanced(by: 1))
    list.append((idx, name))
    lang = lang.advanced(by: 1 + name.count)
  }
  return list
}

func _buildVoiceList() -> [_Voice] {
  var sel = espeak_VOICE()
  var voices = espeak_ListVoices(&sel)
  var list = [_Voice]()
  while let v = voices?.pointee?.pointee {
    voices = voices?.advanced(by: 1)
    if String(cString: v.identifier).hasPrefix("mb/") { continue }
    list.append(_Voice(
      name: String(cString: v.name),
      identifier: String(cString: v.identifier),
      languages: _decodeLangs(v.languages),
      gender: v.gender,
      age: v.age
    ))
  }
  return list
}

func _splitVoices(_ list: [_Voice]) -> (langs: [_Voice], voices: [_Voice]) {
  return (
    list.filter({ !$0.languages.contains(where: { $0.1 == "variant" }) }),
    list.filter({ $0.languages.contains(where: { $0.1 == "variant" }) })
  )
}
