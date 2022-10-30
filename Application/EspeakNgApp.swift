//
//  EspeakNgApp.swift
//  EspeakNg
//
//  Created by Yury Popov on 28.10.2022.
//

import SwiftUI
import AVFAudio

@main
struct EspeakNgApp: App {
  init() {
    do {
      try setupSynth()
    } catch let e {
      print(e)
    }

    #if os(iOS)
    let (langs, voices) = _splitVoices(_buildVoiceList())
    let mapping = _buildMappings(langs)
    let groupData = UserDefaults(suiteName: "group.dj.phoenix.espeak-ng")
    do {
      let enc = JSONEncoder()
      groupData?.synchronize()
      groupData?.set(try? enc.encode(langs), forKey: "langs")
      groupData?.set(try? enc.encode(voices), forKey: "voices")
      groupData?.set(try? enc.encode(mapping), forKey: "mapping")
      groupData?.synchronize()
    }

    AVSpeechSynthesisProviderVoice.updateSpeechVoices()
    #endif
  }
  var body: some Scene {
    WindowGroup {
      #if os(iOS)
      NavigationView { ContentView() }
      #else
      ContentView()
      #endif
    }
  }
}
