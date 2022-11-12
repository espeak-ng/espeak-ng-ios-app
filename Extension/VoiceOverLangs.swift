//  eSpeak-NG VoiceOver synthesis AudioUnit
//  Copyright (C) 2022  Yury Popov <git@phoenix.dj>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <https://www.gnu.org/licenses/>.

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
