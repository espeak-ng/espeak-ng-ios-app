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
import Combine

class ManagedAudioUnit: ObservableObject {
  @Published private(set) var state: Result<AVAudioUnit, Error>?

  private let manager = AVAudioUnitComponentManager.shared()

  private func connect() async throws -> AVAudioUnit {
    let components = manager.components(matching: AudioComponentDescription(
      componentType: kAudioUnitType_SpeechSynthesizer,
      componentSubType: 0x6573706B, // espk
      componentManufacturer: 0x4553504B, // ESPK
      componentFlags: AudioComponentFlags([.sandboxSafe,.isV3AudioUnit]).rawValue,
      componentFlagsMask: AudioComponentFlags([.sandboxSafe,.isV3AudioUnit]).rawValue
    ))
    var err: Error = NSError(domain: NSOSStatusErrorDomain, code: Int(kAudioUnitErr_ExtensionNotFound), userInfo: [:])
    for c in components {
      do {
        return try await AVAudioUnit.instantiate(with: c.audioComponentDescription, options: [.loadOutOfProcess])
      } catch let e {
        err = e
      }
    }
    throw err
  }
  
  func tryConnect() {
    state = nil
    Task {
      for _ in 0..<5 {
        do {
          let unit = try await connect()
          DispatchQueue.main.async {
            self.state = .success(unit)
          }
          return
        } catch let e {
          DispatchQueue.main.async {
            self.state = .failure(e)
          }
        }
      }
    }
  }

  init() {
    tryConnect()
  }
}
