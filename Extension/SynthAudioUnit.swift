//
//  SynthAudioUnit.swift
//  Synth
//
//  Created by Yury Popov on 28.10.2022.
//

// NOTE:- An Audio Unit Speech Extension (ausp) is rendered offline, so it is safe to use
// Swift in this case. It is not recommended to use Swift in other AU types.

import AVFoundation
import Accelerate
import libespeak_ng
import OSLog

fileprivate let log = Logger(subsystem: "espeak-ng", category: "SynthAudioUnit")

class MappingContainer {
  let langs: [_Voice]
  let voices: [_Voice]
  let mapping: [String:Array<String>]
  init() {
    let enc = JSONDecoder()
    let groupData = UserDefaults.appGroup
    groupData?.synchronize()
    langs = (groupData?.value(forKey: "langs") as? Data).flatMap({ try? enc.decode([_Voice].self, from: $0) }) ?? []
    voices = (groupData?.value(forKey: "voices") as? Data).flatMap({ try? enc.decode([_Voice].self, from: $0) }) ?? []
    mapping = (groupData?.value(forKey: "mapping") as? Data).flatMap({ try? enc.decode([String:Array<String>].self, from: $0) }) ?? [:]
  }
}

private let emptyVoiceId = "__espeak"

public class SynthAudioUnit: AVSpeechSynthesisProviderAudioUnit {
  private var outputBus: AUAudioUnitBus
  private var _outputBusses: AUAudioUnitBusArray!
  private var format: AVAudioFormat
  private var output: [Float32] = []
  private var outputOffset: Int = 0
  private var outputMutex = DispatchSemaphore(value: 1)
  private static var espeakVoice = ""

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

  private func performRender(
    actionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
    timestamp: UnsafePointer<AudioTimeStamp>,
    frameCount: AUAudioFrameCount,
    outputBusNumber: Int,
    outputAudioBufferList: UnsafeMutablePointer<AudioBufferList>,
    renderEvents: UnsafePointer<AURenderEvent>?,
    renderPull: AURenderPullInputBlock?
  ) -> AUAudioUnitStatus {
    let unsafeBuffer = UnsafeMutableAudioBufferListPointer(outputAudioBufferList)
    let frames = unsafeBuffer[0].mData!.assumingMemoryBound(to: Float32.self)
    frames.assign(repeating: 0, count: Int(frameCount))

    self.outputMutex.wait()
    let count = min(self.output.count - self.outputOffset, Int(frameCount))
    self.output.withUnsafeBufferPointer { ptr in
      frames.assign(from: ptr.baseAddress!.advanced(by: self.outputOffset), count: count)
    }
    outputAudioBufferList.pointee.mBuffers.mDataByteSize = UInt32(count * MemoryLayout<Float32>.size)

    self.outputOffset += count
    if self.outputOffset >= self.output.count {
      actionFlags.pointee = .offlineUnitRenderAction_Complete
      self.output.removeAll()
      self.outputOffset = 0
    }
    self.outputMutex.signal()

    return noErr
  }

  public override var internalRenderBlock: AUInternalRenderBlock { self.performRender }

  public override func synthesizeSpeechRequest(_ speechRequest: AVSpeechSynthesisProviderRequest) {
    let text = speechRequest.ssmlRepresentation
    let voice = speechRequest.voice.identifier
    let parts = voice.split(separator: ".")
    let voice_id = parts.last.flatMap({ String($0) })
    let lang_id: String? = parts.prefix(parts.count-1).joined(separator: "/")
    let full_voice_id = [lang_id, voice_id == emptyVoiceId ? nil : voice_id].compactMap({ $0 }).joined(separator: "+")
    log.info("synth request: \(full_voice_id, privacy: .public) \(text, privacy: .public)")
    do {
      var holder = SynthHolder()
      try withUnsafeMutablePointer(to: &holder) { ptr in
        if Self.espeakVoice.isEmpty {
          try setupSynth()
        }
        var res: espeak_ng_STATUS
        if Self.espeakVoice != full_voice_id {
          res = espeak_ng_SetVoiceByName(full_voice_id)
          guard res == ENS_OK else { throw NSError(domain: EspeakErrorDomain, code: Int(res.rawValue)) }
          Self.espeakVoice = full_voice_id
        }
        res = espeak_ng_Synthesize(text, text.count, 0, POS_CHARACTER, 0, UInt32(espeakSSML | espeakCHARS_UTF8), nil, ptr)
        guard res == ENS_OK else { throw NSError(domain: EspeakErrorDomain, code: Int(res.rawValue)) }
        res = espeak_ng_Synchronize()
        guard res == ENS_OK else { throw NSError(domain: EspeakErrorDomain, code: Int(res.rawValue)) }
      }
      let resampled = vDSP.multiply(Float(1.0/32767.0), vDSP.integerToFloatingPoint(holder.samples, floatingPointType: Float.self))
      self.outputMutex.wait()
      self.output = resampled
      self.outputOffset = 0
      log.info("synth output: \(self.output.count) samples")
      self.outputMutex.signal()
    } catch let e {
      log.error("synth error: \(e, privacy: .public)")
    }
  }

  public override func cancelSpeechRequest() {
    self.outputMutex.wait()
    self.output.removeAll()
    self.outputOffset = 0
    log.info("stop synthesizing")
    self.outputMutex.signal()
  }

  public override var speechVoices: [AVSpeechSynthesisProviderVoice] {
    get {
      let container = MappingContainer()
      log.info("speechVoices begin")
      var list = [AVSpeechSynthesisProviderVoice]()
      list.reserveCapacity(container.mapping.count * (container.voices.count + 1))
      for (langId, localeIds) in container.mapping {
        let langPath = langId.replacingOccurrences(of: "/", with: ".")
        list.append(AVSpeechSynthesisProviderVoice(
          name: "ESpeak",
          identifier: "\(langPath).\(emptyVoiceId)",
          primaryLanguages: localeIds,
          supportedLanguages: localeIds
        ))
        for voice in container.voices {
          let v = AVSpeechSynthesisProviderVoice(
            name: voice.name,
            identifier: "\(langPath).\(voice.identifier)",
            primaryLanguages: localeIds,
            supportedLanguages: localeIds
          )
          switch UInt32(voice.gender) {
          case ENGENDER_MALE.rawValue: v.gender = .male
          case ENGENDER_FEMALE.rawValue: v.gender = .female
          default: v.gender = .unspecified
          }
          v.age = Int(voice.age)
          list.append(v)
        }
      }
      log.info("speechVoices done: \(list.count)")
      return list
    }
    set { }
  }

}

