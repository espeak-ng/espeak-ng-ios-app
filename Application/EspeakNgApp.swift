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
      NavigationStack {
        switch audioUnit.state {
        case .none: HStack(spacing: 8) {
          ProgressView()
          Text("Starting eSpeak engine...")
        }.padding()
        case .failure(let e): Text("Error loading: \(e.localizedDescription)")
        case .success(let au): ContentView(audioUnit: au)
        }
      }
    }
  }
}
