//
//  SharedData.swift
//  EspeakNg
//
//  Created by Yury Popov on 05.11.2022.
//

import Foundation
import OSLog

fileprivate let log = Logger(subsystem: "espeak-ng", category: "data")

@propertyWrapper struct JSONFileBacked<T: Codable> {
  let storage: URL
  let create: (()->T)?
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()

  init(storage: URL, create: (() -> T)? = nil) {
    self.storage = storage
    self.create = create
  }

  var wrappedValue: T? {
    get {
      do {
        return try decoder.decode(T.self, from: Data(contentsOf: storage, options: [.mappedIfSafe, .uncached]))
      } catch let e {
        log.error("\(e, privacy: .public)")
        return create?()
      }
    }
    set {
      do {
        try encoder.encode(newValue ?? create?()).write(to: storage, options: [.atomic, .noFileProtection])
      } catch let e {
        log.error("\(e, privacy: .public)")
      }
    }
  }
}
