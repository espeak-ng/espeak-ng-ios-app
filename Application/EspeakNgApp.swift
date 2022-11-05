//
//  EspeakNgApp.swift
//  EspeakNg
//
//  Created by Yury Popov on 28.10.2022.
//

import SwiftUI
import Combine

@main
struct EspeakNgApp: App {
  @ObservedObject var audioUnit = ManagedAudioUnit()
  var body: some Scene {
    WindowGroup {
      switch audioUnit.state {
      case .none: EmptyView()
      case .failure(let e): Text("Error loading: \(e.localizedDescription)")
      case .success(let au):
#if os(iOS)
        NavigationView { ContentView(audioUnit: au) }
#else
        ContentView(audioUnit: au)
#endif
      }
    }
  }
}
