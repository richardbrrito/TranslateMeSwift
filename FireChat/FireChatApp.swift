//
//  FireChatApp.swift
//  FireChat
//
//  Created by Richard Brito on 11/4/25.
//

import SwiftUI
import FirebaseCore

@main
struct FireChatApp: App {
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
