//
//  AudioUnitFactory.swift
//  Synth
//
//  Created by Yury Popov on 28.10.2022.
//

import CoreAudioKit

public class AudioUnitFactory: NSObject, AUAudioUnitFactory {
  public func beginRequest(with context: NSExtensionContext) {}
  @objc public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
    return try SynthAudioUnit(componentDescription: componentDescription, options: [])
  }
}
