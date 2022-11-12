//  eSpeak-NG VoiceOver synthesis AudioUnit
//  Copyright (C) 2022  Yury Popov <git@phoenix.dj>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <https://www.gnu.org/licenses/>.

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
