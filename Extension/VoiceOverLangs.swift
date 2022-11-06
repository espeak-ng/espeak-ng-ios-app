//
//  VoiceOverLangs.swift
//  EspeakNg
//
//  Created by Yury Popov on 30.10.2022.
//

import Foundation

extension Locale.Language {
  var parents: [Locale.Language] {
    guard let parent, !parent.isEquivalent(to: self) else { return [] }
    guard parent.languageCode?.identifier(.alpha2) != nil else { return [] }
    return [parent] + parent.parents
  }
  var universalId: String {
    return [
      languageCode?.identifier(.alpha2),
      region?.identifier
    ].compactMap({$0}).joined(separator: "-")
  }
  var universal: Self { return .init(identifier: universalId) }
}

fileprivate let allSystemLanguageVariangs = Set(
  (Locale.Language.systemLanguages + Locale.availableIdentifiers.map({ Locale(identifier: $0).language }))
    .flatMap({ [$0] + $0.parents })
    .map({ $0.universal })
)

let systemLanguages = [String:Set<Locale.Language>](
  allSystemLanguageVariangs
    .compactMap({ l in (l.languageCode?.identifier(.alpha2)).flatMap({ ($0, Set([l])) }) }),
  uniquingKeysWith: { $0.union($1) }
)

let defaultLanguages = Set(Locale.preferredLanguages.map({Locale(identifier:$0).language.universal}))
  .union([Locale.Language(identifier: "en-US").universal])

func matchLang(_ langs: [_Voice], _ locale: Locale.Language) -> _Voice? {
  let lidx = Set<String>([
    locale.universalId,
    locale.minimalIdentifier,
    locale.maximalIdentifier,
    locale.languageCode?.identifier(.alpha2),
    locale.languageCode?.identifier(.alpha3),
  ].compactMap({ $0?.lowercased() }))
  let compat = langs.filter({ v in v.languages.contains(where: { lidx.contains($0.lang.lowercased()) }) })
  return compat.max(by: { v1, v2 in
    let p1 = v1.languages.compactMap({ lidx.contains($0.lang.lowercased()) ? $0.priority : nil }).max() ?? 0
    let p2 = v2.languages.compactMap({ lidx.contains($0.lang.lowercased()) ? $0.priority : nil }).max() ?? 0
    return p1 < p2
  })
}
