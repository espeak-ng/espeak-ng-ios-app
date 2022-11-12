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
      }.tint(.primary).buttonStyle(BorderlessButtonStyle())
    }
    #if os(macOS)
    .listStyle(InsetListStyle(alternatesRowBackgrounds: true))
    #endif
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
