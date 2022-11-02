//
//  VoiceOverLangs.swift
//  EspeakNg
//
//  Created by Yury Popov on 30.10.2022.
//

import SwiftUI

fileprivate extension Locale {
  var langCode2: String? {
    language.languageCode?.identifier(.alpha2)
  }
  var langCode3: String? {
    language.languageCode?.identifier(.alpha3)
  }
  var idBCP47: String {
    identifier(.bcp47)
  }
  var regionId: String? {
    region?.identifier
  }
}

func _matchLang(_ langs: [_Voice], _ locale: Locale) -> _Voice? {
  let lidx = Set<String>([
    locale.idBCP47,
    locale.langCode2,
    locale.langCode3,
    [locale.langCode2, locale.regionId].compactMap({$0}).joined(separator: "-"),
    [locale.langCode3, locale.regionId].compactMap({$0}).joined(separator: "-"),
  ].compactMap({ $0?.lowercased() }))
//  print(locale.identifier, lidx)
  let compat = langs.filter({ v in v.languages.contains(where: { lidx.contains($0.1.lowercased()) }) })
  return compat.max(by: { v1, v2 in
    let p1 = v1.languages.compactMap({ lidx.contains($0.1.lowercased()) ? $0.0 : nil }).max() ?? 0
    let p2 = v2.languages.compactMap({ lidx.contains($0.1.lowercased()) ? $0.0 : nil }).max() ?? 0
    return p1 < p2
  })
}

func _buildMappings(_ langs: [_Voice]) -> [String:Set<String>] {
  let sysLocales = Locale.availableIdentifiers.map(Locale.init(identifier:))
  let sysLangs = Set(sysLocales.compactMap({ $0.langCode2 }))
  let sysLangSet = [String:(Locale,[Locale])](uniqueKeysWithValues: sysLangs.compactMap({ lid in
    guard let exact = sysLocales.first(where: { $0.identifier == lid }) else { return nil }
    let compat = sysLocales.filter({ $0.langCode2 == lid }).filter({ $0.identifier != lid })
    return (lid, (exact, compat))
  }))
  let ret = sysLangSet.flatMap({ (id, locales) -> [(_Voice, Set<String>)] in
    let (lang, regions) = locales
    guard let langBest = _matchLang(langs, lang) else { return [] }
    let regionsBest = regions.compactMap({ r in _matchLang(langs, r).flatMap({ (r, $0) }) })
    let uniques = Set([langBest.identifier] + regionsBest.map({ $0.1.identifier }))
    if uniques.count == 1, regionsBest.count == 1, let r = regionsBest.first { return [(r.1, Set([r.0.identifier]))] }
    if uniques.count == 1 { return [(langBest, Set([lang.identifier]))] }
    return [(langBest, Set([lang.identifier]))] + uniques.subtracting([langBest.identifier]).compactMap({ r in
      guard let v = langs.first(where: { $0.identifier == r }) else { return nil }
      return (v, Set(regionsBest.compactMap({ $0.1.identifier == v.identifier ? $0.0.identifier : nil })))
    })
  })
//  ret.forEach({ print(" - \($0.0.identifier) \($0.0.languages) \($0.1) ") })
  return .init(ret.map({ ($0.0.identifier, $0.1) }), uniquingKeysWith: { $0.union($1) })
}
