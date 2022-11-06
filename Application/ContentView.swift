//
//  ContentView.swift
//  EspeakNg
//
//  Created by Yury Popov on 28.10.2022.
//

import SwiftUI
import AudioUnit
import AudioToolbox
import AVFoundation
import OSLog

let engine = AVAudioEngine()
let playerNode = AVAudioPlayerNode()
let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 22050, channels: 1, interleaved: true)!

fileprivate let log = Logger(subsystem: "espeak-ng", category: "ui")

struct VoiceSelector: View {
  let langs: [(id: String, name: String)]
  let voices: [(id: String, name: String)]

  @Binding var selectedLang: String
  @Binding var selectedVoice: String

  var body: some View {
    HStack {
      NavigationLink(destination: {
        SingleSelectionScreen(data: langs, id: \.id, selection: $selectedLang) {
          Text($0.name)
        }.navigationTitle("Language")
      }, label: {
        Text(langs.first(where: { $0.id == selectedLang })?.name ?? "- None -")
          .frame(maxWidth: .infinity)
      }).buttonStyle(.bordered).accessibilityLabel("Language selector").accessibilityValue(
        Text(langs.first(where: { $0.id == selectedLang })?.name ?? "None")
      )
      NavigationLink(destination: {
        SingleSelectionScreen(data: [(id: "", name: "- None -")] + voices, id: \.id, selection: $selectedVoice) {
          Text($0.name).accessibilityLabel($0.id.isEmpty ? "None" : $0.name)
        }.navigationTitle("Voice")
      }, label: {
        Text(voices.first(where: { $0.id == selectedVoice })?.name ?? "- None -")
          .frame(maxWidth: .infinity)
      }).buttonStyle(.bordered).accessibilityLabel("Voice selector").accessibilityValue(
        Text(voices.first(where: { $0.id == selectedVoice })?.name ?? "None")
      )
    }.frame(maxWidth: .infinity)
  }
}

struct TextInput: View {
  @Binding var synthText: String
  let block: (String) -> Void
  var body: some View {
    HStack {
      TextField("text", text: $synthText)
        .accessibilityLabel("Text to speak")
        .textFieldStyle(.roundedBorder).frame(maxWidth: .infinity)
      Button("eSpeak!") { block(synthText) }
        .accessibilityLabel("Synthesize")
        .buttonStyle(.bordered)
    }
  }
}

struct ParameterSlider: View {
  let parameter: AUParameter
  @State var value: Float
  init(_ param: AUParameter) {
    self.parameter = param
    self.value = Float(param.value)
  }
  var body: some View {
    VStack {
      Text("\(parameter.displayName): \(Int32(value))")
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityHidden(true)
      Slider(
        value: $value,
        in: Float(parameter.minValue)...Float(parameter.maxValue),
        step: 1,
        onEditingChanged: { if !$0 { parameter.value = .init(value) } },
        minimumValueLabel: Text("\(Int32(parameter.minValue))").accessibilityHidden(true),
        maximumValueLabel: Text("\(Int32(parameter.maxValue))").accessibilityHidden(true),
        label: { Text(parameter.displayName) }
      ).accessibilityHint("\(parameter.minValue) to \(parameter.maxValue)")
    }
    .padding()
    .background(
      RoundedRectangle(cornerRadius: 8).foregroundColor(.secondaryBackground)
    )
  }
}

class _Dummy {
  @objc var voicesData: Data? { nil }
  @objc var langsData: Data? { nil }
}

struct ContentView: View {
  let audioUnit: AVAudioUnit
  let langs: [(id: String, name: String)]
  let voices: [(id: String, name: String)]
  @State var synthText: String = "Hello"
  @State var langId: String = "gmw/en-US"
  @State var voiceId: String = ""
  init(audioUnit: AVAudioUnit) {
    self.audioUnit = audioUnit
    let params = audioUnit.auAudioUnit.parameterTree?.allParameters ?? []
    let langIds = params.first(where: { $0.identifier == "langId" })?.valueStrings ?? []
    let voiceIds = params.first(where: { $0.identifier == "voiceId" })?.valueStrings ?? []
    let langNames = params.first(where: { $0.identifier == "langName" })?.valueStrings ?? []
    let voiceNames = params.first(where: { $0.identifier == "voiceName" })?.valueStrings ?? []
    self.langs = zip(langIds, langNames).map({ (id: $0.0, name: $0.1) })
    self.voices = zip(voiceIds, voiceNames).map({ (id: $0.0, name: $0.1) })

    if engine.isRunning { engine.stop() }
    engine.attach(audioUnit)
    engine.connect(audioUnit, to: engine.outputNode, format: format)
    engine.prepare()
    try? engine.start()
  }
  var body: some View {
    ScrollView {
      VStack {
        VoiceSelector(langs: langs, voices: voices, selectedLang: $langId, selectedVoice: $voiceId)
        TextInput(synthText: $synthText, block: { text in
          let voice = [
            langId.replacingOccurrences(of: "/", with: "."),
            voiceId.isEmpty ? "__espeak" : voiceId,
          ].joined(separator: ".")
          let request = AVSpeechSynthesisProviderRequest(
            ssmlRepresentation: text,
            voice: .init(name: "", identifier: voice, primaryLanguages: [], supportedLanguages: [])
          )
          audioUnit.auAudioUnit.perform(#selector(AVSpeechSynthesisProviderAudioUnit.synthesizeSpeechRequest(_:)), with: request)
        })
        ForEach(audioUnit.auAudioUnit.parameterTree?.allParameters.filter({ $0.unit != .indexed }) ?? [], id: \.address, content: ParameterSlider.init)
      }.padding()
    }
    .navigationTitle("eSpeak-NG")
    .toolbar {
      NavigationLink(destination: { AboutScreen() }, label: { Image(systemName: "info.circle") })
        .accessibilityLabel("About")
    }
    #if os(iOS)
    .scrollDismissesKeyboard(.immediately)
    .navigationBarTitleDisplayMode(.inline)
    #endif
  }
}
