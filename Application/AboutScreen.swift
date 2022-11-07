//
//  AboutScreen.swift
//  EspeakNg
//
//  Created by Yury Popov on 29.10.2022.
//

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
