// Copyright 2022 Yury Popov
//
// Permission is hereby granted, free of charge, to any person obtaining a
// copy of this software and associated documentation files (the "Software"),
// to deal in the Software without restriction, including without limitation
// the rights to use, copy, modify, merge, publish, distribute, sublicense,
// and/or sell copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
// THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
// DEALINGS IN THE SOFTWARE.

import SwiftUI
import AVFAudio

fileprivate let userLangs = Set(Locale.preferredLanguages.map({ Locale(identifier: $0).language.universal }))
fileprivate let systemLangs = Set(Locale.Language.systemLanguages.flatMap({ [$0] + $0.parents }).map({ $0.universal }))
fileprivate let allLangs = Set(Locale.availableIdentifiers.map({ Locale(identifier: $0).language }).flatMap({ [$0] + $0.parents }).map({ $0.universal }))
fileprivate let currentLocale = Locale.autoupdatingCurrent

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
  var universal: Locale.Language { .init(identifier: universalId) }
  var localizedTitle: String {
    guard let langTitle = languageCode.flatMap({ currentLocale.localizedString(forLanguageCode: $0.identifier) }) else { return self.maximalIdentifier }
    if let regionTitle = region.flatMap({ currentLocale.localizedString(forRegionCode: $0.identifier) }) {
      return "\(langTitle) (\(regionTitle))"
    } else {
      return langTitle
    }
  }
}

struct VoiceOverLangSelector: View {
  private enum _Section: String {
    case user, system, all

    var title: String {
      switch self {
      case .user: return "User preferred"
      case .system: return "System"
      case .all: return "All"
      }
    }
    var langs: [Locale.Language] {
      switch self {
      case .user: return userLangs.sorted(by: { $0.localizedTitle.lexicographicallyPrecedes($1.localizedTitle) })
      case .system: return systemLangs.subtracting(userLangs).sorted(by: { $0.localizedTitle.lexicographicallyPrecedes($1.localizedTitle) })
      case .all: return allLangs.subtracting(userLangs).subtracting(systemLangs).sorted(by: { $0.localizedTitle.lexicographicallyPrecedes($1.localizedTitle) })
      }
    }
  }

  private struct _HeadNote: View {
    let section: _Section
    var body: some View {
      if section == .all {
        Text("Languages listed below may be poorly supported by VoiceOver and might be broken at all. They are available in \"Spoken content\".").font(.footnote).foregroundColor(.secondary)
      }
    }
  }

  @Binding var selectedLangs: Set<String>
  @State var searchText: String = ""
  let voiceOverLocales: Set<String>

  var body: some View {
    List {
      ForEach([_Section.user, .system, .all], id: \.rawValue) { sect in
        Section {
          _HeadNote(section: sect)
          ForEach(sect.langs.filter({
            voiceOverLocales.contains($0.universalId) == true &&
            (searchText.isEmpty || $0.localizedTitle.lowercased().contains(searchText.lowercased()))
          }), id: \.maximalIdentifier) { lang in
            Button(action: {
              if selectedLangs.contains(lang.universalId) {
                selectedLangs.remove(lang.universalId)
              } else {
                selectedLangs.insert(lang.universalId)
              }
            }) {
              HStack {
                Text(lang.localizedTitle).frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "checkmark")
                  .tint(.accentColor)
                  .opacity(selectedLangs.contains(lang.universalId) ? 1 : 0)
                  .accessibility(hidden: !selectedLangs.contains(lang.universalId))
              }
            }.tint(.primary).buttonStyle(BorderlessButtonStyle())
          }
        } header: {
          Text(sect.title)
        }
      }
    }.navigationTitle("VoiceOver")
    #if os(macOS)
      .searchable(text: $searchText, placement: SearchFieldPlacement.toolbar)
      .listStyle(InsetListStyle(alternatesRowBackgrounds: true))
    #else
      .searchable(text: $searchText, placement: SearchFieldPlacement.navigationBarDrawer(displayMode: .always))
    #endif
  }
}
