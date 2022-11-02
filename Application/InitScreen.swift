//
//  InitScreen.swift
//  EspeakNg
//
//  Created by Yury Popov on 31.10.2022.
//

import SwiftUI
import AVFAudio

enum EspeakState {
  case setup
  case extracted
  case done
  case error(Error)
}

struct InitScreen: View {
  @Binding var state: EspeakState
  var body: some View {
    VStack {
      switch state {
      case .setup:
        ProgressView()
        Text("Starting espeak-ng engine...")
          .onAppear {
            do {
              try setupSynth()
              withAnimation { self.state = .extracted }
            } catch let e {
              withAnimation { self.state = .error(e) }
            }
          }
      case .extracted:
  #if os(iOS)
        ProgressView()
        Text("Syncing VoiceOver voices...")
          .onAppear {
            let (langs, voices) = _splitVoices(_buildVoiceList())
            let mapping = _buildMappings(langs)
            let groupName = "group.\(Bundle.main.appIdentifier!)"
            let groupData = UserDefaults(suiteName: groupName)
            do {
              let enc = JSONEncoder()
              groupData?.synchronize()
              groupData?.set(try enc.encode(langs), forKey: "langs")
              groupData?.set(try enc.encode(voices), forKey: "voices")
              groupData?.set(try enc.encode(mapping), forKey: "mapping")
              groupData?.synchronize()

              AVSpeechSynthesisProviderVoice.updateSpeechVoices()

              withAnimation { self.state = .done }
            } catch let e {
              withAnimation { self.state = .error(e) }
            }
          }
  #else
        Text(" ").onAppear { withAnimation { self.state = .done } }
  #endif
      case .done: Text("Done")
      case .error(let e): Text("eSpeak failure: \(String(describing: e))")
      }
    }.padding().background(RoundedRectangle(cornerRadius: 8).foregroundColor(.secondaryBackground))
  }
}

