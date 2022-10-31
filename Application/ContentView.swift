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
import libespeak_ng

let engine = AVAudioEngine()
let playerNode = AVAudioPlayerNode()
let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 22050, channels: 1, interleaved: true)!

func _synth(_ text: String) throws {
  var holder = SynthHolder()
  try withUnsafeMutablePointer(to: &holder) { ptr in
    var res: espeak_ng_STATUS
    res = espeak_ng_Synthesize(text, text.count, 0, POS_CHARACTER, 0, 0, nil, ptr)
    guard res == ENS_OK else { throw NSError(domain: EspeakErrorDomain, code: Int(res.rawValue)) }
    res = espeak_ng_Synchronize()
    guard res == ENS_OK else { throw NSError(domain: EspeakErrorDomain, code: Int(res.rawValue)) }
  }

  let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(holder.samples.count))!
  for (i, s) in holder.samples.enumerated() {
    buffer.floatChannelData?[0][i] = Float32(s) / 32767.0
  }
  buffer.frameLength = buffer.frameCapacity

  if !engine.isRunning {
    engine.attach(playerNode)
    engine.connect(playerNode, to: engine.outputNode, format: buffer.format)
    engine.prepare()
    try engine.start()
  }

  playerNode.scheduleBuffer(buffer)
  playerNode.prepare(withFrameCount: buffer.frameLength)
  playerNode.play()
}

struct VoiceSelector: View {
  let (_langs, _voices) = _splitVoices(_buildVoiceList())
  @State var selectedLang = "gmw/en-US" { didSet { trySetVoice() } }
  @State var selectedVoice = "" { didSet { trySetVoice() } }
  func trySetVoice() {
    do {
      try setVoice()
    } catch let e {
      print(e)
    }
  }
  func setVoice() throws {
    let name = [
      selectedLang,
      selectedVoice.replacingOccurrences(of: "!v/", with: ""),
    ].filter({ !$0.isEmpty }).joined(separator: "+")
    let res = espeak_ng_SetVoiceByName(name)
    guard res == ENS_OK else { throw NSError(domain: EspeakErrorDomain, code: Int(res.rawValue)) }
  }
  var body: some View {
    HStack {
      Menu {
        ForEach(_langs, id: \.identifier) { l in
          Button(action: { selectedLang = l.identifier }, label: { Text(l.name) })
        }
      } label: {
        Text(_langs.first(where: { $0.identifier == selectedLang })?.name ?? "- None -")
          .frame(maxWidth: .infinity)
      }.buttonStyle(.bordered).accessibilityLabel("Language selector").accessibilityValue(
        Text(_langs.first(where: { $0.identifier == selectedLang })?.name ?? "None")
      )
      Menu {
        Button(action: { selectedVoice = "" }, label: { Text("- None -") })
        ForEach(_voices, id: \.identifier) { l in
          Button(action: { selectedVoice = l.identifier }, label: { Text(l.name) })
        }
      } label: {
        Text(_voices.first(where: { $0.identifier == selectedVoice })?.name ?? "- None -")
          .frame(maxWidth: .infinity)
      }.buttonStyle(.bordered).accessibilityLabel("Voice selector").accessibilityValue(
        Text(_voices.first(where: { $0.identifier == selectedVoice })?.name ?? "None")
      )
    }.frame(maxWidth: .infinity)
  }
}

struct TextInput: View {
  @State var synthText = "Hello"
  var body: some View {
    HStack {
      TextField("text", text: $synthText)
        .accessibilityLabel("Text to speak")
        .textFieldStyle(.roundedBorder).frame(maxWidth: .infinity)
      Button("eSpeak!") {
        do {
          try _synth(synthText)
        } catch let e {
          print(e)
        }
      }.accessibilityLabel("Synthesize").buttonStyle(.bordered)
    }
  }
}

struct ParameterSlider: View {
  let property: espeak_PARAMETER
  let title: String
  let range: ClosedRange<Int32>
  @State var value: Float
  init(_ property: espeak_PARAMETER, title: String, range: ClosedRange<Int32>) {
    self.property = property
    self.title = title
    self.range = range
    self.value = Float(espeak_GetParameter(property, 1))
  }
  var body: some View {
    VStack {
      Text("\(title): \(Int32(value))").frame(maxWidth: .infinity, alignment: .leading).accessibilityHidden(true)
      Slider(
        value: $value,
        in: Float(range.lowerBound)...Float(range.upperBound),
        step: 1,
        onEditingChanged: { _ in do {
          let res = espeak_ng_SetParameter(property, Int32(value), 0)
          guard res == ENS_OK else { throw NSError(domain: EspeakErrorDomain, code: Int(res.rawValue)) }
        } catch let e {
          print(e)
        } },
        minimumValueLabel: Text("\(range.lowerBound)").accessibilityHidden(true),
        maximumValueLabel: Text("\(range.upperBound)").accessibilityHidden(true),
        label: { Text(title) }
      ).accessibilityHint("\(range.lowerBound) to \(range.upperBound)")
    }
    .padding()
    .background(
      RoundedRectangle(cornerRadius: 8).foregroundColor(.secondaryBackground)
    )
  }
}

struct ContentView: View {
  @State var aboutShown: Bool = false
  var body: some View {
    ScrollView {
      VStack {
        VoiceSelector()
        TextInput()
        ParameterSlider(espeakRATE, title: "Rate", range: espeakRATE_MINIMUM...900)
        ParameterSlider(espeakVOLUME, title: "Volume", range: 0...200)
        ParameterSlider(espeakPITCH, title: "Pitch", range: 0...100)
        ParameterSlider(espeakWORDGAP, title: "Word gap", range: 0...500)
      }.padding()
    }
    .navigationTitle("eSpeak-NG")
    .toolbar {
//      #if os(iOS)
//      NavigationLink(destination: { AboutScreen() }, label: { Image(systemName: "info.circle") }).accessibilityLabel("About")
//      #else
      Button(action: { aboutShown = true }, label: { Image(systemName: "info.circle") }).accessibilityLabel("About")
        .sheet(isPresented: $aboutShown, content: { AboutScreen() })
//      #endif
    }
    #if os(iOS)
    .scrollDismissesKeyboard(.immediately)
    .navigationBarTitleDisplayMode(.inline)
    #endif
  }
}
