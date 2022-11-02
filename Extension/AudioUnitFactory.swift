//
//  AudioUnitFactory.swift
//  Synth
//
//  Created by Yury Popov on 28.10.2022.
//

import CoreAudioKit
import os

public class AudioUnitFactory: NSObject, AUAudioUnitFactory {
  var auAudioUnit: AUAudioUnit?
  private var observation: NSKeyValueObservation?
  public func beginRequest(with context: NSExtensionContext) {}

  @objc public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
    auAudioUnit = try SynthAudioUnit(componentDescription: componentDescription, options: [])
    guard let audioUnit = auAudioUnit as? SynthAudioUnit else {
      fatalError("Failed to create Synth")
    }
    self.observation = audioUnit.observe(\.allParameterValues, options: [.new]) { object, change in
      guard let tree = audioUnit.parameterTree else { return }
      for param in tree.allParameters { param.value = param.value }
    }
    return audioUnit
  }

}
