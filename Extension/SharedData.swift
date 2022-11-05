//
//  SharedData.swift
//  EspeakNg
//
//  Created by Yury Popov on 05.11.2022.
//

import Foundation
import OSLog

fileprivate let log = Logger(subsystem: "espeak-ng", category: "data")

@propertyWrapper struct JSONUserDefaults<T: Codable> {
  let storage: UserDefaults
  let key: ReferenceWritableKeyPath<UserDefaults, Data?>
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()

  var wrappedValue: T? {
    get {
      do {
        return try storage[keyPath: key].flatMap({ try decoder.decode(T.self, from: $0) })
      } catch let e {
        log.error("\(e, privacy: .public)")
        return nil
      }
    }
    set {
      do {
        storage[keyPath: key] = try newValue.flatMap({ try encoder.encode($0) })
      } catch let e {
        log.error("\(e, privacy: .public)")
      }
    }
  }
}

extension UserDefaults {
  @objc dynamic var espeakRate: NSNumber? {
    get { object(forKey: "espeakRate") as? NSNumber }
    set { set(newValue, forKey: "espeakRate") }
  }
  @objc dynamic var espeakVolume: NSNumber? {
    get { object(forKey: "espeakVolume") as? NSNumber }
    set { set(newValue, forKey: "espeakVolume") }
  }
  @objc dynamic var espeakPitch: NSNumber? {
    get { object(forKey: "espeakPitch") as? NSNumber }
    set { set(newValue, forKey: "espeakPitch") }
  }
  @objc dynamic var espeakWordGap: NSNumber? {
    get { object(forKey: "espeakWordGap") as? NSNumber }
    set { set(newValue, forKey: "espeakWordGap") }
  }
  @objc dynamic var espeakLangs: Data? {
    get { object(forKey: "espeakLangs") as? Data }
    set { set(newValue, forKey: "espeakLangs") }
  }
  @objc dynamic var espeakVoices: Data? {
    get { object(forKey: "espeakVoices") as? Data }
    set { set(newValue, forKey: "espeakVoices") }
  }
  @objc dynamic var espeakMappings: Data? {
    get { object(forKey: "espeakMappings") as? Data }
    set { set(newValue, forKey: "espeakMappings") }
  }
}
