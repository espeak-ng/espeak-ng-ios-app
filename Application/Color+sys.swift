//
//  Color+sys.swift
//  EspeakNg
//
//  Created by Yury Popov on 28.10.2022.
//

import SwiftUI

extension Color {
  static var secondaryBackground: Color {
#if os(iOS)
    return .init(uiColor: .secondarySystemBackground)
#else
    return .init(nsColor: .controlBackgroundColor)
#endif
  }
}
