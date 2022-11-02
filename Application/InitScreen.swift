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
        ProgressView()
        Text("Syncing VoiceOver voices...")
          .onAppear {
            let (langs, voices) = _splitVoices(_buildVoiceList())
            let mapping = _buildMappings(langs)
            do {
              let enc = JSONEncoder()
              enc.outputFormatting = .sortedKeys
              let langsData = try enc.encode(langs)
              let voiceData = try enc.encode(voices)
              let mappingData = try enc.encode(mapping)

              let groupData = UserDefaults.appGroup
              groupData?.synchronize()

              if langsData != groupData?.data(forKey: "langs") || voiceData != groupData?.data(forKey: "voices") || mappingData != groupData?.data(forKey: "mapping") {
                groupData?.set(langsData, forKey: "langs")
                groupData?.set(voiceData, forKey: "voices")
                groupData?.set(mappingData, forKey: "mapping")
                groupData?.synchronize()
                AVSpeechSynthesisProviderVoice.updateSpeechVoices()
              }

              withAnimation { self.state = .done }
            } catch let e {
              withAnimation { self.state = .error(e) }
            }
          }
      case .done: Text("Done")
      case .error(let e): Text("eSpeak failure: \(String(describing: e))")
      }
    }.padding().background(RoundedRectangle(cornerRadius: 8).foregroundColor(.secondaryBackground))
  }
}

