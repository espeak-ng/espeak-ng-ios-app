// Copyright 2022 Yury Popov
//
// Permission is hereby granted, free of charge, to any person obtaining a
// copy of this software and associated documentation files (the "Software"),
// to deal in the Software without restriction, including without limitation
// the rights to use, copy, modify, merge, publish, distribute, sublicense,
// and/or sell copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
// THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
// DEALINGS IN THE SOFTWARE.

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
