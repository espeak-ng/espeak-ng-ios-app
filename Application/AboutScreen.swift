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

struct IconLinkButton: View {
  func _openURL(_ urlString: String) {
#if os(iOS)
    UIApplication.shared.open(URL(string: urlString)!)
#else
    NSWorkspace.shared.open(URL(string: urlString)!)
#endif
  }

  let iconName: String
  let url: String

  var body: some View {
    Button(action: {
      _openURL(url)
    }) { Image(iconName).resizable().tint(Color.white).frame(width: 34, height: 34) }.buttonStyle(.plain)
  }
}

struct AboutScreen: View {
  #if os(iOS)
  private let platform = "iOS"
  #else
  private let platform = "macOS"
  #endif

  var body: some View {
    ScrollView {
      VStack(spacing: 8) {
        Text("eSpeak-NG").font(.headline)
        Text("The eSpeak NG is a compact open source software text-to-speech synthesizer. It supports more than 100 languages and accents. It is based on the eSpeak engine created by Jonathan Duddington.")
        HStack {
          IconLinkButton(iconName: "github", url: "https://github.com/espeak-ng/espeak-ng")
        }
      }
      .padding()
      .frame(maxWidth: .infinity, alignment: .center)
      .background(RoundedRectangle(cornerRadius: 8).foregroundColor(Color.secondaryBackground))
      .padding(.horizontal).padding(.top)

      VStack(spacing: 8) {
        Text("eSpeak-NG \(platform) app").font(.headline)
        Text("eSpeak NG app is wrote by Yury Popov (@djphoenix). It is always free and open with respect to blind people.")
        HStack {
          IconLinkButton(iconName: "github", url: "https://github.com/espeak-ng/espeak-ng-ios-app")
          IconLinkButton(iconName: "telegram", url: "http://t.me/djphoenix")
          IconLinkButton(iconName: "vk", url: "http://vk.com/djphoenix.hardcore")
        }
      }
      .padding()
      .frame(maxWidth: .infinity, alignment: .center)
      .background(RoundedRectangle(cornerRadius: 8).foregroundColor(Color.secondaryBackground))
      .padding(.horizontal).padding(.bottom)
    }.navigationTitle("About")
  }
}
