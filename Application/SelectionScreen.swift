//
//  SelectionScreen.swift
//  EspeakNg
//
//  Created by Yury Popov on 06.11.2022.
//

import SwiftUI

struct SelectionScreen<Element, I: Hashable & Equatable, V: View>: View {
  let data: [Element]
  let id: KeyPath<Element, I>
  let isSelected: (I)->Bool
  let setSelected: (I, Bool)->Void
  @ViewBuilder let content: (Element)->V
  var body: some View {
    List(data, id: id) { item in
      Button(action: {
        let i = item[keyPath: id]
        setSelected(i, !isSelected(i))
      }) {
        HStack {
          content(item).frame(maxWidth: .infinity, alignment: .leading)
          Image(systemName: "checkmark")
            .tint(.accentColor)
            .opacity(isSelected(item[keyPath: id]) ? 1 : 0)
            .accessibilityHidden(!isSelected(item[keyPath: id]))
        }
      }.tint(.primary)
    }
  }
}

struct SingleSelectionScreen<Element, I: Hashable & Equatable, V: View>: View {
  @Environment(\.presentationMode) var presentationMode
  let data: [Element]
  let id: KeyPath<Element, I>
  @Binding var selection: I
  @ViewBuilder let content: (Element)->V
  var body: some View {
    SelectionScreen(
      data: data,
      id: id,
      isSelected: { selection == $0 },
      setSelected: { (new, sel) in
        if sel { selection = new }
        presentationMode.wrappedValue.dismiss()
      },
      content: content
    )
  }
}
