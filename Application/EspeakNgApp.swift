//
//  EspeakNgApp.swift
//  EspeakNg
//
//  Created by Yury Popov on 28.10.2022.
//

import SwiftUI

@main
struct EspeakNgApp: App {
  @State var espeakState: EspeakState = .setup
  var body: some Scene {
    WindowGroup {
      if case .done = espeakState {
        #if os(iOS)
        NavigationView { ContentView() }
        #else
        ContentView()
        #endif
      } else {
        InitScreen(state: $espeakState)
        #if !os(iOS)
          .frame(minWidth: 640, minHeight: 480)
        #endif
      }
    }
  }
}
