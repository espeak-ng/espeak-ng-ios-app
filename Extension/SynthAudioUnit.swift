//
//  SynthAudioUnit.swift
//  Synth
//
//  Created by Yury Popov on 28.10.2022.
//

// NOTE:- An Audio Unit Speech Extension (ausp) is rendered offline, so it is safe to use
// Swift in this case. It is not recommended to use Swift in other AU types.

import AVFoundation
import libespeak_ng

class MappingContainer {
  let langs: [_Voice]
  let voices: [_Voice]
  let mapping: [String:Set<String>]
  private init() {
    let enc = JSONDecoder()
    let groupData = UserDefaults(suiteName: "group.dj.phoenix.espeak-ng")
    groupData?.synchronize()
    langs = (groupData?.value(forKey: "langs") as? Data).flatMap({ try? enc.decode([_Voice].self, from: $0) }) ?? []
    voices = (groupData?.value(forKey: "voices") as? Data).flatMap({ try? enc.decode([_Voice].self, from: $0) }) ?? []
    mapping = (groupData?.value(forKey: "mapping") as? Data).flatMap({ try? enc.decode([String:Array<String>].self, from: $0) })?.mapValues({ Set($0) }) ?? [:]
  }
  static let shared = MappingContainer()
}

public class SynthAudioUnit: AVSpeechSynthesisProviderAudioUnit {
  private var outputBus: AUAudioUnitBus
  private var _outputBusses: AUAudioUnitBusArray!
  private var request: AVSpeechSynthesisProviderRequest?
  private var format: AVAudioFormat
  private var output: [Float32] = []

  @objc override init(componentDescription: AudioComponentDescription, options: AudioComponentInstantiationOptions) throws {
    let basicDescription = AudioStreamBasicDescription(
      mSampleRate: 22050.0,
      mFormatID: kAudioFormatLinearPCM,
      mFormatFlags: kAudioFormatFlagsNativeFloatPacked | kAudioFormatFlagIsNonInterleaved,
      mBytesPerPacket: 4,
      mFramesPerPacket: 1,
      mBytesPerFrame: 4,
      mChannelsPerFrame: 1,
      mBitsPerChannel: 32,
      mReserved: 0
    )
    self.format = AVAudioFormat(cmAudioFormatDescription: try! CMAudioFormatDescription(audioStreamBasicDescription: basicDescription))
    outputBus = try AUAudioUnitBus(format: self.format)
    try super.init(componentDescription: componentDescription, options: options)
    _outputBusses = AUAudioUnitBusArray(audioUnit: self, busType: AUAudioUnitBusType.output, busses: [outputBus])
  }

  public override var outputBusses: AUAudioUnitBusArray {
    return _outputBusses
  }

  public override func allocateRenderResources() throws {
    try super.allocateRenderResources()
  }

  public func setupParameterTree(_ parameterTree: AUParameterTree) {
    self.parameterTree = parameterTree
    for param in parameterTree.allParameters {
      setParameter(paramAddress: param.address, value: param.value)
    }
    setupParameterCallbacks()
  }

  private func setupParameterCallbacks() {
    parameterTree?.implementorValueObserver = { [weak self] param, value -> Void in
      self?.setParameter(paramAddress: param.address, value: value)
    }
    parameterTree?.implementorValueProvider = { [weak self] param in
      return self!.getParameter(param.address)
    }
    parameterTree?.implementorStringFromValueCallback = { param, valuePtr in
      guard let value = valuePtr?.pointee else { return "-" }
      return NSString.localizedStringWithFormat("%.f", value) as String
    }
  }

  func setParameter(paramAddress: AUParameterAddress, value: AUValue) {
    switch paramAddress {
//    case SynthParameterAddress.gain.rawValue:
//      linearGain = value
    default: return
    }
  }

  func getParameter(_ paramAddress: AUParameterAddress) -> AUValue {
    switch paramAddress {
//    case SynthParameterAddress.gain.rawValue:
//      return linearGain
    default: return 0.0
    }
  }

  public override var internalRenderBlock: AUInternalRenderBlock {
    return { actionFlags, timestamp, frameCount, outputBusNumber, outputAudioBufferList, _, _ in
      let unsafeBuffer = UnsafeMutableAudioBufferListPointer(outputAudioBufferList)[0]
      let frames = unsafeBuffer.mData!.assumingMemoryBound(to: Float32.self)
      frames.assign(repeating: 0, count: Int(frameCount))
      let count = min(self.output.count, Int(frameCount))
      frames.assign(from: self.output, count: count)
      self.output.removeFirst(count)
      if self.output.isEmpty {
        actionFlags.pointee = .offlineUnitRenderAction_Complete
      }
      return noErr
    }
  }

  public override func synthesizeSpeechRequest(_ speechRequest: AVSpeechSynthesisProviderRequest) {
    self.request = speechRequest
    let text = speechRequest.ssmlRepresentation
    let voice = speechRequest.voice.identifier
    let parts = voice.split(separator: ".")
    let voice_id = parts.last.flatMap({ String($0) })
    let lang_id: String? = parts.prefix(parts.count-1).joined(separator: "/")
    let full_voice_id = [lang_id, voice_id].compactMap({ $0 }).joined(separator: "+")
    NSLog("Voice: ", full_voice_id);
    do {
      try setupSynth()
      var holder = SynthHolder()
      try withUnsafeMutablePointer(to: &holder) { ptr in
        var res: espeak_ng_STATUS
        res = espeak_ng_SetVoiceByName(full_voice_id)
        guard res == ENS_OK else { throw NSError(domain: EspeakErrorDomain, code: Int(res.rawValue)) }
        res = espeak_ng_Synthesize(text, text.count, 0, POS_CHARACTER, 0, UInt32(espeakSSML | espeakCHARS_UTF8), nil, ptr)
        guard res == ENS_OK else { throw NSError(domain: EspeakErrorDomain, code: Int(res.rawValue)) }
        res = espeak_ng_Synchronize()
        guard res == ENS_OK else { throw NSError(domain: EspeakErrorDomain, code: Int(res.rawValue)) }
      }
      self.output = holder.samples.map({ Float32($0) / 32767.0 })
      NSLog("Output length: %@", NSNumber(value: self.output.count))
    } catch let e {
      NSLog("Synth error: %@", e as NSError)
    }
    espeak_ng_Terminate()
  }

  public override func cancelSpeechRequest() {
    self.request = nil
    NSLog("Stop synthesizing")
  }

  public override var speechVoices: [AVSpeechSynthesisProviderVoice] {
    get {
      let container = MappingContainer.shared
      return container.mapping.flatMap({ langId, localeIds -> [AVSpeechSynthesisProviderVoice] in
        return container.voices.map({ voice in
          let v = AVSpeechSynthesisProviderVoice(
            name: voice.name,
            identifier: [
              langId.replacingOccurrences(of: "/", with: "."),
              voice.identifier.replacingOccurrences(of: "!v/", with: "")
            ].joined(separator: "."),
            primaryLanguages: Array(localeIds),
            supportedLanguages: Array(localeIds)
          )
          switch UInt32(voice.gender) {
          case ENGENDER_MALE.rawValue: v.gender = .male
          case ENGENDER_FEMALE.rawValue: v.gender = .female
          default: v.gender = .unspecified
          }
          v.age = Int(voice.age)
          return v
        })
      })
    }
    set { }
  }

}

