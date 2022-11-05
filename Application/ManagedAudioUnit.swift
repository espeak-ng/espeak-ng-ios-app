//
//  ManagedAudioUnit.swift
//  EspeakNg
//
//  Created by Yury Popov on 05.11.2022.
//

import AVFAudio

class ManagedAudioUnit: ObservableObject {
  @Published var state: Result<AVAudioUnit, Error>?
  init() {
    let manager = AVAudioUnitComponentManager.shared()
    guard let component = manager.components(matching: AudioComponentDescription(
      componentType: kAudioUnitType_SpeechSynthesizer,
      componentSubType: 0x6573706B, // espk
      componentManufacturer: 0x4553504B, // ESPK
      componentFlags: AudioComponentFlags([.sandboxSafe,.isV3AudioUnit]).rawValue,
      componentFlagsMask: AudioComponentFlags([.sandboxSafe,.isV3AudioUnit]).rawValue
    )).first else {
      self.state = .failure(NSError(domain: "component", code: -1))
      return
    }
    AVAudioUnit.instantiate(with: component.audioComponentDescription, options: [.loadOutOfProcess], completionHandler: { unit, error in
      guard let unit = unit else {
        DispatchQueue.main.async {
          self.state = .failure(error ?? NSError(domain: "component", code: -2))
        }
        return
      }
      DispatchQueue.main.async {
        self.state = .success(unit)
      }
    })
  }
}
